---
name: comment-jira
description: Post or update a comment on a Jira ticket using the Atlassian MCP server. Accepts a ticket ID (e.g. PROJ-123), a Jira ticket URL, or a direct link to an existing comment. Works for both human-authored comments and agent-generated summaries.
---

# Comment on Jira Skill

## Steps

### 1. Resolve the Target

Accept the target from one of the following:
- **Ticket ID** — e.g. `PROJ-123`
- **Ticket URL** — e.g. `https://yourorg.atlassian.net/browse/PROJ-123`
- **Comment link** — e.g. `https://yourorg.atlassian.net/browse/PROJ-123?focusedCommentId=456789` — extract the ticket ID and comment ID from the URL

If no target is provided, ask the human for one before proceeding.

If the Atlassian MCP connector is not configured, prompt the human to set it up and stop.

### 2. Determine the Action

Ask (or infer from context) whether to:
- **Add a new comment** — post fresh content to the ticket
- **Update an existing comment** — edit a specific comment by ID (required when a comment link was provided, or when the caller explicitly wants to update)
- **Reply to a comment** — if the Atlassian API supports threaded replies for this project type; otherwise fall back to adding a new top-level comment that references the original

If the action is ambiguous, ask the human to clarify.

### 3. Compose the Comment

Accept the comment body from one of:
- **Inline text provided by the caller** (human message or agent output passed to this skill)
- **A file path** — read the file content and use it as the comment body
- **Interactive input** — if no content was provided, ask the human to type or paste the comment

**Identity footer:** Always append the following footer to every comment posted by this skill, separated from the body by a blank line:

```
---
_Posted by {your identity}_
```

If the comment is an update to an existing comment with this footer already present, replace the existing footer rather than appending a second one.

Format the comment in Atlassian Document Format (ADF) if required by the API, or plain markdown if the connector handles conversion. Keep the comment concise — do not pad with filler.

### 4. Preview and Confirm

Show the human the final comment body and the target ticket ID before posting. Ask:
> "Post this comment to `{ticket-id}`? (yes / edit / cancel)"

Do not post without explicit confirmation. If the human selects "edit", accept revised content and re-show the preview.

### 5. Post the Comment

Use the Atlassian MCP connector. It handles all Jira API communication — use its "Add comment" tool for new comments and its update/edit comment tool for existing ones. Do not make raw REST calls.

On success, confirm to the caller: "Comment posted to `{ticket-id}`: `{comment-url}`"
On failure, surface the full error and ask the human how to proceed — do not retry silently.
