---
layout: default
title: FAQ
nav_order: 5
---

# Frequently Asked Questions

## General

### Why doesn't gitmux push directly to my destination branch?

That's dangerous. Pull requests provide an audit trail and allow review before merging. gitmux creates a unique feature branch for each sync (`update-from-<branch>-<sha>`).

### Can I use a local directory as the source?

Yes. Local paths are faster but using URLs ensures you don't miss upstream updates.

### Can I run gitmux multiple times?

Yes. gitmux is designed for repeated runs. Each run creates a new PR with the latest changes from the source.

### Who is gitmux for?

- **Monorepo extractors** — Fork a subset into a standalone repo
- **Gist upgraders** — Turn a GitHub gist into a full repository
- **History preservers** — Redo a copy-paste with proper git history
- **Git power users** — Explore rebase strategies and conflict resolution
- **Automation bots** — Keep downstream mirrors in sync via PRs

## Conflicts

### What if there are merge conflicts?

gitmux uses the rebase strategy specified by `-X` (default: `theirs`). With `theirs`, source changes are preferred. For complex conflicts, use `-i` for manual resolution.

### Can I manage the rebase manually?

Yes! Use `-i` for interactive rebase. gitmux will give you a `cd` command to enter the workspace. Complete the rebase and push to the remote named `destination`.

## Path Mapping

### Can I migrate multiple directories at once?

Yes. Use the `-m` flag multiple times:

```bash
./gitmux.sh \
  -r source -t dest \
  -m 'src:pkg/src' \
  -m 'tests:pkg/tests' \
  -s
```

All paths are processed in a single operation, creating one branch and one PR.

### How do I handle colons in path names?

Use `\:` to escape literal colons:

```bash
-m 'path\:with\:colons:destination'
```

## Author Rewriting

### How do I remove AI-generated attribution from commits?

Use `--coauthor-action claude` to remove Claude/Anthropic attribution while preserving human co-authors:

```bash
./gitmux.sh \
  -r source -t dest \
  --author-name "Your Name" \
  --author-email "you@example.com" \
  --coauthor-action claude \
  -s
```

Use `--coauthor-action all` to remove all co-author trailers.

### What's the difference between author and committer?

In git:
- **Author** = who wrote the code
- **Committer** = who applied the commit

They're often the same person, but differ in scenarios like cherry-picking or rebasing. Use `--author-*` to change who wrote the code; use `--committer-*` to change who committed it.

### Can I set author/committer options via environment variables?

Yes:

| Option | Environment Variable |
|--------|---------------------|
| `--author-name` | `GITMUX_AUTHOR_NAME` |
| `--author-email` | `GITMUX_AUTHOR_EMAIL` |
| `--committer-name` | `GITMUX_COMMITTER_NAME` |
| `--committer-email` | `GITMUX_COMMITTER_EMAIL` |
| `--coauthor-action` | `GITMUX_COAUTHOR_ACTION` |

## Troubleshooting

### How can I preview what gitmux will do before running it?

Use `--dry-run` (or `-D`). This shows you the source/destination, which commits would be affected, what author/committer changes would be made, and which co-author trailers would be removed — all without modifying anything.

### How do I see more detailed output?

Use `-v` for verbose output (debug level), or set `--log-level debug` for maximum detail. Log levels from most to least verbose: `debug`, `info` (default), `warning`, `error`.

### Why did gitmux fail before doing any work?

gitmux runs pre-flight checks to validate permissions and access before starting long-running operations. This prevents wasted time from failures late in the process.

Check the error message for what's missing (e.g., repository access, branch existence). Use `--skip-preflight` to bypass these checks if you know what you're doing.

### How do I get faster performance?

Install git-filter-repo:

```bash
brew install git-filter-repo      # macOS
apt install git-filter-repo       # Debian/Ubuntu
pip install git-filter-repo       # Any platform
```

gitmux auto-detects and uses it when available for ~10x speedup. See [Filter Backend]({% link filter-backend.md %}) for details.

### The temp workspace wasn't cleaned up

Use `-k` to intentionally keep the workspace for debugging. Otherwise, this might indicate gitmux was interrupted. The workspace location is printed in the output — you can safely delete it manually.
