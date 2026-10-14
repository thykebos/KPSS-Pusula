"""Supabase (service_role) yazma katmanı. Yalnızca bot kullanır; anahtar uygulamaya konmaz."""
from __future__ import annotations

import logging
from typing import Any, Iterable

from scrapers.base import Listing

logger = logging.getLogger("database")
_CHUNK = 100


class Database:
    def __init__(self, url: str, service_key: str):
        from supabase import create_client  # geç içe aktarım: testler paketsiz de çalışsın

        self._client: Any = create_client(url, service_key)

    def known_ids(self, source: str) -> set[str]:
        """Kaynağın veritabanında zaten kayıtlı external_id'leri (detay sayfası açmamak için)."""
        ids: set[str] = set()
        start = 0
        while True:
            res = (self._client.table("appointments").select("external_id")
                   .eq("source", source).range(start, start + 999).execute())
            ids.update(r["external_id"] for r in res.data)
            if len(res.data) < 1000:
                return ids
            start += 1000

    def insert_new(self, listings: Iterable[Listing], source: str) -> int:
        """Yalnızca yeni ilanları ekler (aynı source+external_id varsa dokunmaz). Eklenen sayısını döndürür.

        `ignore_duplicates` kullanılır: var olan satır güncellenmez, böylece published_at her
        taramada "şimdi"ye kaymaz ve yeni-ilan bildirimi tekrar tetiklenmez.
        """
        rows = [l.to_row(source) for l in listings]
        inserted = 0
        for i in range(0, len(rows), _CHUNK):
            chunk = rows[i:i + _CHUNK]
            res = (self._client.table("appointments")
                   .upsert(chunk, on_conflict="source,external_id", ignore_duplicates=True)
                   .execute())
            inserted += len(res.data or [])
        return inserted
