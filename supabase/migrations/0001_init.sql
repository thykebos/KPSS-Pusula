-- =====================================================================
-- KPSS PUSULA - Supabase (PostgreSQL) Şeması  v1
-- Çalıştırma: Supabase Dashboard > SQL Editor veya `supabase db push`
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1) ENUM TİPLERİ
-- ---------------------------------------------------------------------
create type education_level as enum ('lise', 'onlisans', 'lisans');

create type subject_type as enum (
  'tarih', 'cografya', 'vatandaslik', 'matematik', 'turkce'
);

create type subscription_status as enum (
  'active', 'trialing', 'grace_period', 'cancelled', 'expired', 'billing_issue'
);

create type store_type as enum ('app_store', 'play_store', 'stripe', 'promotional');

create type appointment_source as enum (
  'kariyerkapisi',   -- kariyerkapisi.cbiko.gov.tr
  'yerelyonetimler', -- yerelyonetimler.csb.gov.tr
  'kamuilan',        -- kamuilan.sbb.gov.tr
  'osym',            -- ÖSYM
  'diger'
);

create type device_platform as enum ('ios', 'android', 'macos', 'windows', 'web');

-- ---------------------------------------------------------------------
-- 2) YARDIMCI FONKSİYONLAR
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------------------------------------------------------------------
-- 3) USERS  (auth.users ile 1-1 profil tablosu)
-- ---------------------------------------------------------------------
create table public.users (
  id                  uuid primary key references auth.users(id) on delete cascade,
  email               text,
  full_name           text,
  education_level     education_level not null default 'lisans',
  department          text,                         -- bölüm (örn. "Kamu Yönetimi")
  qualification_codes text[] not null default '{}', -- KPSS nitelik kodları
  free_subjects       subject_type[] not null default '{}', -- ücretsiz kullanıcının seçtiği 2 ders
  target_exam_id      uuid,                         -- dashboard sayacı için (FK aşağıda)
  notify_new_appointments boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint free_subjects_max_two check (coalesce(array_length(free_subjects, 1), 0) <= 2)
);

create trigger trg_users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- Kayıt sırasında profil satırını otomatik oluştur.
-- Flutter signUp çağrısında: data: {'education_level': 'lisans', 'full_name': '...'}
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, email, full_name, education_level)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    coalesce((new.raw_user_meta_data ->> 'education_level')::education_level, 'lisans')
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 4) EXAMS  (yaklaşan sınav sayacı)
-- ---------------------------------------------------------------------
create table public.exams (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,                    -- "KPSS Lisans 2026"
  education_levels education_level[] not null,
  exam_date        timestamptz not null,
  application_end  timestamptz,
  url              text,
  created_at       timestamptz not null default now()
);

alter table public.users
  add constraint users_target_exam_fk
  foreign key (target_exam_id) references public.exams(id) on delete set null;

-- ---------------------------------------------------------------------
-- 5) SUBSCRIPTIONS  (RevenueCat webhook -> Edge Function -> service_role)
-- ---------------------------------------------------------------------
create table public.subscriptions (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null unique references public.users(id) on delete cascade,
  revenuecat_app_user_id text not null,              -- RevenueCat appUserID = users.id olmalı
  entitlement            text not null default 'premium',
  product_id             text,
  store                  store_type,
  status                 subscription_status not null default 'expired',
  started_at             timestamptz,
  expires_at             timestamptz,
  will_renew             boolean not null default false,
  last_event_type        text,                       -- RC event: INITIAL_PURCHASE, RENEWAL, ...
  raw_event              jsonb,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create index idx_subscriptions_status on public.subscriptions(status, expires_at);

create trigger trg_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

-- Premium kontrolü: tüm RLS ve RPC'ler bunu kullanır.
create or replace function public.is_premium(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = uid
      and s.status in ('active', 'trialing', 'grace_period')
      and (s.expires_at is null or s.expires_at > now())
  );
$$;

-- ---------------------------------------------------------------------
-- 6) QUESTIONS + QUESTION_OPTIONS  (KPSS Matik)
-- ---------------------------------------------------------------------
create table public.questions (
  id               uuid primary key default gen_random_uuid(),
  subject          subject_type not null,
  topic            text,                              -- konu başlığı (örn. "Osmanlı Kuruluş")
  education_levels education_level[] not null default '{lise,onlisans,lisans}',
  body             text not null,                     -- soru kökü
  image_url        text,                              -- Supabase Storage yolu (opsiyonel)
  difficulty       smallint not null default 2 check (difficulty between 1 and 5),
  hint             text,                              -- soru çözerken gösterilebilir ipucu
  mnemonic         text,                              -- doğru cevap için akılda kalıcı çağrışım
  general_explanation text,                           -- konu özeti
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index idx_questions_subject on public.questions(subject) where is_active;
create index idx_questions_levels  on public.questions using gin (education_levels);

create trigger trg_questions_updated_at
  before update on public.questions
  for each row execute function public.set_updated_at();

-- Her şık için AYRI açıklama: "bu şık neden doğru / neden yanlış"
create table public.question_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  label       char(1) not null check (label in ('A','B','C','D','E')),
  body        text not null,
  is_correct  boolean not null default false,
  explanation text not null,                          -- şıkkın neden doğru/yanlış olduğu
  unique (question_id, label)
);

