# Proje Özeti

## Proje Adı
KPSS Pusula

## Ana Hedef
KPSS'ye hazırlanan ve kamuya atanmak isteyen kişilere iki şey sunan bir Flutter uygulaması: (1) soru çözme (KPSS Matik) ve (2) güncel kamu personel alım ilanlarının takibi (Atama Takip). İlanları bir Python botu otomatik toplar.

## Temel Gereksinimler
- Kayıt/giriş, eğitim seviyesi (lise, önlisans, lisans) ve ders seçimi içeren onboarding.
- KPSS Matik: günlük kotalı soru çözme, açıklamalar, ezber kartları, yanlış soruların ertesi gün tekrarı.
- Ana ekran: sınav geri sayımı, günlük istatistik, son ilanlar şeridi (Premium).
- Atama Takip: yalnızca GÜNCEL ilanlar; şehir, bölüm, KPSS kodu, KPSS'li/KPSS'siz, "mesleklerim" filtreleri; ilanı takip etme; bağlantıya git / kopyala.
- Abonelik: RevenueCat ile Premium (Android/iOS), sunucu tarafı webhook.
- Bot: saatlik çalışır, robots.txt'e uyar, aynı ilanı ikinci kez eklemez, eskiyen ilanı siler.

## Kapsam
- İçinde: mobil + masaüstü + web Flutter istemcisi, Supabase (Postgres, Auth, RLS, RPC, Edge Functions), ilan botu.
- Dışında (şimdilik): ÖSYM sınav tarihi botu, gerçek soru bankası, uygulama mağazası yayını.

## Değişmez Kurallar
- `service_role` anahtarı ASLA uygulamada veya paylaşılan dosyada olmaz. `env.json` yalnızca anon key ve RevenueCat public key içerir; service key yalnızca `scraper/.env` veya GitHub Secrets'ta durur.
- Kullanıcı yalnızca değiştirilen dosyaları teslim almak ister ("diğer dosyalar karışmasın"). Tam paket istediğinde `.env`, `env.json` gibi gizli dosyalar zipe konmaz.
- Sorun bulmak yetmez, çözülmelidir.
