// Supabase Edge Function: RevenueCat -> public.subscriptions
// Dağıtım ve ayar adımları için README.md'ye bak.
//
// Güvenlik: bu fonksiyon JWT doğrulaması OLMADAN dağıtılır (RevenueCat JWT göndermez),
// bu yüzden gizli anahtar (REVENUECAT_WEBHOOK_SECRET) kontrolü ZORUNLUDUR.
import { createClient } from 'npm:@supabase/supabase-js@2';

import { isStale, mapEvent, type RcEvent } from './map_event.ts';

const WEBHOOK_SECRET = Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ?? '';
const ENTITLEMENT = Deno.env.get('PREMIUM_ENTITLEMENT') ?? 'premium';

// Bu iki değişken Supabase tarafından Edge Function'a otomatik verilir.
const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false } },
);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/** Zamanlama saldırılarına karşı sabit sürede karşılaştırma. */
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const len = Math.max(x.length, y.length);
  for (let i = 0; i < len; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  if (WEBHOOK_SECRET.length < 16) {
    console.error('REVENUECAT_WEBHOOK_SECRET tanımlı değil veya çok kısa');
    return json({ error: 'server not configured' }, 500);
  }

  const auth = req.headers.get('Authorization') ?? '';
  // RevenueCat paneline "Bearer <gizli>" yazılması önerilir; çıplak değer de kabul edilir.
  if (!safeEqual(auth, `Bearer ${WEBHOOK_SECRET}`) && !safeEqual(auth, WEBHOOK_SECRET)) {
    return json({ error: 'unauthorized' }, 401);
  }

  let event: RcEvent | undefined;
  try {
    const body = await req.json();
    event = body?.event as RcEvent | undefined;
  } catch {
    return json({ error: 'invalid json' }, 400);
  }
  if (!event || typeof event.type !== 'string') return json({ error: 'event missing' }, 400);

  const decision = mapEvent(event, ENTITLEMENT);
  if (decision.action === 'ignore') {
    // 200 dönülür: RevenueCat işlenmeyen olayı sonsuza dek yeniden denemesin.
    return json({ ok: true, ignored: decision.reason });
  }
  const update = decision.update;

  // Kullanıcı silinmişse (FK ihlali kalıcı hata olur) yeniden denemeyi önlemek için 200 dön.
  const { data: user, error: userErr } = await admin
    .from('users')
    .select('id')
    .eq('id', update.user_id)
    .maybeSingle();
  if (userErr) {
    console.error('users sorgusu başarısız', userErr.message);
    return json({ error: 'db error' }, 500); // RevenueCat yeniden dener
  }
  if (!user) return json({ ok: true, ignored: 'user not found' });

  // Sırasız gelen eski olay, daha yeni durumu ezmesin.
  const { data: existing, error: subErr } = await admin
    .from('subscriptions')
    .select('raw_event')
    .eq('user_id', update.user_id)
    .maybeSingle();
  if (subErr) {
    console.error('subscriptions sorgusu başarısız', subErr.message);
    return json({ error: 'db error' }, 500);
  }
  if (isStale(existing?.raw_event, event)) {
    return json({ ok: true, ignored: 'stale event' });
  }

  const { error: upsertErr } = await admin
    .from('subscriptions')
    .upsert(update, { onConflict: 'user_id' });
  if (upsertErr) {
    console.error('upsert başarısız', upsertErr.message);
    return json({ error: 'db error' }, 500);
  }

  return json({ ok: true, status: update.status });
});
