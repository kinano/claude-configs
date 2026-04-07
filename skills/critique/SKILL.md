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
6. Commit and push. If the push fails due to pre-push hook errors, prompt the human for approval before using `git push --no-verify`.
