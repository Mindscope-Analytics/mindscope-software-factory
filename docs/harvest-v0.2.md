# Backlog de cosecha — v0.2

Activos marcados **ADOPTAR** o **GENERALIZAR** en las auditorías HO-001 (Zoni, Aevo) y HO-003
(okr-tracker) que **no** entran en v0.1 (núcleo de gobernanza + preset `expo-supabase`). Cada
línea cita el repo y la ruta de origen. Regla: se copian **archivos** y se generalizan; nunca
historial. De okr-tracker no se copia nada que contenga marca, dominio corporativo, catálogos
reales ni cifras (ver HO-003 §2 y §9b de P-004).

Cada activo tiene un issue con la etiqueta `harvest` (enlaces al final).

## Preset `next-supabase` (origen: zoni-admin, aevo-web)

| # | Activo | Origen | Notas |
|---|---|---|---|
| H-01 | Trío `@supabase/ssr` (client/server/middleware) + `admin.ts` server-only | aevo-project `aevo-web/lib/supabase/{client,server,middleware,admin}.ts`; zoni-admin `lib/supabase/*` | `import 'server-only'` en admin; gate `is_admin` en middleware. |
| H-02 | `middleware.ts` + `lib/rate-limit.ts` (Upstash sliding window, no-op local) | aevo-project `aevo-web/middleware.ts`, `aevo-web/lib/rate-limit.ts` | Regla 6 de CLAUDE.md. |
| H-03 | `next.config.js` con CSP sin unsafe-eval, HSTS preload, nosniff, sin sourcemaps | aevo-project `aevo-web/next.config.js` | Parametrizar `connect-src`. |
| H-04 | `lib/site-url.ts` + `lib/auth-destino.ts` (origen via x-forwarded-*, anti open-redirect) | aevo-project `aevo-web/lib/site-url.ts`, `lib/auth-destino.ts` | Con sus tests vitest. |
| H-05 | `app/auth/confirm/route.ts` (token_hash + PKCE) | aevo-project `aevo-web/app/auth/confirm/route.ts` | Quitar lookup de dominio. |
| H-06 | Puente deep link `/abrir/[destino]` → scheme nativo | aevo-project `aevo-web/app/abrir/[destino]/route.ts`, `lib/abrir-app.ts` | Parametrizar scheme/hosts. |
| H-07 | `lib/sesion-movil.ts` (Bearer → cliente RLS) para API consumida por app nativa | aevo-project `aevo-web/lib/sesion-movil.ts` | Desacoplar de tablas de dominio. |
| H-08 | `lib/auth.ts` (Bearer + cookie) + `lib/auth-utils.ts` | zoni-admin `lib/auth.ts`, `lib/auth-utils.ts` | Guardas para RSC/API. |
| H-09 | Proxy server-side de API de terceros ("la key nunca al cliente") | zoni-admin `lib/google-places.ts`, `app/api/google-places/*` | Generalizar a cualquier proveedor. |
| H-10 | `vitest.config.ts` con stub `server-only` | aevo-project `aevo-web/vitest.config.ts`, `tests/stubs/server-only.ts` | Setup de tests del preset. |
| H-11 | `railway.json` (NIXPACKS, restart policy, `-p ${PORT}`) + runbook Railway | zoni-admin `railway.json`; aevo-project `aevo-docs/ARCHITECTURE.md` §7 | Para presets server; el preset Expo usa Cloudflare Pages. |
| H-12 | shadcn kit + tailwind + `components.json` sin tokens de marca | zoni-admin `components/ui`, `tailwind.config.ts`, `components.json` | Sustituir paleta. |

## Módulo `multi-tenant` (origen: aevo-web)

| # | Activo | Origen | Notas |
|---|---|---|---|
| H-13 | `current_tenant_id()` SECURITY DEFINER + trigger `set_tenant_id` BEFORE INSERT + policies `*_all_tenant` | aevo-project `aevo-web/supabase/migrations/20260703*_s04_base_schema.sql`, `*_tenant_id_auto.sql`, `*_tenant_id_column_default.sql` | NULL con service_role = fila global. Documentado en `aevo-docs/RLS-SCHEMA.md`. |
| H-14 | RPC con PII restringida (`revoke` + `grant` solo a service_role) | aevo-project `s04_base_schema.sql` (`canje_info`) | Patrón, no la función. |
| H-15 | Test cross-tenant → pgTAP | aevo-project `aevo-web/db/verify-rls*.sql` | Convertir a la técnica del módulo `supabase-base`. |

