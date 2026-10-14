"""Tüm kaynak botlarının ortak mantığı: ilan modeli, süzme, genel bağlantı toplama."""
from __future__ import annotations

import hashlib
import logging
import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Iterable
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from http_client import Fetcher, RobotsDisallowed
from text_utils import (
    TR_TZ, clean, extract_city, extract_codes, extract_levels, extract_positions,
    find_application_end, find_dates, fold_tr,
)

logger = logging.getLogger("scraper")


@dataclass
class Listing:
    """appointments tablosundaki bir satırın bot tarafındaki karşılığı."""
    external_id: str
    title: str
    institution: str
    url: str
    city: str | None = None
    description: str | None = None
    education_levels: list[str] = field(default_factory=list)
    qualification_codes: list[str] = field(default_factory=list)
    departments: list[str] = field(default_factory=list)
    positions_count: int | None = None
    application_start: datetime | None = None
    application_end: datetime | None = None
    published_at: datetime | None = None
    kpss_required: bool = True

    def to_row(self, source: str) -> dict:
        iso = lambda d: d.isoformat() if d else None  # noqa: E731
        row = {
            "source": source,
            "external_id": self.external_id,
            "title": self.title,
            "institution": self.institution,
            "city": self.city,
            "description": self.description,
            "education_levels": self.education_levels,
            "qualification_codes": self.qualification_codes,
            "departments": self.departments,
            "positions_count": self.positions_count,
            "application_start": iso(self.application_start),
            "application_end": iso(self.application_end),
            "url": self.url,
            "kpss_required": self.kpss_required,
            # Tarih bilinmiyorsa ilk görüldüğü an: liste sıralaması için yeterlidir.
            "published_at": iso(self.published_at or datetime.now(TR_TZ)),
        }
        return row


# ---------------------------------------------------------------------------
# Süzgeçler
# ---------------------------------------------------------------------------
_HIRING = ("alim", "alinacak", "alinmasi", "personel", "isci", "kadro", "memur", "sozlesmeli",
           "ilan", "atama", "istihdam", "eleman", "gorevli")
_NOISE = ("sonuc", "listesi", "yer ve tarih", "sinav yeri", "mulakat", "test ilan", "sistem test",
          "iletisim", "hakkimizda", "gizlilik", "cerez", "kvkk", "anasayfa", "arsivi", "site haritasi")


def is_hiring_title(title: str) -> bool:
    """Başlık bir personel alım ilanına benziyor mu? (sonuç/liste/menü bağlantıları elenir)"""
    t = fold_tr(title)
    if len(t) < 12:
        return False
    if any(n in t for n in _NOISE):
        return False
    return any(h in t for h in _HIRING)


_NO_KPSS = re.compile(r"kpss\s*['’]?\s*(siz|sart(i|siz)?\s*(aranmaz|yok)|gerekmez|aranmamaktadir)")


def detect_kpss(text: str, default: bool) -> bool:
    """Metne göre KPSS şartı: 'KPSS'siz' -> False, 'KPSS' geçiyorsa True, yoksa kaynağın varsayılanı."""
    t = fold_tr(text)
    if _NO_KPSS.search(t):
        return False
    if "kpss" in t:
        return True
    return default


_INSTITUTION = re.compile(
    r"([A-ZÇĞİÖŞÜ][\wÇĞİÖŞÜçğıöşü.'’ ]{2,70}?"
    r"(?:Belediyesi|Belediye Başkanlığı|Üniversitesi|Müdürlüğü|Bakanlığı|Başkanlığı|Valiliği|"
    r"Kaymakamlığı|Hastanesi|Kurumu|Başkanlık|Müdürlük))"
)


def guess_institution(title: str, context: str, default: str) -> str:
    for text in (title, context):
        m = _INSTITUTION.search(text or "")
        if m:
            return clean(m.group(1))[:120]
    return default


def stable_id(*parts: str) -> str:
    return hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:32]


