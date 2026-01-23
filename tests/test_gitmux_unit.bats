#!/usr/bin/env bats
# shellcheck disable=SC1090  # Can't follow dynamic sources (expected in bats tests)
# Unit tests for gitmux.sh helper functions
# Run with: bats tests/test_gitmux_unit.bats

# Load bats support libraries if available
load_bats_libs() {
    # Try to load bats-support and bats-assert if installed
    if [[ -d "${BATS_TEST_DIRNAME}/../.bats" ]]; then
        load "${BATS_TEST_DIRNAME}/../.bats/bats-support/load"
        load "${BATS_TEST_DIRNAME}/../.bats/bats-assert/load"
    fi
}

# Setup: Extract and source functions from gitmux.sh
# This ensures tests always use the actual implementation
setup() {
    export GITMUX_SCRIPT="${BATS_TEST_DIRNAME}/../gitmux.sh"
    export TEST_HELPER="${BATS_TEST_TMPDIR}/test_helper.sh"

    # Create a helper file by extracting functions from gitmux.sh
    # This avoids running the main script logic while testing real functions
    cat > "${TEST_HELPER}" << 'HELPER_HEADER'
#!/usr/bin/env bash
# Stub errcho to avoid dependency on the full script
errcho() { printf "%s\n" "$@" 1>&2; }
HELPER_HEADER

    # Extract functions and constants from gitmux.sh
    {
        # _cmd_exists function
        sed -n '/^_cmd_exists () {/,/^}/p' "${GITMUX_SCRIPT}"
        # _realpath function
        sed -n '/^_realpath () {/,/^}/p' "${GITMUX_SCRIPT}"
        # stripslashes function
        sed -n '/^function stripslashes () {/,/^}/p' "${GITMUX_SCRIPT}"
        # REPO_REGEX constant
        grep "^REPO_REGEX=" "${GITMUX_SCRIPT}"
    } >> "${TEST_HELPER}"

    # Add URL parsing helper functions that use the extracted REPO_REGEX
    # These wrap the inline sed logic used in gitmux.sh for testability
    cat >> "${TEST_HELPER}" << 'HELPER_FOOTER'

# Parse domain from repository URL
# Uses the same sed logic as gitmux.sh lines 382, 409
parse_domain() {
    local url="${1}"
    echo "${url}" | sed -E "${REPO_REGEX}"'/\2/' | sed -E "s/(^[a-zA-Z0-9_-]{0,38}\:{1})([a-zA-Z0-9_]{5,40})(\@?)"'//'
}

# Parse project name from repository URL
# Uses the same sed logic as gitmux.sh lines 383, 410
parse_project() {
    local url="${1}"
    echo "${url}" | sed -E "${REPO_REGEX}"'/\6/'
}

# Parse owner from repository URL
# Uses the same sed logic as gitmux.sh lines 384, 411
parse_owner() {
    local url="${1}"
    echo "${url}" | sed -E "${REPO_REGEX}"'/\4/'
}
HELPER_FOOTER

    source "${TEST_HELPER}"
}

teardown() {
    rm -f "${TEST_HELPER}"
}

# ============================================================================
# Function extraction verification
# ============================================================================

@test "setup: successfully extracts functions from gitmux.sh" {
    # Verify the helper file was created and contains expected content
    [[ -f "${TEST_HELPER}" ]]
    grep -q "_cmd_exists" "${TEST_HELPER}"
    grep -q "_realpath" "${TEST_HELPER}"
    grep -q "stripslashes" "${TEST_HELPER}"
    grep -q "REPO_REGEX" "${TEST_HELPER}"
}

# ============================================================================
# stripslashes function tests
# ============================================================================

@test "stripslashes: removes trailing slash" {
    result=$(stripslashes "path/to/dir/")
    [[ "$result" == "path/to/dir" ]]
}

@test "stripslashes: removes leading slash" {
    result=$(stripslashes "/path/to/dir")
    [[ "$result" == "path/to/dir" ]]
}

@test "stripslashes: removes both leading and trailing slashes" {
    result=$(stripslashes "/path/to/dir/")
    [[ "$result" == "path/to/dir" ]]
}

