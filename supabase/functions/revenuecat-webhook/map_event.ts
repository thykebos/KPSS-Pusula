// RevenueCat webhook olayını public.subscriptions satırına çeviren SAF mantık.
// Deno'ya veya Supabase'e bağımlılığı yoktur; bu yüzden Node ile de test edilebilir
// (bkz. map_event.test.ts).

export type SubscriptionStatus =
  | 'active'
  | 'trialing'
  | 'grace_period'
  | 'cancelled'
  | 'expired'
  | 'billing_issue';

export type StoreType = 'app_store' | 'play_store' | 'stripe' | 'promotional';

export interface RcEvent {
  type: string;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  product_id?: string;
  entitlement_ids?: string[] | null;
  entitlement_id?: string | null;
  period_type?: string;
  purchased_at_ms?: number | null;
  expiration_at_ms?: number | null;
  event_timestamp_ms?: number;
  store?: string;
  environment?: string;
  [key: string]: unknown;
}

export interface SubscriptionUpdate {
  user_id: string;
  revenuecat_app_user_id: string;
  entitlement: string;
  product_id: string | null;
  store: StoreType | null;
  status: SubscriptionStatus;
  /** Yalnızca ilk satın almada gönderilir; diğer olaylarda mevcut değer korunur. */
  started_at?: string;
  expires_at: string | null;
  will_renew: boolean;
  last_event_type: string;
  raw_event: RcEvent;
}

export type Decision =
  | { action: 'ignore'; reason: string }
  | { action: 'upsert'; update: SubscriptionUpdate };

// Supabase auth kullanıcı kimlikleri UUID'dir. RevenueCat anonim kimlikleri
// ("$RCAnonymousID:...") UUID DEĞİLDİR ve bir kullanıcıya bağlanamaz.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function pickUserId(event: RcEvent): string | null {
  const candidates = [
    event.app_user_id,
    event.original_app_user_id,
    ...(Array.isArray(event.aliases) ? event.aliases : []),
  ];
  for (const c of candidates) {
    if (typeof c === 'string' && UUID_RE.test(c)) return c.toLowerCase();
  }
  return null;
}

export function mapStore(store: string | undefined): StoreType | null {
  switch (store) {
    case 'APP_STORE':
    case 'MAC_APP_STORE':
      return 'app_store';
    case 'PLAY_STORE':
      return 'play_store';
    case 'STRIPE':
    case 'RC_BILLING':
      return 'stripe';
    case 'PROMOTIONAL':
      return 'promotional';
    default:
      return null;
  }
}

function toIso(ms: number | null | undefined): string | null {
  return typeof ms === 'number' && Number.isFinite(ms) ? new Date(ms).toISOString() : null;
}

/**
 * RevenueCat olayını karara çevirir.
 * @param entitlement  Premium'u temsil eden RevenueCat entitlement adı.
 * @param nowMs        Test edilebilirlik için şimdiki zaman (ms).
 */
export function mapEvent(
  event: RcEvent,
  entitlement = 'premium',
  nowMs: number = Date.now(),
): Decision {
  const type = event.type;
  if (typeof type !== 'string' || type.length === 0) {
    return { action: 'ignore', reason: 'event type missing' };
  }
  if (type === 'TEST') return { action: 'ignore', reason: 'test event' };
  if (type === 'TRANSFER') return { action: 'ignore', reason: 'transfer events are not handled' };

  // Başka bir entitlement'a ait olay (ileride ikinci bir ürün eklenirse) Premium'u etkilemesin.
  const ids = Array.isArray(event.entitlement_ids)
    ? event.entitlement_ids
    : event.entitlement_id
      ? [event.entitlement_id]
      : null;
  if (ids && !ids.includes(entitlement)) {
    return { action: 'ignore', reason: `entitlement ${entitlement} not in event` };
  }

  const userId = pickUserId(event);
  if (!userId) return { action: 'ignore', reason: 'no uuid user in event' };

  const expiresMs =
    typeof event.expiration_at_ms === 'number' && Number.isFinite(event.expiration_at_ms)
      ? event.expiration_at_ms
      : null;
  const stillValid = expiresMs === null || expiresMs > nowMs;
  const isTrial = event.period_type === 'TRIAL';

  let status: SubscriptionStatus;
  let willRenew: boolean;

  switch (type) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'UNCANCELLATION':
    case 'PRODUCT_CHANGE':
    case 'SUBSCRIPTION_EXTENDED':
      status = isTrial ? 'trialing' : 'active';
      willRenew = true;
      break;

    case 'NON_RENEWING_PURCHASE':
    case 'TEMPORARY_ENTITLEMENT_GRANT':
      status = 'active';
      willRenew = false;
      break;

    // İptal / duraklatma: dönem sonuna kadar erişim sürer. Süresi dolmuşsa (ör. iade) hemen biter.
    case 'CANCELLATION':
    case 'SUBSCRIPTION_PAUSED':
      status = stillValid ? (isTrial ? 'trialing' : 'active') : 'cancelled';
      willRenew = false;
      break;

    // Ödeme sorunu: mağaza ek süre (grace) veriyorsa erişim sürer; vermiyorsa süre dolunca EXPIRATION gelir.
    case 'BILLING_ISSUE':
      status = stillValid ? 'grace_period' : 'billing_issue';
      willRenew = false;
      break;

    case 'EXPIRATION':
      status = 'expired';
      willRenew = false;
      break;

    default:
      return { action: 'ignore', reason: `unhandled event type ${type}` };
  }

  const update: SubscriptionUpdate = {
    user_id: userId,
    revenuecat_app_user_id: event.app_user_id ?? userId,
    entitlement,
    product_id: event.product_id ?? null,
    store: mapStore(event.store),
    status,
    expires_at: toIso(expiresMs),
    will_renew: willRenew,
    last_event_type: type,
    raw_event: event,
  };
  if (type === 'INITIAL_PURCHASE') {
    const startedAt = toIso(event.purchased_at_ms);
    if (startedAt) update.started_at = startedAt;
  }
  return { action: 'upsert', update };
}

/**
 * RevenueCat olayları sırasız gelebilir. Kayıtlı olaydan ESKİ bir olay gelirse atlanır.
 */
export function isStale(
  existingRawEvent: { event_timestamp_ms?: unknown } | null | undefined,
  incoming: RcEvent,
): boolean {
  const prev = existingRawEvent?.event_timestamp_ms;
  const next = incoming.event_timestamp_ms;
  return typeof prev === 'number' && typeof next === 'number' && prev > next;
}
