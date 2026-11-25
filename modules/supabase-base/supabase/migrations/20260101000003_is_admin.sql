-- ============================================================================
-- 0003 — is_admin() (origen: patrón anti-recursión RLS de proyectos previos)
-- Una policy sobre profiles no puede consultar profiles directamente (recursión).
-- is_admin() es SECURITY DEFINER (omite RLS de profiles), STABLE, con search_path
-- fijo y grants explícitos: se revoca de public y se concede solo a los roles
-- que evalúan policies.
-- ============================================================================

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = (select auth.uid())),
    false
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated, service_role;

comment on function public.is_admin() is
  'TRUE si el usuario autenticado es admin. SECURITY DEFINER para usarse dentro de policies de profiles sin recursión.';

-- Admin lee todos los perfiles (la escritura sigue siendo solo propia o service_role).
drop policy if exists "profiles: admin reads all" on public.profiles;
create policy "profiles: admin reads all"
  on public.profiles for select
  to authenticated
  using (public.is_admin());
