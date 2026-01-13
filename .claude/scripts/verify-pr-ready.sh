#!/bin/bash
# Verify PR is truly ready for merge
# Returns exit code 0 if ready, 1 if not ready, 2 on error
#
# This script checks ABSOLUTE STATE, not just changes since last check:
#   - ALL CI checks must have conclusion == "success"
#   - NO checks can be pending/in-progress
#   - NO checks can be failing
#
# Usage:
#   bash verify-pr-ready.sh <pr-number>
#
# Exit codes:
#   0 = PR is ready (all checks passing, no pending)
#   1 = PR is NOT ready (checks failing or pending)
#   2 = Error (cannot determine status)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Emoji toggle (set NO_EMOJI=1 to disable emoji output)
if [ "${NO_EMOJI:-0}" = "1" ]; then
    readonly SUCCESS="[OK]"
    readonly FAILURE="[FAIL]"
    readonly WARNING="[WARN]"
    readonly PENDING="[WAIT]"
else
    readonly SUCCESS="✅"
    readonly FAILURE="❌"
    readonly WARNING="⚠️"
    readonly PENDING="⏳"
fi

# ============================================================================
# Arguments
# ============================================================================

PR_NUMBER="${1:-}"

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <pr-number>" >&2
    exit 2
fi

# ============================================================================
# Get Repository Info
# ============================================================================

echo "Verifying PR #$PR_NUMBER is ready for merge..." >&2

REPO_OWNER=$(gh repo view --json owner -q '.owner.login' 2>/dev/null || echo "")
REPO_NAME=$(gh repo view --json name -q '.name' 2>/dev/null || echo "")

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    echo "$FAILURE Error: Could not determine repository" >&2
    echo "  Make sure you're in a git repository with GitHub remote" >&2
    exit 2
fi

echo "  Repository: $REPO_OWNER/$REPO_NAME" >&2

# ============================================================================
# Get PR Head SHA
# ============================================================================

if ! HEAD_SHA=$(gh api "repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER" --jq '.head.sha' 2>&1); then
    echo "$FAILURE Error: Could not fetch PR #$PR_NUMBER" >&2
    echo "  API Error: $HEAD_SHA" >&2
    exit 2
fi

