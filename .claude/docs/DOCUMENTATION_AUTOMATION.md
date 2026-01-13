# Documentation Automation Integration Guide

This guide explains how to integrate the documentation checker script into various automation workflows.

## Quick Start

**Want to get started immediately? Choose your path:**

```bash
# 1. Try it now (manual check)
./.claude/scripts/check-docs-updated.sh main

# 2. Add as pre-commit hook (local, informational)
ln -sf ../../.claude/scripts/pre-commit-docs-check .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# 3. Add to GitHub Actions (see "GitHub Actions Integration" below)
```

### Should I Make This Blocking?

Use this decision tree to determine the right enforcement level:

```
START: Do you want to enforce documentation updates?
│
├─ NO → Use informational mode (default)
│   ├─ Provides warnings without blocking
│   ├─ Good for: new projects, legacy codebases, gradual adoption
│   └─ Script exits with 0 (always passes)
│
└─ YES → Consider these factors:
    │
    ├─ Is this a NEW project or greenfield code?
    │   └─ YES → ✅ Safe to make blocking
    │       └─ Implementation: Modify script to exit 1 on warnings
    │
    ├─ Is this LEGACY code with poor documentation?
    │   └─ YES → ⚠️  Start informational, make blocking after 2-4 weeks
    │       └─ Implementation: Gradual rollout (see Best Practices)
    │
    ├─ Is this CRITICAL infrastructure code?
    │   └─ YES → ✅ Strongly consider blocking
    │       └─ Implementation: Blocking mode + manual review
    │
    └─ Is your TEAM on board with strict enforcement?
        ├─ YES → ✅ Safe to make blocking
        └─ NO → ⚠️  Start informational, educate, then enforce
```

**Recommendation:** Start with informational mode for 2-4 weeks to establish baseline, then make blocking if appropriate.

## Overview

The `check-docs-updated.sh` script verifies that code changes include corresponding documentation updates. It can be integrated into:

1. **GitHub Actions CI/CD** - Automated checks on pull requests
2. **Pre-commit hooks** - Local validation before commits
3. **Manual workflows** - On-demand verification

## GitHub Actions Integration

### Ready-to-Use Workflow

**🚀 Quick Start:** A complete, production-ready workflow is available at:
`.claude/docs/examples/documentation-check-workflow.yml`

To use it:
```bash
# Copy the example workflow to your .github/workflows directory
cp .claude/docs/examples/documentation-check-workflow.yml .github/workflows/documentation-check.yml

# Commit and push
git add .github/workflows/documentation-check.yml
git commit -m "ci: add documentation enforcement workflow"
git push
```

The workflow includes:
- ✅ Python AST-based docstring detection
- ✅ Informational mode by default (non-blocking)
- ✅ Optional PR comment posting
- ✅ Easy configuration for blocking mode
- ✅ Full documentation with inline comments

### Example Workflow (Alternative)

If you prefer to create your own, here's a minimal example for `.github/workflows/docs-check.yml`:

```yaml
name: Documentation Check

on:
  pull_request:
    branches: [ main, master ]
  push:
    branches: [ main, master ]

jobs:
  check-documentation:
    name: Verify Documentation Updates
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for accurate diff

      - name: Check documentation updates
        run: |
          # Make script executable
          chmod +x .claude/scripts/check-docs-updated.sh

          # Run the checker against the base branch
          if [ "${{ github.event_name }}" == "pull_request" ]; then
            BASE_BRANCH="${{ github.base_ref }}"
          else
            BASE_BRANCH="origin/main"
          fi

          echo "Checking documentation against: $BASE_BRANCH"
          ./.claude/scripts/check-docs-updated.sh "$BASE_BRANCH"

      - name: Comment on PR (if warnings found)
        if: failure() && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ **Documentation Check**: Code changes detected without corresponding documentation updates. Please review the [documentation requirements](.claude/docs/ENGINEERING_STANDARDS.md#documentation-requirements).'
            })
```

### Integration with Existing Quality Checks

Add to an existing workflow (e.g., `python-quality.yml`):

