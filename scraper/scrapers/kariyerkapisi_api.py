"""Kariyer Kapısı "İş e-Alım" (kariyerkapisi.gov.tr/isealim) — JSON API tabanlı.

Sayfa JavaScript ile oluşur ve ilanları şu API'den alır (giriş gerektirmez):
    POST https://api.kariyerkapisi.gov.tr/api/ilan/GetIseAlimPage
    gövde: {"krM_ID": 0, "searchText": "", "il": "0", "ilanTuru": "0"}   (hepsi = filtresiz)
Yanıttaki `searchIlan` listesi ilan kayıtlarını içerir (guid, kurumAdi, ilanBaslik, ilanTuru, basTarih, bitTarih,
onayDate, basvuruLinki ...). HTML'de bağlantı aranmaz, tarayıcı (Playwright) gerekmez.

İlan bağlantısı RSS beslemesiyle aynı biçimdedir: https://kariyerkapisi.gov.tr/IlanDetay?i=<guid>
(RSS'teki ilan kimliği API'deki `guid` ile aynıdır; dedup.py bu sayede iki kaynaktaki aynı ilanı tek sayar).
"""
from __future__ import annotations

import logging
import re
from datetime import datetime
from typing import Iterable

from http_client import RobotsDisallowed
from text_utils import TR_TZ, clean, extract_city, extract_positions

from .base import BaseScraper, Listing, detect_kpss

logger = logging.getLogger("scraper")

API_URL = "https://api.kariyerkapisi.gov.tr/api/ilan/GetIseAlimPage"
PAGE_URL = "https://kariyerkapisi.gov.tr/isealim"
DETAIL_URL = "https://kariyerkapisi.gov.tr/IlanDetay?i={guid}"
_PAYLOAD = {"krM_ID": 0, "searchText": "", "il": "0", "ilanTuru": "0"}

_ISO = re.compile(r"(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?")


def parse_api_date(value: str | None) -> datetime | None:
    """"2026-10-18T23:59:00" -> 18.10.2026 23:59 (Türkiye saati).
    API saat dilimi vermez, değerler Türkiye saatidir; sunucunun yerel saat dilimi KULLANILMAZ
    (GitHub çalıştırıcıları UTC'dedir, yerel saate göre yorumlamak bitiş saatini 3 saat kaydırırdı).
    Kesirli saniye ve Python sürümü farklarından etkilenmemek için elle ayrıştırılır."""
    m = _ISO.match(value or "")
    if not m:
        return None
    y, mo, d, h, mi, s = (int(x or 0) for x in m.groups())
    try:
        return datetime(y, mo, d, h, mi, s, tzinfo=TR_TZ)
    except ValueError:
        return None


class KariyerKapisiIsealimScraper(BaseScraper):
    key = "kariyerkapisi_isealim"
    name = "Kariyer Kapısı (İş e-Alım)"
    list_urls: tuple[str, ...] = (PAGE_URL,)   # yalnızca raporlama/robots için; veri API'den gelir
    default_institution = "Kariyer Kapısı"
    default_kpss = True
    needs_js = False
    js_fallback = False

    def scrape(self, known_ids: Iterable[str] = (), now: datetime | None = None) -> list[Listing]:
        now = now or datetime.now(TR_TZ)
        try:
            data = self.fetcher.post_json(API_URL, _PAYLOAD, robots_url=PAGE_URL)
        except RobotsDisallowed:
            logger.warning("%s: %s robots.txt ile yasak; atlandı.", self.name, PAGE_URL)
            return []
        except Exception as e:  # noqa: BLE001 - kaynak hatası diğer kaynakları durdurmasın
            logger.error("%s: API isteği başarısız: %s", self.name, e)
            return []

        records = data.get("searchIlan") if isinstance(data, dict) else None
        if not isinstance(records, list):
            logger.warning("%s: API yanıtında 'searchIlan' listesi yok (API değişmiş olabilir).", self.name)
            return []

        items: dict[str, Listing] = {}
        for rec in records:
            try:
                it = self._parse_record(rec, now)
            except Exception as e:  # noqa: BLE001 - tek kaydın hatası diğerlerini durdurmasın
                logger.warning("%s: kayıt okunamadı: %s", self.name, e)
                continue
            if it:
                items.setdefault(it.external_id, it)

        fresh = [i for i in items.values() if self._is_current(i, now)]
        logger.info("%s: %s -> %d aday ilan", self.name, PAGE_URL, len(fresh))
        if len(fresh) < len(items):
            logger.info("%s: %d eski/süresi dolmuş ilan atlandı.", self.name, len(items) - len(fresh))
        return sorted(fresh, key=lambda i: i.published_at or now, reverse=True)

    def _parse_record(self, rec: dict, now: datetime) -> Listing | None:
        guid = clean(rec.get("guid")).lower()
        title = clean(rec.get("ilanBaslik"))
        if not guid or not title:
            return None
        institution = clean(rec.get("kurumAdi")) or self.default_institution
        # "KURUM - ilan başlığı" -> kurum adı zaten ayrı alanda
        prefix = f"{institution} - "
        if title.upper().startswith(prefix.upper()):
            title = title[len(prefix):]

        ilan_type = clean(rec.get("ilanTuru")).strip(" ,")
        unit = clean(rec.get("birimAdi"))
        context = " · ".join(p for p in (ilan_type, unit) if p)

        start = parse_api_date(rec.get("basTarih"))
        end = parse_api_date(rec.get("bitTarih"))
        # Yayın tarihi: sistemde onaylandığı an (yoksa başvuru başlangıcı); gelecekte olamaz.
        published = parse_api_date(rec.get("onayDate")) or start
        if published and published > now:
            published = now

        return Listing(
            external_id=guid,
            title=title[:300],
            institution=institution[:120],
            url=DETAIL_URL.format(guid=guid),
            city=extract_city(f"{institution} {title}"),
            description=context[:500] or None,
            positions_count=extract_positions(title),
            application_start=start,
            application_end=end,
            published_at=published,
            kpss_required=detect_kpss(f"{title} {ilan_type}", self.default_kpss),
        )
