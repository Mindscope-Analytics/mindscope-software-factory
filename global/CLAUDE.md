# CLAUDE.md global — Mindscope Analytics

Reglas que aplican en todos los proyectos de Mindscope Analytics, se instalan en
`~/.claude/CLAUDE.md` con `scripts/install-global.sh` de la Factory. Las reglas del repo
(`CLAUDE.md` en la raíz) las complementan y nunca las relajan.

## Idioma y estilo
- Prosa en español; identificadores (variables, funciones, tablas, ramas, commits) en inglés.
- Commits con Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.
- Respuestas breves: primero el resultado, luego la evidencia.

## Forma de trabajar
- Antes de codificar: análisis corto y **una** recomendación. Si hay dudas que cambian el
  diseño, pregunta; si no, decide y deja la suposición escrita.
- Fases pequeñas y desplegables. Cada fase termina en un PR que se puede revisar en minutos.
- Todo cambio llega por rama + PR. Nunca empujes a `main`. Nunca hagas merge: eso lo decide
  una persona.
- Toda feature trae tests. Todo cambio de base de datos trae un test RLS.
- Antes de abrir el PR: lint + typecheck + tests + `/security-review`.
- Decisiones no triviales (stack, esquema, auth, deploy) van a un ADR en `docs/adr/`.

## Seguridad
- Nunca secretos en el repo, ni en `eas.json`, `app.config.*`, `app.json` o workflows. Las
  variables de build van por EAS environment variables; las de servidor, por el proveedor.
- `service_role` de Supabase solo en código server-only (Edge Functions, scripts de servidor,
  módulos con `import 'server-only'`). Jamás en apps móviles o web.
- No leas `.env` ni archivos de datos (dumps, `.db`, `.sqlite`, `handoff/**/*.json`,
  `audit-log.json`). Si necesitas un valor, pide que lo pongan en `.env.example` como
  placeholder.
- Toda tabla con RLS. Toda función `SECURITY DEFINER` con `set search_path` y `revoke` de
  `public`.

## Protocolo de handoff con Claude.ai
Cada proyecto tiene una carpeta compartida: `C:\Claude\<Proyecto>\MDs` en Windows, que en
WSL es `/mnt/c/Claude/<Proyecto>/MDs`.
- Claude.ai escribe los prompts como `P-###-tema.md`.
- Claude Code responde con `HO-###-tema.md` (handoff): resumen, decisiones, evidencia,
  pendientes con comandos exactos.
- La numeración es **única y compartida** entre P y HO. Antes de nombrar, lista la carpeta y
  toma el siguiente número libre. Si te piden "ejecuta P-007", el resultado es `HO-007`.
- Redacta siempre secretos, project refs y correos personales.

## Lo que no haces
- `git push --force`, `gh pr merge`, `gh repo delete`, `supabase db reset --linked`,
  `rm -rf` sobre rutas fuera del proyecto. El hook te lo impedirá; no insistas.
- Debilitar un test para que pase. Si un test falla, el código está mal o la spec cambió:
  dilo.
- Instalar con `sudo`. Propón el comando y deja que la persona lo ejecute.
