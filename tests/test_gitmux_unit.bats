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
    [[ "$output" =~ "--coauthor-action must be 'remove' or 'keep'" ]]
}

@test "validation: --coauthor-action 'remove' is valid" {
    # This should fail later (no actual repo), but not on coauthor-action validation
    run bash -c "cd '$BATS_TEST_DIRNAME/..' && ./gitmux.sh --coauthor-action remove -r foo -t bar 2>&1"
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
