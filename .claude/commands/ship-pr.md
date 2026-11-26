---
description: Verifica calidad y seguridad, commitea con Conventional Commits, empuja la rama, abre el PR con la plantilla y vigila los checks (hasta 3 intentos de corrección). Nunca hace merge.
allowed-tools: Bash(git *), Bash(gh *), Bash(pnpm *), Bash(supabase *), Read, Edit, Write, Grep, Glob
---

Lleva el trabajo actual hasta un PR listo para revisión humana. Sigue estos pasos en orden y
detente en el primero que falle, explicando por qué.

1. **Rama**: `git rev-parse --abbrev-ref HEAD`. Si es `main` o `master`, crea una rama
   `feat/<tema>` o `fix/<tema>` antes de seguir. Nunca trabajes sobre main.
2. **Calidad**: `pnpm lint`, `pnpm typecheck`, `pnpm test`. Si hay `supabase/` con cambios,
   también `supabase test db` (requiere Docker; si no está, dilo y continúa).
3. **Seguridad**: ejecuta `/security-review` sobre el diff. Hallazgos critical/major se
   corrigen antes de seguir; minor se anotan en el PR.
4. **Commit**: `git add` de lo que corresponde (nunca `.env*` salvo `.env.example`), mensaje
   Conventional Commits (`feat:`, `fix:`, `chore:`, …) con cuerpo breve que explique el porqué.
5. **Push**: `git push -u origin <rama>`. Jamás `--force`.
6. **PR**: `gh pr create --fill --template .github/pull_request_template.md`, y luego edita el
   cuerpo para completar: qué cambia, riesgo (menciona si toca rutas de
   `.factory/risk-policy.yml`), cómo probar, checklist DoD.
7. **Checks**: `gh pr checks --watch`. Si falla `ci` o `security`, lee el log
   (`gh run view <id> --log-failed`), corrige, commitea y empuja de nuevo. Máximo **3
   intentos**; al tercero, reporta el estado y detente. Si falla `risk-gate`, no intentes
   evadirlo: explica en el PR el riesgo y pide la etiqueta `human-approved`.
8. **Reporta** la URL del PR y el estado final de cada check.

Prohibido: `gh pr merge`, `gh pr review --approve`, `git push --force`, debilitar tests.
$ARGUMENTS
