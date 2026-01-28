# gitmux

[![CI](https://github.com/stavxyz/gitmux/actions/workflows/ci.yml/badge.svg)](https://github.com/stavxyz/gitmux/actions/workflows/ci.yml)
[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)

**Extract files from one repo to another while preserving full git history.**

```bash
# Extract packages/auth from a monorepo into its own repo
./gitmux.sh -r github.com/company/monorepo -t github.com/company/auth-lib -d packages/auth -s
```

Every commit, every blame, every bisect — preserved.

---

## Why gitmux?

- **Full history** — Not a copy-paste. Every commit follows the code.
- **PR-based** — Changes go through pull requests, never direct pushes.
- **10x faster** — Auto-uses [git-filter-repo](https://github.com/newren/git-filter-repo) when available.
- **Multi-path** — Migrate multiple directories in one operation.

## Install

```bash
git clone https://github.com/stavxyz/gitmux.git
cd gitmux && ./gitmux.sh -h
```

**Optional** (10x speedup): `brew install git-filter-repo` or `pip install git-filter-repo`

## Quick Start

### Extract a subdirectory

```bash
./gitmux.sh \
  -r https://github.com/source-owner/monorepo \
  -t https://github.com/dest-owner/extracted-lib \
  -d packages/my-library \
  -s  # Submit PR automatically
```

### Migrate multiple paths

```bash
./gitmux.sh \
  -r https://github.com/source/monorepo \
  -t https://github.com/dest/new-repo \
  -m 'src/lib:packages/lib' \
  -m 'tests/lib:packages/lib/tests' \
  -s
```

### Rewrite authorship

```bash
./gitmux.sh \
  -r source -t dest \
  --author-name "Your Name" \
  --author-email "you@example.com" \
  --coauthor-action claude \
  -s
```

Removes AI attribution while preserving human co-authors.

## Usage

```
gitmux.sh -r SOURCE -t DESTINATION [OPTIONS]

Required:
  -r <url|path>              Source repository
  -t <url|path>              Destination repository

Path Filtering:
  -m <src:dest>              Map source path to destination (repeatable)
  -d <path>                  Extract subdirectory from source
  -p <path>                  Place content at path in destination
  -l <rev-list>              Extract specific files

Destination:
  -b <branch>                Target branch (default: main/master)
  -c                         Create destination repo if missing

Rebase:
  -X <strategy>              theirs|ours|patience (default: theirs)
  -i                         Interactive rebase mode

GitHub Integration:
  -s                         Submit PR automatically
  -z <org/team>              Add team to destination repo

Author Rewriting:
  --author-name <name>       Override author name
  --author-email <email>     Override author email
  --coauthor-action <act>    claude|all|keep (remove co-author trailers)
  --dry-run                  Preview without changes

Filtering:
  --filter-backend <be>      filter-branch|filter-repo|auto

Logging:
  --log-level <level>        debug|info|warning|error
  -v                         Verbose (debug level)
  -h                         Show help
```

### Environment Variables

| CLI Option | Environment Variable |
|------------|---------------------|
| `--author-name` | `GITMUX_AUTHOR_NAME` |
| `--author-email` | `GITMUX_AUTHOR_EMAIL` |
| `--coauthor-action` | `GITMUX_COAUTHOR_ACTION` |
| `--filter-backend` | `GITMUX_FILTER_BACKEND` |
| `--log-level` | `GITMUX_LOG_LEVEL` |

## How It Works

```
┌─────────────┐                      ┌─────────────┐
│   Source    │ ──── filter ────▶    │   Filtered  │
│ Repository  │                      │   Content   │
└─────────────┘                      └──────┬──────┘
                                            │
                                       rebase onto
                                            │
                                            ▼
┌─────────────┐                      ┌─────────────┐
│ Destination │ ◀── pull request ── │   Feature   │
│   Branch    │                      │   Branch    │
└─────────────┘                      └─────────────┘
```

1. **Clone** source to temp workspace
2. **Filter** to extract selected content (preserves history)
3. **Rebase** onto destination branch
4. **Push** to feature branch
5. **PR** via GitHub CLI (optional)

## FAQ

<details>
<summary><strong>Why pull requests instead of direct push?</strong></summary>

Direct pushes are dangerous. PRs provide an audit trail and allow review before merging.
</details>

<details>
<summary><strong>Can I run gitmux multiple times?</strong></summary>

Yes. Each run creates a new PR with the latest changes from source.
</details>

<details>
<summary><strong>What if there are merge conflicts?</strong></summary>

gitmux uses `-X theirs` by default (keep source changes). For complex conflicts, use `-i` for interactive mode.
</details>

<details>
<summary><strong>How do I remove AI attribution from commits?</strong></summary>

Use `--coauthor-action claude` to remove Claude/Anthropic co-author trailers while preserving human contributors. Use `--coauthor-action all` to remove all co-author lines.
</details>

<details>
<summary><strong>What's the difference between author and committer?</strong></summary>

**Author** = who wrote the code. **Committer** = who applied the commit. Usually the same, but differ during cherry-picks or rebases.
</details>

## Advanced Topics

### Rebase Strategies

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `theirs` (default) | Keep source version on conflict | Most syncs |
| `ours` | Keep destination version | Protect local changes |
| `patience` | Smarter diff algorithm | Moved/refactored code |

**Why `theirs` is default:** When you run gitmux, you want source content. With `theirs`, any overwritten destination content appears in the PR diff — you'll see it. With `ours`, dropped source changes are invisible.

### Filter Backend

| Backend | Speed | Requirement |
|---------|-------|-------------|
| `filter-repo` | ~10x faster | Python 3.6+ |
| `filter-branch` | Baseline | Built into git |

gitmux auto-detects and uses filter-repo if available. Override with `--filter-backend`.

```bash
# Install filter-repo
brew install git-filter-repo      # macOS
apt install git-filter-repo       # Debian/Ubuntu
pip install git-filter-repo       # Any platform
```

### Pre-flight Checks

gitmux validates permissions before long-running operations:

```
[INFO] 🔍 Running pre-flight checks...
  ✅ git installed
  ✅ source repo accessible
  ✅ destination repo accessible with push access
[INFO] ✅ All pre-flight checks passed!
```

Skip with `--skip-preflight` if needed.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

[Unlicense](LICENSE) — Public domain. Do whatever you want.

---

**[Issues](https://github.com/stavxyz/gitmux/issues)** · **[Email](mailto:hi@stav.xyz)**