```yaml
  docs-check:
    name: Documentation Updates
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check docs updated
        run: |
          chmod +x .claude/scripts/check-docs-updated.sh
          ./.claude/scripts/check-docs-updated.sh origin/${{ github.base_ref }}
```

### Expected Output Examples

#### ✅ Success: Documentation Updated

```
=== Documentation Update Checker ===

Checking documentation updates against: main

Changed files:
  - src/auth/login.py
  - src/auth/utils.py
  - README.md
  - docs/api/authentication.md

Analysis:
  Code files changed: 2
  Documentation files changed: 2
  Test files changed: 0

✓ Documentation files were updated alongside code changes

Checking Python files for docstrings...
✓ All Python files with functions/classes have docstrings

Summary:
✓ Code changes include corresponding documentation updates
✓ All checks passed
```

#### ⚠️  Warning: Missing Documentation

```
=== Documentation Update Checker ===

Checking documentation updates against: main

Changed files:
  - src/auth/login.py
  - src/auth/utils.py
  - tests/test_auth.py

Analysis:
  Code files changed: 2
  Documentation files changed: 0
  Test files changed: 1

WARNING: Code changes detected without documentation updates

Please update at least one of:
  - README.md (for user-facing changes)
  - docs/ (for API or architecture changes)
  - Inline docstrings (for new functions/classes)

Checking Python files for docstrings...

⚠ File may be missing docstrings: src/auth/login.py
  Found function/class definitions but could not verify docstrings
  Please ensure all public functions and classes have docstrings

Summary:
⚠ Warning: Code changes without documentation
⚠ Possible missing docstrings in Python files
```

#### ℹ️ Info: Test-Only Changes

```
=== Documentation Update Checker ===

Checking documentation updates against: main

Changed files:
  - tests/test_auth.py
  - tests/fixtures/auth_data.json

Analysis:
  Code files changed: 0
  Documentation files changed: 0
  Test files changed: 2

ℹ Only test files changed - no documentation update needed

Summary:
✓ No documentation updates required
```

### Informational vs. Blocking

The script exits with code 0 (success) even when warnings are found, making it **informational by default**. To make it **blocking**:

**Option 1: Modify script exit code**

```bash
# At the end of check-docs-updated.sh, change:
# exit 0  # Informational
exit $warnings  # Blocking if warnings > 0
```

**Option 2: Parse output in CI**

```yaml
- name: Check documentation (blocking)
  run: |
    output=$(./.claude/scripts/check-docs-updated.sh main 2>&1)
    echo "$output"
    if echo "$output" | grep -q "WARNING"; then
      echo "::error::Documentation updates required"
      exit 1
    fi
```

## Pre-commit Hook Integration

### Manual Installation

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Pre-commit hook: Check documentation updates

# Run the documentation checker
if [ -f .claude/scripts/check-docs-updated.sh ]; then
    echo "Checking documentation updates..."
    ./.claude/scripts/check-docs-updated.sh main

    # Note: Script exits 0 even with warnings (informational)
    # Uncomment below to make it blocking:
    # if [ $? -ne 0 ]; then
    #     echo "Documentation check failed. Commit aborted."
    #     exit 1
    # fi
fi

exit 0
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

### Using pre-commit Framework

