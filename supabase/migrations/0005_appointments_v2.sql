-- =====================================================================
-- 0005: Atama Takip v2
--   1) 0004'teki "Sunucu hatası" düzeltmesi: get_appointments / get_followed_appointments
--      var olmayan `sub.row` sütununa başvuruyordu; filtrelerde AND/OR önceliği de yanlıştı.
--   2) Kullanıcının takip ettiği MESLEKLER (users.followed_professions).
--   3) KPSS'li / KPSS'siz ilan ayrımı (appointments.kpss_required).
--   4) Yeni kaynaklar: pgm_adalet, iskur.
--   5) Sahte [ÖRNEK] ilanların temizliği.
-- Çalıştırma: 0001-0004'ten sonra, Supabase SQL Editor'de. Tekrar çalıştırılabilir.
-- =====================================================================

-- 4) Yeni kaynak değerleri (kullanılmadan önce ayrı çalışır)
alter type appointment_source add value if not exists 'pgm_adalet'; -- pgm.adalet.gov.tr
alter type appointment_source add value if not exists 'iskur';      -- iskur.gov.tr

-- 2) Takip edilen meslekler
alter table public.users
  add column if not exists followed_professions text[] not null default '{}';

do $$ begin
  alter table public.users
    add constraint followed_professions_max check (coalesce(array_length(followed_professions, 1), 0) <= 20);
exception when duplicate_object then null; end $$;

grant update (followed_professions) on public.users to authenticated;

-- 3) KPSS şartı
alter table public.appointments
  add column if not exists kpss_required boolean not null default true;

-- İlanlar tarayıcıdan gelir: aynı kaynakta aynı ilan tekrar eklenmesin diye mevcut
-- unique(source, external_id) kullanılır. Hızlı filtre için indeks:
create index if not exists idx_app_kpss on public.appointments(kpss_required);

-- 5) Sahte örnek ilanları sil (sample_appointments.sql'den kalanlar)
delete from public.appointments where source = 'diger' and external_id like 'ornek-%';

-- ---------------------------------------------------------------------
-- Yardımcılar: Türkçe harf/büyük-küçük harf duyarsız karşılaştırma
-- ("HEMŞİRE" = "hemşire", "Şoför" = "soför")
-- ---------------------------------------------------------------------
create or replace function public.tr_fold(p text)
returns text language sql stable set search_path = public as $$
  select lower(translate(coalesce(p, ''), 'İIıŞşĞğÜüÖöÇç', 'iiissgguuoocc'));
$$;

-- LIKE özel karakterlerini kaçır
create or replace function public.like_escape(p text)
returns text language sql immutable as $$
  select replace(replace(replace(p, '\', '\\'), '%', '\%'), '_', '\_');
$$;

-- İlan, kullanıcının takip ettiği mesleklerden en az biriyle eşleşiyor mu?
create or replace function public.profession_match(
  p_profs text[], p_title text, p_description text, p_institution text, p_departments text[]
) returns boolean language sql stable set search_path = public as $$
  select coalesce((
    select bool_or(
      public.tr_fold(concat_ws(' ', p_title, p_description, p_institution,
                               array_to_string(p_departments, ' ')))
        like '%' || public.like_escape(public.tr_fold(btrim(p))) || '%'
    )
    from unnest(coalesce(p_profs, '{}')) p
    where length(btrim(p)) >= 2
  ), false);
$$;

-- ---------------------------------------------------------------------
-- İlan listesi (eski imza kaldırılır, yenisi oluşturulur)
-- p_kpss: 'all' | 'kpss' | 'nokpss'
-- ---------------------------------------------------------------------
drop function if exists public.get_appointments(text, text, text, integer, integer);
drop function if exists public.get_followed_appointments(integer, integer);

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
      where (a.education_levels = '{}' or v_level = any (a.education_levels))
        and (p_city is null or public.tr_fold(a.city) like '%' || public.like_escape(public.tr_fold(p_city)) || '%')
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

-- ---------------------------------------------------------------------
-- Takip edilen ilanlar
-- ---------------------------------------------------------------------
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
    order by rn
    limit v_limit offset v_page * v_limit
  ) s;

  return coalesce(v_result, jsonb_build_object('items', '[]'::jsonb, 'total', 0));
end $$;

grant execute on function public.get_followed_appointments(integer, integer) to authenticated;

-- ---------------------------------------------------------------------
-- Takip aç/kapat: olmayan ilan için anlaşılır hata
-- ---------------------------------------------------------------------
create or replace function public.toggle_follow_appointment(p_appointment_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_following boolean;
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;
  if not exists (select 1 from public.appointments where id = p_appointment_id) then
    raise exception 'appointment_not_found';
  end if;

  if exists (select 1 from public.appointment_follows
             where user_id = v_uid and appointment_id = p_appointment_id) then
    delete from public.appointment_follows
     where user_id = v_uid and appointment_id = p_appointment_id;
    v_following := false;
  else
    insert into public.appointment_follows (user_id, appointment_id) values (v_uid, p_appointment_id);
    v_following := true;
  end if;
  return jsonb_build_object('is_following', v_following);
end $$;

-- ---------------------------------------------------------------------
-- İlan detayı: kpss_required eklendi
-- ---------------------------------------------------------------------
create or replace function public.get_appointment_detail(p_appointment_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_row   public.appointments%rowtype;
  v_profs text[];
begin
  if not public.is_premium(v_uid) then
    raise exception 'premium_required';
  end if;

  select * into v_row from public.appointments where id = p_appointment_id;
  if not found then
    raise exception 'appointment_not_found';
  end if;

  select u.followed_professions into v_profs from public.users u where u.id = v_uid;

  return to_jsonb(v_row) - 'raw' - 'external_id'
    || jsonb_build_object(
         'is_following', exists (select 1 from public.appointment_follows f
                                 where f.user_id = v_uid and f.appointment_id = v_row.id),
         'matches_profession',
           public.profession_match(v_profs, v_row.title, v_row.description,
                                   v_row.institution, v_row.departments));
end $$;

grant execute on function public.get_appointment_detail(uuid) to authenticated;
