// Çalıştırma (Node 22.18+):  node --test supabase/functions/revenuecat-webhook/map_event.test.ts
// Daha eski Node 22 sürümleri için: node --experimental-strip-types --test <dosya>
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { isStale, mapEvent, mapStore, pickUserId, type RcEvent } from './map_event.ts';

const UID = '3f2b8f0e-5c1a-4d7e-9b6a-1c2d3e4f5a6b';
const NOW = Date.UTC(2026, 9, 10, 12, 0, 0); // 10 Ekim 2026
const DAY = 24 * 60 * 60 * 1000;

function ev(over: Partial<RcEvent>): RcEvent {
  return {
    type: 'INITIAL_PURCHASE',
    app_user_id: UID,
    product_id: 'premium_monthly',
    entitlement_ids: ['premium'],
    period_type: 'NORMAL',
    purchased_at_ms: NOW,
    expiration_at_ms: NOW + 30 * DAY,
    event_timestamp_ms: NOW,
    store: 'PLAY_STORE',
    ...over,
  };
}

function upsert(e: RcEvent) {
  const d = mapEvent(e, 'premium', NOW);
  assert.equal(d.action, 'upsert', JSON.stringify(d));
  return (d as Extract<typeof d, { action: 'upsert' }>).update;
}

test('ilk satın alma: aktif, yenilenecek, started_at dolu', () => {
  const u = upsert(ev({}));
  assert.equal(u.status, 'active');
  assert.equal(u.will_renew, true);
  assert.equal(u.user_id, UID);
  assert.equal(u.store, 'play_store');
  assert.equal(u.started_at, new Date(NOW).toISOString());
  assert.equal(u.expires_at, new Date(NOW + 30 * DAY).toISOString());
});

test('deneme dönemi: trialing', () => {
  assert.equal(upsert(ev({ period_type: 'TRIAL' })).status, 'trialing');
});

test('yenileme: started_at gönderilmez (mevcut değer korunur)', () => {
  const u = upsert(ev({ type: 'RENEWAL' }));
  assert.equal(u.status, 'active');
  assert.equal('started_at' in u, false);
});

test('iptal (dönem sonu gelecekte): erişim sürer, yenilenmez', () => {
  const u = upsert(ev({ type: 'CANCELLATION' }));
  assert.equal(u.status, 'active');
  assert.equal(u.will_renew, false);
});

test('iptal + süre dolmuş (iade gibi): cancelled', () => {
  const u = upsert(ev({ type: 'CANCELLATION', expiration_at_ms: NOW - 1000 }));
  assert.equal(u.status, 'cancelled');
});

test('süre doldu: expired', () => {
  const u = upsert(ev({ type: 'EXPIRATION', expiration_at_ms: NOW - 1000 }));
  assert.equal(u.status, 'expired');
  assert.equal(u.will_renew, false);
});

test('ödeme sorunu: grace_period (süre gelecekte) / billing_issue (geçmişte)', () => {
  assert.equal(upsert(ev({ type: 'BILLING_ISSUE' })).status, 'grace_period');
  assert.equal(
    upsert(ev({ type: 'BILLING_ISSUE', expiration_at_ms: NOW - 1 })).status,
    'billing_issue',
  );
});

test('ömür boyu (süre yok): active ve expires_at null', () => {
  const u = upsert(ev({ type: 'NON_RENEWING_PURCHASE', expiration_at_ms: null }));
  assert.equal(u.status, 'active');
  assert.equal(u.expires_at, null);
  assert.equal(u.will_renew, false);
});

test('anonim RevenueCat kimliği: alias içindeki UUID bulunur', () => {
  const u = upsert(
    ev({ app_user_id: '$RCAnonymousID:abc123', aliases: ['$RCAnonymousID:abc123', UID.toUpperCase()] }),
  );
  assert.equal(u.user_id, UID);
});

test('yalnızca anonim kimlik varsa yok sayılır', () => {
  const d = mapEvent(ev({ app_user_id: '$RCAnonymousID:abc123', aliases: [] }), 'premium', NOW);
  assert.equal(d.action, 'ignore');
});

test('TEST, TRANSFER, bilinmeyen olay türleri yok sayılır', () => {
  for (const type of ['TEST', 'TRANSFER', 'INVOICE_ISSUANCE', 'SOMETHING_NEW']) {
    assert.equal(mapEvent(ev({ type }), 'premium', NOW).action, 'ignore', type);
  }
});

test('başka entitlement Premium\'u etkilemez; entitlement bilgisi yoksa işlenir', () => {
  assert.equal(mapEvent(ev({ entitlement_ids: ['pro_plus'] }), 'premium', NOW).action, 'ignore');
  assert.equal(mapEvent(ev({ entitlement_ids: null }), 'premium', NOW).action, 'upsert');
  assert.equal(
    mapEvent(ev({ entitlement_ids: undefined, entitlement_id: 'premium' }), 'premium', NOW).action,
    'upsert',
  );
});

test('mağaza eşlemesi', () => {
  assert.equal(mapStore('APP_STORE'), 'app_store');
  assert.equal(mapStore('MAC_APP_STORE'), 'app_store');
  assert.equal(mapStore('PLAY_STORE'), 'play_store');
  assert.equal(mapStore('STRIPE'), 'stripe');
  assert.equal(mapStore('PROMOTIONAL'), 'promotional');
  assert.equal(mapStore('AMAZON'), null);
  assert.equal(mapStore(undefined), null);
});

test('sırasız olay: eskisi atlanır, yenisi veya eşiti işlenir', () => {
  const incoming = ev({ event_timestamp_ms: NOW });
  assert.equal(isStale({ event_timestamp_ms: NOW + 5 }, incoming), true);
  assert.equal(isStale({ event_timestamp_ms: NOW }, incoming), false);
  assert.equal(isStale({ event_timestamp_ms: NOW - 5 }, incoming), false);
  assert.equal(isStale(null, incoming), false);
  assert.equal(isStale({}, incoming), false);
});

test('pickUserId UUID olmayan değerleri reddeder', () => {
  assert.equal(pickUserId(ev({ app_user_id: 'kullanici-123', aliases: [] })), null);
});
