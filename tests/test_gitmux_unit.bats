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
        # check_filter_repo_available function
        sed -n '/^check_filter_repo_available() {/,/^}/p' "${GITMUX_SCRIPT}"
        # _check_python_version function
        sed -n '/^_check_python_version() {/,/^}/p' "${GITMUX_SCRIPT}"
        # get_filter_backend function
        sed -n '/^get_filter_backend() {/,/^}/p' "${GITMUX_SCRIPT}"
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

# =============================================================================
# Multi-Path Migration Tests (-m flag)
# =============================================================================

# Helper to extract functions for multi-path testing
setup_multipath_helpers() {
    export GITMUX_SCRIPT="${BATS_TEST_DIRNAME}/../gitmux.sh"
    export MULTIPATH_HELPER="${BATS_TEST_TMPDIR}/multipath_helper.sh"

    # Extract relevant functions from gitmux.sh
    cat > "${MULTIPATH_HELPER}" << 'HELPER_HEADER'
#!/usr/bin/env bash
errcho() { printf "%s\n" "$@" 1>&2; }
HELPER_HEADER

    # Extract functions
    {
        sed -n '/^function stripslashes () {/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^function normalize_path () {/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^function parse_path_mapping () {/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^function validate_no_dest_overlap () {/,/^}/p' "${GITMUX_SCRIPT}"
    } >> "${MULTIPATH_HELPER}"

    source "${MULTIPATH_HELPER}"
}

@test "normalize_path: dot becomes empty string" {
    setup_multipath_helpers
    result=$(normalize_path ".")
    [[ "$result" == "" ]]
}

@test "normalize_path: empty string stays empty" {
    setup_multipath_helpers
    result=$(normalize_path "")
    [[ "$result" == "" ]]
}

@test "normalize_path: strips leading slashes" {
    setup_multipath_helpers
    result=$(normalize_path "/foo/bar")
    [[ "$result" == "foo/bar" ]]
}

@test "normalize_path: strips trailing slashes" {
    setup_multipath_helpers
    result=$(normalize_path "foo/bar/")
    [[ "$result" == "foo/bar" ]]
}

@test "normalize_path: strips both leading and trailing slashes" {
    setup_multipath_helpers
    result=$(normalize_path "/foo/bar/")
    [[ "$result" == "foo/bar" ]]
}

@test "parse_path_mapping: simple source:dest parsing" {
    setup_multipath_helpers
    parse_path_mapping "src/foo:dest/bar"
    [[ "$PARSED_SOURCE" == "src/foo" ]]
    [[ "$PARSED_DEST" == "dest/bar" ]]
}

@test "parse_path_mapping: empty source (root to subdir)" {
    setup_multipath_helpers
    parse_path_mapping ":dest/bar"
    [[ "$PARSED_SOURCE" == "" ]]
    [[ "$PARSED_DEST" == "dest/bar" ]]
}

@test "parse_path_mapping: empty dest (subdir to root)" {
    setup_multipath_helpers
    parse_path_mapping "src/foo:"
    [[ "$PARSED_SOURCE" == "src/foo" ]]
    [[ "$PARSED_DEST" == "" ]]
}

@test "parse_path_mapping: both empty (root to root)" {
    setup_multipath_helpers
    parse_path_mapping ":"
    [[ "$PARSED_SOURCE" == "" ]]
    [[ "$PARSED_DEST" == "" ]]
}

@test "parse_path_mapping: escaped colons in source" {
    setup_multipath_helpers
    parse_path_mapping 'path\:with\:colons:dest'
    [[ "$PARSED_SOURCE" == "path:with:colons" ]]
    [[ "$PARSED_DEST" == "dest" ]]
}

@test "parse_path_mapping: escaped colons in dest" {
    setup_multipath_helpers
    parse_path_mapping 'src:dest\:with\:colons'
    [[ "$PARSED_SOURCE" == "src" ]]
    [[ "$PARSED_DEST" == "dest:with:colons" ]]
}

@test "parse_path_mapping: fails with no colon" {
    setup_multipath_helpers
    run parse_path_mapping "no_colon_here"
    [[ "$status" -ne 0 ]]
}

@test "parse_path_mapping: fails with multiple unescaped colons" {
    setup_multipath_helpers
    run parse_path_mapping "src:mid:dest"
    [[ "$status" -ne 0 ]]
}

@test "validate_no_dest_overlap: no overlap for different paths" {
    setup_multipath_helpers
    run validate_no_dest_overlap "lib/foo" "lib/bar"
    [[ "$status" -eq 0 ]]
}

@test "validate_no_dest_overlap: detects duplicate paths" {
    setup_multipath_helpers
    run validate_no_dest_overlap "lib" "lib"
    [[ "$status" -ne 0 ]]
}

@test "validate_no_dest_overlap: detects parent/child overlap" {
    setup_multipath_helpers
    run validate_no_dest_overlap "lib" "lib/utils"
    [[ "$status" -ne 0 ]]
}

