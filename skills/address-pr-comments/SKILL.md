---
name: address-pr-comments
description: Used to read PR comments on github and act on them
disable-model-invocation: false
---

# Reads and addresses comments from humans and other agents on github

1. Fetch the open PR for the current branch. If no PR exists, notify the human and stop. If multiple PRs exist, ask the human to select one.
2. Fetch all unresolved comments. Distinguish between human comments and bot/automated comments — focus on human comments first.
3. For each comment, assess its type:
   - **Code change needed** (nit, low, medium, high severity): add to the implementation plan.
   - **Discussion needed** (questions, architectural debates): flag for human review rather than acting on them.
4. Present the plan to the human: show what will be changed, what needs discussion, and what will be ignored. Let the human decide (address all, address a subset, or ignore).
5. Take actions based on human input. For discussion-type comments, post a reply in the PR thread rather than making a code change.
6. Run `/critique` to ensure changes are reviewed, committed, and pushed.
7. Attempt to resolve addressed PR comment threads. The `gh` CLI still has no native resolve command, so use the helper scripts in this skill's folder:

   ```sh
   # List unresolved threads (tab-separated: id, path:line, author, snippet)
   ./skills/address-pr-comments/list-unresolved-threads.sh <pr-number|pr-url> [--repo OWNER/REPO]

   # Resolve specific threads by ID
   ./skills/address-pr-comments/resolve-threads.sh <thread-id> [<thread-id>...]

   # Or resolve every unresolved thread on a PR
   ./skills/address-pr-comments/resolve-threads.sh --all <pr-number|pr-url> [--repo OWNER/REPO]
   ```

   Paths above are relative to the repo root; invoke with absolute paths if running from elsewhere. Only resolve threads whose feedback you actually addressed. Skip discussion-type threads that are still waiting on a human reply. Resolution requires triage/write permission on the repo — report any failures to the human.
8. Re-request review from the original commenters if they had requested changes or notify them via a PR comment that their feedback has been addressed.
9. After pushing, check CI status using `gh pr checks`. If any checks are failing, invoke `/resolve-ci-failures` to investigate and fix them.
10. This skill covers one round of comments. If new comments arrive after this round is complete, the human should invoke this skill again.