## Módulo `legal-lfpdppp` (origen: zoni-mobile, aevo)

| # | Activo | Origen | Notas |
|---|---|---|---|
| H-16 | Consentimiento versionado + gate de navegación (re-pedir al cambiar versión) | zoni-mobile `supabase/migrations/0012_consent_versioning.sql`, `0016_unify_commercial_consent.sql`, `constants/Legal.ts`, `app/_layout.tsx` (AuthGate); aevo-project `aevo-web/lib/legales.ts`, `lib/estado.ts` | Unificar ambos enfoques. |
| H-17 | Legales versionados con slug (`app/legal/[slug]`) + borradores con placeholders | aevo-project `legal/*.md`, `aevo-web/app/legal/[slug]`; zoni-admin `public/legal/privacy.html`, `terms.html` | "Requieren abogado". |
| H-18 | Edge Function `delete-account` (ARCO-C: JWT caller-only, pasos reportables, anonimizado, Storage) | zoni-mobile `supabase/functions/delete-account/index.ts` | Parametrizar tablas. |
| H-19 | Purga ARCO con `pg_cron` (gracia 30 días) | aevo-project `aevo-web/supabase/migrations/20260712013000_paciente_f1_purga.sql` | Desacoplar de `personas`. |

## Módulo `resend`

| # | Activo | Origen | Notas |
|---|---|---|---|
| H-20 | `enviarCorreo()` REST + `envoltura()` HTML | aevo-project `aevo-web/lib/correo.ts` | Remitente y plantillas por env/config. |

## Otros de Zoni/Aevo

| # | Activo | Origen | Notas |
|---|---|---|---|
| H-21 | Storage `temp/{uid}/` → promoción server-side + policies de bucket | zoni-mobile `supabase/migrations/0014_harden_storage_photos.sql`; zoni-admin `lib/storage.ts` | Módulo `storage-base`. |
| H-22 | `scripts/create-user.mjs` (alta idempotente con service_role) | aevo-project `aevo-web/scripts/create-user.mjs` | Script de operación. |
| H-23 | Aterrizaje de deep links de auth en móvil (`confirmar.tsx`, `restablecer.tsx` con verifyOtp token_hash) | aevo-project `aevo-mobile/app/confirmar.tsx`, `app/restablecer.tsx` | Para el preset Expo cuando use magic link además de OTP. |
| H-24 | `RLS-SCHEMA.md` + `ARCHITECTURE.md` como plantillas de docs (checklist por tabla nueva) | aevo-project `aevo-docs/RLS-SCHEMA.md`, `ARCHITECTURE.md` | Arreglar mojibake. |

## Preset `node-react-vite-railway` (origen: okr-tracker, HO-003 §4)

Solo patrones; se reescribe desde cero sin marca, dominio, catálogos ni cifras.

