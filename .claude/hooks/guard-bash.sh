#!/usr/bin/env bash
# guard-bash.sh — Hook PreToolUse (matcher "Bash") de Claude Code.
# Lee el JSON del evento por stdin, extrae tool_input.command y sale con código 2
# (mensaje en stderr) cuando el comando debe bloquearse. Código 0 = permitido.
#
# Alcance (ADR-0005): protege contra ERRORES de Claude, no contra un agente adversarial.
# Es una lista de patrones sobre texto normalizado; prefiere sobre-bloquear a sub-bloquear.
# La compuerta local más sólida es .githooks/pre-push (lee el remote_ref real).
#
# Bloquea:
#   1. git push a main/master: explícito, refspec (HEAD:main, :main, +main), --all/--mirror,
#      comodines, variables, o implícito si la rama actual (cwd o -C) es main/master.
#   2. git push --force / -f / --force-with-lease / +refspec.
#   3. gh: pr merge, repo delete, alias set, pr review --approve, api con PUT/DELETE/PATCH,
#      api POST (o -f/-F) a reviews/merge/labels/protection, y cualquier etiqueta human-approved.
#      Tolera -R/--repo en cualquier posición.
#   4. git reset --hard contra refs remotas (origin/*, upstream/*, @{u}, FETCH_HEAD).
#   5. Archivos sensibles por nombre, sin importar el comando (cat, grep, sed, awk, source,
#      xxd, node -e, python3 -c, sqlite3…): .env y .env.* (no .env.example), *.sqlite*, *.db,
#      *.db-wal, *.dump, *.sql.gz, *-backup-*.json, *.csv, *.xlsx, *.pem, *.key, *.p12, *.jks,
#      signing_keys.json, audit-log.json, handoff/**/*.json. Normaliza comillas y globs.
#      Excepción: el destino de cp/mv (permite `cp .env.example .env`).
#   6. Saltar hooks: --no-verify, git commit -n (y combinaciones), core.hooksPath en git -c o
#      git config, --git-dir global y GIT_DIR=.
#   7. rm sobre /, ~, $HOME, .git, ., .., * ; supabase db reset --linked/--db-url (con flags
#      intermedios); supabase projects delete.
#   8. alias de shell/git y xargs que envuelvan git push o gh (no se pueden inspeccionar).
# Los cuerpos de heredoc reales (<<EOF … EOF) se ignoran: son datos, no comandos. No cuentan
# como heredoc: << entre comillas, tras #, <<< (here-string) ni << dentro de $(( )).
set -uf   # -f: sin expansión de globs al iterar tokens

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

