# Plan-First Pattern

Use plan mode for analysis and classification, exit for implementation.

## Core Principle

> **Think before you act. Plan mode is for thinking. Exit to act.**

---

## When to Use Plan-First

- PR feedback iteration (any size)
- Complex refactoring
- Multi-file changes
- Tasks with multiple decision points
- Anything requiring classification or prioritization

**Rule of thumb**: If you need to classify, prioritize, or make decisions before acting, use plan mode first.

---

## Why It Works

1. **Read-only safety**: Plan mode prevents accidental changes while analyzing
2. **Opus 4.5 reasoning**: "opusplan" model mode = best model for deep thinking
3. **User approval gate**: Plan must be approved before implementation
4. **Visible thinking**: All decisions explicit and auditable
5. **Consistent quality**: Same robust process for small or large tasks

---

## The Process

```
1. User provides context (links, requirements, questions)
2. Enter plan mode (with opusplan for best reasoning)
3. Claude analyzes in plan mode:
   - Read all relevant information (read-only operations)
   - Classify, prioritize, identify issues
   - Write comprehensive plan to plan file
4. User reviews and approves the plan
5. Exit plan mode → Execute with confidence
```

---

## Plan File Structure

The plan file should contain:

| Section | Purpose |
|---------|---------|
| **Context** | What we're working on and why |
| **Classification table** | Items with priority, intent, action |
| **Execution order** | What to do first, second, etc. |
| **Files to modify** | Explicit list with expected changes |
| **Success criteria** | How we know we're done |

---

## Example: PR Feedback

```
User: [enters plan mode with opusplan]
User: "Classify these feedback items:
       - https://github.com/org/repo/pull/67#issuecomment-123
       - https://github.com/org/repo/pull/67#pullrequestreview-456"

Claude: [fetches feedback, classifies, writes to plan file]

Plan file contains:
| Item | Priority | Intent | Action |
|------|----------|--------|--------|
| Security issue | CRITICAL | CHANGE_REQUEST | Fix first |
| "Why this approach?" | MEDIUM | QUESTION | Respond only |
| Typo in docs | NITPICK | CHANGE_REQUEST | Fix and batch |

User: "Approved"
[exits plan mode]

Claude: [executes approved plan in priority order]
```

---

## Example: Refactoring

```
User: [enters plan mode]
User: "Plan refactoring auth module to use JWT"

Claude: [explores codebase, writes plan]

Plan file contains:
| Step | File | Change |
|------|------|--------|
| 1 | auth/session.py | Replace session tokens with JWT |
| 2 | auth/middleware.py | Update token validation |
| 3 | tests/test_auth.py | Update test fixtures |

User: "Let's do steps 1-2 first"
[exits plan mode]

Claude: [executes approved subset only]
```

---

## Example: Bug Investigation

```
User: [enters plan mode]
User: "Investigate why login fails on mobile"

Claude: [searches codebase, reads logs, writes plan]

Plan file contains:
## Root Cause Analysis
- Found: Mobile user agent triggers different auth path
- Issue: Session cookie not set with SameSite=None

## Proposed Fix
1. Update cookie settings in auth/cookies.py
2. Add mobile user agent test case

User: "Good analysis, proceed"
[exits plan mode]

Claude: [implements the fix]
```

---

## Benefits for Different Task Sizes

### Small Tasks (1-2 items)
- Still worth it: classification prevents mistakes
- Quick to plan: maybe 30 seconds
- Prevents "Oh I should have asked first"

### Medium Tasks (3-10 items)
- Essential: prioritization matters
- Catches outdated/conflicting feedback
- Clear execution order

### Large Tasks (10+ items)
- Critical: without plan, easy to miss items
- Batching opportunities visible
- User can approve subset first

---

## Anti-Patterns to Avoid

### Don't: Jump straight to implementation

```
User: "Fix the PR feedback"
Claude: [immediately starts editing files]
```

### Do: Plan first, even for "obvious" fixes

```
User: "Fix the PR feedback"
Claude: "Let me classify this first in plan mode..."
[writes classification to plan file]
Claude: "I've identified 3 items. Ready to proceed?"
```

### Don't: Guess at priorities

```
Claude: "This looks like a nitpick, I'll do it last"
[turns out it was blocking]
```

### Do: Classify explicitly

```
Plan file:
| Item | Priority | Rationale |
|------|----------|-----------|
| "nit: fix typo" | NITPICK | Explicitly marked as nit |
| "consider caching" | LOW | "Consider" = evaluate and likely do |
| "add validation" | HIGH | Bug prevention |
```

---

## Integration with Other Guidelines

This pattern works with:
- `priority-rules.md` - For classification criteria
- `intent-detection.md` - For distinguishing questions from requests
- `iterate-pr-feedback.md` - Specific application to PR iteration
- `feedback-verification.md` - Self-critique checklist

---

## Summary

| Phase | Mode | Activities |
|-------|------|------------|
| **Think** | Plan mode | Read, classify, prioritize, plan |
| **Approve** | Transition | User reviews and approves; assistant exits plan mode |
| **Act** | Normal mode | Execute the approved plan |