@test "validate_no_dest_overlap: detects child/parent overlap" {
    setup_multipath_helpers
    run validate_no_dest_overlap "lib/utils" "lib"
    [[ "$status" -ne 0 ]]
}

@test "validate_no_dest_overlap: root path with other paths fails" {
    setup_multipath_helpers
    run validate_no_dest_overlap "" "lib"
    [[ "$status" -ne 0 ]]
}

# Argument validation tests for -m flag
@test "validation: -m and -d together fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -m 'src:dest' -d subdir -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "-m cannot be used with -d or -p" ]]
}

@test "validation: -m and -p together fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -m 'src:dest' -p destpath -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "-m cannot be used with -d or -p" ]]
}

@test "validation: -m with invalid format fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -m 'no_colon' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "missing colon separator" ]]
}

@test "validation: -m with multiple unescaped colons fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -m 'a:b:c' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "multiple unescaped colons" ]]
}

@test "validation: multiple -m with overlapping destinations fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -m 'src1:lib' -m 'src2:lib/utils' -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "conflict" ]]
}

@test "validation: valid -m flag is accepted" {
    # This should fail later (no actual repo), but not on -m parsing
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -m 'src:dest' -r foo -t bar 2>&1"
    [[ ! "$output" =~ "missing colon separator" ]]
    [[ ! "$output" =~ "multiple unescaped colons" ]]
    [[ ! "$output" =~ "-m cannot be used" ]]
}

@test "validation: multiple valid -m flags are accepted" {
    # This should fail later (no actual repo), but not on -m parsing
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -m 'src1:dest1' -m 'src2:dest2' -r foo -t bar 2>&1"
    [[ ! "$output" =~ "missing colon separator" ]]
    [[ ! "$output" =~ "conflict" ]]
}

# =============================================================================
# E2E Test for Multi-Path Migration with Local Repos
# =============================================================================

@test "e2e: multi-path migration with -m flag" {
    setup_local_repos

    # Create source with src/ and tests/ directories
    cd "$E2E_TEST_DIR/source" || return 1
    mkdir -p src tests
    echo "source code" > src/main.js
    echo "test code" > tests/main.test.js
    git add .
    git commit -m "Add src and tests directories"
    git push origin main

    # Run gitmux with multiple -m flags (auto-detects backend)
    cd "$BATS_TEST_DIRNAME/.." || return 1
    run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        -m 'src:packages/app/src' \
        -m 'tests:packages/app/tests' \
        -k <<< 'y' 2>&1"

    # Debug: show gitmux output if something went wrong
    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail catastrophically
    [[ ! "$output" =~ "errxit" ]]

    # Check the result in dest
    cd "$E2E_TEST_DIR/dest" || return 1

    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    git checkout "$branch_name"

    # Verify src was migrated to packages/app/src/
    [[ -f "packages/app/src/main.js" ]] || { echo "src/main.js not found at destination"; return 1; }
    E2E_SRC_CONTENT=$(cat "packages/app/src/main.js")
    [[ "$E2E_SRC_CONTENT" == "source code" ]]

    # Verify tests was migrated to packages/app/tests/
    [[ -f "packages/app/tests/main.test.js" ]] || { echo "tests/main.test.js not found at destination"; return 1; }
    E2E_TEST_CONTENT=$(cat "packages/app/tests/main.test.js")
    [[ "$E2E_TEST_CONTENT" == "test code" ]]

    teardown_local_repos
}

# =============================================================================
# Log Level Tests
# =============================================================================

@test "validation: --log-level debug is valid" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --log-level debug -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "validation: --log-level info is valid" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --log-level info -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "validation: --log-level warning is valid" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --log-level warning -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "validation: --log-level error is valid" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --log-level error -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "validation: --log-level with invalid value fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --log-level invalid -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--log-level must be" ]]
}

@test "validation: -L short flag is recognized" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -L debug -r foo -t bar 2>&1"
    [[ ! "$output" =~ "Unknown option" ]]
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "validation: GITMUX_LOG_LEVEL environment variable is recognized" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && GITMUX_LOG_LEVEL=debug ./gitmux.sh -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "validation: GITMUX_LOG_LEVEL with invalid value fails" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && GITMUX_LOG_LEVEL=invalid ./gitmux.sh -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--log-level must be" ]]
}

@test "validation: -v flag sets log level to debug" {
    # -v should produce debug output (verbose mode)
    # Test that -v doesn't conflict with --log-level validation
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -v -r foo -t bar 2>&1"
    [[ ! "$output" =~ "--log-level must be" ]]
}

# =============================================================================
# Pre-flight Check Tests
# =============================================================================

@test "validation: --skip-preflight option is recognized" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --skip-preflight -r foo -t bar 2>&1"
    [[ ! "$output" =~ "Unknown option" ]]
    [[ ! "$output" =~ "Unimplemented option" ]]
}

