# AI Assistant Instructions

## Before You Begin

**Read these files IN ORDER before performing any operations:**

1. **`.claude/docs/CLAUDE_CODE_RULES.md`** - Non-negotiable requirements
2. **`.claude/docs/ENGINEERING_STANDARDS.md`** - Coding standards and best practices
3. **`.claude/knowledge/README.md`** - Knowledge base index

## Critical Rules

### NEVER Push to Main Branch

- ALWAYS create feature branch: `git checkout -b feature/name`
- ALWAYS use pull requests
- Check current branch before pushing: `git branch --show-current`

### NEVER Modify System Python

- ALWAYS use virtual environments: `python3 -m venv .venv && source .venv/bin/activate`
- Check venv active: `which python` (must show `.venv/bin/python`)
- NEVER use: `pip install` without venv, `--user` flag, `sudo pip`

### ALWAYS Run Full Test Suite

- Before every commit: `pytest tests/ -v` (FULL suite, not subsets)
- Verify coverage meets threshold (check actual percentage in output, not just exit code)
- Run ALL quality checks: `ruff check . && ruff format . && mypy src/`
- Fix failing tests immediately
- Don't commit if tests fail
- NEVER claim "tests pass" or "PR ready" based on partial test runs

### ALWAYS Verify Branch

- Check branch: `git branch --show-current`
- If on main: Create feature branch immediately

## Quick Reference

### PR Workflow
See: `.claude/knowledge/git/pull-request-workflow.md`

```bash
git checkout -b feature/my-feature
# Make changes (commit after EACH logical unit)
pytest tests/ -v
git add .
git commit -m "feat: description"  # ONE change per commit!
git push -u origin feature/my-feature
gh pr create
```

### Atomic Commits
See: `.claude/knowledge/git/atomic-commits.md`

```bash
# The "AND" Test: If message uses "and", split into multiple commits
# BAD: git commit -m "feat: add form and fix validation"
# GOOD:
git commit -m "feat: add login form"
git commit -m "fix: resolve validation error"
```

### Python Setup
See: `.claude/knowledge/python/virtual-environments.md`

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
lefthook install  # Install git hooks
```

Or use `just setup` to do all of the above in one command.

### Testing
See: `.claude/knowledge/testing/pytest-basics.md`

```bash
pytest tests/ -v
pytest tests/ --cov=src
pytest -m "not e2e"  # Skip slow tests
```

### Code Quality
See: `.claude/knowledge/automation/pr-iteration.md`

```bash
just check  # Run all checks (lint, format, typecheck, test)
# Or manually:
ruff check --fix .
ruff format .
mypy src/
pytest tests/
```

### Model Configuration
See: `.claude/knowledge/claude-code/model-configuration.md`

**Default**: OpusPlan (Opus planning + Sonnet execution)

**Override options**:
- Session: `/model sonnet` (temporary)
- Environment: `export ANTHROPIC_MODEL="sonnet"` in `.envrc` (persistent)
- Team settings: Edit `.claude/settings.json` (affects all sessions)

## Pre-Operation Checklist

**Before ANY operation, verify:**

- [ ] Read project `.claude/CLAUDE.md` (this file)
- [ ] Check venv active: `which python` → `.venv/bin/python`
- [ ] Check branch: `git branch --show-current` → NOT main
- [ ] Read files before editing (use Read tool)
- [ ] Plan atomic commits (one logical change per commit)

## Documentation

- **Standards (AI-optimized)**: `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules**: `.claude/docs/CLAUDE_CODE_RULES.md`
- **Knowledge Base**: `.claude/knowledge/` (tactical tips and patterns)
- **Full Standards (Human)**: `/docs/ENGINEERING_STANDARDS.md` (comprehensive version)

## Project-Specific Rules

*This file may be customized per project. Check if project has additional rules below this line.*

---
