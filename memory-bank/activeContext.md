# Aktif Bağlam

## Şu Anki Odak
Kullanıcı son teslimi (dört istek: tekrar önleme, eskiyen ilanın kalkması, bağlantıya git, şehir seçimi) yerelde (`kpss_pusula4`, Mac) deniyor. 20 Ekim 12:07'de tam proje zip'i ve bu hafıza dosyalarını istedi.

## Son Değişiklikler
- Eklendi: `scraper/dedup.py`, `supabase/migrations/0010_expiry_and_dedup.sql`, `turkish_cities.dart`, `city_picker_sheet.dart`, `scraper/tests/test_dedup_and_isealim.py`.
- Değişti: `run.py`, `database.py` (`known_rows`), `http_client.py` (`post_json`), `yerelyonetimler.py`, `resmigazete.py` (geri alındı), `kariyerkapisi_api.py`, `reset_bot_appointments.sql`, ilan listesi/detay/filtre ekranları, `appointment_filter.dart`, `appointment_providers.dart`, `dashboard_repository_impl.dart`, `pubspec.yaml`.
- Kullanıcının yerel kurulumunda iki sorun çıktı ve çözüldü/yönlendirildi: `text_utils.py` eksikti (elle gönderildi); `lib/main.dart` bulunamadı (zip yanlış klasöre açılmış olabilir; tam paketle giderilecek).

## Sonraki Adımlar
1. Kullanıcı tam zip'i açar, `flutter pub get`, 0010'u Supabase'de çalıştırır, istenirse reset SQL, sonra `cd scraper && python3 run.py --source all`.
2. Derleme hatası olursa metni yapıştırır → düzelt.
3. İstenirse: ilan.gov.tr scraper'ı, Firebase kurulumu (hatırlatma sözü verildi), anahtar döndürme hatırlatması.

## Aktif Kararlar ve Dikkat
- Dart derlenemediği için riskli nokta Flutter tarafı (özellikle `copyWith(clearCity)`, `showCityPicker` dönüş değerleri: ad / `''` = tüm şehirler / `null` = kapatıldı).
- Kullanıcıya tam paket verilirken `.env`, `env.json` zip'e konmaz; kullanıcıdan kendi zip'ine `.env` koymaması istendi.

## Önemli Kalıplar ve Tercihler
- Kullanıcı Türkçe yazar; yanıtlar Türkçe, kısa, çözüm odaklı. Hatayı bulmak yetmez, çözüm teslim edilir.
- Değişen dosyalar klasör yapısıyla verilir; kullanıcı yerelde dosyaların karışmasını istemez.
- Komutlar `scraper/` içinden çalıştırılır.

## Öğrenilenler
- `hash()` kimlik için güvenilmezdir; kalıcı kimlik kullan.
- Eksik dosya sorunlarını azaltmak için kısmi zip yerine ilgili dosyanın bağımlılıklarını da kontrol et.
- Kariyer Kapısı verisi için JSON API, RSS ve HTML'den daha güvenilir; ilan.gov.tr'de de aynı yaklaşım denenecek.