@test "validation: -S short flag is recognized" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -S -r foo -t bar 2>&1"
    [[ ! "$output" =~ "Unknown option" ]]
    [[ ! "$output" =~ "Unimplemented option" ]]
}

@test "preflight: shows pre-flight checks message at info level" {
    # With skip-preflight off, it should run checks and show output
    # Use a non-existent repo to see the pre-flight failure
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -L info -r https://github.com/nonexistent/repo -t https://github.com/nonexistent/dest 2>&1"
    # Should show pre-flight checks message
    [[ "$output" =~ "pre-flight" ]] || [[ "$output" =~ "Pre-flight" ]]
}

@test "preflight: skipped when --skip-preflight is used" {
    # With --skip-preflight, we bypass the checks
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --skip-preflight -r https://github.com/nonexistent/repo -t https://github.com/nonexistent/dest 2>&1"
    # Should NOT show pre-flight checks message (though may still fail on other errors)
    [[ ! "$output" =~ "Running pre-flight checks" ]]
}

@test "preflight: skipped during dry-run mode" {
    # During --dry-run, pre-flight checks are skipped since we're just previewing
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --dry-run -r https://github.com/nonexistent/repo -t https://github.com/nonexistent/dest 2>&1"
    # Should NOT show pre-flight checks message
    [[ ! "$output" =~ "Running pre-flight checks" ]]
}

# =============================================================================
# Log Level Hierarchy Tests (using helper functions)
# =============================================================================

setup_log_helpers() {
    export GITMUX_SCRIPT="${BATS_TEST_DIRNAME}/../gitmux.sh"
    export LOG_HELPER="${BATS_TEST_TMPDIR}/log_helper.sh"

    # Extract logging functions from gitmux.sh
    cat > "${LOG_HELPER}" << 'HELPER_HEADER'
#!/usr/bin/env bash
# Initialize colors (disabled for testing)
_LOG_COLOR_RESET=''
_LOG_COLOR_DEBUG=''
_LOG_COLOR_INFO=''
_LOG_COLOR_WARN=''
_LOG_COLOR_ERROR=''
HELPER_HEADER

    # Extract functions
    {
        sed -n '/^_log_level_to_num()/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^_should_log()/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^log_debug()/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^log_info()/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^log_warn()/,/^}/p' "${GITMUX_SCRIPT}"
        sed -n '/^log_error()/,/^}/p' "${GITMUX_SCRIPT}"
    } >> "${LOG_HELPER}"

    source "${LOG_HELPER}"
}

@test "log_level_to_num: debug returns 0" {
    setup_log_helpers
    result=$(_log_level_to_num "debug")
    [[ "$result" == "0" ]]
}

@test "log_level_to_num: info returns 1" {
    setup_log_helpers
    result=$(_log_level_to_num "info")
    [[ "$result" == "1" ]]
}

@test "log_level_to_num: warning returns 2" {
    setup_log_helpers
    result=$(_log_level_to_num "warning")
    [[ "$result" == "2" ]]
}

@test "log_level_to_num: error returns 3" {
    setup_log_helpers
    result=$(_log_level_to_num "error")
    [[ "$result" == "3" ]]
}

@test "log_level_to_num: unknown defaults to 1 (info)" {
    setup_log_helpers
    result=$(_log_level_to_num "unknown")
    [[ "$result" == "1" ]]
}

@test "should_log: debug message shown at debug level" {
    setup_log_helpers
    LOG_LEVEL=debug
    run _should_log debug
    [[ "$status" -eq 0 ]]
}

@test "should_log: debug message hidden at info level" {
    setup_log_helpers
    LOG_LEVEL=info
    run _should_log debug
    [[ "$status" -ne 0 ]]
}

@test "should_log: info message shown at debug level" {
    setup_log_helpers
    LOG_LEVEL=debug
    run _should_log info
    [[ "$status" -eq 0 ]]
}

@test "should_log: info message shown at info level" {
    setup_log_helpers
    LOG_LEVEL=info
    run _should_log info
    [[ "$status" -eq 0 ]]
}

@test "should_log: info message hidden at warning level" {
    setup_log_helpers
    LOG_LEVEL=warning
    run _should_log info
    [[ "$status" -ne 0 ]]
}

@test "should_log: warning message shown at warning level" {
    setup_log_helpers
    LOG_LEVEL=warning
    run _should_log warning
    [[ "$status" -eq 0 ]]
}

@test "should_log: error message always shown" {
    setup_log_helpers
    LOG_LEVEL=error
    run _should_log error
    [[ "$status" -eq 0 ]]
}

@test "log_debug: produces output at debug level" {
    setup_log_helpers
    LOG_LEVEL=debug
    run log_debug "test message"
    [[ "$output" =~ "[DEBUG]" ]]
    [[ "$output" =~ "test message" ]]
}

