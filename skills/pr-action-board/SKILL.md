---
name: pr-action-board
description: Find your open PRs that are either approved or have new unresolved/unresponded comments, compile them into a triage board with human-annotatable MERGE/ADDRESS/SKIP actions, then dispatch dedicated agents to execute each decision. Use when the user asks "what PRs do I need to deal with?", "triage my open PRs", "which PRs need my attention?", or similar.
disable-model-invocation: false
---

# PR Action Board Skill

Surface every open PR you authored that needs your attention — approved and waiting to merge, or sitting on unanswered reviewer comments — and let you decide what to do about each one from a single annotated file.

---

## Phase 1 — Preflight

1. Run `gh auth status`. If unauthenticated, stop and tell the human to run `gh auth login`.
2. Resolve the GitHub login once and cache it for the session:
   ```sh
   gh api user --jq .login
   ```
   Do NOT assume a login from git config, memory, or any other source.
3. Determine the scan scope based on how the skill was invoked:
   - **Current repo** *(default when inside a git repo with a GitHub remote)*: scope to `{owner}/{repo}` resolved from `git remote get-url origin`.
   - **Org/owner** *(if the human names one)*: scope to `--owner {name}`.
   - **Everywhere** *(if invoked outside a git repo or human says "all my PRs")*: no scope restriction.

---

## Phase 2 — Scan for Actionable PRs

Run both queries in parallel. Collect and merge the results — deduplicate by PR URL.

### 2a. Approved PRs

```sh
gh search prs \
  --author="@me" \
  --state=open \
  --review=approved \
  --json number,title,url,repository,createdAt,updatedAt,isDraft,labels \
  --limit 100
  # Add --repo OWNER/REPO or --owner OWNER to scope when applicable
```

Exclude drafts (`isDraft: true`) unless the human explicitly asked to include them.

### 2b. PRs with new unresponded comments

```sh
gh search prs \
  --author="@me" \
  --state=open \
  --json number,title,url,repository,createdAt,updatedAt,isDraft \
  --limit 100
  # Add scope flags as above
```

For each PR returned, run the following in parallel (batch up to 10 at a time to avoid rate limits):

```sh
# Get all PR-level conversation comments
gh api repos/{owner}/{repo}/issues/{number}/comments \
  --jq '[.[] | {login: .user.login, created_at: .created_at, body: .body}] | sort_by(.created_at)'

# Get all inline review thread comments
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  --jq '[.[] | {login: .user.login, created_at: .created_at, body: .body, path: .path, line: .line}] | sort_by(.created_at)'

# Get formal review states
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --jq '[.[] | {login: .user.login, state: .state, submitted_at: .submitted_at, body: .body}] | sort_by(.submitted_at)'
```

**Identity anchor:** Use the cached `{gh_login}` from Phase 1 as the authoritative identity for all comment filtering. A comment or review is "from the human" if and only if its `user.login` equals `{gh_login}`. Do not infer identity from PR author, assignee, or any other field.

**Keep a PR in the "unresponded" list if ANY of the following is true:**
- A reviewer left a comment or formal review AFTER the human's last comment/review on this PR AND the human has not replied since (compare `user.login` against `{gh_login}`).
- A reviewer's formal review state is `CHANGES_REQUESTED` and there is no subsequent comment where `user.login == {gh_login}` acknowledging it.
- A review thread has comments from reviewers where the last reply's `user.login` is NOT `{gh_login}`.

**Skip the PR (do not include it) if:**
- The human's most recent activity on that PR (any comment/review where `user.login == {gh_login}`) is newer than all reviewer comments — they have already responded.
- The only reviewer activity is a simple `APPROVED` with no comments or concerns.

### 2c. Enrich each PR

For every unique PR collected from 2a and 2b (up to 50 total after deduplication — if more, keep the 50 most recently updated by `updatedAt` descending, warn the human, and list the dropped PR numbers so they know they were skipped), fetch enrichment:

```sh
gh pr view {number} --repo {owner}/{repo} \
  --json mergeable,mergeStateStatus,statusCheckRollup,reviews,reviewRequests,headRefName,baseRefName
```

Derive per PR:
- **Approvers**: unique logins from `reviews` where `state == "APPROVED"`, using the latest review per reviewer (ignore earlier reviews superseded by a later one from the same person).
- **Pending reviewers**: entries in `reviewRequests` who haven't responded yet.
- **CI status**: summarize `statusCheckRollup` → `passing`, `failing`, `pending`, or `none`.
- **Merge readiness**: map `mergeable` + `mergeStateStatus` → `ready`, `conflicts`, `blocked`, or `unknown`.
- **Unresponded comment count**: count of reviewer comments/reviews with no human reply (from Phase 2b analysis).
- **Reason for inclusion**: `approved` | `unresponded-comments` | `both`.
- **CHANGES_REQUESTED override**: If any reviewer's latest review state is `CHANGES_REQUESTED` (regardless of whether other reviewers have approved), override the default action to `ADDRESS` and set `Reason: both` if the PR was also in the approved set. Never default to `MERGE` for a PR with an active unresolved `CHANGES_REQUESTED`.

