---
layout: default
title: Filter Backend
nav_order: 4
---

# Filter Backend

gitmux can use either `git filter-branch` (legacy, built-in) or `git filter-repo` (modern, ~10x faster) to rewrite history.

## Comparison

| Backend | Speed | Requirements |
|---------|-------|--------------|
| `filter-repo` | ~10x faster | Python 3.6+, [separate install](https://github.com/newren/git-filter-repo#how-do-i-install-it) |
| `filter-branch` | Baseline | Built into git |

## Auto-Detection

By default, gitmux uses `auto` mode:

1. Check if `git-filter-repo` is in PATH
2. Check if Python 3.6+ is available
3. Use filter-repo if both pass, otherwise fall back to filter-branch

You'll see which backend is selected in the pre-flight output:

```
[INFO] 🔍 Running pre-flight checks...
  ✅ git installed
  ✅ git-filter-repo available (using filter-repo backend)
```

Or if falling back:

```
[INFO] ℹ️  Using filter-branch (install git-filter-repo for ~10x speedup)
```

## Installation

### macOS

```bash
brew install git-filter-repo
```

### Debian/Ubuntu

```bash
apt install git-filter-repo
```

### Any platform (pip)

```bash
pip install git-filter-repo
```

### Verify installation

```bash
git filter-repo --version
```

## Override Backend

Force a specific backend:

```bash
# Force filter-branch (legacy)
./gitmux.sh -r source -t dest --filter-backend filter-branch

# Require filter-repo (error if not available)
./gitmux.sh -r source -t dest --filter-backend filter-repo
```

Or set via environment:

```bash
export GITMUX_FILTER_BACKEND=filter-repo
```

## When to Override

**Force `filter-branch`:**
- Debugging issues with filter-repo
- Compatibility with older systems
- When filter-repo behavior differs unexpectedly

**Force `filter-repo`:**
- Ensure consistent behavior across environments
- Fail early if filter-repo is missing (rather than slow fallback)
- CI/CD where you want fast, predictable performance

## Technical Notes

### filter-repo advantages

- Written in Python, purpose-built for history rewriting
- Better memory efficiency for large repos
- Cleaner handling of edge cases
- Active development and community support

### filter-branch limitations

- Deprecated by Git project (still works, not recommended for new use)
- Slower on large repositories
- Can be memory-intensive
- Some edge cases handled differently

### Feature parity

gitmux provides the same features regardless of backend:

- Subdirectory extraction (`-d`)
- Path mapping (`-m`)
- Author/committer rewriting (`--author-*`, `--committer-*`)
- Co-author removal (`--coauthor-action`)
- Specific file extraction (`-l`)

The backend choice only affects performance, not functionality.
