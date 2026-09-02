#!/usr/bin/env bash
# Fast evidence for /superaudit: the checks a colleague runs locally before pushing,
# limited to what the diff touches. Reads $SUPERAUDIT_ROOT/config.json (see
# references/project-map-template.md); without a config it detects the stack and says
# what it assumed. Lint compares against the base version of each file: only NEW
# findings make it red, pre-existing ones are counted. Every step that cannot run is
# loudly reported as SKIPPED, so "no errors" is never a silent "did not run".
#
# Usage:
#   fastcheck.sh            # auto-scope
#   fastcheck.sh main..HEAD # explicit range
#   FULL=1 fastcheck.sh     # whole test suite instead of the touched modules

set -u
cd "$(git rev-parse --show-toplevel)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SUPERAUDIT_ROOT:-.claude/superaudit}"
CFG="$ROOT_DIR/config.json"

SCOPE_JSON="$(python3 "$HERE/scope.py" --json ${1:+"$1"})"
jq_py() { printf '%s' "$SCOPE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); $1"; }
cfg() { [ -f "$CFG" ] && python3 -c "import json,sys; print(json.load(open('$CFG')).get(sys.argv[1], ''))" "$1" || echo ""; }

RNG="$(jq_py 'print(d["range"])')"
BASE="${RNG%%..*}"
PYFILES="$(jq_py 'print(" ".join(f for f in d["files"] if f.endswith(".py") and "/migrations/" not in f))')"
JSFILES="$(jq_py 'print(" ".join(f for f in d["files"] if f.endswith((".ts",".tsx",".js",".jsx",".vue",".svelte"))))')"
TESTS="$(jq_py 'print(" ".join(d["test_targets"]))')"
VITEST="$(jq_py 'print(" ".join(d["frontend_tests"]))')"
APPS="$(jq_py 'print(" ".join(d["apps"]))')"

PREFIX="$(cfg runner_prefix)"
run() { if [ -n "$PREFIX" ]; then $PREFIX "$@"; else "$@"; fi; }
# Only run the configured Django/pytest commands if the toolchain is present (locally or
# via runner_prefix); otherwise skip loudly instead of a certain traceback.
PY_OK=0
if run python -c 'import django' >/dev/null 2>&1 || run python -c 'import pytest' >/dev/null 2>&1 || run python3 -c 'import django' >/dev/null 2>&1 || run python3 -c 'import pytest' >/dev/null 2>&1; then PY_OK=1; fi
needs_py() { case "$1" in *manage.py*|*pytest*|*python*) return 0;; *) return 1;; esac; }
status=0
step() { echo; echo "==> $*"; }
skip() { echo "   SKIPPED: $*"; }
fill() { local t="$1"; shift; local mods="$1" files="$2" app="$3"; t="${t//\{modules\}/$mods}"; t="${t//\{files\}/$files}"; t="${t//\{app\}/$app}"; printf '%s' "$t"; }

echo "==> config: $([ -f "$CFG" ] && echo "$CFG" || echo 'none; stack detection')  runner: ${PREFIX:-local}"

# ---------- lint: new findings only ----------
LINT="$(cfg lint)"
if [ -z "$LINT" ]; then
  if command -v ruff >/dev/null 2>&1 && [ -n "$PYFILES" ]; then LINT="ruff check --output-format concise --quiet"; fi
fi
new_lint=0; existing_lint=0
step "lint: new findings vs $BASE"
if [ -n "$LINT" ] && [ -n "$PYFILES" ]; then
  for f in $PYFILES; do
    now="$($LINT "$f" 2>/dev/null | sed -E 's/^[^:]+:[0-9]+:[0-9]+:? //' | sort)"
    if git cat-file -e "$BASE:$f" 2>/dev/null; then
      old="$(git show "$BASE:$f" | $LINT --stdin-filename "$f" - 2>/dev/null | sed -E 's/^[^:]+:[0-9]+:[0-9]+:? //' | sort)"
    else old=""; fi
    new="$(comm -13 <(printf '%s\n' "$old") <(printf '%s\n' "$now") | sed '/^$/d')"
    existing_lint=$((existing_lint + $(comm -12 <(printf '%s\n' "$old") <(printf '%s\n' "$now") | sed '/^$/d' | wc -l)))
    if [ -n "$new" ]; then echo "   NEW in $f:"; printf '%s\n' "$new" | sed 's/^/     /'; new_lint=$((new_lint + $(printf '%s\n' "$new" | wc -l))); fi
  done
  echo "   new: $new_lint, existing: $existing_lint"
  [ "$new_lint" -gt 0 ] && status=1
