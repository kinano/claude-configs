#!/usr/bin/env bash
# find-mention-prs.sh — Find open PRs (not authored by me) where the user or their teams are
#   mentioned in the PR body OR in comments, and the user has NOT responded since the mention.
#
# Sources checked:
#   1. GitHub search  "mentions:<login>"           — body mentions (+ GitHub may index some comments)
#   2. GitHub search  "team:<org>/<slug>"           — team mentions in PR body
#   3. GitHub notifications with reason=mention     — comment-level direct mentions
#   4. GitHub notifications with reason=team_mention — comment-level team mentions
#
# For each candidate the script checks whether the user has posted any comment on the PR
# AFTER the mention timestamp. If yes, the PR is excluded (already responded).
#
# Usage:
#   ./find-mention-prs.sh <gh_login> <org_scope_or_empty> <teams_json>
#
#   gh_login           — the authenticated user's login (e.g. "kinanf")
#   org_scope_or_empty — restrict to one GitHub org (e.g. "embarkvet"), or "" for all orgs
#   teams_json         — JSON array from get-teams.sh, e.g. '[{"mention":"@embarkvet/platform"}]'
#
# Output: JSON array of:
#   { url, number, owner, repo, title, author, reason, mentioned_at, updated_at }
#
# Reasons: "mention" | "team-mention" | "direct-mention"
#   mention        — gh search "mentions:" hit (covers body + comments, indistinguishable)
#   team-mention   — gh search "team:" hit or notification reason=team_mention
#   direct-mention — notification reason=mention (comment-level, not from search)
set -euo pipefail

GH_LOGIN="${1:?Usage: find-mention-prs.sh <gh_login> <org_scope_or_empty> <teams_json>}"
ORG_SCOPE="${2:-}"
TEAMS_JSON="${3:-[]}"

JSON_FIELDS="number,title,url,author,repository,createdAt,updatedAt,body"

build_search_args() {
  # Outputs positional args array for gh search prs (no --owner if ORG_SCOPE is empty)
  local args=("--state" "open" "--json" "$JSON_FIELDS" "--limit" "100")
  [[ -n "$ORG_SCOPE" ]] && args+=("--owner" "$ORG_SCOPE")
  printf '%s\0' "${args[@]}"
}

parse_url() {
  # Extract owner and repo from a github.com PR URL
  local url="$1"
  echo "$url" | awk -F'/' '{print $4 "\t" $5}'
}

# ── Collect raw candidates ───────────────────────────────────────────────────

CANDIDATES="[]"

# 1. Direct body mentions via GitHub search
mapfile -d $'\0' SEARCH_ARGS < <(build_search_args)
BODY_DIRECT=$(gh search prs "mentions:${GH_LOGIN} -author:${GH_LOGIN}" \
  "${SEARCH_ARGS[@]}" 2>/dev/null || echo "[]")
BODY_DIRECT=$(echo "$BODY_DIRECT" | jq '[.[] | . + {reason: "mention"}]')
CANDIDATES=$(jq -n --argjson a "$CANDIDATES" --argjson b "$BODY_DIRECT" '$a + $b')

# 2. Team body mentions
while IFS= read -r team_mention; do
  [[ -z "$team_mention" ]] && continue
  team_slug="${team_mention#@}"   # strip leading @  →  "embarkvet/platform"
  TEAM_PRS=$(gh search prs "team:${team_slug} -author:${GH_LOGIN}" \
    "${SEARCH_ARGS[@]}" 2>/dev/null || echo "[]")
  TEAM_PRS=$(echo "$TEAM_PRS" | jq --arg tm "$team_mention" \
    '[.[] | . + {reason: "team-mention", team_mentioned: $tm}]')
  CANDIDATES=$(jq -n --argjson a "$CANDIDATES" --argjson b "$TEAM_PRS" '$a + $b')
done < <(echo "$TEAMS_JSON" | jq -r '.[].mention')

# 3. Comment-level mentions via notifications API
NOTIF_FILTER='[.[] | select(
    (.reason == "mention" or .reason == "team_mention")
    and .subject.type == "PullRequest"
  ) | {
    reason: (if .reason == "mention" then "direct-mention" else "team-mention" end),
    mentioned_at: .updated_at,
    pr_api_url: .subject.url,
    url: (
      .subject.url
      | gsub("https://api.github.com/repos/"; "https://github.com/")
      | gsub("/pulls/"; "/pull/")
    )
  }]'

