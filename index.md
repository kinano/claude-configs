---
layout: default
title: Farty Bobo
---

<img src="logos/fartybobo_angry_mascot.svg" alt="Farty Bobo mascot" width="200" height="124" />

# Farty Bobo

Shared [Claude Code](https://docs.anthropic.com/en/docs/claude-code) configuration files, hooks, and skills. Clone and symlink to get a fully configured Claude Code environment on any machine.

## What's In Here

- **CLAUDE.md** — Global instructions and behavior rules for Claude Code
- **settings.json** — Model, hooks, and permission configuration
- **skills/** — Custom slash commands and automation
- **hooks/** — Pre/post edit shell hooks
- **commands/** — Status line and other shell commands

## Quick Setup

```sh
git clone https://github.com/fartybobo/farty-bobo ~/dev/farty-bobo
cd ~/dev/farty-bobo
./setup.sh
```

See the [README](https://github.com/fartybobo/farty-bobo) for full setup instructions.
