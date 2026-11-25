#!/usr/bin/env bash
# test-guard.sh — Casos de prueba de .claude/hooks/guard-bash.sh.
# Uso: bash scripts/test-guard.sh   (exit 0 si todos pasan)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/.claude/hooks/guard-bash.sh"

# Repo temporal en rama main para probar el push implícito.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q -b main
git -C "$TMP" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
TMP_FEAT="$(mktemp -d)"
trap 'rm -rf "$TMP" "$TMP_FEAT"' EXIT
git -C "$TMP_FEAT" init -q -b feat/x
git -C "$TMP_FEAT" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init

pass=0; fail=0
run() { # run <esperado: allow|deny> <cwd> <comando>
  local expect="$1" cwd="$2" cmd="$3"
  local json; json=$(jq -cn --arg c "$cmd" --arg d "$cwd" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')
  local rc; printf '%s' "$json" | bash "$HOOK" >/dev/null 2>&1; rc=$?
  local got; [ $rc -eq 0 ] && got=allow || got=deny
  if [ "$got" = "$expect" ]; then pass=$((pass+1)); printf '  ok    %-5s  %s\n' "$expect" "$cmd"
  else fail=$((fail+1)); printf '  FAIL  esperado=%s obtenido=%s (rc=%s)  %s\n' "$expect" "$got" "$rc" "$cmd"; fi
}

echo "Bloqueados:"
run deny "$TMP_FEAT" "git push origin main"
run deny "$TMP_FEAT" "git push origin master"
run deny "$TMP_FEAT" "git push -u origin main"
run deny "$TMP_FEAT" "git push origin HEAD:main"
run deny "$TMP_FEAT" "git push origin feat/x:refs/heads/main"
run deny "$TMP_FEAT" "git push --force origin feat/x"
run deny "$TMP_FEAT" "git push -f"
run deny "$TMP_FEAT" "git push --force-with-lease origin feat/x"
run deny "$TMP_FEAT" "git push origin feat/x --force"
run deny "$TMP"      "git push"
run deny "$TMP"      "git push origin"
run deny "$TMP_FEAT" "gh pr merge 12 --squash"
run deny "$TMP_FEAT" "gh pr merge --auto"
run deny "$TMP_FEAT" "git reset --hard origin/main"
run deny "$TMP_FEAT" "cat .env"
run deny "$TMP_FEAT" "cat ./.env"
run deny "$TMP_FEAT" "cat apps/web/.env.local"
run deny "$TMP_FEAT" "less .env.production"
run deny "$TMP_FEAT" "head -n 5 .env"
run deny "$TMP_FEAT" "git commit -m x --no-verify"
run deny "$TMP_FEAT" "pnpm test && git push origin main"
run deny "$TMP_FEAT" "git add -A && git commit -m x && git push -f origin feat/x"

echo "Permitidos:"
run allow "$TMP_FEAT" "git push origin feat/x"
run allow "$TMP_FEAT" "git push -u origin feat/x"
run allow "$TMP_FEAT" "git push"
run allow "$TMP_FEAT" "git push origin feat/maintenance"
run allow "$TMP_FEAT" "git push origin fix/master-detail"
run allow "$TMP_FEAT" "git fetch origin main"
run allow "$TMP_FEAT" "git pull origin main"
run allow "$TMP_FEAT" "git checkout main"
run allow "$TMP_FEAT" "git log origin/main..HEAD"
run allow "$TMP_FEAT" "git reset --hard HEAD~1"
run allow "$TMP_FEAT" "cat .env.example"
run allow "$TMP_FEAT" "cat apps/web/.env.example"
run allow "$TMP_FEAT" "gh pr create --fill"
run allow "$TMP_FEAT" "gh pr checks --watch"
run allow "$TMP_FEAT" "gh pr view 12"
run allow "$TMP_FEAT" "pnpm lint && pnpm test"
run allow "$TMP_FEAT" "git commit -m 'feat: x'"
run allow "$TMP_FEAT" "echo 'force push is bad'"
run allow "$TMP_FEAT" "cat > .env.example <<EOF\nFOO=bar # copia .env.example a .env\nEOF"
run allow "$TMP_FEAT" "cat > notes.md <<EOF\nusa .env local\nEOF"
run deny  "$TMP_FEAT" "cat .env <<EOF\nx\nEOF"

echo
echo "pass=$pass fail=$fail"
[ $fail -eq 0 ]