elif [ -n "$JSFILES" ] && [ -n "$(cfg lint)" ]; then
  $(cfg lint) $JSFILES || status=1
else
  skip "no linter configured or found for the touched files"
fi

# ---------- migration check ----------
MIG="$(cfg migration_check)"
step "migration check per touched app"
if [ -n "$MIG" ] && needs_py "$MIG" && [ "$PY_OK" = 0 ]; then
  skip "migration_check configured but no Python toolchain (local or runner_prefix); migrations NOT verified"
elif [ -n "$MIG" ]; then
  for app in $APPS; do
    cmd="$(fill "$MIG" "" "" "$app")"
    run bash -c "$cmd" || { echo "   MISSING OR BROKEN MIGRATION in $app"; status=1; }
  done
elif [ -f manage.py ]; then
  if run python -c 'import django' 2>/dev/null; then
    run python manage.py check || status=1
    echo "   (makemigrations --check not configured per app; set migration_check in config.json)"
  else skip "no Django in this environment; migrations NOT verified"; fi
else
  skip "no migration check configured (migration_check in config.json)"
fi

# ---------- typecheck ----------
TC="$(cfg typecheck)"
step "typecheck (only if there are frontend files in scope)"
if [ -z "$JSFILES" ]; then
  echo "   not touched"
elif [ -n "$TC" ]; then
  if [ "$(jq_py 'print("1" if d["preflight"]["node_modules"] else "0")')" = 1 ]; then bash -c "$TC" || status=1
  else skip "typecheck configured but node_modules missing; typecheck NOT run"; fi
elif [ -f tsconfig.json ] && [ -d node_modules ]; then npx tsc --noEmit || status=1
else skip "no typecheck configured or possible"; fi

# ---------- tests ----------
TEST="$(cfg test)"; TEST_ALL="$(cfg test_all)"
step "tests for the touched modules"
if [ -n "${TEST:-$TEST_ALL}" ] && needs_py "${TEST:-$TEST_ALL}" && [ "$PY_OK" = 0 ]; then
  skip "test configured but no Python toolchain (local or runner_prefix); tests NOT run: $TESTS"
elif [ "${FULL:-0}" = 1 ] && [ -n "$TEST_ALL" ]; then
  run bash -c "$TEST_ALL" || status=1
elif [ -n "$TEST" ]; then
  if [ -n "$TESTS" ]; then run bash -c "$(fill "$TEST" "$TESTS" "" "")" || status=1
  else echo "   no test targets derived from the diff; run FULL=1 for the whole suite"; fi
elif [ -f manage.py ] && run python -c 'import django' 2>/dev/null; then
  run python manage.py test $TESTS || status=1
elif python3 -c 'import pytest' 2>/dev/null && [ -n "$TESTS" ]; then
  python3 -m pytest -q $TESTS || status=1
elif [ -f go.mod ]; then go test ./... || status=1
elif [ -f Cargo.toml ]; then cargo test || status=1
else
  skip "no test runner configured or found; tests NOT run: $TESTS"
fi

# ---------- frontend unit tests ----------
FT="$(cfg frontend_test)"
step "frontend unit tests"
if [ -z "$VITEST" ]; then
  echo "   no frontend tests alongside the touched files"
elif [ "$(jq_py 'print("1" if d["preflight"]["node_modules"] else "0")')" = 0 ]; then
  skip "node_modules missing; $VITEST NOT run"
elif [ -n "$FT" ]; then
  bash -c "$(fill "$FT" "" "$VITEST" "")" || status=1
else
  npx vitest run $VITEST 2>/dev/null || npx jest $VITEST || status=1
fi

echo
echo "==> summary for the report"
echo "   range $RNG; $(jq_py 'print(d["shortstat"] or "-")')"
echo "   groups: $(jq_py 'print(", ".join(d["apps"]) or "-")'); migrations: $(jq_py 'print(len(d["migrations"]))'); mode: $(jq_py 'print(d["mode"])')"
echo "   lint new/existing: $new_lint/$existing_lint"
[ "$status" = 0 ] && echo "fastcheck: green (mind the SKIPPED steps above)" || echo "fastcheck: RED"
exit $status