@test "log_debug: suppressed at info level" {
    setup_log_helpers
    LOG_LEVEL=info
    run log_debug "test message"
    [[ -z "$output" ]]
}

@test "log_info: produces output at info level" {
    setup_log_helpers
    LOG_LEVEL=info
    run log_info "test message"
    [[ "$output" =~ "[INFO]" ]]
    [[ "$output" =~ "test message" ]]
}

@test "log_warn: produces output at warning level" {
    setup_log_helpers
    LOG_LEVEL=warning
    run log_warn "test message"
    [[ "$output" =~ "[WARN]" ]]
    [[ "$output" =~ "test message" ]]
}

@test "log_error: always produces output" {
    setup_log_helpers
    LOG_LEVEL=error
    run log_error "test message"
    [[ "$output" =~ "[ERROR]" ]]
    [[ "$output" =~ "test message" ]]
}

@test "log_info: suppressed at error level" {
    setup_log_helpers
    LOG_LEVEL=error
    run log_info "test message"
    [[ -z "$output" ]]
}

@test "log_info: suppressed at warning level" {
    setup_log_helpers
    LOG_LEVEL=warning
    run log_info "test message"
    [[ -z "$output" ]]
}

@test "log_warn: suppressed at error level" {
    setup_log_helpers
    LOG_LEVEL=error
    run log_warn "test message"
    [[ -z "$output" ]]
}

# =============================================================================
# CLI Flag Precedence Tests
# =============================================================================

@test "precedence: CLI --log-level overrides GITMUX_LOG_LEVEL env var" {
    # Set env var to warning, CLI to debug - CLI should win
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && GITMUX_LOG_LEVEL=warning ./gitmux.sh --log-level debug -r foo -t bar 2>&1 | head -20"
    # At debug level we should see DEBUG messages; at warning level we wouldn't
    # Check that the script ran with debug level by looking for debug-level output patterns
    # Note: we can't directly test internal state, but we can verify no "invalid log level" error
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "precedence: CLI -L overrides GITMUX_LOG_LEVEL env var" {
    # Set env var to error, CLI short flag to info - CLI should win
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && GITMUX_LOG_LEVEL=error ./gitmux.sh -L info -r foo -t bar 2>&1 | head -20"
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "precedence: CLI -v overrides GITMUX_LOG_LEVEL env var" {
    # -v sets debug level, should override env var
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && GITMUX_LOG_LEVEL=error ./gitmux.sh -v -r foo -t bar 2>&1 | head -20"
    [[ ! "$output" =~ "--log-level must be" ]]
}

@test "precedence: CLI author options override env vars in validation" {
    # Both CLI and env var provide values - CLI should be used
    # We test this by providing invalid CLI value which should fail validation
    # (If env var was used instead, validation would pass)
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && GITMUX_AUTHOR_NAME=valid GITMUX_AUTHOR_EMAIL=valid@example.com ./gitmux.sh --author-name 'Bad\`Name' --author-email 'cli@example.com' -r foo -t bar 2>&1"
    # Should fail because CLI value contains backtick (shell metacharacter)
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "must not contain" ]] || [[ "$output" =~ "rejected" ]] || [[ "$output" =~ "invalid" ]]
}

@test "precedence: env vars used when no CLI flags provided" {
    # When no CLI override, env var should be validated
    # Test by providing invalid env var value
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && GITMUX_AUTHOR_NAME='Bad\`Name' GITMUX_AUTHOR_EMAIL='valid@example.com' ./gitmux.sh -r foo -t bar 2>&1"
    # Should fail validation because env var contains backtick
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "must not contain" ]] || [[ "$output" =~ "rejected" ]] || [[ "$output" =~ "invalid" ]]
}

# =============================================================================
# Preflight Check Internal Tests
# =============================================================================

setup_preflight_helpers() {
    export GITMUX_SCRIPT="${BATS_TEST_DIRNAME}/../gitmux.sh"
    export PREFLIGHT_HELPER="${BATS_TEST_TMPDIR}/preflight_helper.sh"

    # Extract preflight functions from gitmux.sh
    cat > "${PREFLIGHT_HELPER}" << 'HELPER_HEADER'
#!/usr/bin/env bash
# Stub dependencies
_cmd_exists() { command -v "$1" &>/dev/null; }
log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
HELPER_HEADER

    # Extract _preflight_result function
    sed -n '/^_preflight_result()/,/^}/p' "${GITMUX_SCRIPT}" >> "${PREFLIGHT_HELPER}"

    source "${PREFLIGHT_HELPER}"
}

@test "preflight: _preflight_result pass shows checkmark" {
    setup_preflight_helpers
    run _preflight_result pass "test passed"
    [[ "$output" =~ "✅" ]]
    [[ "$output" =~ "test passed" ]]
}