-- Her soruda tam 1 doğru şık olmalı
create unique index uq_one_correct_option
  on public.question_options(question_id) where is_correct;

-- ---------------------------------------------------------------------
-- 7) USER_SOLVED_QUESTIONS  ("çözüldü" hafızası - soru bir daha çıkmaz)
-- ---------------------------------------------------------------------
create table public.user_solved_questions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  question_id     uuid not null references public.questions(id) on delete cascade,
  selected_option char(1) check (selected_option in ('A','B','C','D','E')), -- null = boş bırakıldı
  is_correct      boolean not null,
  time_spent_sec  integer,
  solved_at       timestamptz not null default now(),
  unique (user_id, question_id)                       -- aynı soru iki kez kaydedilemez
);

create index idx_usq_user_date on public.user_solved_questions(user_id, solved_at desc);

-- ---------------------------------------------------------------------
-- 8) APPOINTMENTS  (Python botu yazar, sadece Premium okur)
-- ---------------------------------------------------------------------
create table public.appointments (
  id                  uuid primary key default gen_random_uuid(),
  source              appointment_source not null,
  external_id         text not null,                  -- kaynak sitedeki ilan kimliği/hash'i
  title               text not null,
  institution         text not null,
  city                text,
  description         text,
  education_levels    education_level[] not null default '{}',
  qualification_codes text[] not null default '{}',   -- KPSS nitelik kodları
  departments         text[] not null default '{}',   -- aranan bölümler
  positions_count     integer,
  application_start   timestamptz,
  application_end     timestamptz,
  url                 text not null,
  raw                 jsonb,
  published_at        timestamptz not null default now(),
  created_at          timestamptz not null default now(),
  unique (source, external_id)                        -- bot tekrar çalışınca duplicate olmaz (upsert)
);

create index idx_app_published on public.appointments(published_at desc);
create index idx_app_end       on public.appointments(application_end);
create index idx_app_levels    on public.appointments using gin (education_levels);
create index idx_app_codes     on public.appointments using gin (qualification_codes);
create index idx_app_depts     on public.appointments using gin (departments);

-- Kullanıcının takip ettiği ilanlar
create table public.appointment_follows (
  user_id        uuid not null references public.users(id) on delete cascade,
  appointment_id uuid not null references public.appointments(id) on delete cascade,
  created_at     timestamptz not null default now(),
  primary key (user_id, appointment_id)
);

-- ---------------------------------------------------------------------
-- 9) DEVICE_TOKENS  (FCM/APNs push bildirimleri)
-- ---------------------------------------------------------------------
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  token      text not null unique,
  platform   device_platform not null,
  updated_at timestamptz not null default now()
);

create index idx_device_tokens_user on public.device_tokens(user_id);

-- ---------------------------------------------------------------------
-- 10) ROW LEVEL SECURITY
-- ---------------------------------------------------------------------
alter table public.users                 enable row level security;
alter table public.exams                 enable row level security;
alter table public.subscriptions         enable row level security;
alter table public.questions             enable row level security;
alter table public.question_options      enable row level security;
alter table public.user_solved_questions enable row level security;
alter table public.appointments          enable row level security;
alter table public.appointment_follows   enable row level security;
alter table public.device_tokens         enable row level security;

