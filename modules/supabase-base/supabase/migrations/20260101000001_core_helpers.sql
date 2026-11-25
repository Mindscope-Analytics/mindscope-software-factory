-- ============================================================================
-- 0001 — Helpers base (origen: patrón set_updated_at de proyectos previos)
-- Idempotente. Aplica con `supabase db reset` / `supabase db push`.
-- ============================================================================

-- updated_at automático. Úsalo en cada tabla con `updated_at`:
--   create trigger trg_<tabla>_updated_at before update on public.<tabla>
--     for each row execute function public.set_updated_at();
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Trigger BEFORE UPDATE: fija updated_at = now(). Sin SECURITY DEFINER a propósito.';
