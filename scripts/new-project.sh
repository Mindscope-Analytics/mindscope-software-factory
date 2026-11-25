#!/usr/bin/env bash
# new-project.sh — crea un repo en Mindscope-Analytics desde la plantilla y lo deja operativo.
#   bash scripts/new-project.sh <nombre> [--public|--private] [--preset expo-supabase] \
#        [--module supabase-base] [--factory-ref <rama>] [--no-protection]
#
#   · gh repo create Mindscope-Analytics/<nombre> --template Mindscope-Analytics/mindscope-software-factory
#   · clona en ~/Claude/projects/<nombre>
#   · --factory-ref <rama>: superpone los archivos de esa rama de la Factory (útil mientras
#     la versión deseada aún no está fusionada en main de la plantilla)
#   · aplica el preset (+ módulo), corre setup-hooks.sh, crea /mnt/c/Claude/<Nombre>/MDs
#   · público → branch protection en main (PR obligatorio, checks ci/risk-gate/security,
#     sin force push, sin bypass para admins) y etiquetas de la Factory
#   · privado → aviso: solo aplican compuertas locales (plan Free)
set -euo pipefail

ORG="${MASF_ORG:-Mindscope-Analytics}"
TEMPLATE="${MASF_TEMPLATE:-$ORG/mindscope-software-factory}"
PROJECTS_DIR="${MASF_PROJECTS_DIR:-$HOME/Claude/projects}"
MDS_BASE="${MASF_MDS_BASE:-/mnt/c/Claude}"

usage() { sed -n '2,14p' "$0"; exit 1; }
[ $# -ge 1 ] || usage
NAME="$1"; shift
VIS="--private"; PRESET=""; MODULE=""; REF=""; PROTECT=1
while [ $# -gt 0 ]; do
  case "$1" in
    --public) VIS="--public"; shift ;;
    --private) VIS="--private"; shift ;;
    --preset) PRESET="$2"; shift 2 ;;
    --module) MODULE="$2"; shift 2 ;;
    --factory-ref) REF="$2"; shift 2 ;;
    --no-protection) PROTECT=0; shift ;;
    *) usage ;;
  esac
done
for t in gh git jq rsync; do command -v "$t" >/dev/null || { echo "new-project: falta $t" >&2; exit 1; }; done

DEST="$PROJECTS_DIR/$NAME"
[ -e "$DEST" ] && { echo "new-project: ya existe $DEST" >&2; exit 1; }

echo "→ creando $ORG/$NAME ($VIS) desde $TEMPLATE"
gh repo create "$ORG/$NAME" "$VIS" --template "$TEMPLATE" --description "Proyecto de Mindscope Analytics creado desde la Factory" >/dev/null
# La generación desde template es asíncrona: espera a que haya contenido.
for i in $(seq 1 30); do
  if gh api "repos/$ORG/$NAME/contents/README.md" >/dev/null 2>&1; then break; fi
  sleep 2
done

echo "→ clonando en $DEST"
gh repo clone "$ORG/$NAME" "$DEST" -- --quiet
cd "$DEST"
DEFAULT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Overlay desde una rama concreta de la Factory ------------------------------------------
if [ -n "$REF" ]; then
  echo "→ superponiendo archivos de $TEMPLATE@$REF"
  tmp="$(mktemp -d)"
  gh api "repos/$TEMPLATE/tarball/$REF" > "$tmp/src.tgz"
  mkdir -p "$tmp/src" && tar -xzf "$tmp/src.tgz" -C "$tmp/src" --strip-components=1
  rsync -a --delete --exclude '.git/' "$tmp/src/" "$DEST/"
  rm -rf "$tmp"
fi

# Preset + módulo -----------------------------------------------------------------------------
if [ -n "$PRESET" ]; then
  args=("$PRESET"); [ -n "$MODULE" ] && args+=(--module "$MODULE")
  bash scripts/apply-preset.sh "${args[@]}"
