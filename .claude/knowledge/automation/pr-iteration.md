# PR Iteration

## When to Use

**Responding to pull request review feedback.**

## Quick Reference

### Option 1: Claude Code Skill (Interactive)

```bash
# Invoke via Claude Code skill
/iterate-pr <pr-number>

# Examples
/iterate-pr 5
/iterate-pr 12
```

### Option 2: CLI Command (Deterministic)

```bash
# Two-phase execution with approval prompt
persuade iterate-pr <pr-number>

# Auto-approve for CI/CD (skips approval prompt)
persuade iterate-pr <pr-number> --auto-approve

# Examples
persuade iterate-pr 67
persuade iterate-pr 67 -y
```

**Requires:** `pip install persuade[agents]`

### Option 3: HTTP Server (Programmatic)

```bash
# Start server
persuade serve --port 8765

# Call via API
curl -X POST http://localhost:8765/agent/run \
  -H "Content-Type: application/json" \
  -d '{"agent_type": "iterate-pr", "params": {"pr_number": 67}}'
```

**Requires:** `pip install persuade[server]`

## Two-Phase Execution Pattern

All invocation methods use the same deterministic two-phase pattern:

1. **Plan Phase (Read-Only)**
   - Fetches PR feedback via workflow scripts
   - Reads state file for unaddressed items
   - Classifies items by priority (CRITICAL/HIGH/MEDIUM/LOW/NITPICK)
   - Presents plan for approval (or returns plan via API)

2. **Execute Phase (After Approval)**
   - Addresses feedback in priority order
   - Updates state file with addressed items
   - Commits and pushes changes

This ensures **deterministic behavior** - you always see what will happen before any changes are made.

## Why This Matters

- **Efficiency:** Automated review-fix-push loop
- **Consistency:** Follows organizational standards
- **Quality:** Addresses **ALL** feedback - critical, high, medium, low, AND nitpicks
- **CI/CD:** Fixes **ALL** GitHub Actions status check failures and warnings
- **Speed:** Faster than manual iteration
- **Comprehensive:** Reads check-run logs to find errors/warnings

## How It Works

1. **Check CI status FIRST:** Uses `gh pr checks` and check-runs API to detect failures
2. **Fetch PR details:** Uses `gh pr view` to get PR info
3. **Fetch bot reviews:** Explicitly checks BOTH `copilot-pull-request-reviewer[bot]` AND `claude[bot]`
4. **Fetch human reviews:** Uses `gh api` to get review feedback
5. **Analyze CI logs:** Reads full logs from failing checks for errors/warnings
6. **Analyze ALL feedback:** Categorizes by priority (CI > critical > high > medium > low > nitpicks)
7. **Make changes:** Fixes CI failures FIRST, then addresses reviews by priority
8. **Verify locally:** Runs pytest, ruff, mypy to ensure fixes work
9. **Push updates:** Commit and push to PR branch
10. **Check status again:** Verify all checks passing and no new reviews

## Patterns

### Pattern 1: Standard PR Iteration

```bash
# You receive review feedback on PR #5

# Run iteration command
/iterate-pr 5

# Claude will:
# 1. Read PR description and comments
# 2. Identify requested changes
# 3. Apply changes to code
# 4. Run tests
# 5. Commit with message referencing review
# 6. Push to PR branch
```

### Pattern 2: Multiple Review Rounds

```bash
# First review round
/iterate-pr 5
# Claude addresses initial feedback

# Reviewer adds more comments

# Second review round
/iterate-pr 5
# Claude addresses new feedback
```

### Pattern 3: Complex Feedback

```bash
# PR has multiple reviewers with different feedback

/iterate-pr 5

# Claude will:
# - Read all review comments
# - Prioritize feedback
# - Address all points systematically
# - Add comment to PR summarizing changes
```

## What Gets Addressed

### **CRITICAL: ALL Feedback Levels Are Addressed**

**Priority order:**
1. **Critical:** Security issues, bugs, breaking changes, test failures, build errors
2. **High:** Status check failures, design concerns, architecture issues
3. **Medium:** Code quality issues, performance concerns, warnings in logs
4. **Low:** Style preferences, minor improvements, linting warnings
5. **Nitpicks:** Formatting, typos, documentation improvements, whitespace

