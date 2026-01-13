# Branch Creation Rules

Ensure feature branches are always created from the correct base branch.

## Core Rule

**ALWAYS create feature branches from `main`**, never from other feature branches.

---

## Pre-Branch Checklist

Before running `git checkout -b feature/...`, verify:

```
□ On main branch: `git branch --show-current` → main
□ Main is up to date: `git pull origin main`
□ No uncommitted changes: `git status` is clean
```

---

## Correct Process

```bash
# Step 1: Switch to main
git checkout main

# Step 2: Pull latest changes
git pull origin main

# Step 3: Verify you're on main
git branch --show-current  # Must output: main

# Step 4: Create feature branch
git checkout -b feature/my-feature
```

---

## Common Mistakes

### Mistake 1: Branching from another feature branch

**Wrong**:
```bash
# Currently on: feature/issue-38-fix
git checkout -b feature/issue-61-new-feature
# Result: New branch contains all commits from issue-38
```

**Right**:
```bash
git checkout main
git pull origin main
git checkout -b feature/issue-61-new-feature
# Result: Clean branch with only main's commits
```

### Mistake 2: Forgetting to pull latest main

**Wrong**:
```bash
git checkout main
git checkout -b feature/my-feature
# Result: Branch is behind origin/main
```

**Right**:
```bash
git checkout main
git pull origin main  # Don't skip this!
git checkout -b feature/my-feature
```

### Mistake 3: Not checking current branch

**Wrong**:
```bash
# Assume you're on main (but you're actually on another branch)
git checkout -b feature/my-feature
```

**Right**:
```bash
git branch --show-current  # Verify first!
# If not main, switch to main first
```

---

## Why This Matters

1. **Clean PRs**: PRs should only contain changes for that feature
2. **Easier reviews**: Reviewers see only relevant changes
3. **Avoid conflicts**: Less merge conflict risk
4. **Clear history**: Git log shows accurate feature history

---

## Recovery: If You Branched Wrong

If you already created a branch from the wrong base:

```bash
# Save your commit hash
COMMIT_HASH=$(git rev-parse HEAD)

# Checkout main and pull
git checkout main
git pull origin main

# Create fresh branch
git checkout -b feature/my-feature-fixed

# Cherry-pick only your commits
git cherry-pick $COMMIT_HASH

# Delete the bad branch
git branch -D feature/my-feature

# Rename the fixed branch
git branch -m feature/my-feature-fixed feature/my-feature

# Force push if already pushed
git push origin feature/my-feature --force
```

---

## Verification Output

Before creating a branch, output:

```
CURRENT_BRANCH: [branch name]
ON_MAIN: [true/false]
MAIN_UP_TO_DATE: [true/false]
WORKING_TREE_CLEAN: [true/false]
READY_TO_BRANCH: [true/false]
```

Only proceed if `READY_TO_BRANCH: true`.

---

## Integration with PR Iteration

When starting work on a new issue during `/iterate-pr`:

1. **If PR is merged**: Safe to stay on current branch for related work
2. **If starting new unrelated work**: MUST checkout main first
3. **If unsure**: Always checkout main - it's the safe default
