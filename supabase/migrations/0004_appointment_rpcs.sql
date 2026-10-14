-- =====================================================================
-- 0004: Atama Takip RPC fonksiyonları
--
-- Bu migration, Adım 5 kapsamında:
--   * İlan listeleme (filtreleme + sayfalama)
--   * Takip edilen ilanlar
--   * Takip ekle/kaldır
--   * İlan detayı (takip durumuyla birlikte)
--
-- NOT: get_appointments ve get_followed_appointments bu dosyada HATALIDIR (var olmayan `sub.row`
-- sütunu -> "Sunucu hatası"). 0005_appointments_v2.sql bunları siler ve doğrusunu kurar;
-- 0004'ten sonra mutlaka 0005'i de çalıştır.
--
-- Çalıştırma: Supabase SQL Editor'de, 0001/0002/0003'ten sonra.
-- Güvenle tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) İlan listeleme (filtreli, sayfalı)
-- ---------------------------------------------------------------------
create or replace function public.get_appointments(
  p_city              text default null,
  p_department        text default null,
  p_qualification     text default null,
  p_page              integer default 0,
  p_limit             integer default 20
)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_level  public.education_level;
  v_result jsonb;
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;

  select education_level into v_level from public.users where id = v_uid;

  select jsonb_build_object(
    'items', coalesce(jsonb_agg(sub.row order by sub.published_at desc), '[]'::jsonb),
    'total', coalesce(max(sub.full_count)::int, 0)
  )
  into v_result
  from (
    select a.*,
      case
        when exists (select 1 from public.appointment_follows f where f.user_id = v_uid and f.appointment_id = a.id)
        then true
        else false
      end as is_following,
      count(*) over() as full_count
    from public.appointments a
    where a.education_levels = '{}' or v_level = any (a.education_levels)
      and (p_city is null or a.city ilike '%' || p_city || '%')
      and (p_department is null or a.departments is null or p_department = any (a.departments))
      and (p_qualification is null or a.qualification_codes is null or p_qualification = any (a.qualification_codes))
    order by a.published_at desc
    limit p_limit
    offset p_page * p_limit
  ) sub;

  if v_result is null then
    return jsonb_build_object('items', '[]'::jsonb, 'total', 0);
  end if;

  return v_result;
end $$;

grant execute on function public.get_appointments(text, text, text, integer, integer) to authenticated;

-- ---------------------------------------------------------------------
-- 2) Takip edilen ilanlar (sayfalı)
-- ---------------------------------------------------------------------
create or replace function public.get_followed_appointments(
  p_page  integer default 0,
  p_limit integer default 20
)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_result jsonb;
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;

  select jsonb_build_object(
    'items', coalesce(jsonb_agg(sub.row order by sub.published_at desc), '[]'::jsonb),
    'total', coalesce(max(sub.full_count)::int, 0)
  )
  into v_result
  from (
    select a.*, true as is_following,
      count(*) over() as full_count
    from public.appointments a
    inner join public.appointment_follows f on f.appointment_id = a.id and f.user_id = v_uid
    order by a.published_at desc
    limit p_limit
    offset p_page * p_limit
  ) sub;

  if v_result is null then
    return jsonb_build_object('items', '[]'::jsonb, 'total', 0);
  end if;

  return v_result;
end $$;

grant execute on function public.get_followed_appointments(integer, integer) to authenticated;

-- ---------------------------------------------------------------------
-- 3) Takip ekle / kaldır (toggle)
-- ---------------------------------------------------------------------
create or replace function public.toggle_follow_appointment(
  p_appointment_id uuid
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_following boolean;
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;

  if exists (select 1 from public.appointment_follows where user_id = v_uid and appointment_id = p_appointment_id) then
    delete from public.appointment_follows where user_id = v_uid and appointment_id = p_appointment_id;
    v_following := false;
  else
    insert into public.appointment_follows (user_id, appointment_id) values (v_uid, p_appointment_id);
    v_following := true;
  end if;

  return jsonb_build_object('is_following', v_following);
end $$;

grant execute on function public.toggle_follow_appointment(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 4) Tek ilan detayı (takip durumuyla birlikte)
-- ---------------------------------------------------------------------
create or replace function public.get_appointment_detail(
  p_appointment_id uuid
)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_row  public.appointments%rowtype;
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;

  select * into v_row from public.appointments where id = p_appointment_id;
  if not found then
    raise exception 'appointment_not_found';
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'source', v_row.source,
    'title', v_row.title,
    'institution', v_row.institution,
    'city', v_row.city,
    'description', v_row.description,
    'education_levels', v_row.education_levels,
    'qualification_codes', v_row.qualification_codes,
    'departments', v_row.departments,
    'positions_count', v_row.positions_count,
    'application_start', v_row.application_start,
    'application_end', v_row.application_end,
    'url', v_row.url,
    'published_at', v_row.published_at,
    'is_following', exists (
      select 1 from public.appointment_follows f
      where f.user_id = v_uid and f.appointment_id = v_row.id
    )
  );
end $$;

grant execute on function public.get_appointment_detail(uuid) to authenticated;

-- 0) 0001_init.sql'de en sonda premium_required hatası yok, ekleyelim
create or replace function public.is_premium(uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = uid
      and s.status in ('active', 'trialing', 'grace_period')
      and (s.expires_at is null or s.expires_at > now())
  );
$$;

-- Yeni hata kodlarını error_mapper'a eklemek üzere not:
-- premium_required: 'Bu özellik yalnızca Premium üyeler içindir.'
-- appointment_not_found: 'İlan bulunamadı.'