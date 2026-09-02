#!/usr/bin/env bash
# Installeert de skills uit deze repo als slash commands voor Claude Code / Codex.
#
#   ./install.sh              # globaal: ~/.claude/skills/{supergoal,superaudit}
#   ./install.sh --project    # alleen dit project: ./.claude/skills/{supergoal,superaudit}
#   ./install.sh --only superaudit   # één van de twee
#
# Kopieert (overschrijft) de skill-mappen; verwijdert niets anders. Daarna een
# nieuwe sessie starten, dan staan /supergoal en /superaudit in de lijst.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude/skills"
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) TARGET="$PWD/.claude/skills" ;;
    --only) ONLY="$2"; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "onbekende optie: $1" >&2; exit 2 ;;
  esac
  shift
done

install_supergoal() {
  local dest="$TARGET/supergoal"
  mkdir -p "$dest"
  cp "$HERE/SKILL.md" "$dest/"
  for d in prompts references scripts templates docs; do
    rm -rf "$dest/$d"; cp -r "$HERE/$d" "$dest/$d"
  done
  echo "supergoal  -> $dest"
}

install_superaudit() {
  local dest="$TARGET/superaudit"
  rm -rf "$dest"; mkdir -p "$dest"
  cp -r "$HERE/superaudit/." "$dest/"
  chmod +x "$dest"/scripts/* 2>/dev/null || true
  echo "superaudit -> $dest"
}

case "$ONLY" in
  "") install_supergoal; install_superaudit ;;
  supergoal) install_supergoal ;;
  superaudit) install_superaudit ;;
  *) echo "onbekende skill: $ONLY (supergoal | superaudit)" >&2; exit 2 ;;
esac
echo "klaar; start een nieuwe sessie voor de slash commands."
