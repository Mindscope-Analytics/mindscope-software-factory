-- RLS de profiles con dos usuarios: B no lee ni escribe datos de A.
-- Técnica: usuarios efímeros en auth.users (el trigger crea profiles), sesión
-- simulada con set_config('request.jwt.claims') + set local role; todo dentro de
-- una transacción que termina en rollback. No deja nada en la base.
begin;
select plan(12);

-- 0. Usuarios efímeros -------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'authenticated', 'authenticated', 'user_a@example.com', '{"full_name":"Usuario A"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'authenticated', 'authenticated', 'user_b@example.com', '{"full_name":"Usuario B"}'::jsonb, now(), now());

select is(
  (select count(*)::int from public.profiles where id in ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')),
  2, 'handle_new_user creó los dos perfiles'
);
select is(
  (select full_name from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Usuario A', 'full_name se tomó de raw_user_meta_data'
);

-- 1. anon: no lee la tabla base -----------------------------------------------
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$ select count(*) from public.profiles $$,
  '42501',
  null,
  'anon no tiene grant sobre profiles'
);
select throws_ok(
  $$ select count(*) from public.public_profiles $$,
  '42501',
  null,
  'anon no lista perfiles: public_profiles no tiene grant a anon (opt-in)'
);
reset role;

-- 2. B autenticado: lee lo suyo, no lo de A -------------------------------------
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.profiles where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1, 'B lee su propio perfil'
);
select is(
  (select count(*)::int from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0, 'B NO lee el perfil de A'
);
select is(
  (select count(*)::int from public.profiles),
  1, 'B solo ve una fila en total'
);
select is(
  (select count(*)::int from public.public_profiles where id in ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')),
  2, 'B autenticado ve la proyección pública (nombre + avatar) de A y de B'
);

-- 3. B intenta escribir sobre A: 0 filas afectadas, dato intacto -----------------
update public.profiles set full_name = 'hackeado' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
reset role;
select is(
  (select full_name from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  'Usuario A', 'el update de B sobre A no afectó ninguna fila'
);

-- 4. B no puede insertar un perfil ajeno ni borrar ------------------------------------
set local role authenticated;
select throws_ok(
  $$ insert into public.profiles (id, full_name) values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'x') $$,
  '42501', null, 'B no puede insertar en profiles'
);
select throws_ok(
  $$ delete from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  '42501', null, 'B no puede borrar perfiles'
);

-- 5. B no puede auto-ascenderse a admin (grant de columna) -------------------------
select throws_ok(
  $$ update public.profiles set is_admin = true where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' $$,
  '42501', null, 'B no puede modificar is_admin'
);
reset role;

select * from finish();
rollback;
