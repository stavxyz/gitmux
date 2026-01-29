---
layout: default
title: Home
nav_order: 1
permalink: /
---

# gitmux

[![GitHub Release](https://img.shields.io/github/v/release/stavxyz/gitmux)](https://github.com/stavxyz/gitmux/releases/latest)

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

---

[Usage Reference]({% link usage.md %}){: .btn .btn-primary }
[FAQ]({% link faq.md %}){: .btn }
[GitHub](https://github.com/stavxyz/gitmux){: .btn }
