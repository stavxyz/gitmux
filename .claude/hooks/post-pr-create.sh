#!/bin/bash
# Post-PR-Create Hook
# Triggered automatically after gh pr create succeeds
# Initializes monitoring state for the new PR

set -euo pipefail

# Dynamically determine project directory from script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$PROJECT_DIR/.claude/state"
HOOK_DATA_FILE="${STATE_DIR}/hook_input.json"

# Create state directory if needed
mkdir -p "$STATE_DIR"

# Save hook input for processing
cat > "$HOOK_DATA_FILE"

# Extract PR URL from the output
PR_URL=$(jq -r '.tool_output.content // empty' "$HOOK_DATA_FILE" 2>/dev/null | grep -oE 'https://github.com/[^/]+/[^/]+/pull/[0-9]+' | head -1 || echo "")

if [ -n "$PR_URL" ]; then
    # Extract PR number
    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')

    # Initialize monitoring state
    cat > "${STATE_DIR}/pr_${PR_NUMBER}_monitor.json" <<EOF
{
  "pr_number": "$PR_NUMBER",
  "pr_url": "$PR_URL",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "last_review_check": null,
  "iterations": 0,
  "status": "monitoring"
}
EOF

    echo "✓ PR monitoring initialized for #$PR_NUMBER"
    echo "✓ PR URL: $PR_URL"

    # Setup webhook
    if [ -f "$PROJECT_DIR/.claude/scripts/setup-webhook.sh" ]; then
        echo "✓ Setting up webhook..."
        bash "$PROJECT_DIR/.claude/scripts/setup-webhook.sh" "$PR_NUMBER" || echo "⚠ Webhook setup failed, will use manual /iterate-pr"
    fi

    echo ""
    echo "🤖 Automated review monitoring is active"
    echo "   Use '/iterate-pr' to manually check for reviews"
else
    echo "⚠ Could not extract PR URL from output"
    echo "   You can still use '/iterate-pr <number>' manually"
fi

exit 0
