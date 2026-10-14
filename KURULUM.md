# KPSS Pusula – Kurulum ve Çalıştırma Rehberi

Bu rehber, hiç Flutter kurmamış biri için baştan sona yazıldı. Sırayla git; her bölümün sonunda "Kontrol" satırı var.

> **Dürüst not:** Bu kodu yazdığım ortamda Flutter kurulu değildi, kod hiç derlenip çalıştırılmadı. İlk çalıştırmada küçük derleme hataları çıkabilir. Çıkarsa **terminaldeki hata metnini olduğu gibi bana yapıştır**, düzeltirim.

---

## 0) Önce karar ver: uygulamayı nerede çalıştıracaksın?

| Hedef | Gerekenler | Not |
|---|---|---|
| **Windows masaüstü** | Flutter + Visual Studio 2022 (C++ iş yükü) | Windows kullanıyorsan en kolay gerçek hedef |
| **macOS masaüstü** | Flutter + Xcode | Mac kullanıyorsan |
| **Android telefon / emülatör** | Flutter + Android Studio | Telefonu USB ile bağlayabilirsin |
| **iPhone / iOS** | Mac + Xcode + Apple Developer hesabı | Windows'ta yapılamaz |
| **Chrome (web)** | Flutter + Chrome | Ek program gerekmez; **ilk deneme için en hızlısı** |

Öneri: İlk gün Chrome ile dene (en az kurulum), uygulamanın çalıştığını gör, sonra istediğin hedefi ekle.

---

## 1) Flutter'ı kur

Resmî kurulum sayfası: **https://docs.flutter.dev/install** (işletim sistemini seç, adımları izle).

Kısaca:

**Windows**
1. **Git for Windows** kur: https://git-scm.com/download/win
2. **Visual Studio Code** kur: https://code.visualstudio.com
3. VS Code'u aç → Eklentiler (Extensions) → **Flutter** eklentisini ara ve kur (Dart eklentisi otomatik gelir).
4. `Ctrl+Shift+P` → **Flutter: New Project** de. VS Code Flutter SDK'yı yoksa senin yerine indirmeyi önerir; onay ver.
   (Elle kurmak istersen SDK'yı resmî sayfadan indirip `C:\src\flutter` gibi bir klasöre aç ve `...\flutter\bin` yolunu PATH'e ekle.)

