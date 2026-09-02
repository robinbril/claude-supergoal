#!/usr/bin/env bash
# Snelle bewijslast voor /superaudit: de checks die een collega lokaal draait voor een
# push, beperkt tot wat de diff raakt. Leest $SUPERAUDIT_ROOT/config.json (zie
# references/projectkaart-template.md); zonder config detecteert hij de stack en zegt
# wat hij aannam. Lint vergelijkt met de basis-versie van elk bestand: alleen NIEUWE
# meldingen maken het rood, bestaande worden geteld. Elke stap die niet kan draaien
# wordt luid OVERGESLAGEN gemeld, zodat "geen fouten" nooit stil "niet gedraaid" is.
#
# Gebruik:
#   fastcheck.sh            # auto-scope
#   fastcheck.sh main..HEAD # expliciete range
#   FULL=1 fastcheck.sh     # hele testsuite i.p.v. de geraakte modules

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
PYFILES="$(jq_py 'print(" ".join(f for f in d["bestanden"] if f.endswith(".py") and "/migrations/" not in f))')"
JSFILES="$(jq_py 'print(" ".join(f for f in d["bestanden"] if f.endswith((".ts",".tsx",".js",".jsx",".vue",".svelte"))))')"
TESTS="$(jq_py 'print(" ".join(d["testmodules"]))')"
VITEST="$(jq_py 'print(" ".join(d["frontend_tests"]))')"
APPS="$(jq_py 'print(" ".join(d["apps"]))')"

PREFIX="$(cfg runner_prefix)"
run() { if [ -n "$PREFIX" ]; then $PREFIX "$@"; else "$@"; fi; }
# Geconfigureerde Django/pytest-commando's alleen draaien als de toolchain er is (lokaal of
# via runner_prefix); anders luid overslaan in plaats van een zekere traceback.
PY_OK=0
if run python -c 'import django' >/dev/null 2>&1 || run python -c 'import pytest' >/dev/null 2>&1 || run python3 -c 'import django' >/dev/null 2>&1 || run python3 -c 'import pytest' >/dev/null 2>&1; then PY_OK=1; fi
needs_py() { case "$1" in *manage.py*|*pytest*|*python*) return 0;; *) return 1;; esac; }
status=0
step() { echo; echo "==> $*"; }
skip() { echo "   OVERGESLAGEN: $*"; }
fill() { local t="$1"; shift; local mods="$1" files="$2" app="$3"; t="${t//\{modules\}/$mods}"; t="${t//\{files\}/$files}"; t="${t//\{app\}/$app}"; printf '%s' "$t"; }

echo "==> config: $([ -f "$CFG" ] && echo "$CFG" || echo 'geen; stack-detectie')  runner: ${PREFIX:-lokaal}"

# ---------- lint: alleen nieuwe meldingen ----------
LINT="$(cfg lint)"
if [ -z "$LINT" ]; then
  if command -v ruff >/dev/null 2>&1 && [ -n "$PYFILES" ]; then LINT="ruff check --output-format concise --quiet"; fi
fi
nieuw_lint=0; bestaand_lint=0
step "lint: nieuwe meldingen t.o.v. $BASE"
if [ -n "$LINT" ] && [ -n "$PYFILES" ]; then
  for f in $PYFILES; do
    nu="$($LINT "$f" 2>/dev/null | sed -E 's/^[^:]+:[0-9]+:[0-9]+:? //' | sort)"
    if git cat-file -e "$BASE:$f" 2>/dev/null; then
      oud="$(git show "$BASE:$f" | $LINT --stdin-filename "$f" - 2>/dev/null | sed -E 's/^[^:]+:[0-9]+:[0-9]+:? //' | sort)"
    else oud=""; fi
    nieuw="$(comm -13 <(printf '%s\n' "$oud") <(printf '%s\n' "$nu") | sed '/^$/d')"
    bestaand_lint=$((bestaand_lint + $(comm -12 <(printf '%s\n' "$oud") <(printf '%s\n' "$nu") | sed '/^$/d' | wc -l)))
    if [ -n "$nieuw" ]; then echo "   NIEUW in $f:"; printf '%s\n' "$nieuw" | sed 's/^/     /'; nieuw_lint=$((nieuw_lint + $(printf '%s\n' "$nieuw" | wc -l))); fi
  done
  echo "   nieuw: $nieuw_lint, bestaand: $bestaand_lint"
  [ "$nieuw_lint" -gt 0 ] && status=1
