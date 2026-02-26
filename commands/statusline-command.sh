#!/usr/bin/env bash
# Claude Code status line - inspired by robbyrussell Oh My Zsh theme

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Current directory basename (like %c in robbyrussell)
dir_name=$(basename "$cwd")

# Git branch (skip lock to be safe)
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build output with ANSI colors (dimmed-friendly)
CYAN='\033[0;36m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Directory
output=$(printf "${CYAN}%s${RESET}" "$dir_name")

# Git branch
if [ -n "$git_branch" ]; then
  output="$output $(printf "${BLUE}git:(${RED}%s${BLUE})${RESET}" "$git_branch")"
fi

# Model
if [ -n "$model" ]; then
  output="$output $(printf "${YELLOW}[%s]${RESET}" "$model")"
fi

# Context usage
if [ -n "$used_pct" ]; then
  printf_pct=$(printf "%.0f" "$used_pct" 2>/dev/null)
  output="$output $(printf "${YELLOW}ctx:%s%%${RESET}" "$printf_pct")"
fi

printf "%b\n" "$output"
