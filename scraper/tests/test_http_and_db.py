import unittest

from database import Database
from http_client import Fetcher, RobotsDisallowed
from scrapers.base import Listing


class Resp:
    def __init__(self, status=200, text="<html></html>"):
        self.status_code, self.text, self.encoding, self.apparent_encoding = status, text, "utf-8", "utf-8"

    def raise_for_status(self):
        if self.status_code >= 400:
            import requests
            raise requests.HTTPError(str(self.status_code))


class Session:
    def __init__(self, robots):
        self.headers, self.robots, self.urls = {}, robots, []

    def get(self, url, timeout=None):
        self.urls.append(url)
        if url.endswith("/robots.txt"):
            return self.robots
        return Resp()


class FetcherTest(unittest.TestCase):
    def test_disallow_all_blocks_without_requesting_page(self):
        s = Session(Resp(200, "User-agent: *\nDisallow: /\n"))
        with self.assertRaises(RobotsDisallowed):
            Fetcher(delay=0, session=s).get("https://x.gov.tr/ilanlar")
        self.assertEqual(s.urls, ["https://x.gov.tr/robots.txt"])

    def test_partial_disallow(self):
        s = Session(Resp(200, "User-agent: *\nDisallow: /admin\n"))
        f = Fetcher(delay=0, session=s)
        self.assertEqual(f.get("https://x.gov.tr/ilanlar"), "<html></html>")
        with self.assertRaises(RobotsDisallowed):
            f.get("https://x.gov.tr/admin/panel")

    def test_missing_robots_means_allowed_and_forbidden_robots_means_blocked(self):
        self.assertEqual(Fetcher(delay=0, session=Session(Resp(404))).get("https://a.tr/x"), "<html></html>")
        with self.assertRaises(RobotsDisallowed):
            Fetcher(delay=0, session=Session(Resp(403))).get("https://a.tr/x")


class DeadSiteTest(unittest.TestCase):
    """Ulaşılamayan site bir kez denenir; sonraki istekler beklemeden hata verir."""

    class Down:
        def __init__(self, exc):
            self.headers, self.exc, self.urls = {}, exc, []

        def get(self, url, timeout=None, stream=False):
            self.urls.append(url)
            raise self.exc

    def test_timeout_on_robots_marks_site_dead(self):
        import requests
        s = self.Down(requests.Timeout("read timed out"))
        f = Fetcher(delay=0, session=s)
        for path in ("a", "b", "c"):
            with self.assertRaises(requests.ConnectionError):
                f.get(f"https://slow.gov.tr/{path}")
        self.assertEqual(s.urls, ["https://slow.gov.tr/robots.txt"])  # sayfa için hiç istek atılmadı

    def test_other_sites_unaffected(self):
        import requests
        s = Session(Resp(404))
        f = Fetcher(delay=0, session=s)
        f._dead.add("https://slow.gov.tr")
        with self.assertRaises(requests.ConnectionError):
            f.get("https://slow.gov.tr/x")
        self.assertEqual(f.get("https://ok.gov.tr/x"), "<html></html>")

    def test_ssl_error_is_not_retried(self):
        import requests
        calls = []

        class Ssl(Session):
            def get(self, url, timeout=None, stream=False):
                calls.append(url)
                if url.endswith("/robots.txt"):
                    return Resp(404)
                raise requests.exceptions.SSLError("CERTIFICATE_VERIFY_FAILED")

        with self.assertRaises(requests.exceptions.SSLError):
            Fetcher(delay=0, session=Ssl(None)).get("https://bad.gov.tr/x")
        self.assertEqual(calls, ["https://bad.gov.tr/robots.txt", "https://bad.gov.tr/x"])


class FakeTable:
    def __init__(self, store):
        self.store = store

    def upsert(self, rows, on_conflict=None, ignore_duplicates=False):
        self.rows, self.ig, self.oc = rows, ignore_duplicates, on_conflict
        return self

    def execute(self):
        new = [r for r in self.rows if (r["source"], r["external_id"]) not in self.store]
        self.store.update({(r["source"], r["external_id"]): r for r in new})
        return type("R", (), {"data": new})()


class FakeClient:
    def __init__(self):
        self.store = {}

    def table(self, name):
        assert name == "appointments"
        return FakeTable(self.store)


class DbTest(unittest.TestCase):
    def test_insert_new_counts_only_new_and_ignores_duplicates(self):
        db = Database.__new__(Database)
        db._client = FakeClient()
        l = lambda i: Listing(external_id=f"e{i}", title="t", institution="k", url="u")
        self.assertEqual(db.insert_new([l(1), l(2)], "iskur"), 2)
        self.assertEqual(db.insert_new([l(2), l(3)], "iskur"), 1)
        self.assertEqual(len(db._client.store), 3)


if __name__ == "__main__":
    unittest.main()
