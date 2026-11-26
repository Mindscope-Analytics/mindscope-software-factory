#!/usr/bin/env bash
# setup-hooks.sh — activa .githooks como hooksPath del repo. Lo llama "prepare" de package.json.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "setup-hooks: no es un repo git; nada que hacer." >&2
  exit 0
fi
chmod +x "$ROOT"/.githooks/* "$ROOT"/.claude/hooks/*.sh 2>/dev/null || true
git -C "$ROOT" config core.hooksPath .githooks
echo "setup-hooks: core.hooksPath=.githooks (pre-commit: gitleaks+actionlint+semgrep · pre-push: bloquea main + gitleaks)"
for t in gitleaks actionlint semgrep jq; do
  command -v "$t" >/dev/null 2>&1 || echo "setup-hooks: AVISO falta '$t' en PATH; los hooks que lo usan fallarán hasta instalarlo." >&2
done
