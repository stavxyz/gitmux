# PR Review Iteration

You are iterating on PR #{PR_NUMBER} to address review feedback automatically.

> **Recommended**: Run this workflow in plan mode first for classification and planning.
> See `.claude/guidelines/workflow/plan-first-pattern.md`.

## Quick Reference

| Phase | File | Description |
|-------|------|-------------|
| 0 | This file | Load guidelines |
| 1 | [step-1-gather-feedback.md](iterate-pr-reviews/step-1-gather-feedback.md) | Fetch & analyze feedback |
| 2 | [step-2-make-changes.md](iterate-pr-reviews/step-2-make-changes.md) | Make changes & commit |
| 3 | [step-3-verify-push.md](iterate-pr-reviews/step-3-verify-push.md) | Verify & push |
| - | [special-cases.md](iterate-pr-reviews/special-cases.md) | Conflicts, failures, etc. |

---

## Step 0: Load Guidelines

**CRITICAL**: Before acting on ANY feedback, classify it using the guidelines in `.claude/guidelines/`.

### Required Guidelines

1. **Priority Rules** (`.claude/guidelines/feedback-classification/priority-rules.md`)
   - CRITICAL: Security, vulnerabilities, breaking changes
   - HIGH: Bugs, errors, crashes
   - MEDIUM: Standard human review feedback
   - LOW: Optional suggestions
   - NITPICK: Style preferences, minor formatting

2. **Intent Detection** (`.claude/guidelines/feedback-classification/intent-detection.md`)
   - QUESTION: "Why did you..." → Respond with explanation, NOT code change
   - CHANGE_REQUEST: "Please add...", "You should..." → Make the change
   - CLARIFICATION_NEEDED: Ambiguous feedback → Ask before acting
   - CONFLICT: Multiple reviewers disagree → Escalate, don't guess

3. **Source Handling** (`.claude/guidelines/feedback-classification/source-handling.md`)
   - Priority based on CONTENT, not source
   - Human CHANGES_REQUESTED: Blocking
   - Bot reviews: Evaluate on content, check for false positives

4. **Conflict Detection** (`.claude/guidelines/feedback-classification/conflict-handling.md`)
   - Same file/line, different suggestions → CONFLICT
   - Stop and escalate, do not implement either

5. **Self-Critique** (`.claude/guidelines/self-critique/feedback-verification.md`)
   - Verify classification BEFORE acting on each item
   - Ask: Is this really a change request, or just a question?
   - Check: Has another reviewer said the opposite?

6. **Workflow** (`.claude/guidelines/workflow/iterate-pr-feedback.md`)
   - Systematic approach to PR iteration
   - How to handle outdated feedback

---

## Classification Output

For each feedback item, output before acting:

```
FEEDBACK: [Quote the feedback]
AUTHOR: [@username] (HUMAN/BOT)
PRIORITY: [CRITICAL/HIGH/MEDIUM/LOW/NITPICK]
INTENT: [QUESTION/CHANGE_REQUEST/CLARIFICATION_NEEDED/DISCUSSION/APPROVAL]
CONFLICTS_WITH: [None / @other-reviewer's comment]
ACTION: [CHANGE/RESPOND/ESCALATE/SKIP]
RATIONALE: [Why this classification?]
```

### Example Classification

```
FEEDBACK: "Why did you use a global variable here instead of passing it as a parameter?"
AUTHOR: @alice (HUMAN)
PRIORITY: MEDIUM
INTENT: QUESTION
CONFLICTS_WITH: None
ACTION: RESPOND
RATIONALE: This is a question (starts with "Why"), not a change request. Reviewer wants
           to understand the design decision. Respond with explanation of the rationale.
           If explanation reveals a flaw, upgrade to CHANGE_REQUEST.
```

---

## Process Overview

### 1. Gather Feedback
See: [step-1-gather-feedback.md](iterate-pr-reviews/step-1-gather-feedback.md)

- Fetch CI status FIRST
- Check bot reviews (copilot, claude) SECOND
- Check human reviews THIRD
- Classify each item using guidelines above

### 2. Make Changes
See: [step-2-make-changes.md](iterate-pr-reviews/step-2-make-changes.md)

- Address in priority order (CRITICAL → NITPICK)
- Verify locally before pushing
- Create well-structured commits

### 3. Verify and Push
See: [step-3-verify-push.md](iterate-pr-reviews/step-3-verify-push.md)

- Post summary comment to PR
- Run `verify-pr-ready.sh` (MANDATORY)
- Check for new reviews

### Special Cases
See: [special-cases.md](iterate-pr-reviews/special-cases.md)

- Conflicting feedback → Escalate
- Ambiguous feedback → Ask for clarification
- Test failures → Fix root cause

---

## Important Reminders

- **Read before editing**: Always read files completely before making changes
- **Test your changes**: Run relevant tests if possible
- **Be thoughtful**: Think through edge cases and implications
- **Stay focused**: Only address the specific feedback, don't over-engineer
- **Communicate clearly**: PR comments should be concise but informative

---

## Example Flow

```
Fetching feedback for PR #42...
  - Status checks: 3 failing, 2 passing with warnings
  - copilot-bot comments: 3
  - claude-bot comments: 2
  - Human reviews: 2

Classifying feedback...
  ✓ [CI] pytest: 2 tests failing - CRITICAL, CHANGE_REQUEST
  ✓ @alice: "Add input validation" - HIGH, CHANGE_REQUEST
  ✓ copilot-bot: "SQL injection risk" - CRITICAL, CHANGE_REQUEST
  ✓ @bob: "Fix typo" - NITPICK, CHANGE_REQUEST

Making changes (priority order)...
  ✓ Fixed SQL injection (CRITICAL)
  ✓ Fixed failing tests (CRITICAL)
  ✓ Added input validation (HIGH)
  ✓ Fixed typo (NITPICK)

Verifying...
  ✓ pytest tests/ -v (all passed)
  ✓ verify-pr-ready.sh exit 0

✓ Iteration complete!
```
