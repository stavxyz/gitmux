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

# Setup: Source the functions we want to test
setup() {
    # Create a temporary file with just the functions we need
    # This avoids running the main script logic
    export TEST_HELPER="${BATS_TEST_TMPDIR}/test_helper.sh"

    cat > "${TEST_HELPER}" << 'HELPER_EOF'
#!/usr/bin/env bash

# Helper function: strip leading and trailing slashes
function stripslashes () {
    echo "$@" | sed 's:/*$::' | sed 's:^/*::'
}

# Helper function: check if command exists
_cmd_exists () {
    if ! type "$*" &> /dev/null; then
        return 1
    fi
    return 0
}

# Helper function: cross-platform realpath
_realpath () {
    if _cmd_exists realpath; then
        realpath "$@"
        return $?
    else
        readlink -f "$@"
        return $?
    fi
}

# Regex for parsing repository URLs
REPO_REGEX='s/(.*:\/\/|^git@)(.*)([\/:]{1})([a-zA-Z0-9_\.-]{1,})([\/]{1})([a-zA-Z0-9_\.-]{1,}$)'

# Parse source domain from URL
parse_domain() {
    local url="${1}"
    echo "${url}" | sed -E "${REPO_REGEX}"'/\2/' | sed -E "s/(^[a-zA-Z0-9_-]{0,38}\:{1})([a-zA-Z0-9_]{5,40})(\@?)"'//'
}

# Parse project name from URL
parse_project() {
    local url="${1}"
    echo "${url}" | sed -E "${REPO_REGEX}"'/\6/'
}

# Parse owner from URL
parse_owner() {
    local url="${1}"
    echo "${url}" | sed -E "${REPO_REGEX}"'/\4/'
}
HELPER_EOF

    source "${TEST_HELPER}"
}

teardown() {
    rm -f "${TEST_HELPER}"
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