-- users: sadece kendi profili
create policy users_select_own on public.users for select using (id = auth.uid());
create policy users_update_own on public.users for update using (id = auth.uid())
  with check (id = auth.uid());

-- exams: herkes okur
create policy exams_read on public.exams for select to authenticated using (true);

-- subscriptions: kullanıcı sadece okur; yazma yalnızca service_role (webhook)
create policy subs_select_own on public.subscriptions for select using (user_id = auth.uid());

-- questions / question_options: İSTEMCİYE DOĞRUDAN AÇIK DEĞİL.
-- Doğru cevap ve açıklamalar sızmasın diye erişim yalnızca aşağıdaki RPC'lerle olur.
-- (RLS açık + policy yok = istemci için tamamen kapalı)

-- user_solved_questions: kendi kayıtlarını okur; yazma sadece submit_answer RPC'si ile
create policy usq_select_own on public.user_solved_questions
  for select using (user_id = auth.uid());

-- appointments: SADECE PREMIUM okuyabilir ve eğitim seviyesine göre filtrelenir
create policy appointments_premium_read on public.appointments
  for select to authenticated
  using (
    public.is_premium()
    and (
      education_levels = '{}'
      or (select education_level from public.users where id = auth.uid()) = any (education_levels)
    )
  );

-- appointment_follows: Premium + kendi kayıtları
create policy follows_own on public.appointment_follows
  for all using (user_id = auth.uid() and public.is_premium())
  with check (user_id = auth.uid() and public.is_premium());

-- device_tokens: kendi cihazları
create policy tokens_own on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- 11) RPC: SORU GETİRME  (çözülmüşleri eler, eğitim seviyesine göre filtreler,
--                         freemium kotasını uygular, doğru cevabı SIZDIRMAZ)
-- ---------------------------------------------------------------------
create or replace function public.free_daily_limit() returns integer
language sql immutable as $$ select 20 $$;

create or replace function public.solved_today(uid uuid default auth.uid())
returns integer language sql stable security definer set search_path = public as $$
  select count(*)::int
  from public.user_solved_questions
  where user_id = uid
    and solved_at >= (date_trunc('day', now() at time zone 'Europe/Istanbul')
                      at time zone 'Europe/Istanbul');
$$;

create or replace function public.get_question_batch(
  p_subject subject_type,
  p_limit   integer default 10
)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_user    public.users%rowtype;
  v_premium boolean;
  v_left    integer;
  v_result  jsonb;
begin
  select * into v_user from public.users where id = v_uid;
  if not found then raise exception 'user_not_found'; end if;

  v_premium := public.is_premium(v_uid);
  v_left := p_limit;

  if not v_premium then
    if not (p_subject = any (v_user.free_subjects)) then
      raise exception 'subject_not_allowed_for_free_user';
    end if;
    v_left := least(p_limit, public.free_daily_limit() - public.solved_today(v_uid));
    if v_left <= 0 then raise exception 'daily_limit_reached'; end if;
  end if;

  select coalesce(jsonb_agg(q), '[]'::jsonb) into v_result
  from (
    select jsonb_build_object(
      'id', qs.id,
      'subject', qs.subject,
      'topic', qs.topic,
      'body', qs.body,
      'image_url', qs.image_url,
      'difficulty', qs.difficulty,
      'hint', qs.hint,
      'options', (
        select jsonb_agg(jsonb_build_object('label', o.label, 'body', o.body) order by o.label)
        from public.question_options o where o.question_id = qs.id
      )
    ) as q
    from public.questions qs
    where qs.is_active
      and qs.subject = p_subject
      and v_user.education_level = any (qs.education_levels)
      and not exists (
        select 1 from public.user_solved_questions u
        where u.user_id = v_uid and u.question_id = qs.id
      )
    order by random()
    limit v_left
  ) t;

  return v_result;
end $$;