| # | Activo | Origen (okr-tracker) | Notas |
|---|---|---|---|
| H-25 | Dockerfile multi-stage Node 22 (builder/production, build args `VITE_*`, prune dev) + `.dockerignore` | `Dockerfile`, `.dockerignore` | Quitar `SQLITE_PATH` y excepciones de contenido. |
| H-26 | Esqueleto Express: `asyncRouter`, manejo de errores `/api`, CORS por env, helmet (activar CSP), rate-limit, static client + **zod** | `server/index.js`, `server/lib/asyncRouter.js`, `server/lib/staticClient.js` | Bajar límite JSON de 50 MB. |
| H-27 | Adaptador `pg` con API tipo better-sqlite3 + transacciones | `server/db/database.js` | Autocontenido. |
| H-28 | Verificación de esquema al arrancar + aplicación controlada | `server/db/migrate.js`, `server/db/schema-requirements.js`, `scripts/apply-schema.js` | Alternativa a `supabase db push` con `DATABASE_URL`. |
| H-29 | Auth Bearer contra Supabase JWKS (jose, ES256) + resolución de perfil + `must_change_password` | `server/middleware/auth.js`, `server/lib/supabase.js`, `server/lib/passwords.js`, `routes/admin.js` | Quitar `CORP_DOMAIN` y textos. |
| H-30 | Roles globales + por proyecto + capabilities | `server/middleware/projectScope.js`, `requireCapability.js`, `server/lib/capabilities.js`, `supabase/migrations/0011_user_capabilities.sql` (solo el patrón, no el archivo) | Renombrar capabilities. |
| H-31 | Audit log append-only → tabla Postgres | `server/lib/auditLog.js`, `routes/admin.js` (`/history`) | Hoy JSON en volumen. |
| H-32 | Tests de API con `embedded-postgres` (sin Docker) + helpers `node --test` | `server/test/testdb.js`, `server/test/helpers.js`, `package.json#test` | Solo infra; descartar casos. |
| H-33 | Storage privado con URLs firmadas + multer en memoria | `server/lib/storage.js` | `putObject/signedUrl/removeObject`. |
| H-34 | Notificaciones in-app, recordatorios y digest | `server/lib/notifications.js`, `routes/notifications.js` | Quitar textos de dominio. |
| H-35 | Export/import CSV/Excel/PDF con **exceljs** en lugar de `xlsx` (CVE sin fix) | `client/src/pages/Reports.jsx`, `admin/Data.jsx`, `server/routes/reports.js` | Patrón re-importable. |
| H-36 | Módulos activables por `VITE_MODULES` | `client/vite.config.js`, `client/src/modules/registry.js`, `client/src/App.jsx` | Registro de módulos. |
| H-37 | Ensayos de migración/restore + verificador de release | `server/scripts/migration-rehearsal.js`, `restore-rehearsal.js`, `scripts/verify-release.js`, `scripts/dump-postgres.js` | Parametrizar tablas. |
| H-38 | Runbook de cutover como plantilla (sin contenido) | `docs/cutover-supabase.md` | Solo estructura. |
| H-39 | Módulo `llm-server`: rúbrica en archivo, rate limit, mocks en tests | `server/routes/okrReview.js`, `server/lib/okr-designer`, `server/lib/okr-linter` | Sin contenido del dominio. |
| H-40 | Trigger allowlist de dominio de correo parametrizable (tabla de tenants) | `supabase/migrations/0001_init.sql` (`profiles_enforce_email_domain`, solo el patrón) | Para apps B2B. |
| H-41 | Preset `landing-static` con captura de leads + `wrangler.toml` | okr-tracker-landing `index.html` (estructura) | Reescribir; añadir formulario de leads. |
| H-42 | `.env.example` server/client con comentarios | `server/.env.example`, `client/.env.example` | Sin `JWT_SECRET` ni `SQLITE_PATH`. |

## Issues

Etiqueta `harvest` en el repo de la Factory. Creados el 2026-11-24 (42 issues):

- H-01 → #1 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/1)
- H-02 → #2 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/2)
- H-03 → #3 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/3)
- H-04 → #4 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/4)
- H-05 → #5 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/5)
- H-06 → #6 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/6)
- H-07 → #7 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/7)
- H-08 → #8 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/8)
- H-09 → #9 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/9)
- H-10 → #10 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/10)
- H-11 → #11 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/11)
- H-12 → #12 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/12)
- H-13 → #13 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/13)
- H-14 → #14 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/14)
- H-15 → #15 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/15)
- H-16 → #16 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/16)
- H-17 → #17 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/17)
- H-18 → #18 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/18)
- H-19 → #19 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/19)
- H-20 → #20 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/20)
- H-21 → #21 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/21)
- H-22 → #22 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/22)
- H-23 → #23 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/23)
- H-24 → #24 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/24)
- H-25 → #25 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/25)
- H-26 → #26 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/26)
- H-27 → #27 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/27)
- H-28 → #28 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/28)
- H-29 → #29 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/29)
- H-30 → #30 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/30)
- H-31 → #31 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/31)
- H-32 → #32 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/32)
- H-33 → #33 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/33)
- H-34 → #34 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/34)
- H-35 → #35 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/35)
- H-36 → #36 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/36)
- H-37 → #37 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/37)
- H-38 → #38 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/38)
- H-39 → #39 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/39)
- H-40 → #40 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/40)
- H-41 → #41 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/41)
- H-42 → #42 (https://github.com/Mindscope-Analytics/mindscope-software-factory/issues/42)

