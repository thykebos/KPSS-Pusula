-- =====================================================================
-- 0003: Aralıklı tekrar
--
-- Kural:
--   * Doğru çözülen soru bir daha ÇIKMAZ.
--   * Yanlış yapılan veya boş bırakılan soru, ertesi gün (Europe/Istanbul gece yarısından sonra)
--     yeniden karşına çıkar. Tekrarda yine yanlış yaparsan bir sonraki güne ertelenir;
--     doğru yaparsan artık hiç çıkmaz.
--   * Tekrar edilecek sorular, yeni sorulardan ÖNCE getirilir.
--   * Tekrarlar da günlük ücretsiz hakka sayılır.
--
-- Çalıştırma: 0001 ve 0002'den sonra, Supabase SQL Editor'de.
-- Güvenle tekrar çalıştırılabilir.
-- =====================================================================

alter table public.user_solved_questions
  add column if not exists attempts integer not null default 1,
  add column if not exists next_review_at timestamptz;

-- Daha önce yanlış yapılmış sorular, çözüldükleri günü izleyen günden itibaren tekrar edilebilir.
update public.user_solved_questions
set next_review_at =
      (date_trunc('day', solved_at at time zone 'Europe/Istanbul') + interval '1 day')
      at time zone 'Europe/Istanbul'
where not is_correct and next_review_at is null;

create index if not exists idx_usq_review
  on public.user_solved_questions (user_id, next_review_at)
  where not is_correct;

-- ---------------------------------------------------------------------
-- Soru getirme: çözülmemişler + tekrarı gelmiş yanlışlar (tekrarlar önce)
-- ---------------------------------------------------------------------
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

  select coalesce(jsonb_agg(s.q order by s.due_at asc nulls last, s.rnd), '[]'::jsonb)
  into v_result
  from (
    select
      jsonb_build_object(
        'id', qs.id,
        'subject', qs.subject,
        'topic', qs.topic,
        'body', qs.body,
        'image_url', qs.image_url,
        'difficulty', qs.difficulty,
        'hint', qs.hint,
        'is_review', (prev.question_id is not null),
        'options', (
          select jsonb_agg(jsonb_build_object('label', o.label, 'body', o.body) order by o.label)
          from public.question_options o where o.question_id = qs.id
        )
      ) as q,
      prev.next_review_at as due_at,
      random() as rnd
    from public.questions qs
    left join public.user_solved_questions prev
      on prev.user_id = v_uid and prev.question_id = qs.id
    where qs.is_active
      and qs.subject = p_subject
      and v_user.education_level = any (qs.education_levels)
      and (
        prev.question_id is null                       -- hiç çözülmemiş
        or (not prev.is_correct                        -- yanlış/boş yapılmış ve
            and coalesce(prev.next_review_at, 'infinity'::timestamptz) <= now())  -- tekrarı gelmiş
      )
    order by due_at asc nulls last, rnd
    limit v_left
  ) s;

  return v_result;
end $$;

-- ---------------------------------------------------------------------
-- Cevap gönderme: ilk cevap kayıt eder; tekrar cevabı mevcut kaydı günceller
-- ---------------------------------------------------------------------
create or replace function public.submit_answer(
  p_question_id     uuid,
  p_selected_option char(1),         -- null => boş
  p_time_spent_sec  integer default null
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_user    public.users%rowtype;
  v_q       public.questions%rowtype;
  v_prev    public.user_solved_questions%rowtype;
  v_correct char(1);
  v_is_ok   boolean;
  v_next    timestamptz;
  v_attempt integer := 1;
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

  select * into v_prev
  from public.user_solved_questions
  where user_id = v_uid and question_id = p_question_id;

  -- Doğru çözülmüş soru veya tekrarı henüz gelmemiş yanlış soru tekrar işaretlenemez.
  if found and (
       v_prev.is_correct
       or coalesce(v_prev.next_review_at, 'infinity'::timestamptz) > now()
     ) then
    raise exception 'already_solved';
  end if;

  select label into v_correct
  from public.question_options where question_id = p_question_id and is_correct;

  v_is_ok := (p_selected_option is not null and p_selected_option = v_correct);

  -- Yanlış/boş: bir sonraki günün başlangıcında (İstanbul) tekrar gelir. Doğru: hiç gelmez.
  v_next := case when v_is_ok then null else
    (date_trunc('day', now() at time zone 'Europe/Istanbul') + interval '1 day')
    at time zone 'Europe/Istanbul'
  end;

  if v_prev.id is not null then
    v_attempt := v_prev.attempts + 1;
    update public.user_solved_questions
    set selected_option = p_selected_option,
        is_correct      = v_is_ok,
        time_spent_sec  = p_time_spent_sec,
        solved_at       = now(),
        attempts        = v_attempt,
        next_review_at  = v_next
    where id = v_prev.id;
  else
    insert into public.user_solved_questions
      (user_id, question_id, selected_option, is_correct, time_spent_sec, next_review_at)
    values (v_uid, p_question_id, p_selected_option, v_is_ok, p_time_spent_sec, v_next);
    -- Aynı anda iki istek gelirse unique(user_id, question_id) ihlali 23505 verir;
    -- istemci bunu 'already_solved' olarak gösterir.
  end if;

  return jsonb_build_object(
    'is_correct', v_is_ok,
    'correct_option', v_correct,
    'selected_option', p_selected_option,
    'mnemonic', v_q.mnemonic,
    'general_explanation', v_q.general_explanation,
    'attempt_no', v_attempt,
    'review_tomorrow', not v_is_ok,
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
-- Ana ekran istatistikleri: "tekrar bekleyen" soru sayısı eklendi
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
    -- Şu an tekrar edilebilecek (yanlış yapılmış, günü gelmiş) soru sayısı.
    -- Ücretsiz kullanıcıda yalnızca erişebildiği dersler sayılır.
    'review_due', (
      select count(*)
      from public.user_solved_questions u
      join public.questions q on q.id = u.question_id and q.is_active
      where u.user_id = auth.uid()
        and not u.is_correct
        and coalesce(u.next_review_at, 'infinity'::timestamptz) <= now()
        and (select education_level from public.users where id = auth.uid()) = any (q.education_levels)
        and (public.is_premium(auth.uid())
             or exists (select 1 from public.users uu
                        where uu.id = auth.uid() and q.subject = any (uu.free_subjects)))
    ),
    'next_exam', (
      select to_jsonb(e) from public.exams e
      where e.exam_date > now()
        and (select education_level from public.users where id = auth.uid()) = any (e.education_levels)
      order by e.exam_date asc limit 1
    )
  );
$$;
