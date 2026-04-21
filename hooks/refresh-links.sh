#!/usr/bin/env bash
# Self-heal: re-establish farty-bobo symlinks if anything (e.g. Claude Desktop)
# has clobbered them. Runs on Claude Code SessionStart. Fail-open by design —
# a broken setup.sh must never block a session from starting.

# Resolve this script's real path (it's typically symlinked from ~/.claude/hooks/
# into the repo's hooks/ dir), then walk one level up to find the repo root.
SELF="${BASH_SOURCE[0]}"
while [[ -L "$SELF" ]]; do
  SELF="$(readlink "$SELF")"
done
REPO_DIR="$(cd "$(dirname "$SELF")/.." 2>/dev/null && pwd)" || exit 0

[[ -x "$REPO_DIR/setup.sh" ]] || exit 0
bash "$REPO_DIR/setup.sh" --links-only --quiet >/dev/null 2>&1 || true
exit 0
