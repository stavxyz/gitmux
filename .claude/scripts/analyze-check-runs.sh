#!/bin/bash
# Analyze check-runs for a PR and output failing checks to stderr
#
# Current functionality:
#   - Detects failing/cancelled/timed_out checks via GitHub API
#   - Outputs check names, conclusions, and URLs to stderr
#   - Returns exit code 4 on API failures, 2 on invalid input
#
# Planned enhancements (Phase 6):
#   - Parse check-run logs for specific error patterns
#   - Extract pytest failures, ruff errors, mypy warnings
#   - Requires additional GitHub Actions API permissions
#   - See lines 57-60 for implementation notes
#
# Usage:
#   bash analyze-check-runs.sh <pr-number>

set -euo pipefail

PR_NUMBER="${1:-}"
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <pr-number>" >&2
    exit 2
fi

# Get repo info
REPO_OWNER=$(gh repo view --json owner -q '.owner.login')
REPO_NAME=$(gh repo view --json name -q '.name')

if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
    echo "Error: Could not determine repository" >&2
    exit 2
fi

# Get PR head SHA
HEAD_SHA=$(gh api "repos/$REPO_OWNER/$REPO_NAME/pulls/$PR_NUMBER" --jq '.head.sha')

# Validate SHA format
if [[ ! "$HEAD_SHA" =~ ^[0-9a-f]{40}$ ]]; then
    echo "Error: Invalid HEAD SHA: $HEAD_SHA" >&2
    exit 2
fi

# Get all check runs
if ! CHECK_RUNS=$(gh api "repos/$REPO_OWNER/$REPO_NAME/commits/$HEAD_SHA/check-runs" --jq '.check_runs' 2>&1); then
    echo "Error: Failed to fetch check-runs: $CHECK_RUNS" >&2
    exit 4
fi

# Output failing checks with structured information
# Use process substitution instead of pipeline to avoid subshell issues
while read -r check; do
    CHECK_NAME=$(echo "$check" | jq -r '.name')
    CHECK_CONCLUSION=$(echo "$check" | jq -r '.conclusion')
    CHECK_URL=$(echo "$check" | jq -r '.html_url')

    echo "=== $CHECK_NAME ($CHECK_CONCLUSION) ===" >&2
    echo "URL: $CHECK_URL" >&2

    # Fetch check details from gh pr checks for summary
    if ! gh pr checks "$PR_NUMBER" --json name,conclusion,detailsUrl \
        --jq ".[] | select(.name == \"$CHECK_NAME\")" 2>/dev/null; then
        echo "Warning: Failed to fetch check details for '$CHECK_NAME'" >&2
    fi

    echo "" >&2
done < <(echo "$CHECK_RUNS" | jq -c '.[] | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out")')

# Note: Detailed log parsing (pytest FAILED, ruff errors, mypy errors) would require
# fetching job logs via Actions API or parsing check run output, which requires
# additional API permissions. For now, check details URL provides human access to logs.
# Future enhancement: Implement pattern matching for common CI tools (pytest, ruff, mypy)