---

## Phase 3 — Build the Triage Board File

Write the triage board to:
```
/tmp/pr-action-board-{YYYYMMDD-HHMMSS}.md
```

(Include seconds to avoid collisions on re-invocations within the same minute.)

### File format

```markdown
# PR Action Board — {YYYY-MM-DD HH:MM:SS}

Scoped to: {scope description}
GitHub login: @{login}

---

## Summary Table

| PR | Title | Repo | Reason | Approvers | CI | Merge Ready | Unresponded | Updated |
|----|-------|------|--------|-----------|----|-----------  |-------------|---------|
| [#123](url) | Fix login redirect | embarkvet/foo | approved | @alice, @bob | passing | ready | 0 | 2h ago |
| [#118](url) | Add PostHog tracking | embarkvet/bar | unresponded-comments | — | failing | blocked | 3 | 1d ago |

**Total PRs:** N  
**Approved + ready to merge:** M  
**Blocked / need attention:** K

---

## PR Details & Actions

<!-- ═══════════════════════════════════════════════════════════ -->

### [#123] Fix login redirect — embarkvet/foo

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
<!-- MERGE  → merge this PR, then monitor CI with /resolve-ci-failures -->
<!-- ADDRESS → address unresolved comments with /address-pr-comments -->
<!-- SKIP   → do nothing this round -->

<!-- ═══════════════════════════════════════════════════════════ -->

### [#118] Add PostHog tracking — embarkvet/bar

**URL:** https://github.com/embarkvet/bar/pull/118  
**Branch:** `feature/posthog` → `main`  
**Reason:** unresponded-comments  
**Approvers:** none  
**Pending reviewers:** @carol  
**CI:** failing  
**Merge ready:** blocked  
**Unresponded comments:** 3  

#### Reviewer Activity

- @carol (2d ago, CHANGES_REQUESTED): "This will fire an event on every render — should be memoized. Also the API key is hardcoded, that needs to be an env var."
- @dave (1d ago, inline on `src/tracking.ts:42`): "Why not use the existing `useAnalytics` hook here instead?"
- @carol (12h ago, PR comment): "Any update on the memoization fix?"

### Action

```
ADDRESS
```

<!-- Set to one of: MERGE | ADDRESS | SKIP -->
```

Include the `#### Reviewer Activity` section only for PRs with unresponded comments — list each unresponded comment/review in chronological order, truncated to 200 chars. For approved PRs with no unresponded comments, write `*(none — approved cleanly)*`.

**Default action values:**
- Approved + merge-ready + CI passing + 0 unresponded: default to `MERGE`
- Has unresponded comments OR CI failing OR merge blocked: default to `ADDRESS`
- Draft PR: default to `SKIP` (note it is a draft)
- Everything else: leave as `TBD` and note what the human should consider

After writing the file, tell the human:

```
Triage board written to: /tmp/pr-action-board-{timestamp}.md

Open the file and set the Action for each PR:
  MERGE    → I will merge it and monitor CI (default for approved + clean)
  ADDRESS  → I will spin up an agent to address reviewer comments
  SKIP     → skip this round

Save the file and tell me "done" to execute.
```

**Do NOT proceed until the human explicitly says they are done annotating.**

---

## Phase 4 — Parse Annotations

Re-read the triage file. For each PR's `### Action` section, find the **first non-comment, non-blank line** inside the code block that matches one of:

- `/^MERGE$/i` → proceed with merge flow (Phase 5a)
- `/^ADDRESS$/i` → proceed with address flow (Phase 5b)
- `/^SKIP$/i` → log as skipped, no action taken
- `/^TBD$/i` → surface to the human for a decision (see below)
- Malformed or missing code block fences → treat as `TBD` and surface to the human; do not guess

**TBD handling:** Dispatch all PRs with clear MERGE/ADDRESS/SKIP annotations immediately. Surface TBD and unrecognized PRs to the human in parallel, and dispatch their agents as soon as the human resolves each one. Do not block the entire queue waiting for a single TBD.

Tally: `{M} MERGE, {A} ADDRESS, {S} SKIP, {T} TBD`

---

## Phase 5 — Execute Actions

### 5a. MERGE flow (one agent per PR, run in parallel)

