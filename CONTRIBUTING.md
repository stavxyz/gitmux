# Contributing to gitmux

## Development Setup

### Prerequisites

- [Bash 4.0+](https://www.gnu.org/software/bash/)
- [Git](https://git-scm.com/)
- [GitHub CLI (`gh`)](https://cli.github.com/)
- [jq](https://jqlang.github.io/jq/)
- [ShellCheck](https://www.shellcheck.net/)
- [just](https://github.com/casey/just)

Optional: **Python 3.11+** (for helper scripts and quality checks)

### Quick Start

```bash
git clone https://github.com/stavxyz/gitmux.git
cd gitmux
just setup
gh auth login
```

## Running Tests

**Unit tests** (no credentials required):

```bash
just test-bats
```

**Integration tests** (creates and deletes real GitHub repos):

```bash
just test-shell
```

Integration tests require `gh auth login` with `repo` and `delete_repo` scopes.
If `GH_TOKEN` is set in your environment, it overrides `gh` login credentials.

**All checks** (lint, format, typecheck, test):

```bash
just check
```

## Pull Request Process

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   ```

2. Make changes with atomic commits using conventional prefixes:
   ```
   feat: add new feature
   fix: resolve bug in X
   docs: update README
   refactor: simplify function Y
   test: add tests for Z
   ```

3. Run all checks:
   ```bash
   just check
   ```

4. Push and open a PR:
   ```bash
   git push -u origin feature/my-feature
   gh pr create
   ```

## License

By contributing to gitmux, you agree that your contributions will be
licensed under the [GPL-3.0 License](LICENSE).