-- ---------------------------------------------------------------------
-- 12) RPC: CEVAP GÖNDERME
--     - soruyu anında "çözüldü" olarak kaydeder (bir daha çıkmaz)
--     - doğru şık + TÜM şıkların açıklamaları + mnemonic döner
-- ---------------------------------------------------------------------
create or replace function public.submit_answer(
  p_question_id    uuid,
  p_selected_option char(1),         -- null => boş
  p_time_spent_sec integer default null
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_user    public.users%rowtype;
  v_q       public.questions%rowtype;
  v_correct char(1);
  v_is_ok   boolean;
begin
  select * into v_user from public.users where id = v_uid;
  select * into v_q from public.questions where id = p_question_id and is_active;
  if not found then raise exception 'question_not_found'; end if;

  if not public.is_premium(v_uid) then
    if not (v_q.subject = any (v_user.free_subjects)) then
      raise exception 'subject_not_allowed_for_free_user';
    end if;
    if public.solved_today(v_uid) >= public.free_daily_limit() then
      raise exception 'daily_limit_reached';
    end if;
  end if;

  select label into v_correct
  from public.question_options where question_id = p_question_id and is_correct;

  v_is_ok := (p_selected_option is not null and p_selected_option = v_correct);

  insert into public.user_solved_questions
    (user_id, question_id, selected_option, is_correct, time_spent_sec)
  values (v_uid, p_question_id, p_selected_option, v_is_ok, p_time_spent_sec);
  -- unique(user_id, question_id) ihlali => 'already_solved' hatası olarak istemciye döner

  return jsonb_build_object(
    'is_correct', v_is_ok,
    'correct_option', v_correct,
    'selected_option', p_selected_option,
    'mnemonic', v_q.mnemonic,
    'general_explanation', v_q.general_explanation,
    'options', (
      select jsonb_agg(jsonb_build_object(
        'label', o.label,
        'body', o.body,
        'is_correct', o.is_correct,
        'explanation', o.explanation
      ) order by o.label)
      from public.question_options o where o.question_id = p_question_id
    ),
    'remaining_today', case
      when public.is_premium(v_uid) then null
      else greatest(public.free_daily_limit() - public.solved_today(v_uid), 0)
    end
  );
end $$;

-- ---------------------------------------------------------------------
-- 13) RPC: DASHBOARD İSTATİSTİKLERİ
-- ---------------------------------------------------------------------
create or replace function public.get_dashboard_stats()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'solved_today', public.solved_today(auth.uid()),
    'correct_today', (
      select count(*) from public.user_solved_questions
      where user_id = auth.uid() and is_correct
        and solved_at >= (date_trunc('day', now() at time zone 'Europe/Istanbul')
                          at time zone 'Europe/Istanbul')
    ),
    'total_solved', (select count(*) from public.user_solved_questions where user_id = auth.uid()),
    'is_premium', public.is_premium(auth.uid()),
    'daily_limit', case when public.is_premium(auth.uid()) then null else public.free_daily_limit() end,
    'by_subject', (
      select coalesce(jsonb_object_agg(subject, cnt), '{}'::jsonb) from (
        select q.subject, count(*) as cnt
        from public.user_solved_questions u
        join public.questions q on q.id = u.question_id
        where u.user_id = auth.uid()
        group by q.subject
      ) s
    ),
    'next_exam', (
      select to_jsonb(e) from public.exams e
      where e.exam_date > now()
        and (select education_level from public.users where id = auth.uid()) = any (e.education_levels)
      order by e.exam_date asc limit 1
    )
  );
$$;

-- ---------------------------------------------------------------------
-- 14) YETKİLER
--     Python botu ve RevenueCat webhook'u service_role anahtarıyla çalışır
--     (RLS'i bypass eder) - bu anahtar ASLA Flutter uygulamasına konmaz.
-- ---------------------------------------------------------------------
revoke all on public.questions, public.question_options from anon, authenticated;
revoke insert, update, delete on public.user_solved_questions from anon, authenticated;
revoke insert, update, delete on public.subscriptions from anon, authenticated;
revoke insert, update, delete on public.appointments from anon, authenticated;

grant execute on function public.get_question_batch(subject_type, integer) to authenticated;
grant execute on function public.submit_answer(uuid, char, integer)       to authenticated;
grant execute on function public.get_dashboard_stats()                    to authenticated;

-- ---------------------------------------------------------------------
-- 15) PUSH BİLDİRİM TETİĞİ (sonraki adım)
--     appointments tablosuna INSERT olduğunda:
--     Database Webhook -> Edge Function `notify-new-appointment`
--     -> Premium + notify_new_appointments=true + eğitim seviyesi/nitelik kodu
--        eşleşen kullanıcıların device_tokens kayıtlarına FCM ile gönderim.
-- ---------------------------------------------------------------------