For each MERGE-annotated PR, spin up a dedicated general-purpose agent named after a unique American outlaw from the 1800s–1900s (e.g. Butch Cassidy, Jesse James, Belle Starr, Black Bart, Dutch Schultz, Pretty Boy Floyd, Billy the Kid, Bonnie Parker, Sam Bass, Pearl Hart, John Wesley Hardin, Cole Younger, Doc Holliday, Calamity Jane, Tom Horn, Kid Curry, Sundance Kid, Cherokee Bill, Cattle Annie, Emmett Dalton). Names must be unique across all agents in this session — including across MERGE and ADDRESS agents. If the named list is exhausted, continue generating unique names from other historical American outlaws of the 1800s–1900s not already used.

Each merge agent receives a self-contained prompt with:
1. The PR URL and number, and repo `{owner}/{repo}`.
2. The merge strategy to use — ask the human once before dispatching if not already specified: `--squash` (default), `--merge`, or `--rebase`.
3. Instructions to:

   a. **Pre-merge check:** Run `gh pr view {number} --repo {owner}/{repo} --json mergeable,mergeStateStatus,statusCheckRollup,baseRefName` and verify:
      - `mergeable` is `"MERGEABLE"` and `mergeStateStatus` is `"CLEAN"`. If `mergeable` is `null` (GitHub is still computing), wait 10 seconds and re-poll up to 3 times. Only treat as a blocker if `mergeable` is explicitly `"CONFLICTING"` or `mergeStateStatus` is a blocking state after all retries.
      - CI is passing (`statusCheckRollup` has no failures).
      - Cache `baseRefName` — this is the target branch for post-merge CI monitoring.
      - If either check fails after retries, **do not merge**. Report the blocker back to the parent (the PR Action Board skill) — do not attempt to fix it silently.

   b. **Merge:**
      ```sh
      gh pr merge {number} --repo {owner}/{repo} --{strategy} --delete-branch
      ```
      For the `--auto` flag: check `gh repo view {owner}/{repo} --json branchProtectionRules`. If the field returns an empty array or an error (not all plan tiers expose it), attempt a direct merge without `--auto`. If the direct merge fails with an error indicating required status checks, retry with `--auto` and note this in the outcome `notes` field.

   c. **Post-merge CI watch:** After the merge, monitor CI on `{baseRefName}` (from the pre-merge check above — do NOT hardcode `main`) for up to 10 minutes:
      ```sh
      gh run list --branch {baseRefName} --repo {owner}/{repo} --limit 3 --json databaseId,status,conclusion,name,createdAt
      ```
      Poll every 60 seconds. If any run fails within the monitoring window, invoke `/resolve-ci-failures` on `{baseRefName}` of that repo. If CI has not reached a terminal state after 10 minutes, return `ci_outcome: timed_out` in the JSON result and note that the run was still in progress at timeout — do NOT invoke `/resolve-ci-failures` for a timed-out run; surface it to the human for manual follow-up instead.

   d. Return a JSON result:
      ```json
      {
        "pr": 123,
        "repo": "owner/repo",
        "status": "merged | blocked | error",
        "merge_sha": "abc123",
        "ci_outcome": "passing | failing | pending | skipped",
        "notes": "any relevant detail"
      }
      ```

Run all MERGE agents in parallel (single message, multiple tool calls).

### 5b. ADDRESS flow (one agent per PR, run sequentially — each requires human interaction)

For each ADDRESS-annotated PR, spawn a dedicated general-purpose agent (use remaining unique outlaw names). Run these **sequentially**, one at a time — each agent will need to present findings to the human and wait for input before proceeding.

