# ADR-0003: Compuertas locales (hooks) para repos privados; protección real solo en públicos

- Estado: Aceptado
- Fecha: 2026-11-24
- Decisores: Arturo Magdiel (owner)

## Contexto

La org `Mindscope-Analytics` está en plan Free. GitHub responde 403 "Upgrade to Pro or make
public" al intentar branch protection o rulesets en repos privados (HO-001 §6, Major 1).
Zoni y Aevo seguirán privados; la Factory y Busy Me serán públicos. Costo objetivo: $0.

## Opciones consideradas

1. Pagar GitHub Team: resuelve protección en privados; rompe el costo $0.
2. Hacer públicos Zoni y Aevo: imposible sin reescribir historial (correos y PII).
3. Compuertas locales: hooks de git + hook de Claude Code que bloquean lo mismo que
   bloquearía la protección (push a main, force push, merge sin PR) en la máquina del dev.

## Decisión

Opción 3. Tres capas que viajan con el template:
- `.claude/settings.json`: `permissions.deny` + hook `PreToolUse` (`guard-bash.sh`).
- `.githooks/`: `pre-commit` (gitleaks, actionlint, semgrep) y `pre-push` (bloquea main y
  secretos), activados por `scripts/setup-hooks.sh` desde `prepare`.
- `global/`: la misma deny-list y CLAUDE.md para `~/.claude`, instalados por
  `scripts/install-global.sh`.
En repos públicos se añade además branch protection real con checks obligatorios.

## Consecuencias

- Positivas: mismo comportamiento en todos los repos; sin costo.
- Negativas: los hooks locales se pueden saltar con `--no-verify`. El hook de Claude Code
  bloquea ese flag en `git push` y `git commit`, pero una persona en la terminal sí puede
  saltárselo. Se acepta el riesgo y se documenta: la protección real existe solo donde el
  plan lo permite.
- Reversa: `git config --unset core.hooksPath` y quitar el hook de settings.

## Verificación

```bash
bash scripts/test-guard.sh         # casos permitidos y bloqueados del hook
git config core.hooksPath          # .githooks
```
