---
description: Planifica la siguiente fase con el agente planner (solo lectura) y deja el plan en docs/plans/ listo para ejecutar en PRs pequeños.
allowed-tools: Read, Grep, Glob, Write, Bash(git log *), Bash(git status *), Bash(ls *)
---

Objetivo de la fase: $ARGUMENTS

1. Invoca al subagente `planner` con el objetivo, el `CLAUDE.md`, los ADRs en `docs/adr/` y
   `.factory/definition-of-done.md`. Pídele análisis, **una** recomendación y un plan por
   fases desplegables con sus tests.
2. Revisa el plan: cada paso debe caber en un PR; marca los que tocan rutas de
   `.factory/risk-policy.yml`.
3. Escribe el plan en `docs/plans/AAAA-MM-DD-<tema>.md` (crea la carpeta si no existe) con:
   contexto, recomendación, fases numeradas (alcance, archivos, tests, riesgo), preguntas
   abiertas y, si aplica, el borrador del ADR.
4. Muestra el resumen y pregunta si se arranca la fase 1. No escribas código en este comando.