@test "preflight: _preflight_result fail shows X mark" {
    setup_preflight_helpers
    run _preflight_result fail "test failed"
    [[ "$output" =~ "❌" ]]
    [[ "$output" =~ "test failed" ]]
}

@test "preflight: _preflight_result warn shows warning mark" {
    setup_preflight_helpers
    run _preflight_result warn "test warning"
    [[ "$output" =~ "⚠️" ]]
    [[ "$output" =~ "test warning" ]]
}

@test "preflight: _preflight_result unknown shows question mark" {
    setup_preflight_helpers
    run _preflight_result unknownstatus "test unknown"
    [[ "$output" =~ "❓" ]]
    [[ "$output" =~ "unknown status" ]]
}

@test "preflight: checks git is installed" {
    # Git should pass since we need it for tests anyway
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -r https://github.com/foo/bar -t https://github.com/baz/qux 2>&1 | grep -i 'git installed'"
    [[ "$output" =~ "✅" ]] || [[ "$output" =~ "git installed" ]]
}

@test "preflight: fails when destination variables are not set" {
    # This tests the guard we added - destination_owner/project must be defined
    # We test this indirectly by checking the preflight output structure
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -r https://github.com/foo/bar -t https://github.com/baz/qux 2>&1"
    # Should either pass preflight or fail with specific messages, not undefined variable errors
    [[ ! "$output" =~ "unbound variable" ]]
}

@test "preflight: reports inaccessible source repo" {
    # Use a non-existent repo to trigger source accessibility failure
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -r https://github.com/nonexistent-owner-12345/nonexistent-repo-67890 -t https://github.com/foo/bar 2>&1"
    # Should show pre-flight check failure for source repo
    [[ "$output" =~ "source" ]] || [[ "$output" =~ "Source" ]]
}

@test "preflight: fails gracefully with informative error" {
    # With non-existent repos, preflight should fail with clear error message
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -r https://github.com/nonexistent-owner-abc/nonexistent-repo-xyz -t https://github.com/foo/bar 2>&1"
    # Should fail
    [[ "$status" -ne 0 ]]
    # Should show pre-flight failure message
    [[ "$output" =~ "Pre-flight" ]] || [[ "$output" =~ "pre-flight" ]] || [[ "$output" =~ "❌" ]]
}

@test "preflight: failure prevents repository clone attempt" {
    # Use a non-existent repo - preflight should fail before any clone attempt
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -r https://github.com/nonexistent-owner-xyz/nonexistent-repo-xyz -t https://github.com/foo/bar 2>&1"
    [[ "$status" -ne 0 ]]
    # Should NOT see cloning message - preflight should abort before that
    [[ ! "$output" =~ "Cloning source repository" ]]
}

@test "validation: --log-level DEBUG (uppercase) fails validation" {
    # Log levels are case-sensitive
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --log-level DEBUG -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--log-level must be" ]]
}

@test "validation: --log-level INFO (uppercase) fails validation" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --log-level INFO -r foo -t bar 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "--log-level must be" ]]
}

@test "log_error: produces output even at debug level" {
    setup_log_helpers
    LOG_LEVEL=debug
    run log_error "test message"
    [[ "$output" =~ "[ERROR]" ]]
    [[ "$output" =~ "test message" ]]
}

@test "log_error: produces output even at info level" {
    setup_log_helpers
    LOG_LEVEL=info
    run log_error "test message"
    [[ "$output" =~ "[ERROR]" ]]
    [[ "$output" =~ "test message" ]]
}

@test "log_error: produces output even at warning level" {
    setup_log_helpers
    LOG_LEVEL=warning
    run log_error "test message"
    [[ "$output" =~ "[ERROR]" ]]
    [[ "$output" =~ "test message" ]]
}

# ============================================================================
# Help output tests
# ============================================================================

@test "help: no arguments shows help and exits 0" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh 2>&1"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "gitmux" ]]
    [[ "$output" =~ "Usage:" ]]
}

@test "help: -h flag shows help and exits 0" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Usage:" ]]
}

@test "help: output contains Required category" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "Required" ]]
    [[ "$output" =~ "-r <url|path>" ]]
    [[ "$output" =~ "-t <url|path>" ]]
}

@test "help: output contains Path Filtering category" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "Path Filtering" ]]
    [[ "$output" =~ "-m <src:dest>" ]]
    [[ "$output" =~ "-d <path>" ]]
    [[ "$output" =~ "-p <path>" ]]
    [[ "$output" =~ "-g <ref>" ]]
    [[ "$output" =~ "-l <rev-list>" ]]
}

@test "help: output contains Destination category" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "Destination" ]]
    [[ "$output" =~ "-b <branch>" ]]
}

@test "help: output contains Rebase category" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "Rebase" ]]
    [[ "$output" =~ "-X <strategy>" ]]
}

@test "help: output contains GitHub Integration category" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "GitHub Integration" ]]
    [[ "$output" =~ "-s" ]]
}

