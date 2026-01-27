# Filter-Repo Migration Design

**Date:** 2026-01-27
**Status:** Approved
**Issue:** [#21](https://github.com/stavxyz/gitmux/issues/21)

## Overview

Add support for `git filter-repo` as an alternative backend to `git filter-branch`, with auto-detection and fallback. This provides ~10x performance improvement while maintaining full backward compatibility.

## Motivation

- **Performance** - filter-repo is ~10x faster than filter-branch
- **Future-proofing** - filter-branch is deprecated by the Git project
- **User experience** - Better error messages and safer operations
- **Modernization** - filter-repo is actively maintained with new features

## Configuration

### New Option

```
--filter-backend <backend>   Filter backend: filter-branch|filter-repo|auto
                             (default: auto, env: GITMUX_FILTER_BACKEND)
```

### Environment Variable

`GITMUX_FILTER_BACKEND` - Same values as the flag.

### Behavior Matrix

| Setting | filter-repo available | Behavior |
|---------|----------------------|----------|
| `auto` | Yes | Use filter-repo, no message |
| `auto` | No | Use filter-branch, info message |
| `filter-repo` | Yes | Use filter-repo |
| `filter-repo` | No | Error and abort |
| `filter-branch` | Either | Use filter-branch, no message |

### Fallback Message (auto mode only)

```
[INFO] ℹ️ Using filter-branch (install git-filter-repo for 10x speedup)
```

## Pre-flight Integration

### When filter-repo available

```
[INFO] 🔍 Running pre-flight checks...
  ✅ git installed
  ✅ gh CLI installed
  ✅ git-filter-repo available (using filter-repo backend)
  ...
```

### When filter-repo not available (auto mode)

```
  ⚠️ git-filter-repo not found (will use filter-branch)
```

### When filter-repo explicitly requested but missing

```
  ❌ git-filter-repo not found but explicitly requested
[ERROR] ❌ Pre-flight checks failed. Aborting.
```

### Python Version Check

filter-repo requires Python >= 3.6. Pre-flight validates this when filter-repo is selected.

## Operation Mapping

### Subdirectory Filter (`-d` flag)

```bash
# filter-branch
git filter-branch --subdirectory-filter "$path" -- --all

# filter-repo
git filter-repo --subdirectory-filter "$path" --force
```

### Multi-Path Migration (`-m src:dest`)

```bash
# filter-branch: requires file reorganization + filter-branch
# (current complex approach)

# filter-repo: single-pass extract AND rename
git filter-repo --path "src/foo" --path-rename "src/foo:dest/bar" --force
```

### Place at Destination (`-p` flag, no `-d`)

```bash
# filter-repo
git filter-repo --to-subdirectory-filter "$dest_path" --force
```

### Author/Committer Rewrite

```bash
# filter-branch
git filter-branch --env-filter 'export GIT_AUTHOR_NAME="Name"...' -- --all

# filter-repo (mailmap approach)
echo "New Name <new@email.com> <*@*>" > /tmp/mailmap
git filter-repo --mailmap /tmp/mailmap --force
```

### Co-author Removal (`--coauthor-action claude`)

```bash
# filter-branch
git filter-branch --msg-filter 'sed -E "/Co-authored-by:.*[Cc]laude/d"' -- --all

# filter-repo
git filter-repo --message-callback '
import re
return re.sub(rb"Co-authored-by:.*[Cc]laude.*\n", b"", message)
' --force
```

### File Extraction (`-l` flag)

```bash
# filter-branch
git filter-branch --index-filter 'git read-tree --empty; git reset $GIT_COMMIT -- file1 file2' -- --all

# filter-repo
git filter-repo --path file1 --path file2 --force
```

### Tag Handling

```bash
# filter-branch
git filter-branch --tag-name-filter cat -- --all

# filter-repo (automatic - tags rewritten by default)
# No extra flag needed
```

## Implementation Architecture

### New Functions

```bash
# Detection
check_filter_repo_available()    # Returns 0 if git-filter-repo in PATH
get_filter_backend()             # Returns "filter-repo" or "filter-branch"

# Backend-specific implementations
filter_subdirectory_filter_branch()
filter_subdirectory_filter_repo()

filter_path_mapping_filter_branch()
filter_path_mapping_filter_repo()

filter_author_rewrite_filter_branch()
filter_author_rewrite_filter_repo()

filter_message_filter_branch()
filter_message_filter_repo()

filter_file_extract_filter_branch()
filter_file_extract_filter_repo()
```

### Dispatcher Pattern

```bash
run_filter_operation() {
  local operation="$1"
  shift
  local backend
  backend="$(get_filter_backend)"

  "filter_${operation}_${backend}" "$@"
}
```

### Usage in Main Flow

```bash
run_filter_operation "subdirectory" "$SOURCE_SUBDIR"
run_filter_operation "author_rewrite" "$AUTHOR_NAME" "$AUTHOR_EMAIL"
run_filter_operation "message" "$COAUTHOR_PATTERN"
```

## Help Text

New entry in help output:

```
Filtering:
  --filter-backend <be>        Backend: filter-branch|filter-repo|auto
                               (default: auto, env: GITMUX_FILTER_BACKEND)
```

## Documentation Updates

### Prerequisites (README.md)

Add optional dependency:

```markdown
- [git-filter-repo](https://github.com/newren/git-filter-repo) (optional, recommended for 10x speedup)
```

### New Section: Filter Backend

```markdown
## Filter Backend

gitmux uses `git filter-branch` or `git filter-repo` to rewrite history. By default,
it auto-detects and uses filter-repo if available, falling back to filter-branch.

| Backend | Speed | Requirements |
|---------|-------|--------------|
| `filter-repo` | ~10x faster | Python 3.6+, separate install |
| `filter-branch` | Baseline | Built into git |

Override with `--filter-backend` or `GITMUX_FILTER_BACKEND`:

```bash
./gitmux.sh -r source -t dest --filter-backend filter-branch  # Force legacy
./gitmux.sh -r source -t dest --filter-backend filter-repo    # Require filter-repo
```
```

### FAQ Addition

```markdown
**Q: How do I get faster performance?**

A: Install git-filter-repo for ~10x speedup: `brew install git-filter-repo` (macOS)
or `apt install git-filter-repo` (Debian/Ubuntu). gitmux auto-detects and uses it
when available.
```

## Testing Strategy

### Unit Tests (test_gitmux_unit.bats)

```bash
# Detection tests
@test "check_filter_repo_available: returns 0 when in PATH"
@test "check_filter_repo_available: returns 1 when not in PATH"
@test "get_filter_backend: returns filter-repo when auto and available"
@test "get_filter_backend: returns filter-branch when auto and not available"
@test "get_filter_backend: respects explicit --filter-backend"
@test "get_filter_backend: respects GITMUX_FILTER_BACKEND env var"

# Help text
@test "help: shows --filter-backend option"

# Pre-flight
@test "preflight: shows filter-repo available when found"
@test "preflight: shows warning when filter-repo not found (auto mode)"
@test "preflight: fails when filter-repo requested but not found"
```

### Integration Tests (test_gitmux.sh)

Run E2E tests for both backends:

```bash
@test "e2e: subdirectory extraction with filter-branch backend"
@test "e2e: subdirectory extraction with filter-repo backend"
@test "e2e: multi-path migration with filter-branch backend"
@test "e2e: multi-path migration with filter-repo backend"
@test "e2e: author rewrite with filter-branch backend"
@test "e2e: author rewrite with filter-repo backend"
@test "e2e: coauthor removal with filter-branch backend"
@test "e2e: coauthor removal with filter-repo backend"
```

### CI Consideration

- CI should have filter-repo installed
- One CI job should explicitly test `--filter-backend filter-branch` to ensure fallback works

## Files to Modify

| File | Changes |
|------|---------|
| `gitmux.sh` | Add backend detection, dispatcher, dual implementations |
| `README.md` | Document new option, prerequisites, FAQ entry |
| `tests/test_gitmux_unit.bats` | Detection and help tests |
| `tests/test_gitmux.sh` | E2E tests for both backends |

## References

- [git-filter-repo repository](https://github.com/newren/git-filter-repo)
- [Official conversion guide](https://github.com/newren/git-filter-repo/blob/main/Documentation/converting-from-filter-branch.md)
- [git-filter-repo documentation](https://raw.githubusercontent.com/newren/git-filter-repo/main/Documentation/git-filter-repo.txt)
- [git filter-branch deprecation notice](https://git-scm.com/docs/git-filter-branch)
