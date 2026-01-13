# Atomic Commits

## When to Use

**EVERY commit. This is the foundation of good git hygiene.**

## What is an Atomic Commit?

An atomic commit represents a **single logical change** that is:
- **Complete**: The change works on its own
- **Focused**: Does ONE thing, not multiple things
- **Reversible**: Can be reverted without side effects
- **Testable**: Tests pass after this commit

## Quick Reference

```bash
# The "AND" Test
# If your commit message uses "and", split it into multiple commits

# BAD: Multiple changes in one commit
git commit -m "feat: add login form and fix validation and update styles"

# GOOD: One logical change per commit
git commit -m "feat: add login form component"
git commit -m "fix: resolve email validation error"
git commit -m "style: update form input styling"
```

## Why Atomic Commits Matter

| Benefit | Description |
|---------|-------------|
| **Code Review** | Reviewers see logical progression of changes |
| **git bisect** | Find exactly which commit introduced a bug |
| **git revert** | Undo specific changes without collateral damage |
| **git blame** | Understand why each line was changed |
| **Merge Conflicts** | Smaller commits = simpler conflicts |
| **Cherry-picking** | Extract specific changes for other branches |

## Patterns

### Pattern 1: When to Commit

Commit after completing each of these (separately):

```bash
# 1. Adding new functionality
git commit -m "feat: add calculateTotal function to billing"

# 2. Writing tests for that functionality
git commit -m "test: add unit tests for calculateTotal"

# 3. Fixing a bug you discovered
git commit -m "fix: handle null values in calculateTotal"

# 4. Refactoring for clarity
git commit -m "refactor: extract tax calculation to separate function"

# 5. Updating documentation
git commit -m "docs: add JSDoc comments to billing module"

# 6. Formatting/linting changes
git commit -m "style: format billing module with prettier"
```

### Pattern 2: Feature Development Sequence

**Example: Adding user authentication**

```bash
# Step 1: Add data model (minimal, just structure)
git commit -m "feat: add User model with authentication fields"

# Step 2: Implement core logic
git commit -m "feat: implement password hashing utility"

# Step 3: Add the main feature
git commit -m "feat: add login endpoint"

# Step 4: Add supporting feature
git commit -m "feat: add logout endpoint"

# Step 5: Add tests (can be after or with each feature)
git commit -m "test: add integration tests for auth endpoints"

# Step 6: Handle edge cases
git commit -m "fix: handle expired session tokens"

# Step 7: Documentation
git commit -m "docs: add authentication section to API docs"
```

### Pattern 3: Bug Fix Sequence

**Example: Fixing a race condition**

```bash
# Step 1: Add failing test that exposes the bug
git commit -m "test: add test exposing cache race condition"

# Step 2: Fix the bug
git commit -m "fix: resolve race condition in cache invalidation"

# Step 3: Add additional test coverage (optional)
git commit -m "test: add edge case tests for cache operations"
```

### Pattern 4: Refactoring Sequence

**Example: Extracting a service class**

```bash
# Step 1: Create the new structure (empty or minimal)
git commit -m "refactor: create PaymentService class skeleton"

# Step 2: Move existing logic
git commit -m "refactor: move payment logic to PaymentService"

# Step 3: Update callers
git commit -m "refactor: update controllers to use PaymentService"

# Step 4: Clean up old code
git commit -m "chore: remove deprecated payment helpers"

# Step 5: Update tests
git commit -m "test: update tests for PaymentService refactor"
```

## AI Assistant Checklist

**Before EVERY commit, verify:**

- [ ] **Single Purpose**: Does this commit do exactly ONE thing?
- [ ] **"AND" Test**: Does the message avoid "and"? (If not, split it)
- [ ] **Complete**: Does the code work after this commit?
- [ ] **Tests Pass**: `pytest tests/ -v` succeeds?
- [ ] **Meaningful**: Would someone understand this change from the message?
- [ ] **Right Size**: Is this the smallest complete unit of work?

**When working on a feature:**

- [ ] Break down into logical steps BEFORE coding
- [ ] Commit after each logical step completes
- [ ] Keep formatting/style changes separate
- [ ] Keep refactoring separate from new features
- [ ] Tests can be with feature OR separate commit

## Anti-Patterns to Avoid

### Anti-Pattern 1: The "Kitchen Sink" Commit