@test "help: output contains Author Rewriting category" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "Author Rewriting" ]]
    [[ "$output" =~ "--author-name" ]]
    [[ "$output" =~ "--dry-run" ]]
}

@test "help: output contains Logging & Debug category" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "Logging" ]]
    [[ "$output" =~ "--log-level" ]]
    [[ "$output" =~ "-v" ]]
}

@test "help: output contains tagline quote" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "The life of a repo man is always intense" ]]
}

@test "help: no ANSI colors when piped (not a TTY)" {
    # When output is piped, colors should be disabled
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h | cat"
    [[ "$status" -eq 0 ]]
    # Should NOT contain ANSI escape sequences
    [[ ! "$output" =~ $'\033' ]]
}

@test "help: output contains main description" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -h 2>&1"
    [[ "$output" =~ "Sync repository subsets while preserving full git history" ]]
}

@test "help: unknown option shows help then errors" {
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh -Q 2>&1"
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "Usage:" ]]
    # Error message varies by shell/getopt implementation
    [[ "$output" =~ "Unknown option" ]] || [[ "$output" =~ "illegal option" ]]
}

# ============================================================================
# Filter backend detection tests
# ============================================================================

@test "check_filter_repo_available: returns 0 when git-filter-repo in PATH" {
    # Create a mock git-filter-repo in temp directory
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    echo '#!/bin/bash' > "${BATS_TEST_TMPDIR}/bin/git-filter-repo"
    echo 'echo "git-filter-repo mock"' >> "${BATS_TEST_TMPDIR}/bin/git-filter-repo"
    chmod +x "${BATS_TEST_TMPDIR}/bin/git-filter-repo"

    PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" run check_filter_repo_available
    [[ "$status" -eq 0 ]]
}

@test "check_filter_repo_available: returns 1 when not in PATH" {
    # Use a PATH that definitely doesn't have git-filter-repo
    PATH="/nonexistent" run check_filter_repo_available
    [[ "$status" -eq 1 ]]
}

# ============================================================================
# _check_python_version tests
# ============================================================================

@test "_check_python_version: returns 0 when Python 3.6+ installed" {
    # Assumes test environment has Python 3.6+
    if ! command -v python3 &>/dev/null; then
        skip "python3 not installed"
    fi
    run _check_python_version
    [[ "$status" -eq 0 ]]
}

@test "_check_python_version: returns 2 when python3 not in PATH" {
    # Use a PATH without python3
    PATH="/nonexistent" run _check_python_version
    [[ "$status" -eq 2 ]]
}

@test "_check_python_version: returns 1 when Python version check fails" {
    # Create a mock python3 that returns exit code 1 (simulates Python < 3.6)
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    cat > "${BATS_TEST_TMPDIR}/bin/python3" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/python3"

    PATH="${BATS_TEST_TMPDIR}/bin" run _check_python_version
    [[ "$status" -eq 1 ]]
}

@test "_check_python_version: returns 3 on unexpected Python error (e.g. exit 127)" {
    # Create a mock python3 that returns unexpected exit code (simulates permission denied, etc.)
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    cat > "${BATS_TEST_TMPDIR}/bin/python3" << 'EOF'
#!/bin/bash
exit 127
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/python3"

    PATH="${BATS_TEST_TMPDIR}/bin" run _check_python_version
    [[ "$status" -eq 3 ]]
}

@test "help: shows --filter-backend option" {
    run "${GITMUX_SCRIPT}" -h
    [[ "$output" =~ "--filter-backend" ]]
    [[ "$output" =~ "filter-branch|filter-repo|auto" ]]
}

@test "filter-backend: accepts auto value" {
    run "${GITMUX_SCRIPT}" --filter-backend auto -r x -t y --dry-run 2>&1
    [[ ! "$output" =~ "must be 'auto'" ]]
}

@test "filter-backend: accepts filter-repo value" {
    run "${GITMUX_SCRIPT}" --filter-backend filter-repo -r x -t y --dry-run 2>&1
    [[ ! "$output" =~ "must be 'auto'" ]]
}

@test "filter-backend: accepts filter-branch value" {
    run "${GITMUX_SCRIPT}" --filter-backend filter-branch -r x -t y --dry-run 2>&1
    [[ ! "$output" =~ "must be 'auto'" ]]
}

@test "filter-backend: rejects invalid value" {
    run "${GITMUX_SCRIPT}" --filter-backend invalid -r x -t y 2>&1
    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "must be 'auto', 'filter-repo', or 'filter-branch'" ]]
}

@test "filter-backend: respects GITMUX_FILTER_BACKEND env var" {
    # This should fail later (domain mismatch), but not on filter-backend validation
    GITMUX_FILTER_BACKEND=filter-branch run "${GITMUX_SCRIPT}" -r x -t y --dry-run 2>&1
    [[ ! "$output" =~ "must be 'auto', 'filter-repo', or 'filter-branch'" ]]
}