**macOS**
1. Xcode'u App Store'dan kur, bir kez açıp lisansı kabul et.
2. Terminalde: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` ve `sudo xcodebuild -runFirstLaunch`
3. CocoaPods: `sudo gem install cocoapods` (veya `brew install cocoapods`)
4. Flutter SDK'yı resmî sayfadan indir, `PATH`'e ekle (veya VS Code Flutter eklentisiyle kur).

**Kontrol:** Yeni bir terminal aç ve çalıştır:

```
flutter --version
flutter doctor
```

`flutter doctor` eksikleri sana madde madde söyler. **Sadece kullanacağın hedefin satırı yeşil olmalı**; diğerleri kırmızı kalabilir.

---

## 2) Hedefe göre ek kurulumlar

### Windows masaüstü
- **Visual Studio 2022** kur (VS Code değil, "Visual Studio"): https://visualstudio.microsoft.com → Community sürümü ücretsiz. Kurulumda **"Desktop development with C++"** iş yükünü işaretle.
- Windows'ta **Geliştirici Modu** açık olmalı (eklentiler için gerekir): `Başlat` → "Geliştirici ayarları" (Developer settings) → **Geliştirici Modu: Açık**. Bu açık değilse `flutter pub get` "symlink" hatası verir.

### macOS masaüstü
- Hazır (Xcode yeterli). Ek olarak **ağ iznini** açman gerekecek, bkz. Bölüm 8.

### Android
- **Android Studio** kur: https://developer.android.com/studio → ilk açılışta SDK'yı indirmesine izin ver.
- Android Studio → Settings → SDK Manager → **Android SDK Command-line Tools** işaretli olsun.
- Terminalde: `flutter doctor --android-licenses` (hepsine `y`).
- Gerçek telefonda: Ayarlar → Telefon hakkında → "Yapı numarası"na 7 kez dokun → Geliştirici seçenekleri → **USB hata ayıklama** aç, USB ile bağla.

### Chrome
- Chrome yüklüyse ek bir şey gerekmez.

**Kontrol:** `flutter devices` komutu seçtiğin hedefi listelemeli (ör. `Windows (desktop)`, `Chrome (web)`, telefonun adı).

---

## 3) Supabase projesini kur (veritabanı + giriş sistemi)

1. https://supabase.com → ücretsiz hesap aç → **New project**.
   - Bölge: sana yakın bir Avrupa bölgesi (ör. Frankfurt).
   - **Veritabanı şifresini bir yere kaydet.**
2. Sol menüden **SQL Editor** → **New query**. Aşağıdaki dosyaları **sırayla**, her birinin içeriğini yapıştırıp **Run** ile çalıştır:

   | Sıra | Dosya | Ne yapar |
   |---|---|---|
   | 1 | `supabase/migrations/0001_init.sql` | Tüm tablolar, güvenlik kuralları, fonksiyonlar |
   | 2 | `supabase/migrations/0002_harden_profile.sql` | Ücretsiz ders seçimi güvenlik yaması |
   | 3 | `supabase/migrations/0003_spaced_review.sql` | Yanlış soruların ertesi gün tekrarı (**yeni uygulama sürümü için şart**) |
   | 4 | `supabase/migrations/0004_appointment_rpcs.sql` | Atama Takip fonksiyonları (içindeki liste fonksiyonları 0005 ile değişir) |
   | 5 | `supabase/migrations/0005_appointments_v2.sql` | **Atama Takip "Sunucu hatası" düzeltmesi**, meslek takibi, KPSS'siz ilan ayrımı, yeni kaynaklar, sahte örnek ilanların silinmesi |
   | 6 | `supabase/seed/sample_questions.sql` | 6 örnek soru (Matik'i denemek için) |
   | 7 | `supabase/seed/sample_exams.sql` | Sınav tarihleri (ana ekran sayacı için) |
   | 8 (isteğe bağlı) | `supabase/seed/sample_test_exam.sql` | ~20 gün sonrası test sınavı: geri sayım kartını görmek için |

   Sahte ilan dosyası (`sample_appointments.sql`) kaldırıldı; gerçek ilanlar `scraper/` botuyla gelir (aşağıda "İlan botu").

   Hata alırsan **hangi dosyada, hangi mesajı aldığını bana yaz**. Aynı dosyayı iki kez çalıştırmak 0001/0002 için hata verir; 0003, 0004 ve 0005 tekrar çalıştırılabilir; seed dosyaları ise tekrar çalıştırılabilir.
3. **Giriş ayarı (geliştirme için):** Sol menü → **Authentication** → **Sign In / Providers** (veya *Providers*) → **Email** → **"Confirm email" seçeneğini kapat** → Save.
   Açık kalırsa kayıt olduktan sonra e-postandaki bağlantıya tıklamadan giriş yapamazsın (uygulama bunu bildirir ama deneme sırasında can sıkar). Yayına çıkarken tekrar aç.
4. **Anahtarları al:** **Project Settings** (dişli) → **API** (yeni arayüzde "API Keys" / "Connect" bölümü olabilir):
   - **Project URL** → `https://xxxx.supabase.co`
   - **anon / public** anahtar (yeni adıyla *publishable key* de olabilir) → ikisi de çalışır.
   - ⚠️ **`service_role` / secret anahtarı ASLA uygulamaya veya bu rehberdeki dosyalara koyma.** Yalnızca public/anon anahtar.

**Kontrol:** SQL Editor'de `select count(*) from public.questions;` çalıştır → **6** dönmeli.

---

## 4) Anahtar dosyasını hazırla

Proje klasöründe:

