# Módulo `supabase-base`

Base de datos mínima y segura para cualquier proyecto Supabase de Mindscope Analytics. Se
aplica con `scripts/apply-preset.sh <preset> --module supabase-base`, que copia `supabase/` a
la raíz del proyecto.

## Qué incluye

| Ruta | Qué es |
|---|---|
| `supabase/config.jsonc` | Configuración del CLI 3.x: `auto_expose_new_tables: false` (grants explícitos), confirmación de correo activa, OTP de 6 dígitos y 10 min, rate limits de Auth, plantillas versionadas. |
| `migrations/20260101000001_core_helpers.sql` | `set_updated_at()` para triggers `BEFORE UPDATE`. |
| `migrations/20260101000002_profiles.sql` | `profiles` (RLS: cada quien lo suyo; `is_admin` solo editable por `service_role` vía grants de columna), `handle_new_user()` SECURITY DEFINER con `search_path` fijo, vista `public_profiles`. |
| `migrations/20260101000003_is_admin.sql` | `is_admin()` SECURITY DEFINER anti-recursión con `revoke`/`grant` explícitos; policy de lectura total para admins. |
| `tests/*.test.sql` | pgTAP: RLS en todas las tablas y `search_path` en todo SECURITY DEFINER; prueba de dos usuarios (B no lee ni escribe datos de A); `is_admin()`. |
| `templates/*.html` | Correos de Auth en español, neutros: confirmación, magic link, recuperación. Muestran `{{ .Token }}` y `{{ .ConfirmationURL }}`. |
| `seed.sql` | Vacío a propósito; aquí van catálogos del dominio. |

## Cómo correrlo

```bash
supabase start          # requiere Docker
supabase db reset       # aplica migraciones + seed
supabase test db        # pgTAP
supabase stop
```

## Cómo añadir una tabla (checklist)

1. Nueva migración `supabase/migrations/<timestamp>_<nombre>.sql` (`supabase migration new <nombre>`).
2. `create table` con `owner_id uuid not null default auth.uid() references auth.users(id)`.
3. `revoke all ... from anon, authenticated;` y `grant` solo lo necesario.
4. `alter table ... enable row level security;` + policies `select/insert/update/delete`
   con `(select auth.uid()) = owner_id`.
5. Trigger `set_updated_at` si hay `updated_at`.
6. Test pgTAP en `supabase/tests/` con dos usuarios: B no lee ni escribe lo de A.
7. `bash scripts/check-rls.sh && supabase test db`.

## Técnica de los tests

Cada test corre dentro de `begin; … rollback;`. Se insertan usuarios efímeros en `auth.users`
(el trigger crea su perfil), se simula la sesión con
`set_config('request.jwt.claims', '{"sub":"<uuid>","role":"authenticated"}', true)` y
`set local role authenticated`, se verifica con `is()`/`throws_ok()`, y se vuelve con
`reset role`. Nada queda en la base.
