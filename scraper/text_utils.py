"""Türkçe ilan metinlerinden alan çıkarma yardımcıları (ağ erişimi yok, saf fonksiyonlar)."""
from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

TR_TZ = timezone(timedelta(hours=3))  # Türkiye saati (UTC+3, yaz saati uygulaması yok)

_FOLD = str.maketrans("İIıŞşĞğÜüÖöÇç", "iiissgguuoocc")


def fold_tr(text: str | None) -> str:
    """Türkçe harfleri sadeleştirip küçültür ("HEMŞİRE" -> "hemsire"). SQL'deki tr_fold ile aynıdır."""
    return (text or "").translate(_FOLD).lower()


def clean(text: str | None) -> str:
    """Fazla boşlukları tek boşluğa indirir."""
    return re.sub(r"\s+", " ", text or "").strip()


# ---------------------------------------------------------------------------
# Tarih
# ---------------------------------------------------------------------------
_MONTHS = {
    "oca": 1, "sub": 2, "mar": 3, "nis": 4, "may": 5, "haz": 6,
    "tem": 7, "agu": 8, "eyl": 9, "eki": 10, "kas": 11, "ara": 12,
}
_NUM_DATE = re.compile(r"(?<!\d)(\d{1,2})\s*[./-]\s*(\d{1,2})\s*[./-]\s*(\d{4})(?!\d)")
_TEXT_DATE = re.compile(r"(?<!\d)(\d{1,2})\s+([a-z]{3,9})\.?(?:\s+(\d{4}))?(?!\d)")


def _mk(day: int, month: int, year: int, hour: int = 0, minute: int = 0) -> datetime | None:
    try:
        return datetime(year, month, day, hour, minute, tzinfo=TR_TZ)
    except ValueError:
        return None


