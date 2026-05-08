#!/usr/bin/env bash
# get-teams.sh — List the authenticated user's GitHub team memberships in one org
# Usage: ./get-teams.sh <org>
# Output: JSON array of {slug, name, mention} where mention = "@org/slug"
#         Empty array if the user belongs to no teams in the org.
set -euo pipefail

ORG="${1:?Usage: get-teams.sh <org>}"

# /user/teams returns all teams the authenticated user belongs to across all orgs.
# --paginate concatenates pages; jq -s merges the resulting array-of-arrays.
gh api "/user/teams" --paginate 2>/dev/null \
  | jq -s --arg org "$ORG" \
    'add // []
     | map(select(.organization.login == $org))
     | map({ slug: .slug, name: .name, mention: ("@" + $org + "/" + .slug) })'