# ── 0. Quitar cuerpos de heredoc reales ───────────────────────────────────────
AWK_HEREDOC=$(cat <<'AWK'
function scan(line,    i, c, n, sq, dq, arith, rest, tag, dash) {
  n = length(line); sq = 0; dq = 0; arith = 0
  for (i = 1; i <= n; i++) {
    c = substr(line, i, 1)
    if (sq) { if (c == "'") sq = 0; continue }
    if (c == "\\") { i++; continue }
    if (dq) { if (c == "\"") dq = 0; continue }
    if (c == "'") { sq = 1; continue }
    if (c == "\"") { dq = 1; continue }
    if (c == "#" && (i == 1 || substr(line, i - 1, 1) ~ /[ \t;&|(]/)) return ""
    if (substr(line, i, 3) == "$((") { arith++; i += 2; continue }
    if (arith > 0 && substr(line, i, 2) == "))") { arith--; i++; continue }
    if (arith > 0) continue
    if (substr(line, i, 3) == "<<<") { i += 2; continue }
    if (substr(line, i, 2) == "<<") {
      rest = substr(line, i + 2)
      if (match(rest, /^-?[ \t]*["']?[A-Za-z_][A-Za-z0-9_]*["']?/)) {
        tag = substr(rest, RSTART, RLENGTH)
        dash = (substr(tag, 1, 1) == "-") ? "-" : "+"
        sub(/^-?[ \t]*/, "", tag); gsub(/["']/, "", tag)
        return dash tag
      }
      i++
    }
  }
  return ""
}
skip { l = $0; if (dash) sub(/^\t+/, "", l); sub(/[ \t]+$/, "", l); if (l == tag) skip = 0; next }
{ r = scan($0); print $0
  if (r != "") { dash = (substr(r, 1, 1) == "-"); tag = substr(r, 2); skip = 1 } }
AWK
)
nohd="$(printf '%s\n' "$cmd" | awk "$AWK_HEREDOC")"

# ── 0b. Normalizar: continuaciones, tabs, backslashes, comillas, subshells ───
norm="$(printf '%s\n' "$nohd" \
  | sed -e ':a' -e '/\\$/{N;s/\\\n/ /;ba}' \
  | tr '\t' ' ' \
  | sed -E 's/\\//g' \
  | sed -E "s/[\"']//g" \
  | sed -E 's/\$\(|`|[()<>#]+/ /g' \
  | sed -E 's/(^| )[{}]( |$)/ /g' \
  | sed -E 's/ +/ /g')"
# Segmentos: un comando simple por línea.
segs="$(printf '%s\n' "$norm" | sed -E 's/(&&|\|\||;|\||&)/\n/g' | sed -E 's/^ +| +$//g' | grep -v '^$' || true)"

B='(^|[^A-Za-z0-9_./-])'                       # frontera de palabra para el nombre del comando
GITPRE="${B}git +(-[^ ]+ +([^ -][^ ]* +)?)*"    # git + opciones globales (-C x, -c k=v, --no-pager…)

# ── 5. Archivos sensibles por nombre, sin importar el comando ─────────────────
is_sensitive_base() { # <basename en minúsculas> → 0 si es sensible
  case "$1" in
    *.example|*.example.*|*.sample|*.sample.*|*.template|*.template.*) return 1 ;;
    .env|.env.*) return 0 ;;
    *.sqlite|*.sqlite3|*.sqlite-*|*.db|*.db-wal|*.db-shm|*.dump|*.sql.gz) return 0 ;;
    *-backup-*.json|full-backup.json|audit-log.json|signing_keys.json) return 0 ;;
    *.csv|*.xlsx|*.xls|*.pem|*.key|*.p12|*.jks|*.keystore|*.p8|*.mobileprovision) return 0 ;;
  esac
  return 1
}
check_path() { # <ruta o patrón>
  local tok="$1" low base stripped m
  low="$(printf '%s' "$tok" | tr '[:upper:]' '[:lower:]')"
  base="${low##*/}"
  [ -z "$base" ] && return 0
  if is_sensitive_base "$base"; then deny "no se leen ni copian archivos sensibles ($tok). Si necesitas un valor, pide que viva en .env.example como placeholder."; fi
  case "$low" in
    handoff/*.json|*/handoff/*.json) deny "no se leen archivos de handoff/**/*.json ($tok)." ;;
  esac
  case "$tok" in
    *[\*\?\[]*)
      stripped="$(printf '%s' "$base" | tr -d '*?[]')"
      case "$stripped" in
        .e*|.) deny "glob que puede expandir a .env ($tok)." ;;
      esac
      if is_sensitive_base "$stripped"; then deny "glob sobre archivos sensibles ($tok)."; fi
      while IFS= read -r m; do
        [ -n "$m" ] && check_path "$m"
      done < <(cd "${cwd:-$PWD}" 2>/dev/null && set +f; compgen -G "$tok" 2>/dev/null | head -50 || true)
      ;;
  esac
}
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  first="${seg%% *}"
  toks="$(printf '%s' "$seg" | tr -c 'A-Za-z0-9_./~*?$\\[\\]{}-' '\n' | grep -v '^$' || true)"
  case "$first" in cp|mv) toks="$(printf '%s\n' "$toks" | sed '$d')" ;; esac
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    case "$t" in -*) continue ;; esac
    check_path "$t"
  done <<< "$toks"
done <<< "$segs"

# ── 6. Saltar hooks ───────────────────────────────────────────────────────────
if printf '%s' "$norm" | grep -qiE "${B}GIT_DIR=|${B}GIT_WORK_TREE=|${GITPRE}--git-dir"; then
  deny "GIT_DIR / --git-dir cambian el repo (y sus hooks) a espaldas de la compuerta."
fi
while IFS= read -r seg; do
  printf '%s' "$seg" | grep -qE "${B}git +" || continue
  if printf '%s' "$seg" | grep -qE -- '--no-verify'; then deny "--no-verify salta los hooks de pre-commit/pre-push."; fi
  if printf '%s' "$seg" | grep -qiE 'hookspath'; then deny "core.hooksPath no se toca: desactivaría pre-commit/pre-push."; fi
  if printf '%s' "$seg" | grep -qE "${GITPRE}commit( |$)"; then
    args="$(printf '%s' "$seg" | sed -E "s/^.*${GITPRE}commit( |$)//")"
    for t in $args; do
      case "$t" in --) break ;; -n*|-[!-]*n*) deny "git commit -n equivale a --no-verify." ;; esac
    done
  fi
  if printf '%s' "$seg" | grep -qE "${GITPRE}config( |$).*alias\."; then deny "no se definen alias de git (ocultarían un push a main)."; fi
  sub="$(printf '%s' "$seg" | sed -E "s/^.*${GITPRE}//" | awk '{print $1}')"
  if printf '%s' "$sub" | grep -qE '^[a-z][a-z0-9-]*$' && [ -n "$(git -C "${cwd:-$PWD}" config --get "alias.$sub" 2>/dev/null)" ]; then
    deny "'git $sub' es un alias de git; escribe el comando completo."
  fi