def find_dates(text: str, ref: datetime | None = None) -> list[datetime]:
    """Metindeki tüm tarihleri bulur (12.10.2026, 12 Ekim 2026, 12 Eki). Yılsız tarihte `ref` yılı
    kullanılır; sonuç ref'ten 6 aydan fazla ileride kalırsa bir önceki yıl alınır."""
    ref = ref or datetime.now(TR_TZ)
    folded = fold_tr(text)
    found: list[tuple[int, datetime]] = []
    for m in _NUM_DATE.finditer(folded):
        dt = _mk(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        if dt:
            found.append((m.start(), dt))
    for m in _TEXT_DATE.finditer(folded):
        month = _MONTHS.get(m.group(2)[:3])
        if not month or not any(m.group(2).startswith(k) for k in _MONTHS):
            continue
        year = int(m.group(3)) if m.group(3) else ref.year
        dt = _mk(int(m.group(1)), month, year)
        if dt and not m.group(3) and dt - ref > timedelta(days=183):
            dt = _mk(dt.day, dt.month, year - 1)
        if dt:
            found.append((m.start(), dt))
    return [d for _, d in sorted(found, key=lambda x: x[0])]


_DEADLINE = re.compile(
    r"son\s*basvuru(?:\s*tarihi)?\s*[:\-]?\s*(?P<d>.{0,40})", re.DOTALL
)


def find_application_end(text: str, ref: datetime | None = None) -> datetime | None:
    """"Son başvuru tarihi: ..." ifadesinden bitiş tarihini çıkarır; yoksa None.
    Bitiş günü 23:59 kabul edilir."""
    m = _DEADLINE.search(fold_tr(text))
    if not m:
        return None
    dates = find_dates(m.group("d"), ref)
    if not dates:
        return None
    d = dates[0]
    return d.replace(hour=23, minute=59)


_SLUG_STAMP = re.compile(r"(\d{2})(\d{2})(\d{4})(\d{2})(\d{2})(\d{2})$")


def date_from_slug(slug: str) -> datetime | None:
    """pgm.adalet.gov.tr bağlantılarının sonundaki ddMMyyyyHHmmss damgasından tarih üretir."""
    m = _SLUG_STAMP.search(slug)
    if not m:
        return None
    d, mo, y, h, mi, _s = (int(g) for g in m.groups())
    return _mk(d, mo, y, h, mi)


# ---------------------------------------------------------------------------
# Eğitim seviyesi, KPSS kodu, kadro sayısı
# ---------------------------------------------------------------------------
def extract_levels(text: str) -> list[str]:
    """Metinde geçen eğitim seviyeleri: 'lise' | 'onlisans' | 'lisans'. Hiçbiri yoksa []."""
    t = fold_tr(text)
    levels: list[str] = []
    if re.search(r"\b(ortaogretim|lise)\b", t):
        levels.append("lise")
    if re.search(r"on\s?lisans", t):
        levels.append("onlisans")
    rest = re.sub(r"on\s?lisans|yuksek\s+lisans", " ", t)
    if re.search(r"\blisans", rest):
        levels.append("lisans")
    return levels


_CODE_BLOCK = re.compile(r"\bkod(?:u|lari|larinda|lu)?\b[^0-9]{0,25}((?:\d{4,5}(?:\s*[,;/-]\s*|\s+ve\s+)?)+)")


def extract_codes(text: str) -> list[str]:
    """KPSS nitelik kodlarını ("Kod: 3121, 3122") çıkarır."""
    codes: list[str] = []
    for m in _CODE_BLOCK.finditer(fold_tr(text)):
        for c in re.findall(r"\d{4,5}", m.group(1)):
            if c not in codes:
                codes.append(c)
    return codes


_ROLE = (r"(?:adet|kisi|personel|isci|kadro|memur|katip|katibi|gorevli|gorevlisi|teknisyen|tekniker|"
         r"muhendis|hemsire|sofor|ogretmen|uzman|avukat|doktor|ebe|sozlesmeli|koruma)")
_COUNT = re.compile(rf"(?<![\d./-])(\d{{1,5}})\s+(?:[a-z]+\s+){{0,2}}?{_ROLE}\b")


def extract_positions(text: str) -> int | None:
    """"25 sürekli işçi", "150 zabıt katibi" gibi kadro sayısını çıkarır; yıl gibi sayıları yok sayar."""
    for m in _COUNT.finditer(fold_tr(text)):
        n = int(m.group(1))
        if 0 < n < 50000 and not (len(m.group(1)) == 4 and 1990 <= n <= 2100):
            return n
    return None


# ---------------------------------------------------------------------------
# Şehir
# ---------------------------------------------------------------------------
_CITIES = (
    "Adana Adıyaman Afyonkarahisar Ağrı Aksaray Amasya Ankara Antalya Ardahan Artvin Aydın "
    "Balıkesir Bartın Batman Bayburt Bilecik Bingöl Bitlis Bolu Burdur Bursa Çanakkale Çankırı "
    "Çorum Denizli Diyarbakır Düzce Edirne Elazığ Erzincan Erzurum Eskişehir Gaziantep Giresun "
    "Gümüşhane Hakkari Hatay Iğdır Isparta İstanbul İzmir Kahramanmaraş Karabük Karaman Kars "
    "Kastamonu Kayseri Kırıkkale Kırklareli Kırşehir Kilis Kocaeli Konya Kütahya Malatya Manisa "
    "Mardin Mersin Muğla Muş Nevşehir Niğde Ordu Osmaniye Rize Sakarya Samsun Siirt Sinop Sivas "
    "Şanlıurfa Şırnak Tekirdağ Tokat Trabzon Tunceli Uşak Van Yalova Yozgat Zonguldak"
).split()
_AMBIGUOUS = {"van", "mus"}
_AMBIGUOUS_NEXT = ("belediye", "valilig", "universite", "yuzuncu", "buyuksehir", "il ", "ili", "ilce")
CITY_BY_FOLD = {fold_tr(c): c for c in _CITIES}


def extract_city(text: str) -> str | None:
    """Metindeki ilk il adını döndürür (ör. "Ankara Şehir Hastanesi" -> "Ankara")."""
    t = fold_tr(text)
    best: tuple[int, str] | None = None
    for key, name in CITY_BY_FOLD.items():
        for m in re.finditer(rf"(?<![a-z]){key}(?![a-z])", t):
            if key in _AMBIGUOUS and not t[m.end():].lstrip(" '").startswith(_AMBIGUOUS_NEXT):
                continue
            if best is None or m.start() < best[0]:
                best = (m.start(), name)
            break
    return best[1] if best else None