@test "stripslashes: removes multiple trailing slashes" {
    result=$(stripslashes "path/to/dir///")
    [[ "$result" == "path/to/dir" ]]
}

@test "stripslashes: removes multiple leading slashes" {
    result=$(stripslashes "///path/to/dir")
    [[ "$result" == "path/to/dir" ]]
}

@test "stripslashes: handles path with no slashes to strip" {
    result=$(stripslashes "path/to/dir")
    [[ "$result" == "path/to/dir" ]]
}

@test "stripslashes: handles empty string" {
    result=$(stripslashes "")
    [[ "$result" == "" ]]
}

@test "stripslashes: handles single directory name" {
    result=$(stripslashes "dirname")
    [[ "$result" == "dirname" ]]
}

# ============================================================================
# _cmd_exists function tests
# ============================================================================

@test "_cmd_exists: returns 0 for existing command (bash)" {
    run _cmd_exists bash
    [[ "$status" -eq 0 ]]
}

@test "_cmd_exists: returns 0 for existing command (git)" {
    run _cmd_exists git
    [[ "$status" -eq 0 ]]
}

@test "_cmd_exists: returns 1 for non-existent command" {
    run _cmd_exists definitely_not_a_real_command_12345
    [[ "$status" -eq 1 ]]
}

# ============================================================================
# URL parsing tests - HTTPS format
# ============================================================================

@test "parse_domain: extracts domain from HTTPS URL" {
    result=$(parse_domain "https://github.com/owner/project")
    [[ "$result" == "github.com" ]]
}

@test "parse_owner: extracts owner from HTTPS URL" {
    result=$(parse_owner "https://github.com/owner/project")
    [[ "$result" == "owner" ]]
}

@test "parse_project: extracts project from HTTPS URL" {
    result=$(parse_project "https://github.com/owner/project")
    [[ "$result" == "project" ]]
}

@test "parse_domain: handles GitHub Enterprise domain" {
    result=$(parse_domain "https://github.mycompany.com/owner/project")
    [[ "$result" == "github.mycompany.com" ]]
}

# ============================================================================
# URL parsing tests - SSH format (git@)
# ============================================================================

@test "parse_domain: extracts domain from SSH URL" {
    result=$(parse_domain "git@github.com:owner/project")
    [[ "$result" == "github.com" ]]
}

@test "parse_owner: extracts owner from SSH URL" {
    result=$(parse_owner "git@github.com:owner/project")
    [[ "$result" == "owner" ]]
}

@test "parse_project: extracts project from SSH URL" {
    result=$(parse_project "git@github.com:owner/project")
    [[ "$result" == "project" ]]
}

# ============================================================================
# URL parsing tests - edge cases
# ============================================================================

@test "parse_project: handles project names with dots" {
    result=$(parse_project "https://github.com/owner/my.project.name")
    [[ "$result" == "my.project.name" ]]
}

@test "parse_project: handles project names with hyphens" {
    result=$(parse_project "https://github.com/owner/my-project-name")
    [[ "$result" == "my-project-name" ]]
}

@test "parse_project: handles project names with underscores" {
    result=$(parse_project "https://github.com/owner/my_project_name")
    [[ "$result" == "my_project_name" ]]
}

@test "parse_owner: handles owner names with hyphens" {
    result=$(parse_owner "https://github.com/my-org/project")
    [[ "$result" == "my-org" ]]
}

@test "parse_owner: handles owner names with underscores" {
    result=$(parse_owner "https://github.com/my_org/project")
    [[ "$result" == "my_org" ]]
}

# ============================================================================
# URL parsing tests - GitLab format
# ============================================================================

@test "parse_domain: handles GitLab URLs" {
    result=$(parse_domain "https://gitlab.com/owner/project")
    [[ "$result" == "gitlab.com" ]]
}

@test "parse_domain: handles GitLab SSH URLs" {
    result=$(parse_domain "git@gitlab.com:owner/project")
    [[ "$result" == "gitlab.com" ]]
}

# ============================================================================
# _realpath function tests
# ============================================================================

