#!/usr/bin/env bash
set -euo pipefail

# Lists unresolved review threads on a PR.
# Usage: list-unresolved-threads.sh <pr-number|pr-url> [--repo OWNER/REPO] [--json]
#
# Output (default): one line per unresolved thread:
#   <thread-id>\t<path>:<line>\t<author>\t<first-comment-snippet>
# Output (--json): jq array of { id, isResolved, path, line, author, body }

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <pr-number|pr-url> [--repo OWNER/REPO] [--json]

Lists unresolved review threads on a PR via GitHub GraphQL.
EOF
  exit 2
}

[[ $# -lt 1 ]] && usage

PR_ARG=""
REPO_FLAG=""
JSON=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_FLAG="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage ;;
    *)
      if [[ -z "$PR_ARG" ]]; then PR_ARG="$1"; shift
      else echo "Unexpected argument: $1" >&2; usage
      fi ;;
  esac
done

[[ -z "$PR_ARG" ]] && usage

if [[ "$PR_ARG" =~ ^https?://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)([/?#].*)?$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]%.git}"
  NUM="${BASH_REMATCH[3]}"
elif [[ "$PR_ARG" =~ ^[0-9]+$ ]]; then
  NUM="$PR_ARG"
  if [[ -n "$REPO_FLAG" ]]; then
    OWNER="${REPO_FLAG%/*}"
    REPO="${REPO_FLAG#*/}"
  else
    if ! NWO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
      echo "Not in a git repo with a configured remote. Pass --repo OWNER/REPO or run from inside the PR's repo." >&2
      exit 1
    fi
    OWNER="${NWO%/*}"
    REPO="${NWO#*/}"
  fi
else
  echo "Could not parse PR argument: $PR_ARG" >&2
  usage
fi

RAW=$(gh api graphql -F owner="$OWNER" -F repo="$REPO" -F num="$NUM" -f query='
  query($owner:String!, $repo:String!, $num:Int!) {
    repository(owner:$owner, name:$repo) {
      pullRequest(number:$num) {
        reviewThreads(first:100) {
          pageInfo { hasNextPage }
          nodes {
            id
            isResolved
            path
            line
            comments(first:1) {
              nodes { author { login } body }
            }
          }
        }
      }
    }
  }')

if [[ "$(echo "$RAW" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')" == "true" ]]; then
  echo "WARNING: PR has more than 100 review threads; only the first 100 are shown." >&2
fi

FILTER='.data.repository.pullRequest.reviewThreads.nodes
  | map(select(.isResolved == false))
  | map({
      id,
      isResolved,
      path,
      line,
      author: (.comments.nodes[0].author.login // "unknown"),
      body: (.comments.nodes[0].body // "")
    })'

if [[ "$JSON" -eq 1 ]]; then
  echo "$RAW" | jq "$FILTER"
else
  echo "$RAW" | jq -r "$FILTER"' | .[] | [.id, "\(.path):\(.line // "?")", .author, (.body | gsub("[\r\n]+"; " ") | .[0:100])] | @tsv'
fi
