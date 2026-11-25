-- ============================================================================
-- 0002 — profiles + handle_new_user (origen: patrón profiles de proyectos previos,
--        generalizado: sin columnas de dominio)
-- Idempotente.
-- ============================================================================

create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  avatar_url  text,
  -- is_admin solo lo cambia service_role (grants de columna más abajo).
  is_admin    boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is
  'Perfil público mínimo por usuario. Se crea automáticamente al registrarse (handle_new_user).';

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- Grants explícitos (auto_expose_new_tables = false en config.jsonc):
--   anon: nada en la tabla base (usa la vista public_profiles).
--   authenticated: select; update solo de columnas propias no sensibles.
--   service_role: todo (omite RLS).
-- ----------------------------------------------------------------------------
revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (full_name, avatar_url) on table public.profiles to authenticated;
grant all on table public.profiles to service_role;

-- ----------------------------------------------------------------------------
-- RLS: cada quien lee y edita SOLO su fila. No hay policy de insert ni delete
-- para authenticated: el insert lo hace el trigger (SECURITY DEFINER) y el
-- delete cae en cascada desde auth.users (borrado de cuenta vía service_role).
-- ----------------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- ----------------------------------------------------------------------------
-- handle_new_user: crea el perfil al insertar en auth.users.
-- SECURITY DEFINER porque auth.users dispara con el rol de Auth; search_path fijo.
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;
-- Nadie la llama directamente: solo el trigger (corre como owner).

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- public_profiles: proyección mínima para mostrar autores (nombre + avatar)
-- a cualquier usuario, incluso anon, SIN exponer el resto del perfil.
-- Sin security_invoker a propósito: la vista corre como owner. NO añadas
-- columnas sensibles aquí.
-- ----------------------------------------------------------------------------
create or replace view public.public_profiles as
  select id, full_name, avatar_url
  from public.profiles;

grant select on public.public_profiles to anon, authenticated;

comment on view public.public_profiles is
  'Proyección pública mínima de profiles (id, full_name, avatar_url). No añadir columnas sensibles.';
