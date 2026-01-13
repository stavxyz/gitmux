#!/bin/bash
# Check for new PR reviews and comments
# Returns exit code 0 if new reviews exist, 1 if no new reviews

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Emoji toggle (set NO_EMOJI=1 to disable emoji output)
if [ "${NO_EMOJI:-0}" = "1" ]; then
    readonly SUCCESS="[OK]"
    readonly FAILURE="[FAIL]"
else
    readonly SUCCESS="✅"
    readonly FAILURE="❌"
fi

# ============================================================================
# Paths
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$PROJECT_DIR/.claude/state"

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <pr-number>" >&2
    exit 2
fi

STATE_FILE="${STATE_DIR}/pr_${PR_NUMBER}_monitor.json"

if [ ! -f "$STATE_FILE" ]; then
    echo "Error: No monitoring state found for PR #$PR_NUMBER" >&2
    echo "  State file not found: $STATE_FILE" >&2
    exit 2
fi

# ============================================================================
# Schema Version Detection and Migration
# ============================================================================

detect_schema_version() {
    local state_file="$1"
    # Check if schema_version field exists
    if jq -e '.schema_version' "$state_file" >/dev/null 2>&1; then
        jq -r '.schema_version' "$state_file"
    else
        echo "1.0"
    fi
}

migrate_state_file() {
    local state_file="$1"
    local backup_file="${state_file}.v1.backup"

    echo "Migrating state file from v1.0 to v2.0..." >&2

    # Backup old file
    if ! cp "$state_file" "$backup_file"; then
        echo "Error: Failed to create backup at $backup_file" >&2
        return 1
    fi
    echo "  Created backup: $backup_file" >&2

    # Transform to v2.0 schema
    if ! jq '{
      schema_version: "2.0",
      pr_number: .pr_number,
      repo_owner: .repo_owner,
      repo_name: .repo_name,
      last_review_check: .last_review_check,
      total_feedback_items: 0,
      unaddressed_count: 0,
      addressed_count: 0,
      feedback_items: [],
      migration: {
        migrated_from_version: "1.0",
        migrated_at: (now | todate)
      }
    }' "$state_file" > "${state_file}.tmp"; then
        echo "Error: Failed to transform state file" >&2
        rm -f "${state_file}.tmp"
        return 1
    fi

    if ! mv "${state_file}.tmp" "$state_file"; then
        echo "Error: Failed to replace state file" >&2
        rm -f "${state_file}.tmp"
        return 1
    fi

    echo "  $SUCCESS Migration complete - state file updated to v2.0" >&2
    echo "" >&2
    echo "  NOTE: Migration is one-way. To rollback:" >&2
    echo "    1. Stop any running iterate-pr processes" >&2
    echo "    2. Restore backup: cp $backup_file $state_file" >&2
    echo "    3. Old v1.0 schema will be used (new feedback items will be lost)" >&2
    return 0
}

# Detect schema version and migrate if necessary
SCHEMA_VERSION=$(detect_schema_version "$STATE_FILE")
if [ "$SCHEMA_VERSION" = "1.0" ]; then
    if ! migrate_state_file "$STATE_FILE"; then
        echo "Error: Schema migration failed" >&2
        exit 2
    fi
fi

# ============================================================================
# Author Classification
# ============================================================================

# shellcheck disable=SC2317  # Function is embedded in jq code, not called directly
classify_author() {
    local login="$1"
    # Return format: "author_type|bot_name"
    # Examples: "bot|copilot", "bot|claude", "bot|github-actions", "human|"
    case "$login" in
        "copilot-pull-request-reviewer[bot]"|"Copilot")
            echo "bot|copilot" ;;
        "claude[bot]")
            echo "bot|claude" ;;
        "github-actions[bot]")
            echo "bot|github-actions" ;;
        *"[bot]")
            echo "bot|unknown" ;;
        *)
            echo "human|" ;;
    esac
}

# ============================================================================
# GraphQL Feedback Fetching
# ============================================================================

