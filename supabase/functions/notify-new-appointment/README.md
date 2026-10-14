# notify-new-appointment Edge Function

Yeni bir kamu ilanı `appointments` tablosuna eklendiğinde, bu Edge Function uygun
Premium kullanıcılara Firebase Cloud Messaging (FCM) push bildirimi gönderir.

## Dağıtım

```bash
cd supabase/functions/notify-new-appointment

# Firebase Admin SDK için servis hesabı JSON'unu kopyala
# (Firebase Console > Project Settings > Service Accounts > Generate new private key)
# ve secret olarak ayarla:
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON "$(cat firebase-service-account.json)"

# Dağıt
supabase functions deploy notify-new-appointment
```

## Tetikleme

Supabase Dashboard > Database > Webhooks:

1. **New Webhook** tıkla
2. **Name:** `notify-new-appointment`
3. **Table:** `appointments`
4. **Events:** `INSERT`
5. **Type:** `Edge Function`
6. **Edge Function name:** `notify-new-appointment`
7. **Region:** *sana en yakın Avrupa bölgesi*

Bundan sonra `appointments` tablosuna her yeni ilan eklendiğinde,
eşleşen Premium kullanıcılara push bildirimi gider.

## Gerekenler

- Firebase projesi (Cloud Messaging etkin)
- Firebase Admin SDK servis hesabı (Service Account)
- `device_tokens` tablosunda geçerli FCM token'ları
  (Flutter tarafında `firebase_messaging` paketi ile toplanır)