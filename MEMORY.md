# KPSS Pusula — Proje Hafızası

_Son güncelleme: 20 Ekim 2026. Ayrıntılar `memory-bank/` klasöründe; oturum başında önce orayı oku (sıra: projectbrief, productContext, systemPatterns, techContext, progress, activeContext)._

## Tek Bakışta
Flutter uygulaması (Riverpod + go_router) + Supabase (Postgres/Auth/RLS/RPC/Edge Functions) + RevenueCat + Python ilan botu. İki ürün: **KPSS Matik** (soru çözme) ve **Atama Takip** (güncel kamu alım ilanları). Kullanıcı Türkçe konuşur, yerelde Mac'te `kpss_pusula4` klasöründe dener; bulut çalışma kopyası `kpss_pusula2`.

## Durum
- Yazıldı ve çalışıyor (bot tarafı test edildi): ilan botu (75 test), tekrar önleme, eskiyen ilanı silme, Kariyer Kapısı İş e-Alım JSON API, SQL 0001–0010.
- Yazıldı ama DERLENMEDİ/denenmedi: Flutter tarafı (bağlantıya git, şehir seçici dahil), RevenueCat gerçek mağazada, push bildirim sunucu tarafı.
- Eksik: ilan.gov.tr ve İŞKUR e-Şube scraper'ları, Resmî Gazete erişimi (kullanıcı ağında zaman aşımı), Flutter push, gerçek soru bankası, ÖSYM tarih botu, Firebase'de bot barındırma.

## Alınan Kararlar
- `service_role` anahtarı yalnızca `scraper/.env` / GitHub Secrets'ta; uygulamaya ve `env.json`'a asla.
- Yalnızca güncel ilan: bitiş geçmediyse (veya tarihsizse yayın ≤ 45 gün) göster; süresi biteni sil; takip edilen satırı silme.
- Tekrar: kalıcı `stable_id` + içerik imzası (kurum+başlık+bitiş günü). Kararsızsa EKLE.
- Şehir filtresi tam eşleşme + 81 il seçici. robots.txt'e her zaman uyulur.
- Kimlikte Python `hash()` yasak. Tarihler Türkiye saati (UTC+3) ile elle ayrıştırılır.

## Çözülen Hatalar
`keep` özniteliği hatası · uydurma Resmî Gazete `.pdf` adresi (geri alındı) · yerelyonetimler `hash()` kimliği yüzünden çift ilan · "Muş" aramasında "Gümüşhane" · `text_utils` eksik (kısmi zip) · Python komutlarının yanlış dizinden çalıştırılması.

## Açık İşler (öncelik sırasıyla)
1. Kullanıcı yerel testi: `flutter pub get`, migration 0010, `cd scraper && python3 run.py --source all`.
2. **Hatırlatılacak:** Firebase kurulumu (botu bilgisayarsız çalıştırma) ve Supabase service key'i döndürme.
3. ilan.gov.tr ABP API scraper'ı → İŞKUR e-Şube → Sayıştay sayfalama.
4. Flutter push, gerçek sorular, doğrulanmış sınav tarihleri, RevenueCat mağaza testi.
5. `DOSYALAR.md`/`KURULUM.md` güncelle (0008–0010 ve yeni dosyaları ekle).

## Çalışma Kuralları
- Yanıtlar Türkçe, kısa ve çözüm odaklı. Sorun bulunca çöz.
- Teslim: değişen dosyalar klasör yapısıyla; tam paket istenirse `.env` ve `env.json` hariç.
- Bot komutları `scraper/` içinden.
