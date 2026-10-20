import itertools
import json
import os
import subprocess
import sys
import unittest
from unittest import mock
from datetime import datetime, timedelta
from pathlib import Path

import run
from dedup import DuplicateIndex, drop_duplicates, make_signature, is_duplicate
from http_client import Fetcher, RobotsDisallowed
from scrapers.base import BaseScraper, Listing
from scrapers.kariyerkapisi_api import (
    API_URL, DETAIL_URL, PAGE_URL, KariyerKapisiIsealimScraper, parse_api_date,
)
from scrapers.rss import KariyerKapisiScraper
from text_utils import TR_TZ

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / "tests" / "fixtures"
ADALET = "f0ca8a29-559f-426a-ade5-5ed30651c618"


def tr(*a):
    return datetime(*a, tzinfo=TR_TZ)


class ApiFetcher:
    """post_json'u taklit eder; gerçek bir API yanıtından alınmış örnek kayıtları döndürür."""

    def __init__(self, data=None, error=None):
        self.data, self.error, self.calls = data, error, []

    def post_json(self, url, payload, retries=2, robots_url=None):
        self.calls.append((url, payload, robots_url))
        if self.error:
            raise self.error
        return self.data


def api_data():
    return json.loads((FIX / "kariyerkapisi_isealim_api.json").read_text(encoding="utf-8"))


class IsealimApiTest(unittest.TestCase):
    def scrape(self, now, fetcher=None):
        f = fetcher or ApiFetcher(api_data())
        return KariyerKapisiIsealimScraper(f).scrape(now=now), f

    def test_date_is_turkey_time_not_server_time(self):
        d = parse_api_date("2026-10-18T23:59:00")
        self.assertEqual((d.hour, d.minute, d.utcoffset()), (23, 59, timedelta(hours=3)))
        # 2 haneli kesirli saniye (eski Python sürümlerinde fromisoformat'ı bozardı) ve bozuk değerler
        self.assertEqual(parse_api_date("2026-09-23T19:05:55.87").minute, 5)
        self.assertIsNone(parse_api_date(None))
        self.assertIsNone(parse_api_date("yarın"))

    def test_expiry_uses_turkey_time(self):
        # Ankara Üniversitesi ilanı 19.10.2026 13:00'e kadar (Türkiye saati)
        ids = lambda now: {r.institution for r in self.scrape(now)[0]}  # noqa: E731
        self.assertIn("ANKARA ÜNİVERSİTESİ REKTÖRLÜĞÜ", ids(tr(2026, 10, 19, 12, 59)))
        self.assertNotIn("ANKARA ÜNİVERSİTESİ REKTÖRLÜĞÜ", ids(tr(2026, 10, 19, 13, 1)))

    def test_expired_listing_is_dropped(self):
        res, _ = self.scrape(tr(2026, 10, 19, 12, 0))
        self.assertEqual(len(res), 4)  # Çevre Bakanlığı ilanı 18.10'da bitti
        self.assertFalse(any("ÇEVRE" in r.institution for r in res))

    def test_fields(self):
        res, f = self.scrape(tr(2026, 10, 19, 12, 0))
        by = {r.external_id: r for r in res}
        ank = by["2ce03869-1a9d-44f3-a18e-fba394abe5aa"]
        self.assertEqual(ank.title, "SÖZLEŞMELİ PERSONEL İLANI 2026")  # kurum öneki atılır
        self.assertEqual(ank.url, DETAIL_URL.format(guid=ank.external_id))
        self.assertEqual(ank.city, "Ankara")
        self.assertEqual(by[ADALET].url, f"https://kariyerkapisi.gov.tr/IlanDetay?i={ADALET}")
        msb = by["39d5a688-3b17-48de-a123-9140f55af29e"]
        self.assertEqual(msb.description, "Askeri Personel İlanları · PERSONEL TEMİN DAİRE BAŞKANLIĞI")
        ika = by["c1ab5cba-d22b-40ab-b89b-1d27431a422c"]
        self.assertEqual(ika.positions_count, 5)
        # Başvuru gelecekte başlıyor (02.11) ama yayın tarihi gelecekte olamaz
        self.assertEqual(ika.application_start.day, 2)
        self.assertLessEqual(ika.published_at, tr(2026, 10, 19, 12, 0))
        # robots.txt sayfa için kontrol edilir, API doğru gövdeyle çağrılır
        self.assertEqual(f.calls, [(API_URL, {"krM_ID": 0, "searchText": "", "il": "0", "ilanTuru": "0"}, PAGE_URL)])

    def test_failures_return_empty(self):
        for f in (ApiFetcher(error=RobotsDisallowed(PAGE_URL)), ApiFetcher(error=RuntimeError("500")),
                  ApiFetcher({"baska": []}), ApiFetcher(None)):
            self.assertEqual(self.scrape(tr(2026, 10, 19), f)[0], [])


