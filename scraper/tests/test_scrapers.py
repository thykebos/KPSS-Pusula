import unittest
from datetime import datetime
from pathlib import Path

from http_client import RobotsDisallowed
from scrapers import SOURCES
from scrapers.base import detect_kpss, is_hiring_title
from scrapers.pgm_adalet import PgmAdaletScraper
from scrapers.sources import IskurScraper, KariyerKapisiScraper
from scrapers.yerelyonetimler import YerelYonetimlerScraper, parse_title
from text_utils import TR_TZ

FIX = Path(__file__).parent / "fixtures"
NOW = datetime(2026, 10, 15, tzinfo=TR_TZ)  # testler için sabit "şimdi"


def fx(name):
    return (FIX / name).read_text(encoding="utf-8")


class FakeFetcher:
    def __init__(self, pages, blocked=()):
        self.pages, self.blocked, self.calls = pages, set(blocked), []

    def get(self, url, render=False):
        self.calls.append((url, render) if render else url)
        if url in self.blocked:
            raise RobotsDisallowed(url)
        if url not in self.pages:
            raise RuntimeError("404 " + url)
        return self.pages[url]


class FilterTest(unittest.TestCase):
    def test_titles(self):
        self.assertTrue(is_hiring_title("150 zabıt katibi alım ilanı"))
        self.assertFalse(is_hiring_title("Sözleşmeli personel alımının sözlü sınav sonuçları"))
        self.assertFalse(is_hiring_title("Sistem Test İlanıdır #2"))
        self.assertFalse(is_hiring_title("İletişim ve ilan bilgileri"))
        self.assertFalse(is_hiring_title("Hakkımızda"))
        self.assertFalse(is_hiring_title("2026 YILI KPSS MERKEZİ YERLEŞTİRME TAKVİMİ"))
        self.assertFalse(is_hiring_title("Hukuk mesleklerine giriş sınavı ve idari yargı ön sınavı ilanı"))
        self.assertFalse(is_hiring_title("RİZE BELEDİYESİ SÖZLEŞMELİ PERSONEL ( Tekniker ) ALIM İPTAL İLANI"))
        self.assertFalse(is_hiring_title("Yerel yönetimler personeli GYS sınav giriş belgeleri sayfası aktif"))
        self.assertTrue(is_hiring_title("Edirne Keşan Belediye Başkanlığına ilk defa atanmak üzere memur alım ilanı"))
        self.assertTrue(is_hiring_title("Kamu personel ilanı"))

    def test_kpss_detection(self):
        self.assertFalse(detect_kpss("Sürekli işçi alımı (KPSS'siz)", True))
        self.assertFalse(detect_kpss("KPSS şartı aranmaz", True))
        self.assertTrue(detect_kpss("KPSS-2026/5 puanı ile", False))
        self.assertFalse(detect_kpss("İşçi alımı", False))
        self.assertTrue(detect_kpss("Memur alımı", True))


class PgmTest(unittest.TestCase):
    def setUp(self):
        self.base = "https://pgm.adalet.gov.tr"
        self.pages = {u: fx("pgm_list.html") for u in PgmAdaletScraper.list_urls}
        self.detail = f"{self.base}/Home/SayfaDetay/adli-yargi-zabit-katibi-alim-ilani-05102026101500"
        self.pages[self.detail] = fx("pgm_detail.html")

    def test_list_filters_results_and_nav(self):
        items = PgmAdaletScraper(FakeFetcher(self.pages)).parse_list(fx("pgm_list.html"), self.base + "/")
        self.assertEqual([i.title[:19] for i in items], ["Adli yargı adalet k"])
        it = items[0]
        self.assertEqual(it.external_id, "adli-yargi-zabit-katibi-alim-ilani-05102026101500")
        self.assertEqual((it.published_at.month, it.published_at.day), (10, 5))
        self.assertEqual(it.url, self.detail)

    def test_scrape_enriches_and_dedupes(self):
        ff = FakeFetcher(self.pages)
        ref = datetime(2026, 10, 14, tzinfo=TR_TZ)
        res = PgmAdaletScraper(ff).scrape(now=NOW)
        self.assertEqual(len(res), 1)  # iki liste sayfasında da aynı ilan: tek kayıt
        it = res[0]
        self.assertEqual(it.qualification_codes, ["3121", "3122"])
        self.assertEqual(it.education_levels, ["lisans"])
        self.assertEqual((it.application_end.month, it.application_end.day), (10, 16))
        self.assertEqual(it.city, "Ankara")
        self.assertTrue(it.kpss_required)
        self.assertEqual(ff.calls.count(self.detail), 1)

    def test_known_ids_skip_detail_fetch(self):
        ff = FakeFetcher(self.pages)
        PgmAdaletScraper(ff).scrape(now=NOW, known_ids={"adli-yargi-zabit-katibi-alim-ilani-05102026101500"})
        self.assertNotIn(self.detail, ff.calls)

    def test_row_shape(self):
        it = PgmAdaletScraper(FakeFetcher(self.pages)).scrape(now=NOW)[0]
        row = it.to_row("pgm_adalet")
        self.assertEqual(row["source"], "pgm_adalet")
        for k in ("title", "institution", "url", "external_id", "kpss_required", "published_at"):
            self.assertTrue(row[k] not in (None, ""), k)