done <<< "$segs"

# ── 8. alias / xargs ──────────────────────────────────────────────────────────
if printf '%s' "$norm" | grep -qE "${B}alias +[A-Za-z0-9_]+=(.* )?(git|gh)( |$)"; then
  deny "no se definen alias de shell que envuelvan git o gh."
fi
if printf '%s' "$norm" | grep -qE "${B}xargs( |$)" && printf '%s' "$norm" | grep -qE "${B}git +push|${B}gh "; then
  deny "xargs con git push / gh no se puede inspeccionar; escribe el comando completo."
fi

# ── 3. gh ─────────────────────────────────────────────────────────────────────
while IFS= read -r seg; do
  printf '%s' "$seg" | grep -qE "${B}gh +" || continue
  gha="$(printf '%s' "$seg" | sed -E "s/^.*${B}gh +//" \
        | sed -E 's/(^| )(-R|--repo|--hostname) +[^ ]+//g; s/(^| )(--repo|--hostname)=[^ ]+//g; s/ +/ /g; s/^ //')"
  ghfirst="${gha%% *}"
  if printf '%s' "$ghfirst" | grep -qE '^[a-z][a-z0-9-]*$' && gh alias list 2>/dev/null | grep -qE "^${ghfirst}:"; then
    deny "'gh $ghfirst' es un alias de gh; escribe el comando completo."
  fi
  if printf '%s' "$gha" | grep -qE '(^| )pr +merge( |$)'; then deny "gh pr merge no está permitido. El merge lo decide una persona desde GitHub."; fi
  if printf '%s' "$gha" | grep -qE '(^| )repo +(delete|archive)( |$)'; then deny "gh repo delete/archive es una decisión humana."; fi
  if printf '%s' "$gha" | grep -qE '(^| )alias +(set|import)( |$)'; then deny "gh alias set ocultaría comandos prohibidos."; fi
  if printf '%s' "$gha" | grep -qE '(^| )pr +review( |$)' && printf '%s' "$gha" | grep -qE '(^| )(--approve|-a|--request-changes|-r)( |$)'; then
    deny "gh pr review --approve / --request-changes: la revisión formal la hace una persona."
  fi
  if printf '%s' "$gha" | grep -qE 'human-approved' && ! printf '%s' "$gha" | grep -qE '^(pr|issue) +(view|list|checks|status)( |$)'; then
    deny "la etiqueta human-approved solo la pone una persona desde GitHub."
  fi
  if printf '%s' "$gha" | grep -qE '(^| )api( |$)'; then
    method="$(printf '%s' "$gha" | grep -oE '(^| )(-X|--method)[ =][A-Za-z]+' | head -1 | sed -E 's/.*[ =]//' | tr '[:lower:]' '[:upper:]')"
    fields=0; printf '%s' "$gha" | grep -qE '(^| )(-f|-F|--field|--raw-field|--input)( |=)' && fields=1
    case "$method" in
      PUT|DELETE|PATCH) deny "gh api con $method modifica el repo (merge, protección, contenidos). No está permitido." ;;
    esac
    if [ "$method" = "POST" ] || { [ -z "$method" ] && [ "$fields" = 1 ]; }; then
      if printf '%s' "$gha" | grep -qE '/(reviews|merge|merges|labels|protection|rulesets|collaborators|dispatches|forks)( |$|/|\?)'; then
        deny "gh api POST a reviews/merge/labels/protection no está permitido."
      fi
    fi
  fi
done <<< "$segs"

# ── 4. git reset --hard contra refs remotas ───────────────────────────────────
if printf '%s' "$norm" | grep -qE "${GITPRE}reset( +[^ ]+)* +--hard(=| +)(origin|upstream|@\{|FETCH_HEAD|[^ ]+/(main|master)( |$))"; then
  deny "git reset --hard contra una ref remota destruye trabajo local. Usa git stash o una rama nueva."
fi