# ---------------------------------------------------------------------------
# Temel sınıf
# ---------------------------------------------------------------------------
class BaseScraper:
    key: str = ""                 # appointment_source enum değeri
    name: str = ""
    list_urls: tuple[str, ...] = ()
    default_institution: str = ""
    default_kpss: bool = True     # kaynakta KPSS şartı varsayılanı
    max_details: int = 40         # tek taramada en fazla kaç detay sayfası açılır
    needs_js: bool = False        # True: sayfa JavaScript ile oluşuyor, doğrudan tarayıcıyla aç
    js_fallback: bool = True      # statik HTML'de ilan bulunamazsa tarayıcıyla bir kez daha dene

    def __init__(self, fetcher: Fetcher):
        self.fetcher = fetcher

    # -- alt sınıfın dolduracağı kısım ---------------------------------------
    def parse_list(self, html: str, page_url: str) -> list[Listing]:
        raise NotImplementedError

    def enrich(self, item: Listing, html: str) -> None:
        """Detay sayfasından ek alanları doldurur (isteğe bağlı)."""

    def wants_details(self) -> bool:
        return False

    # -- ortak akış ---------------------------------------------------------
    def scrape(self, known_ids: Iterable[str] = ()) -> list[Listing]:
        known = set(known_ids)
        items: dict[str, Listing] = {}
        for url in self.list_urls:
            try:
                html = self.fetcher.get(url, render=self.needs_js)
                found = self.parse_list(html, url)
                if not found and self.js_fallback and not self.needs_js:
                    logger.info("%s: statik HTML'de ilan yok, JavaScript ile yeniden deneniyor.", self.name)
                    found = self.parse_list(self.fetcher.get(url, render=True), url)
            except RobotsDisallowed:
                logger.warning("%s: %s robots.txt ile yasak; bu adres atlandı.", self.name, url)
                continue
            except Exception as e:  # noqa: BLE001 - tek adres hatası diğerlerini durdurmasın
                logger.error("%s: %s alınamadı: %s", self.name, url, e)
                continue
            logger.info("%s: %s -> %d aday ilan", self.name, url, len(found))
            for it in found:
                items.setdefault(it.external_id, it)

        if self.wants_details():
            opened = 0
            for it in items.values():
                if it.external_id in known or opened >= self.max_details:
                    continue
                try:
                    self.enrich(it, self.fetcher.get(it.url))
                    opened += 1
                except RobotsDisallowed:
                    continue
                except Exception as e:  # noqa: BLE001
                    logger.warning("%s: detay alınamadı (%s): %s", self.name, it.url, e)

        now = datetime.now(TR_TZ)
        fresh = [i for i in items.values() if not (i.application_end and i.application_end < now)]
        if len(fresh) != len(items):
            logger.info("%s: %d süresi dolmuş ilan atlandı.", self.name, len(items) - len(fresh))
        return fresh


class AnchorListScraper(BaseScraper):
    """Sayfadaki bağlantılardan ilan toplar: site yapısını bilmeden çalışabilen genel yöntem.

    Her `<a>` için başlık = bağlantı metni; tarih/şehir/kurum için bağlantının bulunduğu
    satır/kart metni (en fazla 3 üst eleman) bağlam olarak okunur.
    """

    def parse_list(self, html: str, page_url: str) -> list[Listing]:
        soup = BeautifulSoup(html, "lxml")
        for tag in soup(["script", "style", "noscript", "nav", "header", "footer"]):
            tag.decompose()
        out: list[Listing] = []
        for a in soup.find_all("a", href=True):
            href = a["href"].strip()
            if href.startswith(("#", "javascript:", "mailto:", "tel:")):
                continue
            title = clean(a.get_text(" ")) or clean(a.get("title"))
            if not is_hiring_title(title):
                continue
            out.append(self._listing(title, urljoin(page_url, href), self._context(a, title)))
        return out

    @staticmethod
    def _context(a, title: str) -> str:
        node = a
        text = title
        for _ in range(3):
            parent = node.parent
            if parent is None:
                break
            candidate = clean(parent.get_text(" "))
            if len(candidate) > 500:
                break
            node, text = parent, candidate
            if len(text) > len(title) + 10:
                break
        return text

    def _listing(self, title: str, url: str, context: str) -> Listing:
        both = f"{title} {context}"
        institution = guess_institution(title, context, self.default_institution)
        return Listing(
            external_id=stable_id(self.key, url),
            title=title[:300],
            institution=institution,
            url=url,
            city=extract_city(f"{institution} {title}") or extract_city(context),
            description=context[:1500] if context != title else None,
            education_levels=extract_levels(both),
            qualification_codes=extract_codes(both),
            positions_count=extract_positions(both),
            application_end=find_application_end(context),
            kpss_required=detect_kpss(both, self.default_kpss),
        )
