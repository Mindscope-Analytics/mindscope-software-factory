-- is_admin(): el admin lee perfiles ajenos sin recursión; un no-admin no.
begin;
select plan(5);

insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'authenticated', 'authenticated', 'user_a@example.com', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
   'authenticated', 'authenticated', 'admin@example.com', now(), now());
update public.profiles set is_admin = true where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

-- Propiedades de la función
select is(
  (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_admin'),
  true, 'is_admin es SECURITY DEFINER'
);
select ok(
  (select exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace,
                  unnest(p.proconfig) c
                  where n.nspname = 'public' and p.proname = 'is_admin' and c like 'search_path=%')),
  'is_admin fija search_path'
);

-- Admin lee todo
select set_config('request.jwt.claims', '{"sub":"dddddddd-dddd-dddd-dddd-dddddddddddd","role":"authenticated"}', true);
set local role authenticated;
select is(public.is_admin(), true, 'is_admin() = true para el admin');
select is(
  (select count(*)::int from public.profiles where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1, 'el admin lee el perfil de A'
);
reset role;

-- No-admin
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}', true);
set local role authenticated;
select is(public.is_admin(), false, 'is_admin() = false para un usuario normal');
reset role;

select * from finish();
rollback;
