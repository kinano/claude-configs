#!/usr/bin/env bash
# Acceptance tests for claude-desktop/scripts/codex-shim.sh.
# Builds fake NVM_DIR trees with stub codex scripts and verifies selection.
#
# Run: bash tests/codex-shim.test.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM="$REPO_ROOT/claude-desktop/scripts/codex-shim.sh"

[[ -x "$SHIM" ]] || { echo "FAIL: shim not found or not executable: $SHIM" >&2; exit 1; }

failures=0
pass() { printf "  PASS  %s\n" "$1"; }
fail() { printf "  FAIL  %s\n" "$1" >&2; failures=$((failures + 1)); }

make_stub_codex() {
  local path="$1" tag="$2"
  mkdir -p "$(dirname "$path")"
  # Use <<'EOF' so tag is not expanded during heredoc generation.
  printf '#!/usr/bin/env bash\necho %s\n' "$tag" > "$path"
  chmod +x "$path"
}

# ── AC-1: newest mtime wins, regardless of node-version ordering ──────────
# Put codex under v22.0.0 (high node version) at an OLD mtime, and codex
# under v20.0.0 (lower node version) at a NEW mtime. The shim must pick
# v20.0.0's codex — the recently-installed one — not v22.0.0's.
ac1_dir=$(mktemp -d)
make_stub_codex "$ac1_dir/versions/node/v18.0.0/bin/codex" "from-v18"
make_stub_codex "$ac1_dir/versions/node/v20.0.0/bin/codex" "from-v20"
make_stub_codex "$ac1_dir/versions/node/v22.0.0/bin/codex" "from-v22"
touch -t 202001010000 "$ac1_dir/versions/node/v22.0.0/bin/codex"  # oldest
touch -t 202101010000 "$ac1_dir/versions/node/v18.0.0/bin/codex"
touch -t 202301010000 "$ac1_dir/versions/node/v20.0.0/bin/codex"  # newest
out=$(NVM_DIR="$ac1_dir" bash "$SHIM" 2>/dev/null || true)
if [[ "$out" == "from-v20" ]]; then
  pass "AC-1: shim picked newest-mtime codex (from-v20) over higher-node-version (from-v22)"
else
  fail "AC-1: expected 'from-v20', got: '$out'"
fi
rm -rf "$ac1_dir"

# ── AC-2a: errors when no codex installed under any node version ───────────
ac2a_dir=$(mktemp -d)
mkdir -p "$ac2a_dir/versions/node/v20.0.0/bin"  # node tree but no codex
if NVM_DIR="$ac2a_dir" bash "$SHIM" >/dev/null 2>&1; then
  fail "AC-2a: shim should have exited non-zero when no codex installed"
else
  pass "AC-2a: shim exits non-zero when no codex installed"
fi
rm -rf "$ac2a_dir"

# ── AC-2b: errors when versions/node directory is missing entirely ────────
ac2b_dir=$(mktemp -d)
mkdir -p "$ac2b_dir"  # NVM_DIR exists but versions/node absent
if NVM_DIR="$ac2b_dir" bash "$SHIM" >/dev/null 2>&1; then
  fail "AC-2b: shim should have exited non-zero when versions/node absent"
else
  pass "AC-2b: shim exits non-zero when NVM_DIR/versions/node absent"
fi
rm -rf "$ac2b_dir"

# ── AC-3: single codex install is selected ────────────────────────────────
ac3_dir=$(mktemp -d)
make_stub_codex "$ac3_dir/versions/node/v20.0.0/bin/codex" "the-only-one"
out=$(NVM_DIR="$ac3_dir" bash "$SHIM" 2>/dev/null || true)
if [[ "$out" == "the-only-one" ]]; then
  pass "AC-3: shim picks the single available codex"
else
  fail "AC-3: expected 'the-only-one', got: '$out'"
fi
rm -rf "$ac3_dir"

echo
if (( failures > 0 )); then
  echo "$failures test(s) failed." >&2
  exit 1
fi
echo "All tests passed."