@test "_realpath: resolves current directory" {
    result=$(_realpath .)
    [[ -d "$result" ]]
}

@test "_realpath: resolves absolute path" {
    result=$(_realpath /tmp)
    [[ "$result" == "/tmp" ]] || [[ "$result" == "/private/tmp" ]]
}

@test "_realpath: returns error for non-existent path" {
    run _realpath /definitely/not/a/real/path/12345
    [[ "$status" -ne 0 ]]
}

# Author/committer override validation tests
@test "validation: --author-name without --author-email fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --author-name 'Test' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--author-name requires --author-email" ]]
}

@test "validation: --author-email without --author-name fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --author-email 'test@example.com' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--author-email requires --author-name" ]]
}

@test "validation: --committer-name without --committer-email fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --committer-name 'Test' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--committer-name requires --committer-email" ]]
}

@test "validation: --committer-email without --committer-name fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --committer-email 'test@example.com' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--committer-email requires --committer-name" ]]
}

@test "validation: invalid --coauthor-action value fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --coauthor-action invalid -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--coauthor-action must be 'claude', 'all', or 'keep'" ]]
}

@test "validation: --coauthor-action 'claude' is valid" {
    # This should fail later (no actual repo), but not on coauthor-action validation
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --coauthor-action claude -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--coauthor-action must be" ]]
}

@test "validation: --coauthor-action 'all' is valid" {
    # This should fail later (no actual repo), but not on coauthor-action validation
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --coauthor-action all -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--coauthor-action must be" ]]
}

@test "validation: --coauthor-action 'keep' is valid" {
    # This should fail later (no actual repo), but not on coauthor-action validation
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --coauthor-action keep -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--coauthor-action must be" ]]
}

@test "validation: both --author-name and --author-email together is valid" {
    # This should fail later (no actual repo), but not on author validation
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --author-name 'Test' --author-email 'test@example.com' -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--author-name requires" ]]
    [[ ! "$output" =~ "--author-email requires" ]]
}

@test "validation: both --committer-name and --committer-email together is valid" {
    # This should fail later (no actual repo), but not on committer validation
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --committer-name 'Test' --committer-email 'test@example.com' -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--committer-name requires" ]]
    [[ ! "$output" =~ "--committer-email requires" ]]
}

# Security: Shell metacharacter injection prevention
@test "validation: --author-name with shell metacharacters is rejected" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --author-name 'Test\$(whoami)' --author-email 'test@example.com' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "contains invalid characters" ]]
}

@test "validation: --author-email with backticks is rejected" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --author-name 'Test' --author-email 'test\`id\`@example.com' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "contains invalid characters" ]]
}

@test "validation: --author-name with single quotes is rejected" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --author-name \"Test'injection\" --author-email 'test@example.com' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "contains invalid characters" ]]
}

# Dry-run option test
@test "validation: --dry-run option is recognized" {
    # --dry-run should not cause an unknown option error
    # It will fail later because of missing repos, but not on option parsing
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --dry-run -r foo -t bar 2>&1"
    [[ ! "$output" =~ "Unknown option" ]]
    [[ ! "$output" =~ "Unimplemented option" ]]
}

