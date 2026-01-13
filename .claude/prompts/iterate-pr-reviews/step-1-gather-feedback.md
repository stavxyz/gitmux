# Step 1: Gather Feedback

> **Note**: The bash snippets below are **examples/templates**. Variables like `{PR_NUMBER}`, `{owner}`, `{repo}`, and `$LAST_CHECK` should be substituted with actual values. In practice, use `.claude/scripts/iterate-pr-workflow.sh` which handles this automatically.

## Fetch Latest Reviews and Status Checks

**CRITICAL ORDER:**
1. **CI Status FIRST** - Check GitHub Actions before reviews
2. **Bot Reviews SECOND** - Check both copilot and claude bots explicitly
3. **Human Reviews THIRD** - Check human reviewer feedback

Gather all review feedback and CI status from multiple sources:

```bash
# ============================================================================
# STEP 1: CI/CD Status (CHECK FIRST - HIGHEST PRIORITY)
# ============================================================================

# Get check status summary
gh pr checks {PR_NUMBER}

# Get detailed check-run information including logs
gh api repos/{owner}/{repo}/commits/$(gh pr view {PR_NUMBER} --json headRefOid -q .headRefOid)/check-runs

# ============================================================================
# STEP 2: Bot Reviews (CHECK BOTH BOTS EXPLICITLY)
# ============================================================================

# ⚠️ CRITICAL: Check BOTH bot reviewers
# Fetch bot comments with timestamp filtering

# Get copilot bot comments created after LAST_CHECK
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
    --jq '[.[] | select(.user.login == "copilot-pull-request-reviewer[bot]") | select(.created_at > "$LAST_CHECK")]'

# Get claude bot comments created after LAST_CHECK
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
    --jq '[.[] | select(.user.login == "claude[bot]") | select(.created_at > "$LAST_CHECK")]'

# ============================================================================
# STEP 3: Human Reviews
# ============================================================================

# Get PR reviews (APPROVED, CHANGES_REQUESTED, COMMENTED)
gh pr view {PR_NUMBER} --json reviews -q '.reviews'

# Get review comments (line-specific code comments)
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments

# Get issue comments (general PR discussion)
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments
```

---

## Step 2: Analyze All Feedback

**CRITICAL ORDER OF ANALYSIS:**
1. **CI failures** - MUST be fixed first, blocks merge
2. **Critical human reviews** - Security, bugs, breaking changes
3. **CI warnings** - Even if checks passed, address warnings
4. **High/medium reviews** - Architecture, testing, design
5. **Low/nitpick reviews** - Style, formatting, documentation

**CRITICAL:** Address ALL feedback, including nitpicks. No feedback is too trivial.

### Bot Reviews Are Always Actionable

- Bot reviews from `copilot-pull-request-reviewer[bot]` and `claude[bot]` contain specific, addressable feedback
- NEVER dismiss these as "just summaries", "review summaries", or "not actionable"
- Bot reviews typically include:
  - Specific line-by-line code issues
  - Concrete improvement suggestions with examples
  - Security vulnerabilities requiring fixes
  - Missing tests or documentation
- You MUST read the full body of bot reviews and extract every actionable item

### CI Status Analysis

For CI status checks:

- **Check if ALL status checks passing**:
  - If ANY failing: Fix BEFORE addressing review comments
  - Priority: Tests > Build > Linting > Type checking > Other

- **For failing checks**:
  - Read FULL logs via check-runs API
  - Identify root cause (not just symptoms)
  - Common patterns:
    - `FAILED tests/test_*.py::test_name` → pytest failure
    - `F401 'module' imported but unused` → ruff linting
    - `error: Incompatible types` → mypy type error
    - `Error: Build failed` → compilation/bundling error

- **For warnings in passing checks**:
  - Read logs even if conclusion is "success"
  - Look for: pytest warnings, deprecations, security warnings
  - Address to prevent future issues

### Review Feedback Categorization

For each piece of review feedback:

- **Categorize by priority**:
  - **Critical:** Security issues, bugs, breaking changes, test failures, build errors
  - **High:** Status check failures, design concerns, architecture issues
  - **Medium:** Code quality issues, performance concerns, warnings in logs
  - **Low:** Style preferences, minor improvements, linting warnings
  - **Nitpicks:** Formatting, typos, documentation improvements

- **Identify feedback source**:
  - **Human reviewers:** Highest priority - address every comment
  - **Status checks (CI/CD):** Must pass - address ALL errors, failures, and warnings
  - **Bot reviewers (CRITICAL - CHECK BOTH):**
    - `copilot-pull-request-reviewer[bot]`: Code quality, best practices, security
    - `claude[bot]`: Architecture, patterns, testing, comprehensive reviews
  - **Linters/formatters:** Address all warnings and errors in logs

- **Determine actionability**:
  - **Bot reviews:** ALWAYS actionable - extract ALL specific items
  - Concrete change requested: Make the change immediately
  - Status check failure: Fix the root cause
  - Warning in logs: Address to prevent future issues
  - Question or clarification: Respond with explanation
  - Conflicting feedback: Apply most recent (our policy)
