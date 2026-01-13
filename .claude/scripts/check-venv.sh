#!/bin/bash
# Claude Code Virtual Environment Safety Check
# Validates that a Python virtual environment is active before pip operations
#
# This hook prevents accidental system Python corruption by blocking pip
# install/uninstall commands when no virtual environment is active.
#
# Bypass: Set CLAUDE_VENV_SAFETY_HOOK=false to disable (not recommended)
#
# Exit codes:
#   0 - Safe to proceed (venv active or safety hook disabled)
#   1 - Blocked (no venv active and safety hook enabled)

# Check that we're running in bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash" >&2
    exit 1
fi

set -euo pipefail

# Check if safety hook is disabled
if [ "${CLAUDE_VENV_SAFETY_HOOK:-true}" = "false" ]; then
    # Safety hook disabled, allow operation
    exit 0
fi

# Check if virtual environment is active
if [ -n "${VIRTUAL_ENV:-}" ]; then
    # Virtual environment is active, safe to proceed
    exit 0
fi

# No venv active and safety hook enabled - block operation
echo "" >&2
echo "❌ ERROR: No Python virtual environment active" >&2
echo "" >&2
echo "To protect your system Python, pip operations require an active virtual environment." >&2
echo "" >&2
echo "Options:" >&2
echo "" >&2
echo "1. Activate the virtual environment (recommended):" >&2
echo "   source ~/.virtualenvs/my-project/bin/activate" >&2
echo "   # or" >&2
echo "   source .venv/bin/activate" >&2
echo "" >&2
echo "2. Disable this safety check (not recommended):" >&2
echo "   export CLAUDE_VENV_SAFETY_HOOK=false" >&2
echo "   # Add to .envrc to persist" >&2
echo "" >&2
echo "For more information, see: .claude/docs/VIRTUAL_ENVIRONMENT_SETUP.md" >&2
echo "" >&2

exit 1
