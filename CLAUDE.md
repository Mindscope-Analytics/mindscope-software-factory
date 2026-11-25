# CLAUDE.md — Mindscope Analytics Software Factory

Este archivo gobierna a Claude Code en este repo y en todo repo creado desde esta plantilla.
Las reglas globales (idioma, flujo de trabajo, handoff) viven en `global/CLAUDE.md` y se
instalan en `~/.claude/CLAUDE.md` con `scripts/install-global.sh`. Aquí van las reglas del
proyecto y, sobre todo, las **reglas verificables**: cada una trae el comando que la comprueba.

## Qué es este repo

Plantilla pública (template repository) con tres capas:
1. Gobernanza para Claude Code: `.claude/` (permisos, hooks, agentes, comandos) y `global/`.
2. Compuertas: `.githooks/` (pre-commit, pre-push) y `.github/workflows/` (ci, risk-gate,
   security, claude-review, claude-steward).
3. Presets y módulos: `presets/expo-supabase/` y `modules/supabase-base/`, aplicados con
   `scripts/apply-preset.sh`. Un proyecto nuevo nace con `scripts/new-project.sh`.

Políticas en `.factory/`: `risk-policy.yml`, `review-guidelines.md`, `definition-of-done.md`.

## Comandos que debes conocer

```bash
pnpm install            # también activa los hooks (prepare → scripts/setup-hooks.sh)
pnpm lint && pnpm typecheck && pnpm test
pnpm test:guard         # casos del hook guard-bash.sh
pnpm lint:workflows     # actionlint sobre .github/workflows
pnpm check:rls          # toda tabla en migraciones tiene RLS
supabase start && supabase test db   # pgTAP (requiere Docker)
```

Comandos de Claude Code: `/plan-phase`, `/ship-pr`, `/audit`, `/handoff`.
Agentes: `planner`, `db-guardian`, `test-engineer`, `security-auditor`, `independent-reviewer`.

## Reglas verificables (8 puntos)

Generalizadas desde la disciplina probada en los proyectos previos. Cada regla tiene su
verificación; si el comando devuelve algo distinto a lo esperado, la regla está rota.

### 1. Sin source maps en producción web
El build web no publica `.map`. Para Expo web, `expo export -p web` no los genera por defecto;
para Next.js, `productionBrowserSourceMaps: false`.
```bash
# Esperado: 0 archivos
find dist .next -name "*.map" 2>/dev/null | wc -l
```

### 2. RLS desde el día uno
Toda tabla en `public` tiene `enable row level security` y policies explícitas en la misma
migración que la crea. Toda función `SECURITY DEFINER` fija `search_path` y revoca `public`.
```bash
# Esperado: "OK" (compara create table vs enable row level security en supabase/migrations)
bash scripts/check-rls.sh
# Esperado: 0 (SECURITY DEFINER sin set search_path)
grep -rliE "security definer" supabase/migrations | xargs -r grep -LiE "set search_path" | wc -l
```

### 3. Todo por rama y PR
Nadie empuja a `main`. En repos públicos lo impone branch protection; en privados, los hooks.
```bash
# Esperado: .githooks
git config core.hooksPath
# Esperado: bloqueado (exit 2)
echo '{"tool_input":{"command":"git push origin main"}}' | bash .claude/hooks/guard-bash.sh; echo "exit=$?"
```

### 4. Autenticación validada en el servidor
En server components y route handlers se usa `auth.getUser()` (valida contra Supabase), nunca
`getSession()`. El `user_id` siempre sale de la sesión validada, jamás del body.
`service_role` solo en código server-only.
```bash
# Esperado: 0 referencias a service_role fuera de supabase/ y server-only
grep -rn "SERVICE_ROLE" --include=*.ts --include=*.tsx --include=*.js --include=*.json \
  --exclude-dir=node_modules --exclude-dir=supabase --exclude-dir=.github . \
  | grep -v "server-only" | grep -v ".env.example" | grep -v "CLAUDE.md" | wc -l
# Esperado: 0 (ninguna variable pública con la llave de servicio)
grep -rnE "(EXPO_PUBLIC|NEXT_PUBLIC|VITE)_[A-Z_]*SERVICE" --exclude-dir=node_modules . | grep -v CLAUDE.md | wc -l
```