NOTIF_PRS=$(gh api "notifications?all=true" --paginate 2>/dev/null \
  | jq -s "add // [] | $NOTIF_FILTER" || echo "[]")

# For each notification PR, fetch its title/author so we can do the responded-check
while IFS=$'\t' read -r pr_url pr_api_url reason mentioned_at; do
  [[ -z "$pr_url" ]] && continue
  owner_repo=$(parse_url "$pr_url")
  owner=$(echo "$owner_repo" | cut -f1)
  repo=$(echo "$owner_repo"  | cut -f2)
  pr_num=$(echo "$pr_url" | awk -F'/' '{print $NF}')

  # Fetch PR metadata in a single call
  PR_META=$(gh api "repos/${owner}/${repo}/pulls/${pr_num}" \
    --jq '{author: .user.login, title: .title, updated_at: .updated_at}' 2>/dev/null || echo '{}')
  PR_AUTHOR=$(echo "$PR_META" | jq -r '.author // ""')
  [[ "$PR_AUTHOR" == "$GH_LOGIN" ]] && continue
  PR_TITLE=$(echo "$PR_META"   | jq -r '.title // ""')
  PR_UPDATED=$(echo "$PR_META" | jq -r '.updated_at // ""')

  NOTIF_ENTRY=$(jq -n \
    --arg url          "$pr_url" \
    --arg number       "$pr_num" \
    --arg owner        "$owner" \
    --arg repo         "$repo" \
    --arg title        "$PR_TITLE" \
    --arg author       "$PR_AUTHOR" \
    --arg reason       "$reason" \
    --arg mentioned_at "$mentioned_at" \
    --arg updated_at   "$PR_UPDATED" \
    '{ url: $url, number: ($number | tonumber), owner: $owner, repo: $repo, title: $title,
       author: $author, reason: $reason, mentioned_at: $mentioned_at, updated_at: $updated_at }')
  CANDIDATES=$(jq -n --argjson a "$CANDIDATES" --argjson b "[$NOTIF_ENTRY]" '$a + $b')
done < <(echo "$NOTIF_PRS" | jq -r '.[] | [.url, .pr_api_url, .reason, .mentioned_at] | @tsv')

# ── Deduplicate by URL, keep earliest mentioned_at ──────────────────────────
DEDUPED=$(echo "$CANDIDATES" | jq '
  group_by(.url)
  | map(
      (map(.mentioned_at) | sort | first) as $earliest_mention |
      .[0] | .mentioned_at = ($earliest_mention // .createdAt // .updated_at)
    )
  | sort_by(.updated_at) | reverse
')

# ── Filter: keep only PRs where the user has NOT commented since the mention ─
RESULTS="[]"
while IFS=$'\t' read -r pr_url owner repo pr_num mentioned_at; do
  [[ -z "$pr_url" ]] && continue

  # Fetch the user's most recent comment on this PR.
  # --paginate outputs one array per page; jq -s merges all pages before filtering,
  # avoiding the --jq-per-page bug that would produce multi-line output.
  MY_LAST_COMMENT=$(gh api "repos/${owner}/${repo}/issues/${pr_num}/comments" \
    --paginate 2>/dev/null \
    | jq -s "add // [] | map(select(.user.login == \"${GH_LOGIN}\")) | last | .created_at // \"null\"" \
    || echo "null")

  # If the user commented AFTER the mention, they've responded — skip
  HAS_RESPONDED=$(jq -n \
    --arg last_comment "$MY_LAST_COMMENT" \
    --arg mentioned_at "$mentioned_at" \
    '$last_comment != "null" and $last_comment > $mentioned_at')

  if [[ "$HAS_RESPONDED" == "false" ]]; then
    PR_ENTRY=$(echo "$DEDUPED" | jq \
      --arg url "$pr_url" \
      '.[] | select(.url == $url)')
    RESULTS=$(jq -n --argjson a "$RESULTS" --argjson b "[$PR_ENTRY]" '$a + $b')
  fi
done < <(echo "$DEDUPED" | jq -r '.[] | [.url, .owner, .repo, (.number | tostring), (.mentioned_at // "")] | @tsv')

echo "$RESULTS"
