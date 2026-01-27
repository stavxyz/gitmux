# Filter-Repo Migration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add git-filter-repo as a faster alternative backend with auto-detection and fallback to filter-branch.

**Architecture:** Dispatcher pattern routes filter operations to backend-specific functions. Detection runs once at startup, caches result. All existing filter-branch logic preserved in `*_filter_branch()` functions, new filter-repo logic in `*_filter_repo()` functions.

**Tech Stack:** Bash, git-filter-repo (Python), bats (testing)

---

## Task 1: Add Filter Backend Detection Functions

**Files:**
- Modify: `gitmux.sh` (add after line ~248, near `_cmd_exists`)

**Step 1: Write the failing test**

Add to `tests/test_gitmux_unit.bats`:

```bash
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
```

**Step 2: Run test to verify it fails**

Run: `bats tests/test_gitmux_unit.bats --filter "check_filter_repo_available"`
Expected: FAIL with "check_filter_repo_available: command not found"

**Step 3: Update test helper to extract the new function**

In `tests/test_gitmux_unit.bats`, update the `setup()` function to extract `check_filter_repo_available`:

```bash
# Add after existing sed extractions in setup():
# check_filter_repo_available function
sed -n '/^check_filter_repo_available() {/,/^}/p' "${GITMUX_SCRIPT}"
```

**Step 4: Write the implementation**

Add to `gitmux.sh` after the `_cmd_exists` function (around line 248):

```bash
# Check if git-filter-repo is available.
# Returns:
#   0 if git-filter-repo is in PATH and executable
#   1 otherwise
check_filter_repo_available() {
  command -v git-filter-repo &> /dev/null
}
```

**Step 5: Run test to verify it passes**

Run: `bats tests/test_gitmux_unit.bats --filter "check_filter_repo_available"`
Expected: PASS

**Step 6: Commit**

```bash
git add gitmux.sh tests/test_gitmux_unit.bats
git commit -m "feat: add check_filter_repo_available function

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 2: Add Filter Backend Configuration Variable and Flag

**Files:**
- Modify: `gitmux.sh` (argument parsing section, lines ~303-622)

**Step 1: Write the failing test**

Add to `tests/test_gitmux_unit.bats`:

```bash
@test "help: shows --filter-backend option" {
    run "${GITMUX_SCRIPT}" -h
    [[ "$output" =~ "--filter-backend" ]]
    [[ "$output" =~ "filter-branch|filter-repo|auto" ]]
}
```

**Step 2: Run test to verify it fails**

Run: `bats tests/test_gitmux_unit.bats --filter "help: shows --filter-backend"`
Expected: FAIL - output doesn't contain --filter-backend

**Step 3: Add long option conversion**

In `gitmux.sh`, add to the long-to-short option conversion block (around line 315):

```bash
    '--filter-backend')  set -- "$@" '-F' ;;
```

**Step 4: Add default variable**

In `gitmux.sh`, add to the defaults section (around line 335):

```bash
GITMUX_FILTER_BACKEND="${GITMUX_FILTER_BACKEND:-auto}"
```

**Step 5: Add getopts case**

In `gitmux.sh`, update getopts string to include `F:` and add case:

Change: `while getopts "hvr:d:g:t:p:z:b:l:o:X:m:sickDSL:N:E:n:e:C:" OPT; do`
To: `while getopts "hvr:d:g:t:p:z:b:l:o:X:m:sickDSL:N:E:n:e:C:F:" OPT; do`

Add case:

```bash
    F)  GITMUX_FILTER_BACKEND=$OPTARG
      ;;
```

**Step 6: Add validation**

In `gitmux.sh`, add after the log level validation (around line 635):

```bash
# Validate filter backend value
case "$GITMUX_FILTER_BACKEND" in
  auto|filter-repo|filter-branch) ;; # Valid values
  *) errxit "--filter-backend must be 'auto', 'filter-repo', or 'filter-branch', got: ${GITMUX_FILTER_BACKEND}" ;;
