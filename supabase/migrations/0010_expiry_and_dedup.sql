-- =====================================================================
-- 0010: Eskiyen ilanlar otomatik kalkar + mevcut tekrar ilanlar temizlenir
--
--  1) appointment_is_active(): bir ilan "güncel" mi?
--       • son başvuru tarihi varsa: henüz geçmemiş olmalı
--       • yoksa: yayın tarihi 45 günden eski olmamalı (botun max_age_days kuralıyla aynı)
--  2) get_appointments: yalnızca güncel ilanları listeler. Böylece süresi biten ilan, bot çalışmasa
--     bile uygulamadan ANINDA kalkar. get_followed_appointments (takip edilenler) için de aynı.
--     Şehir filtresi artık TAM eşleşme (uygulamada şehir listeden seçiliyor; "Muş" ≠ "Gümüşhane").
--  3) purge_stale_appointments: bekleme süresi 7 günden 0'a, belirsiz tarihli ilan süresi 90'dan 45'e indi.
--     Takip edilen ilanlar yine silinmez.
--  4) pg_cron varsa temizlik saat başı kendiliğinden çalışır (yoksa bot her taramada çağırmaya devam eder).
--  5) BİR KERELİK: aynı (kurum, başlık, son başvuru günü) olan tekrar satırlar silinir; en eski kalır,
--     takip edilen satır varsa o kalır.
--
-- Çalıştırma: Supabase SQL Editor'de, 0001-0009'dan sonra. Güvenle tekrar çalıştırılabilir.
-- =====================================================================

-- 1) Güncel mi?
create or replace function public.appointment_is_active(
  p_end          timestamptz,
  p_published    timestamptz,
  p_max_age_days integer default 45
) returns boolean
language sql stable set search_path = public as $$
  select case
           when p_end is not null then p_end >= now()
           else p_published >= now() - make_interval(days => p_max_age_days)
         end;
$$;

-- 2) İlan listesi: 0005'teki fonksiyonla aynı, yalnızca "güncel" koşulu eklendi.
create or replace function public.get_appointments(
  p_city           text    default null,
  p_department     text    default null,
  p_qualification  text    default null,
  p_kpss           text    default 'all',
  p_query          text    default null,
  p_my_professions boolean default false,
  p_page           integer default 0,
  p_limit          integer default 20
)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_level  public.education_level;
  v_profs  text[];
  v_limit  integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_page   integer := greatest(coalesce(p_page, 0), 0);
  v_result jsonb;
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;

  select u.education_level, u.followed_professions
    into v_level, v_profs
  from public.users u where u.id = v_uid;

  select jsonb_build_object(
           'items', coalesce(jsonb_agg(to_jsonb(s) - 'raw' - 'external_id' - 'full_count' - 'rn'
                                       order by s.rn), '[]'::jsonb),
           'total', coalesce(max(s.full_count), 0)
         )
    into v_result
  from (
    select b.*,
           count(*) over () as full_count,
           row_number() over (order by b.matches_profession desc,
                                       b.published_at desc, b.id) as rn
    from (
      select a.*,
             public.profession_match(v_profs, a.title, a.description, a.institution, a.departments)
               as matches_profession,
             exists (select 1 from public.appointment_follows f
                     where f.user_id = v_uid and f.appointment_id = a.id) as is_following
      from public.appointments a
      where public.appointment_is_active(a.application_end, a.published_at)
        and (a.education_levels = '{}' or v_level = any (a.education_levels))
        -- Şehir artık listeden SEÇİLİYOR: tam eşleşme. (Eskiden "içerir" araması vardı; "Muş" seçilince
        -- "Gümüşhane" de geliyordu, çünkü tr_fold('Gümüşhane') = 'gumushane' içinde 'mus' geçer.)
        and (p_city is null or btrim(p_city) = ''
             or public.tr_fold(a.city) = public.tr_fold(btrim(p_city)))
        and (p_department is null or cardinality(a.departments) = 0
             or exists (select 1 from unnest(a.departments) d
                        where public.tr_fold(d) like '%' || public.like_escape(public.tr_fold(p_department)) || '%'))
        and (p_qualification is null or cardinality(a.qualification_codes) = 0
             or p_qualification = any (a.qualification_codes))
        and (p_kpss = 'all' or p_kpss is null
             or (p_kpss = 'kpss' and a.kpss_required)
             or (p_kpss = 'nokpss' and not a.kpss_required))
        and (p_query is null or btrim(p_query) = ''
             or public.tr_fold(concat_ws(' ', a.title, a.institution, a.city, a.description))
                  like '%' || public.like_escape(public.tr_fold(btrim(p_query))) || '%')
    ) b
    where (not p_my_professions) or b.matches_profession
    order by rn
    limit v_limit offset v_page * v_limit
  ) s;

  return coalesce(v_result, jsonb_build_object('items', '[]'::jsonb, 'total', 0));
