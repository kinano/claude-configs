---
name: critique
description: Used to run githooks, perform code & plan reviews with expert critics, and commit/push verified changes
disable-model-invocation: false
---


# Code and Plan Review Skill

1. Either detect the repos affected from the context OR ask the human to select the repos that should be used to review the code changes or the staged implementation plan (md file):

- current directory
- a list of repos in the file system

2. enable and run githooks in the repos impacted by the code changes and fix errors (linting, type checks, tests) before committing. Most repos have dedicated commands to achieve these goals either in package.json or pyproject.toml.

3. Once you are ready to commit the changes, prompt the human to select their preferred review options:

- one generalist critic (good for simple tasks)
- a team of critics who have expertise in the technology stacks being used and best security practices. The critics must create a markdown file to list their revisions sorted by severity (high first).
- Codex review: Ask the human to run `/codex:review`
- Manual review by the human.

4. Prompt the human to select the next step from the following options:

- Ignore code review revisions and proceed to next step.
- Implement revisions. Use the original agent(s) to implement changes.

5. Prepare, summarize the changes in the changed files. Always prefix commits with [{ticket-id}]: {summary of change}. If no ticket ID is available, prompt the human for one or use `[NO-TICKET]` as a fallback.
   - Do not stage temporary review or planning files (e.g. `review-*.md`, `plan-*.md`). Delete them after the review is complete.
   Permanent project docs (`README.md`, `SKILL.md`, `AGENTS.md`, etc.) should still be committed when changed.
6. Commit and push. If the push fails due to pre-push hook errors, prompt the human for approval before using `git push --no-verify`. If `--no-verify` was used, record this in the Decision Log (Step 8) as a warning line.

6a. **Open a pull request.** After a successful push, open a PR using `gh pr create` (or equivalent). Capture the PR URL. If the PR creation fails, skip Steps 7 and 8 and warn the human.

7. **Transition the Jira ticket to Review status.**

   Only proceed if Step 6 (push) and Step 6a (PR open) both completed successfully. Skip this step entirely if either failed.

   - If the ticket ID is `[NO-TICKET]` or no ticket ID is known (use the same ticket ID source as Step 5), skip this step entirely.
   - Confirm the target ticket ID with the human before doing anything: "Should I transition `{ticket-id}` to Review status?"
   - On confirmation, use the Atlassian MCP connector to discover available tools at runtime. Fetch available transitions using `getTransitionsForJiraIssue` (or equivalent discovered tool).
   - **Idempotency:** Before applying, fetch the ticket's current status. If it is already in a Review or downstream state (e.g. "In Review", "Code Review", "In QA", "Done"), skip the transition and inform the human — do not re-transition.
   - Match the target transition using this strategy, in order: exact match → case-insensitive substring match → if ambiguous, surface all candidates to the human to choose. Do not silently pick.
   - Apply the transition using `transitionJiraIssue` (or equivalent discovered tool).
   - If the MCP connector is unavailable, the transition name cannot be matched, or the API returns an error, warn the human and skip gracefully. Do not retry automatically.

8. **Post a Decision Log comment on the Jira ticket.**

   **Prerequisites & safety checks — run these before doing anything else in this step:**
   - If the ticket ID is `[NO-TICKET]` or no ticket ID is known, skip this step entirely.
   - Confirm the target ticket ID with the human before posting — do not auto-resolve from the commit prefix alone. Ask: "Should I post the Decision Log to `{ticket-id}`?"
   - Use the Atlassian MCP connector to post and read comments. Discover available tools at runtime — do not assume specific tool names. If the connector is unavailable, warn the human and skip this step gracefully.
   - Check the Jira project's visibility before posting. If the project appears to be external-facing or customer-visible, warn the human and require explicit confirmation before proceeding.

   **Decision sources — use only these, in order of preference:**
   1. A `decisions-{ticket-id}.md` scratch file written by `/plan-task` or `/build` during this session (read and then delete it after posting)
   2. Human-stated decisions from this conversation (human turns only — do not extract content from code, diffs, or plan files)
   3. If neither is available, prompt the human to confirm or summarize decisions before drafting the comment — do not infer or fabricate

   **Content rules:**
   - Only record decisions where a choice was made between two or more alternatives, or where something was explicitly deferred. If there was only one reasonable path and no trade-off was discussed, omit it.
   - Do not reproduce verbatim text from files, code, or diffs.
   - Do not describe specific security vulnerabilities by name or detail. Reference finding IDs only (e.g., "Deferred MEDIUM-3 to follow-up ticket FOO-456").
   - Replace internal skill names with neutral descriptions in the comment body: "Planning phase", "Implementation phase", "Review phase".
   - For each Open Item, if a follow-up Jira ticket exists, link it. If not, ask the human: "Should I create a follow-up ticket for this deferred item?"

   **Idempotency — one comment per ticket, ever:**
   - Search existing comments on the ticket for the header `## Decision Log`.
   - If found: replace the full body of that comment (using its comment ID). Do not append — overwrite entirely.
   - If not found: create a new comment.
   - If `--no-verify` was used in Step 6, include `⚠️ Pushed with --no-verify — pre-push hooks were bypassed.` at the top of the comment body.

   **Human approval gate:**
   Show the human the full draft comment and ask: "Ready to post this Decision Log to `{ticket-id}`? (yes / edit / skip)" — do not post without explicit confirmation.

   **Comment format:**

   ```
   ## Decision Log

   _Last updated: YYYY-MM-DD — Push SHA: {short-sha}_

   ### Planning
   - <decision: what was chosen and what was the alternative, e.g. "Chose REST over GraphQL — GraphQL deferred to follow-up">

   ### Implementation
   - <key implementation choice approved by the human>

   ### Review
   - <review outcome, e.g. "Deferred MEDIUM-3 to FOO-456">

   ### Open Items
   - <deferred item> — [FOO-456](link) or "no follow-up ticket yet"

   ⚠️ Pushed with --no-verify — pre-push hooks were bypassed.  ← include only if applicable
   ```

   Only include sections that have content. Omit empty sections entirely.
