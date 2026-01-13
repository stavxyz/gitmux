# Intent Detection Rules

Determine what the reviewer wants before taking action. The most common mistake is treating a question as a change request.

## Intent Types

| Intent | Description | Response Type |
|--------|-------------|---------------|
| QUESTION | Reviewer wants explanation | Reply with comment, NO code change |
| CHANGE_REQUEST | Reviewer wants code modified | Make the requested change |
| CLARIFICATION_NEEDED | Feedback is ambiguous | Ask for clarification before acting |
| DISCUSSION | Multiple approaches possible | Engage in discussion, await consensus |
| APPROVAL | Positive feedback | Acknowledge, no action needed |

---

## Detection Rules

### QUESTION Intent

**Condition**: Reviewer is asking for explanation, not requesting changes.

**Patterns**:
- Starts with: `Why did you...`, `Why is this...`, `What is the reason...`
- Starts with: `I am curious...`, `Can you explain...`, `I don't understand...`
- Starts with: `How does this...`, `What happens if...`
- Contains `?` with explanation-seeking language

**Action**:
1. **DO NOT make code changes**
2. Post a PR comment with explanation
3. Reference specific code/design decisions
4. Ask if explanation is satisfactory or if changes are needed

**Examples**:
```
"Why did you use a global variable here?"
→ QUESTION: Explain the design decision, don't change the code

"I'm curious about the choice of this data structure"
→ QUESTION: Explain the tradeoffs considered

"What happens if the list is empty?"
→ QUESTION: Explain the handling (or note if it's unhandled)
```

**Critical Distinction**:
```
"Why did you use X? Please change to Y" → CHANGE_REQUEST (has explicit ask)
"Why did you use X?" → QUESTION (no explicit ask)
```

---

### CHANGE_REQUEST Intent

**Condition**: Reviewer explicitly requests a code change.

**Patterns**:
- Starts with: `Please...`, `Could you...`, `You should...`
- Starts with: `Change this to...`, `Replace X with Y...`
- Starts with: `Add...`, `Remove...`, `Fix...`, `Update...`
- Contains imperative verbs: `use`, `add`, `remove`, `rename`, `refactor`
- Review state is `CHANGES_REQUESTED`

**Action**:
1. Make the requested change
2. Follow priority rules for ordering
3. Verify change matches request before pushing

**Examples**:
```
"Please add error handling for the empty list case"
→ CHANGE_REQUEST: Add try/except or null check

"You should use a dictionary instead of a list for O(1) lookup"
→ CHANGE_REQUEST: Refactor to use dictionary

"Remove this unused import"
→ CHANGE_REQUEST: Delete the import line
```

---

### CLARIFICATION_NEEDED Intent

**Condition**: Feedback is ambiguous or incomplete.

**Patterns**:
- Contains `?` but unclear what action is requested
- Multiple interpretations possible
- References code that doesn't exist or has changed
- Incomplete sentences or fragments

**Action**:
1. **DO NOT guess at the intended change**
2. Post a PR comment asking for clarification
3. Describe the ambiguity specifically
4. Offer options if applicable

**Examples**:
```
"This seems off"
→ CLARIFICATION_NEEDED: Ask what specifically seems off

"Consider the edge cases"
→ CLARIFICATION_NEEDED: Ask which edge cases to consider

"?"
→ CLARIFICATION_NEEDED: Ask what the concern is
```

---

### DISCUSSION Intent

**Condition**: Feedback opens a design discussion rather than requesting a specific change.

**Patterns**:
- Presents multiple options: `We could either X or Y`
- Asks for preference: `What do you think about...`
- Philosophical: `Is this the right approach?`
- Contains `I prefer...` or `I would...` without imperative

**Action**:
1. Engage in the discussion via PR comment
2. Present your reasoning
3. Wait for consensus before making changes
4. If blocked, escalate to human

**Examples**:
```
"I wonder if we should use composition over inheritance here"
→ DISCUSSION: Share thoughts on tradeoffs, await decision

"There are pros and cons to both approaches"
→ DISCUSSION: Engage with the analysis, seek direction
```

---

### APPROVAL Intent

**Condition**: Positive feedback or acknowledgment.

**Patterns**:
- Starts with: `LGTM`, `Looks good`, `Nice work`, `Great job`
- Contains: `approved`, `ship it`, `merge when ready`
- Emoji-only: thumbs up, check marks, celebration

**Action**:
1. Acknowledge if appropriate
2. No code changes needed
3. Proceed with merge if all approvals received

**Examples**:
```
"LGTM!"
→ APPROVAL: No action needed

"Nice refactor, this is much cleaner"
→ APPROVAL: Acknowledge, no changes
```

---

## Decision Tree

```
Does feedback contain explicit change language (please/add/remove/fix)?
├── YES → CHANGE_REQUEST
└── NO ──┐
         Does feedback ask "why" or request explanation?
         ├── YES → QUESTION
         └── NO ──┐
                  Is feedback ambiguous or unclear?
                  ├── YES → CLARIFICATION_NEEDED
                  └── NO ──┐
                           Is feedback positive/approving?
                           ├── YES → APPROVAL
                           └── NO → DISCUSSION
```

---

## Common Mistakes to Avoid

1. **Treating questions as change requests**
   - "Why did you..." is asking for explanation, not demanding change
   - Always check for explicit change language before modifying code

2. **Guessing at ambiguous feedback**
   - If unclear, ask for clarification
   - Wrong guess = wasted iteration cycle

3. **Ignoring discussion in favor of action**
   - Some feedback needs conversation first
   - Don't rush to code when alignment is needed

---

## Output Format

When classifying, output:

```
INTENT: [QUESTION|CHANGE_REQUEST|CLARIFICATION_NEEDED|DISCUSSION|APPROVAL]
REQUIRES_CODE_CHANGE: [true|false]
REQUIRES_RESPONSE: [true|false]
RATIONALE: [Why this classification? Which pattern matched?]
```
