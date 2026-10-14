-- =====================================================================
-- 0002: Profil güvenliği
-- Sorun: users tablosunda "kendi satırını güncelle" izni, ücretsiz kullanıcının
-- free_subjects sütununu istediği zaman değiştirip "2 ders" kuralını delmesine izin veriyordu.
-- Çözüm: sütun bazlı yetki + sadece kuralları uygulayan bir RPC.
-- =====================================================================

-- İstemci artık users tablosunda yalnızca bu sütunları güncelleyebilir.
revoke update on public.users from authenticated;
grant update (
  full_name,
  education_level,
  department,
  qualification_codes,
  notify_new_appointments,
  target_exam_id
) on public.users to authenticated;

-- Ücretsiz dersleri seçme: tam 2 farklı ders; ücretsiz kullanıcı yalnızca BİR KEZ seçebilir,
-- premium kullanıcı değiştirebilir.
create or replace function public.set_free_subjects(p_subjects subject_type[])
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_current subject_type[];
begin
  if coalesce(array_length(p_subjects, 1), 0) <> 2
     or (select count(distinct s) from unnest(p_subjects) s) <> 2 then
    raise exception 'exactly_two_distinct_subjects_required';
  end if;

  select free_subjects into v_current from public.users where id = auth.uid();

  if coalesce(array_length(v_current, 1), 0) > 0 and not public.is_premium(auth.uid()) then
    raise exception 'free_subjects_already_set';
  end if;

  update public.users set free_subjects = p_subjects where id = auth.uid();
end $$;

grant execute on function public.set_free_subjects(subject_type[]) to authenticated;
