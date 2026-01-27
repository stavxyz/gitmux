# Single-Pass Multi-Path Refactor

## Summary

Refactor gitmux to process multiple path mappings in a single filter operation instead of the current multi-pass branching/merging approach. This eliminates the filter-repo limitation and significantly simplifies the codebase.

## Problem

The current multi-path implementation:
1. Processes each mapping separately (clone → filter → branch → reset → filter → merge)
2. Requires checking out `ORIGINAL_HEAD` between mappings
3. Uses complex `--allow-unrelated-histories` merges
4. **Breaks with filter-repo** because it rewrites history so aggressively that `ORIGINAL_HEAD` no longer exists

## Solution

Both `git filter-repo` and `git filter-branch` support processing multiple paths in a single invocation:

**filter-repo:**
```bash
git filter-repo --force \
  --path src --path tests \
  --path-rename src:lib --path-rename tests:pkg/tests
```

**filter-branch:**
```bash
git filter-branch --force --prune-empty --tree-filter '
  # Script that filters paths AND renames them
' -- --all
```

## Architecture

### Current Flow (Complex)
```
for each mapping:
    if first:
        process_single_mapping()
        create integration branch
    else:
        checkout ORIGINAL_HEAD        # <-- BREAKS with filter-repo
        create temp branch
        process_single_mapping()
        merge into integration branch
```

### New Flow (Simple)
```
collect all path mappings
if multiple mappings:
    run_multipath_filter_operation(all_mappings)  # Single pass
else:
    run_filter_operation(single_mapping)          # Existing logic
create integration branch
```

## Implementation Plan

### Task 1: Add `filter_run_filter_repo_multipath()` function

Create a new function that builds a single filter-repo command with all paths.

**Location:** `gitmux.sh` after `filter_run_filter_repo()`

**Signature:**
```bash
# Run filter-repo for multiple path mappings in a single pass.
# Arguments:
#   $1 - Newline-separated list of "source:dest" mappings
# Returns:
#   0 on success, 1 on failure
filter_run_filter_repo_multipath() {
  local _mappings="$1"
  local _filter_repo_args=("--force")

  # Build --path and --path-rename args for each mapping
  while IFS= read -r mapping; do
    local _src _dest
    _src="${mapping%%:*}"
    _dest="${mapping#*:}"

    if [[ -n "$_src" ]]; then
      _filter_repo_args+=("--path" "$_src")
    fi
    if [[ -n "$_src" ]] && [[ -n "$_dest" ]] && [[ "$_src" != "$_dest" ]]; then
      _filter_repo_args+=("--path-rename" "${_src}:${_dest}")
    fi
  done <<< "$_mappings"

  # Add author/committer callbacks (same as single-path)
  # Add coauthor message callbacks (same as single-path)

  git filter-repo "${_filter_repo_args[@]}"
}
```

**Verification:**
- Unit test: builds correct args for 2+ mappings
- E2E test: `-m src:lib -m tests:pkg/tests` produces correct result

---

### Task 2: Add `filter_run_filter_branch_multipath()` function

Create a new function that builds a `--tree-filter` script for all paths.

**Location:** `gitmux.sh` after `filter_run_filter_branch()`

**Signature:**
```bash
# Run filter-branch for multiple path mappings in a single pass.
# Arguments:
#   $1 - Newline-separated list of "source:dest" mappings
# Returns:
#   0 on success, 1 on failure
filter_run_filter_branch_multipath() {
  local _mappings="$1"

  # Build tree-filter script
  local _tree_filter_script='
    # Keep only specified paths
    for item in *; do
      case "$item" in
        KEEP_PATTERNS_HERE) ;;
        *) rm -rf "$item" 2>/dev/null || true ;;
      esac
    done

    # Rename paths
    RENAME_COMMANDS_HERE
  '

  # Generate KEEP_PATTERNS and RENAME_COMMANDS from mappings
  # ...

  git filter-branch --force --prune-empty \
    --tree-filter "$_tree_filter_script" \
    -- --all
}
```

