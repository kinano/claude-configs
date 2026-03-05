# Claude Code Configs

Shared configuration files for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Clone this repo and symlink the files into `~/.claude/` to set up a new machine quickly.

## Repo Structure

```
├── CLAUDE.md            # Project-level instructions
├── settings.json        # Claude Code settings (model, hooks, permissions, etc.)
├── commands/
│   └── statusline-command.sh
└── hooks/
    ├── post-edit-check.sh
    └── README.md
```

## Setup on a New Machine

1. **Clone the repo**

   ```sh
   git clone <repo-url> ~/dev/claude-configs
   ```

2. **Create the `~/.claude` directory** (if it doesn't exist)

   ```sh
   mkdir -p ~/.claude
   ```

3. **Symlink config files and directories**

   ```sh

   # Adjust to fit your local setup
   export REPO_DIRECTORY_PATH=~/dev/claude-configs

   # Settings
   ln -sf $REPO_DIRECTORY_PATH/settings.json ~/.claude/settings.json

   # CLAUDE.md (global user instructions)
   ln -sf $REPO_DIRECTORY_PATH/CLAUDE.md ~/.claude/CLAUDE.md

   # Commands
   ln -sfn $REPO_DIRECTORY_PATH/commands ~/.claude/commands

   # Hooks
   ln -sfn $REPO_DIRECTORY_PATH/hooks ~/.claude/hooks

   # Skills
   ln -sfn $REPO_DIRECTORY_PATH/skills ~/.claude/skills
   ```

   > **Note:** `ln -sfn` is used for directories so the symlink replaces any existing directory symlink cleanly.

4. **Verify**

   ```sh
   ls -la ~/.claude/settings.json ~/.claude/CLAUDE.md ~/.claude/commands ~/.claude/hooks
   ```

   Each entry should show `->` pointing to the repo paths.

## Customization

- Edit files in this repo, then `git commit` and `git push` — changes propagate to every machine via `git pull`.
- To override settings on a single machine without affecting the repo, remove the symlink for that file and create a local copy instead.

## TODOs

- https://github.com/simonw/claude-code-transcripts

## Useful Links

- [Hamel Husain's Evals skills](https://hamel.dev/blog/posts/evals-skills/)
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)