If using [pre-commit](https://pre-commit.com/), add to `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: check-docs-updated
        name: Check documentation updates
        entry: .claude/scripts/check-docs-updated.sh
        args: ['main']
        language: script
        pass_filenames: false
        always_run: true
        stages: [commit]
```

Install the hook:

```bash
pre-commit install
```

### Symlink Approach

Create a symlink for easy setup:

```bash
# From project root
ln -sf ../../.claude/scripts/check-docs-updated.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Manual Workflow Integration

### In iterate-pr Command

Already integrated! The `iterate-pr` command includes documentation verification:

```bash
# Run iterate-pr (includes doc check)
./.claude/commands/iterate-pr.md
```

### Standalone Usage

```bash
# Check against main branch
./.claude/scripts/check-docs-updated.sh main

# Check against specific branch
./.claude/scripts/check-docs-updated.sh origin/develop

# Check against specific commit
./.claude/scripts/check-docs-updated.sh HEAD~3
```

## Advanced Integration

### Custom Branch Comparison

```bash
# Compare feature branch against develop
git checkout feature/my-feature
./.claude/scripts/check-docs-updated.sh origin/develop
```

### CI Matrix Strategy

Check documentation across multiple scenarios:

```yaml
jobs:
  docs-check:
    strategy:
      matrix:
        base: [main, develop, release/*]
    steps:
      - name: Check docs vs ${{ matrix.base }}
        run: ./.claude/scripts/check-docs-updated.sh ${{ matrix.base }}
```

### Slack/Email Notifications

Combine with notification actions:

```yaml
- name: Notify about missing docs
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "PR #${{ github.event.number }} has code changes without documentation updates"
      }
```

## Configuration Options

### Environment Variables

The script supports customization via environment variables:

```bash
# Disable color output (for CI logs)
export NO_COLOR=1
./.claude/scripts/check-docs-updated.sh main

# Custom base branch
export DOCS_CHECK_BASE_BRANCH=develop
./.claude/scripts/check-docs-updated.sh
```

### Extending File Detection

Modify the script's file categorization:

```bash
# In check-docs-updated.sh, line ~59
CODE_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(py|js|ts|tsx|jsx|go|java|rb|php|rs|cpp|h|c)$' || true)

# Add more doc extensions
DOC_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(md|rst|txt|adoc|pdf)$|^docs/' || true)
```

## Troubleshooting

### Common Issues

**Issue**: "Not in a git repository"
```bash
# Solution: Run from project root
cd /path/to/project
./.claude/scripts/check-docs-updated.sh main
```

**Issue**: "No changed files detected"
```bash
# Causes:
# 1. On main branch (use feature branch)
# 2. No uncommitted changes
# 3. All changes committed and pushed

# Solution: Create feature branch
git checkout -b feature/my-changes
```

**Issue**: False positive for docstrings
```bash
# The grep-based detection has limitations
# For perfect detection, consider Python AST parsing:

python3 << 'EOF'
import ast
import sys

with open(sys.argv[1]) as f:
    tree = ast.parse(f.read())

for node in ast.walk(tree):
    if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
        if not ast.get_docstring(node):
            print(f"Missing docstring: {node.name}")
            sys.exit(1)
EOF
```

### Debug Mode

Add debug output to the script:

```bash
# Enable bash debugging
bash -x ./.claude/scripts/check-docs-updated.sh main

# Or modify script header
set -euxo pipefail  # Add 'x' for trace mode
```

## Best Practices

### Informational First

Start with informational checks (exit 0) to avoid blocking legitimate PRs:

1. **Week 1-2**: Informational only, gather metrics
2. **Week 3-4**: Alert but don't block, educate team
3. **Week 5+**: Consider making blocking for critical paths

### Gradual Rollout

1. Enable on new code only (not legacy)
2. Start with Python files (easiest to check)
3. Expand to other languages
4. Add external doc checks last

### Metrics Tracking

Track documentation compliance over time:

```bash
# Count warnings per week
git log --since="1 week ago" --format="%H" | while read commit; do
    git checkout $commit
    ./.claude/scripts/check-docs-updated.sh main 2>&1 | grep -c "WARNING" || echo 0
done | awk '{sum+=$1} END {print "Avg warnings:", sum/NR}'
```

### Team Communication

1. **Document in CONTRIBUTING.md** - Set expectations
2. **PR template** - Include documentation checklist
3. **Review guidelines** - Reviewers check for docs
4. **Examples** - Show good vs. bad PRs

## Related Documentation

- **Script source**: `.claude/scripts/check-docs-updated.sh`
- **Engineering standards**: `.claude/docs/ENGINEERING_STANDARDS.md#documentation-requirements`
- **Rule #11**: `.claude/docs/CLAUDE_CODE_RULES.md#11-documentation-updates`
- **Knowledge base**: `.claude/knowledge/documentation/keeping-docs-updated.md`
- **Playbook**: `playbooks/updating-documentation.md`

---

**Note**: This automation complements, but doesn't replace, manual code review. Reviewers should still verify documentation quality, not just presence.
