# Claude Code Configs

Shared configuration files for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Clone this repo and symlink the files into `~/.claude/` to set up a new machine quickly.

## Repo Structure

```
├── CLAUDE.md            # Project-level instructions
├── settings.json        # Claude Code settings (model, hooks, permissions, etc.)
├── .mcp.json            # MCP server configuration
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
   export REPO_DIRECTORY_PATH=~/dev/claude-configs

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

   # MCP server configuration
   ln -sf "$REPO_DIRECTORY_PATH/.mcp.json" ~/.claude/.mcp.json

   # MCP wrapper scripts
   # -sfn for directories (replaces existing directory symlink cleanly)
   ln -sfn "$REPO_DIRECTORY_PATH/claude-desktop/scripts" ~/.claude/scripts
   chmod +x ~/.claude/scripts/*.sh
   ```

   > **Note:** `ln -sf` is used for files and `ln -sfn` is used for directories so the symlink replaces any existing directory symlink cleanly.

4. **Verify**

   ```sh
   ls -la ~/.claude/settings.json ~/.claude/CLAUDE.md ~/.claude/.mcp.json ~/.claude/commands ~/.claude/hooks ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

   Each entry should show `->` pointing to the repo paths.

## Customization

- Edit files in this repo, then `git commit` and `git push` — changes propagate to every machine via `git pull`.
- To override settings on a single machine without affecting the repo, remove the symlink for that file and create a local copy instead.

## TODOs

- https://github.com/simonw/claude-code-transcripts

## Useful Links

- [Claude Code Hooks](https://code.claude.com/docs/en/hooks)

## Adding MCP Servers to a Project

MCP servers are configured **per-project** via a `.mcp.json` file at the repo root — not globally. This means servers only load when Claude Code is running inside the relevant repo, so env vars and credentials don't need to be available everywhere.

Use the `/add-mcp-server` skill to add an MCP server to any project. It will:
- Create or update `.mcp.json` at the project root
- Use `${VAR_NAME}` syntax for secrets (Claude Code expands these at runtime)
- Add missing env vars to `.env` and ensure `.env` is gitignored
- Keep `.mcp.json` safe to commit

### Useful servers

| Server | Install | Notes |
|--------|---------|-------|
| **dbt-mcp** | `uvx dbt-mcp` | Requires dbt installed via pipx. Env vars: `DBT_PROJECT_DIR`, `DBT_PATH`, plus project-specific DB credentials. |
| **redshift** | `uvx awslabs.redshift-mcp-server` | Env vars: `AWS_PROFILE`, `AWS_REGION`. |
| **Langfuse** | HTTP/SSE — `https://us.cloud.langfuse.com/api/public/mcp` | Auth header: `Authorization: Basic ${LANGFUSE_BASE_64_TOKEN}`. See [docs](https://langfuse.com/docs/api-and-data-platform/features/mcp-server). Alternatively, use [langfuse-cli](https://github.com/langfuse/langfuse-cli) as a skill: `npx langfuse-cli get-skill`. |