```bash
# BAD: Everything in one commit
git commit -m "feat: add user dashboard with charts, fix login bug, update deps"

# GOOD: Separate commits
git commit -m "fix: resolve login redirect loop"
git commit -m "chore: update chart.js to v4.0"
git commit -m "feat: add user dashboard page"
git commit -m "feat: add usage chart to dashboard"
```

### Anti-Pattern 2: The "WIP" Commit

```bash
# BAD: Work in progress commits
git commit -m "WIP"
git commit -m "more changes"
git commit -m "fix stuff"

# GOOD: Wait until logical unit is complete, then commit with clear message
git commit -m "feat: add email validation to signup form"
```

### Anti-Pattern 3: The "Mixed Concerns" Commit

```bash
# BAD: Bug fix mixed with refactor
git commit -m "fix: resolve null pointer and refactor error handling"

# GOOD: Separate concerns
git commit -m "fix: handle null user in profile endpoint"
git commit -m "refactor: centralize error handling in middleware"
```

### Anti-Pattern 4: The "Formatting + Logic" Commit

```bash
# BAD: Formatting changes hide logic changes
git commit -m "feat: add search, also ran prettier"

# GOOD: Formatting in separate commit
git commit -m "style: run prettier on search module"
git commit -m "feat: add full-text search to products"
```

## Commit Granularity Guide

| Change Type | Commit Strategy |
|-------------|-----------------|
| **New function/method** | One commit per function (if self-contained) |
| **New class/module** | May span 2-3 commits: structure, core logic, integration |
| **Bug fix** | Usually 1-2 commits: test + fix |
| **Refactoring** | Multiple commits: create new → migrate → cleanup |
| **Dependencies** | One commit per dependency update |
| **Configuration** | One commit per config change |
| **Documentation** | Can group related doc updates in one commit |
| **Formatting/linting** | Always separate from logic changes |

## Commit Size Guidelines

**Ideal commit characteristics:**
- Changes 1-3 files (for most commits)
- Under 100 lines changed (excluding generated files)
- Focused on a single concern
- Self-documenting through message and diff

**Warning signs of too-large commits:**
- Diff spans many unrelated files
- Hundreds of lines changed
- Message requires "and" or bullet points
- Mix of feature + fix + refactor

## Common Workflows

### Workflow 1: You Realize You Need to Split

```bash
# You've made multiple changes but haven't committed yet

# Option A: Stage files selectively
git add src/auth.py
git commit -m "feat: add authentication middleware"
git add src/routes.py
git commit -m "feat: add protected route decorator"

# Option B: Stage hunks within a file
git add -p src/mixed-changes.py
# Select only the hunks for one logical change
git commit -m "fix: handle session expiration"
# Add remaining hunks
git add src/mixed-changes.py
git commit -m "feat: add remember-me functionality"
```

### Workflow 2: Planning Commits Before Coding

```bash
# Before starting work, plan your commit sequence:

# 1. "I'll need to add a new model" → commit 1
# 2. "Then add the service layer" → commit 2
# 3. "Then the API endpoint" → commit 3
# 4. "Then tests" → commit 4
# 5. "Then docs" → commit 5

# Code each step, commit, then move to next
```

### Workflow 3: Discovering Additional Work Mid-Feature

```bash
# You're adding a feature and discover a bug

# Option A: Stash current work, fix bug first
git stash
git commit -m "fix: resolve discovered null pointer bug"
git stash pop
# Continue feature work

# Option B: Note it, finish current unit, then fix
# Complete current atomic unit
git commit -m "feat: add product search"
# Now fix the bug
git commit -m "fix: handle empty search query"
```

## Gotchas

**"But my feature is complex!"**
- Complex features = more commits, not bigger commits
- Each step of a complex feature should be atomic

**"But these changes are related!"**
- Related ≠ same commit
- Related changes get related commit messages, but separate commits

**"But I'll have too many commits!"**
- Many small commits > few large commits
- Squash on merge if needed (PR level decision)

**"But I found a bug while working!"**
- Fix in separate commit OR stash work → fix → stash pop
- Never bury bug fixes inside feature commits

## Related

- **Commit Messages:** [git/commit-messages.md](commit-messages.md)
- **Pull Request Workflow:** [git/pull-request-workflow.md](pull-request-workflow.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** If you can use "and" in your commit message, it should probably be multiple commits. Each commit should be ONE logical change that leaves the codebase in a working state.