### 5. Secretos fuera del repo y de la config de build
`.env` está ignorado; `.env.example` no lleva valores reales. `eas.json` y `app.config.*` no
contienen valores: las variables van por EAS environment variables.
```bash
# Esperado: 0 (ningún EXPO_PUBLIC_* con valor literal en eas.json)
grep -nE '"EXPO_PUBLIC_[A-Z_]+"\s*:\s*"[^"]+"' eas.json 2>/dev/null | wc -l
# Esperado: solo .env.example
git ls-files | grep -E "(^|/)\.env" | grep -v "\.env\.example$" | wc -l
# Esperado: sin hallazgos
gitleaks git --redact --no-banner .
```

### 6. Rate limiting
Los endpoints públicos y los flujos de Auth tienen límite. En Supabase, `auth.rate_limit` en
la configuración del CLI refleja lo configurado en el dashboard; en servidores Next/Express se
usa un limitador con degradación segura en local.
```bash
# Esperado: la sección existe y tiene valores
grep -nE '"rate_limit"|sign_in_sign_ups|token_verifications' supabase/config.jsonc
```

### 7. Caché sin datos personales
Solo se cachea contenido público (landing, catálogos). Vistas con datos de usuario son
`force-dynamic` o equivalentes. Nunca se cachea una respuesta que dependa de la sesión.
```bash
# Esperado: revisar manualmente cada hit; ninguno debe estar en rutas con sesión
grep -rnE "revalidate\s*=|Cache-Control|stale-while-revalidate" --include=*.ts --include=*.tsx --exclude-dir=node_modules . | grep -v CLAUDE.md
```

### 8. Sin SQL construido con strings
Solo consultas parametrizadas (PostgREST `.eq/.insert/.select`, RPC con argumentos, `pg` con
`$1`). Prohibido interpolar input de usuario en SQL. Toda entrada se valida con Zod antes de
tocar la base.
```bash
# Esperado: 0
grep -rnE 'from\(`|select\(`|rpc\(`|\.query\(`[^`]*\$\{' --include=*.ts --include=*.tsx --include=*.js --exclude-dir=node_modules . | grep -v CLAUDE.md | wc -l
```

## Reglas del proyecto

- Toda feature trae tests; todo cambio de base de datos trae un test RLS en `supabase/tests/`.
- Antes de abrir PR: `pnpm lint`, `pnpm typecheck`, `pnpm test`, `/security-review`.
- Nunca ejecutes `gh pr merge`, `git push --force` ni `supabase db reset --linked`. El hook
  los bloquea; si lo necesitas, es una decisión humana en la terminal, no tuya.
- Si el diff toca rutas de `.factory/risk-policy.yml`, dilo en la descripción del PR con el
  riesgo y la reversa. El check `risk-gate` fallará hasta que el owner etiquete
  `human-approved`.
- Decisiones no triviales → ADR en `docs/adr/` (copia `0000-template.md`).
- Acciones de terceros en workflows siempre fijadas por SHA con comentario de versión.
- No leas ni copies archivos de datos (`*.dump`, `*.db`, `*.sqlite`, `handoff/**/*.json`,
  `audit-log.json`): la deny-list lo impide y además no debes intentarlo.

## Cómo trabajar aquí

1. Analiza y propone una recomendación antes de escribir código (`/plan-phase`).
2. Fases pequeñas y desplegables; cada una termina en PR (`/ship-pr`).
3. Al terminar, escribe el handoff (`/handoff`) en la carpeta `MDs` del proyecto.
