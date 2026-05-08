---
name: pr-action-board
description: Find your open PRs that are either approved or have new unresolved/unresponded comments, compile them into a triage board with human-annotatable MERGE/ADDRESS/REPLY/SKIP actions, then dispatch dedicated agents to execute each decision. Use when the user asks "what PRs do I need to deal with?", "triage my open PRs", "which PRs need my attention?", or similar.
disable-model-invocation: false
---

# PR Action Board Skill

Surface every PR that needs your attention in one annotated triage file:

- **Your own open PRs** — approved and waiting to merge, or sitting on unanswered reviewer comments.
- **Others' PRs where you need to respond** — someone replied to your comment, tagged you directly, tagged one of your teams, or the PR description mentions you or a team you belong to.

---

## Helper Scripts

All deterministic state checks in this skill are performed by helper scripts co-located with the skill. Before Phase 2, locate the script directory:

```sh
SCRIPT_DIR=$(find ~ -maxdepth 7 \
  -path "*/farty-bobo/skills/pr-action-board/scripts" \
  -type d 2>/dev/null | head -1)

if [[ -z "$SCRIPT_DIR" ]]; then
  echo "ERROR: farty-bobo scripts not found. Clone the farty-bobo repo first." >&2
  exit 1
fi
```

Cache `$SCRIPT_DIR` for use throughout all phases.

Scripts available (all executable, all take stdin/stdout, all output JSON):

| Script | Purpose |
|--------|---------|
| `get-teams.sh <org>` | Returns `[{slug, name, mention}]` for the user's teams in one org |
| `find-mention-prs.sh <login> <org_or_empty> <teams_json>` | Open PRs (not mine) where I or my teams are mentioned and I haven't responded |
| `find-thread-reply-prs.sh <login> <org_or_empty>` | Open PRs (not mine) where I commented and got unresponded replies |
| `check-pr-threads.sh <login> <owner> <repo> <pr_number>` | Per-PR check: unresolved review threads + issue comment chains with unresponded replies |

---

## Phase 1 — Preflight

1. Run `gh auth status`. If unauthenticated, stop and tell the human to run `gh auth login`.
2. Resolve the GitHub login once and cache it:
   ```sh
   gh api user --jq .login
   ```
   Do NOT assume a login from git config, memory, or any other source.
3. **Prompt the human to choose the org scope.** Fetch the list of orgs:
   ```sh
   gh api user/orgs --jq '.[].login'
   ```
   Present the list and ask the human to pick one, or "all" to scan across all orgs:

   ```
   Which org should I scan?

     1) embarkvet
     2) acme-corp
     3) all orgs (no restriction)

   Enter a number or org name:
   ```

   Do NOT proceed until the human responds. Cache their choice as `{scope}`:
   - Specific org → `{scope}` = `--owner {org}` for `gh search prs` calls; org name alone for scripts.
   - "all" → `{scope}` = `` (no flag); pass empty string to scripts.

---

## Phase 2 — Scan for Actionable PRs

Run phases 2a, 2b, and 2c **in parallel**. Collect and deduplicate by URL.

### 2a. My Approved PRs

```sh
gh search prs \
  --author="@me" \
  --state=open \
  --review=approved \
  --json number,title,url,repository,createdAt,updatedAt,isDraft,labels \
  --limit 100 \
  {scope}
```

Exclude drafts (`isDraft: true`) unless the human explicitly asked to include them.

### 2b. My PRs with New Unresponded Comments

```sh
gh search prs \
  --author="@me" \
  --state=open \
  --json number,title,url,repository,createdAt,updatedAt,isDraft \
  --limit 100 \
  {scope}
```

For each PR, run in parallel (batch up to 10 at a time):

