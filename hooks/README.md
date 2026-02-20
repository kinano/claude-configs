# Repo-Aware Claude Code Hooks

Auto-detect your project toolchain and run the right checks — no hardcoded commands.

## Strategy: Fast Per-Edit Checks

A single hook runs lightweight, single-file linting (and typechecking for Python) immediately after each file edit. No project-wide checks on every turn — keeps things fast.

| Hook | Event | What it does | Speed |
|---|---|---|---|
| `post-edit-check.sh` | `PostToolUse` (Edit/MultiEdit/Write) | **Single-file** lint + typecheck (Python) | ~100-500ms |

## How Detection Works

```
Edit a .ts file → finds package.json → finds biome → runs biome check on that file
                                      → no biome? checks for eslint → runs eslint
                                      → no linter? skips gracefully

Edit a .py file → finds pyproject.toml → finds mypy → runs mypy on that file
                                        → no mypy? checks for pyright → runs pyright
                                        → then finds ruff → runs ruff check on that file
                                        → no ruff? checks for flake8 → runs flake8
                                        → no linter? skips gracefully
```

### Detection Priority

| Signal | What runs |
|---|---|
| `biome.json` or `@biomejs/biome` in deps | `npx biome check` (per-file) |
| `.eslintrc*` / `eslint.config.*` | `npx eslint` (per-file) |
| `mypy.ini` / `.mypy.ini` / `[tool.mypy]` | `mypy` (per-file) |
| `pyrightconfig.json` / `[tool.pyright]` | `pyright` (per-file) |
| `pyproject.toml` → `[tool.ruff]` | `ruff check` (per-file) |
| `pyproject.toml` → `[tool.flake8]` or `.flake8` | `flake8` (per-file) |

## Installation

```bash
mkdir -p ~/.claude/hooks
cp post-edit-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/post-edit-check.sh"
          }
        ]
      }
    ]
  }
}
```

## Requirements

- `jq` — for parsing JSON stdin from Claude Code
  - macOS: `brew install jq`
  - Ubuntu/Debian: `apt-get install jq`
- Your project's tools (biome, eslint, ruff, etc.) installed in the project.

## Customization

### Add more file types

Edit `post-edit-check.sh` and add cases to the `case "$EXT"` block:

```bash
rs)
  if [[ -f "Cargo.toml" ]]; then
    echo "▶ Running cargo check..."
    cargo check 2>&1 | tail -20 || true
  fi
  ;;
```

### Monorepo support

The hook walks up from the edited file to find the nearest `package.json` or
`pyproject.toml`, so it works in monorepos automatically.
