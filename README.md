# Claude Code Configs

Shared configuration files for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Clone this repo and symlink the files into `~/.claude/` to set up a new machine quickly.

## Repo Structure

```
├── CLAUDE.md            # Project-level instructions
├── settings.json        # Claude Code settings (model, hooks, permissions, etc.)
├── commands/
│   └── statusline-command.sh
├── hooks/
│   ├── post-edit-check.sh
│   └── README.md
└── skills/
    └── *
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
   export REPO_DIRECTORY_PATH=~/software_projects/claude-configs

   # Settings
   ln -sf "$REPO_DIRECTORY_PATH/settings.json" ~/.claude/settings.json

   # CLAUDE.md (global user instructions)
   ln -sf "$REPO_DIRECTORY_PATH/CLAUDE.md" ~/.claude/CLAUDE.md

   # Commands
   ln -sfn "$REPO_DIRECTORY_PATH/commands" ~/.claude/commands

   # Hooks
   ln -sfn "$REPO_DIRECTORY_PATH/hooks" ~/.claude/hooks

   # Skills
   ln -sfn "$REPO_DIRECTORY_PATH/skills" ~/.claude/skills

   # Claude Desktop configs
   ln -s "$REPO_DIRECTORY_PATH/claude-desktop/claude_desktop_config.json" ~/Library/Application\ Support/Claude/claude_desktop_config.json

   # Env vars for MCP servers
   # -sf for files (creates/replaces a file symlink)
   ln -sf "$REPO_DIRECTORY_PATH/.env" ~/.claude/mcp.env
   chmod 600 ~/.claude/mcp.env

   # MCP server version pins
   ln -sf "$REPO_DIRECTORY_PATH/claude-desktop/mcp-versions.env" ~/.claude/mcp-versions.env

   # MCP wrapper scripts
   # -sfn for directories (replaces existing directory symlink cleanly)
   ln -sfn "$REPO_DIRECTORY_PATH/claude-desktop/scripts" ~/.claude/scripts
   chmod +x ~/.claude/scripts/*.sh
   ```

   > **Note:** `ln -sf` is used for files and `ln -sfn` is used for directories so the symlink replaces any existing directory symlink cleanly.

4. **Verify**

   ```sh
   ls -la ~/.claude/settings.json ~/.claude/CLAUDE.md ~/.claude/commands ~/.claude/hooks ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

   Each entry should show `->` pointing to the repo paths.

## Customization

- Edit files in this repo, then `git commit` and `git push` — changes propagate to every machine via `git pull`.
- To override settings on a single machine without affecting the repo, remove the symlink for that file and create a local copy instead.

## TODOs

- https://github.com/simonw/claude-code-transcripts

## Useful Links

- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)

## Useful MCP Servers

### dbt-mcp

```
# 1. Install pipx if you don't have it
brew install pipx
pipx ensurepath

# 2. Install dbt-redshift
PIPX_DEFAULT_PYTHON=$(pyenv prefix 3.12.9)/bin/python \
  PIP_INDEX_URL=https://pypi.org/simple/ \
  pipx install dbt-redshift --include-deps

# 3. Verify installation
dbt --version

# Get/set the ENV VARs needed by your DBT project

# 4. Add the dbt MCP server to Claude Code
claude mcp add dbt \
  -e DBT_PROJECT_DIR=/path/to/data-warehouse/dbt \
  -e DBT_PATH=$(which dbt) \
  -e ... \ Add all the DBT ENV VARs required by your DBT project
  -- uvx dbt-mcp
```

### Langfuse MCP & CLI

Inspired by [Hamel Husain's Evals Skills](https://hamel.dev/blog/posts/evals-skills/) for Claude Code.
[Langfuse MCP Documentation](https://langfuse.com/docs/api-and-data-platform/features/mcp-server)

```
LANGFUSE_BASE_64_TOKEN=$(echo -n "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" | base64)

claude mcp add --transport http langfuse https://us.cloud.langfuse.com/api/public/mcp \
    --header "Authorization: Basic $LANGFUSE_BASE_64_TOKEN"
```

The Langfuse MCP server only includes prompts as of March 2026. An [easy alternative](https://github.com/orgs/langfuse/discussions/10605#discussioncomment-15799558) is to use langfuse-cli and wire it up as a tool ([github](https://github.com/langfuse/langfuse-cli)).

```
npx langfuse-cli get-skill
```
