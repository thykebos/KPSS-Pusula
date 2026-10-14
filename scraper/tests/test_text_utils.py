import unittest
from datetime import datetime

from text_utils import (TR_TZ, date_from_slug, extract_city, extract_codes, extract_levels,
                        extract_positions, find_application_end, find_dates, fold_tr)

REF = datetime(2026, 10, 14, tzinfo=TR_TZ)


class TextUtilsTest(unittest.TestCase):
    def test_fold(self):
        self.assertEqual(fold_tr("HEMŞİRE Iğdır ŞOFÖR"), "hemsire igdir sofor")

    def test_dates(self):
        ds = find_dates("Başvuru 05.10.2026 ile 16 Ekim 2026 arası, sınav 25 Eki", REF)
        self.assertEqual([(d.year, d.month, d.day) for d in ds], [(2026, 10, 5), (2026, 10, 16), (2026, 10, 25)])

    def test_date_without_year_far_future_goes_back(self):
        ds = find_dates("27 Tem", datetime(2026, 1, 10, tzinfo=TR_TZ))
        self.assertEqual(ds[0].year, 2025)

    def test_invalid_date_ignored(self):
        self.assertEqual(find_dates("31.02.2026", REF), [])

    def test_application_end(self):
        d = find_application_end("... Son başvuru tarihi: 16.10.2026 saat 23:59'a kadar", REF)
        self.assertEqual((d.month, d.day, d.hour, d.minute), (10, 16, 23, 59))
        self.assertIsNone(find_application_end("Başvuru yapılacaktır", REF))

    def test_slug_date(self):
        d = date_from_slug("hukuk-mesleklerine-giris-sinavi-31072026085643")
        self.assertEqual((d.year, d.month, d.day, d.hour, d.minute), (2026, 7, 31, 8, 56))
        self.assertIsNone(date_from_slug("slug-without-stamp"))

    def test_levels(self):
        self.assertEqual(extract_levels("Lise ve önlisans mezunu"), ["lise", "onlisans"])
        self.assertEqual(extract_levels("Lisans mezunu"), ["lisans"])
        self.assertEqual(extract_levels("Yüksek lisans yapmış"), [])
        self.assertEqual(extract_levels("Ortaöğretim"), ["lise"])

    def test_codes_and_positions(self):
        self.assertEqual(extract_codes("Nitelik Kodu: 3121, 3122 ve 31234"), ["3121", "3122", "31234"])
        self.assertEqual(extract_codes("2026 yılında 1500 kişi"), [])
        self.assertEqual(extract_positions("150 zabıt katibi, 20 personel"), 150)
        self.assertEqual(extract_positions("Toplam 25 sürekli işçi"), 25)
        self.assertIsNone(extract_positions("KPSS-2026/5 Lisans puanı, 2026 yılı"))
        self.assertEqual(extract_positions("25 işçi alınacaktır"), 25)

    def test_city(self):
        self.assertEqual(extract_city("Ankara Şehir Hastanesi"), "Ankara")
        self.assertEqual(extract_city("İZMİR Büyükşehir"), "İzmir")
        self.assertIsNone(extract_city("Van gölü kıyısında"))
        self.assertEqual(extract_city("Van Büyükşehir Belediyesi"), "Van")
        self.assertIsNone(extract_city("Ankaralı"))


if __name__ == "__main__":
    unittest.main()
