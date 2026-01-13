# Step 3: Verify and Push

> **Note**: Variables like `{PR_NUMBER}`, `{owner}`, `{repo}` in the examples below are placeholders. Substitute with actual values when running commands.

## Update PR

Add a comment summarizing your changes:

```bash
gh pr comment {PR_NUMBER} -b "$(cat <<'EOF'
### Review Feedback Addressed

I've addressed the following feedback:

#### Status Checks Fixed
1. **[CI Check] Test failures**
   - Fixed: <specific test that was failing>
   - Root cause: <what was wrong>
   - Files affected: `file1.py`, `file2.py`

2. **[CI Check] Linting warnings**
   - Fixed: <specific linting issues>
   - Tool: ruff/mypy/eslint

#### Review Comments Addressed
1. **[@reviewer] Comment about X** (Critical)
   - Changed: <what you did>
   - Rationale: <why>

2. **[@reviewer] Comment about Y** (Nitpick)
   - Changed: <what you did>
   - Files affected: `file1.py`

### Changes Made

- <bullet list of concrete changes>

### Verification
- ✅ All tests passing locally
- ✅ Linting errors resolved
- ✅ Type checking passed
- ✅ All review comments addressed (including nitpicks)

Ready for re-review.

---
🤖 Automated via Claude Code
EOF
)"
```

---

## Check for More Reviews

First, check if there are new reviews or CI changes:

```bash
bash .claude/scripts/check-pr-reviews.sh {PR_NUMBER}
```

- If iteration needed (exit code 0): Repeat from step 1
- If no iteration needed (exit code 1): Proceed to Final Verification
- If error (exit code 2): Report the issue and stop

---

## Final Verification (MANDATORY)

**CRITICAL:** Before declaring the PR "ready", run this verification script:

### Step 1: Add verification to todo list

```
TodoWrite:
  - content: "Verify PR ready with verify-pr-ready.sh"
    activeForm: "Verifying PR ready with verify-pr-ready.sh"
    status: "pending"
```

### Step 2: Run verification script

```bash
bash .claude/scripts/verify-pr-ready.sh {PR_NUMBER}
```

### Step 3: Update todo based on result

- **Exit 0 (ready):** Mark todo completed, may declare PR ready
- **Exit 1 (not ready):** Keep todo in_progress, wait for fixes
- **Exit 2 (error):** Keep todo in_progress, report to user

**Exit codes:**
- **Exit 0** (ready): All CI checks passing → You may declare PR ready
- **Exit 1** (not ready): CI checks failing or pending → DO NOT declare PR ready
- **Exit 2** (error): Cannot verify CI status → DO NOT declare PR ready

**MANDATORY RULES:**
1. **NEVER declare a PR ready without running this script**
2. **NEVER declare a PR ready if this script exits with code 1 or 2**
3. **NEVER use phrases like "production ready", "ready to merge" unless this script exits with code 0**

---

## Iteration Limit

Track iterations in state file. If iterations ≥ 10:
- Stop automatic iteration
- Add PR comment explaining the situation
- Ask user for guidance
