-- Korrutaja · migratsioon 2: kool + klassiaste + tiimid
-- Kleebi tervikuna Supabase'i SQL Editorisse ja vajuta Run.
-- Ohutu: ainult lisab. Vana create_class ja class_board 'classes' võti jäävad alles,
-- nii et praegu üleval olev index.html töötab edasi kuni uus versioon deploy'takse.

-- ---------- 1. uued veerud ----------
alter table public.classes
  add column if not exists kind         text not null default 'class',
  add column if not exists school       text,
  add column if not exists school_key   text,
  add column if not exists grade        int,
  add column if not exists grade_letter text;

alter table public.classes drop constraint if exists classes_kind_chk;
alter table public.classes add constraint classes_kind_chk check (kind in ('class','team'));
alter table public.classes drop constraint if exists classes_grade_chk;
alter table public.classes add constraint classes_grade_chk check (grade is null or (grade between 1 and 12));

create index if not exists classes_school_grade on public.classes(school_key, grade) where kind = 'class';
create index if not exists classes_grade        on public.classes(grade)             where kind = 'class';

-- ---------- 2. koolinime normaliseerimine ----------
-- "  Õismäe   Gümnaasium " ja "õismäe gümnaasium" annavad sama võtme.
create or replace function public.norm_school(p text) returns text
language sql immutable as $$
  select nullif(regexp_replace(btrim(lower(coalesce(p, ''))), '\s+', ' ', 'g'), '')
$$;
revoke execute on function public.norm_school(text) from public, anon, authenticated;