class YerelTest(unittest.TestCase):
    def scrape(self, now=NOW):
        pages = {u: fx("yerel_duyurular.html") for u in YerelYonetimlerScraper.list_urls}
        return YerelYonetimlerScraper(FakeFetcher(pages)).scrape(now=now)

    def test_only_current_hiring_announcements_from_real_page(self):
        res = self.scrape()
        # gerçek sayfada 10 duyuru var: 4 Rize iptal ilanı elenir, 6 alım/düzeltme ilanı kalır
        self.assertEqual(len(res), 6)
        self.assertTrue(all("İptal" not in r.title for r in res))
        self.assertEqual(len({r.external_id for r in res}), 6)  # iki sayfada da aynı kartlar: tekilleşir
        top = res[0]
        self.assertEqual(top.external_id, "yy-478164")
        self.assertEqual(top.title, "Sarıidris Belediye Başkanlığı — Zabıta Memuru Alımı")
        self.assertEqual((top.city, top.published_at.day, top.published_at.month), ("Isparta", 9, 10))
        self.assertTrue(top.url.endswith("-duyuru-478164"))

    def test_news_and_menu_links_are_ignored(self):
        titles = " ".join(r.title for r in self.scrape()).lower()
        self.assertNotIn("kpss merkezi", titles)
        self.assertNotIn("faaliyet", titles)
        self.assertNotIn("alım izni", titles)

    def test_old_announcements_dropped(self):
        late = datetime(2026, 12, 20, tzinfo=TR_TZ)  # 45 günden eski
        self.assertEqual(self.scrape(now=late), [])

    def test_title_parsing(self):
        p = parse_title("EDİRNE İLİ KEŞAN BELEDİYE BAŞKANLIĞINA İLK DEFA ATANMAK ÜZERE MEMUR ALIM İLANI")
        self.assertEqual((p["city"], p["institution"], p["role"]), ("Edirne", "Keşan Belediye Başkanlığı", "Memur"))
        p = parse_title("RİZE BELEDİYESİ İLK DEFA SÖZLEŞMELİ PERSONEL ( Jeoloji  Mühendisi  ) ALIM İLANI")
        self.assertEqual((p["city"], p["institution"], p["role"]), ("Rize", "Rize Belediyesi", "Jeoloji Mühendisi"))


class GenericTest(unittest.TestCase):
    def run_source(self, cls, url=None):
        url = url or cls.list_urls[0]
        return cls(FakeFetcher({url: fx("generic_list.html")})).scrape(now=NOW)

    def test_filters_nav_test_and_expired(self):
        res = self.run_source(KariyerKapisiScraper)
        titles = [r.title for r in res]
        self.assertEqual(titles, ["Bursa Büyükşehir Belediyesi 25 sürekli işçi alım ilanı"])
        r = res[0]
        self.assertEqual(r.city, "Bursa")
        self.assertEqual(r.positions_count, 25)
        self.assertEqual((r.application_end.month, r.application_end.day), (10, 20))
        self.assertEqual(r.url, "https://kariyerkapisi.cbiko.gov.tr/ilan/101")
        self.assertIn("Belediyesi", r.institution)

    def test_kpss_default_per_source(self):
        self.assertFalse(self.run_source(IskurScraper)[0].kpss_required)
        self.assertTrue(self.run_source(KariyerKapisiScraper)[0].kpss_required)

    def test_robots_disallowed_is_skipped(self):
        url = YerelYonetimlerScraper.list_urls[0]
        res = YerelYonetimlerScraper(FakeFetcher({}, blocked=[url])).scrape(now=NOW)
        self.assertEqual(res, [])

    def test_js_fallback_when_static_html_has_no_listings(self):
        class Dual(FakeFetcher):
            def get(self, url, render=False):
                self.calls.append((url, render))
                return fx("generic_list.html") if render else "<html><body><div id='app'></div></body></html>"

        ff = Dual({})
        res = KariyerKapisiScraper(ff).scrape(now=NOW)
        self.assertEqual(len(res), 1)
        self.assertEqual([r for _, r in ff.calls], [False, True])

    def test_needs_js_source_renders_directly(self):
        class Dual(FakeFetcher):
            def get(self, url, render=False):
                self.calls.append((url, render))
                return fx("generic_list.html")

        ff = Dual({})
        IskurScraper(ff).scrape(now=NOW)
        self.assertEqual(ff.calls, [(IskurScraper.list_urls[0], True)])

    def test_fetch_error_does_not_crash(self):
        self.assertEqual(IskurScraper(FakeFetcher({})).scrape(), [])

    def test_registry_matches_enum(self):
        self.assertEqual(set(SOURCES), {"kariyerkapisi", "yerelyonetimler", "pgm_adalet", "kamuilan", "iskur"})


if __name__ == "__main__":
    unittest.main()
