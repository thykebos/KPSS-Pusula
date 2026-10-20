"""Resmî Gazete kaynağı testleri.

NOT: Günlük sayfanın iç HTML'i gerçek siteden doğrulanamadığı için burada KURGUSAL ama adres
biçimleri gerçek olan sayfalar kullanılır (/eskiler/YYYY/MM/YYYYMMDD.htm, /ilanlar/eskiilanlar/...pdf).
PDF'ler elle üretilmiş gerçek PDF dosyalarıdır; pypdf ile metin çıkarma zinciri uçtan uca denenir.
"""
import importlib.util
import json
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

from http_client import Fetcher, RobotsDisallowed
from scrapers.resmigazete import (
    ResmiGazeteScraper, classify_ilan, daily_url, guess_institution, looks_public, pdf_text,
)
from text_utils import TR_TZ, fold_tr

NOW = datetime(2026, 10, 16, 12, 0, tzinfo=TR_TZ)
HAS_PYPDF = importlib.util.find_spec("pypdf") is not None

BASE = "https://www.resmigazete.gov.tr"
D16, D15 = daily_url(NOW), daily_url(datetime(2026, 10, 15, tzinfo=TR_TZ))
P = f"{BASE}/ilanlar/eskiilanlar/2026/10"


def make_pdf(text: str) -> bytes:
    """Tek sayfalık, yalnızca ASCII metin içeren geçerli bir PDF üretir (parantez kullanmayın)."""
    stream = f"BT /F1 12 Tf 20 750 Td ({text}) Tj ET".encode("latin-1")
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
        b"/Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    out, offsets = b"%PDF-1.4\n", []
    for i, obj in enumerate(objs, 1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + obj + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    return out


KILIS = ("KILIS 7 ARALIK UNIVERSITESI REKTORLUGU Ogretim Uyesi alim ilani. Universitemiz bunyesinde "
         "istihdam edilmek uzere Doktor Ogretim Uyesi alinacaktir. Son basvuru tarihi 30.10.2026.")
ANKARA = ("ANKARA BUYUKSEHIR BELEDIYESI Sozlesmeli Personel alimi yapilacaktir. Lisans mezunu adaylar "
          "icin KPSS P3 puan turunden en az 60 puan aranir. Son basvuru tarihi 20.10.2026.")
IPTAL = "ALTINDAG BELEDIYESI Sozlesmeli Personel alim ilani iptal edilmistir."
GENEL = "Sayin ilgili Mahkeme kararina istinaden bilgi alinacaktir."

DAILY = f"""<html><body>
<a href="/ilanlar/eskiilanlar/2026/10/20261016-4-1.pdf">Kilis 7 Aralık Üniversitesi Rektörlüğünden</a>
<a href="/ilanlar/eskiilanlar/2026/10/20261016-4-2.pdf">Ankara 5. İcra Müdürlüğünden</a>
<a href="/ilanlar/eskiilanlar/2026/10/20261016-4-3.pdf">Ankara Büyükşehir Belediye Başkanlığından</a>
<a href="/ilanlar/eskiilanlar/2026/10/20261016-4-4.pdf">Altındağ Belediye Başkanlığından</a>
<a href="/ilanlar/eskiilanlar/2026/10/20261016-4-5.pdf">İlan</a>
<a href="/yonetmelikler/x.htm">Bir yönetmelik</a>
</body></html>"""

FILES = {
    f"{P}/20261016-4-1.pdf": make_pdf(KILIS),
    f"{P}/20261016-4-2.pdf": make_pdf("Icra dairesi ilani"),
    f"{P}/20261016-4-3.pdf": make_pdf(ANKARA),
    f"{P}/20261016-4-4.pdf": make_pdf(IPTAL),
    f"{P}/20261016-4-5.pdf": make_pdf(GENEL),
}


class RgFetcher:
    def __init__(self, pages, files=None):
        self.pages, self.files, self.page_calls, self.byte_calls = pages, files or {}, [], []

    def get(self, url, render=False):
        self.page_calls.append(url)
        if url not in self.pages:
            raise RuntimeError("404 " + url)
        return self.pages[url]

    def get_bytes(self, url, **_):
        self.byte_calls.append(url)
        if url not in self.files:
            raise RuntimeError("404 " + url)
        return self.files[url]


def scraper(fetcher, **attrs):
    s = ResmiGazeteScraper(fetcher, now=NOW)
    s.cache_file = None
    for k, v in attrs.items():
        setattr(s, k, v)
    return s


class ClassifyTest(unittest.TestCase):
    def test_hiring_kinds(self):
        self.assertEqual(classify_ilan(KILIS), "Öğretim Elemanı Alım İlanı")
        self.assertEqual(classify_ilan(ANKARA), "Sözleşmeli Personel Alım İlanı")
        self.assertEqual(classify_ilan("X Belediyesi 25 surekli isci alinacaktir"), "İşçi Alım İlanı")

    def test_rejects(self):
        self.assertIsNone(classify_ilan(IPTAL))
        self.assertIsNone(classify_ilan("Kilis Universitesi personel alim ilaninin basvuru tarihleri ertelenmistir"))
        self.assertIsNone(classify_ilan("Belediyesi Sozlesmeli Personel alim ilani sonuclari"))
        self.assertIsNone(classify_ilan(GENEL))  # "alinacak" var ama kadro/personel ipucu yok

    def test_result_word_in_body_does_not_reject(self):
        body = ANKARA + " " + "x " * 400 + "Sonuclar internet sitesinden ilan edilecektir."
        self.assertEqual(classify_ilan(body), "Sözleşmeli Personel Alım İlanı")

    def test_institution(self):
        self.assertEqual(guess_institution("T.C. KİLİS 7 ARALIK ÜNİVERSİTESİ Rektörlüğünden"),
                         "Kilis 7 Aralık Üniversitesi")
        # PDF örneği yalnızca ASCII içerir (büyük I -> ı olur); harf biçimine bakmadan karşılaştır.
        self.assertEqual(fold_tr(guess_institution(ANKARA)), "ankara buyuksehir belediyesi")
        self.assertIsNone(guess_institution("Sayin ilgili"))

    def test_prefilter(self):
        self.assertTrue(looks_public("Kilis 7 Aralık Üniversitesi Rektörlüğünden"))
        self.assertFalse(looks_public("Ankara 5. İcra Müdürlüğünden"))
        self.assertFalse(looks_public("Ankara 3. Asliye Hukuk Mahkemesi Başkanlığından"))


@unittest.skipUnless(HAS_PYPDF, "pypdf kurulu değil")
class PdfTest(unittest.TestCase):
    def test_pdf_text_roundtrip(self):
        self.assertIn("Ogretim Uyesi", pdf_text(make_pdf(KILIS)))

    def test_bad_pdf_returns_empty(self):
        self.assertEqual(pdf_text(b"bu bir pdf degil"), "")


@unittest.skipUnless(HAS_PYPDF, "pypdf kurulu değil")
class ScrapeTest(unittest.TestCase):
    def test_list_urls_are_today_and_yesterday(self):
        s = scraper(RgFetcher({}))
        self.assertEqual(s.list_urls, (D16, D15))
        self.assertEqual(D16, "https://www.resmigazete.gov.tr/eskiler/2026/10/20261016.htm")

    def test_full_flow_with_pdfs(self):
        ff = RgFetcher({D16: DAILY}, FILES)  # dünkü sayfa yok (404) -> hata loglanır, tarama sürer
        res = scraper(ff).scrape(now=NOW)
        by_inst = {fold_tr(r.institution): r for r in res}
        self.assertEqual(set(by_inst), {"kilis 7 aralik universitesi", "ankara buyuksehir belediyesi"})

        kilis = by_inst["kilis 7 aralik universitesi"]
        self.assertEqual(fold_tr(kilis.title), "kilis 7 aralik universitesi — ogretim elemani alim ilani")
        self.assertEqual(kilis.city, "Kilis")
        self.assertFalse(kilis.kpss_required)
        self.assertEqual(kilis.application_end.strftime("%d.%m.%Y"), "30.10.2026")
        self.assertEqual(kilis.published_at.strftime("%d.%m.%Y"), "16.10.2026")
        self.assertTrue(kilis.url.endswith("/20261016-4-1.pdf"))

        ank = by_inst["ankara buyuksehir belediyesi"]
        self.assertTrue(ank.kpss_required)
        self.assertEqual(ank.city, "Ankara")
        self.assertEqual(ank.education_levels, ["lisans"])

        # İcra ilanı başlığından elendi: PDF'i hiç indirilmedi. Diğerleri okundu.
        self.assertNotIn(f"{P}/20261016-4-2.pdf", ff.byte_calls)
        self.assertEqual(len(ff.byte_calls), 4)

    def test_quota_leaves_unchecked_items_out(self):
        res = scraper(RgFetcher({D16: DAILY}, FILES), max_details=1).scrape(now=NOW)
        # Yalnızca açılan tek PDF doğrulanabilir; doğrulanmayanlar asla veritabanına gitmez.
        self.assertLessEqual(len(res), 1)

    def test_known_items_are_not_reopened(self):
        ff = RgFetcher({D16: DAILY}, FILES)
        first = scraper(ff).scrape(now=NOW)
        ff2 = RgFetcher({D16: DAILY}, FILES)
        again = scraper(ff2).scrape(known_ids=[r.external_id for r in first], now=NOW)
        self.assertEqual(len(ff2.byte_calls), 2)  # yalnızca bilinmeyen ve reddedilen 2 aday yeniden açıldı
        self.assertEqual({r.external_id for r in again}, {r.external_id for r in first})

    def test_rejected_cache_prevents_redownload(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = str(Path(tmp) / "sub" / "rejected.json")
            ff = RgFetcher({D16: DAILY}, FILES)
            scraper(ff, cache_file=cache).scrape(now=NOW)
            self.assertTrue(Path(cache).exists())
            self.assertEqual(len(json.loads(Path(cache).read_text())), 2)  # IPTAL ve GENEL reddedildi

            ff2 = RgFetcher({D16: DAILY}, FILES)
            res = scraper(ff2, cache_file=cache).scrape(now=NOW)
            self.assertEqual(len(ff2.byte_calls), 2)  # yalnızca kabul edilenler yeniden açıldı
            self.assertEqual(len(res), 2)

    def test_follows_html_pages_when_daily_has_no_pdf(self):
        daily = f'<html><body><a href="/ilanlar/eskiilanlar/2026/10/20261016-4.htm">Diğer İlanlar</a></body></html>'
        group = ('<html><body><a href="/ilanlar/eskiilanlar/2026/10/20261016-4-1.pdf">'
                 "Kilis 7 Aralık Üniversitesi Rektörlüğünden</a></body></html>")
        pages = {D16: daily, f"{P}/20261016-4.htm": group}
        res = scraper(RgFetcher(pages, FILES)).scrape(now=NOW)
        self.assertEqual([fold_tr(r.institution) for r in res], ["kilis 7 aralik universitesi"])

    def test_html_page_without_pdf_is_the_listing_itself(self):
        daily = '<html><body><a href="/ilanlar/eskiilanlar/2026/10/20261016-7.htm">Diğer</a></body></html>'
        page = f"<html><head><title>Resmî Gazete</title></head><body><p>{KILIS}</p></body></html>"
        pages = {D16: daily, f"{P}/20261016-7.htm": page}
        res = scraper(RgFetcher(pages)).scrape(now=NOW)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0].url, f"{P}/20261016-7.htm")
        self.assertEqual(res[0].city, "Kilis")


