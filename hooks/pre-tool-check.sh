#!/bin/bash
# pre-tool-check.sh - block tool calls that reference .env files
# Dependencies: bash >= 4.0, jq >= 1.5, grep with PCRE (-P)
# Exit codes: 0 = allow, 2 = block (before permission rules)

set -euo pipefail

EXIT_BLOCK=2
EXIT_ALLOW=0

INPUT=$(cat 2>/dev/null) || true

if [[ -z "$INPUT" ]]; then
  exit $EXIT_ALLOW
fi

if ! command -v jq &>/dev/null; then
  echo "[pre-tool-check] ERROR: jq is not installed. Cannot safely parse tool input. Failing closed." >&2
  exit $EXIT_BLOCK
fi

# Extract the relevant field depending on tool type:
# - Bash: .tool_input.command
# - Read/Write/Edit/MultiEdit: .tool_input.file_path or .tool_input.path
TARGET=$(printf '%s' "$INPUT" | jq -r '
  .tool_input.command //
  .tool_input.file_path //
  .tool_input.path //
  empty
' 2>/dev/null) || true

if [[ -z "$TARGET" ]]; then
  exit $EXIT_ALLOW
fi

if printf '%s\n' "$TARGET" | grep -qP '\.env\b'; then
  echo "[pre-tool-check] BLOCKED: tool input references .env file — $(date -u +%Y-%m-%dT%H:%M:%SZ)" >&2
  exit $EXIT_BLOCK
fi

exit $EXIT_ALLOW
