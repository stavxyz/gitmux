# PR Feedback Iteration Workflow

Systematic approach to addressing PR review feedback using structured guidelines.

---

## Recommended: Plan-First Workflow

**See**: `plan-first-pattern.md` for the general pattern.

For PR feedback specifically:

1. **Gather feedback links** (comment URLs, review URLs)
2. **Enter plan mode** with `opusplan` model
3. **Claude classifies** each feedback item:
   - Apply `priority-rules.md` (CRITICAL/HIGH/MEDIUM/LOW/NITPICK)
   - Apply `intent-detection.md` (QUESTION vs CHANGE_REQUEST)
   - Check for outdated items (PR may have changed since review)
4. **User approves** the classification and plan
5. **Exit plan mode** → Execute

This ensures even small feedback gets proper classification before action.

---

## Step 1: Gather Feedback

Fetch ALL feedback sources:

```bash
# CI status
gh pr checks {PR_NUMBER}

# Bot reviews (both copilot and claude)
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments

# Human reviews
gh pr view {PR_NUMBER} --json reviews
```

Include:
- Human reviewer comments
- Bot reviewer comments (copilot, claude)
- CI/CD status and logs
- Inline code comments

---

## Step 2: Classify Each Item

Apply guidelines to each feedback item:

1. **Priority** (`priority-rules.md`)
   - CRITICAL / HIGH / MEDIUM / LOW / NITPICK
   - Based on CONTENT, not source

2. **Intent** (`intent-detection.md`)
   - QUESTION / CHANGE_REQUEST / CLARIFICATION_NEEDED
   - Don't treat questions as change requests

3. **Source context** (`source-handling.md`)
   - Bot vs human (affects false positive checking, not priority)
   - Blocking vs non-blocking

4. **Conflicts** (`conflict-handling.md`)
   - Check if reviewers disagree

---

## Step 3: Check for Outdated Feedback

**Critical step often missed!**

If PR has changed since reviews were posted:

1. **Rebase or force-push occurred**
   - Reviews may reference code that no longer exists
   - Mark clearly as OUTDATED, don't silently ignore

2. **Scope changed significantly**
   - Feedback about removed code → OUTDATED
   - Feedback about remaining code → Still VALID

3. **How to handle**
   - List outdated items explicitly
   - Explain what changed in PR comment
   - Don't implement outdated requests

### Outdated Feedback Example

    ## Feedback Classification

    | Item | Status | Notes |
    |------|--------|-------|
    | "Add type hints to utils.py" | **OUTDATED** | utils.py removed in rebase |
    | "Fix typo in README" | VALID | README still exists |

---

## Step 4: Address in Priority Order

Process feedback in this order:

1. **CRITICAL** - Must fix before merge
   - Security vulnerabilities
   - Data loss risks
   - Breaking changes

2. **HIGH** - Should fix before merge
   - Bugs
   - Test failures
   - Build errors

3. **MEDIUM** - Address in order received
   - Design suggestions
   - Code quality

4. **LOW** - Address after higher priorities
   - Suggested improvements
   - "Consider" suggestions
   - Default to doing them

5. **NITPICK** - Fix last (but still fix them)
   - Style preferences
   - Minor formatting
   - Quick fixes - just do them

---

## Step 5: Document What You Did

Post a summary comment to the PR:

```markdown
## Feedback Response

### Addressed in This Update

| Item | Priority | Action |
|------|----------|--------|
| SQL injection risk | CRITICAL | Fixed with parameterized query |
| Missing error handling | HIGH | Added try/catch |
| Typo in docstring | NITPICK | Fixed |

### Marked as Outdated

- "Add type hints to parser.py" - File removed in rebase
- "Split large function" - Already split in previous commit
```

---

## Common Mistakes to Avoid

### Mistake 1: Treating Questions as Change Requests

**Wrong**:
```
Feedback: "Why did you use a global here?"
Action: Changed global to local
```

**Right**:
```
Feedback: "Why did you use a global here?"
Action: Posted explanation of design decision
```

### Mistake 2: Silently Ignoring Outdated Feedback

**Wrong**:
```
# Just ignore the feedback since code changed
```

**Right**:
```
# Explicitly list as outdated with explanation
| "Add tests for util.py" | OUTDATED | util.py was removed |
```

### Mistake 3: Implementing Conflicting Feedback

**Wrong**:
```
Reviewer A: "Add type hints"
Reviewer B: "Remove type hints"
Action: Added type hints (picked one randomly)
```

**Right**:
```
Action: Posted comment asking for consensus
```

---

## Self-Verification Checklist

Before pushing, verify:

- [ ] All CRITICAL items addressed
- [ ] All HIGH items addressed
- [ ] MEDIUM items addressed in order
- [ ] Outdated items explicitly documented
- [ ] Conflicts escalated (not guessed)
- [ ] Summary comment prepared
- [ ] Tests pass locally

---

## Integration with Other Guidelines

This workflow uses:
- `priority-rules.md` - For classification
- `intent-detection.md` - For distinguishing questions from requests
- `source-handling.md` - For bot vs human context
- `conflict-handling.md` - For handling disagreements
- `feedback-verification.md` - For self-critique before acting