1. `env.example.json` dosyasını kopyala, adını **`env.json`** yap.
2. İçini kendi değerlerinle doldur:

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ... veya sb_publishable_...",
  "RC_API_KEY_ANDROID": "",
  "RC_API_KEY_APPLE": ""
}
```

`RC_API_KEY_*` alanlarını **şimdilik boş bırak** (satın alma, Bölüm 9'daki ayrı kurulumdur). `env.json` zaten `.gitignore`'dadır; paylaşma.

---

## 5) Projeyi hazırla (platform klasörlerini üret)

Bu zip'te `android/`, `ios/`, `windows/`, `macos/`, `web/` klasörleri **yoktur**; Flutter bunları senin bilgisayarında üretir.

Zip'i bir klasöre aç, o klasörde terminal aç (VS Code: *Terminal → New Terminal*):

```
flutter create . --platforms=windows,macos,android,ios,web --org com.kpsspusula
```

> `--org` Android/iOS paket adının ön ekidir. Mağazaya yüklemeden önce kendi alan adına göre belirle; **yayından sonra değiştirilemez**. Denemek için bu hâliyle bırakabilirsin.
> Yalnızca kullanacağın platformları yazman da yeter (ör. `--platforms=windows,web`).

Ardından Flutter'ın otomatik eklediği örnek test dosyasını **sil** (projeyle uyumsuzdur, analiz hatası verir):

```
del test\widget_test.dart        (Windows)
rm test/widget_test.dart         (macOS)
```

Sonra paketleri indir:

```
flutter pub get
```

**Kontrol:** `flutter pub get` "Got dependencies!" ile bitmeli. Hata verirse çıktıyı bana yapıştır.

---

## 6) Çalıştır

Anahtarlar `--dart-define-from-file=env.json` ile uygulamaya verilir. **Bu parametre olmadan uygulama "Eksik yapılandırma" ekranı açar.**

```
flutter run --dart-define-from-file=env.json -d chrome
flutter run --dart-define-from-file=env.json -d windows
flutter run --dart-define-from-file=env.json -d macos
flutter run --dart-define-from-file=env.json -d <telefon-kimliği>
```

(`flutter devices` kimlikleri gösterir.) VS Code kullanıyorsan `F5` ile de çalışır; `.vscode/launch.json` parametreyi zaten içerir.

İlk derleme (özellikle Windows/Android) **birkaç dakika** sürebilir; sonrakiler hızlıdır.

---

## 7) İlk denemede ne görmelisin?

1. **Kayıt ol** (ad, e-posta, şifre ≥ 6 karakter, eğitim seviyesi) → otomatik giriş.
2. **Onboarding:** tam **2** ücretsiz ders seç (yalnızca bir kez seçilir).
3. **Ana sayfa:** sınav sayacı, bugünkü istatistik, kilitli ilan kartı.
4. **KPSS Matik:** ders seç → soru → şık işaretle → doğru cevap, her şık için "neden yanlış", "Akılda kalsın" kartı.
5. Soruyu işaretlediğin anda "çözüldü" olur; aynı soru bir daha gelmez. Tüm soruları bitirince "soru kalmadı" ekranı çıkar (örnek veri sadece 6 soru).
6. **Ayarlar:** tema (sistem/açık/koyu), çıkış.

### Sınav sayacı boş görünürse
`sample_exams.sql` içindeki tarihler **2026**'dır ve **ÖSYM duyurularından mutlaka doğrulanmalıdır**. Bugünün tarihine göre seviyendeki sınav geçmişse "yaklaşan sınav bulunamadı" görünür; bu hata değildir. Sayacı denemek için SQL Editor'de:

```sql
insert into public.exams (name, education_levels, exam_date)
values ('TEST SINAVI', '{lise,onlisans,lisans}', now() + interval '20 days 3 hours');
```

### Premium'u elle açıp denemek (satın alma kurmadan)
Premium özellikleri (sınırsız soru, tüm dersler, ilan kartı) satın almadan test etmek için SQL Editor'de, kendi e-postanla:

```sql
insert into public.subscriptions (user_id, revenuecat_app_user_id, status, store, expires_at, will_renew)
select id, id::text, 'active', 'promotional', now() + interval '30 days', false
from public.users where email = 'SENIN@EPOSTAN.COM'
on conflict (user_id) do update
  set status = 'active', expires_at = excluded.expires_at;