fetch_all_feedback() {
    local repo_owner="$1"
    local repo_name="$2"
    local pr_number="$3"

    # Use GraphQL to fetch ALL feedback (no timestamp filtering)
    # This includes: reviews, review threads, review comments, issue comments
    # Pagination: Currently fetches first 100 items of each type
    # TODO: Implement pagination for PRs with >100 items (future enhancement)

    # shellcheck disable=SC2016  # Intentional: GraphQL query uses literal string, not variable expansion
    gh api graphql -f query='
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviews(first: 100) {
            nodes {
              id
              databaseId
              author { login }
              state
              body
              submittedAt
              updatedAt
            }
          }
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              isOutdated
              resolvedBy { login }
              comments(first: 50) {
                nodes {
                  id
                  databaseId
                  body
                  author { login }
                  createdAt
                  updatedAt
                  path
                  line
                }
              }
            }
          }
          comments(first: 100) {
            nodes {
              id
              databaseId
              author { login }
              body
              createdAt
              updatedAt
            }
          }
        }
      }
    }' \
    -f owner="$repo_owner" \
    -f name="$repo_name" \
    -F number="$pr_number" \
    --jq '.data.repository.pullRequest' 2>/dev/null || echo '{}'
}

# ============================================================================
# Feedback Item Synchronization
# ============================================================================

