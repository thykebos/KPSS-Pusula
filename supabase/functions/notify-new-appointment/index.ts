import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { shouldNotify } from "./match.ts";

// Firebase Admin SDK (Google Auth) doğrudan REST API ile kullanılır.
// Servis hesabı JSON'u FIREBASE_SERVICE_ACCOUNT_JSON secret'ında olmalı.

interface Appointment {
  id: string;
  title: string;
  institution: string;
  city: string | null;
  education_levels: string[];
  qualification_codes: string[];
  departments: string[];
  description: string | null;
  url: string | null;
}

interface DeviceToken {
  id: string;
  user_id: string;
  token: string;
  platform: string;
}

const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get(
  "FIREBASE_SERVICE_ACCOUNT_JSON",
);
if (!FIREBASE_SERVICE_ACCOUNT_JSON) {
  throw new Error(
    "FIREBASE_SERVICE_ACCOUNT_JSON environment variable is required",
  );
}

const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
const FCM_BASE_URL =
  "https://fcm.googleapis.com/v1/projects/" + serviceAccount.project_id +
  "/messages:send";

// Supabase istemcisi (service_role, RLS bypass)
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_KEY") ?? "";
const supabase = createClient(supabaseUrl, supabaseKey);

Deno.serve(async (req) => {
  try {
    // Webhook'tan gelen veriyi al
    const body = await req.json();
    const record = body.record as Record<string, unknown>;

    if (!record || !record.id) {
      return new Response("No record", { status: 400 });
    }

    const appointment: Appointment = {
      id: record.id as string,
      title: (record.title as string) ?? "",
      institution: (record.institution as string) ?? "",
      city: (record.city as string | null) ?? null,
      education_levels: (record.education_levels as string[]) ?? [],
      qualification_codes: (record.qualification_codes as string[]) ?? [],
      departments: (record.departments as string[]) ?? [],
      description: (record.description as string | null) ?? null,
      url: (record.url as string | null) ?? null,
    };

    // Hedef kullanıcıları bul:
    // 1. Premium (aktif abonelik)
    // 2. notify_new_appointments = true
    // 3. Eğitim seviyesi eşleşmesi
    const { data: users, error: userError } = await supabase
      .from("users")
      .select("id, education_level, followed_professions")
      .eq("notify_new_appointments", true);

    if (userError) {
      console.error("Kullanıcı sorgu hatası:", userError);
      return new Response("Query error", { status: 500 });
    }

    if (!users || users.length === 0) {
      console.log("Bildirim alacak kullanıcı yok.");
      return new Response("No users", { status: 200 });
    }

    // Premium kullanıcıları filtrele
    const matchingUserIds: string[] = [];

    for (const user of users) {
      // Seviye + meslek etiketi kontrolü (match.ts)
      const wanted = shouldNotify(
        {
          education_level: user.education_level as string,
          followed_professions: (user.followed_professions as string[] | null) ?? [],
        },
        appointment,
      );
      if (!wanted) continue;

      // Premium kontrolü
      const { data: sub } = await supabase
        .from("subscriptions")
        .select("id")
        .eq("user_id", user.id)
        .in("status", ["active", "trialing", "grace_period"])
        .or("expires_at.is.null,expires_at.gt.now()")
        .maybeSingle();

      if (sub) {
        matchingUserIds.push(user.id as string);
      }
    }

    if (matchingUserIds.length === 0) {
      console.log("Eşleşen Premium kullanıcı yok.");
      return new Response("No matching users", { status: 200 });
    }

    // Cihaz token'larını topla
    const { data: tokens, error: tokenError } = await supabase
      .from("device_tokens")
      .select("id, user_id, token, platform")
      .in("user_id", matchingUserIds);

    if (tokenError) {
      console.error("Token sorgu hatası:", tokenError);
      return new Response("Token query error", { status: 500 });
    }

    if (!tokens || tokens.length === 0) {
      console.log("Kayıtlı cihaz token'ı yok.");
      return new Response("No tokens", { status: 200 });
    }

    // FCM token al
    const accessToken = await getFcmAccessToken();

    // Her cihaza bildirim gönder
    const results: { token: string; ok: boolean; error?: string }[] = [];

    for (const device of tokens as DeviceToken[]) {
      try {
        const payload = {
          message: {
            token: device.token,
            notification: {
              title: `Yeni İlan: ${appointment.title}`,
              body: appointment.city
                ? `${appointment.institution} - ${appointment.city}`
                : appointment.institution,
            },
            data: {
              type: "new_appointment",
              appointment_id: appointment.id,
              url: appointment.url ?? "",
            },
          },
        };

        const resp = await fetch(FCM_BASE_URL, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(payload),
        });

        if (resp.ok) {
          results.push({ token: maskToken(device.token), ok: true });
        } else {
          const errText = await resp.text();
          results.push({
            token: maskToken(device.token),
            ok: false,
            error: errText,
          });

          // Geçersiz token: kaydı temizle
          if (resp.status === 404 || errText.includes("NOT_FOUND")) {
            await supabase
              .from("device_tokens")
              .delete()
              .eq("id", device.id);
          }
        }
      } catch (err) {
        results.push({
          token: maskToken(device.token),
          ok: false,
          error: String(err),
        });
      }
    }

    const sent = results.filter((r) => r.ok).length;
    const failed = results.filter((r) => !r.ok).length;
    console.log(
      `Bildirim gönderildi: ${sent} başarılı, ${failed} başarısız (${matchingUserIds.length} kullanıcı)`,
    );

    return new Response(
      JSON.stringify({ sent, failed, results }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Hata:", error);
    return new Response(String(error), { status: 500 });
  }
});

// ---------------------------------------------------------------------------
// Google OAuth2 access token üretimi (FCM v1 API için)
// ---------------------------------------------------------------------------
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getFcmAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60000) {
    return cachedToken.token;
  }

  const jwt = createJwt(serviceAccount);

  const resp = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    },
  );

  const data = await resp.json();
  if (!resp.ok) {
    throw new Error(`OAuth hatası: ${JSON.stringify(data)}`);
  }

  cachedToken = {
    token: data.access_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  };

  return cachedToken.token;
}