**NO feedback is too trivial to address. Every comment, every warning, every nitpick gets addressed.**

### **GitHub Actions Status Checks (REQUIRED)**

**ALL status checks MUST pass:**
- ✅ Reads full logs from `gh api .../check-runs`
- ✅ Fixes test failures (pytest, jest, etc.)
- ✅ Fixes linting errors (ruff, eslint, etc.)
- ✅ Fixes type checking errors (mypy, TypeScript)
- ✅ Fixes build failures (compilation errors)
- ✅ Fixes coverage drops below threshold
- ✅ Addresses security warnings
- ✅ Addresses deprecation warnings
- ✅ Addresses warnings even if check passed

**Status checks are analyzed BEFORE review comments and fixed FIRST.**

### **CI Status Checks Analysis Process**

**How CI checks are analyzed:**

1. **Get check status**: `gh pr checks <pr-number>`
2. **Fetch check-runs**: `gh api .../commits/<sha>/check-runs`
3. **Parse conclusions**: Look for `failure`, `cancelled`, `timed_out`
4. **Fetch logs**: Get full output from failing checks
5. **Parse errors**: Extract specific error messages/line numbers
6. **Detect warnings**: Even in passing checks, look for warning patterns

**CI check conclusions:**
- ✅ `success` - Check passed (but may have warnings)
- ❌ `failure` - Check failed (MUST fix before merge)
- ⏭️ `skipped` - Check was skipped (verify if intentional)
- ❌ `cancelled` - Check was cancelled (treat as failure)
- ❌ `timed_out` - Check timed out (treat as failure)
- ⏳ `in_progress` - Check still running (wait for completion)

**Warning patterns to detect:**
```bash
# pytest warnings
"PytestWarning:"
"DeprecationWarning:"
"PendingDeprecationWarning:"

# ruff warnings (non-blocking)
"warning:"

# mypy notes
"note:"

# Security warnings
"SecurityWarning:"
"InsecureRequestWarning:"
```

### **Human Review Feedback**

**ALL review comments addressed:**
- Code changes (refactoring, bug fixes)
- Style issues (formatting, naming)
- Documentation updates
- Test additions/modifications
- Architecture suggestions
- Security concerns
- Nitpicks and minor suggestions

### **⚠️ Bot Review Feedback (CRITICAL - CHECK BOTH)**

**IMPORTANT:** GitHub PRs may have reviews from TWO different bot reviewers:

1. **`copilot-pull-request-reviewer[bot]`:**
   - Code quality and best practices
   - Security vulnerabilities
   - Performance improvements
   - Style and formatting suggestions

2. **`claude[bot]`:**
   - Comprehensive architecture reviews
   - Testing requirements (often marks missing tests as CRITICAL/HIGH priority)
   - Design patterns and anti-patterns
   - Error handling and edge cases

**⚠️ MUST check for comments from BOTH bot users separately!** They are different reviewers and may provide different types of feedback.

**What it handles automatically:**
- Running code quality tools (ruff, mypy)
- Running tests (pytest)
- Formatting code (ruff format)
- Reading full error logs from CI/CD
- Verifying fixes locally before pushing
- Committing changes
- Pushing to PR branch

## AI Assistant Checklist

**When using /iterate-pr:**
- [ ] Check GitHub Actions status - use `gh pr checks`
- [ ] Read full logs for failing checks - use `gh api .../check-runs`
- [ ] Read all review comments carefully
- [ ] **⚠️ CRITICAL:** Check for reviews from BOTH bot users:
  - [ ] Check `copilot-pull-request-reviewer[bot]` comments
  - [ ] Check `claude[bot]` comments
- [ ] Address EVERY piece of feedback (including nitpicks)
- [ ] Fix status checks FIRST (priority 1)
- [ ] Then address critical/high/medium/low review feedback
- [ ] Then address nitpicks
- [ ] Run tests before pushing
- [ ] Use semantic commit message
- [ ] Reference PR number in commit
- [ ] Push to correct branch (not main!)

**Status check requirements:**
- [ ] ALL checks must pass (no failures)
- [ ] Address warnings even if check passed
- [ ] Read full error output from logs
- [ ] Fix root cause, not symptoms
- [ ] Verify locally: pytest, ruff, mypy

