"""Aynı ilanın ikinci kez eklenmesini önleyen içerik karşılaştırması.

Veritabanındaki unique(source, external_id) yalnızca AYNI kaynaktan AYNI kimlikle gelen ilanı yakalar.
Şu durumlarda ilan yine de ikinci kez eklenirdi:
  • kaynağın kimliği/URL'si çalıştırmalar arasında değişirse,
  • aynı ilan iki kaynakta yayımlanırsa (ör. Kariyer Kapısı RSS ve İş e-Alım),
  • aynı ilan aynı sayfada iki farklı bağlantı biçimiyle görünürse.

Bu modül ilanları kimliklerine değil İÇERİĞİNE göre karşılaştırır: kurum + başlık + son başvuru günü.
İki ilan şu durumlarda "aynı" sayılır:
  1. URL/kimliklerinde ortak bir UUID varsa (Kariyer Kapısı ilanları), ya da
  2. son başvuru günü aynıysa, kurum adları benzerse, başlıktaki sayılar (yıl, dönem no) aynıysa ve
     kuruma ait sözcükler çıkarıldıktan sonra başlıklar neredeyse aynıysa.
Şüphede ilan EKLENİR (iki farklı ilanı yanlışlıkla birleştirmek, bir tekrarı geçirmekten daha kötüdür).
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime
from typing import Iterable

from text_utils import TR_TZ, fold_tr

_UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)
_TOKEN = re.compile(r"[a-z0-9]+")
# "T.C." -> "t", "c" gibi anlamsız parçalar ve bağlaçlar karşılaştırmaya girmez.
_STOP = frozenset({"t", "c", "tc", "ve", "ile", "icin", "bir", "bu"})

_CORE_SIMILARITY = 0.9    # kuruma ait sözcükler çıkarıldıktan sonra başlık benzerliği (Jaccard)
# Kurum adlarında AYIRT EDİCİ olmayan sözcükler: "Düzce Üniversitesi Rektörlüğü" ile "Batman Üniversitesi
# Rektörlüğü" yalnızca bunlar yüzünden benzer sayılmasın (iki ayrı üniversite aynı gün aynı başlıkla ilan verebilir).
_GENERIC = frozenset({
    "universitesi", "rektorlugu", "belediyesi", "belediye", "baskanligi", "baskanlik", "bakanligi",
    "mudurlugu", "mudurluk", "genel", "kurumu", "kurulu", "ajansi", "idaresi", "valiligi", "kaymakamligi",
    "hastanesi", "enstitusu", "fakultesi", "yuksekokulu", "mudurlugunden", "rektorlugunden",
})


def _tokens(text: str | None) -> list[str]:
    return [t for t in _TOKEN.findall(fold_tr(text)) if t not in _STOP]


def _jaccard(a: frozenset[str], b: frozenset[str]) -> float:
    return len(a & b) / len(a | b) if a and b else 0.0


def _parse_dt(value: datetime | str | None) -> datetime | None:
    if value is None or isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


@dataclass(frozen=True)
class Signature:
    ids: frozenset[str]     # URL / kimlikte geçen UUID'ler
    inst: frozenset[str]    # kurum adı sözcükleri
    core: frozenset[str]    # başlık sözcükleri (kurum sözcükleri çıkarılmış)
    day: str | None         # son başvuru günü (Türkiye saatiyle), yoksa None


def make_signature(*, institution: str, title: str, application_end: datetime | str | None,
                   url: str = "", external_id: str = "") -> Signature:
    inst = frozenset(_tokens(institution))
    title_tokens = _tokens(title)
    core = frozenset(t for t in title_tokens if t not in inst) or frozenset(title_tokens)
    end = _parse_dt(application_end)
    day = end.astimezone(TR_TZ).strftime("%Y-%m-%d") if end and end.tzinfo else (
        end.strftime("%Y-%m-%d") if end else None)
    ids = frozenset(m.lower() for m in _UUID.findall(f"{url} {external_id}"))
    return Signature(ids=ids, inst=inst, core=core, day=day)


def signature_of(item) -> Signature:
    """Bot tarafındaki Listing için imza."""
    return make_signature(institution=item.institution, title=item.title,
                          application_end=item.application_end, url=item.url,
                          external_id=item.external_id)


def signature_of_row(row: dict) -> Signature:
    """Veritabanından okunan satır (sözlük) için imza."""
    return make_signature(institution=row.get("institution") or "", title=row.get("title") or "",
                          application_end=row.get("application_end"), url=row.get("url") or "",
                          external_id=row.get("external_id") or "")


def _numbers(tokens: frozenset[str]) -> frozenset[str]:
    return frozenset(t for t in tokens if t.isdigit())


def _institution_similar(a: frozenset[str], b: frozenset[str]) -> bool:
    """Aynı kurum mu? Ayırt edici sözcükler (şehir/ad) aynı olmalı ya da biri diğerini kapsamalı
    ("... Kurumu Başkanlığı" ile "... Kurumu Başkanlığı (BDDK)")."""
    if not a or not b:
        return False
    da, db = a - _GENERIC, b - _GENERIC
    if da and db:
        return da <= db or db <= da
    return a <= b or b <= a


def is_duplicate(a: Signature, b: Signature) -> bool:
    if a.ids & b.ids:
        return True
    if a.day != b.day or not a.core or not b.core:
        return False
    if _numbers(a.core) != _numbers(b.core):
        return False
    return _institution_similar(a.inst, b.inst) and _jaccard(a.core, b.core) >= _CORE_SIMILARITY


class DuplicateIndex:
    """Şimdiye kadar görülen ilanların imzaları. `find` ile yeni bir ilanın tekrar olup olmadığına bakılır."""

    def __init__(self) -> None:
        self._by_day: dict[str | None, list[tuple[Signature, str]]] = {}
        self._by_id: dict[str, str] = {}

    def __len__(self) -> int:
        return sum(len(v) for v in self._by_day.values())

    def add(self, sig: Signature, label: str) -> None:
        self._by_day.setdefault(sig.day, []).append((sig, label))
        for i in sig.ids:
            self._by_id.setdefault(i, label)

    def add_rows(self, rows: Iterable[dict]) -> None:
        for r in rows:
            self.add(signature_of_row(r), f"{r.get('institution')} — {r.get('title')}")

    def find(self, sig: Signature) -> str | None:
        """Tekrar ise var olan ilanın etiketini, değilse None döndürür."""
        for i in sig.ids:
            if i in self._by_id:
                return self._by_id[i]
        for other, label in self._by_day.get(sig.day, ()):
            if is_duplicate(sig, other):
                return label
        return None


def drop_duplicates(listings: Iterable, index: DuplicateIndex) -> tuple[list, list[tuple[object, str]]]:
    """Tekrar olmayanları (kept) ve atlananları ((ilan, var olan ilanın etiketi)) döndürür.
    Kabul edilen her ilan `index`e eklenir: aynı toplu içindeki ve sonraki kaynaklardaki tekrarlar da yakalanır."""
    kept: list = []
    dropped: list[tuple[object, str]] = []
    for item in listings:
        sig = signature_of(item)
        hit = index.find(sig)
        if hit is not None:
            dropped.append((item, hit))
            continue
        index.add(sig, f"{item.institution} — {item.title}")
        kept.append(item)
    return kept, dropped
