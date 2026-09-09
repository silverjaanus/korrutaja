-- Korrutaja · migratsioon 3: Võistle üks kord päevas, nädalasse 5 parimat päeva
-- Kleebi tervikuna Supabase'i SQL Editorisse ja vajuta Run.
-- Ohutu: ei kustuta ega muuda ühtki rida, ainult asendab funktsioone.
-- Võistlus salvestub endiselt mode='test' nimega, et praegu üleval olev versioon ei katkeks.

-- ---------- 1. ühe mängija nädalapunktid = 5 parimat võistluspäeva ----------
create or replace function public.week_score(p_player uuid, p_ws timestamptz) returns int
language sql stable as $$
  select coalesce(sum(best), 0)::int from (
    select max(s.ok) as best
      from sessions s
     where s.player_id = p_player and s.mode = 'test' and s.created_at >= p_ws
     group by (s.created_at at time zone 'Europe/Tallinn')::date
     order by max(s.ok) desc
     limit 5
  ) d
$$;
revoke execute on function public.week_score(uuid, timestamptz) from public, anon, authenticated;

-- ---------- 2. klassi nädalapunktid ja võistelnute arv ----------
create or replace function public.class_week(p_class uuid, p_ws timestamptz)
returns table(week_n int, active int)
language sql stable as $$
  select
    coalesce((select sum(week_score(p.id, p_ws)) from players p where p.class_id = p_class), 0)::int,
    coalesce((select count(distinct s.player_id)
                from sessions s join players p on p.id = s.player_id
               where p.class_id = p_class and s.mode = 'test' and s.created_at >= p_ws), 0)::int
$$;
revoke execute on function public.class_week(uuid, timestamptz) from public, anon, authenticated;

-- ---------- 3. kas mängija on täna juba võistelnud ----------
create or replace function public.competed_today(p_player uuid) returns boolean
language sql stable as $$
  select exists (
    select 1 from sessions
     where player_id = p_player and mode = 'test'
       and (created_at at time zone 'Europe/Tallinn')::date = (now() at time zone 'Europe/Tallinn')::date
  )
$$;
revoke execute on function public.competed_today(uuid) from public, anon, authenticated;