```

Uygulamada ana sayfada aşağı çekerek yenile → "Premium · Sınırsız soru" görünür. Geri almak için:

```sql
update public.subscriptions set status = 'expired' where user_id = (select id from public.users where email = 'SENIN@EPOSTAN.COM');
```

---

## 8) Sık karşılaşılan sorunlar

| Belirti | Neden / çözüm |
|---|---|
| Ekranda **"Eksik yapılandırma: SUPABASE_URL…"** | `--dart-define-from-file=env.json` parametresini unuttun veya `env.json` boş. |
| `flutter pub get` **"symlink"** hatası (Windows) | Geliştirici Modu kapalı. Bölüm 2'ye bak. |
| **"Unable to find suitable Visual Studio toolchain"** | Visual Studio'da *Desktop development with C++* yüklü değil. |
| Kayıttan sonra **giriş yapılamıyor / "E-posta doğrulanmadı"** | Supabase'de *Confirm email* açık. Bölüm 3, adım 3. |
| Giriş sonrası **"Profil yüklenemedi"** | `0001_init.sql` çalıştırılmamış veya hata vermiş (`public.users` tablosu yok). |
| Matik'te **"Sunucu hatası"** | `0001`/`0002` eksik ya da soru yok. SQL Editor'de `select count(*) from public.questions;` ile bak. |
| **macOS'ta her istek "bağlantı hatası"** | macOS uygulamaları varsayılan olarak internete çıkamaz. `macos/Runner/DebugProfile.entitlements` **ve** `macos/Runner/Release.entitlements` dosyalarının `<dict>` içine şunu ekle: `<key>com.apple.security.network.client</key><true/>` |
| **Android'de yayın (release) sürümünde internet yok** | `android/app/src/main/AndroidManifest.xml` içinde `<manifest>` altına ekle: `<uses-permission android:name="android.permission.INTERNET"/>` (debug'da gerekmez, release'de gerekir). |
| `flutter analyze` kırmızı hatalar | Çıktıyı bana yapıştır. |
| Telefon `flutter devices`'ta görünmüyor | USB hata ayıklama açık mı, telefonda "bu bilgisayara izin ver" onayı verildi mi? |

---

## 9) Satın alma (RevenueCat) – şimdilik atlayabilirsin

Uygulama RevenueCat anahtarı **olmadan da çalışır**; "Premium'a geç" ekranı "satın alma yapılandırılmamış" der. Gerçek satın alma için gereken tek seferlik hazırlık:

1. Google Play Console ve/veya App Store Connect'te abonelik ürünlerini oluştur (geliştirici hesabı gerekir; Google ~25 USD tek sefer, Apple 99 USD/yıl).
2. https://www.revenuecat.com → proje → Android/iOS uygulamalarını bağla → **Entitlement** adı tam olarak **`premium`** olsun → ürünleri bir **Offering**'e ekle (varsayılan/current).
3. RevenueCat'in verdiği **public SDK anahtarlarını** `env.json` içine yaz (`RC_API_KEY_ANDROID` → `goog_...`, `RC_API_KEY_APPLE` → `appl_...`).
4. Sunucu tarafı (satın almayı Supabase'e yazan webhook) için `supabase/functions/revenuecat-webhook/README.md` dosyasındaki adımları izle.

Masaüstünde (Windows/Chrome) satın alma **yapılamaz**; aynı hesapla telefondan Premium olursan masaüstü uygulamada da Premium görünür (durum Supabase'den okunur).

---

## 10) Gizlilik ve güvenlik hatırlatması

- `env.json`'u asla paylaşma/commit'leme; `service_role` anahtarını uygulamaya hiçbir koşulda koyma.
- Anon anahtar zaten uygulamanın içinde açık olacağı için güvenlik **Supabase tarafındaki kurallarla (RLS)** sağlanır; bu projedeki `0001/0002` dosyaları bunu yapar.

## İlan botunu çalıştırma (gerçek atama ilanları)

Bot ayrı bir Python programıdır (`scraper/` klasörü); uygulamadan bağımsız çalışır ve ilanları Supabase'e yazar. Python 3.11+ gerekir.

```bash
cd scraper
python -m venv .venv && source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 0) İŞKUR gibi JavaScript'li siteler için bir kez:  pip install -r requirements-js.txt && playwright install chromium

# 1) Önce veritabanına YAZMADAN dene: sitelerden ne bulduğunu listeler
python run.py --dry-run --debug-dir debug

# 2) Gerçek çalıştırma: scraper/.env.example dosyasını .env olarak kopyala, değerleri doldur
python run.py                      # bir kez tara
python run.py --daemon --interval 3600   # saatte bir sürekli tara
```

`.env` içine **service_role** anahtarı yazılır (Supabase → Project Settings → API → `service_role`). Bu anahtar yalnızca botun `.env` dosyasında durur; **Flutter uygulamasına, `env.json`'a ya da bana yazma/paylaşma.**

Önce `--dry-run` çıktısını kontrol et. Hangi sitenin 0 ilan döndürdüğünü ya da yanlış satırlar getirdiğini bana yaz (gerekirse `debug/` klasöründeki ilgili HTML dosyasını da ilet); site yapısına göre ayar yapılır.

Bir site boş dönerse `python run.py --source iskur --discover` çalıştırıp `debug/` klasörünü (özellikle `*.xhr.json` dosyalarını) bana ilet; sitenin gerçek veri adresine göre bot ayarlanır. Bot, sitelerin `robots.txt` kurallarına uyar; kapalı olan adresleri atlar.
