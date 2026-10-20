"""Nazik HTTP istemcisi: robots.txt'e uyar, istekler arasında bekler, hata durumunda yeniden dener."""
from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path
from urllib import robotparser
from urllib.parse import urlparse

import requests

logger = logging.getLogger("http")

USER_AGENT = "KPSSPusulaBot/1.0 (+kamu ilan takibi; iletisim: uygulama sahibi)"


_TRACKER_HOSTS = ("google-analytics.com", "googletagmanager.com", "doubleclick.net", "clarity.ms")
_XHR_BODY_LIMIT = 400_000  # hata ayıklama dosyasında bir yanıtın en fazla kaç karakteri saklanır


def _use_system_certs() -> None:
    """USE_SYSTEM_CERTS=1 ise sertifikalar Python'un paketli listesi yerine işletim sisteminin
    güvenilir sertifika deposundan doğrulanır. Bazı kamu siteleri ara sertifikayı göndermez;
    tarayıcılar/macOS eksik zinciri tamamlar, `requests` tamamlamaz ("unable to get local issuer
    certificate"). Doğrulama KAPATILMAZ; yalnızca güvenilir sertifika kaynağı değişir."""
    if os.environ.get("USE_SYSTEM_CERTS") != "1":
        return
    try:
        import truststore
    except ImportError:
        logger.warning("USE_SYSTEM_CERTS=1 ama truststore kurulu değil: pip install truststore")
        return
    truststore.inject_into_ssl()
    logger.info("Sertifikalar işletim sistemi deposundan doğrulanacak (truststore).")


class RobotsDisallowed(Exception):
    """Site, robots.txt ile bu yolun otomatik okunmasını yasaklıyor."""


