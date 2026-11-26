# Política de seguridad

## Reportar una vulnerabilidad

Escribe a la cuenta de GitHub del owner (`@arturomagdiel666`) por mensaje privado o abre un
**Security Advisory** privado en este repo (Security → Advisories → Report a vulnerability).
No abras un issue público con detalles explotables.

Compromiso: acuse de recibo en 72 horas; evaluación inicial en 7 días.

## Alcance

- Esta plantilla y los scripts, hooks y workflows que distribuye.
- Los presets y módulos (`presets/`, `modules/`), que otros proyectos copian.

Los proyectos creados desde la plantilla tienen su propia política; este archivo viaja con
ellos como punto de partida y debe adaptarse.

## Controles que la plantilla impone

| Control | Dónde |
|---|---|
| Deny-list de Claude Code (`.env`, force push, merge, borrado de repos, reset remoto) | `.claude/settings.json`, `global/settings.deny.json` |
| Hook `PreToolUse` que bloquea push a main, force push, `gh pr merge`, `git reset --hard origin`, lectura de `.env` | `.claude/hooks/guard-bash.sh` |
| `pre-commit`: gitleaks, actionlint, semgrep | `.githooks/pre-commit` |
| `pre-push`: bloquea `main`/`master` y secretos en los commits a empujar | `.githooks/pre-push` |
| SAST en CI: Semgrep CE (todos los repos) + CodeQL (repos públicos) + gitleaks | `.github/workflows/security.yml` |
| Compuerta de riesgo con aprobación humana | `.github/workflows/risk-gate.yml`, `.factory/risk-policy.yml` |
| Acciones de terceros fijadas por SHA | todos los workflows |
| Dependabot semanal (npm y GitHub Actions) | `.github/dependabot.yml` |
| Branch protection en repos públicos (PR obligatorio, checks `ci`, `risk-gate`, `security`, sin force push, sin bypass para admins) | `scripts/new-project.sh` |

## Reglas para quien contribuye

Las 8 reglas verificables están en `CLAUDE.md`. Las que más importan:
1. Nunca un secreto en el repo ni en archivos de configuración de build.
2. `service_role` solo server-only.
3. Toda tabla con RLS y su test negativo en pgTAP.
4. Toda función `SECURITY DEFINER` con `set search_path` fijo y `revoke all from public`.
