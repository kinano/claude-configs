#!/usr/bin/env bash
# post-edit-check.sh — Fast per-file PostToolUse hook for Claude Code
# Runs ONLY fast, single-file checks (biome/eslint/ruff on the edited file).
# Full project typecheck is deferred to a separate Stop hook if needed.

set -uo pipefail

# ── Parse stdin JSON ────────────────────────────────────────────
INPUT=$(cat 2>/dev/null) || true
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || true
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null) || true

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Resolve to absolute path if relative
if [[ "$FILE_PATH" != /* ]]; then
  FILE_PATH="${CWD:-.}/$FILE_PATH"
fi

EXT="${FILE_PATH##*.}"

# ── Walk up to find the project root ────────────────────────────
find_project_root() {
  local dir="$1"
  dir=$(cd "$dir" 2>/dev/null && pwd) || return 1
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]] || [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/setup.py" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root "$(dirname "$FILE_PATH")" 2>/dev/null) || PROJECT_ROOT="$CWD"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# Relative path for single-file tools
FILE_REL="${FILE_PATH#$PROJECT_ROOT/}"

# ── Node.js / TypeScript — single-file lint only ────────────────
run_node_lint() {
  # Biome (fastest — 100-500ms on a single file)
  if [[ -f "biome.json" ]] || [[ -f "biome.jsonc" ]] || \
     jq -e '.devDependencies["@biomejs/biome"] // .dependencies["@biomejs/biome"]' package.json &>/dev/null; then
    echo "▶ Running biome check on ${FILE_REL}..."
    local biome="${PROJECT_ROOT}/node_modules/.bin/biome"
    [[ -x "$biome" ]] || biome="npx biome"
    $biome check "$FILE_REL" 2>&1 | tail -15
  # ESLint fallback
  elif [[ -f ".eslintrc" ]] || [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]] || \
       [[ -f "eslint.config.js" ]] || [[ -f "eslint.config.mjs" ]]; then
    echo "▶ Running eslint on ${FILE_REL}..."
    local eslint="${PROJECT_ROOT}/node_modules/.bin/eslint"
    [[ -x "$eslint" ]] || eslint="npx eslint"
    $eslint "$FILE_REL" 2>&1 | tail -15
  fi

  # NOTE: No typecheck here — tsc runs on the whole project and is too slow for per-edit.
}

# ── Python — single-file lint only ──────────────────────────────
run_python_lint() {
  has_pyproject_tool() { grep -q "\[tool\.${1}" pyproject.toml 2>/dev/null; }

  # Typecheck (single-file)
  if command -v mypy &>/dev/null && { [[ -f "mypy.ini" ]] || [[ -f ".mypy.ini" ]] || has_pyproject_tool "mypy"; }; then
    echo "▶ Running mypy on ${FILE_REL}..."
    mypy "$FILE_REL" 2>&1 | tail -15
  elif command -v pyright &>/dev/null && { [[ -f "pyrightconfig.json" ]] || has_pyproject_tool "pyright"; }; then
    echo "▶ Running pyright on ${FILE_REL}..."
    pyright "$FILE_REL" 2>&1 | tail -15
  fi

  # Lint (single-file)
  if has_pyproject_tool "ruff" || [[ -f "ruff.toml" ]] || [[ -f ".ruff.toml" ]]; then
    if command -v ruff &>/dev/null; then
      echo "▶ Running ruff check on ${FILE_REL}..."
      ruff check "$FILE_REL" 2>&1 | tail -15
    fi
  elif has_pyproject_tool "flake8" || [[ -f ".flake8" ]]; then
    if command -v flake8 &>/dev/null; then
      echo "▶ Running flake8 on ${FILE_REL}..."
      flake8 "$FILE_REL" 2>&1 | tail -15
    fi
  fi
}

# ── Dispatch ────────────────────────────────────────────────────
case "$EXT" in
  ts|tsx|js|jsx|mjs|cjs)
    [[ -f "package.json" ]] && run_node_lint
    ;;
  py)
    { [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; } && run_python_lint
    ;;
esac

exit 0
