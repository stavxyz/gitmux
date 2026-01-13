# Self-Critique: Feedback Verification

Before acting on any feedback item, verify your classification is correct. This prevents the most common mistakes in PR iteration.

## Core Principle

> **Stop and verify before you act.**
>
> A wrong classification wastes an entire iteration cycle.
> Taking 30 seconds to verify saves hours of rework.

---

## Verification Checklist

For EACH feedback item, before taking action:

### 1. Priority Verification

- [ ] If classified CRITICAL: Is this actually a security issue, or does it just mention security in a question?
  - "Is this a security concern?" → QUESTION, not CRITICAL
  - "This has a SQL injection vulnerability" → CRITICAL

- [ ] If classified NITPICK: Is there hidden severity?
  - "nit: this null check is missing" → Actually HIGH (potential crash)
  - "nit: prefer snake_case" → Actually NITPICK

### 2. Intent Verification

- [ ] If treating as CHANGE_REQUEST: Is there explicit change language?
  - Must contain: please, add, remove, fix, change, update, should
  - "Why did you..." alone is QUESTION, not CHANGE_REQUEST

- [ ] If treating as QUESTION: Am I sure they don't want changes?
  - "Why did you use X instead of Y?" → Could be either
  - Check for: "please change", "could you use", "you should"
  - When in doubt, respond with explanation AND offer to change

### 3. Conflict Verification

- [ ] Have I checked ALL feedback for this PR?
  - Don't miss late-arriving comments
  - Check both review comments AND inline comments

- [ ] Does any other reviewer contradict this feedback?
  - Same file/line, different suggestion = CONFLICT
  - Stop and escalate, don't guess

### 4. Source Verification

- [ ] If bot feedback: Have I checked for false positives?
  - Does this contradict human feedback?
  - Is this a known false positive pattern?
  - Has a human already addressed this differently?

- [ ] If human feedback: Is review state CHANGES_REQUESTED?
  - CHANGES_REQUESTED = blocking, must address
  - COMMENTED = should address, not blocking

---

## Verification Output

Before acting on each feedback item, output:

```markdown
## Feedback Verification

**Item**: [Quote the feedback]
**Author**: [@username] ([HUMAN/BOT])

### Classification
- Priority: [CRITICAL/HIGH/MEDIUM/LOW/NITPICK]
- Intent: [QUESTION/CHANGE_REQUEST/CLARIFICATION_NEEDED/DISCUSSION/APPROVAL]
- Source Weight: [HIGHEST/HIGH/MEDIUM/LOW/INFO]

### Verification
- [ ] Priority is correct (not misclassified as higher/lower)
- [ ] Intent is correct (not mistaking question for change request)
- [ ] No conflicts with other reviewers
- [ ] If bot, checked for false positives

### Confidence
- Confidence: [HIGH/MEDIUM/LOW]
- Rationale: [Why this classification?]

### Planned Action
- Action: [CHANGE/RESPOND/ESCALATE/SKIP]
- Details: [Specific change or response planned]
```

---

## Common Mistakes and How to Avoid Them

### Mistake 1: Treating Questions as Change Requests

**Wrong**:
```
Feedback: "Why did you use a global variable here?"
Action: Changed global to local variable
```

**Right**:
```
Feedback: "Why did you use a global variable here?"
Action: Posted explanation of design decision
```

**Prevention**: Look for explicit change language (please, add, remove, fix)

---

### Mistake 2: Missing Security Context

**Wrong**:
```
Feedback: "Is this input validated?"
Classification: QUESTION, LOW priority
```

**Right**:
```
Feedback: "Is this input validated?"
Classification: QUESTION about potential security issue
Action: Explain current validation AND add if missing
```

**Prevention**: Security-adjacent questions may reveal real vulnerabilities

---

### Mistake 3: Implementing Conflicting Feedback

**Wrong**:
```
Reviewer A: "Add type hints"
Reviewer B: "Remove type hints"
Action: Added type hints (picked one)
```

**Right**:
```
Reviewer A: "Add type hints"
Reviewer B: "Remove type hints"
Action: Posted conflict summary, awaiting consensus
```

**Prevention**: Always scan all feedback for conflicts before acting

---

### Mistake 4: Trusting Bot Feedback Blindly

**Wrong**:
```
@copilot-bot: "Add docstring to this function"
Action: Added generic docstring
```

**Right**:
```
@copilot-bot: "Add docstring to this function"
Verification: Human reviewer said code is self-documenting
Action: Skip bot suggestion, human feedback takes precedence
```

**Prevention**: Check if bot feedback conflicts with human decisions

---

## When Confidence is Low

If confidence in classification is LOW:

1. **Don't guess** - Ask for clarification
2. **State uncertainty** - "I interpreted this as X, please confirm"
3. **Offer options** - "I can do A or B, which do you prefer?"
4. **Wait for response** - Don't proceed without clarity

---

## Final Check Before Acting

Before making any change or response:

```
□ I have verified the priority classification
□ I have verified the intent classification
□ I have checked for conflicts with other reviewers
□ I have considered if this is a bot false positive
□ My planned action matches the verified classification
□ I am confident this is the correct response
```

If any box is unchecked, STOP and re-evaluate.
