#!/bin/bash
# Workflow orchestrator for /iterate-pr command
# This script MUST be run as the first step - it provides structured data needed for iteration

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$PROJECT_DIR/.claude/state"

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
    # Try to detect PR from current branch
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ]; then
        # Try to find PR for this branch
        PR_NUMBER=$(gh pr list --head "$CURRENT_BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
    fi

    if [ -z "$PR_NUMBER" ]; then
        echo "Error: Could not detect PR number" >&2
        echo "Usage: $0 <pr-number>" >&2
        echo "   or: $0  (auto-detect from current branch)" >&2
        exit 2
    fi
fi

STATE_FILE="${STATE_DIR}/pr_${PR_NUMBER}_monitor.json"

# ============================================================================
# Ensure State File Exists
# ============================================================================

ensure_state_file() {
    local pr_num="$1"

    mkdir -p "$STATE_DIR"

    if [ ! -f "$STATE_FILE" ]; then
        echo "Creating new state file for PR #$pr_num..." >&2

        # Get repo info
        REPO_OWNER=$(gh repo view --json owner -q '.owner.login' 2>/dev/null || echo "")
        REPO_NAME=$(gh repo view --json name -q '.name' 2>/dev/null || echo "")

        if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
            echo "Error: Could not determine repository info" >&2
            exit 2
        fi

        # Initialize state file with epoch timestamp (will catch all reviews)
        cat > "$STATE_FILE" << EOF
{
  "pr_number": $pr_num,
  "repo_owner": "$REPO_OWNER",
  "repo_name": "$REPO_NAME",
  "last_review_check": "1970-01-01T00:00:00Z",
  "iterations": 0
}
EOF
    fi
}

# ============================================================================
# Main Workflow
# ============================================================================

ensure_state_file "$PR_NUMBER"

# Run check-pr-reviews.sh to detect new feedback
echo "Checking PR #$PR_NUMBER for new reviews and CI status..." >&2
echo "" >&2

# Capture output and exit code without toggling set -e
REVIEW_CHECK_OUTPUT=$("$SCRIPT_DIR/check-pr-reviews.sh" "$PR_NUMBER" 2>&1) || REVIEW_CHECK_EXIT=$?
REVIEW_CHECK_EXIT=${REVIEW_CHECK_EXIT:-0}

# Parse the output to extract counts
CLAUDE_BOT_COMMENTS=$(echo "$REVIEW_CHECK_OUTPUT" | grep "Claude bot comments:" | awk '{print $NF}' || echo "0")
COPILOT_BOT_COMMENTS=$(echo "$REVIEW_CHECK_OUTPUT" | grep "Copilot bot comments:" | awk '{print $NF}' || echo "0")
NEW_REVIEWS=$(echo "$REVIEW_CHECK_OUTPUT" | grep "New reviews:" | awk '{print $NF}' || echo "0")
NEW_REVIEW_COMMENTS=$(echo "$REVIEW_CHECK_OUTPUT" | grep "New review comments:" | awk '{print $NF}' || echo "0")
NEW_ISSUE_COMMENTS=$(echo "$REVIEW_CHECK_OUTPUT" | grep "New issue comments:" | awk '{print $NF}' || echo "0")
FAILING_CI=$(echo "$REVIEW_CHECK_OUTPUT" | grep "Failing CI checks:" | awk '{print $NF}' || echo "0")
PENDING_CI=$(echo "$REVIEW_CHECK_OUTPUT" | grep "Pending CI checks:" | awk '{print $NF}' || echo "0")

# Show the full output
echo "$REVIEW_CHECK_OUTPUT" >&2
echo "" >&2

# Generate verification hash (using random value for uniqueness)
# Note: This hash is for uniqueness/verification that the script ran, not for security
# Fallback to RANDOM if /dev/urandom is not available (e.g., minimal containers)
if [ -e /dev/urandom ]; then
    VERIFICATION_HASH=$(head -c 32 /dev/urandom | sha256sum | cut -d' ' -f1 | head -c 12)
else
    VERIFICATION_HASH=$(echo "$RANDOM$RANDOM$RANDOM" | sha256sum | cut -d' ' -f1 | head -c 12)
fi

# Output structured JSON for Claude to parse
cat << EOF

═══════════════════════════════════════════════════════════════
ITERATE-PR WORKFLOW VALIDATION
═══════════════════════════════════════════════════════════════

PR #$PR_NUMBER Review Status

Verification Hash: $VERIFICATION_HASH
Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Feedback Summary:
  • New reviews: $NEW_REVIEWS
  • New review comments: $NEW_REVIEW_COMMENTS
  • New issue comments: $NEW_ISSUE_COMMENTS
  • Claude bot comments: $CLAUDE_BOT_COMMENTS
  • Copilot bot comments: $COPILOT_BOT_COMMENTS

CI Status:
  • Failing checks: $FAILING_CI
  • Pending checks: $PENDING_CI

Iteration Required: $([ "$REVIEW_CHECK_EXIT" -eq 0 ] && echo "YES" || echo "NO")

═══════════════════════════════════════════════════════════════

EOF

# If iteration needed, display structured feedback from state file
if [ "$REVIEW_CHECK_EXIT" -eq 0 ]; then
    echo "📋 DETAILED FEEDBACK REQUIRING ACTION:" >&2
    echo "" >&2

    LAST_CHECK=$(jq -r '.last_review_check' "$STATE_FILE")

    # Section 1: New feedback since last check
    NEW_ITEMS=$(jq --arg last_check "$LAST_CHECK" '[.feedback_items[] | select(.first_seen > $last_check and .status == "unaddressed")]' "$STATE_FILE")
    NEW_COUNT=$(echo "$NEW_ITEMS" | jq 'length')

    if [ "$NEW_COUNT" -gt 0 ]; then
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "📬 SECTION 1: NEW FEEDBACK (since last check)" >&2
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "" >&2

        echo "$NEW_ITEMS" | jq -r '.[] |
            # Format author label
            (if .author_type == "human" then
                "[HUMAN] @" + .author
             else
                "[BOT: " + (.bot_name // "unknown") + "]"
             end) as $author_label |

            # Type label
            (if .item_type == "review" then "Review"
             elif .item_type == "review_comment" then "Review Comment"
             elif .item_type == "issue_comment" then "Issue Comment"
             else .item_type end) as $type_label |

            # Display
            "\($author_label) - \($type_label)\n" +
            "Created: \(.created_at)\n" +
            (if .path then "File: \(.path):\(.line)\n" else "" end) +
            (if .state then "State: \(.state)\n" else "" end) +
            "\n\(.body // "(no body)" | split("\n") | .[0:5] | join("\n"))\n" +
            "\n→ View: \(.url)\n" +
            "→ Status: \(.status | ascii_upcase)\n" +
            (if .github_resolved then "→ GitHub: RESOLVED\n" else "" end) +
            "\n──────────────────────────────────────────────────────────────\n"
        ' >&2
    fi

    # Section 2: Unaddressed from previous iterations
    OLD_UNADDRESSED=$(jq --arg last_check "$LAST_CHECK" '[.feedback_items[] | select(.first_seen <= $last_check and .status == "unaddressed")]' "$STATE_FILE")
    OLD_COUNT=$(echo "$OLD_UNADDRESSED" | jq 'length')

    if [ "$OLD_COUNT" -gt 0 ]; then
        echo "" >&2
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "🔄 SECTION 2: UNADDRESSED FROM PREVIOUS ITERATIONS" >&2
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "" >&2

        echo "$OLD_UNADDRESSED" | jq -r '.[] |
            # Format author label
            (if .author_type == "human" then
                "[HUMAN] @" + .author
             else
                "[BOT: " + (.bot_name // "unknown") + "]"
             end) as $author_label |

            # Type label
            (if .item_type == "review" then "Review"
             elif .item_type == "review_comment" then "Review Comment"
             elif .item_type == "issue_comment" then "Issue Comment"
             else .item_type end) as $type_label |

            # Display
            "\($author_label) - \($type_label)\n" +
            "Created: \(.created_at)\n" +
            "First seen: \(.first_seen)\n" +
            (if .path then "File: \(.path):\(.line)\n" else "" end) +
            (if .state then "State: \(.state)\n" else "" end) +
            "\n\(.body // "(no body)" | split("\n") | .[0:5] | join("\n"))\n" +
            "\n→ View: \(.url)\n" +
            "→ Status: \(.status | ascii_upcase)\n" +
            (if .github_resolved then "→ GitHub: RESOLVED\n" else "" end) +
            "\n──────────────────────────────────────────────────────────────\n"
        ' >&2
    fi

    # Section 3: Recently addressed (for reference)
    ONE_DAY_AGO=$(date -u -d '1 day ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "1970-01-01T00:00:00Z")
    # Validate ONE_DAY_AGO is not empty (safety check for minimal systems)
    if [ -z "$ONE_DAY_AGO" ]; then
        ONE_DAY_AGO="1970-01-01T00:00:00Z"
    fi
    RECENT_ADDRESSED=$(jq --arg one_day_ago "$ONE_DAY_AGO" '[.feedback_items[] | select(.status == "addressed" and .addressed_at > $one_day_ago)]' "$STATE_FILE")
    ADDRESSED_COUNT=$(echo "$RECENT_ADDRESSED" | jq 'length')

    if [ "$ADDRESSED_COUNT" -gt 0 ]; then
        echo "" >&2
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "✅ SECTION 3: RECENTLY ADDRESSED (for reference)" >&2
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "" >&2

        echo "$RECENT_ADDRESSED" | jq -r '.[] |
            # Format author label
            (if .author_type == "human" then
                "[HUMAN] @" + .author
             else
                "[BOT: " + (.bot_name // "unknown") + "]"
             end) as $author_label |

            # Display
            "\($author_label) - Addressed: \(.addressed_at)\n" +
            (if .addressed_by_commit then "Commit: \(.addressed_by_commit)\n" else "" end) +
            "→ View: \(.url)\n" +
            "\n──────────────────────────────────────────────────────────────\n"
        ' >&2
    fi

    # CI Failures
    if [ "$FAILING_CI" -gt 0 ]; then
        echo "" >&2
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "❌ FAILING CI CHECKS" >&2
        echo "───────────────────────────────────────────────────────────────" >&2
        echo "" >&2
        gh pr checks "$PR_NUMBER" --json name,conclusion,detailsUrl \
            --jq '.[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out") | "  • \(.name): \(.conclusion)\n    \(.detailsUrl)\n"' \
            2>/dev/null || echo "  (Could not fetch details)" >&2
    fi

    echo "" >&2
    echo "═══════════════════════════════════════════════════════════════" >&2
    echo "NEXT STEPS:" >&2
    echo "  1. Create TodoWrite checklist from the feedback above" >&2
    echo "  2. Address each item systematically" >&2
    echo "  3. Run tests to verify fixes" >&2
    echo "  4. Commit and push changes" >&2
    echo "  5. Re-run this script to check for new feedback" >&2
    echo "═══════════════════════════════════════════════════════════════" >&2

    exit 0
else
    echo "✅ No iteration needed - PR is ready!" >&2
    echo "" >&2
    echo "Status:" >&2
    echo "  • All CI checks passing" >&2
    echo "  • No pending reviews or comments" >&2
    echo "  • PR can be merged (pending human approval)" >&2
    echo "" >&2

    exit 1
fi
