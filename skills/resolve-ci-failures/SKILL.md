---
name: resolve-ci-failures
description: Used to investigate and fix errors recorded by ci/cd for the current branch/PR
disable-model-invocation: false
---

# Investigates and resolves CI/CD failures for the current branch or PR

1. Identify the current branch and its associated PR. If no PR exists, work directly from the branch name.
2. Fetch CI/CD run results using `gh run list` and `gh run view` to find failing jobs on the current branch. If a PR exists, also check `gh pr checks` for a consolidated view.
3. For each failing job, fetch the full logs with `gh run view --log-failed` to extract the root cause. Categorize failures by type:
   - **Lint / formatting errors**: fixable automatically.
   - **Type errors**: fixable automatically.
   - **Test failures**: investigate whether the failure is in the test itself or in the code under test. Fixing a flawed test assertion is higher risk — flag it for human approval before modifying tests.
   - **Build errors**: investigate missing dependencies, config issues, or breaking changes.
   - **Infrastructure / environment errors** (flaky network, missing secrets, etc.): flag for human — do not attempt to fix.
4. Present a summary to the human: what failed, why, and your proposed fix for each. Explicitly wait for human approval before proceeding. Do not spin up agents until the human has confirmed the plan.
5. Spin up an agent or team of agents (as appropriate for scope) to implement the approved fixes. Give each agent a focused task with a clear success criterion. No need to create a new branch or worktree — fixes go on the current branch.
6. Once fixes are implemented, run the full project checks locally to verify. Note: per-file lint and type checks run automatically via hooks on every edit — focus this step on full-project commands (e.g. full typecheck, test suite) that hooks defer. Discover the correct commands from `AGENTS.md`, `package.json`, or `pyproject.toml` in the affected repo — do not guess.
7. Run `/critique` to review, commit, and push the fixes.
8. Monitor the new CI run with `gh run watch` until it completes. If new failures appear, repeat from step 3.
