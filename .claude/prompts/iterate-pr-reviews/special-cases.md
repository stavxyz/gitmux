# Special Cases

## Status Check Failures

**REQUIRED:** ALL status checks must pass before iteration completes.

When status checks fail:
1. Get full logs: `gh api repos/{owner}/{repo}/commits/{sha}/check-runs`
2. Identify exact error message/line number
3. Fix root cause (not symptoms)
4. Verify fix locally before pushing
5. Common patterns:
   - **Test failures:** Fix the test or the code being tested
   - **Linting errors:** Run linter locally, fix all issues
   - **Type errors:** Add type hints, fix type mismatches
   - **Build errors:** Fix compilation/bundling issues
   - **Coverage drops:** Add tests to maintain coverage threshold

**Warnings in passing checks:**
- Address deprecation warnings
- Fix security warnings
- Clean up linting warnings
- Update outdated dependencies

---

## Conflicting Feedback

When reviewers disagree:
- Apply the **most recent** feedback (our policy)
- Add PR comment explaining which approach you chose and why
- Tag the reviewers if clarification needed

---

## Ambiguous Feedback

If you can't determine concrete action:
- Add PR comment asking for clarification
- Reference the specific comment
- Propose 2-3 possible interpretations
- Pause iteration until clarification received

---

## Test Failures

If CI tests are failing:
1. Get full test output from status check logs
2. Analyze the specific failure
3. Fix if straightforward
4. If complex, add PR comment describing the issue and ask for help
5. NEVER push without tests passing

---

## Merge Conflicts

If push fails due to conflicts:
- Pull latest changes
- Attempt auto-merge
- If conflicts remain, add PR comment and pause

---

## Success Criteria

You've successfully completed iteration when **ALL** of the following are true:

**PRE-REQUISITE:** You MUST have a completed todo item showing you ran `verify-pr-ready.sh` with exit code 0.

1. **`verify-pr-ready.sh` exits with code 0** (MANDATORY GATE)
   - All checks must have `conclusion == "success"`
   - No checks can be pending/in-progress
   - No checks can be failing

2. **ALL review feedback has been addressed** (critical, high, medium, low, AND nitpicks)

3. **Changes committed and pushed** with clear commit messages

4. **PR comment posted** summarizing all work done

5. **No new reviews detected** by `check-pr-reviews.sh`

**Incomplete iteration if ANY of:**
- `verify-pr-ready.sh` exits with code 1 (not ready) or 2 (error)
- Any CI check is failing or pending
- Any review comment is unaddressed
- Tests don't pass locally
