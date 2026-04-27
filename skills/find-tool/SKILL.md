---
name: find-tool
description: >
  Given a task or user query, check whether an existing skill, plugin, hook, or script in the
  Embark Claude tooling repos already handles it. Always run this before building anything new.
  Trigger on: "do we have a tool for", "is there a skill for", "can we do X already",
  "check if there's a tool", "find a tool for", "what skill should I use for".
model: haiku
---

# Find an Existing Tool

Before anyone builds a new skill, plugin, or script, check whether one already exists.
This skill fetches the current state of both tooling repos live — no stale catalog.

## 1. Fetch the tool catalog

Run the following `gh api` commands in parallel to discover everything available.

**Skills** (`embarkvetlabs/claude-configs`):
```bash
gh api "repos/embarkvetlabs/claude-configs/contents/skills" --jq '.[].name'
```
For each skill name, read its `SKILL.md` frontmatter (name + description):
```bash
gh api "repos/embarkvetlabs/claude-configs/contents/skills/<name>/SKILL.md" --jq '.content' | base64 -d
```

**Plugins** (`embarkvetlabs/embarkvet-claude-plugins`):
```bash
gh api "repos/embarkvetlabs/embarkvet-claude-plugins/contents/plugins" --jq '[.[] | select(.name | startswith("_") | not) | .name]'
```
Skip any directory whose name starts with `_` (e.g. `_template`). For each real plugin, read its `README.md` if present:
```bash
gh api "repos/embarkvetlabs/embarkvet-claude-plugins/contents/plugins/<name>/README.md" --jq '.content' | base64 -d
```
For skills inside a plugin (skip gracefully if `skills/` subdirectory doesn't exist — a 404 means this plugin has no skills):
```bash
gh api "repos/embarkvetlabs/embarkvet-claude-plugins/contents/plugins/<name>/skills" --jq '.[].name'
gh api "repos/embarkvetlabs/embarkvet-claude-plugins/contents/plugins/<name>/skills/<skill-name>/SKILL.md" --jq '.content' | base64 -d
```
For agents inside a plugin (skip gracefully if `agents/` subdirectory doesn't exist):
```bash
gh api "repos/embarkvetlabs/embarkvet-claude-plugins/contents/plugins/<name>/agents" --jq '.[].name'
gh api "repos/embarkvetlabs/embarkvet-claude-plugins/contents/plugins/<name>/agents/<agent-name>.md" --jq '.content' | base64 -d
```

**Hooks** (`embarkvetlabs/claude-configs`):
```bash
gh api "repos/embarkvetlabs/claude-configs/contents/hooks" --jq '[.[] | select(.name | endswith(".sh")) | .name]'
```
For each hook, read its header comment (first 20 lines is enough):
```bash
gh api "repos/embarkvetlabs/claude-configs/contents/hooks/<name>" --jq '.content' | base64 -d | head -20
```

Batch these calls aggressively — fetch all skill SKILL.md files in parallel, all plugin READMEs in parallel, etc. Do not fetch sequentially.

## 2. Match against the query

The user's query is in the skill arguments. Scan everything fetched for tools whose description, trigger keywords, or stated purpose overlaps with the ask.

Cast wide — an 80% match is worth surfacing. Rank by fit: exact trigger-keyword match > description overlap > general category match.

## 3. Respond

### If one or more tools match:

For each match, output:

```
**<Tool name>** (`/<skill-name>` for skills · `<plugin>:<agent>` for agents)
Source: <repo> · <path>
<One sentence on why it fits this specific query.>
<Any caveats — things the tool does NOT cover, or extra steps needed.>
```

If multiple tools match, order best-to-worst and note if they should be combined (e.g. `/plan-task` then `/build`).

End with: "No need to build anything new — use the above."

### If nothing matches:

Say clearly that no existing tool covers this. Name the closest thing and why it falls short.

Then ask the user whether they want to see the full tool catalog using an interactive prompt with exactly two options:

```
Want to see the full list of available tools?
> Yes
  No
```

**If the user selects Yes:**

Print every tool discovered in step 1, grouped into three sections:

```
## Skills
- **<name>** — <one-line description>
  Source: embarkvetlabs/claude-configs · skills/<name>

## Plugins
- **<plugin-name>**
  - Agent: <agent-name> — <one-line description>
  - Skill: /<skill-name> — <one-line description>
  Source: embarkvetlabs/embarkvet-claude-plugins · plugins/<plugin-name>

## Hooks
- **<hook-filename>** — <one-line description from header comment>
  Source: embarkvetlabs/claude-configs · hooks/<hook-filename>
```

Omit a section entirely if it has no entries. After the list, add: "None of these cover your original query — you may need to build something new."

**If the user selects No:**

Ask: "Do you have any other questions about the available tools?"
Wait for the user's response and answer accordingly. Do not start building anything.
