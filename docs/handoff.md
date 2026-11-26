# Protocolo de handoff entre Claude.ai y Claude Code

Cada proyecto tiene una carpeta compartida en Windows que WSL ve montada:

| Dónde | Ruta |
|---|---|
| Windows | `C:\Claude\<Proyecto>\MDs` |
| WSL | `/mnt/c/Claude/<Proyecto>/MDs` |

## Archivos

- **Prompts** (`P-###-tema.md`): los escribe Claude.ai (o la persona) con la tarea a ejecutar.
- **Handoffs** (`HO-###-tema.md`): los escribe Claude Code al terminar, con resultados.
- La **numeración es única y compartida** entre P y HO: antes de nombrar un archivo se lista
  la carpeta y se toma el siguiente número libre. `P-004` genera `HO-004`.

## Contenido mínimo de un HO

1. Resumen ejecutivo (qué se hizo, qué quedó pendiente, semáforo).
2. Decisiones tomadas fuera del prompt, con justificación.
3. Evidencia: comandos ejecutados y su salida relevante (redactada).
4. Pendientes para la persona, en orden y con comandos exactos.
5. Enlaces: PRs, issues, rutas de archivos.

## Reglas

- Secretos, tokens, project refs y correos personales se redactan siempre (`[REDACTED]`).
- Un HO nunca sustituye al PR: lo complementa. El PR lleva el diff; el HO lleva el contexto.
- El comando `/handoff` de la Factory escribe el HO en la carpeta correcta.