esac
```

**Step 7: Add help text**

In `gitmux.sh`, add new section in `show_help()` after "Author Rewriting" section:

```bash
  _help_header "Filtering"
  _help_flag "-F, --filter-backend <be>" "Backend: filter-branch|filter-repo|auto"
  _help_cont "(default: auto, env: GITMUX_FILTER_BACKEND)"
```

**Step 8: Run test to verify it passes**

Run: `bats tests/test_gitmux_unit.bats --filter "help: shows --filter-backend"`
Expected: PASS

**Step 9: Add more tests for validation**

```bash
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
    GITMUX_FILTER_BACKEND=filter-branch run "${GITMUX_SCRIPT}" -r x -t y --dry-run 2>&1
    [[ "$status" -eq 0 ]] || [[ "$output" =~ "filter-branch" ]]
}
```

**Step 10: Run all filter-backend tests**

Run: `bats tests/test_gitmux_unit.bats --filter "filter-backend"`
Expected: All PASS

**Step 11: Commit**

```bash
git add gitmux.sh tests/test_gitmux_unit.bats
git commit -m "feat: add --filter-backend flag and GITMUX_FILTER_BACKEND env var

Supports: auto, filter-repo, filter-branch (default: auto)

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 3: Add get_filter_backend Function

**Files:**
- Modify: `gitmux.sh` (add after `check_filter_repo_available`)

**Step 1: Write the failing tests**

Add to `tests/test_gitmux_unit.bats`:

```bash
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
```

**Step 2: Run tests to verify they fail**

Run: `bats tests/test_gitmux_unit.bats --filter "get_filter_backend"`
Expected: FAIL with "get_filter_backend: command not found"

**Step 3: Update test helper extraction**

Add to `setup()` in test file:

```bash
# get_filter_backend function
sed -n '/^get_filter_backend() {/,/^}/p' "${GITMUX_SCRIPT}"
```

**Step 4: Write the implementation**

Add to `gitmux.sh` after `check_filter_repo_available`:

```bash
# Determine which filter backend to use.
# Uses GITMUX_FILTER_BACKEND setting, with auto-detection for "auto" mode.
# Globals:
#   GITMUX_FILTER_BACKEND - "auto", "filter-repo", or "filter-branch"
# Returns:
#   Echoes "filter-repo" or "filter-branch" to stdout
get_filter_backend() {
  case "${GITMUX_FILTER_BACKEND}" in
    filter-repo)
      echo "filter-repo"
      ;;
    filter-branch)
      echo "filter-branch"
      ;;
    auto|*)
      if check_filter_repo_available; then
        echo "filter-repo"
      else
        echo "filter-branch"
      fi
      ;;
  esac
}
```

**Step 5: Run tests to verify they pass**

Run: `bats tests/test_gitmux_unit.bats --filter "get_filter_backend"`
Expected: All PASS

**Step 6: Commit**

```bash
git add gitmux.sh tests/test_gitmux_unit.bats
git commit -m "feat: add get_filter_backend function for backend selection

Auto-detects filter-repo availability, respects explicit settings.

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 4: Add Pre-flight Check for Filter Backend

**Files:**
- Modify: `gitmux.sh` (in `preflight_checks` function, around line 820)

**Step 1: Write the failing test**

Add to `tests/test_gitmux_unit.bats`:

```bash
@test "preflight: shows filter-repo available when found" {
    # Create mock git-filter-repo
    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    echo '#!/bin/bash' > "${BATS_TEST_TMPDIR}/bin/git-filter-repo"
    chmod +x "${BATS_TEST_TMPDIR}/bin/git-filter-repo"

    # Run gitmux with dry-run to trigger preflight
    PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" run "${GITMUX_SCRIPT}" \
        -r https://github.com/test/source \
        -t https://github.com/test/dest \
        --dry-run 2>&1

    [[ "$output" =~ "filter-repo" ]] || [[ "$output" =~ "git-filter-repo" ]]
}

