# Guía de revisión de código (Factory)

Esta guía la usa `claude-review.yml` y el agente `independent-reviewer`. Cada hallazgo
debe traer **archivo:línea**, **severidad** y una **verificación** (qué se leyó o ejecutó
para confirmarlo). Un hallazgo que no se pudo verificar se reporta como "posible" y nunca
bloquea por sí solo.

## Severidades

### critical — bloquea el merge
- Fuga de datos entre usuarios o tenants: una policy RLS, vista, RPC o endpoint que permite
  leer o escribir filas ajenas.
- Secreto expuesto: API key, `service_role`, token, contraseña o URL con credenciales en el
  código, en `eas.json`, en `app.config.*`, en un workflow o en un `.env` commiteado.
- Bypass de autenticación: ruta o RPC que confía en el body del request en lugar de la sesión
  validada (`auth.getUser()`), o que acepta un `user_id` del cliente.
- Pérdida de datos: migración destructiva sin respaldo ni plan de reversa (`drop table`,
  `drop column`, `truncate`, `delete` sin `where`).
- `service_role` en el cliente: cualquier referencia a la llave de servicio fuera de código
  server-only (Edge Functions, scripts de servidor, `import 'server-only'`).

### major — debe corregirse antes del merge salvo acuerdo explícito
- Tabla nueva sin `enable row level security` o sin policies.
- Función `SECURITY DEFINER` sin `set search_path` fijo o sin `revoke all ... from public`.
- Cambio de comportamiento sin test, o test cuya aserción se debilitó para que pasara.
- Dependencia nueva sin justificación o con vulnerabilidad conocida.
- Workflow con acción de terceros sin fijar por SHA.
- Entrada de usuario que llega a la base sin validación (Zod u equivalente).

### minor — se anota y se decide en el PR
- Nombres o estructura que contradicen `CLAUDE.md`.
- Duplicación evitable, código muerto, logs ruidosos.
- Documentación o ADR faltante para una decisión no trivial.

## Método

1. Lee la descripción del PR y la spec o issue que cita. Si no cita ninguna, pídela.
2. Lee el diff completo. No evalúes solo los archivos "interesantes".
3. Por cada archivo tocado en `supabase/migrations/**`, verifica RLS, grants y tests pgTAP.
4. Ejecuta las verificaciones de `CLAUDE.md` (sección "Reglas verificables") y reporta la salida.
5. Escribe comentarios en línea para cada hallazgo y un resumen al final con el conteo por
   severidad y un veredicto: `APROBABLE`, `CAMBIOS REQUERIDOS` o `BLOQUEADO`.
6. Nunca apruebes ni fusiones el PR. La decisión final es humana.