**In commit message:**
- [ ] Start with type: `fix:`, `refactor:`, etc.
- [ ] Reference status check fixes if any
- [ ] Reference review: "address PR review feedback"
- [ ] Include co-author attribution

**Before completing:**
- [ ] ALL status checks passing
- [ ] ALL review points addressed (including nitpicks)
- [ ] No warnings in CI logs
- [ ] Tests pass locally
- [ ] Code quality checks pass
- [ ] Changes pushed to PR branch

## Example Workflow

### Scenario: Status Checks + Review Feedback

**PR #8:** "Add user authentication"

**Status checks:**
- ❌ pytest: 2 tests failing (Critical)
- ❌ ruff: 5 linting errors (High)
- ⚠️ mypy: 1 type error (warning only) (Medium)

**Review comments:**
1. @alice: "Add input validation" (Critical)
2. copilot-pull-request-reviewer[bot]: "Extract password hashing to separate function" (Medium)
3. claude[bot]: "Consider edge case when password is None" (Medium)
4. claude[bot]: "Missing unit tests for authentication flow" (HIGH/Critical)
5. @bob: "Fix typo in docstring" (Nitpick)

**Running /iterate-pr 8:**

```
🔍 Fetching feedback for PR #8...
  - Reviews: 1
  - Review comments: 3
  - Issue comments: 1
  - copilot-pull-request-reviewer[bot] comments: 1
  - claude[bot] comments: 2
  - Status checks: 2 failing, 1 passing with warnings

📊 Analyzing ALL feedback...
  ✓ [Status Check] pytest: 2 tests failing - Critical
  ✓ [Status Check] ruff: 5 linting errors - High
  ✓ [Status Check] mypy: 1 type error (warning) - Medium
  ✓ @alice: "Add input validation" - Critical
  ✓ copilot-pull-request-reviewer[bot]: "Extract helper function" - Medium
  ✓ claude[bot]: "Handle None edge case" - Medium
  ✓ claude[bot]: "Missing unit tests" - Critical
  ✓ @bob: "Fix typo in docstring" - Nitpick

🔧 Making changes (priority order)...
  1. Fixed 2 failing tests in test_auth.py
  2. Fixed 5 ruff linting errors
  3. Fixed mypy type error
  4. Added input validation to login()
  5. Added unit tests for authentication flow
  6. Extracted hash_password() function
  7. Added None check for password parameter
  8. Fixed typo in docstring

✅ Verifying locally...
  ✓ pytest tests/ -v (all passed)
  ✓ ruff check . (no errors)
  ✓ mypy src/ (no errors)

📝 Committing changes:
git commit -m "fix: address status check failures and review feedback

Status Checks Fixed:
- Fixed 2 failing pytest tests
- Resolved 5 ruff linting errors
- Fixed mypy type error

Review Comments Addressed:
- Added input validation (Critical - @alice)
- Added unit tests for authentication flow (Critical - claude[bot])
- Extracted password hashing function (Medium - copilot-pull-request-reviewer[bot])
- Added None check for edge case (Medium - claude[bot])
- Fixed docstring typo (Nitpick - @bob)

All feedback levels addressed: critical, high, medium, low, and nitpicks.
Both copilot and claude bot reviews addressed.

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: stavxyz <hi@stav.xyz>"

📤 Pushing to PR:
git push origin feature/user-auth

✅ Checking status...
  Status checks: All passing ✅
  No new reviews

✅ PR #8 iteration complete!
```

## Commit Message Format

```bash
git commit -m "$(cat <<'EOF'
fix: address PR review feedback

- Specific change 1
- Specific change 2
- Specific change 3

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: stavxyz <hi@stav.xyz>
EOF
)"
```

## Common Feedback Types

### Type: Status Check Failures (Priority 1)

```
Status Check: "pytest: test_login FAILED"
Claude: Reads full log, identifies root cause, fixes test

Status Check: "ruff: F401 'os' imported but unused"
Claude: Removes unused import

Status Check: "mypy: error: Argument 1 has incompatible type"
Claude: Adds proper type hints to fix type error

Status Check: "coverage: Coverage dropped from 85% to 78%"
Claude: Adds tests to restore coverage threshold
```

