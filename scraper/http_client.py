"""Nazik HTTP istemcisi: robots.txt'e uyar, istekler arasında bekler, hata durumunda yeniden dener."""
from __future__ import annotations

import json
import logging
import time
from pathlib import Path
from urllib import robotparser
from urllib.parse import urlparse

import requests

logger = logging.getLogger("http")

USER_AGENT = "KPSSPusulaBot/1.0 (+kamu ilan takibi; iletisim: uygulama sahibi)"


class RobotsDisallowed(Exception):
    """Site, robots.txt ile bu yolun otomatik okunmasını yasaklıyor."""


class Fetcher:
    def __init__(self, delay: float = 1.5, timeout: float = 30.0, debug_dir: str | None = None,
                 session: requests.Session | None = None):
        self.delay = delay
        self.timeout = timeout
        self.debug_dir = Path(debug_dir) if debug_dir else None
        self.session = session or requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT, "Accept-Language": "tr-TR,tr;q=0.9"})
        self._robots: dict[str, robotparser.RobotFileParser | None] = {}
        self._last = 0.0
        if self.debug_dir:
            self.debug_dir.mkdir(parents=True, exist_ok=True)

    def _allowed(self, url: str) -> bool:
        p = urlparse(url)
        origin = f"{p.scheme}://{p.netloc}"
        if origin not in self._robots:
            rp = robotparser.RobotFileParser()
            try:
                resp = self.session.get(f"{origin}/robots.txt", timeout=self.timeout)
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
        rp = self._robots[origin]
        return True if rp is None else rp.can_fetch(USER_AGENT, url)

    def get(self, url: str, retries: int = 2, render: bool = False) -> str:
        """Sayfayı indirir. render=True: JavaScript'i çalıştıran gerçek tarayıcı (Playwright) kullanır.
        robots.txt kontrolü iki durumda da yapılır."""
        if not self._allowed(url):
            raise RobotsDisallowed(url)
        if render:
            return self._render(url)
        last_err: Exception | None = None
        for attempt in range(retries + 1):
            wait = self.delay - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            try:
                resp = self.session.get(url, timeout=self.timeout)
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
                time.sleep(2 * (attempt + 1))
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
                        try:
                            body = resp.text()[:2000]
                        except Exception:  # noqa: BLE001
                            body = ""
                        xhr.append({"url": resp.url, "status": resp.status, "content_type": ct,
                                    "method": resp.request.method, "body_head": body})

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
