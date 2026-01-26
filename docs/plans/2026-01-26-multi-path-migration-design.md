# Multi-Path Migration Feature Design

**Date:** 2026-01-26
**Status:** Pending approval

## Overview

Add support for migrating multiple source/destination path pairs in a single gitmux invocation, resulting in one branch and one PR.

## Current Behavior

```bash
./gitmux.sh -r SOURCE -t DEST -d src/foo -p dest/bar
```

Single `-d`/`-p` pair per invocation. Multiple paths require multiple runs, creating separate branches and PRs.

## Proposed Behavior

```bash
./gitmux.sh -r SOURCE -t DEST \
  -m src/document_pipeline:packages/geah/src/geah/integrations/humaninterest \
  -m tests:packages/geah/tests/integrations/humaninterest
```

Multiple `-m` flags, each specifying a `source:dest` mapping. All mappings processed sequentially into a single branch/PR.

## Syntax

### New Flag: `-m <source:dest>`

- Can be specified multiple times
- Source and destination separated by unescaped `:`
- Use `\:` to escape literal colons in paths
- Either side can be empty, `.`, or `/` to mean "root"

**Examples:**
| Syntax | Meaning |
|--------|---------|
| `-m src/foo:dest/bar` | Subdir to subdir |
| `-m src/foo:` | Subdir to dest root |
| `-m :dest/bar` | Entire source to dest subdir |
| `-m :` | Entire source to dest root (fork) |
| `-m path\:with\:colons:dest` | Escaped colons in path |

### Backwards Compatibility

- `-d` and `-p` still work for single-pair migrations
- `-m` is mutually exclusive with `-d`/`-p` (error if both used)
- Internally, `-d`/`-p` converts to a single-element mappings array

## Validation

1. Each `-m` value must contain exactly one unescaped colon
2. `-m` cannot be used with `-d` or `-p`
3. Destination paths cannot overlap (e.g., `lib` and `lib/utils` would conflict)
4. Fail fast on any validation error before doing work

## Execution Flow

### Setup (once)
1. Clone source repo to temp workspace
2. Checkout specified git ref if `-g` provided
3. Capture `GIT_BRANCH` and `GIT_SHA`

### For each `-m` pair (sequential, user-specified order)
1. Create working branch from original source state
2. Apply file reorganization (move source path contents to dest path structure)
3. Commit the reorganization
4. Run `git filter-branch` with appropriate subdirectory filter
5. Merge filtered result into integration branch (`--allow-unrelated-histories` for 2nd+ pairs)

### Finalize (once)
1. Add destination remote
2. Create PR branch: `update-from-{branch}-{sha}[-rebase-strategy-X]`
3. Rebase onto destination branch
4. Push to destination
5. Create PR if `-s` specified

## Error Handling

- **Fail fast**: If any step fails, abort entire operation and clean up
- No partial results pushed
- Clear error messages indicating which mapping failed

## Branch Naming

Unchanged: `update-from-{branch}-{sha}[-rebase-strategy-{strategy}]`

The branch identifies where content came from, not what content. PR description lists all mappings.

## PR Description Format

```markdown
# Hello
This is an automated pull request created by `gitmux`.

## Source repository details
Source URL: [`https://github.com/org/source`](...)
Source git ref: `main`
Source git branch: `main` (`abc1234`)

## Path mappings
| Source | Destination |
|--------|-------------|
| `src/document_pipeline` | `packages/geah/src/geah/integrations/humaninterest` |
| `tests` | `packages/geah/tests/integrations/humaninterest` |

## Destination repository details
Destination URL: [`https://github.com/org/dest`](...)
PR Branch (head): `update-from-main-abc1234-rebase-strategy-theirs`
Destination branch (base): `trunk`
```

Table format used for both single and multiple mappings.

## Implementation Plan

### 1. Add helper functions
- `parse_path_mapping()` - Split on unescaped colon, handle escaping
- `normalize_path()` - Convert `.`, `/`, empty to canonical empty string
- `validate_no_dest_overlap()` - Check for conflicting destination paths

### 2. Modify argument parsing
- Add `-m` to getopts
- Store mappings in `PATH_MAPPINGS` array
- Validate mutual exclusivity with `-d`/`-p`
- Convert legacy `-d`/`-p` to mappings array format

### 3. Refactor main execution loop
- Extract current single-path logic into `process_single_mapping()` function
- Wrap in loop over `PATH_MAPPINGS` array
- Handle branch creation/merging between iterations

### 4. Update PR description generation
- Build markdown table from `PATH_MAPPINGS` array

### 5. Update help text
- Document new `-m` flag
- Add examples

## Testing

### Unit tests (bats)

**Parsing:**
- `-m src:dest` parses correctly
- `-m src\:with\:colons:dest` handles escaped colons
- `-m` with no colon fails
- `-m` with multiple unescaped colons fails
- `-m` and `-d`/`-p` together fails

**Path normalization:**
- `"."` → `""`
- `"/"` → `""`
- `"/foo/bar/"` → `"foo/bar"`

**Overlap detection:**
- `lib` and `lib/utils` → overlap detected
- `lib/foo` and `lib/bar` → no overlap
- `lib` and `lib` → duplicate detected

### Integration tests (test_gitmux.sh)

**Multi-path migration:**
- Create source with `src/` and `tests/` directories
- Run with `-m src:pkg/src -m tests:pkg/tests`
- Verify both paths exist at destination
- Verify single PR branch

**Backwards compatibility:**
- Existing tests pass unchanged
