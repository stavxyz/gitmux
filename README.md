# gitmux

[![CI](https://github.com/stavxyz/gitmux/actions/workflows/ci.yml/badge.svg)](https://github.com/stavxyz/gitmux/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docs](https://img.shields.io/badge/docs-gitmux.com-blue)](https://gitmux.com)

**Extract files from one repo to another while preserving full git history.**

```bash
# Extract packages/auth from a monorepo into its own repo
./gitmux.sh -r github.com/company/monorepo -t github.com/company/auth-lib -d packages/auth -s
```

Every commit, every blame, every bisect — preserved.

**[Documentation](https://gitmux.com)** · **[Usage Reference](https://gitmux.com/usage.html)** · **[FAQ](https://gitmux.com/faq.html)**

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

## Documentation

Full documentation available at **[gitmux.com](https://gitmux.com)**:

- [Usage Reference](https://gitmux.com/usage.html) — All CLI options and environment variables
- [Rebase Strategies](https://gitmux.com/rebase-strategies.html) — Conflict resolution and diff algorithms
- [Filter Backend](https://gitmux.com/filter-backend.html) — filter-repo vs filter-branch
- [FAQ](https://gitmux.com/faq.html) — Common questions answered

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

[GPL-3.0](LICENSE) — Free software. Share improvements.

---

**[gitmux.com](https://gitmux.com)** · **[Issues](https://github.com/stavxyz/gitmux/issues)** · **[Email](mailto:hi@stav.xyz)**
