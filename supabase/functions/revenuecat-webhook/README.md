# revenuecat-webhook

Satın alma, yenileme, iptal gibi RevenueCat olaylarını alır ve `public.subscriptions` tablosuna yazar.
Uygulama Premium durumunu bu tablodan (`is_premium()` ile) okur; yani **satın alma doğrulaması sunucudadır**,
telefonu kurcalayan biri kendini Premium yapamaz.

## Dosyalar

| Dosya | Ne yapar |
|---|---|
| `index.ts` | Edge Function sunucusu: gizli anahtarı doğrular, olayı işler, veritabanına yazar. |
| `map_event.ts` | Saf mantık: RevenueCat olayını abonelik durumuna çevirir (iptal ≠ hemen bitiş, ödeme sorunu = ek süre vb.). |
| `map_event.test.ts` | 15 birim test. |

## Önkoşul

- Supabase projesi hazır, `0001_init.sql` çalıştırılmış.
- RevenueCat'te entitlement adı tam olarak **`premium`** (farklıysa `PREMIUM_ENTITLEMENT` gizli değişkenini ayarla).
- Uygulama RevenueCat'e kullanıcıyı **Supabase kullanıcı kimliğiyle** tanıtır (`appUserID = users.id`; kod bunu zaten yapar).

## Kurulum

1. Supabase CLI'yi kur (https://supabase.com/docs/guides/cli) ve giriş yap:
   ```
   supabase login
   supabase link --project-ref <PROJE_KIMLIGI>
   ```
   `<PROJE_KIMLIGI>`, Supabase adresindeki `https://<PROJE_KIMLIGI>.supabase.co` kısmıdır.
2. Uzun, rastgele bir gizli değer üret (en az 16 karakter; ör. `openssl rand -hex 32`) ve kaydet:
   ```
   supabase secrets set REVENUECAT_WEBHOOK_SECRET=<uretilen-gizli-deger>
   ```
3. Fonksiyonu **JWT doğrulamasız** dağıt (RevenueCat JWT göndermez; güvenliği gizli anahtar sağlar):
   ```
   supabase functions deploy revenuecat-webhook --no-verify-jwt
   ```
4. RevenueCat panelinde: **Project settings → Integrations → Webhooks → Add new**
   - **Webhook URL:** `https://<PROJE_KIMLIGI>.supabase.co/functions/v1/revenuecat-webhook`
   - **Authorization header value:** `Bearer <uretilen-gizli-deger>`
   - **Environment:** deneme için *Sandbox + Production*, yayında *Production*.
   - **Entitlements:** `premium`.
5. Test: panelde **Send test event** → yanıt `{"ok":true,"ignored":"test event"}` ve HTTP 200 olmalı.
   `401` alıyorsan gizli değer eşleşmiyor demektir.
6. Gerçek deneme: Sandbox/test hesabıyla satın al → SQL Editor'de
   `select user_id, status, expires_at, last_event_type from public.subscriptions;` satırı görmelisin.

## Birim testleri çalıştırma

Node 22.18 veya üstü:
```
node --test supabase/functions/revenuecat-webhook/map_event.test.ts
```
(Daha eski Node 22 sürümünde komuta `--experimental-strip-types` ekle.)

## Davranış özeti

| RevenueCat olayı | `status` | Not |
|---|---|---|
| INITIAL_PURCHASE, RENEWAL, UNCANCELLATION, PRODUCT_CHANGE, SUBSCRIPTION_EXTENDED | `active` (deneme ise `trialing`) | `will_renew = true` |
| NON_RENEWING_PURCHASE, TEMPORARY_ENTITLEMENT_GRANT | `active` | `will_renew = false`; süre yoksa ömür boyu |
| CANCELLATION, SUBSCRIPTION_PAUSED | süre dolmadıysa `active`, dolduysa `cancelled` | İptal edince erişim dönem sonuna kadar sürer; iade hemen bitirir |
| BILLING_ISSUE | süre dolmadıysa `grace_period`, dolduysa `billing_issue` | Yalnızca `grace_period` Premium sayılır |
| EXPIRATION | `expired` | |
| TEST, TRANSFER, bilinmeyenler | yok sayılır (HTTP 200) | |

## Bilinen sınırlar

- **TRANSFER** olayları (bir aboneliğin bir kullanıcıdan diğerine taşınması) işlenmez. Kullanıcıyı her zaman
  Supabase kimliğiyle tanıttığımız için normalde gerekmez; ihtiyaç doğarsa eklenir.
- `index.ts` (Deno sunucusu) bu ortamda çalıştırılamadı; yalnızca `map_event.ts` testlerle doğrulandı.
  İlk dağıtımdan sonra 5. adımdaki test olayını mutlaka dene.