# Validate SHA format (hexadecimal: 0-9, a-f)
if [[ ! "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "$FAILURE Error: Invalid HEAD SHA format: $HEAD_SHA" >&2
    exit 2
fi

echo "  HEAD SHA: ${HEAD_SHA:0:8}" >&2

# ============================================================================
# Fetch Check Runs (CRITICAL - MUST NOT FAIL SILENTLY)
# ============================================================================

if ! CHECK_RUNS=$(gh api "repos/$REPO_OWNER/$REPO_NAME/commits/$HEAD_SHA/check-runs" --jq '.check_runs' 2>&1); then
    echo "$FAILURE Error: Failed to fetch check-runs from GitHub API" >&2
    echo "  API Error: $CHECK_RUNS" >&2
    echo "  This could be due to:" >&2
    echo "    - Network issues" >&2
    echo "    - Permission issues (gh auth status)" >&2
    echo "    - Invalid PR number" >&2
    echo "" >&2
    echo "  CRITICAL: Cannot verify CI status - assuming PR NOT ready" >&2
    exit 2
fi

# Validate JSON structure (FAIL-SAFE: assume not ready if invalid)
if ! echo "$CHECK_RUNS" | jq -e '. | type == "array"' >/dev/null 2>&1; then
    echo "$FAILURE Error: Invalid check-runs response from GitHub API" >&2
    echo "  Response: $CHECK_RUNS" >&2
    echo "  CRITICAL: Cannot parse CI status - assuming PR NOT ready" >&2
    exit 2
fi

# ============================================================================
# Analyze Check Runs
# ============================================================================

# Count total checks
TOTAL_CHECKS=$(echo "$CHECK_RUNS" | jq 'length' 2>/dev/null || echo "0")

# Count checks by status
if ! PASSING_CHECKS=$(echo "$CHECK_RUNS" | jq '[.[] | select(.conclusion == "success")] | length' 2>&1); then
    echo "$WARNING Warning: Failed to count passing checks: $PASSING_CHECKS" >&2
    PASSING_CHECKS=0
fi

if ! FAILING_CHECKS=$(echo "$CHECK_RUNS" | jq '[.[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out")] | length' 2>&1); then
    echo "$WARNING Warning: Failed to count failing checks: $FAILING_CHECKS" >&2
    FAILING_CHECKS=0
fi

if ! PENDING_CHECKS=$(echo "$CHECK_RUNS" | jq '[.[] | select(.status == "queued" or .status == "in_progress" or .status == "pending" or .status == "waiting")] | length' 2>&1); then
    echo "$WARNING Warning: Failed to count pending checks: $PENDING_CHECKS" >&2
    PENDING_CHECKS=0
fi

if ! SKIPPED_CHECKS=$(echo "$CHECK_RUNS" | jq '[.[] | select(.conclusion == "skipped")] | length' 2>&1); then
    echo "$WARNING Warning: Failed to count skipped checks: $SKIPPED_CHECKS" >&2
    SKIPPED_CHECKS=0
fi

# ============================================================================
# Report Status
# ============================================================================

echo "" >&2
echo "CI Status Summary:" >&2
echo "  Total checks: $TOTAL_CHECKS" >&2
echo "  $SUCCESS Passing: $PASSING_CHECKS" >&2
echo "  $FAILURE Failing: $FAILING_CHECKS" >&2
echo "  $PENDING Pending: $PENDING_CHECKS" >&2
echo "  Skipped: $SKIPPED_CHECKS" >&2
echo "" >&2

# ============================================================================
# Determine Ready Status
# ============================================================================

READY=1  # Assume NOT ready
BLOCKERS=()

# Check for failing checks
if [ "$FAILING_CHECKS" -gt 0 ]; then
    BLOCKERS+=("$FAILING_CHECKS failing check(s)")
    echo "$FAILURE BLOCKER: $FAILING_CHECKS check(s) failing" >&2

    # List failing checks
    echo "$CHECK_RUNS" | jq -r '.[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out") | "    - \(.name): \(.conclusion)"' >&2
    echo "" >&2
fi

# Check for pending checks
if [ "$PENDING_CHECKS" -gt 0 ]; then
    BLOCKERS+=("$PENDING_CHECKS pending check(s)")
    echo "$PENDING BLOCKER: $PENDING_CHECKS check(s) still running" >&2

    # List pending checks
    echo "$CHECK_RUNS" | jq -r '.[] | select(.status == "queued" or .status == "in_progress" or .status == "pending" or .status == "waiting") | "    - \(.name): \(.status)"' >&2
    echo "" >&2
fi

# Check for no checks configured
if [ "$TOTAL_CHECKS" -eq 0 ]; then
    BLOCKERS+=("no CI checks configured")
    echo "$WARNING BLOCKER: No CI checks configured for this PR" >&2
    echo "  This is unusual - most PRs should have automated checks" >&2
    echo "  Verify this is expected before merging" >&2
    echo "" >&2
fi

# Check if all non-skipped checks are passing
# Ready condition: All non-skipped checks passed AND no failures AND no pending
NON_SKIPPED=$((TOTAL_CHECKS - SKIPPED_CHECKS))
if [ "$NON_SKIPPED" -gt 0 ] && [ "$PASSING_CHECKS" -eq "$NON_SKIPPED" ] && [ "$FAILING_CHECKS" -eq 0 ] && [ "$PENDING_CHECKS" -eq 0 ]; then
    READY=0  # PR is ready!
fi

# ============================================================================
# Exit with Result
# ============================================================================

if [ "$READY" -eq 0 ]; then
    echo "$SUCCESS PR #$PR_NUMBER is ready for merge!" >&2
    echo "  All $PASSING_CHECKS check(s) passing" >&2
    echo "  No failing or pending checks" >&2
    exit 0
else
    echo "$FAILURE PR #$PR_NUMBER is NOT ready for merge" >&2
    echo "" >&2
    echo "Blockers:" >&2
    for blocker in "${BLOCKERS[@]}"; do
        echo "  - $blocker" >&2
    done
    echo "" >&2
    echo "DO NOT declare this PR ready until all blockers are resolved!" >&2
    exit 1
fi