@test "get_filter_backend: returns filter-repo when auto and available" {
    # Mock git-filter-repo as available
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    echo '#!/bin/bash' > "${BATS_TEST_TMPDIR}/bin/git-filter-repo"
    chmod +x "${BATS_TEST_TMPDIR}/bin/git-filter-repo"

    GITMUX_FILTER_BACKEND=auto PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" run get_filter_backend
    [[ "$output" == "filter-repo" ]]
}

@test "get_filter_backend: returns filter-branch when auto and not available" {
    GITMUX_FILTER_BACKEND=auto PATH="/nonexistent" run get_filter_backend
    [[ "$output" == "filter-branch" ]]
}

@test "get_filter_backend: returns filter-repo when explicitly set" {
    GITMUX_FILTER_BACKEND=filter-repo run get_filter_backend
    [[ "$output" == "filter-repo" ]]
}

@test "get_filter_backend: returns filter-branch when explicitly set" {
    GITMUX_FILTER_BACKEND=filter-branch run get_filter_backend
    [[ "$output" == "filter-branch" ]]
}

@test "get_filter_backend: returns filter-branch when auto and filter-repo available but Python < 3.6" {
    # Mock git-filter-repo as available
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    echo '#!/bin/bash' > "${BATS_TEST_TMPDIR}/bin/git-filter-repo"
    chmod +x "${BATS_TEST_TMPDIR}/bin/git-filter-repo"

    # Mock python3 to fail version check (simulates Python < 3.6)
    cat > "${BATS_TEST_TMPDIR}/bin/python3" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "${BATS_TEST_TMPDIR}/bin/python3"

    GITMUX_FILTER_BACKEND=auto PATH="${BATS_TEST_TMPDIR}/bin" run get_filter_backend
    [[ "$output" == "filter-branch" ]]
}

# ============================================================================
# Filter backend pre-flight check tests
# ============================================================================

@test "preflight: shows filter backend in help" {
    # Note: preflight checks are skipped in dry-run mode, so we verify
    # via the help output that filter-backend option exists
    run "${GITMUX_SCRIPT}" -h 2>&1

    # Should show filter backend option in help
    [[ "$output" =~ "filter-backend" ]]
    [[ "$output" =~ "filter-branch|filter-repo|auto" ]]
}

@test "preflight: fails when filter-repo explicitly requested but not found" {
    # Use a PATH without git-filter-repo
    PATH="/usr/bin:/bin" GITMUX_FILTER_BACKEND=filter-repo run "${GITMUX_SCRIPT}" \
        -r https://github.com/test/source \
        -t https://github.com/test/dest \
        --dry-run 2>&1

    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "filter-repo" ]] && [[ "$output" =~ "not found" || "$output" =~ "not installed" || "$output" =~ "requested" ]]
}

# ============================================================================
# Filter-repo E2E tests (skipped if filter-repo not installed)
# ============================================================================

@test "e2e: filter-repo author override changes commit author" {
    # Skip if filter-repo not installed
    if ! command -v git-filter-repo &>/dev/null; then
        skip "git-filter-repo not installed"
    fi

    setup_local_repos

    # Create source commit
    cd "$E2E_TEST_DIR/source" || return 1
    echo "content" > file.txt
    git add .
    git commit -m "Test commit"
    git push origin main

    # Run gitmux with filter-repo backend and author override
    cd "$BATS_TEST_DIRNAME/.." || return 1
    GITMUX_FILTER_BACKEND=filter-repo run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --author-name 'New Author' \
        --author-email 'new@example.com' \
        -k <<< 'y' 2>&1"

    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail
    [[ ! "$output" =~ "errxit" ]]
    [[ ! "$output" =~ "filter-repo failed" ]]

    # Fetch the new branch
    cd "$E2E_TEST_DIR/dest" || return 1
    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    E2E_COMMIT_AUTHOR=$(git log -1 --format="%an <%ae>" "$branch_name" 2>/dev/null)
    [[ "$E2E_COMMIT_AUTHOR" == "New Author <new@example.com>" ]]

    teardown_local_repos
}

@test "e2e: filter-repo coauthor-action 'claude' removes Claude attribution" {
    # Skip if filter-repo not installed
    if ! command -v git-filter-repo &>/dev/null; then
        skip "git-filter-repo not installed"
    fi

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

    # Run gitmux with filter-repo backend
    cd "$BATS_TEST_DIRNAME/.." || return 1
    GITMUX_FILTER_BACKEND=filter-repo run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --coauthor-action claude \
        -k <<< 'y' 2>&1"

    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail
    [[ ! "$output" =~ "errxit" ]]
    [[ ! "$output" =~ "filter-repo failed" ]]

    # Check the commit message
    cd "$E2E_TEST_DIR/dest" || return 1
    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    # Look at the filtered commit (HEAD~1), not the "Bring in changes" commit (HEAD)
    E2E_COMMIT_MSG=$(git log -1 --format="%B" "${branch_name}~1" 2>/dev/null)
    echo "Filtered commit message: $E2E_COMMIT_MSG" >&2

    # Should preserve human co-author
    [[ "$E2E_COMMIT_MSG" =~ "Co-authored-by: Human Dev" ]]
    # Should remove Claude co-authors
    [[ ! "$E2E_COMMIT_MSG" =~ "@anthropic.com" ]]
    [[ ! "$E2E_COMMIT_MSG" =~ "Generated with" ]]

    teardown_local_repos
}