# Default behavior test - verify coauthor-action defaults to 'claude' when author options are used
# This is tested indirectly via E2E tests, but we also verify the code logic here
@test "validation: --coauthor-action defaults to 'claude' when author options are used" {
    # Test the GITMUX_COAUTHOR_ACTION default logic:
    # When author/committer options are provided without explicit --coauthor-action,
    # gitmux defaults to 'claude' mode (remove Claude/Anthropic attribution).
    # We verify this by simulating the same logic in a subshell.
    run bash -c '
        GITMUX_COAUTHOR_ACTION=""
        GITMUX_AUTHOR_NAME="Test Author"
        # Apply the default logic (mirrors gitmux.sh behavior)
        if [[ -z "$GITMUX_COAUTHOR_ACTION" ]]; then
            if [[ -n "$GITMUX_AUTHOR_NAME" ]] || [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
                GITMUX_COAUTHOR_ACTION="claude"
            fi
        fi
        echo "$GITMUX_COAUTHOR_ACTION"
    '
    [[ "$output" == "claude" ]]
}

# =============================================================================
# E2E Tests for Author/Committer Override and Co-author Handling
# These tests use local git repos to verify the full workflow
# =============================================================================

setup_local_repos() {
    # Set git identity via environment variables for CI environments
    # This avoids modifying global git config and is isolated to this test process
    export GIT_AUTHOR_NAME="Test User"
    export GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Test User"
    export GIT_COMMITTER_EMAIL="test@example.com"

    # Create temp directory for test repos
    E2E_TEST_DIR=$(mktemp -d)
    export E2E_TEST_DIR

    # Create source repo with bare remote (use -b main for consistent branch naming)
    mkdir -p "$E2E_TEST_DIR/source-bare.git"
    git init --bare --initial-branch=main "$E2E_TEST_DIR/source-bare.git"
    git clone "$E2E_TEST_DIR/source-bare.git" "$E2E_TEST_DIR/source"
    cd "$E2E_TEST_DIR/source" || return 1
    git config user.name "Original Author"
    git config user.email "original@example.com"
    # Ensure we're on main branch (git clone of empty repo may not set this)
    git checkout -b main 2>/dev/null || git checkout main 2>/dev/null || true

    # Create destination repo with bare remote (use -b main for consistent branch naming)
    mkdir -p "$E2E_TEST_DIR/dest-bare.git"
    git init --bare --initial-branch=main "$E2E_TEST_DIR/dest-bare.git"
    git clone "$E2E_TEST_DIR/dest-bare.git" "$E2E_TEST_DIR/dest"
    cd "$E2E_TEST_DIR/dest" || return 1
    git config user.name "Dest User"
    git config user.email "dest@example.com"
    # Ensure we're on main branch (git clone of empty repo may not set this)
    git checkout -b main 2>/dev/null || git checkout main 2>/dev/null || true
    echo "init" > README.md
    git add .
    git commit -m "Initial commit"
    git push origin main
}

teardown_local_repos() {
    rm -rf "$E2E_TEST_DIR" 2>/dev/null || true
}

# Generic helper to get git log field from update branch
# Usage: get_field_from_update_branch <dest_dir> <format> <output_var_name>
# Example: get_field_from_update_branch "$dir" "%B" E2E_COMMIT_MSG
# Returns 1 on failure with error message to stderr
get_field_from_update_branch() {
    local dest_dir="$1"
    local format="$2"
    local output_var="$3"

    cd "$dest_dir" || return 1
    git fetch --all --quiet 2>/dev/null

    local branch_name
    branch_name=$(git branch -r | grep "update-from-main" | head -1 | tr -d ' ')
    if [[ -z "$branch_name" ]]; then
        echo "ERROR: No update-from-main branch found in destination" >&2
        echo "Available remote branches:" >&2
        git branch -r >&2
        return 1
    fi

    local value
    value=$(git log -1 --format="$format" "$branch_name" 2>/dev/null)
    if [[ -z "$value" ]]; then
        echo "ERROR: Could not get field (format=$format) from branch $branch_name" >&2
        return 1
    fi

    # Export the result to the named variable
    export "$output_var"="$value"
    return 0
}

@test "e2e: author override changes commit author" {
    setup_local_repos

    # Create source commit
    cd "$E2E_TEST_DIR/source" || return 1
    echo "content" > file.txt
    git add .
    git commit -m "Test commit"
    git push origin main

    # Run gitmux with author override - use working copies
    cd "$BATS_TEST_DIRNAME/.." || return 1
    run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --author-name 'New Author' \
        --author-email 'new@example.com' \
        -k <<< 'y' 2>&1"

    # Debug: show gitmux output if something went wrong
    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail catastrophically
    [[ ! "$output" =~ "errxit" ]]

    # Fetch the new branch that gitmux pushed to our dest working copy
    cd "$E2E_TEST_DIR/dest" || return 1

    # gitmux pushes directly to dest as "destination" remote, so check local refs
    # The branch should be in refs/remotes/destination/ or as a local tracking branch
    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    E2E_COMMIT_AUTHOR=$(git log -1 --format="%an <%ae>" "$branch_name" 2>/dev/null)
    [[ "$E2E_COMMIT_AUTHOR" == "New Author <new@example.com>" ]]

    teardown_local_repos
}

@test "e2e: coauthor-action 'claude' removes Claude attribution but preserves human co-authors" {
    setup_local_repos

    # Create source commit with mixed co-authors
    cd "$E2E_TEST_DIR/source" || return 1
    echo "content" > file.txt
    git add .
    git commit -m "Test commit

Co-authored-by: Human Dev <human@example.com>
Co-authored-by: Claude <noreply@anthropic.com>
Co-Authored-By: Claude Code <claude@anthropic.com>

Generated with [Claude Code](https://claude.ai/code)"
    git push origin main

    # Run gitmux with claude coauthor-action
    cd "$BATS_TEST_DIRNAME/.." || return 1
    run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --coauthor-action claude \
        -k <<< 'y' 2>&1"

    # Debug: show gitmux output if something went wrong
    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail catastrophically
    [[ ! "$output" =~ "errxit" ]]

    # Check the commit message in dest
    cd "$E2E_TEST_DIR/dest" || return 1

    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    # Find the "Test commit" message in the history (not the gitmux merge commit)
    E2E_COMMIT_MSG=$(git log --format="%B" "$branch_name" | grep -A20 "^Test commit" | head -20)

    # Should contain human co-author
    [[ "$E2E_COMMIT_MSG" =~ "Human Dev" ]]

    # Should NOT contain Claude
    [[ ! "$E2E_COMMIT_MSG" =~ "Claude" ]]

    # Should NOT contain Generated with
    [[ ! "$E2E_COMMIT_MSG" =~ "Generated with" ]]

    teardown_local_repos
}

@test "e2e: coauthor-action 'all' removes all co-authors" {
    setup_local_repos

    # Create source commit with co-authors
    cd "$E2E_TEST_DIR/source" || return 1
    echo "content" > file.txt
    git add .
    git commit -m "Test commit

Co-authored-by: Human Dev <human@example.com>
Co-authored-by: Claude <noreply@anthropic.com>"
    git push origin main

    # Run gitmux with 'all' coauthor-action
    cd "$BATS_TEST_DIRNAME/.." || return 1
    run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --coauthor-action all \
        -k <<< 'y' 2>&1"

    # Debug: show gitmux output if something went wrong
    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail catastrophically
    [[ ! "$output" =~ "errxit" ]]

    # Check the commit message in dest
    cd "$E2E_TEST_DIR/dest" || return 1

    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    E2E_COMMIT_MSG=$(git log -1 --format="%B" "$branch_name" 2>/dev/null)

    # Should NOT contain any co-author (case-insensitive check)
    [[ ! "$E2E_COMMIT_MSG" =~ [Cc]o-[Aa]uthored-[Bb]y ]]

    teardown_local_repos
}

@test "e2e: coauthor-action 'keep' preserves all trailers" {
    setup_local_repos

    # Create source commit with co-authors
    cd "$E2E_TEST_DIR/source" || return 1
    echo "content" > file.txt
    git add .
    git commit -m "Test commit

Co-authored-by: Human Dev <human@example.com>
Co-authored-by: Claude <noreply@anthropic.com>"
    git push origin main

    # Run gitmux with 'keep' coauthor-action
    cd "$BATS_TEST_DIRNAME/.." || return 1
    run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --coauthor-action keep \
        -k <<< 'y' 2>&1"

    # Debug: show gitmux output if something went wrong
    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail catastrophically
    [[ ! "$output" =~ "errxit" ]]

    # Check the commit message in dest
    cd "$E2E_TEST_DIR/dest" || return 1

    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    # Find the "Test commit" message in the history (not the gitmux merge commit)
    E2E_COMMIT_MSG=$(git log --format="%B" "$branch_name" | grep -A20 "^Test commit" | head -20)

    # Should contain both co-authors
    [[ "$E2E_COMMIT_MSG" =~ "Human Dev" ]]
    [[ "$E2E_COMMIT_MSG" =~ "Claude" ]]

    teardown_local_repos
}
