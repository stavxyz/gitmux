# Conflict Handling Rules

Detect when reviewers disagree and escalate to humans rather than guessing.

## Conflict Types

| Type | Description | Resolution |
|------|-------------|------------|
| DIRECT_CONFLICT | Reviewers give opposite instructions | Escalate immediately |
| APPROACH_CONFLICT | Reviewers suggest different solutions | Present options, await consensus |
| PRIORITY_CONFLICT | Reviewers disagree on importance | Follow priority rules, note disagreement |
| SCOPE_CONFLICT | Reviewers disagree on what to include | Clarify scope with PR author |

---

## Detection Rules

### DIRECT_CONFLICT

**Condition**: Two or more reviewers give contradictory instructions for the same code.

**Patterns**:
- Reviewer A says "add X" / Reviewer B says "remove X"
- Reviewer A says "use approach A" / Reviewer B says "use approach B"
- Reviewer A says "this is correct" / Reviewer B says "this is wrong"
- Same file/line referenced with opposing suggestions

**Action**:
1. **DO NOT implement either suggestion**
2. Post a PR comment summarizing the conflict
3. Tag both reviewers
4. Request they reach consensus
5. Wait for resolution before proceeding

**Template Response**:

    ## Conflicting Feedback Detected

    I've received conflicting feedback on this change:

    **@reviewer-a**: [their suggestion]
    **@reviewer-b**: [their suggestion]

    These suggestions appear to conflict. Could you please discuss and let me know
    which direction to take? I'll wait for consensus before making changes.

**Examples**:
```
Reviewer A: "Please add type hints to all functions"
Reviewer B: "Remove the type hints, they're making the code harder to read"
→ DIRECT_CONFLICT: Cannot satisfy both, escalate

Reviewer A: "Use a list comprehension here"
Reviewer B: "Use a for loop for clarity"
→ DIRECT_CONFLICT: Mutually exclusive approaches, escalate
```

---

### APPROACH_CONFLICT

**Condition**: Reviewers suggest different but potentially compatible solutions.

**Patterns**:
- Multiple suggestions for solving the same problem
- Different patterns/idioms suggested
- Performance vs readability tradeoffs mentioned by different reviewers

**Action**:
1. Analyze if approaches can be combined
2. If not combinable, post options summary
3. Recommend one approach with reasoning
4. Wait for agreement before implementing

**Template Response**:
```markdown
## Multiple Approaches Suggested

Different solutions were suggested for [problem]:

**Option A** (@reviewer-a): [approach]
- Pros: [benefits]
- Cons: [tradeoffs]

**Option B** (@reviewer-b): [approach]
- Pros: [benefits]
- Cons: [tradeoffs]

I'd recommend **Option [A/B]** because [reasoning].
Please confirm or redirect before I proceed.
```

---

### PRIORITY_CONFLICT

**Condition**: Reviewers disagree on the severity or importance of an issue.

**Patterns**:
- One reviewer says "blocker" / another says "nice to have"
- One says "must fix" / another says "can defer"
- Disagreement on what should block merge

**Action**:
1. Apply priority rules from `priority-rules.md`
2. Note the disagreement in commit message
3. Proceed with conservative (higher priority) interpretation
4. Flag for human review if unclear

---

### SCOPE_CONFLICT

**Condition**: Reviewers disagree on what changes belong in this PR.

**Patterns**:
- "This should be a separate PR"
- "While you're here, also fix X"
- "This change is out of scope"
- "We need to address Y before this"

**Action**:
1. Note scope disagreement
2. Default to original PR scope
3. Ask PR author for guidance
4. Consider splitting if both changes are valid

---

## Conflict Detection Checklist

Before implementing any feedback, check:

- [ ] Are there 2+ reviewers on this PR?
- [ ] Do any comments reference the same file/line?
- [ ] Do any suggestions contradict each other?
- [ ] Is there explicit disagreement in thread replies?

If any check is positive, evaluate for conflicts before proceeding.

---

## Examples of Non-Conflicts

Not every difference is a conflict:

```
Reviewer A: "Add error handling to function X"
Reviewer B: "Add error handling to function Y"
→ NOT A CONFLICT: Different functions, do both

Reviewer A: "Consider using a dictionary"
Reviewer B: "The list approach is fine too"
→ NOT A CONFLICT: One is a suggestion, one is neutral

Reviewer A: "Fix the bug in line 10"
Reviewer B: "Also, add a test for this"
→ NOT A CONFLICT: Complementary feedback, do both
```

---

## Escalation Protocol

When conflict is detected:

1. **Stop** - Do not implement conflicting changes
2. **Summarize** - Clearly state the conflict
3. **Tag** - Notify all involved reviewers
4. **Wait** - Do not proceed until resolved
5. **Document** - Note resolution in commit message

---

## Output Format

When detecting conflicts:

```
CONFLICT_TYPE: [DIRECT|APPROACH|PRIORITY|SCOPE|NONE]
CONFLICTING_PARTIES: [@reviewer-a, @reviewer-b]
CONFLICT_SUMMARY: [One sentence describing the disagreement]
RESOLUTION_STATUS: [BLOCKED|AWAITING_CONSENSUS|RESOLVED]
```