```sh
# PR-level conversation comments
gh api repos/{owner}/{repo}/issues/{number}/comments \
  --jq '[.[] | {login: .user.login, created_at: .created_at, body: .body}] | sort_by(.created_at)'

# Formal review states
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --jq '[.[] | {login: .user.login, state: .state, submitted_at: .submitted_at, body: .body}] | sort_by(.submitted_at)'

# Inline review threads WITH resolution status (GraphQL)
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            isOutdated
            comments(first: 20) {
              nodes {
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
  }
' -f owner="{owner}" -f repo="{repo}" -F number={number}
```

**Identity anchor:** Use the cached `{gh_login}` from Phase 1 as the authoritative identity. A comment or review is "from the human" if and only if `author.login` / `user.login` equals `{gh_login}`.

**Inline thread filtering:**
- Exclude `isResolved: true` and `isOutdated: true` threads.
- Only count and surface threads where `isResolved: false` AND `isOutdated: false`.

**Keep a PR in the unresponded list if ANY of:**
- A reviewer left a conversation comment AFTER the human's last comment and the human has not replied since.
- A reviewer's formal review state is `CHANGES_REQUESTED` with no subsequent human acknowledgment.
- An unresolved, non-outdated inline thread where the last reply's `author.login` is NOT `{gh_login}`.

**Skip if:**
- The human's most recent activity on the PR is newer than all unresolved reviewer activity.
- The only reviewer activity is a simple `APPROVED` with no comments.

### 2c. Others' PRs — Where I Need to Respond

