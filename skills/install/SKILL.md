---
name: install
description: >
  Selectively install skills, hooks, and commands from the Farty Bobo config repo
  (fartybobo/farty-bobo) onto this machine — without forking or cloning the whole repo.
  Trigger on: "install farty bobo", "install skills from farty bobo", "get the farty bobo skills",
  "install hooks", "install commands from config repo".
---

# Farty Bobo Installer

Fetch the live catalog from `fartybobo/farty-bobo`, let the user pick what they want,
and install it to the right places on this machine.

## 1. Fetch the catalog

Run all three in parallel:

```bash
# Skills
gh api "repos/fartybobo/farty-bobo/contents/skills" --jq '.[].name'

# Hooks (.sh files only)
gh api "repos/fartybobo/farty-bobo/contents/hooks" \
  --jq '[.[] | select(.name | endswith(".sh")) | .name]'

# Commands
gh api "repos/fartybobo/farty-bobo/contents/commands" --jq '.[].name'
```

For each skill, fetch its description from the frontmatter:
```bash
gh api "repos/fartybobo/farty-bobo/contents/skills/<name>/SKILL.md" \
  --jq '.content' | base64 -d | head -6
```

For each hook, fetch its purpose from the file header:
```bash
gh api "repos/fartybobo/farty-bobo/contents/hooks/<name>" \
  --jq '.content' | base64 -d | head -5
```

Fetch all descriptions in parallel — do not loop sequentially.

## 2. Present the menu

Display a categorized list:

```
Available from fartybobo/farty-bobo:

SKILLS
  • <name> — <description from frontmatter>
  ...

HOOKS
  • <name> — <purpose from header comment>
  ...

COMMANDS
  • <name>
  ...
```

Ask the user:
> "Which would you like to install? Type 'all', a category name (skills / hooks / commands), or a space-separated list of names."

Parse the response. If ambiguous, ask for clarification.

## 3. Download selected items

### Skills

For each selected skill, list the files in its directory:
```bash
gh api "repos/fartybobo/farty-bobo/contents/skills/<name>" --jq '.[].name'
```

For each file in the skill directory, download it:
```bash
gh api "repos/fartybobo/farty-bobo/contents/skills/<name>/<file>" \
  --jq '.content' | base64 -d > ~/.claude/skills/<name>/<file>
```

Create `~/.claude/skills/<name>/` if it doesn't exist. If the skill directory already exists,
ask the user: "~/.claude/skills/<name>/ already exists — overwrite, skip, or merge?"

### Hooks

For each selected hook, download the script:
```bash
gh api "repos/fartybobo/farty-bobo/contents/hooks/<name>" \
  --jq '.content' | base64 -d > ~/.claude/hooks/<name>
chmod +x ~/.claude/hooks/<name>
```

Create `~/.claude/hooks/` if it doesn't exist.

If a hook file already exists, ask: "~/.claude/hooks/<name> already exists — overwrite or skip?"

After downloading, go to Step 4 (hook registration) for each hook installed.

### Commands

For each selected command, download it:
```bash
gh api "repos/fartybobo/farty-bobo/contents/commands/<name>" \
  --jq '.content' | base64 -d > ~/.claude/commands/<name>
chmod +x ~/.claude/commands/<name>
```

Create `~/.claude/commands/` if it doesn't exist.

## 4. Register hooks in settings.json

This step only applies if one or more hooks were installed.

First, fetch the hook registration config from the source repo's `settings.json` to know
exactly how each hook should be wired up (event type, matcher, command path):
```bash
gh api "repos/fartybobo/farty-bobo/contents/settings.json" \
  --jq '.content' | base64 -d
```

Extract the `hooks` entries that correspond to each installed hook script.

Then ask the user:
> "Where should the hooks be registered?
>   1. Globally — `~/.claude/settings.json` (fires in every project)
>   2. This project only — `.claude/settings.json` in the current directory"

Based on their choice, read the target `settings.json` (create it with `{}` if it doesn't exist),
merge in the new hook entries under the correct event keys (`PreToolUse`, `PostToolUse`,
`SessionStart`, etc.), and write it back. Do not overwrite existing hook entries for other scripts —
append only.

If a hook entry for the same script path already exists in the target settings.json, skip it
and tell the user it was already registered.

## 5. Report

Print a summary:

```
Installed:
  ✓ skills/  <name>, <name>, ...
  ✓ hooks/   <name> (registered in ~/.claude/settings.json)
  ✓ commands/ <name>, ...

Skipped (already existed):
  - <name>

Done. Restart Claude Code for hook changes to take effect.
```