class DedupTest(unittest.TestCase):
    @staticmethod
    def sig(inst, title, end=None, url="", ext=""):
        return make_signature(institution=inst, title=title, application_end=end, url=url, external_id=ext)

    def test_same_ilan_with_institution_prefix_in_title(self):
        # İş e-Alım (kurum adı + "(BDDK)") ile RSS/sayfa (başlıkta kurum öneki) aynı ilanı farklı yazar
        a = self.sig("Bankacılık Düzenleme ve Denetleme Kurumu Başkanlığı",
                     "Sözleşmeli Bilişim Personeli Alım İlanı", tr(2026, 11, 2, 23, 59))
        b = self.sig("BANKACILIK DÜZENLEME VE DENETLEME KURUMU BAŞKANLIĞI (BDDK)",
                     "BANKACILIK DÜZENLEME VE DENETLEME KURUMU - SÖZLEŞMELİ BİLİŞİM PERSONELİ ALIM İLANI",
                     tr(2026, 11, 2, 23, 59))
        self.assertTrue(is_duplicate(a, b))
        c = self.sig("BDDK Başkanlığı", "Sözleşmeli Bilişim Personeli Alım İlanı", tr(2026, 11, 2, 9, 0))
        d = self.sig("BDDK Başkanlığı", "BDDK BAŞKANLIĞI - SÖZLEŞMELİ BİLİŞİM PERSONELİ ALIM İLANI",
                     tr(2026, 11, 2, 23, 59))
        self.assertTrue(is_duplicate(c, d))  # aynı gün, kurum öneki atılınca aynı başlık

    def test_shared_uuid_is_duplicate_even_if_everything_else_differs(self):
        rss = self.sig("Adalet Bakanlığı", "2026 Yılı Açıktan İcra Müdür ve İcra Müdür Yardımcılığı Sınav İlanı",
                       None, url=f"https://kariyerkapisi.gov.tr/IlanDetay?i={ADALET}", ext=f"kk-{ADALET}")
        api = self.sig("ADALET BAKANLIĞI", "Farklı bir başlık", tr(2026, 11, 5), url=DETAIL_URL.format(guid=ADALET),
                       ext=ADALET)
        self.assertTrue(is_duplicate(rss, api))

    def test_different_ilans_are_kept(self):
        end = tr(2026, 11, 5, 23, 59)
        base = self.sig("Düzce Üniversitesi Rektörlüğü", "2026 / 3 Sözleşmeli Personel Alım İlanı", end)
        self.assertFalse(is_duplicate(base, self.sig("Düzce Üniversitesi Rektörlüğü",
                                                     "2026 / 4 Sözleşmeli Personel Alım İlanı", end)))  # dönem no
        self.assertFalse(is_duplicate(base, self.sig("Düzce Üniversitesi Rektörlüğü",
                                                     "2026 / 3 Sözleşmeli Personel Alım İlanı",
                                                     tr(2026, 11, 6, 23, 59))))                          # başka gün
        self.assertFalse(is_duplicate(base, self.sig("Batman Üniversitesi Rektörlüğü",
                                                     "2026 / 3 Sözleşmeli Personel Alım İlanı", end)))   # başka kurum
        self.assertFalse(is_duplicate(base, self.sig("Düzce Üniversitesi Rektörlüğü",
                                                     "Öğretim Görevlisi Alım İlanı", end)))              # başka ilan
        # Aynı başlık, aynı gün, "Kalkınma Ajansı" ortak ama ajans farklı
        self.assertFalse(is_duplicate(self.sig("İstanbul Kalkınma Ajansı", "Personel Alım İlanı 5 Uzman", end),
                                      self.sig("Mevlana Kalkınma Ajansı", "Personel Alım İlanı 5 Uzman", end)))

    def test_db_rows_with_iso_strings(self):
        idx = DuplicateIndex()
        idx.add_rows([{"external_id": "yy-1", "institution": "Keçiören Belediyesi",
                       "title": "Keçiören Belediyesi — Zabıta Memuru Alımı",
                       "application_end": "2026-11-05T20:59:00+00:00", "url": "https://x/1"}])
        new = Listing(external_id="yy-999", title="Keçiören Belediyesi — Zabıta Memuru Alımı",
                      institution="Keçiören Belediyesi", url="https://x/2", application_end=tr(2026, 11, 5, 23, 59))
        kept, dropped = drop_duplicates([new], idx)
        self.assertEqual((kept, len(dropped)), ([], 1))   # kimlik farklı olsa da aynı ilan

    def test_batch_and_cross_source_duplicates_added_once(self):
        mk = lambda ext, url: Listing(external_id=ext, title="Zabıta Memuru Alımı", institution="X Belediyesi",  # noqa: E731
                                      url=url, application_end=tr(2026, 11, 5))
        idx = DuplicateIndex()
        kept, dropped = drop_duplicates([mk("a", "https://x/a"), mk("b", "https://x/b")], idx)
        self.assertEqual([k.external_id for k in kept], ["a"])
        kept2, dropped2 = drop_duplicates([mk("c", "https://y/c")], idx)  # sonraki kaynak
        self.assertEqual((kept2, len(dropped2)), ([], 1))

    def test_real_rss_and_api_versions_of_same_ilan(self):
        rss_url = KariyerKapisiScraper.list_urls[0]

        class Rss:
            def get(self, url, render=False):
                return (FIX / "kariyerkapisi_rss.xml").read_text(encoding="utf-8")

        now = tr(2026, 10, 15)
        rss = [x for x in KariyerKapisiScraper(Rss()).scrape(now=now) if ADALET in x.external_id]
        api = [x for x in KariyerKapisiIsealimScraper(ApiFetcher(api_data())).scrape(now=now) if x.external_id == ADALET]
        self.assertEqual((len(rss), len(api)), (1, 1))
        self.assertEqual(rss_url, "https://kariyerkapisi.gov.tr/RSS?k=3")
        idx = DuplicateIndex()
        self.assertEqual(len(drop_duplicates(rss, idx)[0]), 1)
        kept, dropped = drop_duplicates(api, idx)
        self.assertEqual((kept, len(dropped)), ([], 1))   # RSS + İş e-Alım: tek satır


