# Priority Classification Rules

Classify PR feedback by priority level to ensure critical issues are addressed first.

> **Important**: These rules assume you've already applied **intent detection** (see `intent-detection.md`). After identifying the feedback's intent, classify its **priority** based on the content. A question about security is not CRITICAL - it's a QUESTION about a security topic.
>
> **Example**:
> - "Is this vulnerable to SQL injection?" → Intent: QUESTION → Priority: Informational (answer the question)
> - "This is vulnerable to SQL injection because X" → Intent: CHANGE_REQUEST → Priority: CRITICAL (fix immediately)

## Priority Levels

**Priority is based on CONTENT, not SOURCE.** A security issue from a bot is CRITICAL. A nitpick from a human is NITPICK.

## Core Principle

> **Address ALL worthwhile feedback. Priority determines ORDER, not whether to act.**
>
> If feedback is smart, good, or valid - implement it. Don't defer good suggestions
> just because they're "LOW" or "NITPICK". A 2-second fix should be done immediately,
> not deferred to a "future cleanup PR" that never happens.
>
> The ONLY reasons to skip feedback:
> 1. **FALSE POSITIVE** - factually incorrect about the code
> 2. **CONFLICT** - contradicts another reviewer's feedback
> 3. **DISAGREE** - you can articulate a clear technical reason why not
>
> "Non-blocking" means the PR can technically merge - it does NOT mean skip the feedback.

| Level | Description | Action Required |
|-------|-------------|-----------------|
| CRITICAL | Security vulnerabilities, data loss, breaking changes | Must fix before merge, block PR |
| HIGH | Bugs, errors, crashes, test failures | Fix before merge |
| MEDIUM | Substantive feedback about code logic, design, implementation | Address in order received |
| LOW | Suggested improvements, "consider" items | Address after higher priorities |
| NITPICK | Style preferences, minor formatting | Fix last, batch together |

---

## Classification Rules

### CRITICAL Priority

**Condition**: Feedback contains any of these patterns:
- `security`, `vulnerability`, `CVE-`, `exploit`
- `injection`, `XSS`, `SSRF`, `CSRF`, `SQL injection`
- `authentication bypass`, `authorization`, `access control`
- `data leak`, `data loss`, `exposure`
- `breaking change`, `backwards compatibility`
- `regression`, `revert`

**Action**:
1. Stop other work immediately
2. Research the vulnerability type before fixing
3. Add security test case demonstrating the fix
4. Request security review in PR comment
5. Do NOT merge until verified fixed

**Example**:
```
"This endpoint is vulnerable to SQL injection - user input is not sanitized"
→ CRITICAL: Research SQL injection, add parameterized query, add test case
```

---

### HIGH Priority

**Condition**: Feedback contains any of these patterns:
- `bug`, `error`, `crash`, `fail`, `broken`
- `doesn't work`, `not working`, `incorrect`
- `test failure`, `CI failing`, `build broken`
- `exception`, `stack trace`, `undefined`
- `null pointer`, `type error`, `runtime error`

**Action**:
1. Address before any MEDIUM/LOW/NITPICK items
2. Understand root cause before fixing
3. Add test case to prevent regression
4. Verify fix locally before pushing

**Example**:
```
"This causes a crash when the user list is empty"
→ HIGH: Add null check, add test with empty list
```

---

### MEDIUM Priority

**Condition**: Substantive feedback that doesn't match CRITICAL/HIGH/LOW/NITPICK patterns.

**Indicators**:
- Contains feedback about code logic, design, or implementation
- Not explicitly marked as optional or nit
- Suggests a concrete change or improvement

**Action**:
1. Address in order received
2. Group related feedback together
3. Standard code review process

**Example**:
```
"Consider using a dictionary here for O(1) lookup instead of a list"
→ MEDIUM: Evaluate suggestion, implement if beneficial
```

---

### LOW Priority

**Condition**: Optional improvements and suggestions.

**Indicators**:
- Contains phrases like `consider`, `you might want to`, `optional`, `could`
- Suggestions that are nice-to-have rather than required
- Improvements that don't affect correctness or security

**Action**:
1. Address after CRITICAL/HIGH/MEDIUM items
2. These are still good suggestions - default to doing them
3. Skip ONLY if factually wrong, conflicts, or you can articulate why not
4. Quick improvements (< 1 minute) should be done, not deferred

**Example**:
```
"You might want to consider adding a cache here for performance"
→ LOW: Valid suggestion - evaluate and likely implement
```

**Note**: Being from a bot does NOT make something LOW priority. A bot finding a security issue is CRITICAL.

---

### NITPICK Priority

**Condition**: Style preferences and minor formatting.

**Indicators**:
- Explicitly marked: `nit:`, `nitpick:`, `minor:`
- Formatting issues (whitespace, line length)
- Naming preferences without functional impact
- Comment wording suggestions

**Action**:
1. Address last, after all other priorities
2. Batch multiple nitpicks into single commit
3. These are often 2-second fixes - just do them
4. Don't overthink, don't defer, just fix

**Example**:
```
"nit: prefer snake_case for this variable name"
→ NITPICK: Quick rename, batch with other style fixes
```

---

## Decision Tree

```
Is feedback about security/vulnerability?
├── YES → CRITICAL (regardless of source)
└── NO ──┐
         Is feedback about bugs/errors/crashes?
         ├── YES → HIGH (regardless of source)
         └── NO ──┐
                  Is it marked as nit/nitpick/minor?
                  ├── YES → NITPICK
                  └── NO ──┐
                           Is it optional? ("consider", "you might", "could")
                           ├── YES → LOW
                           └── NO → MEDIUM
```

**Note**: Source (bot vs human) is NOT part of priority classification. Priority is content-based only.

---

## Pattern Matching Caveats

**IMPORTANT**: Check context, not just keywords. Apply intent detection FIRST.

### False Positive Examples

| Feedback | Naive Classification | Correct Classification | Why |
|----------|---------------------|----------------------|-----|
| "Is this a security concern?" | CRITICAL | QUESTION about security | Asking, not asserting |
| "This doesn't exploit anything" | CRITICAL | MEDIUM | Denying vulnerability, not reporting |
| "Why is this error handling?" | HIGH | QUESTION | Asking why, not reporting bug |
| "Please fix this potential crash" | HIGH | HIGH | Correct - asserting potential bug |

### Rule: Intent Detection First

1. **First**: Is this a QUESTION or CHANGE_REQUEST? (See `intent-detection.md`)
2. **Then**: If CHANGE_REQUEST, classify the *content* of what they want changed
3. **If QUESTION**: Classify what they're asking *about*, not the feedback itself

> **Clarification**: For QUESTIONS, do not upgrade the PRIORITY just because the
> feedback text contains scary keywords like "security", "crash", or "data loss".
> Instead, keep the PRIORITY appropriate for answering a question (typically LOW)
> and respond with an explanation. Only upgrade if answering reveals a real issue.

**Examples**:
- "Is this secure?" → QUESTION about security → Respond with explanation
- "This is insecure, please fix" → CHANGE_REQUEST about security → CRITICAL priority
- "Why did you use eval()?" → QUESTION → But security-relevant, so explain AND evaluate if change needed

---

## Output Format

When classifying, output:

```
PRIORITY: [CRITICAL|HIGH|MEDIUM|LOW|NITPICK]
RATIONALE: [Why this classification? Which pattern matched?]
```
