#!/usr/bin/env bash
set -euo pipefail

# Resolves one or more review threads on a PR.
# Usage:
#   resolve-threads.sh <thread-id> [<thread-id>...]
#   resolve-threads.sh --all <pr-number|pr-url> [--repo OWNER/REPO]
#
# With --all, resolves every unresolved thread on the PR.
# Without --all, pass explicit thread IDs (from list-unresolved-threads.sh).

usage() {
  cat >&2 <<EOF
Usage:
  $(basename "$0") <thread-id> [<thread-id>...]
  $(basename "$0") --all <pr-number|pr-url> [--repo OWNER/REPO]

Resolves PR review threads via GitHub GraphQL (resolveReviewThread mutation).
Threads opened by others can only be resolved if you have the right repo permission.
EOF
  exit 2
}

[[ $# -lt 1 ]] && usage

MODE="ids"
PR_ARG=""
REPO_FLAG=""
IDS=()

case "$1" in
  -h|--help) usage ;;
  --all)
    MODE="all"
    shift
    [[ $# -lt 1 ]] && usage
    PR_ARG="$1"; shift
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --repo) REPO_FLAG="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unexpected argument: $1" >&2; usage ;;
      esac
    done
    ;;
  *)
    IDS=("$@")
    ;;
esac

resolve_one() {
  local id="$1"
  local out rc
  out=$(gh api graphql -F id="$id" -f query='
    mutation($id:ID!) {
      resolveReviewThread(input:{threadId:$id}) {
        thread { id isResolved }
      }
    }' 2>&1); rc=$?

  if [[ $rc -eq 0 ]]; then
    local resolved err
    resolved=$(echo "$out" | jq -r '.data.resolveReviewThread.thread.isResolved // empty')
    if [[ "$resolved" == "true" ]]; then
      echo "resolved: $id"
      return 0
    fi
    err=$(echo "$out" | jq -r '(.errors // []) | map(.message) | join("; ") // ""')
    echo "NOT resolved: $id — ${err:-unexpected response: $out}" >&2
    return 1
  fi

  local err
  err=$(echo "$out" | jq -r '(.errors // []) | map(.message) | join("; ") // ""' 2>/dev/null || true)
  echo "FAILED: $id — ${err:-$out}" >&2
  return 1
}

if [[ "$MODE" == "all" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LIST_ARGS=("$PR_ARG" "--json")
  [[ -n "$REPO_FLAG" ]] && LIST_ARGS+=("--repo" "$REPO_FLAG")
  MAPFILE_IDS=$("$SCRIPT_DIR/list-unresolved-threads.sh" "${LIST_ARGS[@]}" | jq -r '.[].id')
  if [[ -z "$MAPFILE_IDS" ]]; then
    echo "No unresolved threads."
    exit 0
  fi
  while IFS= read -r id; do
    IDS+=("$id")
  done <<< "$MAPFILE_IDS"
fi

if [[ ${#IDS[@]} -eq 0 ]]; then
  echo "No thread IDs to resolve." >&2
  exit 1
fi

fail=0
for id in "${IDS[@]}"; do
  resolve_one "$id" || fail=$((fail+1))
done

if [[ $fail -gt 0 ]]; then
  echo "$fail thread(s) failed to resolve." >&2
  exit 1
fi