class FetcherBytesTest(unittest.TestCase):
    class Resp:
        def __init__(self, status=200, content=b"%PDF", headers=None, text=""):
            self.status_code, self.content, self.headers, self.text = status, content, headers or {}, text

        def raise_for_status(self):
            if self.status_code >= 400:
                import requests
                raise requests.HTTPError(str(self.status_code))

        def close(self):
            pass

    class Session:
        def __init__(self, robots, file_resp):
            self.headers, self.robots, self.file_resp, self.urls = {}, robots, file_resp, []

        def get(self, url, timeout=None, stream=False):
            self.urls.append(url)
            return self.robots if url.endswith("/robots.txt") else self.file_resp

    def make(self, robots_text="", file_resp=None):
        robots = self.Resp(200, text=robots_text)
        s = self.Session(robots, file_resp or self.Resp())
        return Fetcher(delay=0, session=s), s

    def test_returns_bytes(self):
        f, _ = self.make()
        self.assertEqual(f.get_bytes("https://x.gov.tr/a.pdf"), b"%PDF")

    def test_disallowed_does_not_request_file(self):
        f, s = self.make("User-agent: *\nDisallow: /")
        with self.assertRaises(RobotsDisallowed):
            f.get_bytes("https://x.gov.tr/a.pdf")
        self.assertEqual(s.urls, ["https://x.gov.tr/robots.txt"])

    def test_too_large_is_rejected(self):
        f, _ = self.make(file_resp=self.Resp(headers={"Content-Length": "9000000"}))
        with self.assertRaises(ValueError):
            f.get_bytes("https://x.gov.tr/a.pdf")


if __name__ == "__main__":
    unittest.main()
