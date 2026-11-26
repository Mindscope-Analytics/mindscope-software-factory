## Qué cambia

<!-- Una o dos oraciones. Enlaza el issue o el P-### que lo origina. -->

## Riesgo

<!-- ¿Toca rutas de .factory/risk-policy.yml? (migraciones, auth, workflows, eas.json, deps…)
     Si sí: qué puede salir mal, a quién afecta y cómo se revierte. Pide la etiqueta human-approved. -->

- [ ] No toca rutas de riesgo
- [ ] Toca rutas de riesgo (explicado arriba; requiere `human-approved`)

## Cómo probar

```bash
pnpm install
pnpm lint && pnpm typecheck && pnpm test
# si hay cambios en supabase/:
supabase start && supabase test db
```

<!-- Pasos manuales si los hay. -->

## Checklist (Definition of Done)

- [ ] Rama distinta de `main`; PR pequeño y revisable.
- [ ] Tests nuevos o actualizados; ninguna aserción debilitada.
- [ ] Cambios de DB como migración + test RLS negativo en `supabase/tests/`.
- [ ] Sin secretos en repo, `eas.json`, `app.config.*` ni workflows; `service_role` solo server-only.
- [ ] `/security-review` ejecutado; critical/major resueltos.
- [ ] ADR en `docs/adr/` si hubo decisión no trivial.
- [ ] Docs/README actualizados si cambió cómo correr, probar o desplegar.
