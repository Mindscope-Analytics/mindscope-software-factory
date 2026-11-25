# Mindscope Analytics Software Factory (MASF)

Plantilla pública con la gobernanza, las compuertas y los presets con los que Mindscope
Analytics arranca cada proyecto. Un repo nuevo nace con `scripts/new-project.sh` y hereda:

- **Reglas para Claude Code**: `CLAUDE.md` con 8 reglas verificables por comando, agentes
  especializados (`planner`, `db-guardian`, `test-engineer`, `security-auditor`,
  `independent-reviewer`) y comandos (`/plan-phase`, `/ship-pr`, `/audit`, `/handoff`).
- **Compuertas locales** que funcionan aunque el repo sea privado en plan Free: deny-list y
  hook `PreToolUse` de Claude Code, `pre-commit` (gitleaks + actionlint + semgrep) y
  `pre-push` (bloquea `main` y secretos).
- **CI/CD en GitHub Actions** con acciones fijadas por SHA: `ci` (lint, typecheck, tests,
  pgTAP), `security` (Semgrep CE, gitleaks, CodeQL en públicos), `risk-gate` (rutas de riesgo
  requieren aprobación humana), `claude-review` y `claude-steward`.
- **Presets y módulos**: `expo-supabase` (Expo 54 + expo-router + auth OTP) y `supabase-base`
  (migraciones con RLS, `is_admin()`, tests pgTAP, plantillas de email).

Costo objetivo: **$0** (org en plan Free, Actions gratuitas en repos públicos, Cloudflare
Pages para web). Decisiones en `docs/adr/`.

## Crear un proyecto

```bash
# Requisitos: gh (owner de la org), git, jq, rsync, node 22 (nvm), pnpm (corepack),
#             supabase CLI, gitleaks, actionlint, semgrep, Docker.
bash scripts/new-project.sh busy-me --public --preset expo-supabase --module supabase-base
cd ~/Claude/projects/busy-me && pnpm install
```

Repo **público** → branch protection real en `main` (PR obligatorio; checks `ci`, `risk-gate`,
`security`; sin force push; sin bypass para admins). Repo **privado** → solo compuertas
locales (el plan Free no permite protección).

## Estructura

```
global/            CLAUDE.md global, agents/, settings.deny.json → ~/.claude (install-global.sh)
.claude/           settings.json (deny + hook), agents/, commands/, hooks/guard-bash.sh
.githooks/         pre-commit, pre-push (activados por scripts/setup-hooks.sh)
.github/           workflows/, ISSUE_TEMPLATE/, pull_request_template.md, dependabot.yml, CODEOWNERS
.factory/          risk-policy.yml, review-guidelines.md, definition-of-done.md
docs/              adr/, handoff.md, harvest-v0.2.md
presets/           expo-supabase/
modules/           supabase-base/
scripts/           install-global.sh, setup-hooks.sh, apply-preset.sh, new-project.sh, test-guard.sh, check-rls.sh
```

## Instalar la capa global de Claude Code

```bash
bash scripts/install-global.sh
```

Copia `global/CLAUDE.md` a `~/.claude/CLAUDE.md` (con backup), los agentes a
`~/.claude/agents/` y fusiona la deny-list en `~/.claude/settings.json` con `jq`, mostrando el
diff y pidiendo confirmación. No toca `model`, `theme` ni `skipDangerousModePermissionPrompt`.

## Activar Claude en GitHub (review y steward)

Los workflows `claude-review` y `claude-steward` usan `anthropics/claude-code-action` y
necesitan el secret `CLAUDE_CODE_OAUTH_TOKEN`. Sin él, se omiten con un aviso.

```bash
claude setup-token                       # genera el token OAuth (requiere suscripción)
gh secret set CLAUDE_CODE_OAUTH_TOKEN --org Mindscope-Analytics --visibility all
```

Después, en cualquier repo con Claude Code: `/install-github-app` instala la GitHub App de
Claude en la org (necesaria para que el bot comente y empuje commits).

Controles: solo PRs del mismo repo; comentarios `/review` y `@claude` solo de OWNER/MEMBER;
`@claude stop` detiene al steward; máximo 3 intentos; el steward nunca aprueba, fusiona ni
toca `.github/workflows` o `.factory`.

## Verificar la plantilla

```bash
pnpm install
pnpm test:guard            # 43 casos del hook guard-bash.sh
pnpm lint:workflows        # actionlint
pnpm check:rls             # RLS en todas las tablas del módulo
cd modules/supabase-base && supabase start && supabase test db && supabase stop
```

## Handoff con Claude.ai

Prompts `P-###` y resultados `HO-###` en `C:\Claude\<Proyecto>\MDs` (WSL:
`/mnt/c/Claude/<Proyecto>/MDs`). Protocolo en `docs/handoff.md`.

## Licencia

MIT. Ver `LICENSE`.
