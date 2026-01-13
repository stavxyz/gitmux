# Source Handling Rules

Different feedback sources require different handling, but **priority is determined by CONTENT, not SOURCE**.

## Core Principle

> **Bots are often MORE thorough than humans.**
>
> A security issue found by a bot is just as critical as one found by a human.
> A nitpick from a human is just as low-priority as one from a bot.
> Always evaluate feedback based on WHAT it says, not WHO said it.

## Source Types

| Source | Blocking? | Handling |
|--------|-----------|----------|
| Human with CHANGES_REQUESTED | YES | Must address before merge |
| Human with COMMENTED | NO | Should address |
| Code owner review | REPO-SPECIFIC | Check branch protection rules and CODEOWNERS |
| Bot reviewer | NO | Evaluate on content, check for false positives |
| CI/GitHub Actions | N/A | Status only, not review feedback |

> **Determining REPO-SPECIFIC blocking status**: Check the repository's branch protection
> rules (Settings → Branches → Branch protection rules). If "Require review from Code
> Owners" is enabled, code owner approval is blocking. If not enabled, treat as
> non-blocking but high-weight feedback.

> **Clarification**: "Non-blocking" means the PR can technically merge without this
> reviewer's explicit approval. It does NOT mean their feedback can be ignored.
> Address all worthwhile feedback regardless of blocking status.

---

## Identification Rules

### Human Reviewers

**Identification**:
- Username does NOT end with `[bot]`
- Review submitted via GitHub PR review UI
- Has review state: `APPROVED`, `CHANGES_REQUESTED`, or `COMMENTED`

**Weight by Review State**:

| State | Weight | Meaning |
|-------|--------|---------|
| CHANGES_REQUESTED | HIGHEST | Blocking - must address to merge |
| COMMENTED | HIGH | Non-blocking but should address |
| APPROVED | INFO | Positive signal, no action needed |

**Handling**:
1. CHANGES_REQUESTED blocks merge until resolved
2. COMMENTED feedback should be addressed but isn't blocking
3. Address based on content priority (security > bugs > standard feedback > nitpicks)

---

### Bot Reviewers

**Known Bots**:
- `copilot-pull-request-reviewer[bot]` - GitHub Copilot code review
- `claude[bot]` - Claude automated review
- `dependabot[bot]` - Dependency updates
- `github-actions[bot]` - CI status (not review feedback)
- `codecov[bot]` - Coverage reports
- `sonarcloud[bot]` - Code quality analysis

**Identification**:
- Username ends with `[bot]`
- Often have structured/templated feedback format
- May include confidence scores or categories

**Handling**:
1. **Classify by CONTENT first** - apply priority-rules.md to bot feedback same as human
2. **Check for false positives** - bots may lack project-specific context
3. Skip if clearly incorrect OR already addressed by human feedback
4. **Do NOT deprioritize just because it's a bot** - bots often catch issues humans miss

**Why Bots Can Be More Thorough**:
- Systematic: Check every file, every pattern, every time
- Consistent: Do not get fatigued or rush reviews
- Comprehensive: May catch edge cases, security patterns, type issues
- Up-to-date: Often have latest best practices

**Common False Positives (check before dismissing)**:
- Type hint suggestions for dynamic code
- "Missing docstring" where project documentation standards intentionally exempt that kind of symbol
- Security warnings for intentional patterns
- Style suggestions that conflict with project conventions

---

### CI/GitHub Actions

**Identification**:
- `github-actions[bot]` author
- Appears as check status, not review comment
- Contains workflow run information

**Handling**:
1. This is STATUS information, not review feedback
2. Use for determining if CI is passing
3. Do not treat as review comments to address
4. Check run failures should be fixed based on logs, not comment content

---

## Priority Ordering

When processing feedback, order by **CONTENT** (from priority-rules.md), then by blocking status:

> **Note**: Content priority (CRITICAL > HIGH > MEDIUM > LOW > NITPICK) always supersedes
> blocking status. A CRITICAL security issue from a bot is addressed before a NITPICK from
> a blocking human reviewer.

```
1. CRITICAL feedback (security, vulnerabilities) - ANY source
2. HIGH feedback (bugs, errors) - ANY source
3. MEDIUM feedback from BLOCKING reviews (human CHANGES_REQUESTED)
4. MEDIUM feedback from non-blocking sources - ANY source
5. LOW/NITPICK feedback - ANY source
6. CI status (separate from feedback)
```

---

## False Positive Detection

Before implementing bot suggestions, check:

- [ ] Does this contradict human reviewer feedback?
- [ ] Is this a known false positive pattern?
- [ ] Has a human already addressed this concern differently?
- [ ] Does this conflict with project conventions?

If YES to any, skip the bot suggestion with a note.

---

## Special Cases

### Code Owner Reviews

**Identification**:
- GitHub CODEOWNERS file defines ownership
- Review from designated owner for affected paths

**Handling**:
- Treat as HIGH priority even if just COMMENTED
- May be required for merge depending on branch protection
- Pay special attention to domain expertise

### External Contributor Reviews

**Identification**:
- Reviewer is not a team member
- May have limited context on project conventions

**Handling**:
- Evaluate suggestions on merit
- May need additional context before implementing
- Confirm with maintainer if suggestion is significant

---

## Output Format

When classifying source:

```
SOURCE_TYPE: [HUMAN|BOT|CI|CODE_OWNER]
SOURCE_NAME: [@username]
REVIEW_STATE: [CHANGES_REQUESTED|COMMENTED|APPROVED|N/A]
BLOCKING: [YES|NO]
CONTENT_PRIORITY: [CRITICAL|HIGH|MEDIUM|LOW|NITPICK] (from priority-rules.md)
FALSE_POSITIVE_RISK: [HIGH|MEDIUM|LOW|NONE] (bots only)
```

---

## Examples

```
@alice (CHANGES_REQUESTED): "Please add error handling"
→ SOURCE: HUMAN, BLOCKING: YES, CONTENT_PRIORITY: HIGH (bug prevention)

@copilot-pull-request-reviewer[bot]: "This input is not sanitized - potential SQL injection"
→ SOURCE: BOT, BLOCKING: NO, CONTENT_PRIORITY: CRITICAL (security)
→ Note: Address BEFORE human nitpicks - content priority trumps source

@copilot-pull-request-reviewer[bot]: "Consider adding type hints"
→ SOURCE: BOT, BLOCKING: NO, CONTENT_PRIORITY: NITPICK (style)
→ Note: Check if project uses type hints, may be false positive

@github-actions[bot]: "CI run completed"
→ SOURCE: CI, not feedback to address

@bob (COMMENTED): "nit: prefer snake_case here"
→ SOURCE: HUMAN, BLOCKING: NO, CONTENT_PRIORITY: NITPICK (style)
→ Note: Same priority as bot style suggestion - content determines priority
```