@test "preflight: shows warning when filter-repo not found (auto mode)" {
    PATH="/usr/bin:/bin" GITMUX_FILTER_BACKEND=auto run "${GITMUX_SCRIPT}" \
        -r https://github.com/test/source \
        -t https://github.com/test/dest \
        --skip-preflight \
        --dry-run 2>&1

    # Should mention filter-branch or the fallback
    [[ "$output" =~ "filter-branch" ]] || [[ "$output" =~ "10x speedup" ]]
}

@test "preflight: fails when filter-repo explicitly requested but not found" {
    PATH="/usr/bin:/bin" GITMUX_FILTER_BACKEND=filter-repo run "${GITMUX_SCRIPT}" \
        -r https://github.com/test/source \
        -t https://github.com/test/dest \
        --dry-run 2>&1

    [[ "$status" -ne 0 ]]
    [[ "$output" =~ "filter-repo" ]] && [[ "$output" =~ "not found" || "$output" =~ "not installed" ]]
}
```

**Step 2: Run tests to verify behavior**

Run: `bats tests/test_gitmux_unit.bats --filter "preflight:"`
Expected: May fail depending on current implementation state

**Step 3: Add pre-flight check for filter backend**

In `gitmux.sh`, add to `preflight_checks()` function after the gh authentication check (around line 865):

```bash
  # Check filter backend availability
  local _selected_backend="${GITMUX_FILTER_BACKEND:-auto}"

  if [[ "$_selected_backend" == "filter-repo" ]]; then
    # User explicitly requested filter-repo
    if check_filter_repo_available; then
      # Check Python version
      if python3 -c "import sys; exit(0 if sys.version_info >= (3,6) else 1)" 2>/dev/null; then
        _preflight_result pass "git-filter-repo available (explicit)"
      else
        _preflight_result fail "git-filter-repo requires Python 3.6+"
        _checks_passed=false
      fi
    else
      _preflight_result fail "git-filter-repo not found but explicitly requested"
      log_error ""
      log_error "  📦 Install: brew install git-filter-repo (macOS)"
      log_error "             apt install git-filter-repo (Debian/Ubuntu)"
      log_error "             pip install git-filter-repo"
      log_error ""
      _checks_passed=false
    fi
  elif [[ "$_selected_backend" == "filter-branch" ]]; then
    _preflight_result pass "using filter-branch (explicit)"
  else
    # Auto mode
    if check_filter_repo_available; then
      if python3 -c "import sys; exit(0 if sys.version_info >= (3,6) else 1)" 2>/dev/null; then
        _preflight_result pass "git-filter-repo available (using filter-repo backend)"
      else
        _preflight_result warn "git-filter-repo found but Python < 3.6 (will use filter-branch)"
      fi
    else
      _preflight_result warn "git-filter-repo not found (will use filter-branch)"
    fi
  fi
```

**Step 4: Run tests to verify they pass**

Run: `bats tests/test_gitmux_unit.bats --filter "preflight:"`
Expected: All PASS

**Step 5: Commit**

```bash
git add gitmux.sh tests/test_gitmux_unit.bats
git commit -m "feat: add filter backend pre-flight check

Shows which backend will be used, validates Python version for filter-repo.

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 5: Extract Existing Filter-Branch Logic into Functions

**Files:**
- Modify: `gitmux.sh` (refactor `process_single_mapping` function)

This task extracts the existing filter-branch code into named functions to prepare for the dispatcher pattern.

**Step 1: Identify current filter-branch code blocks**

The current implementation in `process_single_mapping()` (lines 1370-1453) has:
1. Subdirectory filter options building
2. Env-filter for author/committer
3. Msg-filter for co-author removal
4. Index-filter for file extraction
5. Combined filter-branch execution

**Step 2: Create filter_run_filter_branch function**

Add before `process_single_mapping` function:

