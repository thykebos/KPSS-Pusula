"""yerelyonetimler.csb.gov.tr — Çevre, Şehircilik Bakanlığı Yerel Yönetimler Genel Müdürlüğü.

Gerçek sayfa yapısı (kullanıcının çalıştırdığı bottan alınan ham HTML'den):
  • Ana sayfada "Haberler" (haber kartları) ve "Duyurular" bölümleri vardır. Personel alım ilanları
    DUYURULAR'dadır; haberler (KPSS yerleştirme takvimi, faaliyet raporu vb.) ilan değildir.
  • Duyuru kartı:  <a class="duyurular-second-card-wrapper" href=".../xxx-duyuru-478164">
                      <span class="date">09 Ekim 2026</span><p>BAŞLIK (BÜYÜK HARF)</p></a>
  • Tüm duyurular: https://yerelyonetimler.csb.gov.tr/duyurular
Başlık kalıpları:
  "<İL> İLİ <KURUM> BELEDİYE BAŞKANLIĞINA İLK DEFA ATANMAK ÜZERE <UNVAN> ALIMI İLANI"
  "<KURUM> İLK DEFA SÖZLEŞMELİ PERSONEL ( <Unvan> ) ALIM İPTAL İLANI"   (iptal: alınmaz)
  "... MEMUR ALIMI DÜZELTME İLANI"                                      (düzeltme: alınır)
"""
from __future__ import annotations

import re
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from text_utils import (
    CITY_BY_FOLD, clean, extract_city, find_application_end, find_dates, fold_tr, tr_title,
)
from .base import BaseScraper, Listing, is_hiring_title, stable_id

_ID = re.compile(r"-(\d{4,})$")


def parse_title(raw: str) -> dict:
    """Büyük harfli duyuru başlığından il, kurum, unvan ve düzeltme bilgisini çıkarır."""
    raw = clean(raw)
    f = fold_tr(raw)  # fold_tr karakter sayısını değiştirmez: indeksler raw için de geçerlidir
    city = None
    start = 0
    m = re.match(r"^([a-z ]+?) ili\s+", f)
    if m:
        city = CITY_BY_FOLD.get(m.group(1).strip())
        start = m.end()
    end_m = re.search(r"\s(ilk defa|atanmak uzere)\b", f[start:])
    end = start + end_m.start() if end_m else len(raw)
    institution = re.sub(r"Başkanlığına$", "Başkanlığı", tr_title(raw[start:end])) or None

    role = None
    paren = re.search(r"\(([^)]+)\)", raw)
    if paren and "sozlesmeli" in f:
        role = paren.group(1)
    else:
        r = re.search(r"atanmak uzere\s+(.+?)\s+alim", f)
        if r:
            role = raw[r.start(1):r.end(1)]
    return {
        "city": city or extract_city(raw),
        "institution": institution,
        "role": tr_title(role) if role else None,
        "correction": "duzeltme" in f,
        "sozlesmeli": "sozlesmeli" in f,
    }


class YerelYonetimlerScraper(BaseScraper):
    key = "yerelyonetimler"
    name = "Yerel Yönetimler (ÇŞB)"
    # Önce tüm duyurular sayfası, ayrıca ana sayfadaki "Duyurular" bölümü (aynı kart yapısı).
    list_urls = (
        "https://yerelyonetimler.csb.gov.tr/duyurular",
        "https://yerelyonetimler.csb.gov.tr/",
    )
    default_institution = "Yerel Yönetim"
    default_kpss = True
    max_age_days = 45

    def wants_details(self) -> bool:
        return True

    def parse_list(self, html: str, page_url: str) -> list[Listing]:
        soup = BeautifulSoup(html, "lxml")
        out: list[Listing] = []
        for a in soup.select("a.duyurular-second-card-wrapper"):
            date_el, title_el = a.select_one(".date"), a.find("p")
            raw = clean(title_el.get_text(" ")) if title_el else ""
            if not raw or not is_hiring_title(raw):
                continue  # iptal, sonuç, giriş belgesi vb. alınmaz
            dates = find_dates(date_el.get_text(" ")) if date_el else []
            url = urljoin(page_url, a["href"])
            idm = _ID.search(url.rstrip("/"))
            info = parse_title(raw)
            parts = [info["institution"] or self.default_institution]
            role = info["role"] or ("Sözleşmeli Personel" if info["sozlesmeli"] else None)
            title = f"{parts[0]} — {role} Alımı" if role else tr_title(raw)
            if info["correction"]:
                title += " (Düzeltme)"
            out.append(Listing(
                # NOT: Python'un hash()'i her çalıştırmada farklıdır; kimlik kalıcı olmalı (sha1 tabanlı).
                external_id=f"yy-{idm.group(1)}" if idm else f"yy-{stable_id(self.key, url)}",
                title=title[:300],
                institution=parts[0],
                url=url,
                city=info["city"],
                description=raw,
                departments=[role] if role else [],
                published_at=dates[0] if dates else None,
                kpss_required=True,
            ))
        return out

    def enrich(self, item: Listing, html: str) -> None:
        """Detay sayfasından yalnızca son başvuru tarihini alır (sayfada çok menü metni vardır;
        başka alan okumak yanlış veri getirir)."""
        text = clean(BeautifulSoup(html, "lxml").get_text(" "))
        item.application_end = find_application_end(text, item.published_at)
