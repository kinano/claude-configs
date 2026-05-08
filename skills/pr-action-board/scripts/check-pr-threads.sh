#!/usr/bin/env bash
# check-pr-threads.sh — For a single PR, find unresolved review threads and PR-level comment chains
#   where the authenticated user commented but has NOT replied to the most recent message.
#
# Usage: ./check-pr-threads.sh <gh_login> <owner> <repo> <pr_number>
#
# Output: JSON object:
#   {
#     "pr_number": <int>,
#     "has_unresponded_replies": <bool>,
#     "review_thread_replies": [ { thread_id, path, line, my_last_comment_at,
#                                  last_reply_author, last_reply_at, last_reply_body } ],
#     "issue_comment_replies":  [ { reply_author, reply_at, reply_body } ]
#   }
set -euo pipefail

GH_LOGIN="${1:?Usage: check-pr-threads.sh <gh_login> <owner> <repo> <pr_number>}"
OWNER="${2:?}"
REPO="${3:?}"
PR_NUMBER="${4:?}"

# ── Review threads (GraphQL — only way to get isResolved + isOutdated) ──────
REVIEW_THREADS=$(gh api graphql \
  -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              isOutdated
              comments(first: 50) {
                nodes {
                  databaseId
                  author { login }
                  createdAt
                  body
                  path
                  line
                }
              }
            }
          }
        }
      }
    }' \
  -f owner="$OWNER" -f repo="$REPO" -F number="$PR_NUMBER" 2>/dev/null \
  || echo '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}'
)

# ── PR-level (issue) comments (REST) ────────────────────────────────────────
ISSUE_COMMENTS=$(gh api "repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments" \
  --paginate 2>/dev/null \
  | jq -s 'add // [] | map({ author: .user.login, created_at: .created_at, body: (.body | .[0:300]) })'
)

# ── Merge and analyse ────────────────────────────────────────────────────────
jq -n \
  --arg login      "$GH_LOGIN" \
  --argjson rt     "$REVIEW_THREADS" \
  --argjson ic     "$ISSUE_COMMENTS" \
  --arg prn        "$PR_NUMBER" \
'
# ── Review threads: unresolved, non-outdated, where I commented but am NOT last ──
($rt.data.repository.pullRequest.reviewThreads.nodes
  | map(select(.isResolved == false and .isOutdated == false))
  | map(select(any(.comments.nodes[]; .author.login == $login)))
  | map(select((.comments.nodes | last | .author.login) != $login))
  | map({
      thread_id:              .id,
      first_comment_rest_id:  (.comments.nodes | first | .databaseId),
      path:                   (.comments.nodes | first | .path // ""),
      line:                   (.comments.nodes | first | .line // null),
      my_last_comment_at:     (.comments.nodes | map(select(.author.login == $login)) | last | .createdAt),
      last_reply_author:      (.comments.nodes | last | .author.login),
      last_reply_at:          (.comments.nodes | last | .createdAt),
      last_reply_body:        (.comments.nodes | last | .body | .[0:200])
    })
) as $thread_replies |

# ── Issue comments: any comment by others AFTER my last comment ──────────────
(($ic | map(select(.author == $login)) | last | .created_at) as $my_last_at |
  if $my_last_at == null then []
  else
    $ic
    | map(select(.author != $login and .created_at > $my_last_at))
    | map({ reply_author: .author, reply_at: .created_at, reply_body: (.body | .[0:200]) })
  end
) as $ic_replies |

{
  pr_number:               ($prn | tonumber),
  has_unresponded_replies: (($thread_replies | length) > 0 or ($ic_replies | length) > 0),
  review_thread_replies:   $thread_replies,
  issue_comment_replies:   $ic_replies
}
'
