#!/usr/bin/env bash
# install-global.sh — instala la capa global de Claude Code de Mindscope Analytics.
#   · global/CLAUDE.md   → ~/.claude/CLAUDE.md   (backup con timestamp si existe)
#   · global/agents/*    → ~/.claude/agents/
#   · global/settings.deny.json se FUSIONA en ~/.claude/settings.json con jq, sin borrar
#     llaves existentes (model, theme, …) y sin tocar skipDangerousModePermissionPrompt.
#     Muestra el diff y pide confirmación (y/N) antes de escribir.
# Uso: bash scripts/install-global.sh
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"
command -v jq >/dev/null 2>&1 || { echo "install-global: falta jq" >&2; exit 1; }
mkdir -p "$CLAUDE_HOME/agents"

# 1. CLAUDE.md global --------------------------------------------------------------
if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
  cp "$CLAUDE_HOME/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md.bak-$STAMP"
  echo "backup: $CLAUDE_HOME/CLAUDE.md.bak-$STAMP"
fi
cp "$ROOT/global/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"
echo "instalado: $CLAUDE_HOME/CLAUDE.md"

# 2. Agentes -------------------------------------------------------------------------
for f in "$ROOT"/global/agents/*.md; do
  cp "$f" "$CLAUDE_HOME/agents/"
done
echo "instalados: $(ls "$ROOT"/global/agents/*.md | wc -l) agentes en $CLAUDE_HOME/agents/"

# 3. settings.json: fusión aditiva ----------------------------------------------------
SETTINGS="$CLAUDE_HOME/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
MERGED="$(jq -S --slurpfile deny "$ROOT/global/settings.deny.json" '
  . as $cur
  | ($cur.permissions.deny // []) as $have
  | ($deny[0].permissions.deny) as $want
  | $cur
  | .permissions = (($cur.permissions // {}) + {deny: ($have + ($want - $have))})
' "$SETTINGS")"

if [ "$(jq -S . "$SETTINGS")" = "$MERGED" ]; then
  echo "settings.json: ya contiene la deny-list; sin cambios."
  exit 0
fi
echo
echo "Cambios propuestos en $SETTINGS:"
diff -u <(jq -S . "$SETTINGS") <(printf '%s\n' "$MERGED") || true
echo
printf '¿Aplicar? [y/N] '
read -r ans
case "$ans" in
  y|Y)
    cp "$SETTINGS" "$SETTINGS.bak-$STAMP"
    printf '%s\n' "$MERGED" > "$SETTINGS"
    echo "escrito: $SETTINGS (backup en $SETTINGS.bak-$STAMP)" ;;
  *) echo "cancelado; settings.json intacto." ;;
esac
