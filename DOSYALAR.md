# KPSS Pusula – Dosya Rehberi

Durum etiketleri: ✅ yazıldı · ⏳ sıradaki adımlarda yazılacak

**Önce `KURULUM.md`'yi oku**: Flutter'ı nasıl kuracağın, Supabase'i nasıl hazırlayacağın ve uygulamayı nasıl çalıştıracağın orada.

## İlerleme özeti

| Adım | Konu | Durum |
|---|---|---|
| 1 | Temel iskelet: tema, router, giriş/kayıt, onboarding | ✅ |
| 2 | KPSS Matik (soru çözme) | ✅ |
| 3 | Ana ekran (sınav sayacı, günlük istatistik, Premium ilan kartı) | ✅ |
| 4 | Abonelik: paywall, RevenueCat, sunucu webhook'u | ✅ (yazıldı, gerçek mağazayla denenmedi) |
| 5 | Atama Takip ekranları + push bildirim | ✅ |
| 6 | Python scraper botu | ✅ |

## 1) Veritabanı ve sunucu (Supabase)

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `supabase/migrations/0001_init.sql` | ✅ | Ana şema: tablolar, enum'lar, RLS güvenlik kuralları ve RPC fonksiyonları (soru getirme, cevap gönderme, dashboard istatistikleri, premium kontrolü). Premium ve ücretsiz kota kuralları burada sunucu tarafında uygulanır. (İlk adımda sunduğum `schema.sql` ile aynıdır.) |
| `supabase/migrations/0002_harden_profile.sql` | ✅ | Güvenlik yaması: kullanıcı kendi `free_subjects` alanını doğrudan değiştirip "2 ders" kuralını delemesin diye sütun yetkilerini daraltır ve `set_free_subjects()` fonksiyonunu ekler. |
| `supabase/seed/sample_questions.sql` | ✅ | Matik'i denemek için 6 örnek soru (her şıkta "neden doğru/yanlış" açıklaması ve mnemonik ile). Tekrar çalıştırılabilir. Örnek içeriktir, gerçek soru bankanla değiştirilecek. |
| `supabase/migrations/0003_spaced_review.sql` | ✅ | Aralıklı tekrar: yanlış/boş sorular ertesi gün (İstanbul saatiyle) yeniden sorulur, doğrular bir daha çıkmaz. Tekrar soruları günlük kotaya sayılır; ana ekranda "tekrar bekliyor" sayısı görünür. |
| `supabase/seed/sample_test_exam.sql` | ✅ | Geri sayımı denemek için ~20 gün sonrası test sınavı (silme komutu içinde). |
| `supabase/seed/sample_exams.sql` | ✅ | Ana ekran geri sayımı için sınav tarihleri. **Tarihleri osym.gov.tr'den mutlaka doğrula**; bazıları geçmişte kalmış olabilir. |
| `supabase/functions/revenuecat-webhook/index.ts` | ✅ | Edge Function: RevenueCat'in satın alma olaylarını gizli anahtarla doğrular ve `subscriptions` tablosuna yazar. Premium'un **gerçek kaynağı** budur; telefon taraflı sahtecilik işe yaramaz. |
| `supabase/functions/revenuecat-webhook/map_event.ts` | ✅ | Olay → abonelik durumu mantığı (iptal edince erişim dönem sonuna kadar sürer, iade hemen bitirir, ödeme sorunu ek süre sayılır, sırasız olay koruması). |
| `supabase/functions/revenuecat-webhook/map_event.test.ts` | ✅ | Bu mantığın 15 birim testi (bu ortamda çalıştırıldı, 15/15 geçti). |
| `supabase/functions/revenuecat-webhook/README.md` | ✅ | Webhook'u dağıtma ve RevenueCat'e bağlama adımları. |
| `supabase/functions/notify-new-appointment/index.ts` | ✅ | Yeni ilan eklenince Premium kullanıcılara FCM push bildirimi gönderir. |
| `supabase/functions/notify-new-appointment/README.md` | ✅ | Firebase kurulum, secret ayarı ve webhook bağlama adımları. |