# ── 7. rm / supabase ──────────────────────────────────────────────────────────
while IFS= read -r seg; do
  if printf '%s' "$seg" | grep -qE "${B}rm +"; then
    args="$(printf '%s' "$seg" | sed -E "s/^.*${B}rm +//")"
    for t in $args; do
      case "$t" in
        --no-preserve-root) deny "rm --no-preserve-root." ;;
        -*) continue ;;
        /|//|/\*|'~'|'~/'|'~/*'|\$HOME|\$HOME/|\$HOME/\*|\${HOME}|\${HOME}/|\${HOME}/\*|.git|.git/|*/.git|*/.git/|.|..|\*|./\*|../\*|"$HOME"|"$HOME/"|"$HOME/*")
          deny "rm sobre $t está prohibido." ;;
      esac
    done
  fi
  if printf '%s' "$seg" | grep -qE "${B}supabase +(-[^ ]+ +([^ -][^ ]* +)?)*db +reset( |$)" \
     && printf '%s' "$seg" | grep -qE -- '--linked|--db-url'; then
    deny "supabase db reset --linked / --db-url borra una base remota. Es una decisión humana."
  fi
  if printf '%s' "$seg" | grep -qE "${B}supabase +(-[^ ]+ +([^ -][^ ]* +)?)*projects +delete( |$)"; then
    deny "supabase projects delete es una decisión humana."
  fi
done <<< "$segs"

# ── 1 y 2. git push ───────────────────────────────────────────────────────────
current_branch() { # <dir>
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || echo ''
}
curdir="${cwd:-$PWD}"
while IFS= read -r seg; do
  if printf '%s' "$seg" | grep -qE '^cd( |$)'; then      # cd previo en el mismo comando
    target="$(printf '%s' "$seg" | awk '{print $2}')"
    case "$target" in ""|"~") curdir="$HOME" ;; "~/"*) curdir="$HOME/${target#\~/}" ;; /*) curdir="$target" ;; -) ;; *) curdir="$curdir/$target" ;; esac
    continue
  fi
  printf '%s' "$seg" | grep -qE "${GITPRE}push( |$)" || continue
  args="$(printf '%s' "$seg" | sed -E "s/^.*${GITPRE}push( |$)//")"
  if printf '%s' "$args" | grep -q '\$'; then deny "no se usan variables ni sustituciones en git push; escribe la rama literal."; fi
  dir="$curdir"
  cdir="$(printf '%s' "$seg" | grep -oE "${B}git +-C +[^ ]+" | head -1 | awk '{print $NF}')"
  if [ -n "$cdir" ]; then case "$cdir" in /*) dir="$cdir" ;; *) dir="$dir/$cdir" ;; esac; fi
  remote=""; refspecs=(); skipnext=0; repo_opt=0; noopts=0
  for t in $args; do
    if [ "$skipnext" = 1 ]; then skipnext=0; continue; fi
    if [ "$noopts" = 0 ]; then
      case "$t" in
        --) noopts=1; continue ;;
        --follow-tags) continue ;;
        --f*|-f*|-[!-]*f*) deny "git push --force / -f / --force-with-lease no está permitido." ;;
        --mirror|--mirr*|--all|--al|--branches|--branch*) deny "git push --all/--mirror empujaría main. Empuja solo tu rama." ;;
        --no-verify) deny "--no-verify salta los hooks de pre-push." ;;
        --repo=*) repo_opt=1; continue ;;
        --repo) repo_opt=1; skipnext=1; continue ;;
        -o|--push-option|--receive-pack|--exec|--recurse-submodules) skipnext=1; continue ;;
        -*) continue ;;
      esac
    fi
    if [ -z "$remote" ] && [ "$repo_opt" = 0 ]; then remote="$t"; else refspecs+=("$t"); fi
  done
  need_branch=0
  [ ${#refspecs[@]} -eq 0 ] && need_branch=1
  for rs in "${refspecs[@]}"; do
    case "$rs" in
      *\**) deny "refspec con comodín ($rs) puede empujar main." ;;
      +*) deny "refspec con + ($rs) es un force push." ;;
    esac
    if [ "${rs#*:}" != "$rs" ]; then src="${rs%%:*}"; dst="${rs#*:}"; else src="$rs"; dst="$rs"; fi
    dst="${dst#refs/heads/}"; dst="${dst#refs/remotes/}"
    case "$dst" in
      main|master|*/main|*/master) deny "no se empuja a main/master ($rs). Abre una rama y un PR." ;;
      ""|HEAD|HEAD~*|HEAD^*|@|@\{*) need_branch=1 ;;
    esac
    case "$src" in HEAD|HEAD~*|HEAD^*|@|@\{*) need_branch=1 ;; esac
  done
  if [ "$need_branch" = 1 ]; then
    branch="$(current_branch "$dir")"
    case "$branch" in
      main|master) deny "estás en '$branch'; este push empujaría a main/master." ;;
    esac
  fi
done <<< "$segs"

exit 0