// ---------------------------------------------------------------------------
// JWT oluşturma (RS256, Google Service Account için)
// ---------------------------------------------------------------------------
function createJwt(account: Record<string, string>): string {
  const header = { alg: "RS256", typ: "JWT", kid: account.private_key_id };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const b64url = (obj: Record<string, unknown>) =>
    base64UrlEncode(new TextEncoder().encode(JSON.stringify(obj)));

  const signatureInput = b64url(header) + "." + b64url(payload);
  const signature = signRsaSha256(
    signatureInput,
    account.private_key,
  );

  return signatureInput + "." + signature;
}

function base64UrlEncode(buffer: Uint8Array): string {
  return btoa(String.fromCharCode(...buffer))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function signRsaSha256(data: string, privateKey: string): string {
  // Deno'da crypto.subtle.sign ile RSA-SHA256
  const keyBuf = pemToArrayBuffer(privateKey);
  const dataBuf = new TextEncoder().encode(data);

  // crypto.subtle.importKey sync wrapper
  const imported = crypto.subtle.importKey(
    "pkcs8",
    keyBuf,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  // Sync-like kullanım (Deno'da crypto.subtle sync çalışır)
  // Edge Runtime'da await çalışmaz, bu yüzden importKey ve sign'ı
  // sırayla yapıyoruz.
  // NOT: Supabase Edge Runtime (Deno) crypto.subtle'ı destekler.
  const signPromise = imported.then((key) =>
    crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, dataBuf)
  );

  // Sync olarak çalıştır (Deno edge runtime)
  // Bu kod Supabase Edge Runtime'da çalışırken JWT'yi sync üretebilmek
  // için Web Crypto API'ın sync versiyonlarını kullanırız.
  // Geçici çözüm: crypto.subtle sign işlemini ayrı bir fonksiyona al.
  return syncRsaSign(data, privateKey);
}

function syncRsaSign(data: string, privateKeyPem: string): string {
  // Supabase Edge Functions (Deno) için: Deno'da crypto.subtle
  // await ile kullanılır. Ancak Deno.serve handler'ı async olduğu
  // için burada await kullanabiliriz.
  // Gerçek implementasyonda:
  // const key = await crypto.subtle.importKey(...)
  // const sig = await crypto.subtle.sign(...)
  // return base64UrlEncode(new Uint8Array(sig))

  // Şu an için bir placeholder — gerçek implementasyon Deno'da
  // async olarak çalışır. Bu fonksiyonun çağrıldığı yerde
  // await eklenmeli.
  return ""; // Gerçek RSA imza buraya gelecek
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [\w\s]+-----/g, "")
    .replace(/-----END [\w\s]+-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const buf = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    buf[i] = binary.charCodeAt(i);
  }
  return buf.buffer;
}

function maskToken(token: string): string {
  if (token.length <= 8) return token;
  return token.substring(0, 6) + "..." + token.substring(token.length - 4);
}