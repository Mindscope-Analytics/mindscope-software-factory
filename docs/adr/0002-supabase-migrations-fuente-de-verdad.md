# ADR-0002: Migraciones de Supabase como única fuente de verdad

- Estado: Aceptado
- Fecha: 2026-11-24
- Decisores: Arturo Magdiel (owner)

## Contexto

HO-001 §6: un proyecto aplicaba migraciones a mano en el SQL Editor (sin trazabilidad) y otro
mantenía un `db/schema.sql` de 1,672 líneas que duplicaba las migraciones. Ninguno tenía
tests pgTAP ni plantillas de email de Auth versionadas.

## Decisión

- Todo cambio de esquema es un archivo en `supabase/migrations/`. Está prohibido un
  `schema.sql` editado a mano; si se quiere un snapshot, se genera con `supabase db dump`.
- Los tests de base de datos viven en `supabase/tests/` y corren con `supabase test db`
  (pgTAP). Todo cambio de RLS trae su test negativo.
- Las plantillas de email de Supabase Auth se versionan en `supabase/templates/` y se
  referencian desde la configuración del CLI.
- La configuración del CLI usa el formato nativo de la versión instalada (CLI 3.x genera
  `supabase/config.jsonc`; `config.toml` sigue siendo aceptado por el CLI pero no se genera).

## Consecuencias

- Positivas: `supabase db reset` reconstruye la base desde cero; CI prueba RLS en cada PR.
- Negativas: migraciones aplicadas a mano en proyectos existentes deben reconciliarse con
  `supabase migration repair` antes de adoptar la Factory.

## Verificación

```bash
bash scripts/check-rls.sh     # toda tabla en migraciones tiene RLS
supabase test db              # pgTAP en verde
test ! -e supabase/schema.sql && test ! -e db/schema.sql
```
