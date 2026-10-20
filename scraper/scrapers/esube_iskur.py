"""İŞKUR e-Şube "Açık İş İlanları" (esube.iskur.gov.tr) — yalnızca kamu alımları.

Bu sayfa özel sektör ilanlarını da listeler; bu yüzden başlık/bağlam kamu kurumu ipuçlarıyla
süzülür. Sayfa ASP.NET formu olduğundan tarayıcıyla (render) açılır.

UYARI: HTML yapısı geliştirme ortamından doğrulanamadı. İlk çalıştırmada GitHub Actions
"discover" modunu ya da yerelde `--dry-run --debug-dir debug` kullanıp sonucu kontrol et.
"""
from __future__ import annotations

import re

from text_utils import fold_tr
from .base import AnchorListScraper, Listing

# Kamu kurumu ipuçları (fold_tr ile: küçük harf, Türkçe karakter yok)
_PUBLIC_HINT = re.compile(
    r"kamu|belediye|bakanlik|mudurlugu|universite|valilik|kaymakamlik|kurum|hastane|baskanlik"
)


class IskurEsubeScraper(AnchorListScraper):
    key = "iskur_esube"
    name = "İŞKUR e-Şube (kamu alımları)"
    list_urls = ("https://esube.iskur.gov.tr/Istihdam/AcikIsIlanAra.aspx",)
    default_institution = "İŞKUR"
    default_kpss = False
    needs_js = True

    def parse_list(self, html: str, page_url: str) -> list[Listing]:
        found = super().parse_list(html, page_url)
        return [it for it in found if _PUBLIC_HINT.search(fold_tr(f"{it.title} {it.institution} {it.description or ''}"))]