end $$;

grant execute on function public.get_appointments(text, text, text, text, text, boolean, integer, integer)
  to authenticated;

-- 2b) Takip edilenler listesi: süresi dolan ilan burada da görünmez (0005'teki fonksiyonla aynı,
--     yalnızca "güncel" koşulu eklendi). Satırlar silinmez; yalnızca listelenmez.
create or replace function public.get_followed_appointments(
  p_page  integer default 0,
  p_limit integer default 20
)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_profs  text[];
  v_limit  integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_page   integer := greatest(coalesce(p_page, 0), 0);
  v_result jsonb;
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;

  select u.followed_professions into v_profs from public.users u where u.id = v_uid;

  select jsonb_build_object(
           'items', coalesce(jsonb_agg(to_jsonb(s) - 'raw' - 'external_id' - 'full_count' - 'rn'
                                       order by s.rn), '[]'::jsonb),
           'total', coalesce(max(s.full_count), 0)
         )
    into v_result
  from (
    select a.*,
           true as is_following,
           public.profession_match(v_profs, a.title, a.description, a.institution, a.departments)
             as matches_profession,
           count(*) over () as full_count,
           row_number() over (order by f.created_at desc, a.id) as rn
    from public.appointments a
    join public.appointment_follows f on f.appointment_id = a.id and f.user_id = v_uid
    where public.appointment_is_active(a.application_end, a.published_at)
    order by rn
    limit v_limit offset v_page * v_limit
  ) s;

  return coalesce(v_result, jsonb_build_object('items', '[]'::jsonb, 'total', 0));
end $$;

grant execute on function public.get_followed_appointments(integer, integer) to authenticated;

-- 3) Temizlik fonksiyonu (varsayılanlar değişti; bot argümansız çağırır)
drop function if exists public.purge_stale_appointments(integer, integer);

create function public.purge_stale_appointments(
  p_grace_days   integer default 0,
  p_max_age_days integer default 45
) returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_deleted integer;
begin
  with gone as (
    delete from public.appointments a
    where not exists (select 1 from public.appointment_follows f where f.appointment_id = a.id)
      and (
        (a.application_end is not null and a.application_end < now() - make_interval(days => p_grace_days))
        or (a.application_end is null and a.published_at < now() - make_interval(days => p_max_age_days))
      )
    returning 1
  )
  select count(*) into v_deleted from gone;
  return v_deleted;
end $$;

revoke all on function public.purge_stale_appointments(integer, integer) from public, anon, authenticated;
grant execute on function public.purge_stale_appointments(integer, integer) to service_role;

-- 4) Saat başı otomatik temizlik (pg_cron). Kullanılamıyorsa atlanır; liste zaten güncel olmayanı göstermez.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    begin
      perform cron.unschedule('purge-stale-appointments');
    exception when others then null;  -- iş henüz yoksa
    end;
    perform cron.schedule('purge-stale-appointments', '5 * * * *', 'select public.purge_stale_appointments()');
    raise notice 'pg_cron: saat başı temizlik kuruldu.';
  else
    raise notice 'pg_cron yok: temizliği bot her taramada yapar; liste güncel olmayan ilanı zaten göstermez.';
  end if;
exception when others then
  raise notice 'pg_cron kurulamadı (%). Önemli değil: liste güncel olmayan ilanı göstermez, bot da temizler.', sqlerrm;
end $$;

-- 5) BİR KERELİK: tekrar ilanları sil (aynı kurum + başlık + son başvuru günü).
--    Karşılaştırma büyük/küçük harf, Türkçe harf ve noktalamadan bağımsızdır. Takip edilen satırlar silinmez.
do $$
declare
  v_deleted integer;
begin
  with ranked as (
    select a.id,
           row_number() over (
             partition by
               regexp_replace(public.tr_fold(a.institution), '[^a-z0-9]+', ' ', 'g'),
               regexp_replace(public.tr_fold(a.title),       '[^a-z0-9]+', ' ', 'g'),
               (a.application_end at time zone 'Europe/Istanbul')::date
             order by
               exists (select 1 from public.appointment_follows f where f.appointment_id = a.id) desc,
               a.created_at, a.id
           ) as rn
    from public.appointments a
  ),
  gone as (
    delete from public.appointments d
    using ranked r
    where d.id = r.id and r.rn > 1
      and not exists (select 1 from public.appointment_follows f where f.appointment_id = d.id)
    returning 1
  )
  select count(*) into v_deleted from gone;
  raise notice 'Silinen tekrar ilan sayısı: %', v_deleted;
end $$;

select source, count(*) as ilan_sayisi
from public.appointments
group by source
order by ilan_sayisi desc;   -- temizlik sonrası kaynak başına güncel ilan sayısı