This phase uses the helper scripts to deterministically find open PRs authored by others where:
- Someone replied to a comment I left (and I haven't responded to the reply), **or**
- A comment tags me directly (`@{gh_login}`), **or**
- A comment or PR description tags one of my teams, **or**
- The PR description itself tags me directly —

and I have **not** commented on the PR since the triggering event.

Run 2c-i first (TEAMS_JSON is needed by 2c-ii). Once 2c-i completes, run 2c-ii and 2c-iii **in parallel** — 2c-iii has no dependency on TEAMS_JSON.

#### 2c-i. Team membership (prerequisite for 2c-ii only)

```sh
TEAMS_JSON=$("$SCRIPT_DIR/get-teams.sh" "{org}")
# If scope is "all orgs", call get-teams.sh for each org individually and merge results.
# If get-teams.sh errors or returns [], proceed with TEAMS_JSON="[]".
```

#### 2c-ii. Mention PRs (run after TEAMS_JSON is available)

```sh
MENTION_PRS=$("$SCRIPT_DIR/find-mention-prs.sh" \
  "{gh_login}" "{org_or_empty}" "$TEAMS_JSON")
```

Output is a JSON array of PRs. Each entry includes `reason` (`"direct-mention"`, `"team-mention"`, or `"description-mention"`), `mentioned_at`, and the full PR metadata.

**"Has not responded" rule:** `find-mention-prs.sh` already filters out PRs where the user posted a comment after `mentioned_at`. No additional filtering needed.

#### 2c-iii. Thread reply PRs (run after TEAMS_JSON step completes)

```sh
THREAD_REPLY_PRS=$("$SCRIPT_DIR/find-thread-reply-prs.sh" \
  "{gh_login}" "{org_or_empty}")
```

Output is a JSON array of PRs. Each entry includes `reason: "thread-reply"`, plus `review_thread_replies` and `issue_comment_replies` arrays with the specific unresponded content.

#### 2c-iv. Merge and deduplicate

Combine `MENTION_PRS` and `THREAD_REPLY_PRS`. Deduplicate by URL, preserving all distinct `reason` values. If a PR appears with multiple reasons (e.g., both a thread reply and a direct mention), set `reason` to `"multiple"` and list all individual reasons in a `reasons` array.

Cap at 30 PRs from Phase 2c (most recently updated first). Warn the human and list dropped PR numbers if more are found.

### 2d. Enrich All PRs

For every unique PR from 2a, 2b, and 2c (up to 50 total — if more, keep the 50 most recently updated, warn and list dropped numbers):

```sh
gh pr view {number} --repo {owner}/{repo} \
  --json mergeable,mergeStateStatus,statusCheckRollup,reviews,reviewRequests,headRefName,baseRefName
```

Derive per PR:
- **Approvers**: unique logins from `reviews` where `state == "APPROVED"`, latest review per reviewer.
- **Pending reviewers**: entries in `reviewRequests` who haven't responded.
- **CI status**: `passing` | `failing` | `pending` | `none`.
- **Merge readiness**: `ready` | `conflicts` | `blocked` | `unknown`.
- **Unresponded comment count** (2a/2b PRs only): unresolved, non-outdated threads + unacknowledged conversation comments.
- **PR type**: `my-pr` (2a/2b) | `others-pr` (2c).
- **Reason for inclusion**: `approved` | `unresponded-comments` | `both` | `thread-reply` | `mention` | `direct-mention` | `team-mention` | `multiple`.
- **CHANGES_REQUESTED override**: If any reviewer's latest review state is `CHANGES_REQUESTED`, default action is `ADDRESS` regardless of approvals.

---

## Phase 3 — Build the Triage Board File

Write to:
```
/tmp/pr-action-board-{YYYYMMDD-HHMMSS}.md
```

### File format

```markdown
# PR Action Board — {YYYY-MM-DD HH:MM:SS}

Scoped to: {org name, or "all orgs"}
GitHub login: @{login}

---

## My Open PRs

| PR | Title | Repo | Reason | Approvers | CI | Merge Ready | Unresponded | Updated |
|----|-------|------|--------|-----------|----|-----------  |-------------|---------|
| [#123](url) | Fix login redirect | embarkvet/foo | approved | @alice, @bob | passing | ready | 0 | 2h ago |
| [#118](url) | Add PostHog tracking | embarkvet/bar | unresponded-comments | — | failing | blocked | 3 | 1d ago |

**Total:** N  **Approved + ready:** M  **Need attention:** K

---

## Others' PRs — Action Needed From Me

| PR | Author | Repo | Reason | Context | Updated |
|----|--------|------|--------|---------|---------|
| [#77](url) | @alice | embarkvet/bar | thread-reply | Reply to my comment on `src/auth.ts:14` | 3h ago |
| [#55](url) | @bob | embarkvet/baz | direct-mention | @kinanf tagged in comment by @carol | 1d ago |
| [#42](url) | @dave | embarkvet/qux | description-mention | PR description mentions @kinanf | 2d ago |

**Total:** N

---

## PR Details & Actions

<!-- ═══════════════════════════════════════════════════════════════════════ -->

### [My PR] [#123] Fix login redirect — embarkvet/foo

**URL:** https://github.com/embarkvet/foo/pull/123  
**Branch:** `fix/login-redirect` → `main`  
**Reason:** approved  
**Approvers:** @alice, @bob  
**Pending reviewers:** none  
**CI:** passing  
**Merge ready:** ready  
**Unresponded comments:** 0  

#### Reviewer Activity

*(none — approved cleanly)*

### Action

```
MERGE
```

<!-- Set to one of: MERGE | ADDRESS | SKIP -->
<!-- MERGE   → merge this PR, then monitor CI -->
<!-- ADDRESS → spin up an agent to address reviewer comments -->
<!-- SKIP    → do nothing this round -->

<!-- ═══════════════════════════════════════════════════════════════════════ -->

### [Others' PR] [#77] Refactor auth service — embarkvet/bar

**URL:** https://github.com/embarkvet/bar/pull/77  
**Author:** @alice  
**Reason:** thread-reply  
**Updated:** 3h ago  

#### Unresponded Thread Replies

- Review thread on `src/auth.ts:14` — @alice (3h ago): "Do you think we should extract this into a shared helper? Would love your take since you built the original."

#### Action

```
REPLY
```

<!-- Set to one of: REPLY | SKIP -->
<!-- REPLY → I will draft a response and post it after your approval -->
<!-- SKIP  → skip this round -->

<!-- ═══════════════════════════════════════════════════════════════════════ -->

### [Others' PR] [#55] Add rate limiting — embarkvet/baz

**URL:** https://github.com/embarkvet/baz/pull/55  
**Author:** @bob  
**Reason:** direct-mention  
**Mentioned at:** 2026-05-07 14:32 UTC  
**Updated:** 1d ago  

#### Mention Context

- @carol (1d ago, PR comment): "@kinanf — can you review the token bucket implementation here? You wrote the original spec."

#### Action

```
REPLY
```

<!-- ═══════════════════════════════════════════════════════════════════════ -->
```

**"Others' PR" detail format:**
- Header: `### [Others' PR] [#N] {title} — {owner}/{repo}`
- Show: URL, Author, Reason, Mentioned at (for mention reasons) or Updated at (for thread-reply), Updated
- Show `#### Unresponded Thread Replies` (for `thread-reply`) listing each reply truncated to 200 chars
- Show `#### Mention Context` (for mention reasons) showing the comment(s) that triggered the match, truncated to 200 chars
- Default action: `REPLY`

**"My PR" detail format:** unchanged from before (see example above).

**Default action values:**
- My PR — approved + merge-ready + CI passing + 0 unresponded: `MERGE`
- My PR — unresponded comments OR CI failing OR merge blocked: `ADDRESS`
- My PR — draft: `SKIP` (note it is a draft)
- Others' PR — any: `REPLY`
- Everything else: `TBD`

After writing the file, tell the human:

```
Triage board written to: /tmp/pr-action-board-{timestamp}.md

Open the file and set the Action for each PR:
  MERGE   → I will merge it and monitor CI (default for approved + clean)
  ADDRESS → I will address reviewer comments on your PR
  REPLY   → I will draft a reply and post it after your approval
  SKIP    → skip this round

Save the file and tell me "done" to execute.
```

**Do NOT proceed until the human explicitly says they are done annotating.**

---

## Phase 4 — Parse Annotations

Re-read the triage file. For each PR's `### Action` section, find the **first non-comment, non-blank line** inside the code block that matches:

- `/^MERGE$/i` → Phase 5a
- `/^ADDRESS$/i` → Phase 5b
- `/^REPLY$/i` → Phase 5c
- `/^SKIP$/i` → log as skipped
- `/^TBD$/i` → surface to the human (see below)
- Malformed or missing code block → treat as `TBD`

**TBD handling:** Dispatch all clear-action PRs immediately. Surface TBD PRs to the human in parallel; dispatch their agents as soon as the human resolves each one.

Tally: `{M} MERGE, {A} ADDRESS, {R} REPLY, {S} SKIP, {T} TBD`

---

## Phase 5 — Execute Actions

### 5a. MERGE flow (parallel)

For each MERGE-annotated PR, spin up a dedicated general-purpose agent named after a unique American outlaw from the 1800s–1900s (e.g. Butch Cassidy, Jesse James, Belle Starr, Black Bart, Dutch Schultz, Pretty Boy Floyd, Billy the Kid, Bonnie Parker, Sam Bass, Pearl Hart, John Wesley Hardin, Cole Younger, Doc Holliday, Calamity Jane, Tom Horn, Kid Curry, Sundance Kid, Cherokee Bill, Cattle Annie, Emmett Dalton). Names must be unique across all agents in this session. If the list is exhausted, continue with other historical American outlaws.

Each merge agent receives:
1. PR URL, number, and repo `{owner}/{repo}`.
2. Merge strategy — ask the human once before dispatching if not already specified: `--squash` (default), `--merge`, or `--rebase`.
3. Instructions to:

   a. **Pre-merge check:** Run `gh pr view {number} --repo {owner}/{repo} --json mergeable,mergeStateStatus,statusCheckRollup,baseRefName` and verify:
      - `mergeable` is `"MERGEABLE"` and `mergeStateStatus` is `"CLEAN"`. If `mergeable` is `null`, wait 10 seconds and re-poll up to 3 times.
      - CI is passing.
      - Cache `baseRefName` for post-merge monitoring.
      - If either check fails after retries, do NOT merge — report the blocker to the parent skill.

   b. **Merge:**
      ```sh
      gh pr merge {number} --repo {owner}/{repo} --{strategy} --delete-branch
      ```
      Check `gh repo view {owner}/{repo} --json branchProtectionRules`. If it returns an empty array or errors, attempt direct merge. If direct merge fails citing required status checks, retry with `--auto`.

   c. **Post-merge CI watch:** Monitor `{baseRefName}` for up to 10 minutes, polling every 60 seconds:
      ```sh
      gh run list --branch {baseRefName} --repo {owner}/{repo} --limit 3 \
        --json databaseId,status,conclusion,name,createdAt
      ```
      If any run fails, invoke `/resolve-ci-failures` on `{baseRefName}`. If not terminal after 10 minutes, return `ci_outcome: timed_out` — do NOT invoke `/resolve-ci-failures` for timed-out runs.

   d. **Jira ticket transition (only after CI is green):**
      1. Extract ticket key from PR title then `headRefName` using `[A-Z]+-\d+`. If none found, record `jira_transition: skipped_no_ticket`.
      2. Fetch available transitions via `getTransitionsForJiraIssue`.
      3. Select target: "Done" → "Merged" → "Released" → "Closed" (first match, case-insensitive).
      4. Idempotency check via `getJiraIssue` — skip if already in or past target state.
      5. Apply via `transitionJiraIssue`. On error, record `jira_transition: failed` and do not block.
      6. Skip entirely if CI is not green; record `jira_transition: skipped_ci_not_green`.

   e. Return:
      ```json
      {
        "pr": 123,
        "repo": "owner/repo",
        "status": "merged | blocked | error",
        "merge_sha": "abc123",
        "ci_outcome": "passing | failing | timed_out | skipped",
        "jira_ticket": "BBH-1915 | null",
        "jira_transition": "done | skipped_no_ticket | skipped_no_matching_state | skipped_already_done | skipped_ci_not_green | failed",
        "notes": "any relevant detail"
      }
      ```

### 5b. ADDRESS flow (sequential — each requires human interaction)

For each ADDRESS-annotated PR (my own PRs), spawn a dedicated agent (continue unique outlaw names). Run **sequentially**.

Each address agent receives:
1. PR URL, number, repo `{owner}/{repo}`, and `headRefName`.
2. The unresponded reviewer activity from Phase 2b (verbatim, so the agent does not need to re-fetch).
3. Instructions to locate the local clone, check out `{headRefName}`, and invoke `/address-pr-comments`. The agent must return findings **before making any changes**.
4. If no local clone is found: return `status: no_local_clone` — do not proceed.
5. Return findings in:
   ```json
   {
     "pr": 118,
     "repo": "owner/repo",
     "proposed_changes": [
       { "comment_author": "@carol", "comment_summary": "...", "proposed_action": "...", "type": "code_change | discussion | ignore" }
     ],
     "discussion_items": [
       { "comment_author": "@dave", "question": "...", "draft_reply": "..." }
     ],
     "questions_for_human": ["..."]
   }
   ```

**After each address agent returns findings:**
1. Present proposed changes, discussion items, and questions clearly.
2. Wait for human approval — which changes to make, which to skip, how to answer questions.
3. Only after approval: send follow-up to the agent to implement changes, post discussion replies, run `/build`, and run `/critique`.
4. Wait for completion before the next ADDRESS PR.

### 5c. REPLY flow (sequential — each requires human interaction)

For each REPLY-annotated PR (others' PRs where I'm mentioned or got a thread reply), spawn a dedicated agent (continue unique outlaw names). Run **sequentially**.

Each reply agent receives:
1. PR URL, number, repo `{owner}/{repo}`, PR author.
2. The full mention/thread context captured in Phase 2c (verbatim — exact comment text, author, timestamp).
3. Instructions to draft one reply per unresponded thread or mention. The draft should:
   - Be professional and actionable.
   - Reference the specific question or request.
   - NOT make any code changes.
4. Return a structured draft:
   ```json
   {
     "pr": 77,
     "repo": "owner/repo",
     "drafts": [
       {
         "target_type": "review_thread | pr_comment | pr_description",
         "target_id": "thread id or comment id or null",
         "context_summary": "Alice asked for my take on extracting a shared helper",
         "draft_reply": "Hey @alice — yeah I think extracting it makes sense. The original pattern in the auth module was...",
         "questions_for_human": ["Do you want me to volunteer to implement the extraction, or just answer the question?"]
       }
     ]
   }
   ```

**After each reply agent returns drafts:**
1. Present each draft reply with its context to the human.
2. Ask the human: approve as-is, edit, or skip each draft. Wait for answers to `questions_for_human`.
3. Only after approval: send follow-up to the agent to post approved replies.
   - All replies posted to GitHub must open with `_Posted by Farty Bobo on behalf of @{gh_login}._`
   - For review thread replies: use `first_comment_rest_id` from the `review_thread_replies` entry (provided by `check-pr-threads.sh`). Post via `gh api -X POST repos/{owner}/{repo}/pulls/{number}/comments/{first_comment_rest_id}/replies -f body="..."`. This is the REST integer comment ID, not the GraphQL node ID.
   - For PR-level comments: post via `gh api repos/{owner}/{repo}/issues/{number}/comments`
4. Wait for completion before the next REPLY PR.

---

## Phase 6 — Update Triage File and Report

Phase 6 runs only after ALL agents have returned. The parent skill (PR Action Board) writes the triage file; sub-agents do NOT.

1. Re-read the triage file.
2. Append `#### Outcome` under each PR's `### Action` block:
   ```markdown
   #### Outcome

   **Status:** merged | addressed | replied | skipped | blocked  
   **Completed:** {timestamp}  
   **Details:** {one-sentence summary}  
   **CI post-merge:** passing | failing | timed_out | n/a  
   **Jira:** {ticket} → Done | skipped ({reason}) | n/a  
   ```
3. Add an `Outcome` column to both summary tables.
4. Report to the human:
   ```
   PR Action Board — complete.

   ✓  MERGE  [#123] embarkvet/foo — merged. CI passing. BBH-1915 → Done.
   ✓  ADDRESS [#118] embarkvet/bar — 3 comments addressed, pushed, critique passed.
   ✓  REPLY  [#77] embarkvet/bar — 1 thread reply posted.
   ✓  REPLY  [#55] embarkvet/baz — 1 mention reply posted.
   —  SKIP   [#101] embarkvet/qux — skipped per your instruction.
   ✗  MERGE  [#109] embarkvet/qux — blocked: merge conflicts. Needs manual rebase.

   Updated triage file: /tmp/pr-action-board-{timestamp}.md
   ```

---

## Guardrails

- **No merges or commits without annotation.** The skill takes no destructive action until the human annotates and says "done". The pre-merge check in Phase 5a is a second safety gate.
- **Human-in-the-loop for ADDRESS.** Findings are presented before any code is modified.
- **Human-in-the-loop for REPLY.** Draft replies are presented before posting. No reply is sent without explicit approval.
- **No external posts without disclosure.** Every comment, reply, or notification posted to GitHub must open with `_Posted by Farty Bobo on behalf of @{gh_login}._`
- **No summary comments to GitHub PRs.** Only inline code review comments and targeted replies to specific threads. Summaries stay in the triage file.
- **Sequential ADDRESS and REPLY, parallel MERGE.** MERGE agents are fire-and-report. ADDRESS and REPLY agents require human interaction.
- **Do not post the triage file externally.** The `/tmp` file is local only.
- **One round per invocation.** New PRs or comments arriving after Phase 2 are not included.
- **Outlaw names must be unique per session.** Never reuse a name — even after the previous agent has completed.
