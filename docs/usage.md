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

Two `-m` mappings may share the same **destination** as long as their
**sources differ** — gitmux allows it (with a warning) so you can reassemble a
file's history across renames, e.g. mapping both `old/name.py` and `new/name.py`
to `dot.py`.

## Destination Options

| Option | Description |
|--------|-------------|
| `-b <branch>` | Target branch in destination (default: main) |
| `-c` | Create destination repo if missing (requires gh) |

## Rebase Options

| Option | Description |
|--------|-------------|
| `-X <strategy>` | `theirs` \| `ours` \| `patience` (default: theirs) |
| `-o <options>` | Custom git rebase options (mutually exclusive with `-X`) |
| `-i` | Interactive rebase mode |

By default the rebase preserves each commit's original authorship date as its
committer date (`--committer-date-is-author-date`), so an extracted history keeps
its original timeline instead of collapsing to the moment gitmux ran (GitHub
orders and groups commits by committer date). Set the
`PRESERVE_COMMITTER_DATES=false` environment variable to use git's default
(committer date = now).

See [Rebase Strategies]({% link rebase-strategies.md %}) for detailed guidance.

## GitHub Integration

| Option | Description |
|--------|-------------|
| `-s` | Submit PR automatically (requires gh) |
| `-z <org/team>` | Add team to destination repo (repeatable) |

## Author Rewriting

| Option | Description |
|--------|-------------|
| `-N`, `--author-name <name>` | Override author name for all commits |
| `-E`, `--author-email <email>` | Override author email for all commits |
| `-n`, `--committer-name <name>` | Override committer name |
| `-e`, `--committer-email <email>` | Override committer email |
| `-C`, `--coauthor-action <act>` | `claude` \| `all` \| `keep` |

### Co-author Actions

| Action | Behavior |
|--------|----------|
| `claude` | Remove Claude/Anthropic attribution, keep human co-authors |
| `all` | Remove all co-author trailers |
| `keep` | Preserve all trailers (default when no author options used) |

## Filter Backend

| Option | Description |
|--------|-------------|
| `-F`, `--filter-backend <be>` | `filter-branch` \| `filter-repo` \| `auto` (default: auto) |

See [Filter Backend]({% link filter-backend.md %}) for details.

## Logging & Debug

| Option | Description |
|--------|-------------|
| `-L`, `--log-level <level>` | `debug` \| `info` \| `warning` \| `error` (default: info) |
| `-S`, `--skip-preflight` | Skip pre-flight validation checks |
| `-D`, `--dry-run` | Preview changes without modifying anything |
| `-k` | Keep temp workspace for debugging |
| `-v` | Verbose output (sets log level to debug) |
| `-h` | Show help |
| `-V`, `--version` | Show version and exit |

## Environment Variables

Most CLI options can also be set via an environment variable:

| CLI Option | Environment Variable |
|------------|---------------------|
| `-r` | `SOURCE_REPOSITORY` |
| `-t` | `DESTINATION_REPOSITORY` |
| `-d` | `SUBDIRECTORY_FILTER` |
| `-p` | `DESTINATION_PATH` |
| `-g` | `SOURCE_GIT_REF` |
| `-l` | `REV_LIST_FILES` |
| `-b` | `DESTINATION_BRANCH` |
| `-c` | `CREATE_NEW_REPOSITORY` |
| `-s` | `SUBMIT_PR` |
| `-i` | `INTERACTIVE_REBASE` |
| `-k` | `KEEP_TMP_WORKSPACE` |
| `-X` | `MERGE_STRATEGY_OPTION_FOR_REBASE` |
| `-o` | `REBASE_OPTIONS` |
| `-D`, `--dry-run` | `DRY_RUN` |
| `-S`, `--skip-preflight` | `SKIP_PREFLIGHT` |
| `-L`, `--log-level` | `GITMUX_LOG_LEVEL` |
| `-F`, `--filter-backend` | `GITMUX_FILTER_BACKEND` |
| `-N`, `--author-name` | `GITMUX_AUTHOR_NAME` |
| `-E`, `--author-email` | `GITMUX_AUTHOR_EMAIL` |
| `-n`, `--committer-name` | `GITMUX_COMMITTER_NAME` |
| `-e`, `--committer-email` | `GITMUX_COMMITTER_EMAIL` |
| `-C`, `--coauthor-action` | `GITMUX_COAUTHOR_ACTION` |

Some knobs have no CLI flag and are set only via the environment:

| Environment Variable | Default | Description |
|----------------------|---------|-------------|
| `PRESERVE_COMMITTER_DATES` | `true` | Preserve original authorship dates as committer dates on rebase (see [Rebase Options](#rebase-options)) |
| `GH_HOST` | `github.com` | GitHub host used for `gh` operations |

CLI options take precedence over environment variables.
