#!/bin/bash
# Claude Code status line configuration
# Shows: [Model] Repository | Branch | PR #X (if applicable)
#
# Usage: echo '{"model": {...}, "workspace": {...}}' | statusline.sh
#
# Expected JSON schema:
#   {
#     "model": {"display_name": string},
#     "workspace": {"current_dir": string}
#   }
#
# Returns: Formatted status line with ANSI colors
# Exit codes: 0 on success, 1 on error

set -euo pipefail

# Check required dependencies
for cmd in jq git; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not installed" >&2
        exit 1
    fi
done

# ANSI color codes
CYAN='\033[36m'
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
RESET='\033[0m'
DIM='\033[2m'

# Read input from stdin
input=$(cat)

# Extract model name
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')

# Extract current directory and get repo name
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // "."')
REPO_NAME=$(basename "$CURRENT_DIR")

# Get git branch (if in a git repo)
BRANCH=""
if git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$CURRENT_DIR" branch --show-current 2>/dev/null || echo "")
fi

# Get PR number (if on a feature branch with associated PR)
PR_NUM=""
if [ -n "$BRANCH" ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
    # Validate directory exists before cd
    if [ -d "$CURRENT_DIR" ]; then
        PR_NUM=$(cd "$CURRENT_DIR" && gh pr view "${BRANCH}" --json number -q .number 2>/dev/null || echo "")
    fi
fi

# Build status line with colors
STATUS="${CYAN}[${MODEL}]${RESET} ${BOLD}${REPO_NAME}${RESET}"

if [ -n "$BRANCH" ]; then
    # Color branch based on whether it's main or feature
    if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
        STATUS="${STATUS} ${DIM}|${RESET} ${GREEN}${BRANCH}${RESET}"
    else
        STATUS="${STATUS} ${DIM}|${RESET} ${YELLOW}${BRANCH}${RESET}"
    fi
fi

if [ -n "$PR_NUM" ]; then
    STATUS="${STATUS} ${DIM}|${RESET} ${MAGENTA}PR #${PR_NUM}${RESET}"
fi

# Get Python virtual environment info
VENV_NAME=""
PYTHON_VERSION=""

if [ -n "${VIRTUAL_ENV:-}" ]; then
    VENV_NAME=$(basename "$VIRTUAL_ENV")

    # Get Python version from active venv
    if [ -x "${VIRTUAL_ENV}/bin/python" ]; then
        PYTHON_VERSION=$("${VIRTUAL_ENV}/bin/python" --version 2>&1 | cut -d' ' -f2)
    elif command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    fi

    # Append venv info to status line
    if [ -n "$PYTHON_VERSION" ]; then
        STATUS="${STATUS} ${DIM}|${RESET} 🐍 ${GREEN}${VENV_NAME}${RESET} ${DIM}(${PYTHON_VERSION})${RESET}"
    else
        STATUS="${STATUS} ${DIM}|${RESET} 🐍 ${GREEN}${VENV_NAME}${RESET}"
    fi
fi

printf '%b\n' "$STATUS"
