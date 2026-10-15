"""Genel bağlantı toplama yöntemiyle çalışan kaynaklar.

UYARI: Bu sitelerin gerçek HTML'i geliştirme ortamından doğrulanamadı. İlk çalıştırmada
`python run.py --source <anahtar> --dry-run --debug-dir debug` ile bulunanları ve kaydedilen
ham sayfaları kontrol et; gerekirse `list_urls` ya da süzgeçleri bu dosyada ayarla.
"""
from __future__ import annotations

from .base import AnchorListScraper


class KariyerKapisiScraper(AnchorListScraper):
    key = "kariyerkapisi"
    name = "Kariyer Kapısı"
    list_urls = ("https://kariyerkapisi.gov.tr/",)
    default_institution = "Cumhurbaşkanlığı Kariyer Kapısı"
    default_kpss = True


class KamuIlanScraper(AnchorListScraper):
    """KPSS'siz alımlar."""
    key = "kamuilan"
    name = "Kamu İlan (SBB)"
    list_urls = ("https://kamuilan.sbb.gov.tr/",)
    default_institution = "Kamu Kurumu"
    default_kpss = False


class IskurScraper(AnchorListScraper):
    """KPSS'siz kurum dışı kamu işçi alımları. Genel 'Açık İşler' (özel sektör) taranmaz."""
    key = "iskur"
    name = "İŞKUR (kamu işçi alımı)"
    list_urls = ("https://iskur.gov.tr/ilanlar/kurumdisi-kamu-isci-alim-ilanlari/",)
    default_institution = "İŞKUR"
    default_kpss = False
    needs_js = True  # ilan listesi sayfa metninde yok; tarayıcıyla oluşturulur (il filtresi + liste)
