"""Resmî Gazete "İlan Bölümü" (resmigazete.gov.tr) — kamu personel alım ilanları.

Resmî Gazete'nin ilan bölümünde yargı, ihale, icra vb. yüzlerce ilanın arasında üniversite, belediye ve
kurumların personel alım ilanları da yayımlanır. İlanlar çoğunlukla PDF olduğu için akış şöyledir:

  1. Son `days_back` günün günlük sayfası açılır:
       https://www.resmigazete.gov.tr/eskiler/YYYY/MM/YYYYMMDD.htm
  2. Sayfadaki `/ilanlar/eskiilanlar/...` bağlantıları toplanır (PDF doğrudan aday olur; yalnızca HTML
     sayfa bağlantıları varsa bu sayfalar bir seviye daha izlenir — `follow`).
  3. Başlığı kamu kurumuna benzeyen ve mahkeme/icra/ihale gibi gürültü içermeyen adaylar açılır;
     PDF'in metni `pypdf` ile okunur ve gerçekten bir ALIM ilanı olup olmadığına bakılır
     (iptal, erteleme, sonuç, düzeltme ilanları elenir).
  4. Alım ilanından kurum, il, eğitim seviyesi, KPSS şartı, son başvuru tarihi çıkarılır.

UYARI: Günlük sayfa adresi ve ilan PDF yolu doğrulandı, ama günlük sayfanın İÇ HTML yapısı geliştirme
ortamından görülemedi (site otomatik erişime kapalı). İlk çalıştırmada GitHub Actions "discover" modunu
(source: resmigazete) ya da yerelde `python run.py --source resmigazete --discover` kullanıp çıktıyı
kontrol edin; gerekirse `_ILAN_HREF` ve ön süzgeçleri bu dosyada ayarlayın.

Aynı PDF'i her saat yeniden indirmemek için alım ilanı OLMADIĞI anlaşılan adaylar küçük bir yerel
önbelleğe yazılır (`scraper/.cache/`, yoksa oluşturulur; GitHub'da her çalışma temiz olduğundan orada
yalnızca `actions/cache` ile kalıcı olur).
"""
from __future__ import annotations

import io
import json
import logging
import os
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from text_utils import (
    TR_TZ, clean, extract_city, extract_codes, extract_levels, extract_positions,
    find_application_end, fold_tr, tr_title,
)
from .base import BaseScraper, Listing, detect_kpss, stable_id

logger = logging.getLogger("scraper")

DAILY_URL = "https://www.resmigazete.gov.tr/eskiler/{y}/{m:02d}/{y}{m:02d}{d:02d}.htm"

# İlan bağlantıları: .../ilanlar/eskiilanlar/2023/02/20230215-4-1.pdf (PDF) ya da .htm sayfası.
_ILAN_HREF = re.compile(r"/ilanlar/eskiilanlar/[^\s\"'<>]*?\.(pdf|html?)(?:$|[?#])", re.I)
_DATE_IN_PATH = re.compile(r"(?<!\d)(20\d{2})(\d{2})(\d{2})(?!\d)")

# Başlık ön süzgeci (fold_tr ile): kamu kurumu ipuçları var, mahkeme/icra/ihale gürültüsü yok.
_PUBLIC_HINT = ("universite", "rektorlug", "belediye", "bakanlig", "baskanlig", "mudurlug", "valilig",
                "kaymakamlig", "hastane", "kurumu", "genel mudur", "komutanlig", "fakulte", "enstitu",
                "yuksekokul", "meslek yuksek")
_COURT_NOISE = ("icra", "mahkeme", "hakimlig", "savcilig", "noter", "iflas", "konkordato", "ihale",
                "tebligat", "satis ilani", "ilan ucreti", "tapu", "vergi dairesi", "ticaret sicil")


def daily_url(day: datetime) -> str:
    return DAILY_URL.format(y=day.year, m=day.month, d=day.day)


def looks_public(title: str) -> bool:
    """Başlık bir kamu kurumuna benziyor ve mahkeme/icra/ihale ilanı değil mi?"""
    t = fold_tr(title)
    return any(h in t for h in _PUBLIC_HINT) and not any(n in t for n in _COURT_NOISE)


# ---------------------------------------------------------------------------
# İçerik sınıflandırma
# ---------------------------------------------------------------------------
_HIRING = ("alinacak", "alim ilani", "istihdam edilecek", "atanmak uzere", "alimi yapilacak")
_ROLE_HINT = ("personel", "isci", "ogretim", "memur", "kadro", "sozlesmeli", "arastirma gorevlisi", "uzman",
              "hemsire", "teknisyen", "tekniker", "muhendis", "avukat", "doktor", "zabita", "bekci", "sofor")
