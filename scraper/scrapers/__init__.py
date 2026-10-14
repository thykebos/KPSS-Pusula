"""Kaynak kaydı: `--source` anahtarı -> sınıf."""
from __future__ import annotations

from .base import BaseScraper
from .pgm_adalet import PgmAdaletScraper
from .sources import IskurScraper, KamuIlanScraper, KariyerKapisiScraper, YerelYonetimlerScraper

SOURCES: dict[str, type[BaseScraper]] = {
    cls.key: cls
    for cls in (
        KariyerKapisiScraper,
        YerelYonetimlerScraper,
        PgmAdaletScraper,
        KamuIlanScraper,
        IskurScraper,
    )
}
