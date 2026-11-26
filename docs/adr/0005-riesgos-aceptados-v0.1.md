# ADR-0005: Riesgos aceptados en v0.1 (compuerta local, aprobación humana, nombres internos)

- Estado: Aceptado
- Fecha: 2026-11-25
- Decisores: Arturo Magdiel (owner)

## Contexto

La revisión independiente del PR #43 (HO-006: `independent-reviewer` + `security-auditor`,
ambos de solo lectura y con contexto limpio) no encontró fugas de datos ni secretos, pero sí
que varias garantías declaradas en `SECURITY.md`, ADR-0003 y `CLAUDE.md` eran más fuertes
que lo que el código cumplía. El owner decidió (P-007) corregir en la misma rama lo que
protege las compuertas una vez que `claude-review` y `claude-steward` estén vivos (C-2 a
C-8, C-10 a C-13, C-15, C-22) y registrar aquí, de forma explícita, lo que se acepta como
riesgo en v0.1 y se difiere a v0.2.

## Opciones consideradas

1. Fusionar v0.1 tal cual, con todo el riesgo aceptado en la descripción del PR.
2. Reescribir `guard-bash.sh` en deny-por-defecto con tokenización completa antes de fusionar.
3. Corregir lo que endurece las compuertas (hecho en P-007) y aceptar explícitamente tres
   riesgos acotados, con issues abiertos para v0.2.

## Decisión

Opción 3. Se aceptan los tres riesgos siguientes, con sus límites:

1. **`guard-bash.sh` protege contra errores de Claude, no contra un agente adversarial.**
   Es una lista de patrones sobre texto normalizado (sin comillas, tabs, backslashes ni
   subshells), que prefiere sobre-bloquear a sub-bloquear. Cubre heredocs reales, `-C/-c`,
   `--git-dir`, `gh -R` en cualquier posición, alias de git/gh existentes, rutas sensibles por
   basename sin importar el comando, `rm` y `supabase db reset` con flags intermedios. Lo que
   no ve: rutas o ramas construidas con variables o sustituciones (`cat $(…)`), comandos
   detrás de un binario intermedio (`pnpm exec sh -c …`) y alias que no existan aún en el
   momento de la evaluación. La tokenización deny-por-defecto (resto de C-1) queda para v0.2.
   La compuerta local más sólida es `.githooks/pre-push`: lee el `remote_ref` real que git
   entrega por stdin y bloquea cualquier destino `refs/heads/main|master`; el hook de Claude
   bloquea las formas conocidas de desactivarlo (`--no-verify`, `-n`, `core.hooksPath`,
   `GIT_DIR`).
2. **Con un solo miembro en la org, la branch protection exige 0 aprobaciones.** GitHub no
   permite exigir una aprobación que nadie más puede dar. La compuerta real en repos públicos
   es `risk-gate` + la etiqueta `human-approved` que el owner pone desde la web de GitHub, y
   que el hook y los workflows impiden que Claude ponga por sí mismo (`gh pr edit --add-label`,
   `gh api` con PUT/DELETE/PATCH o POST a `labels`, `can_approve_pull_request_reviews=false`
   en org y repo). Cuando entre un segundo miembro: `required_approving_review_count: 1` +
   `require_code_owner_reviews: true` en `new-project.sh` y en la Factory.
3. **Nombres internos en documentación pública.** `docs/harvest-v0.2.md` y ADR-0003 citaban
   repos privados, funciones y un nombre de producto. No son secretos, pero no aportan al
   lector externo; se sustituyen por descripciones genéricas. Las rutas de origen exactas
   viven en los HO-### de la carpeta de handoff (fuera del repo).

## Consecuencias

- Positivas: la plantilla declara exactamente lo que cumple; las compuertas remotas
  (`risk-gate` leyendo la política de la base, steward sin credenciales de push y con el push
  verificado por el workflow, review sin `gh api` mutante) ya no dependen del hook local.
- Negativas: el hook sobre-bloquea algunos comandos legítimos (por ejemplo, mencionar `.env`
  en un `git commit -m`, o leer un CSV de fixtures por shell); la salida es usar `-F archivo`
  o la herramienta Read donde la deny-list lo permita. El steward sin `STEWARD_PUSH_TOKEN`
  empuja con `GITHUB_TOKEN` y los checks no se relanzan solos.
- Reversa: cada punto tiene un issue `security` en v0.2; este ADR se marca "Reemplazado"
  cuando se cierren.

## Verificación

```bash
bash scripts/test-guard.sh                 # casos permitidos y bloqueados del hook
gh api repos/Mindscope-Analytics/mindscope-software-factory/actions/permissions/workflow \
  --jq .can_approve_pull_request_reviews   # false
grep -nE "zoni|aevo|okr-tracker|Busy Me" docs/ README.md CLAUDE.md   # sin resultados
```