_ACADEMIC = ("ogretim uyesi", "ogretim elemani", "ogretim gorevlisi", "arastirma gorevlisi", "okutman")
# Başlık bölgesinde (ilk 500 karakter) bulunursa ilan alım ilanı sayılmaz.
_HEAD_REJECT = ("iptal", "ertelen", "duzeltme", "sonuc", "ek sure", "ek ilan")
# Metnin herhangi bir yerinde bulunursa alım ilanı sayılmaz.
_ANY_REJECT = ("iptal edilmis", "iptal edilmistir", "ertelenmis", "ertelenmistir")


def classify_ilan(text: str) -> str | None:
    """İlan metni bir personel ALIM ilanıysa türünü ("Öğretim Elemanı Alım İlanı" vb.), değilse None döner."""
    t = fold_tr(text[:5000])
    if any(w in t[:500] for w in _HEAD_REJECT) or any(w in t for w in _ANY_REJECT):
        return None
    if not any(h in t for h in _HIRING) or not any(r in t for r in _ROLE_HINT):
        return None
    if any(a in t for a in _ACADEMIC):
        return "Öğretim Elemanı Alım İlanı"
    if re.search(r"\bisci", t):
        return "İşçi Alım İlanı"
    if "sozlesmeli" in t:
        return "Sözleşmeli Personel Alım İlanı"
    return "Personel Alım İlanı"


_INSTITUTION = re.compile(
    r"([a-z0-9][a-z0-9 .'\-]{2,90}?"
    r"(?:universitesi|rektorlugu|belediye baskanligi|belediyesi|valiligi|kaymakamligi|bakanligi|"
    r"genel mudurlugu|mudurlugu|baskanligi|hastanesi|kurumu))"
)
_TC_PREFIX = re.compile(r"^t\.?\s?c\.?\s+")


def guess_institution(text: str) -> str | None:
    """Metnin başındaki kurum adını bulur ("T.C. KİLİS 7 ARALIK ÜNİVERSİTESİ Rektörlüğünden" -> "Kilis 7 Aralık
    Üniversitesi"). fold_tr uzunluğu değiştirmediğinden eşleşme konumları özgün metne uygulanır."""
    head = text[:500]
    folded = fold_tr(head)
    m = _INSTITUTION.search(folded)
    if not m:
        return None
    start, end = m.span(1)
    prefix = _TC_PREFIX.match(folded[start:end])
    if prefix:
        start += prefix.end()
    name = tr_title(head[start:end])
    return name[:120] if len(name) >= 5 else None


def pdf_text(data: bytes, max_pages: int = 3) -> str:
    """PDF'in ilk sayfalarının metni. pypdf yoksa ya da PDF okunamazsa (ör. taranmış görüntü) boş döner."""
    try:
        from pypdf import PdfReader
    except ImportError:
        logger.warning("pypdf kurulu değil; PDF ilanlar okunamıyor (pip install pypdf).")
        return ""
    try:
        reader = PdfReader(io.BytesIO(data))
        return clean(" ".join((page.extract_text() or "") for page in reader.pages[:max_pages]))
    except Exception as e:  # noqa: BLE001 - bozuk PDF taramayı durdurmasın
        logger.warning("PDF okunamadı: %s", e)
        return ""


def _is_pdf(url: str) -> bool:
    return re.split(r"[?#]", url, maxsplit=1)[0].lower().endswith(".pdf")


# ---------------------------------------------------------------------------
# Reddedilen adaylar için küçük yerel önbellek (her saat aynı PDF'leri yeniden indirmemek için)
# ---------------------------------------------------------------------------
_CACHE_DAYS = 10


def _load_cache(path: str | None, now: datetime) -> set[str]:
    if not path:
        return set()
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return set()
    limit = (now - timedelta(days=_CACHE_DAYS)).date().isoformat()
    return {k for k, day in data.items() if isinstance(day, str) and day >= limit}


def _save_cache(path: str | None, old: set[str], new: Iterable[str], now: datetime) -> None:
    new = set(new)
    if not path or not new:
        return
    today = now.date().isoformat()
    try:
        existing = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        existing = {}
    limit = (now - timedelta(days=_CACHE_DAYS)).date().isoformat()
    merged = {k: d for k, d in existing.items() if isinstance(d, str) and d >= limit and k in old}
    merged.update({k: today for k in new})
    try:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_text(json.dumps(merged, ensure_ascii=False), encoding="utf-8")
    except OSError as e:
        logger.warning("Önbellek yazılamadı (%s): %s", path, e)


