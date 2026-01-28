---
layout: default
title: Usage
nav_order: 2
---

# Usage Reference

```
gitmux.sh -r SOURCE -t DESTINATION [OPTIONS]
```

## Required Options

| Option | Description |
|--------|-------------|
| `-r <url\|path>` | Source repository |
| `-t <url\|path>` | Destination repository |

## Path Filtering

| Option | Description |
|--------|-------------|
| `-m <src:dest>` | Map source path to destination (repeatable) |
| `-d <path>` | Extract subdirectory from source |
| `-p <path>` | Place content at path in destination |
| `-g <ref>` | Source git ref: branch, tag, or commit |
| `-l <rev-list>` | Extract specific files (git rev-list format) |

### Multi-path Mapping

Use `-m` multiple times to migrate several paths in one operation:

```bash
./gitmux.sh \
  -r source -t dest \
  -m 'src/lib:packages/lib' \
  -m 'tests/lib:packages/lib/tests' \
  -m 'docs:packages/lib/docs' \
  -s
```

Use `\:` to escape literal colons in paths. Empty string or `.` means root.

## Destination Options

| Option | Description |
|--------|-------------|
| `-b <branch>` | Target branch (default: main/master) |
| `-c` | Create destination repo if missing (requires gh) |

## Rebase Options

| Option | Description |
|--------|-------------|
| `-X <strategy>` | `theirs` \| `ours` \| `patience` (default: theirs) |
| `-o <options>` | Custom git rebase options |
| `-i` | Interactive rebase mode |

See [Rebase Strategies]({% link rebase-strategies.md %}) for detailed guidance.

## GitHub Integration

| Option | Description |
|--------|-------------|
| `-s` | Submit PR automatically (requires gh) |
| `-z <org/team>` | Add team to destination repo (repeatable) |

## Author Rewriting

| Option | Description |
|--------|-------------|
| `--author-name <name>` | Override author name for all commits |
| `--author-email <email>` | Override author email for all commits |
| `--committer-name <name>` | Override committer name |
| `--committer-email <email>` | Override committer email |
| `--coauthor-action <act>` | `claude` \| `all` \| `keep` |
| `--dry-run` | Preview changes without modifying anything |

### Co-author Actions

| Action | Behavior |
|--------|----------|
| `claude` | Remove Claude/Anthropic attribution, keep human co-authors |
| `all` | Remove all co-author trailers |
| `keep` | Preserve all trailers (default when no author options used) |

## Filter Backend

| Option | Description |
|--------|-------------|
| `--filter-backend <be>` | `filter-branch` \| `filter-repo` \| `auto` |

See [Filter Backend]({% link filter-backend.md %}) for details.

## Logging & Debug

| Option | Description |
|--------|-------------|
| `--log-level <level>` | `debug` \| `info` \| `warning` \| `error` |
| `--skip-preflight` | Skip pre-flight validation checks |
| `-k` | Keep temp workspace for debugging |
| `-v` | Verbose output (sets log level to debug) |
| `-h` | Show help |

## Environment Variables

All options can be set via environment variables:

| CLI Option | Environment Variable |
|------------|---------------------|
| `--author-name` | `GITMUX_AUTHOR_NAME` |
| `--author-email` | `GITMUX_AUTHOR_EMAIL` |
| `--committer-name` | `GITMUX_COMMITTER_NAME` |
| `--committer-email` | `GITMUX_COMMITTER_EMAIL` |
| `--coauthor-action` | `GITMUX_COAUTHOR_ACTION` |
| `--filter-backend` | `GITMUX_FILTER_BACKEND` |
| `--log-level` | `GITMUX_LOG_LEVEL` |

CLI options take precedence over environment variables.
