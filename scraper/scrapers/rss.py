"""RSS/Atom beslemesi okuyan kaynaklar.

Kariyer Kapısı (kariyerkapisi.gov.tr) "Kamu İşe Alım" için resmi bir RSS beslemesi yayınlıyor
(`/RSS?k=3`). Besleme zaten yalnızca alım ilanlarını içerir; HTML'den bağlantı toplamaktan çok daha
sağlamdır ve site tasarımı değişse de bozulmaz.
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from datetime import datetime
from email.utils import parsedate_to_datetime
from urllib.parse import parse_qs, urlparse

from text_utils import (
    TR_TZ, clean, extract_city, extract_codes, extract_levels, extract_positions, tr_title,
)
from .base import BaseScraper, Listing, detect_kpss, is_noise_title, stable_id

_XML_DECL = re.compile(r"^\s*<\?xml[^>]*\?>", re.I)


def parse_feed_date(text: str | None) -> datetime | None:
    """RFC 822 ("Sun, 05 Oct 2026 08:30:00 +0300"), ISO 8601 ve "2026-10-05 08:30:00" biçimlerini okur.
    Saat dilimi yoksa Türkiye saati kabul edilir."""
    text = clean(text)
    if not text:
        return None
    dt: datetime | None = None
    try:
        dt = parsedate_to_datetime(text)
    except (TypeError, ValueError):
        dt = None
    if dt is None:
        try:
            dt = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None
    return dt.replace(tzinfo=TR_TZ) if dt.tzinfo is None else dt.astimezone(TR_TZ)


class RssFeedScraper(BaseScraper):
    """Alt sınıf `list_urls` (besleme adresleri) ve `default_institution` verir."""

    split_institution = True  # "KURUM - İlan başlığı" biçimindeki başlığı kuruma ve başlığa ayır
    js_fallback = False       # RSS'in tarayıcıyla açılmasının anlamı yok

    def parse_list(self, html: str, page_url: str) -> list[Listing]:
        try:
            root = ET.fromstring(_XML_DECL.sub("", html).strip())
        except ET.ParseError as e:
            raise RuntimeError(f"RSS çözümlenemedi ({page_url}): {e}") from e

        out: list[Listing] = []
        # RSS 2.0: channel/item — Atom: entry. Ad alanı önekini yok sayarak tarıyoruz.
        for node in root.iter():
            if node.tag.split("}")[-1] not in ("item", "entry"):
                continue
            item = self._read_item(node, page_url)
            if item:
                out.append(item)
        return out

    @staticmethod
    def _text(node: ET.Element, name: str) -> str:
        for child in node:
            if child.tag.split("}")[-1] == name:
                # Atom <link href="..."/> biçimi
                return clean(child.text) or child.attrib.get("href", "")
        return ""

    def _read_item(self, node: ET.Element, page_url: str) -> Listing | None:
        raw_title = self._text(node, "title")
        link = self._text(node, "link") or self._text(node, "guid")
        if not raw_title or not link or is_noise_title(raw_title):
            return None

        institution, title = self.default_institution, raw_title
        if self.split_institution and " - " in raw_title:
            head, tail = raw_title.split(" - ", 1)
            if 3 <= len(head) <= 90 and len(tail) >= 8:
                institution, title = tr_title(head), clean(tail)

        categories = [clean(c.text) for c in node if c.tag.split("}")[-1] == "category" and clean(c.text)]
        summary = self._text(node, "description") or self._text(node, "summary")
        description = " • ".join(p for p in (
            f"Kategori: {', '.join(categories)}" if categories else "",
            summary if summary and clean(summary) != clean(raw_title) else "",
        ) if p) or None

        both = f"{raw_title} {description or ''}"
        return Listing(
            external_id=self._external_id(link),
            title=title[:300],
            institution=institution[:120],
            url=link,
            city=extract_city(both),
            description=description,
            education_levels=extract_levels(both),
            qualification_codes=extract_codes(both),
            positions_count=extract_positions(raw_title),
            published_at=parse_feed_date(self._text(node, "pubDate") or self._text(node, "published")
                                         or self._text(node, "updated")),
            kpss_required=detect_kpss(both, self.default_kpss),
        )

    def _external_id(self, link: str) -> str:
        return stable_id(self.key, link)


class KariyerKapisiScraper(RssFeedScraper):
    key = "kariyerkapisi"
    name = "Kariyer Kapısı"
    # k=3: "Kamu İşe Alım". Beslemede şimdilik yalnızca bu kategori gözlendi; başka kategori
    # numaraları (ör. staj) doğrulanırsa buraya eklenir.
    list_urls = ("https://kariyerkapisi.gov.tr/RSS?k=3",)
    default_institution = "Cumhurbaşkanlığı Kariyer Kapısı"
    default_kpss = True

    def _external_id(self, link: str) -> str:
        # İlan bağlantısı: https://kariyerkapisi.gov.tr/IlanDetay?i=<uuid>
        ilan = parse_qs(urlparse(link).query).get("i", [""])[0]
        return f"kk-{ilan}" if ilan else stable_id(self.key, link)
