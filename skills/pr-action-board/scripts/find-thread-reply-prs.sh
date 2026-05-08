#!/usr/bin/env bash
# find-thread-reply-prs.sh — Find open PRs (not authored by me) where I've commented and
#   someone replied to my comment/thread but I have NOT responded yet.
#
# Strategy:
#   1. Search for open PRs where I've commented but am not the author.
#   2. For each PR, call check-pr-threads.sh to determine whether there are
#      unresponded replies in any review thread or the PR-level comment chain.
#   3. Return only PRs with at least one unresponded reply.
#
# Usage:
#   ./find-thread-reply-prs.sh <gh_login> <org_scope_or_empty>
#
#   gh_login           — the authenticated user's login (e.g. "kinanf")
#   org_scope_or_empty — restrict to one GitHub org (e.g. "embarkvet"), or "" for all orgs
#
# Output: JSON array of:
#   { url, number, owner, repo, title, author, updated_at, reason,
#     review_thread_replies, issue_comment_replies }
set -euo pipefail

GH_LOGIN="${1:?Usage: find-thread-reply-prs.sh <gh_login> <org_scope_or_empty>}"
ORG_SCOPE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SEARCH_ARGS=("--state" "open" "--json" "number,title,url,author,repository,updatedAt" "--limit" "50")
[[ -n "$ORG_SCOPE" ]] && SEARCH_ARGS+=("--owner" "$ORG_SCOPE")

# Find PRs I've commented on but didn't author
COMMENTED_PRS=$(gh search prs \
  "commenter:${GH_LOGIN} -author:${GH_LOGIN}" \
  "${SEARCH_ARGS[@]}" 2>/dev/null || echo "[]")

PR_COUNT=$(echo "$COMMENTED_PRS" | jq 'length')
if [[ "$PR_COUNT" -eq 0 ]]; then
  echo "[]"
  exit 0
fi

RESULTS="[]"

# Iterate over JSON objects directly to avoid TSV corruption from tab/newline in PR titles.
while IFS= read -r pr_json; do
  [[ -z "$pr_json" ]] && continue

  number=$(echo "$pr_json" | jq -r '.number')
  url=$(echo "$pr_json"    | jq -r '.url')
  author=$(echo "$pr_json" | jq -r '.author.login // ""')
  title=$(echo "$pr_json"  | jq -r '.title')
  updated_at=$(echo "$pr_json" | jq -r '.updatedAt')

  owner=$(echo "$url" | awk -F'/' '{print $4}')
  repo=$(echo  "$url" | awk -F'/' '{print $5}')

  THREAD_DATA=$("$SCRIPT_DIR/check-pr-threads.sh" \
    "$GH_LOGIN" "$owner" "$repo" "$number" 2>/dev/null \
    || echo '{"has_unresponded_replies":false,"review_thread_replies":[],"issue_comment_replies":[]}')

  HAS_REPLIES=$(echo "$THREAD_DATA" | jq '.has_unresponded_replies')
  [[ "$HAS_REPLIES" != "true" ]] && continue

  ENTRY=$(jq -n \
    --arg url        "$url" \
    --arg number     "$number" \
    --arg owner      "$owner" \
    --arg repo       "$repo" \
    --arg title      "$title" \
    --arg author     "$author" \
    --arg updated_at "$updated_at" \
    --argjson td     "$THREAD_DATA" \
    '{
      url:                    $url,
      number:                 ($number | tonumber),
      owner:                  $owner,
      repo:                   $repo,
      title:                  $title,
      author:                 $author,
      updated_at:             $updated_at,
      reason:                 "thread-reply",
      review_thread_replies:  $td.review_thread_replies,
      issue_comment_replies:  $td.issue_comment_replies
    }')

  RESULTS=$(jq -n --argjson a "$RESULTS" --argjson b "[$ENTRY]" '$a + $b')

done < <(echo "$COMMENTED_PRS" | jq -c '.[]')

echo "$RESULTS"