sync_feedback_items() {
    local fetched_data="$1"
    local state_file="$2"
    local repo_owner="$3"
    local repo_name="$4"
    local pr_number="$5"
    local tmp_file
    tmp_file=$(mktemp)

    # Embed classify_author logic into jq for author classification
    # This function will be called for each feedback item
    # Note: GraphQL API returns author.login without [bot] suffix, unlike REST API
    local classify_jq='
        def classify_author:
            if . == "copilot-pull-request-reviewer[bot]" or . == "copilot-pull-request-reviewer" or . == "Copilot" then
                {type: "bot", name: "copilot"}
            elif . == "claude[bot]" or . == "claude" then
                {type: "bot", name: "claude"}
            elif . == "github-actions[bot]" or . == "github-actions" then
                {type: "bot", name: "github-actions"}
            elif (. // "") | endswith("[bot]") then
                {type: "bot", name: "unknown"}
            else
                {type: "human", name: null}
            end;
    '

    # Transform GraphQL response into standardized feedback items
    # Handle reviews, review comments, and issue comments
    echo "$fetched_data" | jq --arg repo_owner "$repo_owner" \
                               --arg repo_name "$repo_name" \
                               --argjson pr_number "$pr_number" \
                               --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                               "$classify_jq"'
        # Build lookup map of existing items from state file
        {} as $existing_map |

        # Transform reviews into feedback items
        ((.reviews.nodes // []) | map({
            item_id: ("review_" + (.databaseId | tostring)),
            item_type: "review",
            github_id: .databaseId,
            author: .author.login,
            author_info: (.author.login | classify_author),
            created_at: .submittedAt,
            updated_at: .updatedAt,
            body: .body,
            url: ("https://github.com/\($repo_owner)/\($repo_name)/pull/\($pr_number)#pullrequestreview-" + (.databaseId | tostring)),
            state: .state,
            path: null,
            line: null,
            github_resolved: false,
            sub_items: []
        })) as $reviews |

        # Transform review comments (from review threads)
        ((.reviewThreads.nodes // []) | map(.comments.nodes // []) | flatten | map({
            item_id: ("review_comment_" + (.databaseId | tostring)),
            item_type: "review_comment",
            github_id: .databaseId,
            author: .author.login,
            author_info: (.author.login | classify_author),
            created_at: .createdAt,
            updated_at: .updatedAt,
            body: .body,
            url: ("https://github.com/\($repo_owner)/\($repo_name)/pull/\($pr_number)#discussion_r" + (.databaseId | tostring)),
            state: null,
            path: .path,
            line: .line,
            github_resolved: false,  # Will be set from thread data in future enhancement
            sub_items: []
        })) as $review_comments |

        # Transform issue comments
        ((.comments.nodes // []) | map({
            item_id: ("issue_comment_" + (.databaseId | tostring)),
            item_type: "issue_comment",
            github_id: .databaseId,
            author: .author.login,
            author_info: (.author.login | classify_author),
            created_at: .createdAt,
            updated_at: .updatedAt,
            body: .body,
            url: ("https://github.com/\($repo_owner)/\($repo_name)/pull/\($pr_number)#issuecomment-" + (.databaseId | tostring)),
            state: null,
            path: null,
            line: null,
            github_resolved: false,
            sub_items: []
        })) as $issue_comments |

        # Combine all feedback items
        ($reviews + $review_comments + $issue_comments) as $all_fetched |

        # Set author_type and bot_name from author_info
        ($all_fetched | map(
            . + {
                author_type: .author_info.type,
                bot_name: .author_info.name
            } | del(.author_info)
        ))
    ' > "${tmp_file}.fetched" || {
        echo "Error: Failed to transform fetched feedback" >&2
        rm -f "$tmp_file" "${tmp_file}.fetched"
        return 1
    }

    # Read current state and merge with fetched items
    jq --slurpfile fetched "${tmp_file}.fetched" \
       --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '
        # Build lookup map of existing items
        (.feedback_items | map({(.item_id): .}) | add // {}) as $existing |

        # Process fetched items
        ($fetched[0] | map(
            . as $item |
            ($existing[$item.item_id]) as $existing_item |

            # If exists, preserve status and tracking info; else set defaults
            $item + {
                status: ($existing_item.status // "unaddressed"),
                addressed_at: ($existing_item.addressed_at // null),
                addressed_by_commit: ($existing_item.addressed_by_commit // null),
                first_seen: ($existing_item.first_seen // $now),
                sub_items: ($existing_item.sub_items // [])
            }
        )) as $merged |

        # Update state with merged items and recalculate counts
        .feedback_items = $merged |
        .total_feedback_items = ($merged | length) |
        .unaddressed_count = ($merged | map(select(.status == "unaddressed")) | length) |
        .addressed_count = ($merged | map(select(.status == "addressed")) | length) |
        .last_updated = $now
    ' "$state_file" > "$tmp_file" || {
        echo "Error: Failed to merge feedback items" >&2
        rm -f "$tmp_file" "${tmp_file}.fetched"
        return 1
    }

    # Replace state file
    mv "$tmp_file" "$state_file" || {
        echo "Error: Failed to update state file" >&2
        rm -f "$tmp_file" "${tmp_file}.fetched"
        return 1
    }

    # Cleanup temp files
    rm -f "${tmp_file}.fetched"
    return 0
}

# Get repository info from state file
REPO_OWNER=$(jq -r '.repo_owner // empty' "$STATE_FILE" 2>/dev/null || echo "")
REPO_NAME=$(jq -r '.repo_name // empty' "$STATE_FILE" 2>/dev/null || echo "")

# Fallback to gh repo view if not in state
if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    REPO_OWNER=$(gh repo view --json owner -q '.owner.login' 2>/dev/null || echo "")
    REPO_NAME=$(gh repo view --json name -q '.name' 2>/dev/null || echo "")
fi

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    echo "Error: Could not determine repository" >&2
    exit 2
fi

# ============================================================================
# Fetch and Sync Feedback Items
# ============================================================================

echo "Fetching all feedback for PR #$PR_NUMBER..." >&2

# Fetch ALL feedback from GitHub (no timestamp filtering)
FEEDBACK_DATA=$(fetch_all_feedback "$REPO_OWNER" "$REPO_NAME" "$PR_NUMBER")

if [ -z "$FEEDBACK_DATA" ] || [ "$FEEDBACK_DATA" = "{}" ]; then
    echo "Warning: Failed to fetch feedback or PR not found" >&2
    # Don't exit - continue with empty feedback data
    FEEDBACK_DATA='{}'
fi

# Use file locking for state file update
LOCK_FILE="${STATE_FILE}.lock"

# Cleanup lock on exit
# shellcheck disable=SC2317  # Function is invoked by trap, not directly called
cleanup_lock() {
    rmdir "$LOCK_FILE" 2>/dev/null || true
}
trap cleanup_lock EXIT

# Acquire lock with timeout (max 10 seconds)
LOCK_SLEEP=0.1
LOCK_MAX_ATTEMPTS=100  # 100 iterations * 0.1s = 10 seconds
LOCK_ATTEMPTS=0

while ! mkdir "$LOCK_FILE" 2>/dev/null; do
    LOCK_ATTEMPTS=$((LOCK_ATTEMPTS + 1))
    if [ "$LOCK_ATTEMPTS" -ge "$LOCK_MAX_ATTEMPTS" ]; then
        echo "Error: Could not acquire lock after 10 seconds" >&2
        echo "  Lock file: $LOCK_FILE" >&2
        exit 3
    fi
    sleep "$LOCK_SLEEP"
done

# Sync feedback items with state file
echo "Syncing feedback items with state file..." >&2
if ! sync_feedback_items "$FEEDBACK_DATA" "$STATE_FILE" "$REPO_OWNER" "$REPO_NAME" "$PR_NUMBER"; then
    echo "Error: Failed to sync feedback items" >&2
    exit 3
fi

# Read updated counts from state file
UNADDRESSED_COUNT=$(jq -r '.unaddressed_count // 0' "$STATE_FILE")
TOTAL_FEEDBACK=$(jq -r '.total_feedback_items // 0' "$STATE_FILE")

echo "  Found $TOTAL_FEEDBACK total feedback items" >&2
echo "  Unaddressed: $UNADDRESSED_COUNT" >&2

# Warn if approaching GraphQL pagination limit
if [ "$TOTAL_FEEDBACK" -ge 95 ]; then
    echo "" >&2
    echo "  ⚠️  WARNING: Approaching GraphQL pagination limit (100 items)" >&2
    echo "     Current count: $TOTAL_FEEDBACK items" >&2
    echo "     Some feedback may not be fetched if limit is exceeded" >&2
    echo "     Consider implementing pagination or archiving old items" >&2
fi

# ============================================================================
# CI/CD Status Check (CRITICAL - MUST DETECT FAILING CHECKS)
# ============================================================================

echo "Checking CI status for PR #$PR_NUMBER..." >&2

# Get PR head SHA
HEAD_SHA=$(gh api "repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER" --jq '.head.sha' 2>/dev/null || echo "")

if [ -z "$HEAD_SHA" ]; then
    echo "Warning: Could not get HEAD SHA for PR #$PR_NUMBER" >&2
    CI_FAILING=0
    CI_WARNINGS=0
elif [[ ! "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "Warning: Invalid HEAD SHA format: $HEAD_SHA" >&2
    CI_FAILING=0
    CI_WARNINGS=0
else
    # Get all check runs for this commit
    # CRITICAL: Fail-safe - if API fails, we MUST NOT assume "all clear"
    CI_API_FAILED=0
    if ! CHECK_RUNS=$(gh api "repos/$REPO_OWNER/$REPO_NAME/commits/$HEAD_SHA/check-runs" --jq '.check_runs' 2>&1); then
        echo "  $FAILURE CRITICAL: Failed to fetch check-runs from GitHub API" >&2
        echo "    API Error: $CHECK_RUNS" >&2
        echo "    FAIL-SAFE: Assuming CI checks are failing (cannot verify)" >&2
        CI_API_FAILED=1
        CHECK_RUNS="[]"
    fi

    # Validate JSON structure (FAIL-SAFE: treat invalid response as API failure)
    if ! echo "$CHECK_RUNS" | jq -e '. | type == "array"' >/dev/null 2>&1; then
        echo "  $FAILURE CRITICAL: Invalid check-runs response from API" >&2
        echo "    Response: $CHECK_RUNS" >&2
        echo "    FAIL-SAFE: Assuming CI checks are failing (cannot parse)" >&2
        CI_API_FAILED=1
        CHECK_RUNS="[]"
    fi

    # If API failed, treat as failing CI (fail-safe behavior)
    # We cannot verify CI status, so we must trigger iteration
    if [ "$CI_API_FAILED" -eq 1 ]; then
        CI_FAILING=1  # Cannot verify = assume failing (fail-safe)
        CI_PENDING=0
        TOTAL_CHECKS=0
    else
        # Count failing checks
        if ! CI_FAILING=$(echo "$CHECK_RUNS" | jq '[.[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out")] | length' 2>&1); then
            echo "Warning: Failed to parse check-runs with jq: $CI_FAILING" >&2
            CI_FAILING=0
        fi

        # Count pending/in-progress checks (CRITICAL - prevents premature "ready to merge")
        if ! CI_PENDING=$(echo "$CHECK_RUNS" | jq '[.[] | select(.status == "queued" or .status == "in_progress" or .status == "pending" or .status == "waiting")] | length' 2>&1); then
            echo "Warning: Failed to parse pending checks: $CI_PENDING" >&2
            CI_PENDING=0
        fi

        # Count total checks
        TOTAL_CHECKS=$(echo "$CHECK_RUNS" | jq 'length' || echo "0")
    fi

    # Count checks with warnings (even if they passed)
    # TODO (FUTURE WORK): Implement warning detection by parsing check-run logs
    # This requires fetching job logs via Actions API and scanning for patterns:
    #   - pytest: "PytestWarning:", "DeprecationWarning:"
    #   - ruff: non-blocking warnings
    #   - mypy: "note:" messages
    # Implementation plan:
    #   1. Fetch job logs via gh api repos/{owner}/{repo}/actions/jobs/{job_id}/logs
    #   2. Parse logs with grep/awk for warning patterns
    #   3. Count distinct warnings and update CI_WARNINGS
    # Status: Deferred to Phase 6 (future enhancement) - not blocking for MVP
    # For now, CI_WARNINGS is always 0
    CI_WARNINGS=0

    # Report CI status
    if [ "$CI_API_FAILED" -eq 1 ]; then
        # API failed, cannot verify status
        echo "  $FAILURE CANNOT VERIFY CI STATUS - API Error" >&2
        echo "    This PR should NOT be declared ready until CI status can be verified" >&2
    elif [ "$CI_FAILING" -gt 0 ]; then
        echo "  $FAILURE Found $CI_FAILING failing CI check(s)" >&2
        # Log details of failing checks
        echo "$CHECK_RUNS" | jq -r '.[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out") | "    - \(.name): \(.conclusion)"' >&2
    elif [ "$CI_PENDING" -gt 0 ]; then
        echo "  ⏳ $CI_PENDING CI check(s) still pending/in-progress" >&2
        # Log details of pending checks
        echo "$CHECK_RUNS" | jq -r '.[] | select(.status == "queued" or .status == "in_progress" or .status == "pending" or .status == "waiting") | "    - \(.name): \(.status)"' >&2
    elif [ "$TOTAL_CHECKS" -eq 0 ]; then
        echo "  ⚠️  Warning: No CI checks configured for this PR" >&2
    else
        echo "  $SUCCESS All CI checks passing ($TOTAL_CHECKS checks)" >&2
    fi

    # Check for warnings in logs (even for passing checks)
    # Look for common warning patterns: pytest warnings, ruff warnings, mypy warnings
    # This is complex and may require separate enhancement
fi

# ============================================================================
# Determine if iteration needed
# ============================================================================

SHOULD_ITERATE=0
REASONS=()

# Count-based iteration detection (not timestamp-based)
# This ensures unaddressed feedback is never lost

if [ "$UNADDRESSED_COUNT" -gt 0 ]; then
    SHOULD_ITERATE=1
    REASONS+=("$UNADDRESSED_COUNT unaddressed feedback item(s)")
fi

if [ "$CI_FAILING" -gt 0 ]; then
    SHOULD_ITERATE=1
    REASONS+=("$CI_FAILING failing CI check(s)")
fi

# CRITICAL: Pending checks block merge - must wait for completion
if [ "${CI_PENDING:-0}" -gt 0 ]; then
    SHOULD_ITERATE=1
    REASONS+=("$CI_PENDING pending/in-progress CI check(s) - waiting for completion")
fi

if [ "$CI_WARNINGS" -gt 0 ]; then
    SHOULD_ITERATE=1
    REASONS+=("$CI_WARNINGS CI warning(s)")
fi

# Output summary
if [ "$SHOULD_ITERATE" -eq 1 ]; then
    echo "$SUCCESS Iteration needed for PR #$PR_NUMBER"
    echo ""
    echo "Reasons:"
    for reason in "${REASONS[@]}"; do
        echo "  - $reason"
    done
    echo ""
    echo "Details:"
    echo "  - Total feedback items: $TOTAL_FEEDBACK"
    echo "  - Unaddressed items: $UNADDRESSED_COUNT"
    echo "  - Failing CI checks: $CI_FAILING"
    echo "  - Pending CI checks: ${CI_PENDING:-0}"
    echo "  - CI warnings: $CI_WARNINGS"
    exit 0
else
    echo "No iteration needed for PR #$PR_NUMBER"
    echo "  - All feedback addressed ($TOTAL_FEEDBACK items)"
    echo "  - All CI checks complete and passing"
    echo "  - No pending or failing checks"
    echo "  - No warnings detected"
    exit 1
fi