## 2) Uygulama çekirdeği (`lib/`)

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `main.dart` | ✅ | Başlangıç noktası: yapılandırmayı kontrol eder, Supabase'i başlatır, uygulamayı açar. Anahtarlar eksikse açıklayıcı bir hata ekranı gösterir. |
| `app.dart` | ✅ | Ana uygulama kabuğu: tema (açık/koyu), Türkçe dil ayarı ve router bağlantısı. |
| `core/config/env.dart` | ✅ | Supabase adresi/anahtarı ve RevenueCat public anahtarlarını derleme sırasında okur (`service_role` asla buraya girmez). |
| `core/config/app_constants.dart` | ✅ | Ortak sabitler: günlük 20 soru (yalnızca gösterim; asıl kural sunucuda), 2 ücretsiz ders, masaüstü genişlik eşiği. |
| `core/storage/shared_prefs_provider.dart` | ✅ | Cihazda küçük ayarları saklayan SharedPreferences'ı uygulamaya sağlar. |
| `core/theme/app_colors.dart` | ✅ | Marka renkleri: lacivert `#1A237E`, mercan `#FF7043`, açık gri arkaplan. |
| `core/theme/app_theme.dart` | ✅ | Açık ve koyu tema tanımları (Material 3). |
| `core/theme/theme_provider.dart` | ✅ | Kullanıcının tema seçimini (sistem/açık/koyu) tutar ve hatırlar. |
| `core/network/supabase_client_provider.dart` | ✅ | Supabase istemcisini tüm uygulamaya tek noktadan sunar. |
| `core/error/app_exception.dart` | ✅ | Kullanıcıya gösterilecek Türkçe hata nesnesi. |
| `core/error/error_mapper.dart` | ✅ | Sunucu hatalarını ("daily_limit_reached" gibi) anlaşılır Türkçe mesajlara çevirir. |
| `core/utils/responsive.dart` | ✅ | Ekranın masaüstü genişliğinde olup olmadığını söyler. |
| `core/widgets/adaptive_scaffold.dart` | ✅ | Mobilde alt menü, masaüstünde yan menü gösteren ortak sayfa iskeleti. |
| `core/widgets/placeholder_screen.dart` | ✅ | Henüz yazılmamış modüller için geçici ekran (şu an yalnızca Atama Takip'te). |
| `core/widgets/error_view.dart` | ✅ | Ortak hata görünümü: mesaj + "Tekrar dene" düğmesi. |
| `core/router/routes.dart` | ✅ | Sayfa adreslerinin listesi (Matik oturumu ve paywall dahil). |
| `core/router/app_router.dart` | ✅ | Sayfa yönlendirme ve kuralları: giriş yoksa login, ders seçimi yoksa onboarding, hazırsa ana sayfa. Soru çözme ekranı alt menüsüz, tam ekran açılır; paywall da tam ekrandır. |
| `shared/models/education_level.dart` | ✅ | Lise / Önlisans / Lisans seçeneği (veritabanı enum'uyla eşleşir). |
| `shared/models/subject.dart` | ✅ | Tarih, Coğrafya, Vatandaşlık, Matematik, Türkçe dersleri (veritabanı enum'uyla eşleşir). |

## 3) Kimlik doğrulama ve onboarding (`features/auth/`)

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `domain/entities/user_profile.dart` | ✅ | Kullanıcı profilinin uygulamadaki modeli; onboarding gerekip gerekmediğini bilir. |
| `domain/auth_repository.dart` | ✅ | Giriş/kayıt/profil işlemlerinin sözleşmesi (arayüz). |
| `data/auth_repository_impl.dart` | ✅ | Bu işlemlerin Supabase ile gerçek uygulaması. Kayıtta eğitim seviyesini gönderir, onboarding'de dersleri `set_free_subjects` ile kaydeder. |
| `presentation/providers/auth_providers.dart` | ✅ | Oturum durumunu ve kullanıcı profilini uygulama genelinde izler. |
| `presentation/screens/login_screen.dart` | ✅ | Giriş ekranı. |
| `presentation/screens/register_screen.dart` | ✅ | Kayıt ekranı; seviye seçimi burada yapılır. Kayıttan sonra kalıcı "Hesabını onayla" ekranı ve 60 sn beklemeli yeniden gönder düğmesi. |
| `presentation/screens/onboarding_screen.dart` | ✅ | İlk girişte 2 ücretsiz dersi ve (isteğe bağlı) bölümü seçtirir. |
| `presentation/screens/splash_screen.dart` | ✅ | Profil yüklenirken bekleme ekranı; hata olursa "Tekrar dene". |
| `presentation/widgets/auth_shell.dart` | ✅ | Üç ekranın ortak görünümü. |
| `presentation/widgets/education_level_picker.dart` | ✅ | Lise/Önlisans/Lisans seçici. |

## 4) KPSS Matik – soru çözüm (`features/matik/`)

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `domain/entities/question.dart` | ✅ | Ekrandaki soru ve şıkları. Doğru cevap bilgisi bilerek yok: sunucu cevap işaretlenene kadar göndermez. |
| `domain/entities/answer_result.dart` | ✅ | Cevap sonrası dönen veri: doğru şık, **her şıkkın açıklaması**, mnemonik, kalan hak. |
| `domain/entities/quota.dart` | ✅ | Günlük hak ve Premium durumu. |
| `domain/question_repository.dart` | ✅ | Soru getirme / cevap gönderme / kota okuma sözleşmesi. |
| `data/question_repository_impl.dart` | ✅ | Sözleşmenin Supabase uygulaması (`get_question_batch`, `submit_answer`, `get_dashboard_stats`). |
| `presentation/providers/matik_providers.dart` | ✅ | Repository ve kota sağlayıcıları. |
| `presentation/providers/question_session_controller.dart` | ✅ | Oturumun beyni: şık işaretlendiği an kaydeder, sonucu gösterir, sıradaki soruya geçer, paket bitince yenisini ister, hak bitince durur. |
| `presentation/screens/subject_select_screen.dart` | ✅ | Ders seçimi. Ücretsiz kullanıcıda seçmediği dersler kilitli görünür; dokununca "Premium" kısayolu çıkar. |
| `presentation/screens/question_screen.dart` | ✅ | Soru çözme ekranı: soru, ipucu, şıklar, sonuç, mnemonik, her şık için açıklama, "Boş bırak" ve "Sonraki soru". Hak bitince paywall'a götürür; Premium olunca akış devam eder. |
| `presentation/widgets/option_tile.dart` | ✅ | Tek şık kutusu (doğru yeşil, yanlış kırmızı). |
| `presentation/widgets/option_explanation_list.dart` | ✅ | Her şıkkın "neden yanlış / doğru" açıklaması; seçtiğin şık en üstte. |
| `presentation/widgets/mnemonic_card.dart` | ✅ | "Akılda kalsın" kartı. |
| `presentation/widgets/quota_banner.dart` | ✅ | "Bugün kalan hak" çubuğu veya "Premium · Sınırsız". |

## 5) Ana sayfa (`features/dashboard/`) ve ayarlar

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `domain/entities/dashboard_stats.dart` | ✅ | Günlük istatistik, ders dağılımı, Premium durumu ve yaklaşan sınav modeli. |
| `domain/entities/appointment_summary.dart` | ✅ | Ana ekran kartı için ilanın kısa hali. |
| `domain/dashboard_repository.dart` | ✅ | İstatistik ve son ilanları getirme sözleşmesi. |
| `data/dashboard_repository_impl.dart` | ✅ | Sözleşmenin Supabase uygulaması (tek RPC çağrısı + ilan sorgusu). |
| `presentation/providers/dashboard_providers.dart` | ✅ | Ana ekran verisini sağlar. Ücretsiz kullanıcı için ilan sorgusu hiç atılmaz. |
| `presentation/screens/dashboard_screen.dart` | ✅ | Ana ekran: selamlama, sayaç, bugünkü istatistik, ilan kartları. Aşağı çekerek yenilenir; geniş ekranda iki sütun. |
| `presentation/widgets/exam_countdown_card.dart` | ✅ | Sınava gün/saat/dakika geri sayımı. |
| `presentation/widgets/daily_stats_card.dart` | ✅ | Bugünkü çözülen/doğru/başarı, günlük hak çubuğu, derslere göre dağılım, "Soru çözmeye başla". |
| `presentation/widgets/latest_appointments_strip.dart` | ✅ | Premium'da son 3 ilan, ücretsizde kilitli kart ve "Premium'a geç". |
| `features/settings/.../widgets/change_level_dialog.dart` | ✅ | Eğitim seviyesi değiştirme diyaloğu; sonrasında profil, ana ekran ve kota yenilenir. |
| `features/settings/.../widgets/change_password_dialog.dart` | ✅ | Yeni şifre + tekrar (en az 6 karakter) diyaloğu. |
| `features/settings/.../settings_screen.dart` | ✅ | Profil, **eğitim seviyesi ve şifre değiştirme**, üyelik durumu / "Yükselt", tema seçimi, çıkış. |

## 6) Abonelik (`features/subscription/`) — Adım 4

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `domain/purchase_service.dart` | ✅ | Satın alma sağlayıcısının sözleşmesi (paketleri yükle, satın al, geri yükle). |
| `data/revenuecat_service.dart` | ✅ | RevenueCat ile gerçek mağaza satın alması (yalnızca Android/iOS'ta kullanılır). Kullanıcıyı Supabase kimliğiyle RevenueCat'e tanıtır. |
| `data/unavailable_purchase_service.dart` | ✅ | Masaüstü, web veya anahtar yokken kullanılan "satın alma yok" servisi; hiçbir yerel eklentiyi çağırmaz, nedenini söyler. |
| `presentation/providers/subscription_providers.dart` | ✅ | Platforma göre doğru servisi seçer, paketleri yükler, ödeme sonrası Premium'un hesaba yansımasını bekler. |
| `presentation/screens/paywall_screen.dart` | ✅ | Premium ekranı: avantajlar, paketler ve fiyatlar, satın al, satın alımları geri yükle. |

## 7) Proje yapılandırma dosyaları

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `KURULUM.md` | ✅ | Gereksinimler, Supabase kurulumu, çalıştırma, Premium'u elle açma, sık sorunlar. |
| `pubspec.yaml` | ✅ | Kullanılan paketlerin listesi (RevenueCat dahil; Firebase henüz yok). |
| `analysis_options.yaml` | ✅ | Kod kalitesi kuralları. |
| `env.example.json` | ✅ | Anahtar şablonu. Kopyalayıp `env.json` yap ve kendi değerlerini yaz. |
| `.gitignore` | ✅ | `env.json` ve üretilen dosyaların paylaşılmasını engeller. |
| `.vscode/launch.json` | ✅ | VS Code'da `F5` ile `env.json` parametresiyle çalıştırır. |
| `schema.sql`, `flutter_structure.md` | ✅ | İlk adımda sunduğum şema ve klasör planı (şema artık `0001_init.sql` olarak projede; klasör planı referans amaçlı). |

## 8) Atama Takip modülü (`features/appointments/`) ve ilan botu

| Dosya | Durum | Ne işe yarar |
|---|---|---|
| `domain/appointment_repository.dart` | ✅ | Atama ilanı reposu: listeleme, filtreleme, takip, detay. |
| `domain/entities/appointment.dart` | ✅ | İlan modeli (kaynak, kurum, şehir, tarihler, KPSS kodları) + `kpssRequired`, `matchesProfession`. |
| `domain/entities/appointment_filter.dart` | ✅ | Filtre: şehir, bölüm, nitelik kodu, arama, KPSS'li/KPSS'siz, "yalnızca mesleklerim". |
| `domain/entities/appointment_list.dart` | ✅ | Sayfalanmış ilan listesi (toplam + hasMore). |
| `data/appointment_repository_impl.dart` | ✅ | RPC çağrıları: `get_appointments`, `get_followed_appointments`, `get_appointment_detail`, `toggle_follow_appointment`. |
| `presentation/providers/appointment_providers.dart` | ✅ | Filtre durumu + **sayfa sayfa biriken liste** (tüm ilanlar / takip edilenler), yerinde takip güncellemesi, detay. |
| `presentation/screens/appointment_list_screen.dart` | ✅ | Liste: KPSS'li/KPSS'siz/Mesleklerim hızlı filtreleri, sonsuz kaydırma, aşağı çekip yenileme, Premium kapısı. |
| `presentation/screens/appointment_detail_screen.dart` | ✅ | İlan detayı, takip düğmesi, bağlantı kopyalama. |
| `presentation/widgets/appointment_card.dart` | ✅ | Liste kartı; "Mesleğine uygun" ve "KPSS'siz" rozetleri. |
| `presentation/widgets/appointment_filter_bar.dart` | ✅ | Filtre penceresi: arama, şehir, bölüm, nitelik kodu. |
| `features/settings/.../widgets/profession_tags_editor.dart` | ✅ | Ayarlar'da **takip edilen meslekler** (etiket girişi, öneriler, anında kayıt). |
| `supabase/migrations/0004_appointment_rpcs.sql` | ✅ | İlk RPC sürümü (liste fonksiyonlarında hata vardı, 0005 ile değiştirilir). |
| `supabase/migrations/0005_appointments_v2.sql` | ✅ | Hata düzeltmesi + `followed_professions`, `kpss_required`, yeni kaynaklar (`pgm_adalet`, `iskur`), Türkçe duyarsız arama/meslek eşleştirme, sahte ilan temizliği. |
| `supabase/functions/notify-new-appointment/index.ts` | ✅ | Yeni ilanda Premium kullanıcılara FCM push (seviye + meslek eşleşmesi). |
| `supabase/functions/notify-new-appointment/match.ts`, `match.test.ts` | ✅ | Bildirim eşleştirme kuralı (saf fonksiyon) ve 6 test. |
| `supabase/functions/notify-new-appointment/README.md` | ✅ | Firebase kurulum, secret ve webhook adımları. |
| `scraper/run.py` | ✅ | Bot girişi: `--dry-run`, `--source`, `--debug-dir`, `--daemon`. |
| `scraper/http_client.py` | ✅ | robots.txt'e uyan, bekleyen, yeniden deneyen HTTP istemcisi; JavaScript'li sayfalar için Playwright tarayıcı modu ve XHR/JSON keşfi. |
| `scraper/requirements-js.txt` | ✅ | Tarayıcı modu için isteğe bağlı bağımlılık (Playwright). |
| `scraper/text_utils.py` | ✅ | Türkçe metinden tarih, son başvuru, eğitim seviyesi, KPSS kodu, kadro sayısı, il çıkarma. |
| `scraper/scrapers/base.py` | ✅ | İlan modeli, "ilan mı?" süzgeci, KPSS şartı tespiti, genel bağlantı toplama sınıfı. |
| `scraper/scrapers/pgm_adalet.py` | ✅ | pgm.adalet.gov.tr (duyuru bağlantı yapısı gözlemlenerek yazıldı). |
| `scraper/scrapers/yerelyonetimler.py` | ✅ | Yerel Yönetimler: gerçek sayfaya göre yazıldı (yalnızca "Duyurular" kartları; başlıktan il/kurum/unvan çıkarır, iptal ilanlarını almaz). |
| `scraper/scrapers/sources.py` | ✅ | Kariyer Kapısı, Kamu İlan (KPSS'siz), İŞKUR (KPSS'siz). **Gerçek HTML görülmedi; `--discover` ile ayarlanacak.** |
| `.github/workflows/scraper.yml` | ✅ | GitHub Actions: botu her saat başı çalıştırır (Secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`). |
| `scraper/database.py` | ✅ | Yalnızca yeni ilanları ekler (var olana dokunmaz). |
| `scraper/tests/` | ✅ | 30 birim testi (`python -m unittest discover -s tests -t .`). |

## 9) Sonraki adımlar

| Modül | Durum | Ne işe yarar |
|---|---|---|
| Bot kaynaklarının gerçek siteyle ayarı | ⏳ | `--dry-run` çıktısına göre `scrapers/sources.py` ayarlanacak; ÖSYM botu eklenecek. |
| Firebase push (Flutter tarafı) | ⏳ | `firebase_messaging` paketi eklenip cihaz token kaydı ve bildirim alımı yapılacak. |
| Gerçek soru bankası | ⏳ | Şu an yalnızca 6 örnek soru var; gerçek KPSS soruları eklenecek. |
| Gerçek sınav tarihleri | ⏳ | `sample_exams.sql`'deki tarihler ÖSYM duyurularıyla doğrulanmalı. |
| RevenueCat gerçek test | ⏳ | Gerçek mağazada abonelik ürünleri oluşturulup denenmeli. |

## Dikkat edilecek noktalar

- **Kod henüz derlenip çalıştırılmadı.** Yazdığım ortamda Flutter kurulu değil. İlk `flutter run`'da küçük derleme hataları çıkabilir; terminal çıktısını bana yapıştır. Yalnızca webhook mantığı (`map_event.ts`) gerçekten çalıştırılıp test edildi.
- **Satın alma gerçek mağazayla denenmedi.** Gerçek ürünler, RevenueCat ayarı ve webhook dağıtımı sende yapılacak (bkz. `KURULUM.md` Bölüm 9 ve webhook README'si). Anahtar yoksa uygulama sorunsuz çalışır, paywall nedenini açıklar.
- **Satın alma yalnızca Android ve iOS'ta yapılır.** Masaüstünde/webde yapılamaz; telefondan Premium olan hesap, masaüstünde de Premium görünür (durum Supabase'den okunur).
- **Soru ve sınav verisi örnektir.** Gerçek soru bankası ve doğrulanmış ÖSYM tarihleri sonra eklenecek.
- **Matik'te bilinen eksikler:** (1) Soru görseli (`image_url`) yalnızca tam `http` adresi ise gösterilir; Storage bucket'ı sonra kurulacak. (2) Soruyu işaretlediğin an "çözüldü" olur; geri alma yoktur (bilinçli tercih; "Boş bırak" da soruyu tüketir).
