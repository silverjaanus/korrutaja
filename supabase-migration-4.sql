-- Korrutaja · migratsioon 4: rekord serverist, mitte kliendilt + turvalisem koodigeneraator
-- Kleebi tervikuna Supabase'i SQL Editorisse ja vajuta Run.
-- Ohutu: ei kustuta ega muuda ühtki rida, ainult asendab kaks funktsiooni.

-- ---------- 1. best_test (Rekord) arvutatakse ainult päriselt salvestatud võistlustest ----------
-- Varem uuendas iga raport best_test'i kliendi saadetud numbriga (ka harjutusring),
-- nii sai telefoni kella keerates või curl'iga rekordi pumbata. Nüüd võtab server
-- väärtuse alati oma sessions-tabelist ja kliendi p_best_test'i ei usalda.
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

  -- Võistelda saab üks kord Eesti kalendripäevas. Harjutusring salvestub ikka.
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
    -- rekord = parim päriselt salvestatud võistlus; p_best_test'i (kliendilt) ei usaldata
    best_test     = coalesce((select max(ok) from sessions
                                where player_id = v_p.id and mode = 'test'), best_test),
    total_answers = total_answers + p_n,
    total_correct = total_correct + p_ok,
    state         = coalesce(p_state, state),
    last_seen     = now()
  where id = v_p.id;

  return jsonb_build_object('ok', true, 'competed_today', competed_today(v_p.id));
end $$;

-- ---------- 2. koodigeneraator krüptoturvalistest baitidest ----------
-- 32-tähelise tähestiku puhul jagab 256 baiti täpselt (256/32=8), nii et jääk %32
-- on kallutamata. pgcrypto on juba laetud (supabase.sql).
create or replace function public.gen_code(p_len int) returns text
language plpgsql volatile as $$
declare chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; r text := ''; i int; b bytea;
begin
  b := gen_random_bytes(p_len);
  for i in 1..p_len loop
    r := r || substr(chars, 1 + (get_byte(b, i - 1) % 32), 1);
  end loop;
  return r;
end $$;
revoke execute on function public.gen_code(int) from public, anon, authenticated;

-- Valmis. Pärast seda migratsiooni:
--   * Rekord (best_test) tuleb ainult päriselt kirja läinud võistlustest.
--   * Uued klassi- ja taastekoodid tulevad krüptoturvalisest juhuslikkusest.
