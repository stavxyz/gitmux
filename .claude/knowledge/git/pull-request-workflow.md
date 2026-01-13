# Pull Request Workflow

## When to Use

**EVERY CODE CHANGE. No exceptions.**

## Quick Reference

```bash
# Create feature branch
git checkout -b feature/my-change

# Make changes, run tests
pytest tests/ -v

# Commit and push
git add .
git commit -m "feat: description"
git push -u origin feature/my-change

# Create PR
gh pr create --title "Title" --body "Description"
```

## Why This Matters

- **Code Review:** Catch bugs before they reach main
- **CI/CD:** Tests run automatically on PRs
- **History:** Clear audit trail of all changes
- **Collaboration:** Team can review and discuss
- **Safety:** Prevents direct pushes to main

## Patterns

### Pattern 1: Standard Feature Branch

```bash
# Start from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/add-user-auth

# Work, commit, push
git add .
git commit -m "feat: add user authentication"
git push -u origin feature/add-user-auth

# Create PR
gh pr create
```

### Pattern 2: Bug Fix Branch

```bash
# Create fix branch
git checkout -b fix/login-error

# Fix bug, test
git add .
git commit -m "fix: resolve login redirect issue"
git push -u origin fix/login-error

# Create PR
gh pr create
```

### Pattern 3: If Accidentally on Main

```bash
# Check current branch
git branch --show-current
# Output: main  ⚠️ Problem!

# Create feature branch with changes
git checkout -b feature/my-fix

# Push feature branch
git push -u origin feature/my-fix

# Create PR
gh pr create
```

## AI Assistant Checklist

**Before ANY push:**
- [ ] Run `git branch --show-current`
- [ ] Verify NOT on main/master
- [ ] If on main: Create feature branch immediately
- [ ] Run tests: `pytest tests/ -v`
- [ ] If tests pass: Proceed with push
- [ ] Create PR, never merge directly

**Branch naming:**
- [ ] Start with: `feature/`, `fix/`, `docs/`, `refactor/`
- [ ] Use kebab-case: `feature/add-user-auth`
- [ ] Be descriptive: `fix/login-redirect-error`

## Prohibited Commands

```bash
# ❌ NEVER do this
git push origin main
git push origin master
git commit -m "changes" && git push  # If on main
```

## Recovery Steps

**If you pushed to main:**

```bash
# 1. Revert the commit
git revert HEAD --no-edit
git push origin main

# 2. Create feature branch with changes
git checkout -b feature/my-change
git cherry-pick <commit-hash>
git push -u origin feature/my-change

# 3. Create PR
gh pr create
```

## PR Creation

```bash
# Interactive (asks for title/body)
gh pr create

# With all details
gh pr create --title "Add user authentication" --body "Implements login, signup, and password reset"

# With template
gh pr create --body "$(cat .github/pull_request_template.md)"
```

## PR Management

```bash
# List PRs
gh pr list

# View PR details
gh pr view 123

# Check PR status
gh pr checks

# Review PR locally
gh pr checkout 123
pytest tests/ -v

# Merge PR (after approval)
gh pr merge 123
```

## Common Workflows

### Workflow 1: Single Commit PR

```bash
git checkout -b feature/update-readme
# Edit README.md
git add README.md
git commit -m "docs: update installation instructions"
git push -u origin feature/update-readme
gh pr create
```

### Workflow 2: Multi-Commit PR

```bash
git checkout -b feature/user-dashboard
# Multiple commits
git commit -m "feat: add dashboard route"
git commit -m "feat: add dashboard view"
git commit -m "test: add dashboard tests"
git push -u origin feature/user-dashboard
gh pr create
```

### Workflow 3: Responding to Review

```bash
# Already on feature branch
git checkout feature/user-auth

# Make requested changes
git add .
git commit -m "fix: address PR review feedback"
git push origin feature/user-auth

# PR automatically updates
```

## Gotchas

**"Permission denied: protected branch"**
- Good! Branch protection is working
- Create feature branch instead

**"Already on branch main"**
- Don't commit here
- Create feature branch: `git checkout -b feature/name`

**"No upstream branch"**
- First push needs: `git push -u origin branch-name`
- Subsequent pushes: `git push`

**"PR conflicts with main"**
```bash
# Update feature branch from main
git checkout feature/my-branch
git fetch origin
git merge origin/main
# Resolve conflicts
git push origin feature/my-branch
```

## Related

- **Commit Messages:** [git/commit-messages.md](commit-messages.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** NEVER push to main. ALWAYS use feature branches and PRs. No exceptions.
