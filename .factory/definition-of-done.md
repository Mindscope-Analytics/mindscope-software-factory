# Definition of Done

Un cambio está terminado cuando **todo** lo siguiente es cierto. El PR template repite esta
lista como checklist; `/ship-pr` la verifica antes de abrir el PR.

## Código
- [ ] Vive en una rama distinta de `main` y llega por PR.
- [ ] `pnpm lint`, `pnpm typecheck` y `pnpm test` pasan en local.
- [ ] Toda feature nueva trae tests. Un bug fix trae el test que lo reproduce.
- [ ] No hay `console.log` de depuración, código comentado ni TODOs sin issue.

## Base de datos
- [ ] Todo cambio de esquema es una migración en `supabase/migrations/` (nunca SQL a mano).
- [ ] Toda tabla nueva tiene `enable row level security` y policies explícitas.
- [ ] Todo cambio de RLS trae un test pgTAP en `supabase/tests/` que prueba el caso negativo
      (el usuario B no lee ni escribe datos del usuario A).
- [ ] `supabase test db` pasa en local.

## Seguridad
- [ ] Ningún secreto en el repo, en `eas.json`, `app.config.*` ni en workflows.
- [ ] `service_role` solo en código server-only.
- [ ] `/security-review` ejecutado y sus hallazgos critical/major resueltos.
- [ ] Si el diff toca rutas de `.factory/risk-policy.yml`, el PR explica el riesgo y la reversa.

## Documentación
- [ ] Decisiones no triviales tienen un ADR en `docs/adr/`.
- [ ] README o docs actualizados si cambió la forma de correr, probar o desplegar.
- [ ] El PR describe qué cambia, el riesgo y cómo probarlo.