# ---------------------------------------------------------------------------
class ResmiGazeteScraper(BaseScraper):
    key = "resmigazete"
    name = "Resmî Gazete (İlan Bölümü)"
    default_institution = "Resmî Gazete İlanı"
    default_kpss = False        # KPSS yalnızca metinde geçiyorsa (detect_kpss) şart sayılır
    days_back = 2               # bugün + dün
    max_details = 80            # tek taramada en fazla PDF/sayfa açılır
    max_list_pages = 60
    js_fallback = False         # günlük sayfa statik HTML
    cache_file: str | None = os.environ.get("RG_CACHE_FILE", ".cache/resmigazete_rejected.json")

    def __init__(self, fetcher, now: datetime | None = None):
        super().__init__(fetcher)
        now = now or datetime.now(TR_TZ)
        self.list_urls = tuple(daily_url(now - timedelta(days=n)) for n in range(self.days_back))
        self._cached: set[str] = set()
        self._rejected: set[str] = set()
        self._accepted: set[str] = set()

    # -- liste ---------------------------------------------------------------
    def _ilan_links(self, html: str, page_url: str) -> list[tuple[str, str]]:
        """Sayfadaki (adres, başlık) çiftleri; aynı adres bir kez."""
        soup = BeautifulSoup(html, "lxml")
        seen: dict[str, str] = {}
        for a in soup.find_all("a", href=True):
            href = a["href"].strip()
            if not _ILAN_HREF.search(href):
                continue
            url = urljoin(page_url, href)
            title = clean(a.get_text(" ")) or clean(a.get("title"))
            if url not in seen or (title and not seen[url]):
                seen[url] = title
        return list(seen.items())

    def parse_list(self, html: str, page_url: str) -> list[Listing]:
        links = self._ilan_links(html, page_url)
        pdfs = [(u, t) for u, t in links if _is_pdf(u)]
        if pdfs:
            return [c for u, t in pdfs if (c := self._candidate(u, t))]
        if "/eskiler/" not in page_url:
            # İzlenen bir grup/ilan sayfası ve içinde PDF yok: sayfanın kendisi ilan metnidir.
            soup = BeautifulSoup(html, "lxml")
            title = clean(soup.title.get_text(" ")) if soup.title else ""
            c = self._candidate(page_url, title, prefilter=False)  # <title> çoğu zaman genel ("Resmî Gazete")
            return [c] if c else []
        return []

    def follow(self, html: str, page_url: str) -> list[str]:
        """Günlük sayfada doğrudan PDF yoksa, ilan HTML sayfalarını bir seviye izle."""
        if "/eskiler/" not in page_url:
            return []
        links = self._ilan_links(html, page_url)
        if any(_is_pdf(u) for u, _ in links):
            return []
        pages = [u for u, t in links if not any(n in fold_tr(t) for n in _COURT_NOISE)]
        # discover modunda sayfalar tarayıcıyla açılır (yavaş): az sayıda sayfa yeterli.
        return pages[: 8 if self.needs_js else self.max_list_pages]

    def _candidate(self, url: str, title: str, prefilter: bool = True) -> Listing | None:
        ext_id = stable_id(self.key, url)
        if ext_id in self._cached:
            return None
        # Başlık anlamlıysa (uzunsa) kamu kurumuna benzemeli; "PDF"/numara gibi boş başlıkta elenmez.
        if prefilter and len(fold_tr(title)) >= 12 and not looks_public(title):
            return None
        m = _DATE_IN_PATH.search(url)
        published = None
        if m:
            try:
                published = datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)), tzinfo=TR_TZ)
            except ValueError:
                published = None
        return Listing(
            external_id=ext_id,
            title=(title or self.default_institution)[:300],
            institution=self.default_institution,
            url=url,
            published_at=published,
            kpss_required=self.default_kpss,
        )

    # -- detay ---------------------------------------------------------------
    def wants_details(self) -> bool:
        return True

    def fetch_detail(self, item: Listing) -> str:
        """PDF ise metni `pypdf` ile, HTML ise sayfa metnini döndürür."""
        if _is_pdf(item.url):
            return pdf_text(self.fetcher.get_bytes(item.url))
        soup = BeautifulSoup(self.fetcher.get(item.url), "lxml")
        for tag in soup(["script", "style", "noscript"]):
            tag.decompose()
        return clean(soup.get_text(" "))

    def enrich(self, item: Listing, text: str) -> None:
        text = clean(text)
        kind = classify_ilan(text)
        if not kind:
            self._rejected.add(item.external_id)
            return
        self._accepted.add(item.external_id)
        institution = guess_institution(text) or item.institution
        head, body = text[:600], text[:6000]
        item.institution = institution
        item.title = f"{institution} — {kind}"[:300]
        item.description = text[:1500]
        item.city = extract_city(f"{institution} {head}")
        item.education_levels = extract_levels(body)
        item.qualification_codes = extract_codes(body)
        item.positions_count = extract_positions(body)
        item.application_end = find_application_end(body)
        item.kpss_required = detect_kpss(body, self.default_kpss)

    def keep(self, item: Listing) -> bool:
        # Yalnızca metni okunup alım ilanı olduğu doğrulananlar alınır (kota dışı kalanlar sonraki taramada).
        return item.external_id in self._accepted

    # -- önbellek ------------------------------------------------------------
    def scrape(self, known_ids: Iterable[str] = (), now: datetime | None = None) -> list[Listing]:
        clock = now or datetime.now(TR_TZ)
        self._cached = _load_cache(self.cache_file, clock)
        self._rejected, self._accepted = set(), set()
        try:
            return super().scrape(known_ids, now)
        finally:
            _save_cache(self.cache_file, self._cached, self._rejected, clock)
