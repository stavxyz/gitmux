#!/bin/bash
# Setup GitHub Webhook for PR Review Notifications
# Usage: setup-webhook.sh [PR_NUMBER]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$PROJECT_DIR/.claude/state"

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <pr-number>" >&2
    exit 1
fi

# Get repository info
REPO_OWNER=$(gh repo view --json owner -q '.owner.login' 2>/dev/null || echo "")
REPO_NAME=$(gh repo view --json name -q '.name' 2>/dev/null || echo "")

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    echo "⚠ Could not determine repository owner/name" >&2
    echo "  Make sure you're in a git repository with GitHub remote" >&2
    exit 1
fi

# For now, we'll use a fallback approach with gh api polling instead of webhooks
# TODO: Implement actual webhook setup when local listener or smee.io is configured

echo "ℹ️  Webhook setup: Using API polling fallback"
echo "   Repository: $REPO_OWNER/$REPO_NAME"
echo "   PR: #$PR_NUMBER"

# Store repository info in state file for later use
STATE_FILE="${STATE_DIR}/pr_${PR_NUMBER}_monitor.json"
if [ -f "$STATE_FILE" ]; then
    # Update state file with repo info
    TMP_FILE=$(mktemp)
    jq --arg owner "$REPO_OWNER" --arg repo "$REPO_NAME" \
        '.repo_owner = $owner | .repo_name = $repo | .webhook_mode = "api_polling"' \
        "$STATE_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$STATE_FILE"
fi

echo "✓ Webhook configuration completed"
echo ""
echo "Note: Currently using API polling mode."
echo "For real-time webhook notifications, see .claude/README.md for setup instructions."

exit 0
