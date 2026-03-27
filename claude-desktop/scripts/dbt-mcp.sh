#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.claude/mcp.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. See README for setup instructions." >&2
  exit 1
fi

env_perms=$(stat -Lf "%OLp" "$ENV_FILE")
if [[ "$env_perms" != "600" && "$env_perms" != "400" ]]; then
  echo "ERROR: $ENV_FILE has unsafe permissions ($env_perms). Run: chmod 600 $ENV_FILE" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

VERSIONS_FILE="$HOME/.claude/mcp-versions.env"
if [[ -f "$VERSIONS_FILE" ]]; then
  source "$VERSIONS_FILE"
fi

exec uvx dbt-mcp