Each address agent receives a self-contained prompt with:
1. The PR URL, number, repo `{owner}/{repo}`, and `headRefName` (the PR's source branch).
2. The unresponded reviewer activity captured in Phase 2 (list the comments verbatim so the agent does not have to re-fetch).
3. Instructions to locate the correct local clone of `{owner}/{repo}` (via `find ~ -name ".git" -maxdepth 5 -type d | xargs -I{} dirname {} | xargs -I{} sh -c 'cd {} && git remote get-url origin 2>/dev/null | grep -q "{repo}" && echo {}'` or similar), check it out to `{headRefName}` (`git checkout {headRefName} && git pull`), and then invoke `/address-pr-comments`. The `/address-pr-comments` skill operates on the *current branch* of the working directory — it will fail silently or target the wrong PR if the branch is not checked out first.
4. If no local clone is found, report back to the parent skill with `status: no_local_clone` and do not proceed — the human must check out the repo manually.
5. Instructions to invoke `/address-pr-comments` for this PR and return its findings **before making any code changes or committing anything**.
4. Explicit instruction: **Do NOT invoke `/build` or `/critique` until the parent skill (PR Action Board) presents the findings to the human and receives approval.**
5. The agent must return a structured summary of findings and proposed actions in this format:

   ```json
   {
     "pr": 118,
     "repo": "owner/repo",
     "proposed_changes": [
       {
         "comment_author": "@carol",
         "comment_summary": "Memoize the event call",
         "proposed_action": "Wrap in useMemo — see src/tracking.ts:42",
         "type": "code_change | discussion | ignore"
       }
     ],
     "discussion_items": [
       {
         "comment_author": "@dave",
         "question": "Why not use useAnalytics hook?",
         "draft_reply": "The useAnalytics hook doesn't support batched events yet — this is a deliberate short-term workaround."
       }
     ],
     "questions_for_human": [
       "Carol also asked about the hardcoded API key — do you want me to move it to env or is there a separate ticket for that?"
     ]
   }
   ```

**After each address agent returns findings:**

1. Present the findings to the human in a clear, structured format:
   - List proposed code changes with the comment that prompted them
   - List discussion items with the draft reply
   - Ask any `questions_for_human` explicitly and wait for answers
2. Wait for the human to respond and confirm which proposed changes to proceed with, which to skip, and how to answer discussion items.
3. Only after human approval: send a follow-up message to the agent instructing it to:
   - Implement the approved code changes
   - Post replies to discussion threads
   - Run `/build` to verify the changes compile and tests pass
   - Run `/critique` to commit, push, and open/update the PR
4. Wait for the agent to complete before moving to the next ADDRESS PR.

If the human answers questions for a PR, pass the answers into the follow-up message verbatim.

---

## Phase 6 — Update Triage File and Report

Phase 6 runs only after ALL agents — both MERGE and ADDRESS — have returned their results to the parent skill. The parent skill (PR Action Board) performs all writes to the triage file in a single sequential pass. Sub-agents do NOT write to the triage file themselves; they only return structured results.

1. Re-read the triage file.
2. For each PR, append an `#### Outcome` subsection under its `### Action` block:

   ```markdown
   #### Outcome

   **Status:** merged | addressed | skipped | blocked  
   **Completed:** {timestamp}  
   **Details:** {one-sentence summary — e.g. "Merged via squash. CI passed on main." or "3 comments addressed, 1 discussion replied to, PR pushed and critique passed."}  
   **CI post-merge:** passing | failing (see /resolve-ci-failures output below) | n/a  
   ```

3. Update the Summary Table at the top — add an `Outcome` column with the final status per PR.

4. Report to the human in the conversation:

   ```
   PR Action Board — complete.

   ✓  MERGE  [#123] embarkvet/foo — merged. CI passing.
   ✓  ADDRESS [#118] embarkvet/bar — 3 comments addressed, pushed, critique passed.
   —  SKIP   [#101] embarkvet/baz — skipped per your instruction.
   ✗  MERGE  [#109] embarkvet/qux — blocked: merge conflicts. Needs manual rebase.

   Updated triage file: /tmp/pr-action-board-{timestamp}.md
   ```

   For any failures or outstanding blockers, surface them explicitly and suggest next steps.

---

## Guardrails

- **No merges or commits without annotation.** This skill takes no destructive action until the human has annotated the triage file and said "done". The pre-merge check in Phase 5a is a second safety gate — it will refuse to merge if the PR is not actually mergeable at execution time.
- **Human-in-the-loop for ADDRESS.** Each ADDRESS PR must get explicit human approval on proposed changes before any code is modified or committed. The agent presents findings first; the human decides what to do.
- **Do not post the triage file externally.** The `/tmp` file is local. Do not upload it to Slack, Jira, Confluence, or anywhere else.
- **Sequential ADDRESS, parallel MERGE.** MERGE agents are fire-and-report. ADDRESS agents require human interaction at each step — do not try to run them in parallel.
- **Identity disclosure on any GitHub posts.** Every comment, reply, notification, or re-review-request message posted to GitHub — including replies to review threads, PR-level acknowledgment comments, and "feedback has been addressed" notifications — must open with `_Posted by Farty Bobo on behalf of @{gh_login}._` — this is non-negotiable per CLAUDE.md.
- **No summary comments posted to GitHub PRs.** PR-level summary comments are never posted. All summaries stay in the triage file and the conversation. Only inline code review comments and targeted reply comments to specific review threads are permitted on GitHub.
- **One round per invocation.** New PRs or new comments that arrive after Phase 2 are not included. Re-invoke the skill to pick them up.
- **Outlaw names must be unique per session.** Do not reuse an agent name within a single run — even if the previous agent with that name has completed.
