---
name: delete-dead-worktrees
description: >
  Delete dead git worktrees. A worktree is dead if it has no uncommitted changes, OR if its
  branch was pushed to origin and that branch has since been deleted from origin (e.g. after a
  merged/closed PR). Trigger when the user says things like "clean up worktrees", "delete dead
  worktrees", "prune old worktrees", "remove stale worktrees", or "worktree cleanup".
---

# Cleanup Dead Worktrees

A dead worktree is one that is safe to delete because all meaningful work is either gone or
already preserved in the remote. There are exactly two conditions that make a worktree dead:

1. **No changes** — the worktree has no uncommitted changes (staged or unstaged) AND no commits
   that haven't been pushed somewhere already.
2. **Branch deleted from origin** — the worktree's branch was pushed to origin at some point,
   but the remote branch no longer exists (i.e., the PR was merged or the branch was deleted).

The main worktree (the one at the repo root) is **never** a candidate for deletion.

---

## Steps

### 1. Fetch and prune remote tracking refs

Run this in the repo root (wherever the user is working):

```bash
git fetch --prune
```

This removes stale remote-tracking refs (e.g. `origin/feature-x` that no longer exist on the
remote). Without this step, condition 2 cannot be evaluated correctly.

### 2. List all worktrees

```bash
git worktree list --porcelain
```

Parse the output to get each worktree's:
- `worktree` — absolute path to the worktree directory
- `branch` — the branch checked out in that worktree (e.g. `refs/heads/feature-x`)
- `HEAD` — current commit SHA

Skip the **first** entry — that is always the main worktree.

### 3. Evaluate each worktree

For every non-main worktree, run the checks below. A worktree is dead if **either** condition is
true.

#### Condition 1 — No changes

First, check the working tree:

```bash
git -C <worktree-path> status --porcelain
```

If the output is **not** empty, the worktree has uncommitted changes — stop here and do NOT mark
it dead under this condition.

If the working tree is clean, determine whether unpushed commits exist. The approach depends on
whether the branch has an upstream configured:

**Case A — upstream is configured:**

```bash
git -C <worktree-path> config --get branch.<branch-name>.merge
```

If this returns a value, an upstream exists. Check for unpushed commits:

```bash
git -C <worktree-path> log @{u}..HEAD --oneline
```

If this returns nothing, there are no unpushed commits. Mark as dead under condition 1.

**Case B — no upstream configured:**

Find the default branch reference. Try these in order until one succeeds:

```bash
# Option 1: use origin/HEAD if it resolves
git -C <worktree-path> rev-parse --verify refs/remotes/origin/HEAD 2>/dev/null
# If resolved, get the branch name:
git -C <worktree-path> symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||'

# Option 2: check for origin/main
git -C <worktree-path> rev-parse --verify refs/remotes/origin/main 2>/dev/null

# Option 3: check for origin/master
git -C <worktree-path> rev-parse --verify refs/remotes/origin/master 2>/dev/null
```

Use the first one that resolves as `DEFAULT_REF`. If none resolves, skip this worktree — cannot
safely evaluate it.

Now check for commits ahead of the default:

```bash
git -C <worktree-path> log ${DEFAULT_REF}..HEAD --oneline
```

If there are **any** commits ahead of the default branch, skip this worktree — it has unshared
work. Do NOT mark it dead.

If the output is empty (no commits ahead of default), mark as dead under condition 1.

#### Condition 2 — Branch pushed then deleted from origin

After `git fetch --prune` (Step 1), any remote-tracking ref that no longer exists on the remote
has already been removed locally. So no second network call is needed — check the local ref store.

First, confirm the branch was configured to track `origin`:

```bash
git -C <worktree-path> config --get branch.<branch-name>.remote
```

If this returns `origin`, the branch was tracking a remote at some point. Now check if the
remote-tracking ref still exists locally:

```bash
git -C <worktree-path> rev-parse --verify refs/remotes/origin/<branch-name> 2>/dev/null
```

If this returns **empty output** (non-zero exit), the remote branch is gone. Mark as dead under
condition 2.

Also handle the case where the worktree is in **detached HEAD** state — `git worktree list
--porcelain` emits `detached` instead of a `branch:` line. For detached HEAD worktrees, skip
condition 2 entirely. Apply condition 1 only (check working tree cleanliness and commits ahead of
default branch).

### 4. Present findings to the user

Display a table like this:

```
Dead worktrees found:

PATH                          BRANCH              REASON
/path/to/worktree-a           feature/foo         No changes, no upstream commits
/path/to/worktree-b           fix/bar             Branch deleted from origin
/path/to/worktree-c           chore/baz           Both conditions met
```

If no dead worktrees are found, tell the user and stop.

### 5. Ask for confirmation

**Do not delete anything without explicit user confirmation.**

Ask: "Shall I delete all of these, or do you want to pick specific ones?"

Wait for the user's answer. Never auto-delete.

### 6. Delete confirmed worktrees

For each confirmed worktree, run:

```bash
git worktree remove <worktree-path>
```

If the worktree has uncommitted changes that somehow slipped through (shouldn't happen, but
`git worktree remove` will refuse by default), report the error and do NOT use `--force` without
asking the user explicitly.

After deletion, run:

```bash
git worktree prune
```

to clean up any leftover administrative files.

### 7. Report results

Tell the user which worktrees were deleted and which (if any) were skipped due to errors.

---

## Safety rules

- **Never delete the main worktree.** Always skip the first entry from `git worktree list`.
- **Never use `--force` on `git worktree remove` without explicit user approval.**
- **Never delete a worktree with local-only commits** that haven't been pushed anywhere, unless
  the user explicitly says "yes, nuke it" after being warned about the data loss.
- If `git fetch --prune` fails (e.g. no network), warn the user that condition 2 cannot be
  reliably evaluated and offer to proceed with condition 1 only.
