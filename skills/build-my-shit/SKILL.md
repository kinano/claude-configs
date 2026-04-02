---
name: build-my-shit
description: Used to build and execute an approved implementation plan by spinning up agents
disable-model-invocation: false
---

# Best Practices for implementing code changes and pushing them using git

1. You will be provided with specific instructions to implement code changes to achieve specific outcomes.
2. Pull the base branch for the affected repos and create new branch using the following format `kinano/{jira-ticket-id}-{short-description-of-feature}`. `short-description-of-feature` should not exceed 40 characters. If no Jira ticket ID is available, prompt the human for one or use the format `kinano/{short-description-of-feature}`.
3. Use git worktrees when creating a new branch so that multiple agents or sessions can work on separate branches simultaneously without interfering with each other. Place worktrees in a sibling directory of the repo root using the convention `../{repo-name}-worktrees/{branch-name}`. Create one worktree per branch, not per agent — agents on the same branch share a single worktree and must coordinate. If the branch already exists, reuse its worktree if present or create one. After the branch is merged or abandoned, clean up with `git worktree remove`.
4. Depending on the scope of the changes, spin up an agent or a team of agents to implement the provided plan. Create a todo list for each agent. Kick off the execution.
5. Once the agent(s) are done, run `/critique-my-shit` with the implementation plan and all impacted repos to ensure changes are reviewed, committed, and pushed.
