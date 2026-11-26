-- Toda tabla de public tiene RLS; toda función SECURITY DEFINER fija search_path.
begin;
select plan(3);

select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity),
  0,
  'todas las tablas de public tienen row level security'
);

select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  0,
  'ninguna función SECURITY DEFINER sin set search_path'
);

select is(
  (select count(*)::int
     from pg_tables t
    where t.schemaname = 'public'
      and not exists (select 1 from pg_policies pol where pol.schemaname = t.schemaname and pol.tablename = t.tablename)),
  0,
  'ninguna tabla con RLS activa y cero policies (quedaría inaccesible por accidente)'
);

select * from finish();
rollback;