elif [ -n "$JSFILES" ] && [ -n "$(cfg lint)" ]; then
  $(cfg lint) $JSFILES || status=1
else
  skip "geen linter geconfigureerd of gevonden voor de geraakte bestanden"
fi

# ---------- migratie-check ----------
MIG="$(cfg migration_check)"
step "migratie-check per geraakte app"
if [ -n "$MIG" ] && needs_py "$MIG" && [ "$PY_OK" = 0 ]; then
  skip "migration_check geconfigureerd maar geen Python-toolchain (lokaal of runner_prefix); migraties NIET geverifieerd"
elif [ -n "$MIG" ]; then
  for app in $APPS; do
    cmd="$(fill "$MIG" "" "" "$app")"
    run bash -c "$cmd" || { echo "   ONTBREKENDE OF KAPOTTE MIGRATIE in $app"; status=1; }
  done
elif [ -f manage.py ]; then
  if run python -c 'import django' 2>/dev/null; then
    run python manage.py check || status=1
    echo "   (makemigrations --check niet per app geconfigureerd; zet migration_check in config.json)"
  else skip "geen Django in deze omgeving; migraties NIET geverifieerd"; fi
else
  skip "geen migratie-check geconfigureerd (migration_check in config.json)"
fi

# ---------- typecheck ----------
TC="$(cfg typecheck)"
step "typecheck"
if [ -n "$TC" ]; then bash -c "$TC" || status=1
elif [ -f tsconfig.json ] && [ -d node_modules ]; then npx tsc --noEmit || status=1
else skip "geen typecheck geconfigureerd of mogelijk"; fi

# ---------- tests ----------
TEST="$(cfg test)"; TEST_ALL="$(cfg test_all)"
step "tests voor de geraakte modules"
if [ -n "${TEST:-$TEST_ALL}" ] && needs_py "${TEST:-$TEST_ALL}" && [ "$PY_OK" = 0 ]; then
  skip "test geconfigureerd maar geen Python-toolchain (lokaal of runner_prefix); tests NIET gedraaid: $TESTS"
elif [ "${FULL:-0}" = 1 ] && [ -n "$TEST_ALL" ]; then
  run bash -c "$TEST_ALL" || status=1
elif [ -n "$TEST" ]; then
  if [ -n "$TESTS" ]; then run bash -c "$(fill "$TEST" "$TESTS" "" "")" || status=1
  else echo "   geen testdoelen afgeleid uit de diff; draai FULL=1 voor de hele suite"; fi
elif [ -f manage.py ] && run python -c 'import django' 2>/dev/null; then
  run python manage.py test $TESTS || status=1
elif python3 -c 'import pytest' 2>/dev/null && [ -n "$TESTS" ]; then
  python3 -m pytest -q $TESTS || status=1
elif [ -f go.mod ]; then go test ./... || status=1
elif [ -f Cargo.toml ]; then cargo test || status=1
else
  skip "geen testrunner geconfigureerd of gevonden; tests NIET gedraaid: $TESTS"
fi

# ---------- frontend unit-tests ----------
FT="$(cfg frontend_test)"
step "frontend unit-tests"
if [ -n "$VITEST" ]; then
  if [ -n "$FT" ]; then bash -c "$(fill "$FT" "" "$VITEST" "")" || status=1
  elif [ -d node_modules ]; then npx vitest run $VITEST 2>/dev/null || npx jest $VITEST || status=1
  else skip "node_modules ontbreekt; $VITEST NIET gedraaid"; fi
else
  echo "   geen frontend-tests bij de geraakte bestanden"
fi

echo
echo "==> samenvatting voor het rapport"
echo "   range $RNG; $(jq_py 'print(d["shortstat"] or "-")')"
echo "   groepen: $(jq_py 'print(", ".join(d["apps"]) or "-")'); migraties: $(jq_py 'print(len(d["migraties"]))'); modus: $(jq_py 'print(d["modus"])')"
echo "   lint nieuw/bestaand: $nieuw_lint/$bestaand_lint"
[ "$status" = 0 ] && echo "fastcheck: groen (let op OVERGESLAGEN-stappen hierboven)" || echo "fastcheck: ROOD"
exit $status