**Verification:**
- Unit test: generates correct tree-filter script
- E2E test: same multi-path test with `GITMUX_FILTER_BACKEND=filter-branch`

---

### Task 3: Add `run_multipath_filter_operation()` dispatcher

Create dispatcher that routes to the appropriate multipath function.

**Location:** `gitmux.sh` after `run_filter_operation()`

```bash
# Run filter operation for multiple path mappings.
# Arguments:
#   $1 - Newline-separated list of "source:dest" mappings
# Returns:
#   0 on success, 1 on failure
run_multipath_filter_operation() {
  local _mappings="$1"
  local _backend
  _backend="$(get_filter_backend)"

  case "$_backend" in
    filter-repo)
      filter_run_filter_repo_multipath "$_mappings"
      ;;
    filter-branch)
      filter_run_filter_branch_multipath "$_mappings"
      ;;
  esac
}
```

---

### Task 4: Refactor main loop to use single-pass for multi-path

Replace the complex per-mapping loop with single-pass logic.

**Current code to replace:** Lines ~1860-1960 (the `for mapping_idx` loop)

**New logic:**
```bash
MAPPING_COUNT=${#PATH_MAPPINGS[@]}

if [[ $MAPPING_COUNT -gt 1 ]]; then
  # Multi-path: use single-pass approach
  log_info "📂 Processing ${MAPPING_COUNT} path mappings in single pass..."

  # Build mappings string
  local _all_mappings=""
  for mapping in "${PATH_MAPPINGS[@]}"; do
    _all_mappings+="${mapping}"$'\n'
  done

  # Run single-pass filter
  if ! run_multipath_filter_operation "$_all_mappings"; then
    errxit "Failed to process multi-path mappings"
  fi

  # Create integration branch
  if ! git checkout -b "${INTEGRATION_BRANCH}"; then
    errxit "Failed to create integration branch"
  fi
else
  # Single path: use existing logic (unchanged)
  # ... existing process_single_mapping code ...
fi
```

**What gets removed:**
- `ORIGINAL_HEAD` variable and usage
- Temp branch creation/cleanup for subsequent mappings
- `refs/original/` cleanup between mappings
- `--allow-unrelated-histories` merge logic
- Complex merge conflict resolution

---

### Task 5: Update tests

**Remove from test file:**
- The `GITMUX_FILTER_BACKEND=filter-branch` override in multi-path test

**Add new tests:**
```bash
@test "e2e: filter-repo multi-path migration" {
    # Same as existing multi-path test but explicitly uses filter-repo
    GITMUX_FILTER_BACKEND=filter-repo run ...
}

@test "e2e: filter-branch multi-path migration" {
    # Same test with filter-branch to ensure both work
    GITMUX_FILTER_BACKEND=filter-branch run ...
}
```

---

### Task 6: Update documentation

**Remove from README:**
- The "Limitations" section about multi-path requiring filter-branch

**Update filter backend section:**
- Note that both backends now support multi-path mappings efficiently

---

## File Changes Summary

| File | Change |
|------|--------|
| `gitmux.sh` | Add 3 new functions, refactor main loop (~150 lines added, ~100 lines removed) |
| `tests/test_gitmux_unit.bats` | Add 2 E2E tests, update existing multi-path test |
| `README.md` | Remove limitations section |

## Testing Strategy

1. **Unit tests** for new functions (arg building)
2. **E2E tests** for both backends with multi-path
3. **Regression tests** - all existing tests must pass
4. **Manual verification** - test with real repos

## Rollback Plan

If issues discovered:
1. The existing multi-pass code can be kept as fallback
2. Add `GITMUX_MULTIPATH_STRATEGY=single|multi` env var for override
3. Default to single-pass, allow multi-pass for edge cases

## Success Criteria

- [ ] `./gitmux.sh -m src:lib -m tests:pkg/tests` works with filter-repo
- [ ] Same command works with filter-branch
- [ ] No duplicate commits when paths share commits
- [ ] All existing tests pass
- [ ] No "lame" limitation documentation needed