-- ---------- 3. uus loomisfunktsioon ----------
-- Kooliklass: kind='class', kool + aste + täht. Nimi pannakse kokku: "Õismäe Gümnaasium 3B".
-- Tiim:       kind='team', ainult vaba nimi. Tiim ei osale kooli- ega astmevõrdluses.
create or replace function public.create_group(
  p_kind text, p_school text, p_grade int, p_letter text, p_name text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_kind   text := lower(btrim(coalesce(p_kind, 'class')));
  v_school text := left(regexp_replace(btrim(coalesce(p_school, '')), '\s+', ' ', 'g'), 60);
  v_letter text := upper(left(btrim(coalesce(p_letter, '')), 1));
  v_name   text := left(btrim(coalesce(p_name, '')), 40);
  v_code text; v_id uuid; i int := 0; v_existing text;
begin
  if v_kind not in ('class', 'team') then return jsonb_build_object('error', 'input'); end if;

  if v_kind = 'class' then
    if length(v_school) < 2 then return jsonb_build_object('error', 'school'); end if;
    if p_grade is null or p_grade < 1 or p_grade > 12 then return jsonb_build_object('error', 'grade'); end if;
    if v_letter <> '' and v_letter !~ '^[A-ZÕÄÖÜ]$' then return jsonb_build_object('error', 'letter'); end if;
    -- kui see kool on juba kirjas, kasuta esimesena sisestatud kirjapilti
    select c.school into v_existing from classes c
      where c.kind = 'class' and c.school_key = norm_school(v_school)
      order by c.created_at limit 1;
    if v_existing is not null then v_school := v_existing; end if;
    v_name := v_school || ' ' || p_grade::text || v_letter;
  else
    if length(v_name) < 2 then return jsonb_build_object('error', 'name'); end if;
    v_school := null; v_letter := null;
  end if;

  loop
    v_code := gen_code(6);
    begin
      insert into classes(code, name, kind, school, school_key, grade, grade_letter)
      values (v_code, v_name, v_kind, v_school, norm_school(v_school),
              case when v_kind = 'class' then p_grade else null end,
              nullif(v_letter, ''))
      returning id into v_id;
      exit;
    exception when unique_violation then
      i := i + 1; if i > 10 then raise; end if;
    end;
  end loop;

  return jsonb_build_object('class_id', v_id, 'code', v_code, 'name', v_name,
                            'kind', v_kind, 'school', v_school, 'grade', p_grade, 'letter', v_letter);
end $$;
grant execute on function public.create_group(text, text, int, text, text) to anon;

-- ---------- 4. koolinimede soovitamine ----------
-- Tagastab kuni 8 juba olemasolevat koolinime, mis algavad sisestatud tekstiga.
-- Ainult koolinimed, mitte ükski isikuandme.
create or replace function public.school_suggest(p_q text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_q text := norm_school(p_q); v_out jsonb;
begin
  if v_q is null or length(v_q) < 2 then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(s order by n desc, s), '[]'::jsonb) into v_out from (
    select min(school) as s, count(*) as n
      from classes
     where kind = 'class' and school_key like v_q || '%'
     group by school_key
     limit 8
  ) q;
  return v_out;
end $$;
grant execute on function public.school_suggest(text) to anon;

-- ---------- 5. edetabelid ----------
-- Lisab kaks uut tabelit: 'siblings' = sama kooli sama astme klassid,
--                         'peers'    = sama aste üle Eesti.
-- Vana 'classes' võti jääb alles, et praegu üleval olev versioon ei katkeks.
create or replace function public.class_board(p_player_id uuid, p_secret text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_p players%rowtype; v_ws timestamptz := week_start();
  v_c classes%rowtype;
  v_players jsonb; v_class jsonb; v_classes jsonb; v_siblings jsonb := '[]'::jsonb; v_peers jsonb := '[]'::jsonb;
begin
  select * into v_p from players where id = p_player_id and secret = p_secret;
  if not found then return jsonb_build_object('error', 'auth'); end if;
  update players set last_seen = now() where id = v_p.id;
  select * into v_c from classes where id = v_p.class_id;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_players from (
    select jsonb_build_object(
      'id', p.id, 'nick', p.nick,
      'greens', p.greens_mul + p.greens_div, 'greens_mul', p.greens_mul, 'greens_div', p.greens_div,
      'best_test', p.best_test, 'total_n', p.total_answers,
      'week_n', coalesce((select sum(s.ok) from sessions s where s.player_id = p.id and s.created_at >= v_ws), 0)
    ) as x
    from players p where p.class_id = v_p.class_id
  ) q;

  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'code', c.code, 'kind', c.kind,
    'school', c.school, 'grade', c.grade, 'letter', c.grade_letter,
    'week_n',      coalesce((select sum(ok) from sessions where class_id = c.id and created_at >= v_ws), 0),
    'total_n',     coalesce((select sum(n) from sessions where class_id = c.id), 0),
    'active_week', (select count(distinct player_id) from sessions where class_id = c.id and created_at >= v_ws),
    'players',     (select count(*) from players where class_id = c.id)
  ) into v_class from classes c where c.id = v_p.class_id;

  -- vana võti, et üleval olev versioon ei katkeks
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_classes from (
    select jsonb_build_object(
      'id', c.id, 'name', c.name, 'week_n', t.week_n, 'active', t.active,
      'per_player', round(t.week_n::numeric / greatest(t.active, 1))
    ) as x
    from classes c
    join (select class_id, sum(ok) as week_n, count(distinct player_id) as active
            from sessions where created_at >= v_ws group by class_id) t on t.class_id = c.id
    order by (t.week_n::numeric / greatest(t.active, 1)) desc
    limit 20
  ) q;

  if v_c.kind = 'class' and v_c.grade is not null then
    -- sama kool, sama aste: 3A vs 3B vs 3C
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_siblings from (
      select jsonb_build_object(
        'id', c.id,
        'name', coalesce(c.grade::text, '') || coalesce(c.grade_letter, ''),
        'week_n', coalesce(t.week_n, 0), 'active', coalesce(t.active, 0),
        'per_player', round(coalesce(t.week_n, 0)::numeric / greatest(coalesce(t.active, 0), 1))
      ) as x
      from classes c
      left join (select class_id, sum(ok) as week_n, count(distinct player_id) as active
                   from sessions where created_at >= v_ws group by class_id) t on t.class_id = c.id
      where c.kind = 'class' and c.school_key = v_c.school_key and c.grade = v_c.grade
      order by coalesce(t.week_n, 0)::numeric / greatest(coalesce(t.active, 0), 1) desc, c.name
      limit 20
    ) q;

    -- sama aste üle Eesti
    select coalesce(jsonb_agg(x), '[]'::jsonb) into v_peers from (
      select jsonb_build_object(
        'id', c.id, 'name', c.name, 'school', c.school,
        'week_n', coalesce(t.week_n, 0), 'active', coalesce(t.active, 0),
        'per_player', round(coalesce(t.week_n, 0)::numeric / greatest(coalesce(t.active, 0), 1))
      ) as x
      from classes c
      left join (select class_id, sum(ok) as week_n, count(distinct player_id) as active
                   from sessions where created_at >= v_ws group by class_id) t on t.class_id = c.id
      where c.kind = 'class' and c.grade = v_c.grade
      order by coalesce(t.week_n, 0)::numeric / greatest(coalesce(t.active, 0), 1) desc, c.name
      limit 20
    ) q;
  end if;

  return jsonb_build_object('me', v_p.id, 'week_start', v_ws, 'class', v_class,
                            'players', v_players, 'classes', v_classes,
                            'siblings', v_siblings, 'peers', v_peers);
end $$;

-- Valmis. Kontroll:
--   select create_group('class','Õismäe Gümnaasium',3,'B',null);  -> peaks tagastama koodi ja nime "Õismäe Gümnaasium 3B"
--   select school_suggest('õis');                                 -> peaks tagastama ["Õismäe Gümnaasium"]
