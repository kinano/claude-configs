#!/usr/bin/env bash
# Portable codex shim. Finds the @openai/codex binary under any nvm-managed
# node version and execs it. Symlinked to ~/.local/bin/codex by setup.sh so
# Claude Code's shell can find it regardless of which node version is active.
#
# Selection: the codex binary with the most recent mtime — i.e. the one most
# recently overwritten by `npm install -g @openai/codex`. Picking by node
# version instead would mean upgrades under a non-highest node version are
# silently ignored.
#
# Ties (identical mtime, sub-second installs): winner is find traversal order,
# which is filesystem-dependent and not guaranteed stable. Acceptable because
# same-second installs under two distinct node versions are extremely rare.
set -euo pipefail

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ ! -d "$NVM_DIR/versions/node" ]]; then
  echo "ERROR: nvm node versions not found at $NVM_DIR/versions/node." >&2
  echo "Install nvm and at least one node version first." >&2
  exit 1
fi

# stat flavor differs: BSD (macOS) uses -f %m, GNU (Linux) uses -c %Y.
# Probe both; error out if neither works (e.g. stripped busybox stat).
if stat -f %m / >/dev/null 2>&1; then
  stat_mtime() { stat -f %m "$1"; }
elif stat -c %Y / >/dev/null 2>&1; then
  stat_mtime() { stat -c %Y "$1"; }
else
  echo "ERROR: cannot determine file mtime (stat supports neither -f nor -c)." >&2
  exit 1
fi

CODEX_BIN=""
newest_mtime=-1
# find -L follows symlinks (nvm installs codex as a symlink); -type f excludes
# directories. maxdepth 3 from versions/node: <version>/bin/codex = 3 levels.
while IFS= read -r candidate; do
  [[ -z "$candidate" ]] && continue
  mtime=$(stat_mtime "$candidate" 2>/dev/null) || continue
  if (( mtime > newest_mtime )); then
    newest_mtime=$mtime
    CODEX_BIN=$candidate
  fi
done < <(find -L "$NVM_DIR/versions/node" -maxdepth 3 -type f -name "codex" -path "*/bin/codex" 2>/dev/null)

if [[ -z "$CODEX_BIN" ]]; then
  echo "ERROR: codex not found under any nvm node version." >&2
  echo "Install it with: npm install -g @openai/codex" >&2
  exit 1
fi

exec "$CODEX_BIN" "$@"