-- ---------- 4. report_session: võistlus ainult üks kord päevas ----------
create or replace function public.report_session(
  p_player_id uuid, p_secret text, p_mode text, p_op text,
  p_n int, p_ok int, p_score int, p_avg real,
  p_greens_mul int, p_greens_div int, p_best_test int, p_state jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_p players%rowtype;
begin
  select * into v_p from players where id = p_player_id and secret = p_secret;
  if not found then return jsonb_build_object('error', 'auth'); end if;
  if p_mode not in ('train', 'test') or p_op not in ('mul', 'div', 'mix') then return jsonb_build_object('error', 'input'); end if;
  if p_n is null or p_n < 1 or p_n > 300 or p_ok is null or p_ok < 0 or p_ok > p_n then return jsonb_build_object('error', 'input'); end if;
  if p_state is not null and pg_column_size(p_state) > 300000 then return jsonb_build_object('error', 'input'); end if;

  -- Võistelda saab üks kord Eesti kalendripäevas. Kella keeramine telefonis ei aita.
  -- Harjutamise ring salvestub ikka, ainult võistlustulemust ei võeta teist korda vastu.
  if p_mode = 'test' and competed_today(v_p.id) then
    update players set
      greens_mul = greatest(0, least(coalesce(p_greens_mul, 0), 55)),
      greens_div = greatest(0, least(coalesce(p_greens_div, 0), 55)),
      state      = coalesce(p_state, state),
      last_seen  = now()
    where id = v_p.id;
    return jsonb_build_object('error', 'done_today');
  end if;

  insert into sessions(player_id, class_id, mode, op, n, ok, score, avg_t)
  values (v_p.id, v_p.class_id, p_mode, p_op, p_n, p_ok, greatest(0, least(coalesce(p_score, 0), 10000)), p_avg);

  update players set
    greens_mul    = greatest(0, least(coalesce(p_greens_mul, 0), 55)),
    greens_div    = greatest(0, least(coalesce(p_greens_div, 0), 55)),
    best_test     = greatest(best_test, greatest(0, least(coalesce(p_best_test, 0), 25))),
    total_answers = total_answers + p_n,
    total_correct = total_correct + p_ok,
    state         = coalesce(p_state, state),
    last_seen     = now()
  where id = v_p.id;

  return jsonb_build_object('ok', true, 'competed_today', competed_today(v_p.id));
end $$;

-- ---------- 5. edetabelid nädala uue reegli järgi ----------
create or replace function public.class_board(p_player_id uuid, p_secret text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_p players%rowtype; v_ws timestamptz := week_start();
  v_c classes%rowtype; v_cw record;
  v_players jsonb; v_class jsonb; v_classes jsonb; v_siblings jsonb := '[]'::jsonb; v_peers jsonb := '[]'::jsonb;
begin
  select * into v_p from players where id = p_player_id and secret = p_secret;
  if not found then return jsonb_build_object('error', 'auth'); end if;
  update players set last_seen = now() where id = v_p.id;
  select * into v_c from classes where id = v_p.class_id;
  select * into v_cw from class_week(v_p.class_id, v_ws);

  -- oma klassi mängijad. week_n = 5 parima võistluspäeva summa.
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_players from (
    select jsonb_build_object(
      'id', p.id, 'nick', p.nick,
      'greens', p.greens_mul + p.greens_div, 'greens_mul', p.greens_mul, 'greens_div', p.greens_div,
      'best_test', p.best_test, 'total_n', p.total_answers,
      'week_n', week_score(p.id, v_ws),
      'days', (select count(distinct (s.created_at at time zone 'Europe/Tallinn')::date)
                 from sessions s where s.player_id = p.id and s.mode = 'test' and s.created_at >= v_ws)
    ) as x
    from players p where p.class_id = v_p.class_id
  ) q;

  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'code', c.code, 'kind', c.kind,
    'school', c.school, 'grade', c.grade, 'letter', c.grade_letter,
    'week_n', v_cw.week_n, 'active_week', v_cw.active,
    'total_n', coalesce((select sum(n) from sessions where class_id = c.id), 0),
    'players', (select count(*) from players where class_id = c.id)
  ) into v_class from classes c where c.id = v_p.class_id;

  -- vana võti, et praegu üleval olev versioon ei katkeks
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_classes from (
    select jsonb_build_object('id', c.id, 'name', c.name, 'week_n', w.week_n, 'active', w.active,
                              'per_player', round(w.week_n::numeric / greatest(w.active, 1))) as x
    from classes c cross join lateral class_week(c.id, v_ws) w
    where w.active > 0
    order by (w.week_n::numeric / greatest(w.active, 1)) desc
    limit 20
  ) q;

  if v_c.kind = 'class' and v_c.grade is not null then
    -- sama kool, sama aste
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_siblings from (
      select jsonb_build_object(
        'id', c.id, 'name', coalesce(c.grade::text, '') || coalesce(c.grade_letter, ''),
        'week_n', w.week_n, 'active', w.active,
        'per_player', round(w.week_n::numeric / greatest(w.active, 1))) as x
      from classes c cross join lateral class_week(c.id, v_ws) w
      where c.kind = 'class' and c.school_key = v_c.school_key and c.grade = v_c.grade
      order by (w.week_n::numeric / greatest(w.active, 1)) desc, c.name
      limit 20
    ) q;

    -- sama aste üle Eesti
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_peers from (
      select jsonb_build_object(
        'id', c.id, 'name', c.name, 'school', c.school,
        'week_n', w.week_n, 'active', w.active,
        'per_player', round(w.week_n::numeric / greatest(w.active, 1))) as x
      from classes c cross join lateral class_week(c.id, v_ws) w
      where c.kind = 'class' and c.grade = v_c.grade
      order by (w.week_n::numeric / greatest(w.active, 1)) desc, c.name
      limit 20
    ) q;
  end if;

  return jsonb_build_object('me', v_p.id, 'week_start', v_ws, 'class', v_class,
                            'players', v_players, 'classes', v_classes,
                            'siblings', v_siblings, 'peers', v_peers,
                            'competed_today', competed_today(v_p.id));
end $$;

-- Valmis. Reeglid pärast seda migratsiooni:
--   * Võistelda saab üks kord Eesti kalendripäevas (server kontrollib).
--   * Nädalapunktid = viie parima võistluspäeva õigete vastuste summa.
--   * Harjutamine on piiramatu ja ei mõjuta nädalapunkte.