class YerelIdStabilityTest(unittest.TestCase):
    """Regresyon: eski kod `abs(hash(url))` kullanıyordu; Python hash()'i her çalıştırmada farklıdır,
    sayısal kimliği olmayan duyurular bu yüzden her taramada yeni ilan sanılıp tekrar ekleniyordu."""

    CODE = (
        "from scrapers.yerelyonetimler import YerelYonetimlerScraper as S\n"
        "html = ('<a class=\"duyurular-second-card-wrapper\" href=\"/duyuru/kecioren-zabita\">'\n"
        "        '<span class=\"date\">09 Ekim 2026</span>'\n"
        "        '<p>ANKARA İLİ KEÇİÖREN BELEDİYE BAŞKANLIĞINA İLK DEFA ATANMAK ÜZERE ZABITA MEMURU ALIMI İLANI</p></a>')\n"
        "items = S(None).parse_list(html, 'https://yerelyonetimler.csb.gov.tr/duyurular')\n"
        "print(items[0].external_id)\n"
    )

    def run_with_seed(self, seed):
        env = {**os.environ, "PYTHONHASHSEED": str(seed)}
        out = subprocess.run([sys.executable, "-c", self.CODE], cwd=ROOT, env=env, check=True,
                             capture_output=True, text=True).stdout.strip()
        return out

    def test_id_does_not_depend_on_process(self):
        ids = {self.run_with_seed(s) for s in (1, 2, 3)}
        self.assertEqual(len(ids), 1, ids)
        self.assertTrue(ids.pop().startswith("yy-"))


