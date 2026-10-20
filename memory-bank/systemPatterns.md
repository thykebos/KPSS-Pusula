# Sistem Desenleri

## Mimari Genel Bakış
```
Python botu (scraper/) --service_role--> Supabase Postgres <--anon+JWT--> Flutter uygulaması
                                           |  RLS + RPC fonksiyonları
                                           +--> Edge Functions: notify-new-appointment (FCM),
                                                               revenuecat-webhook (abonelik)
RevenueCat <--> mağaza ; webhook -> subscriptions tablosu
```
İstemci tabloları doğrudan değil, çoğunlukla RPC'lerle okur (`get_appointments`, `get_followed_appointments`, `get_appointment_detail`, `toggle_follow_appointment`). Premium kontrolü sunucuda (`is_premium`) yapılır.

## Flutter Katmanları
`lib/core` (tema, router, ağ, hata eşleme) · `lib/shared` (modeller) · `lib/features/<özellik>/{data,domain,presentation}`. Özellikler: auth, dashboard, matik, appointments, settings, subscription. Durum yönetimi Riverpod (`NotifierProvider`), yönlendirme go_router. Hata, `error_mapper` ile kullanıcıya Türkçe mesaja çevrilir.

## Veritabanı (supabase/migrations, sırayla 0001–0010)
Tablolar: `users`, `exams`, `subscriptions`, `questions`, `question_options`, `user_solved_questions`, `appointments`, `appointment_follows`, `device_tokens`. Enum `appointment_source` her yeni kaynakta migration ile genişler (0007 ilan_gov/sayistay, 0008 kariyerkapisi_isealim, 0009 resmigazete). `appointments` üzerinde `unique(source, external_id)` vardır.
- Yardımcılar: `tr_fold` (Türkçe duyarsız karşılaştırma), `like_escape`, `profession_match`, `is_premium`.
- Güncellik: `appointment_is_active(p_end, p_published, p_max_age_days=45)`: bitiş tarihi varsa geçmemiş olmalı; yoksa yayın tarihi 45 günden yeni olmalı. Liste RPC'leri ve ana ekran sorgusu bunu uygular.
- `purge_stale_appointments` yalnızca service_role çağırır; bot her taramadan sonra çağırır, pg_cron varsa saatlik de çalışır. Takip edilen ilan silinmez ama listede görünmez.
- 0010 tekrarları bir kez temizler (aynı kurum+başlık+bitiş günü, takip edilen satırlar korunur). Dosya tekrar çalıştırılabilir.

## Bot Desenleri (scraper/)
- `scrapers/base.py`: `Listing`, `BaseScraper` (liste → aday → detay → `keep`), `is_hiring_title`, `_is_current`, `stable_id` (kalıcı kimlik).
- Her kaynak bir sınıf, `scrapers/__init__.py` içindeki `SOURCES` kaydına eklenir. Kaynaklar: kariyerkapisi (RSS), kariyerkapisi_isealim (JSON API), yerelyonetimler, pgm_adalet, kamuilan, iskur, iskur_esube, ilan_gov, sayistay, resmigazete (PDF, `pypdf`).
- `http_client.Fetcher`: robots.txt'e uyar (bilerek atlatma seçeneği yok), istekler arası bekler, yeniden dener, ölü siteyi devre kesici ile atlar, `post_json`, Playwright yedeği, `--discover` ile XHR yakalama.
- `dedup.py`: imza = kurum + başlık + son başvuru günü (Türkiye saati) veya ortak UUID. Kararsızsa ilan EKLENİR (iki farklı ilanı yanlışlıkla birleştirmek daha kötüdür).
- `database.py`: yalnızca yeni ilan ekler (`ignore_duplicates`); mevcut satıra dokunmaz.
- Kimlikler asla Python `hash()` ile üretilmez (süreç başına değişir); `stable_id` kullanılır.
- Saat dilimi: bitiş/yayın tarihleri elle ayrıştırılıp Türkiye saati (UTC+3) atanır; sunucunun yerel saatine güvenilmez (GitHub UTC'dedir).

## Kritik Akışlar
1. Bot turu: `known_rows()` ile imza indeksi → kaynak taraması → `known_ids` ve `drop_duplicates` ile süzme → `insert_new` → `purge_stale_appointments`.
2. İlan listesi: filtre (şehir tam eşleşme `tr_fold`, KPSS, meslek) → `get_appointments` → sayfa sayfa birikim → kart → detay → "Bağlantıya Git".
3. Premium: mağaza → RevenueCat → webhook → `subscriptions` → `is_premium` → RPC/ekran kapısı.
