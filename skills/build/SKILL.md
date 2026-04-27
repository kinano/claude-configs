---
name: build
description: Used to build and execute an approved implementation plan by spinning up agents
disable-model-invocation: false
---

# Best Practices for implementing code changes and pushing them using git

1. You will be provided with specific instructions to implement code changes to achieve specific outcomes.
2. Pull the base branch for the affected repos and create new branch using the following format `eesam/{jira-ticket-id}-{short-description-of-feature}`. `short-description-of-feature` should not exceed 40 characters. If no Jira ticket ID is available, prompt the human for one or use the format `eesam/{short-description-of-feature}`.
3. Use git worktrees when creating a new branch so that multiple agents or sessions can work on separate branches simultaneously without interfering with each other. Place worktrees in a sibling directory of the repo root using the convention `../{repo-name}-worktrees/{branch-name}`. Create one worktree per branch, not per agent — agents on the same branch share a single worktree and must coordinate. If the branch already exists, reuse its worktree if present or create one. After the branch is merged or abandoned, clean up with `git worktree remove`.
4. Ask the human to choose from the following options:

- spin up an agent
- spin up a team of agents to implement the provided plan

5. Create a todo list for each agent. Kick off the execution.
6. Once the agent(s) are done, assess whether the changes warrant a modularity review:
   - If the diff touches **3+ modules/packages** or exceeds **500 changed lines**, run `/modularity:review` against the affected repos before proceeding to critique. Present coupling findings to the human and address any issues before committing.
   - Otherwise, skip the modularity review.
7. Run `/critique` with the implementation plan and all impacted repos to ensure changes are reviewed, committed, and pushed.
8. Do not leave code comments. The code should be simple and self-explanatory. Comments should be used sparingly.
