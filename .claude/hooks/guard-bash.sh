#!/usr/bin/env bash
# guard-bash.sh — Hook PreToolUse (matcher "Bash") de Claude Code.
# Lee el JSON del evento por stdin, extrae tool_input.command y sale con código 2
# (mensaje en stderr) cuando el comando debe bloquearse. Código 0 = permitido.
#
# Bloquea:
#   1. git push a main/master (explícito, HEAD:main, o implícito si la rama actual es main)
#   2. git push con --force / -f / --force-with-lease
#   3. gh pr merge
#   4. git reset --hard origin*
#   5. cat/less/more/head/tail/bat de archivos .env (no .env.example)
#   6. --no-verify en git commit/push (salta los hooks de .githooks)
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "guard-bash: falta jq; no puedo inspeccionar el comando. Bloqueo por seguridad." >&2
  exit 2
fi

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

deny() {
  echo "guard-bash: BLOQUEADO — $1" >&2
  echo "Comando: $cmd" >&2
  exit 2
}

# Normaliza espacios para que las regex sean simples.
flat="$(printf '%s' "$cmd" | tr '\n' ' ' | tr -s ' ')"

# ── 3. gh pr merge ─────────────────────────────────────────────────────────────
if printf '%s' "$flat" | grep -qE '(^|[;&| ])gh +pr +merge\b'; then
  deny "gh pr merge no está permitido. El merge lo decide una persona desde GitHub."
fi

# ── 4. git reset --hard origin* ────────────────────────────────────────────────
if printf '%s' "$flat" | grep -qE '(^|[;&| ])git +reset +--hard +origin'; then
  deny "git reset --hard origin/* destruye trabajo local. Usa git stash o una rama nueva."
fi

# ── 5. lectura directa de .env ─────────────────────────────────────────────────
# Captura .env, .env.local, .env.production, etc. Permite .env.example.
# Solo mira los argumentos del comando lector: ignora cuerpos de heredoc (<<) y
# escrituras (cat > archivo).
while IFS= read -r seg; do
  seg="${seg%%<<*}"
  printf '%s' "$seg" | grep -qE '(^| )(cat|less|more|head|tail|bat|nl|strings)( |$)' || continue
  printf '%s' "$seg" | grep -qE '(^| )cat +>' && continue
  while IFS= read -r word; do
    base="${word##*/}"
    case "$base" in
      .env.example|.env.*.example) ;;
      .env|.env.*) deny "no se leen archivos .env. Pide que el valor viva en .env.example como placeholder." ;;
    esac
  done < <(printf '%s\n' "$seg" | tr ' ' '\n')
done < <(printf '%s\n' "$flat" | sed -E 's/(&&|\|\||;|\|)/\n/g')

# ── 6. --no-verify ────────────────────────────────────────────────────────────
if printf '%s' "$flat" | grep -qE '(^|[;&| ])git +(commit|push)\b[^;&|]*--no-verify'; then
  deny "--no-verify salta los hooks de pre-commit/pre-push."
fi

# ── 1 y 2. git push ────────────────────────────────────────────────────────────
# Evalúa cada segmento de un comando compuesto por separado.
while IFS= read -r seg; do
  seg="$(printf '%s' "$seg" | sed -E 's/^ +| +$//g')"
  printf '%s' "$seg" | grep -qE '(^|[ ])git +push\b' || continue

  # 2. force
  if printf '%s' "$seg" | grep -qE ' (--force(-with-lease)?(=[^ ]*)?|-f|-[a-zA-Z]*f[a-zA-Z]*)( |$)'; then
    deny "git push --force / -f / --force-with-lease no está permitido."
  fi

  # 1a. destino explícito main/master (incluye refspec HEAD:main y origin/main)
  if printf '%s' "$seg" | grep -qE ' (origin|upstream|[A-Za-z0-9_.-]+) +(\+?[A-Za-z0-9_./-]+:)?(refs/heads/)?(main|master)( |$)' \
     || printf '%s' "$seg" | grep -qE ' (\+?[A-Za-z0-9_./-]+:)(refs/heads/)?(main|master)( |$)' \
     || printf '%s' "$seg" | grep -qE ' (origin|upstream)/(main|master)( |$)'; then
    deny "no se empuja a main/master. Abre una rama y un PR."
  fi

  # 1b. push implícito (sin refspec) estando en main/master
  args="$(printf '%s' "$seg" | sed -E 's/.*git +push//' | sed -E 's/ --?[A-Za-z-]+(=[^ ]*)?//g' | sed -E 's/^ +| +$//g')"
  nwords=$(printf '%s' "$args" | wc -w)
  if [ "$nwords" -le 1 ]; then
    dir="${cwd:-$PWD}"
    branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
    case "$branch" in
      main|master) deny "estás en '$branch'; un push sin refspec empujaría a main/master." ;;
    esac
  fi
done < <(printf '%s\n' "$flat" | sed -E 's/(&&|\|\||;|\|)/\n/g')

exit 0