### Type: Code Quality (Priority varies)

```
Reviewer: "Add type hints to this function" (High)
Claude: Adds proper type hints using typing module

Reviewer: "This function is too long, extract helper" (Medium)
Claude: Refactors into smaller functions

Reviewer: "Use list comprehension instead of loop" (Low)
Claude: Refactors to more Pythonic code

Reviewer: "Fix indentation here" (Nitpick)
Claude: Fixes whitespace
```

### Type: Testing

```
Reviewer: "Add test for edge case"
Claude: Writes new test function

Reviewer: "Mock this external API call"
Claude: Adds unittest.mock usage

Reviewer: "Coverage dropped, add tests"
Claude: Identifies uncovered lines, adds tests
```

### Type: Documentation

```
Reviewer: "Add docstring explaining parameters"
Claude: Adds comprehensive docstring

Reviewer: "Update README with new feature"
Claude: Updates documentation

Reviewer: "Add inline comment explaining algorithm"
Claude: Adds explanatory comments
```

### Type: Architecture

```
Reviewer: "Move this to separate module"
Claude: Refactors code structure

Reviewer: "Use Protocol instead of inheritance"
Claude: Refactors to use typing.Protocol

Reviewer: "Extract configuration to constants"
Claude: Creates constants file
```

## Integration with Tools

**Automatically runs:**

```bash
# Code formatting
ruff format .

# Linting
ruff check --fix .

# Type checking
mypy src/

# Tests
pytest tests/ -v

# Coverage
pytest tests/ --cov=src
```

**If tools fail:**
- Claude fixes issues automatically
- Runs tools again
- Only commits when all pass

## Best Practices

**For reviewers:**
- Be specific in feedback
- Reference line numbers
- Explain why change is needed
- Suggest specific solutions

**For AI assistant:**
- Read entire review thread
- Address all points before pushing
- Don't skip running tests
- Use descriptive commit messages
- Never push to main branch

## Gotchas

**"PR not found"**
- Check PR number is correct
- Verify PR exists: `gh pr view <number>`

**"Permission denied"**
- Ensure gh CLI authenticated
- Check repository access

**"Can't push to branch"**
- Branch may be protected
- Check you're not on main

**"Review comments not loading"**
- GitHub API rate limit
- Wait and retry

**"Changes already addressed"**
- Review was outdated
- Confirm with reviewer

## Manual Override

**If automation doesn't work:**

```bash
# 1. Manually fetch PR
gh pr view 5

# 2. Read review comments
gh api repos/owner/repo/pulls/5/comments

# 3. Make changes manually

# 4. Push to PR branch
git checkout feature/branch
git add .
git commit -m "fix: address review feedback"
git push origin feature/branch
```

## Success Criteria

**Iteration is successful when:**
- [ ] **ALL** status checks passing (no failures)
- [ ] **ALL** warnings in CI logs addressed (even if check passed)
- [ ] **ALL** review feedback addressed (critical, high, medium, low, AND nitpicks)
- [ ] Tests pass locally
- [ ] Code quality checks pass locally
- [ ] Changes pushed to PR branch
- [ ] Commit message references status checks and review
- [ ] Co-authors attributed

**Incomplete iteration if:**
- [ ] Any status check failing
- [ ] Any review comment unaddressed (even nitpicks)
- [ ] Warnings in CI logs (even if check passed)
- [ ] Tests don't pass locally

**Ready for re-review when:**
- [ ] All requested changes made
- [ ] No test failures (local or CI)
- [ ] No linting errors (local or CI)
- [ ] No type errors (local or CI)
- [ ] No warnings in logs
- [ ] Documentation updated
- [ ] All nitpicks addressed
- [ ] PR marked ready for review

## Related

- **Sync Tool Usage:** [automation/sync-tool-usage.md](sync-tool-usage.md)
- **Pull Request Workflow:** [git/pull-request-workflow.md](../git/pull-request-workflow.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** `/iterate-pr <number>` automates review-fix-push loop. Addresses **ALL** feedback systematically: status check failures, status check warnings, human review feedback at **ALL** priority levels (critical, high, medium, low, AND nitpicks). Nothing is too small to fix.
