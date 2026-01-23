# gitmux

**Sync repository subsets while preserving full git history.**

If you've ever thought "I wish this were a separate repo", you've come to the right place.

## Overview

gitmux extracts files or directories from a source repository into a destination repository while maintaining complete commit history and tags. Unlike copy-paste, gitmux preserves the full provenance of your code.

### Key Features

- **History Preservation** - Maintains complete commit history for synced content
- **Selective Extraction** - Fork entire repos or just specific files/directories
- **Safe by Design** - Changes go through pull requests, never direct pushes
- **Repeatable** - Run multiple times to sync incremental updates
- **Flexible Rebase** - Multiple strategies (ours/theirs/patience) for conflict resolution
- **Author Rewriting** - Override commit author/committer across entire history
- **AI Attribution Cleanup** - Remove Claude/Anthropic co-author trailers while preserving human contributors
- **Dry-Run Mode** - Preview all changes before modifying anything

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
make build

# Run interactively
make run
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
  -l <rev-list>       Extract specific files (git rev-list format)
                      Note: file paths with spaces are not supported
  -g <gitref>         Source git ref (branch, tag, commit)

Destination:
  -p <path>           Place content at this path in destination
  -b <branch>         Target branch in destination (default: trunk)
  -c                  Create destination repo if it doesn't exist

Rebase:
  -X <strategy>       Rebase strategy: ours, theirs, patience (default: ours)
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

Other:
  -k                  Keep temp workspace (for debugging)
  -v                  Verbose output
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

## FAQ

**Q: Why doesn't gitmux push directly to my destination branch?**

A: That's dangerous. Pull requests provide an audit trail and allow review before merging. gitmux creates a unique feature branch for each sync.

**Q: Can I use a local directory as the source?**

A: Yes. Local paths are faster but using URLs ensures you don't miss upstream updates.

**Q: Can I manage the rebase manually?**

A: Yes! Use `-i` for interactive rebase. gitmux will give you a `cd` command to enter the workspace. Complete the rebase and push to the remote named `destination`.

**Q: What if there are merge conflicts?**

A: gitmux uses the rebase strategy specified by `-X` (default: `ours`). For complex conflicts, use `-i` for manual resolution.

**Q: Can I run gitmux multiple times?**

A: Yes. gitmux is designed for repeated runs. Each run creates a new PR with the latest changes from the source.

**Q: How do I remove AI-generated attribution from commits?**

A: Use `--coauthor-action claude` to remove Claude/Anthropic attribution while preserving human co-authors. Use `--coauthor-action all` to remove all co-author trailers. Combine with `--author-name` and `--author-email` to also rewrite commit authorship.

**Q: Can I set author/committer options via environment variables?**

A: Yes. All author/committer options have corresponding environment variables: `GITMUX_AUTHOR_NAME`, `GITMUX_AUTHOR_EMAIL`, `GITMUX_COMMITTER_NAME`, `GITMUX_COMMITTER_EMAIL`, and `GITMUX_COAUTHOR_ACTION`.

**Q: How can I preview what gitmux will do before running it?**

A: Use `--dry-run` (or `-D`). This shows you the source/destination, which commits would be affected, what author/committer changes would be made, and which co-author trailers would be removed—all without modifying anything.

**Q: What's the difference between author and committer?**

A: In git, the **author** is who wrote the code, and the **committer** is who applied the commit. They're often the same person, but differ in scenarios like cherry-picking or rebasing. Use `--author-*` to change who wrote the code; use `--committer-*` to change who committed it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and PR guidelines.

## License

[Unlicense](LICENSE) - Public domain. Do whatever you want with this.

## Contact

- **Issues**: [GitHub Issues](https://github.com/stavxyz/gitmux/issues)
- **Email**: hi@stav.xyz
