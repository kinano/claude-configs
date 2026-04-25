---
name: report-approved-prs
description: Report the user's own open pull requests that have already been approved by at least one reviewer. Use when the user asks "what PRs of mine are approved?", "what's ready to merge?", "which of my PRs got an approval?", or similar. Surfaces PRs that are waiting on the author to merge, address nits, or rebase.
---

# Report Approved PRs Skill

## 1. Determine the search scope

Pick the scope based on the caller's request and the current working directory — ask only if ambiguous:

- **Current repo** *(default when invoked inside a git repo with a GitHub remote)*: scope to the repo resolved from `origin`.
- **An org or owner**: if the caller names one (e.g. "my approved PRs in embarkvet"), scope to that owner.
- **Everywhere**: if the caller explicitly asks across all repos, or if invoked outside a git repo with no scope given.

Resolve the current user via `gh api user --jq .login` once and cache it for the rest of the run — do not assume a login from git config or memory.

## 2. Query GitHub

Use `gh search prs` with the cached login. Always request machine-readable JSON — do not parse human output.

```sh
# Base query — adjust scope with --repo OWNER/REPO or --owner OWNER.
gh search prs \
  --author="@me" \
  --state=open \
  --review=approved \
  --json number,title,url,repository,author,createdAt,updatedAt,isDraft,labels \
  --limit 100
```

Notes:

- `--review=approved` surfaces PRs whose current review decision is APPROVED. It does **not** include PRs with `CHANGES_REQUESTED` still outstanding, which is the behavior we want.
- Do NOT add `reviewDecision` to the `--json` list above — `gh search prs` rejects it ("Unknown JSON field: reviewDecision"). The `--review=approved` filter already enforces the approval state, and the per-PR enrichment in step 3 pulls reviewer detail from `gh pr view` instead.
- Draft PRs can technically carry an approval. Exclude `isDraft: true` entries from the default report; mention them only if the caller asked to include drafts.
- If the scope is "current repo", add `--repo {owner}/{name}` resolved from `git remote get-url origin`.
- If the scope is an owner/org, add `--owner {name}`.
- If `gh` is not authenticated (exit code 4 / "gh auth status" fails), stop and tell the caller to run `gh auth login`. Do not retry silently.

## 3. Enrich each PR (optional, only if < 25 results)

For up to 25 PRs, fetch additional context that makes the report actionable. Skip this step if the result set is larger — the caller can re-scope.

For each PR, fetch:

```sh
gh pr view {number} --repo {owner}/{name} \
  --json mergeable,mergeStateStatus,statusCheckRollup,reviews,reviewRequests
```

Derive these fields per PR:

- **Approvers**: unique logins from `reviews` with `state == "APPROVED"` (keep the latest review per reviewer only — ignore earlier APPROVED reviews superseded by a later review from the same person).
- **Outstanding requests**: any entry in `reviewRequests` — these are reviewers who haven't responded yet.
- **CI status**: summarize `statusCheckRollup` to one of `passing`, `failing`, `pending`, `none`.
- **Mergeable**: map `mergeable` + `mergeStateStatus` to `ready`, `conflicts`, `blocked`, or `unknown`.

## 4. Format the report

Render a compact table. Sort by `updatedAt` descending (most recently active first).

```
Approved PRs opened by @{login} — scope: {scope}

| PR | Title | Repo | Approvers | CI | Mergeable | Updated |
|----|-------|------|-----------|----|-----------| --------|
| #123 | Fix login redirect | embarkvet/foo | @alice, @bob | passing | ready | 2h ago |
| #118 | Add PostHog tracking | embarkvet/bar | @carol | failing | blocked | 1d ago |
```

Then append a short human-readable summary:

- Total approved PRs: `N`
- Ready to merge (approved + CI passing + mergeable): `M`
- Blocked despite approval (CI failing, conflicts, or additional reviewers still requested): `K`
- Any PRs with outstanding review requests beyond the existing approvers — list them explicitly so the caller knows someone else is still expected to look.

If there are zero results, say so plainly. Do not pad the report.

## 5. Offer a next action

After the report, offer concrete follow-ups based on what was found — do not take any of these actions without explicit confirmation:

- If one or more PRs are `ready` to merge: offer to merge them (`gh pr merge --squash --auto` or whatever the caller's preferred strategy is — ask).
- If any PR is `blocked` by CI: offer to invoke `/resolve-ci-failures` on that PR's branch.
- If any PR has unresolved review comments: offer to invoke `/address-pr-comments` on that PR.
- If the caller just wants the report and no action: stop cleanly.

## 6. Guardrails

- This skill is read-only by default. It must not merge, close, rebase, or comment on any PR without explicit caller confirmation.
- Never post a summary comment on the PRs being reported. The report lives in the conversation, not on GitHub.
- Do not exfiltrate the report to Slack, Jira, Confluence, or any other external system unless the caller explicitly directs it. If directed, use the dedicated `post-on-slack` / `comment-jira` / `comment-confluence` skill so the identity disclosure (as defined in CLAUDE.md) is applied.
