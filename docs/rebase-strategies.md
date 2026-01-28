---
layout: default
title: Rebase Strategies
nav_order: 3
---

# Rebase Strategies

When gitmux rebases source history onto the destination, conflicts can occur if the same lines were changed in both places. The `-X` option controls how these conflicts are resolved automatically.

## Quick Reference

| Strategy | When a conflict occurs... | Best for |
|----------|--------------------------|----------|
| `theirs` (default) | Keep the source's version | Most syncs — you want the source content |
| `ours` | Keep the destination's version | Protecting local destination changes |
| `patience` | Use smarter diff algorithm | Cleaner diffs with moved/refactored code |

## Why `theirs` is the Default

When you run gitmux, your intent is to get content from the source. If conflicts occur:

- **With `theirs`**: Source changes are kept. Any overwritten destination content appears in the PR diff — you'll see lines being removed and can review before merging.

- **With `ours`**: Destination changes are kept. Dropped source changes are **invisible** — you'd never know they were supposed to be there.

Override with `-X ours` if your destination has changes you want to protect.

## `-X theirs` (Default)

**"When in doubt, take what's coming from the source."**

```bash
./gitmux.sh -r source -t dest           # uses theirs by default
./gitmux.sh -r source -t dest -X theirs # explicit
```

**Example:** The monorepo's `utils.py` has important upstream fixes. With `theirs`, gitmux takes the source's version of conflicting lines — upstream changes come through as expected.

## `-X ours`

**"When in doubt, keep what's already in the destination."**

```bash
./gitmux.sh -r source -t dest -X ours
```

Use this when your destination has intentional local changes you want to protect.

**Caution:** With `ours`, conflicting source changes are silently dropped. The PR will show what was added, but won't show what *should have been* added but wasn't.

**Example:** You extracted `utils.py` and made local improvements. With `ours`, gitmux keeps the destination's version of conflicting lines — your local changes are preserved, but upstream conflict changes are lost.

## `-X patience`

**"Take more time to find a better diff."**

```bash
./gitmux.sh -r source -t dest -X patience
```

The patience algorithm produces cleaner diffs when code has been moved around or refactored. It's particularly good at matching up function boundaries correctly.

**Example:** A file was reorganized — functions were reordered, blank lines added. The standard diff might match the wrong sections together. Patience diff is smarter about finding the "right" matches, resulting in fewer false conflicts.

## Diff Algorithms

The diff algorithm determines how git figures out what changed between two versions:

| Algorithm | Description | Best for |
|-----------|-------------|----------|
| `histogram` | gitmux default. Extends patience to support low-occurrence common elements | Code with repeated patterns or blocks |
| `patience` | Matches unique lines first, then fills in gaps | Highly structured code |
| `minimal` | Spends extra time to produce the smallest diff | When you need the most compact diff |
| `myers` | Git's default. Basic greedy diff algorithm | General purpose, fast |

```bash
# gitmux uses histogram by default, but you can override:
./gitmux.sh -r source -t dest -X diff-algorithm=myers
./gitmux.sh -r source -t dest -X patience  # shorthand
```

## Custom Options with `-o`

For advanced use cases, pass any valid `git rebase` options directly:

```bash
# Combine strategies
./gitmux.sh -r source -t dest -o "--strategy-option=theirs --strategy-option=patience"

# Specify diff algorithm explicitly
./gitmux.sh -r source -t dest -o "--strategy-option=diff-algorithm=histogram"
```

## Interactive Mode with `-i`

When automatic resolution isn't enough, use interactive mode to resolve conflicts manually:

```bash
./gitmux.sh -r source -t dest -i
```

gitmux will pause and provide a `cd` command to enter the workspace. Resolve conflicts, complete the rebase, then push to the `destination` remote.
