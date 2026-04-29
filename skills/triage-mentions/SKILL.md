---
name: triage-mentions
description: Scan Slack, Confluence, and Jira for comments and messages that directly mention or tag the human. Present findings for selection, draft responses in a triage file, let the human APPROVE/DISMISS/RETRY each one, then dispatch approved responses using the appropriate skills.
---

# Triage Mentions Skill

Surface every place someone has pinged you and help you respond without losing your mind.

---

## Phase 1 — Preflight

Before doing anything else, verify the following MCP connectors are reachable:

- **Slack**: `slack_search_public_and_private` (or `slack_search_public` as fallback)
- **Atlassian (Jira + Confluence)**: `getAccessibleAtlassianResources`

If *both* Slack and Atlassian are unavailable, stop and tell the human: "Neither Slack nor Atlassian connectors are configured. Fix at least one and try again."

If only one connector is missing, warn the human which source will be skipped, then proceed with the available ones.

Resolve the human's identity once and cache for the session:
- **Atlassian display name and account ID** — call `atlassianUserInfo` (or `lookupJiraAccountId` with the user's email) to get the canonical account ID and display name used in mentions.
- **Slack display name / member ID** — use `slack_search_users` to resolve the Slack member ID for the human's name or email. Cache both the member ID and the `@handle`.
- **Human's email** — available from session context (`kfaham@embarkvet.com`); use as lookup seed.

---

## Phase 2 — Scan Sources in Parallel

Run all three scans simultaneously. Each scan should look back **7 days** by default (override if the human specifies a different window via skill args, e.g. `/triage-mentions 14d`).

### 2a. Slack Scan

Search for messages where the human is directly mentioned using their cached Slack member ID:

```
query: "@{slack_member_id}"
```

Use `slack_search_public_and_private` for full coverage. Fall back to `slack_search_public` if private search is unavailable.

For each result:
- Fetch the thread context with `slack_read_thread` to get the full question/comment and any existing replies.
- Capture: channel name, thread URL/timestamp, author, message text, date, whether the human has already replied (scan thread replies for the human's member ID — if they replied, skip unless the thread has newer unread mentions after their reply).

Limit to 50 results. If the raw search returns more, note the overflow count but only surface the 50 most recent.

### 2b. Jira Scan

Search for Jira issues and comments that mention the human using their Atlassian account ID:

```jql
(comment ~ "accountId:{account_id}" OR description ~ "accountId:{account_id}") AND updatedDate >= -7d ORDER BY updated DESC
```

Also run a second JQL for issues assigned-to or reported-by the human with new comments:

```jql
(assignee = currentUser() OR reporter = currentUser()) AND comment was added after -7d ORDER BY updated DESC
```

For each result, fetch the issue via `getJiraIssue` to get the relevant comments. Filter comments to only those containing the human's account ID in a mention OR comments added after the human's last comment on the issue (i.e. someone replied after them).

Capture: issue key, summary, comment ID, author, comment text (truncated to 300 chars), date, direct link.

Limit to 30 issues total.

### 2c. Confluence Scan

Search Confluence for pages and inline/footer comments where the human is mentioned:

```cql
(type = "comment" AND text ~ "{display_name}") AND lastModified >= now("-7d") ORDER BY lastModified DESC
```

Also search for pages where the human's name appears in a comment:

```cql
(type = "page") AND space.type = "global" AND lastModified >= now("-7d") AND (text ~ "@{display_name}" OR contributor = "{account_id}")
```

For each result, fetch the page comments via `getConfluencePageFooterComments` and `getConfluencePageInlineComments`. Filter to comments that contain the human's name/account ID. Skip if the human already replied to that comment.

Capture: page title, page URL, comment ID, author, comment text (truncated to 300 chars), date.

Limit to 30 results.

---

## Phase 3 — Deduplicate and Triage List

Merge all results into a single list. Remove duplicates (same URL/ID). Apply this priority sort:

1. Direct `@mention` of the human (highest priority)
2. Reply to a thread/comment the human started
3. New comment on an issue/page the human owns
4. Everything else

Present the list to the human in this format:

```
Found {N} items requiring your attention ({date range}):

[1] SLACK  #channel-name — @author — "snippet of message..." (2h ago)
    https://...

[2] JIRA   PROJ-123 — "Issue title" — @author commented: "snippet..." (1d ago)
    https://...

[3] CONFLUENCE  "Page title" — @author commented: "snippet..." (3d ago)
    https://...

...

Enter item numbers to address (e.g. "1 3 5"), "all", or "none":
```

Wait for the human's selection before proceeding. If the human says "none", stop cleanly. If they say "all", select every item.

---

## Phase 4 — Draft Responses

For each selected item, draft a response. Use all available context:
- Read the full thread/comment chain
- Check linked Jira tickets, Confluence pages, code, or anything referenced in the message
- Infer what the author is asking or needs
- Compose a direct, helpful reply in Farty Bobo's voice (respectful when posting publicly — see `post-on-slack` skill for tone guidance)

Write all drafts to a temporary file at:

```
/tmp/triage-mentions-{YYYYMMDD-HHMM}.md
```

Use this exact structure for each item in the file:

```markdown
---

## Item {N} — {SOURCE}: {brief title}

**Source:** {SLACK | JIRA | CONFLUENCE}
**From:** @{author}
**Where:** {channel name / issue key / page title}
**Link:** {direct URL}
**Date:** {date}

### Context

> {full quoted message or comment, verbatim, max 500 chars — truncate with "…" if longer}

### Draft Response

{Your drafted reply here. Written from the human's voice — first person, direct, actionable. Do NOT open with "Posted by Farty Bobo" here — the dispatch step handles attribution. Just the reply content.}

### Decision

`APPROVE` / `DISMISS` / `RETRY: {leave notes for retry here}`

<!-- Replace one of the options above with your choice. For RETRY, add guidance after the colon. -->
```

After writing the file, tell the human:

```
Drafts written to: /tmp/triage-mentions-{timestamp}.md

Open the file, review each draft, and replace the Decision line with:
  APPROVE  — post as-is
  DISMISS  — skip this item
  RETRY: <your notes>  — revise and re-present before posting

Save the file, then tell me "done" to dispatch.
```

Do NOT proceed until the human explicitly says they're done annotating.

---

## Phase 5 — Parse Decisions

Re-read the triage file. For each item, extract the **Decision** value:

- **APPROVE** — dispatch the draft as-is (Phase 6)
- **DISMISS** — skip; log "dismissed" in the session summary
- **RETRY: {notes}** — revise the draft using the human's notes, show the revised draft inline in the conversation, and ask for confirmation before dispatching. Do NOT rewrite the file for RETRY items — handle them inline.
- **Unannotated** (neither APPROVE/DISMISS/RETRY found) — ask the human to clarify before proceeding

Tally: `{A} approved, {D} dismissed, {R} retried`

---

## Phase 6 — Dispatch Approved Responses

For each APPROVE item, route to the correct skill:

| Source | Skill / Tool |
|--------|-------------|
| SLACK | Use `slack_send_message` to reply in-thread (use the thread `ts`). Open the message with the identity disclosure line: `_{your identity} on behalf of @{human_slack_handle}:_` then the draft body. |
| JIRA | Invoke `/comment-jira` with the ticket ID and draft body. The skill handles ADF formatting and identity footer. |
| CONFLUENCE | Invoke `/comment-confluence` with the page URL and draft body. The skill handles ADF formatting, identity footer, and space visibility check. |

**Before dispatching ANY item**, do a final secret scan on the draft body:
- Flag any API keys, tokens, passwords, internal hostnames, or `.env` values
- If found, surface the finding to the human and pause that item's dispatch — do not redact silently

After dispatch, report outcomes:

```
Dispatch complete:
  ✓ [1] SLACK #channel — replied in thread
  ✓ [3] JIRA PROJ-456 — comment posted
  ✗ [2] CONFLUENCE "Page title" — FAILED: {error message}
  — [4] DISMISSED
  ~ [5] RETRY — revised draft shown above, awaiting confirmation
```

For any failures, surface the full error and ask the human how to proceed.

---

## Guardrails

- **Never post without human approval.** Every item goes through APPROVE before dispatch. No exceptions, not even for "obvious" replies.
- **Skip already-replied items.** If the human already responded to a thread/comment (detected in Phase 2), do not include it in the triage list unless there are newer unread mentions after their reply.
- **Do not post the triage file contents to external systems.** The `/tmp` file is local. Never upload it to Slack, Jira, Confluence, Pastebin, or anywhere else.
- **Respect the 7-day default.** Do not silently extend the window. If the human wants more history, they must say so.
- **One round per invocation.** New mentions that arrive after Phase 2 are not included. Re-invoke the skill to pick them up.