```bash
# Run filter-branch with the configured options.
# This is the legacy implementation - preserved for systems without filter-repo.
# Arguments:
#   $1 - source_path (subdirectory to filter, empty for root)
#   $2 - dest_path (destination path for reorganization)
#   $3 - mapping_idx (index for logging)
# Globals read:
#   GITMUX_AUTHOR_NAME, GITMUX_AUTHOR_EMAIL
#   GITMUX_COMMITTER_NAME, GITMUX_COMMITTER_EMAIL
#   GITMUX_COAUTHOR_ACTION
#   rev_list_files
# Returns:
#   0 on success, 1 on failure
filter_run_filter_branch() {
  local _source_path="$1"
  local _dest_path="$2"
  local _mapping_idx="$3"

  # Build subdirectory filter options
  local _subdirectory_filter_options=""
  if [ -n "${_source_path}" ]; then
    _subdirectory_filter_options="--subdirectory-filter ${_source_path}"
  fi

  # Build --env-filter for author/committer override
  local _env_filter_script=""
  if [[ -n "$GITMUX_AUTHOR_NAME" ]] || [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
    export GITMUX_AUTHOR_NAME GITMUX_AUTHOR_EMAIL
    export GITMUX_COMMITTER_NAME GITMUX_COMMITTER_EMAIL
    # shellcheck disable=SC2016
    _env_filter_script='
      if [ -n "${GITMUX_AUTHOR_NAME:-}" ]; then
        export GIT_AUTHOR_NAME="${GITMUX_AUTHOR_NAME}"
        export GIT_AUTHOR_EMAIL="${GITMUX_AUTHOR_EMAIL}"
      fi
      if [ -n "${GITMUX_COMMITTER_NAME:-}" ]; then
        export GIT_COMMITTER_NAME="${GITMUX_COMMITTER_NAME}"
        export GIT_COMMITTER_EMAIL="${GITMUX_COMMITTER_EMAIL}"
      fi
    '
    log "Author/committer override enabled"
  fi

  # Build --msg-filter for Co-authored-by handling
  local _msg_filter_script=""
  if [[ "$GITMUX_COAUTHOR_ACTION" == "claude" ]]; then
    _msg_filter_script='sed -E \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*[Cc]laude[[:space:]]+[Cc]ode/d" \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:[[:space:]]*[Cc]laude[[:space:]]*</d" \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:.*@anthropic\.com/d" \
      -e "/[Gg]enerated with.*[Cc]laude/d"'
  elif [[ "$GITMUX_COAUTHOR_ACTION" == "all" ]]; then
    _msg_filter_script='sed -E \
      -e "/[Cc]o-[Aa]uthored-[Bb]y:/d" \
      -e "/[Gg]enerated with[[:space:]]*\[/d"'
  fi

  # Build the filter-branch command dynamically
  local _filter_branch_cmd="git filter-branch --tag-name-filter cat"

  if [ -n "${_env_filter_script}" ]; then
    _filter_branch_cmd="${_filter_branch_cmd} --env-filter '${_env_filter_script}'"
  fi

  if [ -n "${_msg_filter_script}" ]; then
    _filter_branch_cmd="${_filter_branch_cmd} --msg-filter '${_msg_filter_script}'"
  fi

  log "rev-list options --> ${rev_list_files}"
  log "subdirectory filter options --> ${_subdirectory_filter_options}"

  export FILTER_BRANCH_SQUELCH_WARNING=1

  if [ -n "${rev_list_files}" ]; then
    log "Targeting paths/revisions: ${rev_list_files}"
    # shellcheck disable=SC2086
    _filter_branch_cmd="${_filter_branch_cmd} ${_subdirectory_filter_options} --index-filter \"
      git read-tree --empty
      git reset \\\$GIT_COMMIT -- ${rev_list_files}
     \" -- --all -- ${rev_list_files}"
    log "Running: ${_filter_branch_cmd}"
    if ! eval "${_filter_branch_cmd}"; then
      log_error "git filter-branch failed for mapping $((_mapping_idx + 1))"
      log_debug "Command was: ${_filter_branch_cmd}"
      return 1
    fi
  else
    # shellcheck disable=SC2086
    _filter_branch_cmd="${_filter_branch_cmd} ${_subdirectory_filter_options}"
    log "Running: ${_filter_branch_cmd}"
    if ! eval "${_filter_branch_cmd}"; then
      log_error "git filter-branch failed for mapping $((_mapping_idx + 1))"
      log_debug "Command was: ${_filter_branch_cmd}"
      return 1
    fi
  fi

  return 0
}
```

