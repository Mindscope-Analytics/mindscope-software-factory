#!/usr/bin/env bash
# apply-preset.sh — aplica un preset (y opcionalmente un módulo) sobre la raíz del repo actual.
#   bash scripts/apply-preset.sh expo-supabase [--module supabase-base] [--factory <ruta>]
#
# Qué hace:
#   1. Copia los archivos del preset a la raíz (sin README.md ni ci/; esos se integran aparte).
#   2. Fusiona package.json con jq (scripts, deps, devDeps, jest…) sin perder lo del template.
#   3. Fusiona .gitignore y .env.example (líneas nuevas al final, sin duplicar).
#   4. Inserta los pasos de CI del preset (ci/steps.yml) en el marcador <<preset-steps>> de
#      .github/workflows/ci.yml y, si existe ci/jobs.yml, en <<preset-jobs>>.
#   5. Copia el módulo (modules/<m>/supabase → ./supabase) y fija project_id en config.jsonc.
#   6. Guarda el README del preset en docs/PRESET-<preset>.md.
# Es idempotente: volver a correrlo no duplica líneas ni pasos.
set -euo pipefail

usage() { sed -n '2,15p' "$0"; exit 1; }
[ $# -ge 1 ] || usage
PRESET="$1"; shift
MODULE=""
FACTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --module) MODULE="$2"; shift 2 ;;
    --factory) FACTORY="$(cd "$2" && pwd)"; shift 2 ;;
    *) usage ;;
  esac
done
ROOT="$(pwd)"
SRC="$FACTORY/presets/$PRESET"
[ -d "$SRC" ] || { echo "apply-preset: no existe el preset '$PRESET' en $FACTORY/presets" >&2; exit 1; }
command -v jq >/dev/null || { echo "apply-preset: falta jq" >&2; exit 1; }
command -v rsync >/dev/null || { echo "apply-preset: falta rsync" >&2; exit 1; }

echo "→ preset: $PRESET  (factory: $FACTORY → destino: $ROOT)"

# 1. Copia de archivos (excluye lo que se fusiona o se integra aparte) ---------------------
rsync -a \
  --exclude 'README.md' --exclude 'ci/' --exclude 'package.json' \
  --exclude '.gitignore' --exclude '.env.example' \
  "$SRC/" "$ROOT/"

# 2. package.json ------------------------------------------------------------------------
if [ -f "$ROOT/package.json" ]; then
  tmp="$(mktemp)"
  # El template manda en name/private/engines/packageManager; el preset aporta el resto.
  jq -s '
    .[0] as $base | .[1] as $preset |
    ($base * $preset)
    | .name = $base.name
    | .private = true
    | .engines = ($base.engines // $preset.engines)
    | .packageManager = ($base.packageManager // $preset.packageManager)
    | .scripts = (($base.scripts // {}) + ($preset.scripts // {}))
    | .scripts.prepare = ($base.scripts.prepare // "bash scripts/setup-hooks.sh")
    | if ($preset.scripts.test? and $base.scripts["test:guard"]?) then
        .scripts.test = ($preset.scripts.test + " && pnpm run test:guard") else . end
    | .main = ($preset.main // $base.main)
  ' "$ROOT/package.json" "$SRC/package.json" > "$tmp"
  mv "$tmp" "$ROOT/package.json"
  echo "→ package.json fusionado"
else
  cp "$SRC/package.json" "$ROOT/package.json"
fi

# 3. .gitignore y .env.example (append sin duplicar) -------------------------------------
merge_lines() { # merge_lines <src> <dst>
  local src="$1" dst="$2"
  [ -f "$src" ] || return 0
  touch "$dst"
  local added=0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac   # los comentarios no se fusionan
    if ! grep -qxF -- "$line" "$dst"; then
      [ $added -eq 0 ] && printf '\n# ─── preset %s ───\n' "$PRESET" >> "$dst"
      printf '%s\n' "$line" >> "$dst"; added=$((added+1))
    fi
  done < "$src"
  echo "→ $(basename "$dst"): $added línea(s) nueva(s)"
}
merge_lines "$SRC/.gitignore" "$ROOT/.gitignore"
merge_lines "$SRC/.env.example" "$ROOT/.env.example"

# 4. CI: insertar pasos/jobs en los marcadores --------------------------------------------
insert_block() { # insert_block <fragment> <marker> <workflow>
  local frag="$1" marker="$2" wf="$3"
  [ -f "$frag" ] && [ -f "$wf" ] || return 0
  if grep -qF "preset: $PRESET (begin)" "$wf"; then echo "→ ci.yml ya tiene el bloque $marker del preset"; return 0; fi
  grep -qF "$marker" "$wf" || { echo "apply-preset: AVISO no encuentro el marcador $marker en $wf" >&2; return 0; }
  local tmp; tmp="$(mktemp)"
  awk -v marker="$marker" -v frag="$frag" -v name="$PRESET" '
    index($0, marker) {
      ind = $0; sub(/[^ ].*$/, "", ind)
      print ind "# preset: " name " (begin)"
      while ((getline l < frag) > 0) print l
      close(frag)
      print ind "# preset: " name " (end)"
    }
    { print }
  ' "$wf" > "$tmp" && mv "$tmp" "$wf"
  echo "→ ci.yml: insertado $(basename "$frag") en $marker"
}
insert_block "$SRC/ci/steps.yml" "<<preset-steps>>" "$ROOT/.github/workflows/ci.yml"
insert_block "$SRC/ci/jobs.yml"  "<<preset-jobs>>"  "$ROOT/.github/workflows/ci.yml"
if command -v actionlint >/dev/null 2>&1 && [ -f "$ROOT/.github/workflows/ci.yml" ]; then
  actionlint "$ROOT/.github/workflows/ci.yml" && echo "→ actionlint OK"
fi

# 5. Módulo -------------------------------------------------------------------------------
if [ -n "$MODULE" ]; then
  MSRC="$FACTORY/modules/$MODULE"
  [ -d "$MSRC" ] || { echo "apply-preset: no existe el módulo '$MODULE'" >&2; exit 1; }
  rsync -a --exclude 'README.md' "$MSRC/" "$ROOT/"
  if [ -f "$ROOT/supabase/config.jsonc" ]; then
    pid="$(basename "$ROOT" | tr -c 'a-zA-Z0-9_\n' '_')"
    sed -i -E "s/\"project_id\": \"[^\"]*\"/\"project_id\": \"$pid\"/" "$ROOT/supabase/config.jsonc"
    echo "→ módulo $MODULE aplicado (project_id=$pid)"
  fi
  [ -f "$MSRC/README.md" ] && { mkdir -p "$ROOT/docs"; cp "$MSRC/README.md" "$ROOT/docs/MODULE-$MODULE.md"; }
fi

# 6. README del preset → docs/ --------------------------------------------------------------
mkdir -p "$ROOT/docs"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$ROOT/docs/PRESET-$PRESET.md"

cat <<MSG

Listo. Siguientes pasos:
  pnpm install                 # instala deps y activa hooks
  cp .env.example .env         # valores locales (nunca se commitea)
  pnpm lint && pnpm typecheck && pnpm test
  supabase start && supabase test db   # si aplicaste un módulo supabase
Docs: docs/PRESET-$PRESET.md${MODULE:+, docs/MODULE-$MODULE.md}
MSG
