# KPSS Pusula — İlan Botu

Kamu personel alım ilanlarını tarar ve Supabase `appointments` tablosuna **yalnızca yeni olanları** ekler.

| Kaynak anahtarı | Site | KPSS şartı |
|---|---|---|
| `kariyerkapisi` | kariyerkapisi.cbiko.gov.tr | varsayılan evet |
| `yerelyonetimler` | yerelyonetimler.csb.gov.tr/duyurular | evet |
| `pgm_adalet` | pgm.adalet.gov.tr (duyurular) | varsayılan evet |
| `kamuilan` | kamuilan.sbb.gov.tr | varsayılan hayır |
| `iskur` | iskur.gov.tr (kurum dışı kamu işçi alımı) | varsayılan hayır |

İlan metninde "KPSS'siz" / "KPSS şartı aranmaz" geçerse KPSS'siz, "KPSS" geçerse KPSS'li işaretlenir.

## Kurulum ve çalıştırma
```bash
pip install -r requirements.txt
python run.py --dry-run --debug-dir debug   # DB'ye yazmadan ne bulduğunu listeler, ham sayfaları debug/ içine kaydeder
python run.py --source pgm_adalet           # tek kaynak, DB'ye yazar
python run.py --daemon --interval 3600      # saatte bir sürekli tara
python -m unittest discover -s tests -t .   # testler
```
`.env.example` dosyasını `.env` olarak kopyala: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (service_role).
> ⚠️ `service_role` anahtarı yalnızca bu botta kullanılır; Flutter uygulamasına ve `env.json`'a asla konmaz.

## Yalnızca güncel atama ilanları
Bot haber, sınav sonucu, giriş belgesi, iptal ve menü bağlantılarını almaz; başlıkta alım/atama ifadesi arar
(`scrapers/base.py` → `is_hiring_title`). Ayrıca **güncellik** denetimi yapar: son başvuru tarihi geçmiş ilan alınmaz;
bitiş tarihi bilinmiyorsa yayın tarihi 45 günden eskiyse alınmaz; hiç tarihi olmayan ilan alınmaz (eski ilanın yeni gibi görünmemesi için).
- `yerelyonetimler`: gerçek sayfa yapısına göre yazıldı (yalnızca "Duyurular" kartları; haberler ve menü yok). Başlıktan il, kurum ve unvan çıkarılır.
- `pgm_adalet`: duyuru bağlantı yapısına göre yazıldı; tarih bağlantının sonundaki damgadan alınır.
- `kariyerkapisi`, `kamuilan`, `iskur`: sayfa yapısı henüz görülmedi; genel yöntemle çalışır. İlk çalıştırmada `--discover` çıktısıyla bunlara da özel ayar yapılacak.

## JavaScript ile oluşan siteler (Playwright)
Bazı siteler (ör. İŞKUR) ilan listesini sayfa açıldıktan sonra JavaScript ile yükler; düz HTTP isteği boş döner.
Bu kaynaklar gerçek bir tarayıcıyla açılır; statik HTML'de ilan bulunamayan diğer kaynaklar da otomatik olarak tarayıcıyla bir kez daha denenir.
```bash
pip install -r requirements-js.txt
playwright install chromium
```
**Site yapısını keşfetmek için:** `python run.py --source iskur --discover` sayfayı tarayıcıyla açar, ham HTML'i ve sayfanın arka planda yaptığı tüm XHR/JSON isteklerini `debug/*.xhr.json` içine kaydeder. Sitenin gerçek veri adresi (JSON API) bulunursa, HTML kazımak yerine doğrudan o kullanılır; bu daha sağlam ve siteye daha az yük bindirir.

## Davranış
- **robots.txt'e uyar** (hem düz istekte hem tarayıcıda): bir adres botun kullanıcı adı (`KPSSPusulaBot`) için kapalıysa o adres atlanır, log'da uyarı çıkar. Bu denetimi atlatan bir seçenek bilerek yoktur. Atlanan bir site için sitenin sahibinden yazılı izin/veri akışı (RSS, API) istemek doğru yoldur. İstekler arası 1,5 sn beklenir.
- Süresi dolmuş, "sonuç/liste/yer ve tarih" duyurusu olan ve test ilanları elenir.
- Aynı ilan ikinci taramada eklenmez; `published_at` kaymaz, yeni-ilan bildirimi tekrar gitmez.
- Bir kaynağın hatası diğerlerini durdurmaz.

## Bilinen sınırlar
Kaynak siteler geliştirme ortamından doğrulanamadı (yalnızca `pgm.adalet.gov.tr` bağlantı yapısı gözlemlendi). `sources.py` içindeki kaynaklar sayfadaki bağlantılardan ilan toplar; bir site beklenenden farklı çıkarsa `--dry-run --debug-dir debug` çıktısıyla `list_urls`/süzgeçler ayarlanır. Sitelerin kendi API'si veya RSS'i varsa onu kullanmak HTML kazımadan daha dayanıklıdır.