class Fetcher:
    def __init__(self, delay: float = 1.5, timeout: float = 30.0, debug_dir: str | None = None,
                 session: requests.Session | None = None):
        _use_system_certs()
        self.delay = delay
        self.timeout = timeout
        self.debug_dir = Path(debug_dir) if debug_dir else None
        self.session = session or requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT, "Accept-Language": "tr-TR,tr;q=0.9"})
        self._robots: dict[str, robotparser.RobotFileParser | None] = {}
        self._dead: set[str] = set()   # bu taramada ulaşılamayan siteler (zaman aşımı / bağlantı / SSL)
        self._last = 0.0
        if self.debug_dir:
            self.debug_dir.mkdir(parents=True, exist_ok=True)

    @property
    def _req_timeout(self):
        """(bağlanma, okuma): ulaşılamayan site 30 sn yerine 10 sn'de anlaşılır."""
        return (min(10.0, self.timeout), self.timeout)

    @staticmethod
    def _origin(url: str) -> str:
        p = urlparse(url)
        return f"{p.scheme}://{p.netloc}"

    def _mark_dead(self, url: str, err: Exception) -> None:
        origin = self._origin(url)
        if origin not in self._dead:
            self._dead.add(origin)
            logger.error("%s ulaşılamıyor (%s); bu taramada bu siteye başka istek atılmayacak.",
                         origin, type(err).__name__)

    def _check_alive(self, url: str) -> None:
        if self._origin(url) in self._dead:
            raise requests.ConnectionError(f"{self._origin(url)} bu taramada ulaşılamaz olarak işaretlendi")

    def _allowed(self, url: str) -> bool:
        p = urlparse(url)
        origin = f"{p.scheme}://{p.netloc}"
        if origin not in self._robots:
            rp = robotparser.RobotFileParser()
            try:
                resp = self.session.get(f"{origin}/robots.txt", timeout=self._req_timeout)
                if resp.status_code == 200:
                    rp.parse(resp.text.splitlines())
                    self._robots[origin] = rp
                elif resp.status_code in (401, 403):
                    # robots.txt'e bile erişim yasaksa en temkinli yorum: izin yok.
                    rp.parse(["User-agent: *", "Disallow: /"])
                    self._robots[origin] = rp
                else:
                    self._robots[origin] = None  # robots.txt yok -> kısıt yok
            except requests.RequestException as e:
                logger.warning("robots.txt okunamadı (%s): %s", origin, e)
                self._robots[origin] = None
                if isinstance(e, (requests.Timeout, requests.ConnectionError)):
                    # robots.txt bile gelmiyorsa sayfa da gelmez: dakikalarca beklemeyelim.
                    self._mark_dead(origin, e)
        rp = self._robots[origin]
        return True if rp is None else rp.can_fetch(USER_AGENT, url)

    def get(self, url: str, retries: int = 2, render: bool = False) -> str:
        """Sayfayı indirir. render=True: JavaScript'i çalıştıran gerçek tarayıcı (Playwright) kullanır.
        robots.txt kontrolü iki durumda da yapılır."""
        if not render:
            self._check_alive(url)
        if not self._allowed(url):
            raise RobotsDisallowed(url)
        if render:
            return self._render(url)
        self._check_alive(url)  # robots.txt okunurken ulaşılamaz çıkmış olabilir
        last_err: Exception | None = None
        for attempt in range(retries + 1):
            wait = self.delay - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            try:
                resp = self.session.get(url, timeout=self._req_timeout)
                self._last = time.monotonic()
                resp.raise_for_status()
                resp.encoding = resp.encoding if resp.encoding and resp.encoding.lower() != "iso-8859-1" else resp.apparent_encoding
                html = resp.text
                self._dump(url, html)
                return html
            except requests.RequestException as e:
                last_err = e
                self._last = time.monotonic()
                logger.warning("İstek hatası (%s) deneme %d/%d: %s", url, attempt + 1, retries + 1, e)
                if isinstance(e, requests.exceptions.SSLError):
                    # Sertifika zinciri sorunu yeniden denemekle düzelmez.
                    self._mark_dead(url, e)
                    break
                time.sleep(2 * (attempt + 1))
        if isinstance(last_err, (requests.Timeout, requests.ConnectionError)):
            self._mark_dead(url, last_err)
        raise last_err  # type: ignore[misc]

    def post_json(self, url: str, payload: dict, retries: int = 2, robots_url: str | None = None):
        """JSON gövdeli POST (sitenin sayfasına veri sağlayan kendi API'si); yanıtı JSON olarak döndürür.
        robots.txt, bekleme, yeniden deneme ve "ulaşılamıyor" mantığı `get` ile aynıdır. robots.txt, `robots_url`
        (verilmezse `url`) için kontrol edilir: veri API'si ayrı bir site değil, o sayfanın arka ucudur."""
        self._check_alive(url)
        if not self._allowed(robots_url or url):
            raise RobotsDisallowed(robots_url or url)
        self._check_alive(url)
        last_err: Exception | None = None
        for attempt in range(retries + 1):
            wait = self.delay - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            try:
                resp = self.session.post(url, json=payload, timeout=self._req_timeout)
                self._last = time.monotonic()
                resp.raise_for_status()
                data = resp.json()
                self._dump(url, resp.text)
                return data
            except ValueError:
                raise  # bozuk JSON: yeniden denemenin anlamı yok
            except requests.RequestException as e:
                last_err = e
                self._last = time.monotonic()
                logger.warning("İstek hatası (%s) deneme %d/%d: %s", url, attempt + 1, retries + 1, e)
                if isinstance(e, requests.exceptions.SSLError):
                    self._mark_dead(url, e)
                    break
                time.sleep(2 * (attempt + 1))
        if isinstance(last_err, (requests.Timeout, requests.ConnectionError)):
            self._mark_dead(url, last_err)
        raise last_err  # type: ignore[misc]

    def get_bytes(self, url: str, retries: int = 2, max_bytes: int = 8_000_000) -> bytes:
        """İkili dosya (PDF vb.) indirir. robots.txt, bekleme ve yeniden deneme `get` ile aynıdır;
        `max_bytes`'tan büyük dosyalar indirilmeden reddedilir."""
        self._check_alive(url)
        if not self._allowed(url):
            raise RobotsDisallowed(url)
        self._check_alive(url)
        last_err: Exception | None = None
        for attempt in range(retries + 1):
            wait = self.delay - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            try:
                resp = self.session.get(url, timeout=self._req_timeout, stream=True)
                self._last = time.monotonic()
                resp.raise_for_status()
                size = int(resp.headers.get("Content-Length") or 0)
                if size > max_bytes:
                    resp.close()
                    raise ValueError(f"dosya çok büyük ({size} bayt): {url}")
                data = resp.content
                if len(data) > max_bytes:
                    raise ValueError(f"dosya çok büyük ({len(data)} bayt): {url}")
                return data
            except ValueError:
                raise  # boyut hatası: yeniden denemenin anlamı yok
            except requests.RequestException as e:
                last_err = e
                self._last = time.monotonic()
                logger.warning("İstek hatası (%s) deneme %d/%d: %s", url, attempt + 1, retries + 1, e)
                if isinstance(e, requests.exceptions.SSLError):
                    self._mark_dead(url, e)
                    break
                time.sleep(2 * (attempt + 1))
        if isinstance(last_err, (requests.Timeout, requests.ConnectionError)):
            self._mark_dead(url, last_err)
        raise last_err  # type: ignore[misc]

    def _dump(self, url: str, html: str) -> None:
        if not self.debug_dir:
            return
        name = "".join(c if c.isalnum() else "_" for c in url)[:120] + ".html"
        (self.debug_dir / name).write_text(html, encoding="utf-8")

    # -- JavaScript ile oluşan sayfalar -----------------------------------------
    def _render(self, url: str) -> str:
        try:
            from playwright.sync_api import sync_playwright
        except ImportError as e:  # pragma: no cover - ortam bağımlı
            raise RuntimeError(
                "JavaScript gerektiren sayfa için Playwright kurulu olmalı: "
                "pip install -r requirements-js.txt && playwright install chromium"
            ) from e
        wait = self.delay - (time.monotonic() - self._last)
        if wait > 0:
            time.sleep(wait)
        xhr: list[dict] = []
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True)
            try:
                page = browser.new_page(user_agent=USER_AGENT, locale="tr-TR")

                def on_response(resp):
                    ct = resp.headers.get("content-type", "")
                    if resp.request.resource_type in ("xhr", "fetch") or "json" in ct:
                        if any(h in resp.url for h in _TRACKER_HOSTS):
                            return
                        try:
                            body = resp.text()[:_XHR_BODY_LIMIT]
                        except Exception:  # noqa: BLE001
                            body = ""
                        try:
                            post = resp.request.post_data
                        except Exception:  # noqa: BLE001
                            post = None
                        xhr.append({
                            "url": resp.url, "status": resp.status, "content_type": ct,
                            "method": resp.request.method,
                            "post_data": post,  # sitenin API'ye gönderdiği istek gövdesi (aynı çağrıyı kurmak için)
                            # Yalnızca başlık ADLARI kaydedilir (jeton/çerez değerleri dosyaya yazılmaz).
                            "request_header_names": sorted(resp.request.headers.keys()),
                            "body": body,
                        })

                page.on("response", on_response)
                page.goto(url, wait_until="networkidle", timeout=int(self.timeout * 1000))
                html = page.content()
            finally:
                browser.close()
        self._last = time.monotonic()
        self._dump(url, html)
        if self.debug_dir and xhr:
            name = "".join(c if c.isalnum() else "_" for c in url)[:120] + ".xhr.json"
            (self.debug_dir / name).write_text(json.dumps(xhr, ensure_ascii=False, indent=2), encoding="utf-8")
            logger.info("%d XHR/JSON isteği kaydedildi: %s", len(xhr), name)
        return html