class PostJsonTest(unittest.TestCase):
    class Resp:
        def __init__(self, status=200, data=None, text="{}", bad_json=False):
            self.status_code, self._data, self.text, self._bad = status, data, text, bad_json

        def raise_for_status(self):
            if self.status_code >= 400:
                import requests
                raise requests.HTTPError(str(self.status_code))

        def json(self):
            if self._bad:
                raise ValueError("bozuk json")
            return self._data

    class Session:
        def __init__(self, robots, post):
            self.headers, self.robots, self.post_resp, self.gets, self.posts = {}, robots, post, [], []

        def get(self, url, timeout=None):
            self.gets.append(url)
            return self.robots

        def post(self, url, json=None, timeout=None):
            self.posts.append((url, json))
            return self.post_resp

    def make(self, robots_text, post):
        R = self.Resp
        return self.Session(R(200, text=robots_text), post)

    def test_robots_checked_for_page_not_api_host_and_json_returned(self):
        s = self.make("User-agent: *\nAllow: /\n", self.Resp(200, {"searchIlan": []}))
        out = Fetcher(delay=0, session=s).post_json(API_URL, {"a": 1}, robots_url=PAGE_URL)
        self.assertEqual(out, {"searchIlan": []})
        self.assertEqual(s.gets, ["https://kariyerkapisi.gov.tr/robots.txt"])  # api. alt alan sorgulanmaz
        self.assertEqual(s.posts, [(API_URL, {"a": 1})])

    def test_disallowed_means_no_post(self):
        s = self.make("User-agent: *\nDisallow: /isealim\n", self.Resp(200, {}))
        with self.assertRaises(RobotsDisallowed):
            Fetcher(delay=0, session=s).post_json(API_URL, {}, robots_url=PAGE_URL)
        self.assertEqual(s.posts, [])

    def test_invalid_json_is_not_retried(self):
        s = self.make("", self.Resp(200, bad_json=True))
        with self.assertRaises(ValueError):
            Fetcher(delay=0, session=s).post_json(API_URL, {}, robots_url=PAGE_URL)
        self.assertEqual(len(s.posts), 1)


class FakeDb:
    """Database'in run.py'nin kullandığı kısmı (bellekte)."""

    def __init__(self):
        self.rows = []

    def known_ids(self, source):
        return {r["external_id"] for r in self.rows if r["source"] == source}

    def known_rows(self):
        return list(self.rows)

    def insert_new(self, listings, source):
        have = {(r["source"], r["external_id"]) for r in self.rows}
        new = [l for l in listings if (source, l.external_id) not in have]
        self.rows.extend(l.to_row(source) for l in new)
        return len(new)


def _ilan(ext, url="https://x/a"):
    return Listing(external_id=ext, title="Keçiören Belediyesi — Zabıta Memuru Alımı",
                   institution="Keçiören Belediyesi", url=url, application_end=tr(2099, 1, 1))


class UnstableIdScraper(BaseScraper):
    """Eski hata: kimlik her çalıştırmada değişir."""
    key, name, counter = "yerelyonetimler", "Kararsız kimlik", itertools.count()

    def scrape(self, known_ids=(), now=None):
        return [_ilan(f"yy-{next(self.counter)}")]


class SourceA(BaseScraper):
    key, name = "kamuilan", "Kaynak A"

    def scrape(self, known_ids=(), now=None):
        return [_ilan("a-1", "https://a/1")]


class SourceB(BaseScraper):
    key, name = "iskur", "Kaynak B"

    def scrape(self, known_ids=(), now=None):
        return [_ilan("b-77", "https://b/77")]


class RunTwiceTest(unittest.TestCase):
    def run_all(self, db, scrapers):
        with mock.patch.dict(run.SOURCES, {c.key: c for c in scrapers}, clear=True):
            run.run_once(list(run.SOURCES), db, None)

    def test_running_twice_adds_nothing_even_if_source_ids_change(self):
        db = FakeDb()
        self.run_all(db, [UnstableIdScraper])
        self.run_all(db, [UnstableIdScraper])
        self.run_all(db, [UnstableIdScraper])
        self.assertEqual(len(db.rows), 1)

    def test_same_ilan_from_two_sources_is_stored_once(self):
        db = FakeDb()
        self.run_all(db, [SourceA, SourceB])
        self.assertEqual([r["source"] for r in db.rows], ["kamuilan"])
        self.run_all(db, [SourceA, SourceB])
        self.assertEqual(len(db.rows), 1)


if __name__ == "__main__":
    unittest.main()