**Step 3: Update process_single_mapping to use the new function**

Replace the filter-branch code block in `process_single_mapping` with:

```bash
  # Run the filter operation using the selected backend
  if ! filter_run_filter_branch "${_source_path}" "${_dest_path}" "${_mapping_idx}"; then
    return 1
  fi
```

**Step 4: Run existing tests to verify no regression**

Run: `bats tests/test_gitmux_unit.bats`
Expected: All existing tests PASS

**Step 5: Commit**

```bash
git add gitmux.sh
git commit -m "refactor: extract filter-branch logic into filter_run_filter_branch

Prepares for dispatcher pattern with dual backend support.
No functional changes - pure refactoring.

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 6: Add filter_run_filter_repo Function

**Files:**
- Modify: `gitmux.sh` (add after `filter_run_filter_branch`)

**Step 1: Write the implementation**

Add after `filter_run_filter_branch`:

```bash
# Run filter-repo with the configured options.
# This is the modern implementation - faster and recommended.
# Arguments:
#   $1 - source_path (subdirectory to filter, empty for root)
#   $2 - dest_path (destination path for reorganization)
#   $3 - mapping_idx (index for logging)
# Globals read:
#   GITMUX_AUTHOR_NAME, GITMUX_AUTHOR_EMAIL
#   GITMUX_COMMITTER_NAME, GITMUX_COMMITTER_EMAIL
#   GITMUX_COAUTHOR_ACTION
#   rev_list_files
# Returns:
#   0 on success, 1 on failure
filter_run_filter_repo() {
  local _source_path="$1"
  local _dest_path="$2"
  local _mapping_idx="$3"

  local _filter_repo_args=("--force")

  # Handle subdirectory extraction with optional path rename
  if [ -n "${_source_path}" ]; then
    if [ -n "${_dest_path}" ] && [ "${_source_path}" != "${_dest_path}" ]; then
      # Extract source path and rename to dest path
      _filter_repo_args+=("--path" "${_source_path}")
      _filter_repo_args+=("--path-rename" "${_source_path}:${_dest_path}")
    else
      # Simple subdirectory filter
      _filter_repo_args+=("--subdirectory-filter" "${_source_path}")
    fi
  elif [ -n "${_dest_path}" ]; then
    # No source path but dest path - move everything to subdirectory
    _filter_repo_args+=("--to-subdirectory-filter" "${_dest_path}")
  fi

  # Handle specific file extraction (-l flag)
  if [ -n "${rev_list_files}" ]; then
    # Parse rev_list_files and add each path
    # rev_list_files format: "--all -- file1 file2"
    local _files_only
    _files_only=$(echo "${rev_list_files}" | sed 's/.*-- //')
    for _file in ${_files_only}; do
      _filter_repo_args+=("--path" "${_file}")
    done
  fi

  # Handle author/committer rewrite using mailmap
  if [[ -n "$GITMUX_AUTHOR_NAME" ]] || [[ -n "$GITMUX_COMMITTER_NAME" ]]; then
    local _mailmap_file
    _mailmap_file=$(mktemp)

    # Build mailmap entries
    # Format: "New Name <new@email.com> <old@email.com>"
    # Using <*> to match all old emails
    if [[ -n "$GITMUX_AUTHOR_NAME" ]]; then
      echo "${GITMUX_AUTHOR_NAME} <${GITMUX_AUTHOR_EMAIL}> <*>" >> "${_mailmap_file}"
    fi

    _filter_repo_args+=("--mailmap" "${_mailmap_file}")
    log "Author/committer override enabled via mailmap"
  fi

  # Handle Co-authored-by removal using message-callback
  if [[ "$GITMUX_COAUTHOR_ACTION" == "claude" ]]; then
    _filter_repo_args+=("--message-callback" '
import re
# Remove Claude/Anthropic co-author lines
patterns = [
    rb"Co-authored-by:\s*Claude\s+Code[^\n]*\n",
    rb"Co-authored-by:\s*Claude\s*<[^\n]*\n",
    rb"Co-authored-by:[^\n]*@anthropic\.com[^\n]*\n",
    rb"Generated with[^\n]*Claude[^\n]*\n",
]
result = message
for pattern in patterns:
    result = re.sub(pattern, b"", result, flags=re.IGNORECASE)
return result
')
  elif [[ "$GITMUX_COAUTHOR_ACTION" == "all" ]]; then
    _filter_repo_args+=("--message-callback" '
import re
# Remove all co-author lines
result = re.sub(rb"Co-authored-by:[^\n]*\n", b"", message, flags=re.IGNORECASE)
result = re.sub(rb"Generated with\s*\[[^\n]*\n", b"", result, flags=re.IGNORECASE)
return result
')
  fi

  log "Running: git filter-repo ${_filter_repo_args[*]}"

  if ! git filter-repo "${_filter_repo_args[@]}"; then
    log_error "git filter-repo failed for mapping $((_mapping_idx + 1))"
    return 1
  fi

  return 0
}
```

**Step 2: Commit**

```bash
git add gitmux.sh
git commit -m "feat: add filter_run_filter_repo function

Implements filter-repo backend with:
- Subdirectory filter and path rename
- Author/committer rewrite via mailmap
- Co-author removal via message-callback
- Specific file extraction via --path

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 7: Add run_filter_operation Dispatcher

**Files:**
- Modify: `gitmux.sh` (add after `filter_run_filter_repo`, update `process_single_mapping`)

**Step 1: Write the dispatcher function**

Add after `filter_run_filter_repo`:

```bash
# Cached filter backend - set once at runtime
_GITMUX_CACHED_BACKEND=""

# Run the appropriate filter operation based on configured backend.
# Caches the backend selection for consistency across all operations.
# Arguments:
#   $1 - source_path
#   $2 - dest_path
#   $3 - mapping_idx
# Returns:
#   0 on success, 1 on failure
run_filter_operation() {
  local _source_path="$1"
  local _dest_path="$2"
  local _mapping_idx="$3"

  # Cache backend selection on first call
  if [[ -z "${_GITMUX_CACHED_BACKEND}" ]]; then
    _GITMUX_CACHED_BACKEND="$(get_filter_backend)"

    # Log fallback message for auto mode when using filter-branch
    if [[ "${GITMUX_FILTER_BACKEND}" == "auto" ]] && [[ "${_GITMUX_CACHED_BACKEND}" == "filter-branch" ]]; then
      log_info "ℹ️ Using filter-branch (install git-filter-repo for 10x speedup)"
    fi
  fi

  case "${_GITMUX_CACHED_BACKEND}" in
    filter-repo)
      filter_run_filter_repo "$_source_path" "$_dest_path" "$_mapping_idx"
      ;;
    filter-branch)
      filter_run_filter_branch "$_source_path" "$_dest_path" "$_mapping_idx"
      ;;
    *)
      log_error "Unknown filter backend: ${_GITMUX_CACHED_BACKEND}"
      return 1
      ;;
  esac
}
```

**Step 2: Update process_single_mapping to use dispatcher**

Change:
```bash
  if ! filter_run_filter_branch "${_source_path}" "${_dest_path}" "${_mapping_idx}"; then
```
To:
```bash
  if ! run_filter_operation "${_source_path}" "${_dest_path}" "${_mapping_idx}"; then
```

**Step 3: Run all tests**

Run: `bats tests/test_gitmux_unit.bats`
Expected: All PASS

**Step 4: Commit**

```bash
git add gitmux.sh
git commit -m "feat: add run_filter_operation dispatcher

Routes to filter-repo or filter-branch based on configuration.
Caches backend selection for consistency.
Shows fallback message when auto mode uses filter-branch.

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 8: Update README Documentation

**Files:**
- Modify: `README.md`

**Step 1: Add filter-repo to Prerequisites**

In the Prerequisites section, add:

```markdown
- [git-filter-repo](https://github.com/newren/git-filter-repo) (optional, recommended for ~10x speedup)
```

**Step 2: Add --filter-backend to Usage section**

Add to the options list:

```markdown
Filtering:
  --filter-backend <be>        Backend: filter-branch|filter-repo|auto
                               (default: auto, env: GITMUX_FILTER_BACKEND)
```

**Step 3: Add Filter Backend section**

Add new section after "Rebase Strategies":

```markdown
## Filter Backend

gitmux can use either `git filter-branch` (legacy, built-in) or `git filter-repo` (modern, ~10x faster) to rewrite history. By default, gitmux auto-detects and uses filter-repo if available.

| Backend | Speed | Requirements |
|---------|-------|--------------|
| `filter-repo` | ~10x faster | Python 3.6+, [separate install](https://github.com/newren/git-filter-repo#how-do-i-install-it) |
| `filter-branch` | Baseline | Built into git |

### Installation

```bash
# macOS
brew install git-filter-repo

# Debian/Ubuntu
apt install git-filter-repo

# pip (any platform)
pip install git-filter-repo
```

### Override Backend

```bash
# Force filter-branch (legacy)
./gitmux.sh -r source -t dest --filter-backend filter-branch

# Require filter-repo (error if not available)
./gitmux.sh -r source -t dest --filter-backend filter-repo

# Auto-detect (default)
./gitmux.sh -r source -t dest --filter-backend auto
```

Or set via environment: `export GITMUX_FILTER_BACKEND=filter-repo`
```

**Step 4: Add FAQ entry**

Add to FAQ section:

```markdown
**Q: How do I get faster performance?**

A: Install git-filter-repo for ~10x speedup: `brew install git-filter-repo` (macOS) or `apt install git-filter-repo` (Debian/Ubuntu). gitmux auto-detects and uses it when available.
```

**Step 5: Add Environment Variable to table**

Add to the Environment Variables table:

```markdown
| `--filter-backend` | `GITMUX_FILTER_BACKEND` |
```

**Step 6: Commit**

```bash
git add README.md
git commit -m "docs: add filter-repo backend documentation

Documents:
- Optional filter-repo prerequisite
- --filter-backend flag and GITMUX_FILTER_BACKEND env var
- New Filter Backend section with installation instructions
- FAQ entry for performance improvement

Co-authored-by: stavxyz <hi@stav.xyz>"
```

---

## Task 9: Run Full Test Suite and Verify

**Step 1: Run unit tests**

Run: `bats tests/test_gitmux_unit.bats -v`
Expected: All PASS

**Step 2: Test with filter-branch explicitly**

Run: `./gitmux.sh --filter-backend filter-branch -r https://github.com/stavxyz/gitmux -t /tmp/test-dest --dry-run`
Expected: Shows "using filter-branch (explicit)" in preflight

**Step 3: Test with filter-repo (if available)**

Run: `./gitmux.sh --filter-backend filter-repo -r https://github.com/stavxyz/gitmux -t /tmp/test-dest --dry-run`
Expected: Shows "git-filter-repo available" in preflight (or error if not installed)

**Step 4: Test auto mode**

Run: `./gitmux.sh -r https://github.com/stavxyz/gitmux -t /tmp/test-dest --dry-run`
Expected: Shows appropriate backend based on availability

**Step 5: Commit any fixes**

If any issues found, fix and commit.

---

## Task 10: Final Review and Push

**Step 1: Review all changes**

Run: `git log --oneline origin/main..HEAD`
Verify commits are atomic and well-documented.

**Step 2: Run final test suite**

Run: `bats tests/test_gitmux_unit.bats`
Expected: All PASS

**Step 3: Push to PR branch**

Run: `git push origin docs/filter-repo-design`

**Step 4: Update PR description if needed**

Use `gh pr edit 37` to update description with implementation details.

---

## Future Enhancements (filter-repo only)

These features could be added later, only available when filter-repo is the active backend:

- `--strip-large-files <size>` - Remove files larger than specified size
- `--path-glob <pattern>` - Extract files matching glob pattern
- `--analyze` - Pre-migration analysis report
- `--replace-text <file>` - Find/replace across all history
