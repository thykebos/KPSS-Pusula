"""KPSS Pusula ilan botu.

  python run.py --dry-run                      # hepsini tara, veritabanına YAZMADAN listele
  python run.py --source pgm_adalet --dry-run --debug-dir debug
  python run.py                                # hepsini tara ve yeni ilanları Supabase'e ekle
  python run.py --daemon --interval 3600       # saatte bir sürekli tara
"""
from __future__ import annotations

import argparse
import logging
import os
import sys
import time

from dotenv import load_dotenv

from dedup import DuplicateIndex, drop_duplicates
from http_client import Fetcher
from scrapers import SOURCES

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("run")


def run_once(keys: list[str], db, fetcher: Fetcher) -> None:
    # Tekrar önleme: veritabanındaki TÜM ilanların (hangi kaynaktan olursa olsun) imzaları. Her kaynağın
    # kabul ettiği ilan da buraya eklenir; böylece aynı ilan iki kaynakta çıksa bile bir kez eklenir.
    index = DuplicateIndex()
    if db is not None:
        try:
            index.add_rows(db.known_rows())
        except Exception:  # noqa: BLE001 - okunamazsa yalnızca (source, external_id) koruması kalır
            logger.exception("Mevcut ilanlar okunamadı; içerik tabanlı tekrar kontrolü bu turda kapalı.")

    for key in keys:
        scraper = SOURCES[key](fetcher)
        try:
            known = db.known_ids(key) if db else set()
            listings = scraper.scrape(known)
        except Exception:  # noqa: BLE001 - bir kaynağın hatası diğerlerini durdurmasın
            logger.exception("%s taranırken hata", scraper.name)
            continue

        fresh, dropped = drop_duplicates([l for l in listings if l.external_id not in known], index)
        for item, existing in dropped:
            logger.info("%s: tekrar ilan atlandı: %r (zaten var: %r)", scraper.name, item.title[:80], existing[:80])

        if db is None:  # --dry-run
            print(f"\n=== {scraper.name} ({key}): {len(fresh)} ilan"
                  f"{f' (+{len(dropped)} tekrar atlandı)' if dropped else ''} ===")
            for l in fresh:
                end = l.application_end.strftime("%d.%m.%Y") if l.application_end else "-"
                print(f"- {l.title[:90]} | {l.institution[:40]} | {l.city or '-'} | "
                      f"KPSS:{'evet' if l.kpss_required else 'hayır'} | son:{end}\n    {l.url}")
            continue

        try:
            new = db.insert_new(fresh, key)
            logger.info("%s: %d ilan bulundu, %d yeni eklendi, %d tekrar atlandı.",
                        scraper.name, len(listings), new, len(dropped))
        except Exception:  # noqa: BLE001
            logger.exception("%s: veritabanına yazılamadı", scraper.name)


def purge(db) -> None:
    if db is not None:
        n = db.purge_stale()
        if n:
            logger.info("%d eski/süresi geçmiş ilan silindi.", n)


def main() -> int:
    load_dotenv()
    p = argparse.ArgumentParser(description="KPSS Pusula ilan botu")
    p.add_argument("--source", choices=[*SOURCES, "all"], default="all")
    p.add_argument("--dry-run", action="store_true", help="Veritabanına yazma, sadece bulunanları göster")
    p.add_argument("--debug-dir", help="İndirilen ham HTML sayfalarını bu klasöre kaydet")
    p.add_argument("--discover", action="store_true",
                   help="Tüm sayfaları tarayıcıyla aç; ağ isteklerini (XHR/JSON) debug-dir'e kaydet. Sitenin gerçek veri adresini bulmak için")
    p.add_argument("--daemon", action="store_true", help="Sürekli çalış")
    p.add_argument("--interval", type=int, default=3600, help="Daemon tarama aralığı (sn)")
    p.add_argument("--delay", type=float, default=1.5, help="İstekler arası bekleme (sn)")
    args = p.parse_args()

    # --discover zaten dry-run demektir; DB kontrolünden önce işaretle
    if args.discover:
        args.debug_dir = args.debug_dir or "debug"
        args.dry_run = True

    db = None
    if not args.dry_run:
        url, key = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SERVICE_KEY")
        if not url or not key:
            logger.error("SUPABASE_URL ve SUPABASE_SERVICE_KEY .env dosyasında tanımlı olmalı "
                         "(ya da --dry-run kullan).")
            return 1
        from database import Database
        db = Database(url, key)

    keys = list(SOURCES) if args.source == "all" else [args.source]
    fetcher = Fetcher(delay=args.delay, debug_dir=args.debug_dir)
    if args.discover:
        for k in keys:
            SOURCES[k].needs_js = True
    try:
        while True:
            run_once(keys, db, fetcher)
            purge(db)
            if not args.daemon:
                return 0
            logger.info("Sonraki tarama %d sn sonra.", args.interval)
            time.sleep(args.interval)
    except KeyboardInterrupt:
        logger.info("Durduruldu.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
