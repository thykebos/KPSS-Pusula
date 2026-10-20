"""Kaynak kaydı: `--source` anahtarı -> sınıf."""
from __future__ import annotations

from .base import BaseScraper
from .esube_iskur import IskurEsubeScraper
from .kariyerkapisi_api import KariyerKapisiIsealimScraper
from .pgm_adalet import PgmAdaletScraper
from .resmigazete import ResmiGazeteScraper
from .rss import KariyerKapisiScraper
from .sources import (
    IlanGovScraper, IskurScraper, KamuIlanScraper, SayistayScraper,
)
from .yerelyonetimler import YerelYonetimlerScraper

SOURCES: dict[str, type[BaseScraper]] = {
    cls.key: cls
    for cls in (
        KariyerKapisiScraper,
        KariyerKapisiIsealimScraper,
        YerelYonetimlerScraper,
        PgmAdaletScraper,
        KamuIlanScraper,
        IskurScraper,
        IlanGovScraper,
        SayistayScraper,
        IskurEsubeScraper,
        ResmiGazeteScraper,
    )
}
