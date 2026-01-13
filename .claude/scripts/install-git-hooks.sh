#!/bin/bash
# Install git hooks from .claude/git-hooks/ to .git/hooks/
#
# This script copies tracked git hooks to the .git/hooks/ directory
# and makes them executable.
#
# Usage:
#   bash .claude/scripts/install-git-hooks.sh

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_SOURCE="$PROJECT_DIR/.claude/git-hooks"
HOOKS_TARGET="$PROJECT_DIR/.git/hooks"

# Emoji toggle
if [ "${NO_EMOJI:-0}" = "1" ]; then
    SUCCESS="[OK]"
    FAILURE="[FAIL]"
else
    SUCCESS="✅"
    FAILURE="❌"
fi

# ============================================================================
# Validate Environment
# ============================================================================

echo "Installing git hooks..."

# Check if we're in a git repository
if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "$FAILURE Error: Not in a git repository" >&2
    echo "  Expected .git directory at: $PROJECT_DIR/.git" >&2
    exit 1
fi

# Check if hooks source directory exists
if [ ! -d "$HOOKS_SOURCE" ]; then
    echo "$FAILURE Error: Hooks source directory not found" >&2
    echo "  Expected: $HOOKS_SOURCE" >&2
    exit 1
fi

# Create hooks target directory if it doesn't exist
mkdir -p "$HOOKS_TARGET"

# ============================================================================
# Install Hooks
# ============================================================================

INSTALLED_COUNT=0
FAILED_COUNT=0

# Find all hook files in source directory
while IFS= read -r hook_file; do
    HOOK_NAME=$(basename "$hook_file")

    echo "  Installing $HOOK_NAME..."

    # Copy hook to .git/hooks/
    if cp "$hook_file" "$HOOKS_TARGET/$HOOK_NAME"; then
        # Make executable
        chmod +x "$HOOKS_TARGET/$HOOK_NAME"
        echo "    $SUCCESS Installed: $HOOKS_TARGET/$HOOK_NAME"
        INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
    else
        echo "    $FAILURE Failed to install: $HOOK_NAME" >&2
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done < <(find "$HOOKS_SOURCE" -type f -not -name "*.md" -not -name "README*")

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "Git hooks installation complete!"
echo "  $SUCCESS Installed: $INSTALLED_COUNT hook(s)"

if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "  $FAILURE Failed: $FAILED_COUNT hook(s)"
    exit 1
fi

echo ""
echo "Installed hooks will prevent:"
echo "  - Direct pushes to main/master branches"
echo "  - (Add more protections as needed)"
echo ""
echo "To bypass a hook (not recommended):"
echo "  git push --no-verify"
echo ""

exit 0
