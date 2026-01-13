# Contributing to gitmux

Thank you for your interest in contributing to gitmux! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Development Setup](#development-setup)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Pull Request Process](#pull-request-process)
- [Project Structure](#project-structure)

## Development Setup

### Prerequisites

- **Bash 4.0+** - The main script requires modern bash features
- **Git** - For version control and script functionality
- **GitHub CLI (`gh`)** - Required for `-s`, `-c`, and `-z` flags ([install guide](https://cli.github.com/))
- **jq** - JSON processor for API responses
- **ShellCheck** - For linting shell scripts ([install guide](https://www.shellcheck.net/))
- **just** - Task runner for common operations ([install guide](https://github.com/casey/just))

### Optional (for Python tooling)

- **Python 3.11+** - For helper scripts and quality checks
- **direnv** - Automatic environment loading ([install guide](https://direnv.net/))

### Quick Start

```bash
# Clone the repository
git clone https://github.com/stavxyz/gitmux.git
cd gitmux

# Run setup (creates venv, installs dependencies, git hooks)
just setup

# Or manually:
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### Environment Configuration

Copy the environment template and customize:

```bash
cp .envrc.example .envrc
# Edit .envrc with your settings
direnv allow  # If using direnv
```

## Running Tests

### Shell Script Tests

```bash
# Run integration tests (requires GitHub credentials)
just test-shell

# Or directly:
./test_gitmux.sh

# Run unit tests (bats)
just test-bats
bats tests/
```

### Python Tests (if applicable)

```bash
# Run all Python tests
just test-python
pytest tests/ -v

# With coverage
pytest tests/ --cov=src --cov-report=term-missing
```

### All Quality Checks

```bash
# Run all checks (lint, format, typecheck, test)
just check

# Individual checks:
just lint      # ShellCheck + ruff
just format    # Format Python code
```

## Code Style

### Shell Scripts

- Follow [ShellCheck](https://www.shellcheck.net/) recommendations
- Use `set -euoE pipefail` for strict error handling
- Quote all variable expansions: `"${variable}"`
- Use `[[ ]]` for conditionals (not `[ ]`)
- Add function docstrings as comments above each function:

```bash
# Description of what the function does
# Arguments:
#   $1 - description of first argument
#   $2 - description of second argument
# Returns:
#   0 on success, 1 on error
function my_function() {
    local arg1="${1}"
    local arg2="${2}"
    # implementation
}
```

### Python Code

- Follow [PEP 8](https://peps.python.org/pep-0008/) style guide
- Use type hints for all function signatures
- Use `ruff` for linting and formatting
- Use `mypy` for type checking

## Pull Request Process

### Before You Start

1. **Create a feature branch** - Never commit directly to main:
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Check existing issues** - Look for related issues or discussions

### Making Changes

1. **Make atomic commits** - One logical change per commit
2. **Write clear commit messages** - Follow [conventional commits](https://www.conventionalcommits.org/):
   ```
   feat: add new feature
   fix: resolve bug in X
   docs: update README
   refactor: simplify function Y
   test: add tests for Z
   ```

3. **Run all checks before pushing**:
   ```bash
   just check
   ```

### Submitting Your PR

1. **Push your branch**:
   ```bash
   git push -u origin feature/my-feature
   ```

2. **Create the pull request**:
   ```bash
   gh pr create
   ```

3. **PR Description should include**:
   - Summary of changes
   - Related issue numbers (if any)
   - Test plan / verification steps
   - Screenshots (for UI changes)

### Review Process

- All PRs require at least one approval
- CI checks must pass
- Address review feedback promptly
- Keep PRs focused and reasonably sized

## Project Structure

```
gitmux/
├── gitmux.sh              # Main script (748 lines)
├── test_gitmux.sh         # Integration tests
├── tests/                 # Unit tests (bats)
│   └── test_gitmux_unit.bats
├── Dockerfile             # Docker container
├── Makefile              # Docker build targets
├── justfile              # Task runner commands
├── .github/
│   ├── workflows/        # CI/CD pipelines
│   │   ├── shellcheck.yml
│   │   └── python-quality.yml
│   └── ISSUE_TEMPLATE/   # Issue templates
├── .claude/              # AI assistant configuration
│   ├── CLAUDE.md        # Project instructions
│   ├── docs/            # Standards documentation
│   └── knowledge/       # Tactical guides
└── README.md            # User documentation
```

## Getting Help

- **Questions**: Open an issue with the "question" label
- **Bugs**: Use the bug report template
- **Features**: Use the feature request template
- **Email**: hi@stav.xyz

## License

By contributing to gitmux, you agree that your contributions will be licensed under the [Unlicense](LICENSE).