fi

# Identidad del proyecto en package.json / README --------------------------------------------
if [ -f package.json ]; then
  tmp="$(mktemp)"; jq --arg n "$NAME" '.name = $n | .version = "0.1.0"' package.json > "$tmp" && mv "$tmp" package.json
fi

# Hooks ---------------------------------------------------------------------------------------
bash scripts/setup-hooks.sh

# Carpeta de handoff ---------------------------------------------------------------------------
TITLE="$(printf '%s' "$NAME" | sed -E 's/(^|-)([a-z])/\1\u\2/g' | tr -d '-')"
MDS="$MDS_BASE/$TITLE/MDs"
if mkdir -p "$MDS" 2>/dev/null; then echo "→ handoff: $MDS"; else echo "new-project: AVISO no pude crear $MDS" >&2; fi

# Commit inicial de la configuración ---------------------------------------------------------
git add -A
if ! git diff --cached --quiet; then
  git -c core.hooksPath=/dev/null commit -q -m "chore: bootstrap from mindscope-software-factory${REF:+@$REF}${PRESET:+ (preset $PRESET${MODULE:+ + $MODULE})}"
  git -c core.hooksPath=/dev/null push -q origin "$DEFAULT_BRANCH"
  echo "→ commit inicial empujado a $DEFAULT_BRANCH (único push directo permitido: antes de la protección)"
fi

# Etiquetas de la Factory ----------------------------------------------------------------------
mklabel() { gh label create "$1" --color "$2" --description "$3" -R "$ORG/$NAME" --force >/dev/null 2>&1 || true; }
mklabel human-approved   0E8A16 "Riesgo revisado y aprobado por el owner (risk-gate)"
mklabel steward-stopped  B60205 "Steward detenido por una persona"
mklabel steward-attempt-1 FBCA04 "Intento 1 del steward"
mklabel steward-attempt-2 FBCA04 "Intento 2 del steward"
mklabel steward-attempt-3 FBCA04 "Intento 3 del steward"
mklabel security         D93F0B "Hallazgo de seguridad"
mklabel critical         B60205 "Severidad critical"
mklabel major            D93F0B "Severidad major"
mklabel minor            FBCA04 "Severidad minor"
mklabel harvest          C5DEF5 "Activo a cosechar de un proyecto previo"
mklabel dependencies     0366D6 "Actualización de dependencias"
mklabel github-actions   000000 "Workflows"

# Protección de main --------------------------------------------------------------------------
if [ "$VIS" = "--public" ] && [ "$PROTECT" = 1 ]; then
  echo "→ branch protection en $DEFAULT_BRANCH"
  gh api -X PUT "repos/$ORG/$NAME/branches/$DEFAULT_BRANCH/protection" \
    -H "Accept: application/vnd.github+json" --input - >/dev/null <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ["ci", "risk-gate", "security"] },
  "enforce_admins": true,
  "required_pull_request_reviews": { "dismiss_stale_reviews": true, "require_code_owner_reviews": false, "required_approving_review_count": 0 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false,
  "required_conversation_resolution": true,
  "lock_branch": false
}
JSON
  echo "   PR obligatorio · checks ci/risk-gate/security · sin force push · sin bypass para admins"
else
  cat >&2 <<MSG
┌──────────────────────────────────────────────────────────────────────────────┐
│ AVISO: repo PRIVADO en plan Free → GitHub no permite branch protection.      │
│ Solo aplican las compuertas locales: .claude/settings.json (deny + hook),    │
│ .githooks/pre-commit y pre-push. No las desactives con --no-verify.          │
└──────────────────────────────────────────────────────────────────────────────┘
MSG
fi

cat <<MSG

Listo: https://github.com/$ORG/$NAME
  cd $DEST
  pnpm install
  git checkout -b feat/<primera-fase>
Handoff: $MDS
MSG
