"""Genel bağlantı toplama yöntemiyle çalışan kaynaklar.

UYARI: Bu sitelerin gerçek HTML'i geliştirme ortamından doğrulanamadı. İlk çalıştırmada
`python run.py --source <anahtar> --dry-run --debug-dir debug` ile bulunanları ve kaydedilen
ham sayfaları kontrol et; gerekirse `list_urls` ya da süzgeçleri bu dosyada ayarla.
"""
from __future__ import annotations

import re

from .base import AnchorListScraper


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


class IlanGovScraper(AnchorListScraper):
    """ilan.gov.tr (Basın İlan Kurumu) "Personel Alımı ve İş İlanları" kategorisi.
    Kategori zaten yalnızca alım ilanı içerdiği için başlıkta alım kelimesi aranmaz; ilan bağlantıları
    `/ilan/<sayı>/<başlık>` biçimindedir (menü/kategori bağlantıları böylece elenir)."""
    key = "ilan_gov"
    name = "ilan.gov.tr (Personel Alımı)"
    list_urls = ("https://www.ilan.gov.tr/ilan/kategori/81/personel-alimi-ve-is-ilanlari",)
    default_institution = "Kamu Kurumu"
    default_kpss = True
    link_pattern = re.compile(r"/ilan/\d+")
    trust_titles = True


class SayistayScraper(AnchorListScraper):
    """Sayıştay duyuruları: alım ilanları genel duyurularla karışık olduğundan başlık süzgeci kullanılır.
    Duyurular sayfalara bölünmüş; ilk sayfa ve ilk 7 sayfa taranır (?page=N)."""
    key = "sayistay"
    name = "Sayıştay"
    list_urls = ("https://www.sayistay.gov.tr/Duyuru",) + tuple(
        f"https://www.sayistay.gov.tr/Duyuru?page={n}" for n in range(2, 8)
    )
    default_institution = "Sayıştay Başkanlığı"
    default_kpss = True


class KariyerKapisiIsealimScraper(AnchorListScraper):
    """Kariyer Kapısı "İş e-Alım" HTML sayfası (kariyerkapisi.gov.tr/isealim).

    UYARI: Bu sayfanın HTML'i geliştirme ortamından doğrulanamadı. Aynı "Kamu İşe Alım" ilanları
    RSS beslemesinden (KariyerKapisiScraper, kariyerkapisi kaynağı) da geliyor; bu yüzden aynı ilan
    iki kaynakta görünebilir. Tekrar görülürse bu sınıfı kayıttan çıkarın (scrapers/__init__.py).
    Kaynak anahtarı ayrı tutuldu ki RSS'teki "kk-<uuid>" kimlikleriyle karışmasın.
    """
    key = "kariyerkapisi_isealim"
    name = "Kariyer Kapısı (İş e-Alım)"
    list_urls = ("https://kariyerkapisi.gov.tr/isealim",)
    default_institution = "Cumhurbaşkanlığı Kariyer Kapısı"
    default_kpss = True
