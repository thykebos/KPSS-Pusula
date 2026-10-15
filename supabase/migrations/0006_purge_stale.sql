-- =====================================================================
-- 0006: Eski ilanların otomatik temizliği
-- Bot her taramadan sonra bu fonksiyonu çağırır (service_role). Silinenler:
--   • son başvuru tarihi, `p_grace_days` günden daha önce geçmiş ilanlar
--   • bitiş tarihi olmayıp yayın tarihi `p_max_age_days` günden eski ilanlar
-- Bir kullanıcının TAKİP ETTİĞİ ilan silinmez. Tekrar çalıştırılabilir.
-- =====================================================================
create or replace function public.purge_stale_appointments(
  p_grace_days   integer default 7,
  p_max_age_days integer default 90
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

-- Yalnızca bot (service_role) çağırabilir; uygulama kullanıcıları çağıramaz.
revoke all on function public.purge_stale_appointments(integer, integer) from public, anon, authenticated;
grant execute on function public.purge_stale_appointments(integer, integer) to service_role;