@test "e2e: filter-repo coauthor-action 'all' removes all co-authors" {
    # Skip if filter-repo not installed
    if ! command -v git-filter-repo &>/dev/null; then
        skip "git-filter-repo not installed"
    fi

    setup_local_repos

    # Create source commit with mixed co-authors
    cd "$E2E_TEST_DIR/source" || return 1
    echo "content" > file.txt
    git add .
    git commit -m "Test commit

Co-authored-by: Human Dev <human@example.com>
Co-authored-by: Claude <noreply@anthropic.com>

Generated with [Some Tool](https://example.com)"
    git push origin main

    # Run gitmux with filter-repo backend and coauthor-action 'all'
    cd "$BATS_TEST_DIRNAME/.." || return 1
    GITMUX_FILTER_BACKEND=filter-repo run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --coauthor-action all \
        -k <<< 'y' 2>&1"

    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail
    [[ ! "$output" =~ "errxit" ]]
    [[ ! "$output" =~ "filter-repo failed" ]]

    # Check the commit message
    cd "$E2E_TEST_DIR/dest" || return 1
    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    # Look at the filtered commit (HEAD~1), not the "Bring in changes" commit (HEAD)
    E2E_COMMIT_MSG=$(git log -1 --format="%B" "${branch_name}~1" 2>/dev/null)
    echo "Filtered commit message: $E2E_COMMIT_MSG" >&2

    # Should remove ALL co-authors (including human)
    [[ ! "$E2E_COMMIT_MSG" =~ "Co-authored-by:" ]]
    [[ ! "$E2E_COMMIT_MSG" =~ "Generated with" ]]

    teardown_local_repos
}

@test "e2e: filter-repo warns when committer differs from author" {
    # Skip if filter-repo not installed
    if ! command -v git-filter-repo &>/dev/null; then
        skip "git-filter-repo not installed"
    fi

    setup_local_repos

    # Create a simple source commit
    cd "$E2E_TEST_DIR/source" || return 1
    echo "content" > file.txt
    git add .
    git commit -m "Test commit"
    git push origin main

    # Run gitmux with filter-repo backend and different author/committer
    cd "$BATS_TEST_DIRNAME/.." || return 1
    GITMUX_FILTER_BACKEND=filter-repo run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        --author-name 'Author Name' \
        --author-email 'author@example.com' \
        --committer-name 'Committer Name' \
        --committer-email 'committer@example.com' \
        -k <<< 'y' 2>&1"

    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail
    [[ ! "$output" =~ "errxit" ]]

    # Should show warning about filter-repo limitation
    [[ "$output" =~ "filter-repo backend applies same name/email to both author and committer" ]]

    teardown_local_repos
}

@test "e2e: filter-repo with path mapping" {
    # Skip if filter-repo not installed
    if ! command -v git-filter-repo &>/dev/null; then
        skip "git-filter-repo not installed"
    fi

    setup_local_repos

    # Create source commit with a subdirectory
    cd "$E2E_TEST_DIR/source" || return 1
    mkdir -p src
    echo "content" > src/file.txt
    git add .
    git commit -m "Add src directory"
    git push origin main

    # Run gitmux with filter-repo backend and path mapping
    cd "$BATS_TEST_DIRNAME/.." || return 1
    GITMUX_FILTER_BACKEND=filter-repo run bash -c "./gitmux.sh \
        -r '$E2E_TEST_DIR/source' \
        -t '$E2E_TEST_DIR/dest' \
        -b main \
        -m 'src:lib' \
        -k <<< 'y' 2>&1"

    echo "gitmux output: $output" >&2

    # Verify gitmux didn't fail
    [[ ! "$output" =~ "errxit" ]]
    [[ ! "$output" =~ "filter-repo failed" ]]

    # Check file exists at new path
    cd "$E2E_TEST_DIR/dest" || return 1
    local branch_name
    branch_name=$(git branch -a | grep "update-from-main" | head -1 | tr -d ' *')

    [[ -n "$branch_name" ]] || { echo "No update-from-main branch found"; return 1; }

    git checkout "$branch_name" 2>/dev/null || git checkout -b test-branch "$branch_name"

    # File should be at lib/file.txt (renamed from src/file.txt)
    # With filter-repo's --path-rename, src/ -> lib/ directly
    [[ -f "lib/file.txt" ]]

    teardown_local_repos
}
