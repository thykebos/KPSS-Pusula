# Teknik Bağlam

## Teknolojiler
- Flutter (Dart SDK ^3.5): flutter_riverpod 2.6, go_router 14.6, supabase_flutter 2.8, shared_preferences, url_launcher ^6.3.1 (yeni), purchases_flutter (RevenueCat, yalnızca Android/iOS), intl, flutter_localizations.
- Supabase: Postgres, Auth, RLS, RPC (plpgsql), Edge Functions (Deno/TypeScript), isteğe bağlı pg_cron.
- Python 3.10+ (kullanıcının Mac'inde 3.10; GitHub Actions'ta 3.11): requests, beautifulsoup4, lxml, supabase, python-dotenv, pypdf; isteğe bağlı Playwright (`requirements-js.txt`), `truststore` (`USE_SYSTEM_CERTS=1`).

## Kurulum
- Uygulama: `flutter pub get` → `flutter run --dart-define-from-file=env.json -d <hedef>`. `env.json`, `env.example.json`'dan kopyalanır (SUPABASE_URL, SUPABASE_ANON_KEY, RC_API_KEY_ANDROID, RC_API_KEY_APPLE). Platform klasörleri (android/ios/macos/windows/web) depoda YOK; `flutter create . --platforms=windows,macos,android,ios,web --org com.kpsspusula` ile üretilir. Zip'i açan kişi `lib/main.dart`'ın proje kökünde olduğundan emin olmalıdır.
- Supabase: SQL Editor'de `supabase/migrations/0001…0010` sırayla; örnek veriler `supabase/seed/`. Sıfırlamak için `supabase/maintenance/reset_bot_appointments.sql` (tüm ilanları ve takipleri siler).
- Bot: `cd scraper`, `pip install -r requirements.txt`, `.env` (SUPABASE_URL, SUPABASE_SERVICE_KEY). Komutlar proje kökünden DEĞİL `scraper/` içinden çalıştırılır (`python3 run.py --source all`, `--dry-run`, `--discover --debug-dir debug`, `--daemon`). Testler: `python -m unittest discover -s tests -t .` (75 test, geçiyor).
- Otomasyon: `.github/workflows/scraper.yml` saat başı çalışır; Secrets: SUPABASE_URL, SUPABASE_SERVICE_KEY. Elle çalıştırmada `source` ve `mode` (run/discover) girişi vardır.

## Kısıtlar
- Dart/Flutter geliştirme ortamında (bulut çalışma alanı) derlenemiyor; Dart değişiklikleri yalnızca okunarak denetlendi. İlk `flutter run`'da derleme hatası çıkabilir; hata metni geri bildirilir.
- Kullanıcının evindeki ağdan Resmî Gazete'ye GET zaman aşımına uğruyor (neden bilinmiyor); bulut çalışma alanının ağı da izin listesi ile sınırlı.
- Satın alma yalnızca Android/iOS'ta; masaüstü/web Premium durumunu Supabase'den okur.
- Yerel proje klasörü kullanıcıda `kpss_pusula4` (Mac, ~/Downloads); bulutta çalışma kopyası `kpss_pusula2`.

## Araç Kullanım Kalıpları
- Her teslimde yalnızca değişen dosyalar zip'lenir, klasör yapısı korunur; tam paket istenirse `.env`/`env.json` hariç tutulur.
- Bot için dosya eklerken hem `__init__.py` kaydı hem enum migration'ı hem fixture + test gerekir.
- Yeni kaynak yazmadan önce `--discover` çıktısı (HTML + `*.xhr.json`) incelenir; mümkünse HTML kazımak yerine JSON API kullanılır.
