**TL;DR**: `persuade iterate-pr {PR_NUMBER}` - Review and address PR feedback in two phases (plan, then execute after approval).

---

Run the iterate-pr workflow with deterministic two-phase execution.

## Usage

```bash
persuade iterate-pr {PR_NUMBER}
```

Or with auto-approve for CI/CD:
```bash
persuade iterate-pr {PR_NUMBER} --auto-approve
```

## What Happens

**Phase 1 (Plan):** Read-only analysis
- Fetches PR feedback via workflow scripts
- Reads state file for unaddressed items
- Classifies items by priority (CRITICAL/HIGH/MEDIUM/LOW/NITPICK)
- Presents plan for approval

**Phase 2 (Execute):** After approval
- Addresses feedback in priority order using Claude Agent SDK
- Updates state file with addressed items
- Commits and pushes changes

## Two-Phase Pattern

The CLI enforces deterministic two-phase execution:

1. **Plan phase is always read-only** - No code changes until you approve
2. **Execution only after approval** - You see exactly what will happen first
3. **Same behavior every time** - No more non-deterministic LLM instructions

## Example Session

```
$ persuade iterate-pr 67

**Then:**
1. Use TodoWrite to create a checklist from the feedback
2. Address each item systematically (mark in_progress → completed)
3. **Verify documentation updated:**
   - [ ] Code changes have corresponding doc updates
   - [ ] Docstrings updated for modified functions
   - [ ] README/API docs updated if applicable
   - [ ] PR description reflects all changes
4. Run tests after changes
5. Commit and push fixes with Co-Authored-By tags
6. Re-run the workflow script to check for new feedback

**If no feedback found:** The PR is ready to merge!

---

## Documentation Verification

**When addressing PR feedback, ALWAYS check documentation:**

### Code Changes → Documentation Updates

| If you changed... | Then update... |
|-------------------|----------------|
| Function signature | Docstring (Args, Returns) |
| Function behavior | Docstring + comments |
| User-facing feature | README.md |
| API endpoint | docs/api.md |
| Architecture/design | docs/architecture.md |
| Configuration | README + docs |

### Quick Documentation Checklist

Before pushing fixes:
- [ ] All modified functions have updated docstrings
- [ ] Complex new logic has explanatory comments
- [ ] README reflects any user-visible changes
- [ ] API docs updated if endpoints changed
- [ ] PR description mentions doc updates

### Common Mistakes

❌ **Don't do this:**
- Fix code but forget to update docstring
- Update function signature without updating docs
- Add feature without updating README

✅ **Do this instead:**
- Update docs in same commit as code fix
- Mention doc updates in commit message
- Review PR template documentation checklist
┌─────────────────────────────────────────────────────────────┐
│ PR #67 requires iteration                                   │
│ Found 3 unaddressed feedback items:                         │
│                                                             │
│   Review Comments: 2                                        │
│     - @alice: Please add input validation...                │
│     - @bob: Consider using dataclass here...                │
│                                                             │
│   Issue Comments: 1                                         │
│     - [BOT]: CI check failed: mypy errors...                │
└─────────────────────────────────────────────────────────────┘

Proceed with execution? [y/N]: y

✓ Addressed 3 feedback items
✓ Changes committed

Run 'git diff HEAD~1' to review changes before pushing.
```

## Manual Workflow (Alternative)

If you prefer manual control over each step, the detailed workflow is documented in:
- `.claude/guidelines/workflow/iterate-pr-feedback.md`
- `.claude/guidelines/feedback-classification/priority-rules.md`

## Requirements

The `persuade` CLI must be installed:
```bash
pip install -e ".[agents]"  # For full agent support
```

Or without Claude Agent SDK (plan-only mode):
```bash
pip install -e .
```
