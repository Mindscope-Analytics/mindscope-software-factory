---
description: Escribe el handoff HO-### en la carpeta MDs del proyecto (C:\Claude\<Proyecto>\MDs) con resumen, decisiones, evidencia y pendientes.
allowed-tools: Read, Grep, Glob, Write, Bash(ls *), Bash(git log *), Bash(git status *), Bash(gh pr view *), Bash(gh pr list *), Bash(mkdir *)
---

Tema o número de prompt al que responde: $ARGUMENTS

1. Determina la carpeta: `/mnt/c/Claude/<Proyecto>/MDs` donde `<Proyecto>` es el nombre del
   proyecto (pregunta si no es obvio por el repo). Créala si no existe.
2. Lista la carpeta y toma el **siguiente número libre** compartido entre `P-###` y `HO-###`.
   Si respondes a un `P-NNN`, el handoff es `HO-NNN`.
3. Escribe `HO-###-<tema>.md` con, en este orden:
   - Resumen ejecutivo (qué se hizo, semáforo, qué quedó fuera y por qué).
   - Decisiones tomadas fuera del prompt, con justificación.
   - Evidencia: comandos y salidas relevantes, PRs e issues (URLs), árbol de archivos si aplica.
   - Pendientes para la persona, en orden, con comandos exactos.
   - Referencias: rutas de archivos, ADRs.
4. Redacta secretos, tokens, project refs y correos personales como `[REDACTED]`.
5. Muestra la ruta final del archivo.
