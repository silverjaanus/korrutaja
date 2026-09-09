-- Korrutaja · migratsioon 5: class_board set-põhiseks (skaleerimine)
-- Kleebi tervikuna Supabase'i SQL Editorisse ja vajuta Run.
-- Ohutu: asendab ainult class_board funktsiooni. Tagastusformaat on identne
-- (samad JSON-võtmed), nii et kliendikoodi muutma ei pea.
--
-- Miks: vana versioon tegi iga edetabeliklassi kohta eraldi `cross join lateral
-- class_week(...)`, mis omakorda arvutas week_score iga mängija kohta alampäringuna
-- (~klasside arv × mängijad alampäringut ühe vaate kohta). Uus versioon arvutab
-- kõik nädalapunktid ühe akna-funktsiooniga kahte ajutisse tabelisse ja loeb neist.

create or replace function public.class_board(p_player_id uuid, p_secret text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_p players%rowtype; v_ws timestamptz := week_start();
  v_c classes%rowtype;
  v_players jsonb; v_class jsonb; v_classes jsonb;
  v_siblings jsonb := '[]'::jsonb; v_peers jsonb := '[]'::jsonb;
begin
  select * into v_p from players where id = p_player_id and secret = p_secret;
  if not found then return jsonb_build_object('error', 'auth'); end if;
  update players set last_seen = now() where id = v_p.id;
  select * into v_c from classes where id = v_p.class_id;

  -- Selle nädala võistluspäevad: iga mängija-päeva parim tulemus (üks pass).
  create temp table _daily on commit drop as
    select s.player_id, p.class_id,
           (s.created_at at time zone 'Europe/Tallinn')::date as d,
           max(s.ok) as best
      from sessions s join players p on p.id = s.player_id
     where s.mode = 'test' and s.created_at >= v_ws
     group by s.player_id, p.class_id, (s.created_at at time zone 'Europe/Tallinn')::date;

  -- Mängija nädalapunktid = viie parima päeva summa; days = võistluspäevi kokku.
  create temp table _pw on commit drop as
    with r as (
      select player_id, class_id, best,
             row_number() over (partition by player_id order by best desc) as rn
        from _daily)
    select player_id, class_id,
           coalesce(sum(best) filter (where rn <= 5), 0)::int as week_n,
           count(*)::int as days
      from r group by player_id, class_id;

  -- Klassi koond: nädalapunktid ja aktiivsete võistlejate arv.
  create temp table _cw on commit drop as
    select class_id, sum(week_n)::int as week_n, count(*)::int as active
      from _pw group by class_id;

  -- oma klassi mängijad
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_players from (
    select jsonb_build_object(
      'id', p.id, 'nick', p.nick,
      'greens', p.greens_mul + p.greens_div, 'greens_mul', p.greens_mul, 'greens_div', p.greens_div,
      'best_test', p.best_test, 'total_n', p.total_answers,
      'week_n', coalesce(pw.week_n, 0),
      'days', coalesce(pw.days, 0)
    ) as x
    from players p
    left join _pw pw on pw.player_id = p.id
    where p.class_id = v_p.class_id
  ) q;

  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'code', c.code, 'kind', c.kind,
    'school', c.school, 'grade', c.grade, 'letter', c.grade_letter,
    'week_n', coalesce(cw.week_n, 0), 'active_week', coalesce(cw.active, 0),
    'total_n', coalesce((select sum(n) from sessions where class_id = c.id), 0),
    'players', (select count(*) from players where class_id = c.id)
  ) into v_class from classes c left join _cw cw on cw.class_id = c.id where c.id = v_p.class_id;

  -- vana võti, et vana index.html ei katkeks
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_classes from (
    select jsonb_build_object('id', c.id, 'name', c.name, 'week_n', cw.week_n, 'active', cw.active,
                              'per_player', round(cw.week_n::numeric / greatest(cw.active, 1))) as x
    from classes c join _cw cw on cw.class_id = c.id
    where cw.active > 0
    order by (cw.week_n::numeric / greatest(cw.active, 1)) desc
    limit 20
  ) q;

  if v_c.kind = 'class' and v_c.grade is not null then
    -- sama kool, sama aste
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_siblings from (
      select jsonb_build_object(
        'id', c.id, 'name', coalesce(c.grade::text, '') || coalesce(c.grade_letter, ''),
        'week_n', coalesce(cw.week_n, 0), 'active', coalesce(cw.active, 0),
        'per_player', round(coalesce(cw.week_n, 0)::numeric / greatest(coalesce(cw.active, 0), 1))) as x
      from classes c left join _cw cw on cw.class_id = c.id
      where c.kind = 'class' and c.school_key = v_c.school_key and c.grade = v_c.grade
      order by coalesce(cw.week_n, 0)::numeric / greatest(coalesce(cw.active, 0), 1) desc, c.name
      limit 20
    ) q;

    -- sama aste üle Eesti
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_peers from (
      select jsonb_build_object(
        'id', c.id, 'name', c.name, 'school', c.school,
        'week_n', coalesce(cw.week_n, 0), 'active', coalesce(cw.active, 0),
        'per_player', round(coalesce(cw.week_n, 0)::numeric / greatest(coalesce(cw.active, 0), 1))) as x
      from classes c left join _cw cw on cw.class_id = c.id
      where c.kind = 'class' and c.grade = v_c.grade
      order by coalesce(cw.week_n, 0)::numeric / greatest(coalesce(cw.active, 0), 1) desc, c.name
      limit 20
    ) q;
  end if;

  drop table if exists _daily; drop table if exists _pw; drop table if exists _cw;

  return jsonb_build_object('me', v_p.id, 'week_start', v_ws, 'class', v_class,
                            'players', v_players, 'classes', v_classes,
                            'siblings', v_siblings, 'peers', v_peers,
                            'competed_today', competed_today(v_p.id));
end $$;

-- Valmis. Tagastusformaat sama; edetabel arvutatakse nüüd ühe passiga, mitte
-- klass-korda-mängija alampäringutega. week_score/class_week jäävad alles (kasutusest väljas).
