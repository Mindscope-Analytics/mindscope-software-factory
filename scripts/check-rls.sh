#!/usr/bin/env bash
# check-rls.sh — toda tabla creada en supabase/migrations tiene "enable row level security".
# Uso: bash scripts/check-rls.sh [dir]   (exit 1 si alguna tabla carece de RLS)
set -u
DIR="${1:-supabase/migrations}"
[ -d "$DIR" ] || { echo "check-rls: no existe $DIR (nada que verificar)"; exit 0; }
all="$(cat "$DIR"/*.sql 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')"
tables="$(printf '%s' "$all" | grep -oE 'create table (if not exists )?(public\.)?[a-z_][a-z0-9_]*' | sed -E 's/create table (if not exists )?(public\.)?//' | sort -u)"
missing=0
for t in $tables; do
  if ! printf '%s' "$all" | grep -qE "alter table (public\.)?$t enable row level security"; then
    echo "check-rls: FALTA RLS en public.$t"; missing=$((missing+1))
  fi
done
if [ "$missing" -eq 0 ]; then echo "OK: $(printf '%s\n' $tables | grep -c . ) tabla(s) con RLS"; exit 0; fi
exit 1
