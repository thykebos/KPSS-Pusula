"""pgm.adalet.gov.tr — Adalet Bakanlığı Personel Genel Müdürlüğü duyuruları.

Gözlenen yapı: duyuru bağlantıları `/Home/SayfaDetay/<slug><ddMMyyyyHHmmss>` biçimindedir; tarih
slug'ın sonunda gömülüdür. Arşiv: /Home/TumHaberler/1 (duyurular), /Home/TumHaberler/5 (haberler).
"""
from __future__ import annotations

from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

from text_utils import (
    clean, date_from_slug, extract_city, extract_codes, extract_levels, extract_positions,
    find_application_end,
)
from .base import BaseScraper, Listing, detect_kpss, is_hiring_title, stable_id


class PgmAdaletScraper(BaseScraper):
    key = "pgm_adalet"
    name = "Adalet Bakanlığı (PGM)"
    list_urls = (
        "https://pgm.adalet.gov.tr/Home/TumHaberler/1",
        "https://pgm.adalet.gov.tr/",
    )
    default_institution = "T.C. Adalet Bakanlığı"
    default_kpss = True

    def wants_details(self) -> bool:
        return True

    def parse_list(self, html: str, page_url: str) -> list[Listing]:
        soup = BeautifulSoup(html, "lxml")
        out: list[Listing] = []
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if "/Home/SayfaDetay/" not in href:
                continue
            title = clean(a.get_text(" ")) or clean(a.get("title"))
            if not is_hiring_title(title):
                continue
            url = urljoin(page_url, href)
            slug = urlparse(url).path.rstrip("/").split("/")[-1]
            out.append(Listing(
                external_id=slug[:100] or stable_id(self.key, url),
                title=title[:300],
                institution=self.default_institution,
                url=url,
                city=extract_city(title),
                education_levels=extract_levels(title),
                positions_count=extract_positions(title),
                published_at=date_from_slug(slug),
                kpss_required=detect_kpss(title, self.default_kpss),
            ))
        return out

    def enrich(self, item: Listing, html: str) -> None:
        soup = BeautifulSoup(html, "lxml")
        for tag in soup(["script", "style", "noscript", "nav", "header", "footer"]):
            tag.decompose()
        main = soup.find(id="content") or soup.find("main") or soup.body or soup
        text = clean(main.get_text(" "))
        if len(text) < 40:
            return
        item.description = text[:1500]
        item.education_levels = item.education_levels or extract_levels(text)
        item.qualification_codes = extract_codes(text)
        item.positions_count = item.positions_count or extract_positions(text)
        item.city = item.city or extract_city(text[:600])
        item.application_end = find_application_end(text, item.published_at)
        item.kpss_required = detect_kpss(f"{item.title} {text}", self.default_kpss)
