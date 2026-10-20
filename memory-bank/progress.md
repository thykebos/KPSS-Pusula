# İlerleme

## Çalışanlar (20 Ekim 2026 itibarıyla)
- Auth, onboarding, KPSS Matik (kota, ezber kartı, seçenek açıklamaları, ertesi gün tekrarı), ana ekran, ayarlar (seviye/şifre/meslek etiketleri), paywall + RevenueCat servisi, webhook ve bildirim Edge Function'ları YAZILDI. Gerçek mağaza ve cihazda denenmedi.
- Atama Takip: güncel-ilan filtresi, şehir seçici (81 il, tam eşleşme), "Bağlantıya Git" + "Bağlantıyı Kopyala", hızlı filtreler, sonsuz kaydırma, takip.
- Bot: kariyerkapisi (RSS), kariyerkapisi_isealim (JSON API, doğrulandı, ~30 ilan), yerelyonetimler, pgm_adalet çalışıyor; tekrar önleme, eskiyen ilanı silme ve saat dilimi doğru. 75 test geçiyor. 0010 migration ve reset SQL, PostgreSQL 16'da denendi.

## Yapılacaklar
1. ilan.gov.tr için ABP API scraper'ı (API tabanı `https://www.ilan.gov.tr/api/api/services/app/...`; ilan-listesi uç noktası henüz bulunamadı; Kamu-Akademik Personel ~116 ilan).
2. İŞKUR e-Şube: veri uç noktası yakalanmadı.
3. Sayıştay: 2.–6. sayfalar boş (düşük öncelik).
4. Resmî Gazete: kullanıcının ağından erişilemiyor (neden bilinmiyor); Firebase/başka ağdan çalıştırınca denenecek.
5. Botu kullanıcının bilgisayarı olmadan çalıştırmak (Firebase; kullanıcı hatırlatılmak istedi: "firebase setupu bana hatırlatırsın"). Workflow'daki kaynak listesi `source` açıklaması güncellenmeli.
6. Flutter push (`firebase_messaging`, cihaz token kaydı), ÖSYM sınav tarihi botu, gerçek soru bankası, doğrulanmış sınav tarihleri, RevenueCat gerçek mağaza testi.
7. Supabase service_role anahtarı döndürülmeli (terminalde, sohbette ve bir zip içinde göründü; yapıldığı doğrulanmadı).
8. `DOSYALAR.md` ve `KURULUM.md` eski: 0007'de bitiyor, 0008–0010, dedup.py, kariyerkapisi_api.py, resmigazete.py, şehir seçici ve 75 teste değinmiyor; güncellenmeli.

## Bilinen Sorunlar
- Dart kodu derlenmedi (url_launcher, şehir seçici ve filtre değişiklikleri dahil).
- Kullanıcı bir seferde `lib/main.dart` bulunamadı hatası aldı (zip yanlış yere açılmış olabilir); bir başka seferde `text_utils` bulunamadı (değişmeyen dosya zip'te yoktu, elle gönderildi). Bu yüzden tam paket teslim edilir.
- Matik: soru görseli yalnızca tam http adresiyle; "boş bırak" soruyu tüketir (bilinçli).

## Karar ve Hata Geçmişi
- Kariyer Kapısı İş e-Alım HTML'i yerine JSON API (`POST api.kariyerkapisi.gov.tr/api/ilan/GetIseAlimPage`) kullanıldı; bağlantı `IlanDetay?i=<guid>`, RSS ile aynı kimlik.
- Hata: `keep` eksik özniteliği (özel `scrape` içinde çağrılıyordu) → kaldırıldı, sonra `post_json` kullanan sürüme yeniden yazıldı.
- Hata: Resmî Gazete için uydurma `.pdf` günlük adresi denendi (dayanaksız), `DAILY_URL` NameError bıraktı → `.htm` günlük sayfaya geri alındı. Zaman aşımı hâlâ çözülmedi.
- Hata: yerelde tekrar çalıştırınca aynı ilanlar ikinci kez ekleniyordu. Sebep: yerelyonetimler'de kimlik `hash(url)` (her süreçte farklı) + aynı ilanın iki kaynakta çıkması. Çözüm: `stable_id` + içerik tabanlı `dedup.py` + 0010 temizlik.
- Hata: şehir araması "içerir" idi ("Muş" → "Gümüşhane"). Çözüm: tam eşleşme + seçici.
- Karar: eskiyen ilan hem sunucuda filtrelenir hem silinir; takip edilen ilan satırı silinmez.
- Karar: kararsız durumda ilan eklenir (yanlış birleştirme > ufak tekrar).
