-- Korrutaja · Supabase andmebaas (faas 2)
-- Kleebi see tervikuna Supabase'i SQL Editorisse ja vajuta Run.
-- Turvamudel: tabelitele pole anon-kasutajal otse ligipääsu (RLS sees, poliitikaid pole).
-- Kogu liiklus käib allolevate funktsioonide kaudu, mis kontrollivad mängija salakoodi.

create extension if not exists pgcrypto;

-- ---------- tabelid ----------
create table if not exists public.classes (
  id          uuid primary key default gen_random_uuid(),
  code        text unique not null,
  name        text not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.players (
  id             uuid primary key default gen_random_uuid(),
  class_id       uuid not null references public.classes(id) on delete cascade,
  nick           text not null,
  secret         text not null,
  greens_mul     int  not null default 0,
  greens_div     int  not null default 0,
  best_test      int  not null default 0,
  total_answers  int  not null default 0,
  total_correct  int  not null default 0,
  state          jsonb,
  created_at     timestamptz not null default now(),
  last_seen      timestamptz not null default now(),
  unique (class_id, nick)
);

create table if not exists public.sessions (
  id          bigserial primary key,
  player_id   uuid not null references public.players(id) on delete cascade,
  class_id    uuid not null references public.classes(id) on delete cascade,
  mode        text not null,
  op          text not null,
  n           int  not null,
  ok          int  not null,
  score       int  not null default 0,
  avg_t       real,
  created_at  timestamptz not null default now()
);
create index if not exists sessions_class_time  on public.sessions(class_id, created_at);
create index if not exists sessions_player_time on public.sessions(player_id, created_at);

alter table public.classes  enable row level security;
alter table public.players  enable row level security;
alter table public.sessions enable row level security;
revoke all on public.classes, public.players, public.sessions from anon, authenticated;
revoke all on sequence public.sessions_id_seq from anon, authenticated;

-- ---------- abifunktsioonid (ei ole avalikud) ----------
create or replace function public.gen_code(p_len int) returns text
language plpgsql volatile as $$
declare chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; r text := ''; i int;
begin
  for i in 1..p_len loop
    r := r || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return r;
end $$;
revoke execute on function public.gen_code(int) from public, anon, authenticated;

-- Nädala algus (esmaspäev 00:00 Eesti aja järgi)
create or replace function public.week_start() returns timestamptz
language sql stable as $$
  select date_trunc('week', now() at time zone 'Europe/Tallinn') at time zone 'Europe/Tallinn';
$$;
revoke execute on function public.week_start() from public, anon, authenticated;

-- ---------- avalikud funktsioonid ----------

-- Loo klass. Tagastab 6-märgilise koodi.
create or replace function public.create_class(p_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_name text := left(btrim(coalesce(p_name, '')), 40); v_code text; v_id uuid; i int := 0;
begin
  if length(v_name) < 2 then return jsonb_build_object('error', 'name'); end if;
  loop
    v_code := gen_code(6);
    begin
      insert into classes(code, name) values (v_code, v_name) returning id into v_id;
      exit;
    exception when unique_violation then
      i := i + 1; if i > 10 then raise; end if;
    end;
  end loop;
  return jsonb_build_object('class_id', v_id, 'code', v_code, 'name', v_name);
end $$;

-- Liitu klassiga koodi ja hüüdnimega. Tagastab mängija id + salakoodi (taastekood).
create or replace function public.join_class(p_code text, p_nick text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_class classes%rowtype; v_nick text := left(btrim(coalesce(p_nick, '')), 16); v_id uuid; v_secret text;
begin
  select * into v_class from classes where code = upper(btrim(coalesce(p_code, '')));
  if not found then return jsonb_build_object('error', 'code'); end if;
  if length(v_nick) < 2 then return jsonb_build_object('error', 'nick'); end if;
  if exists (select 1 from players where class_id = v_class.id and lower(nick) = lower(v_nick)) then
    return jsonb_build_object('error', 'taken');
  end if;
  v_secret := gen_code(8);
  insert into players(class_id, nick, secret) values (v_class.id, v_nick, v_secret) returning id into v_id;
  return jsonb_build_object('player_id', v_id, 'secret', v_secret, 'class_id', v_class.id,
                            'class_name', v_class.name, 'code', v_class.code, 'nick', v_nick);
end $$;

-- Taasta konto teises telefonis: klassikood + hüüdnimi + taastekood.
create or replace function public.restore_player(p_code text, p_nick text, p_secret text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select p.id, p.secret, p.class_id, p.nick, p.state, c.name as class_name, c.code
    into r
    from players p join classes c on c.id = p.class_id
   where c.code = upper(btrim(coalesce(p_code, '')))
     and lower(p.nick) = lower(btrim(coalesce(p_nick, '')))
     and p.secret = upper(btrim(coalesce(p_secret, '')));
  if not found then return jsonb_build_object('error', 'auth'); end if;
  update players set last_seen = now() where id = r.id;
  return jsonb_build_object('player_id', r.id, 'secret', r.secret, 'class_id', r.class_id,
                            'class_name', r.class_name, 'code', r.code, 'nick', r.nick, 'state', r.state);
end $$;

-- Raporteeri üks mänguring + uuenda mängija koondnäitajad ja varunda edenemine.
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

  return jsonb_build_object('ok', true);
end $$;

-- Edetabelid: oma klassi mängijad + klassi koond + klassidevaheline tabel. Nädal = õigete vastuste arv.
create or replace function public.class_board(p_player_id uuid, p_secret text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_p players%rowtype; v_ws timestamptz := week_start(); v_players jsonb; v_class jsonb; v_classes jsonb;
begin
  select * into v_p from players where id = p_player_id and secret = p_secret;
  if not found then return jsonb_build_object('error', 'auth'); end if;
  update players set last_seen = now() where id = v_p.id;

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
    'id', c.id, 'name', c.name, 'code', c.code,
    'week_n',      coalesce((select sum(ok) from sessions where class_id = c.id and created_at >= v_ws), 0),
    'total_n',     coalesce((select sum(n) from sessions where class_id = c.id), 0),
    'active_week', (select count(distinct player_id) from sessions where class_id = c.id and created_at >= v_ws),
    'players',     (select count(*) from players where class_id = c.id)
  ) into v_class from classes c where c.id = v_p.class_id;

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

  return jsonb_build_object('me', v_p.id, 'week_start', v_ws, 'class', v_class, 'players', v_players, 'classes', v_classes);
end $$;

grant execute on function public.create_class(text) to anon;
grant execute on function public.join_class(text, text) to anon;
grant execute on function public.restore_player(text, text, text) to anon;
grant execute on function public.report_session(uuid, text, text, text, int, int, int, real, int, int, int, jsonb) to anon;
grant execute on function public.class_board(uuid, text) to anon;

-- Valmis. Kontroll: select create_class('Test 3B');  -> peaks tagastama koodi.
