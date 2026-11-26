---
description: Auditoría del repo o de un alcance dado con security-auditor e independent-reviewer; convierte los hallazgos en issues etiquetados.
allowed-tools: Read, Grep, Glob, Bash
---

Alcance: $ARGUMENTS (vacío = repo completo contra `main`).

1. Lanza el subagente `security-auditor` sobre el alcance. Pídele hallazgos con
   archivo:línea, severidad y evidencia, según `.factory/review-guidelines.md`.
2. Lanza el subagente `independent-reviewer` con la spec disponible (issue, P-###, README).
   Pídele la tabla requisito → estado y su veredicto.
3. Consolida: deduplica, ordena por severidad, descarta lo que no se pudo verificar (déjalo en
   una sección "posibles" sin issue).
4. Por cada hallazgo critical/major crea un issue:
   `gh issue create --title "[<severidad>] <resumen>" --label security --label <severidad> --body "<archivo:línea, evidencia, impacto, corrección sugerida>"`.
   Los minor van agrupados en un solo issue "Auditoría <fecha>: hallazgos menores".
   Crea las etiquetas que falten (`gh label create`).
5. Reporta: conteo por severidad, enlaces a los issues y veredicto global. No corrijas nada en
   este comando; cada issue se atiende en su propio PR.
