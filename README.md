# gitmux

**Sync repository subsets while preserving full git history.**

If you've ever thought "I wish this were a separate repo", you've come to the right place.

## Overview

gitmux extracts files or directories from a source repository into a destination repository while maintaining complete commit history and tags. Unlike copy-paste, gitmux preserves the full provenance of your code.

### Key Features

- **History Preservation** - Maintains complete commit history for synced content
- **Selective Extraction** - Fork entire repos or just specific files/directories
- **Multi-Path Migration** - Sync multiple directories in a single operation with `-m`
- **Safe by Design** - Changes go through pull requests, never direct pushes
- **Repeatable** - Run multiple times to sync incremental updates
- **Flexible Rebase** - Multiple strategies for conflict resolution ([see below](#rebase-strategies))
- **Author Rewriting** - Override commit author/committer across entire history
- **AI Attribution Cleanup** - Remove Claude/Anthropic co-author trailers while preserving human contributors
- **Dry-Run Mode** - Preview all changes before modifying anything
- **Pre-flight Checks** - Validates permissions and access before long-running operations
- **Configurable Logging** - Debug, info, warning, or error log levels

## Installation

### Prerequisites

- Bash 4.0+
- Git
- [GitHub CLI (`gh`)](https://cli.github.com/) - for `-s`, `-c`, `-z` flags
- jq

### Quick Install

```bash
# Clone the repository
git clone https://github.com/stavxyz/gitmux.git
cd gitmux

# Make executable (if needed)
chmod +x gitmux.sh

# Verify installation
./gitmux.sh -h
```

### Docker

```bash
# Build the image
just docker-build

# Run interactively
just docker-run
```

## Quick Start

### Basic Sync (Full Repository)

```bash
./gitmux.sh \
  -r https://github.com/source-owner/source-repo \
  -t https://github.com/dest-owner/dest-repo \
  -s  # Submit PR automatically
```

### Extract a Subdirectory

```bash
./gitmux.sh \
  -r https://github.com/source-owner/monorepo \
  -t https://github.com/dest-owner/extracted-lib \
  -d packages/my-library \
  -s
```

### Extract Specific Files

```bash
./gitmux.sh \
  -r https://github.com/source-owner/source-repo \
  -t https://github.com/dest-owner/dest-repo \
  -l '--all -- src/utils.py src/helpers.py' \
  -s
```

### Migrate Multiple Directories

Sync multiple source paths to different destinations in one operation:

```bash
./gitmux.sh \
  -r https://github.com/source-owner/monorepo \
  -t https://github.com/dest-owner/dest-repo \
  -m 'src/lib:packages/lib' \
  -m 'tests/lib:packages/lib/tests' \
  -s
```

This creates a single PR with both paths migrated, preserving history for each.

### Create Destination if Missing

```bash
./gitmux.sh \
  -r https://github.com/source-owner/source-repo \
  -t https://github.com/dest-owner/new-repo \
  -c  # Create destination repo
  -s
```

### Override Author and Clean Up AI Attribution

When syncing AI-assisted code, you may want to rewrite authorship and remove AI co-author trailers:

```bash
./gitmux.sh \
  -r https://github.com/source-owner/source-repo \
  -t https://github.com/dest-owner/dest-repo \
  --author-name "Your Name" \
  --author-email "you@example.com" \
  --coauthor-action claude \
  -s
```

This rewrites all commits to show you as the author while removing Claude/Anthropic `Co-authored-by` and `Generated with` lines (human co-authors are preserved).

### Preview Changes with Dry-Run

Before running a sync, preview what would happen:

```bash
./gitmux.sh \
  -r https://github.com/source-owner/source-repo \
  -t https://github.com/dest-owner/dest-repo \
  --author-name "Your Name" \
  --author-email "you@example.com" \
  --dry-run
```

This shows you exactly which commits would be affected and what changes would be made, without modifying anything.

## Usage

```
gitmux.sh [-r SOURCE] [-t DESTINATION] [OPTIONS]

Required:
  -r <repository>     Source repository (URL or local path)
  -t <repository>     Destination repository (URL or local path)

Filtering:
  -d <path>           Extract only this subdirectory
  -p <path>           Place content at this path in destination
  -m <src:dest>       Map source path to destination path (repeatable)
                      Use \: to escape literal colons in paths
                      Cannot be combined with -d or -p
  -l <rev-list>       Extract specific files (git rev-list format)
                      Note: file paths with spaces are not supported
  -g <gitref>         Source git ref (branch, tag, commit)

Destination:
  -b <branch>         Target branch in destination (default: trunk)
  -c                  Create destination repo if it doesn't exist

Rebase:
  -X <strategy>       Rebase strategy: theirs, ours, patience (default: theirs)
  -o <options>        Custom git rebase options
  -i                  Interactive rebase mode

GitHub:
  -s                  Submit PR automatically (requires gh)
  -z <org/team>       Add team to destination repo (repeatable)

Author/Committer Override:
  -N, --author-name       Override author name (requires --author-email)
  -E, --author-email      Override author email (requires --author-name)
  -n, --committer-name    Override committer name (requires --committer-email)
  -e, --committer-email   Override committer email (requires --committer-name)
  -C, --coauthor-action   Handle Co-authored-by trailers: claude|all|keep
                          - claude: Remove Claude/Anthropic attribution only
                                    (default when author/committer options used)
                          - all: Remove all Co-authored-by trailers
                          - keep: Preserve all trailers (default otherwise)
  -D, --dry-run           Preview changes without modifying anything

Logging & Diagnostics:
  -L, --log-level     Log verbosity: debug, info, warning, error (default: info)
  -S, --skip-preflight  Skip pre-flight validation checks (advanced use)
  -k                  Keep temp workspace (for debugging)
  -v                  Verbose output (sets log level to debug)
  -h                  Show help
```

### Environment Variables

All author/committer options can also be set via environment variables:

| Option | Environment Variable |
|--------|---------------------|
| `--author-name` | `GITMUX_AUTHOR_NAME` |
| `--author-email` | `GITMUX_AUTHOR_EMAIL` |
| `--committer-name` | `GITMUX_COMMITTER_NAME` |
| `--committer-email` | `GITMUX_COMMITTER_EMAIL` |
| `--coauthor-action` | `GITMUX_COAUTHOR_ACTION` |
| `--log-level` | `GITMUX_LOG_LEVEL` |

## Pre-flight Checks

Before starting any long-running operations (cloning, filter-branch, rebase), gitmux validates that everything is in place:

```
[INFO] 🔍 Running pre-flight checks...
  ✅ git installed
  ✅ gh CLI installed
  ✅ gh authenticated (yourname)
  ✅ source repo accessible
  ✅ destination repo accessible with push access
  ✅ destination branch exists (main)
[INFO] ✅ All pre-flight checks passed!
```

If any check fails, gitmux provides actionable error messages:

```
[INFO] 🔍 Running pre-flight checks...
  ✅ git installed
  ✅ gh CLI installed
  ✅ gh authenticated (yourname)
  ✅ source repo accessible
  ❌ destination repo not accessible

[ERROR]   📂 gh cannot access this repository. This may be because:
[ERROR]     - The repository doesn't exist (use -c to create it)
[ERROR]     - You don't have permission to access it
[ERROR]     - GH_TOKEN is set to a token without access
[ERROR]     - Try: unset GH_TOKEN && gh auth status

[ERROR] ❌ Pre-flight checks failed. Aborting.
```

Use `--skip-preflight` to bypass these checks (advanced use only).

## How It Works

1. **Clone** - gitmux clones the source repository to a temp workspace
2. **Filter** - Uses `git filter-branch` to extract selected content
3. **Rebase** - Rebases filtered history onto destination branch
4. **Push** - Pushes to a feature branch (`update-from-<branch>-<sha>`)
5. **PR** - Optionally creates a pull request via GitHub CLI
6. **Cleanup** - Removes temp workspace

```
┌─────────────┐    filter-branch    ┌─────────────┐
│   Source    │ ─────────────────▶  │   Filtered  │
│ Repository  │                     │   Content   │
└─────────────┘                     └──────┬──────┘
                                           │
                                      rebase onto
                                           │
                                           ▼
┌─────────────┐    pull request     ┌─────────────┐
│ Destination │ ◀───────────────── │   Feature   │
│   Branch    │                     │   Branch    │
└─────────────┘                     └─────────────┘
```

## Who Is This For?

- **Monorepo extractors** - Fork a subset into a standalone repo
- **Gist upgraders** - Turn a GitHub gist into a full repository
- **History preservers** - Redo a copy-paste with proper git history
- **Git power users** - Explore rebase strategies and conflict resolution
- **Automation bots** - Keep downstream mirrors in sync via PRs

## Rebase Strategies

When gitmux rebases the source history onto the destination, conflicts can occur if the same lines were changed in both places. The `-X` option controls how these conflicts are resolved automatically.

**Why `theirs` is the default:** When you run gitmux, your intent is to get content from the source. If conflicts occur and source changes are dropped (as with `ours`), you might never notice—the PR shows what was added, not what *should have been* added. But if destination changes are dropped (as with `theirs`), those deletions appear in the PR diff, giving you a chance to catch them before merging. Override with `-X ours` if your destination has changes you want to protect.

### Understanding the Strategies

| Strategy | When a conflict occurs... | Best for |
|----------|--------------------------|----------|
| `theirs` (default) | Keep the source's version | Most syncs — you want the source content |
| `ours` | Keep the destination's version | Protecting local destination changes |
| `patience` | Use smarter diff algorithm | Cleaner diffs with moved/refactored code |
| `diff-algorithm=<algo>` | Change how diffs are computed | Fine-tuning diff quality (histogram, minimal, myers) |

### `-X theirs` (Default)

**"When in doubt, take what's coming from the source."**

This is the default because it aligns with user intent: when you run gitmux, you're trying to get content from the source repository.

```bash
./gitmux.sh -r source -t dest           # uses theirs by default
./gitmux.sh -r source -t dest -X theirs # explicit
```

**Why this default?** If conflicts are resolved by keeping the source's version, any overwritten destination content will be **visible in the PR diff**. You'll see lines being removed from destination files, giving you a chance to review before merging. This is better than the alternative (`ours`), where dropped source changes are invisible—you'd never know they were supposed to be there.

**Example:** The monorepo's `utils.py` has important upstream fixes. With `theirs`, gitmux takes the source's version of conflicting lines—upstream changes come through as expected.

### `-X ours`

**"When in doubt, keep what's already in the destination."**

Use this when your destination has intentional local changes you want to protect, and you're selectively pulling from source.

```bash
./gitmux.sh -r source -t dest -X ours
```

**Caution:** With `ours`, conflicting source changes are silently dropped. The PR will show what was added, but won't show what *should have been* added but wasn't. Use this only when you're confident destination changes should take precedence.

**Example:** You extracted `utils.py` and made local improvements. With `ours`, gitmux keeps the destination's version of conflicting lines—your local changes are preserved, but upstream conflict changes are lost.

### `-X patience`

**"Take more time to find a better diff."**

The patience algorithm produces cleaner diffs when code has been moved around or refactored. It's particularly good at matching up function boundaries correctly.

```bash
./gitmux.sh -r source -t dest -X patience
```

**Example:** A file was reorganized—functions were reordered, blank lines added. The standard diff might match the wrong sections together. Patience diff is smarter about finding the "right" matches, resulting in fewer false conflicts.

### `-X diff-algorithm=<algo>`

**"Change how git computes the diff itself."**

The diff algorithm determines how git figures out what changed between two versions. Different algorithms have different trade-offs:

| Algorithm | Description | Best for |
|-----------|-------------|----------|
| `myers` | Default. Fast, minimal edit distance | Most cases |
| `minimal` | Like myers, but tries harder to minimize diff size | When you want the smallest possible diff |
| `patience` | Matches unique lines first, then fills in | Code with clear structure (functions, classes) |
| `histogram` | Enhanced patience with better performance | Large files, code with repetitive patterns |

```bash
# Use histogram algorithm (often best for code)
./gitmux.sh -r source -t dest -X diff-algorithm=histogram

# Use minimal algorithm
./gitmux.sh -r source -t dest -X diff-algorithm=minimal
```

**When to use what:**
- **`histogram`** is generally the best choice for code—it's what GitHub uses internally
- **`patience`** (shorthand `-X patience`) is good when histogram produces weird results
- **`minimal`** when you want the mathematically smallest diff
- **`myers`** (default) when speed matters more than diff quality

### Custom Options with `-o`

For advanced use cases, pass any valid `git rebase` options directly:

```bash
# Combine strategies
./gitmux.sh -r source -t dest -o "--strategy-option=theirs --strategy-option=patience"

# Specify diff algorithm explicitly
./gitmux.sh -r source -t dest -o "--strategy-option=diff-algorithm=histogram"
```

### Interactive Mode with `-i`

When automatic resolution isn't enough, use interactive mode to resolve conflicts manually:

```bash
./gitmux.sh -r source -t dest -i
```

gitmux will pause and provide a `cd` command to enter the workspace. Resolve conflicts, complete the rebase, then push to the `destination` remote.

## FAQ

**Q: Why doesn't gitmux push directly to my destination branch?**

A: That's dangerous. Pull requests provide an audit trail and allow review before merging. gitmux creates a unique feature branch for each sync.

**Q: Can I use a local directory as the source?**

A: Yes. Local paths are faster but using URLs ensures you don't miss upstream updates.

**Q: Can I manage the rebase manually?**

A: Yes! Use `-i` for interactive rebase. gitmux will give you a `cd` command to enter the workspace. Complete the rebase and push to the remote named `destination`.

**Q: What if there are merge conflicts?**

A: gitmux uses the rebase strategy specified by `-X` (default: `theirs`). For complex conflicts, use `-i` for manual resolution.

**Q: Can I run gitmux multiple times?**

A: Yes. gitmux is designed for repeated runs. Each run creates a new PR with the latest changes from the source.

**Q: Can I migrate multiple directories at once?**

A: Yes. Use the `-m` flag multiple times to specify source:destination mappings. For example: `-m 'src:pkg/src' -m 'tests:pkg/tests'`. All paths are processed in a single operation, creating one branch and one PR. Use `\:` to escape literal colons in paths.

**Q: How do I remove AI-generated attribution from commits?**

A: Use `--coauthor-action claude` to remove Claude/Anthropic attribution while preserving human co-authors. Use `--coauthor-action all` to remove all co-author trailers. Combine with `--author-name` and `--author-email` to also rewrite commit authorship.

**Q: Can I set author/committer options via environment variables?**

A: Yes. All author/committer options have corresponding environment variables: `GITMUX_AUTHOR_NAME`, `GITMUX_AUTHOR_EMAIL`, `GITMUX_COMMITTER_NAME`, `GITMUX_COMMITTER_EMAIL`, and `GITMUX_COAUTHOR_ACTION`.

**Q: How can I preview what gitmux will do before running it?**

A: Use `--dry-run` (or `-D`). This shows you the source/destination, which commits would be affected, what author/committer changes would be made, and which co-author trailers would be removed—all without modifying anything.

**Q: What's the difference between author and committer?**

A: In git, the **author** is who wrote the code, and the **committer** is who applied the commit. They're often the same person, but differ in scenarios like cherry-picking or rebasing. Use `--author-*` to change who wrote the code; use `--committer-*` to change who committed it.

**Q: How do I see more detailed output?**

A: Use `-v` for verbose output (debug level), or set `--log-level debug` for maximum detail. Log levels from most to least verbose: `debug`, `info` (default), `warning`, `error`. You can also set `GITMUX_LOG_LEVEL=debug` in your environment.

**Q: Why did gitmux fail before doing any work?**

A: gitmux runs pre-flight checks to validate permissions and access before starting long-running operations. This prevents wasted time from failures late in the process. Check the error message for what's missing (e.g., repository access, branch existence). Use `--skip-preflight` to bypass these checks if you know what you're doing.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and PR guidelines.

## License

[Unlicense](LICENSE) - Public domain. Do whatever you want with this.

## Contact

- **Issues**: [GitHub Issues](https://github.com/stavxyz/gitmux/issues)
- **Email**: hi@stav.xyz
