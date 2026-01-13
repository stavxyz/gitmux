# Commit Messages

## When to Use

**EVERY git commit. No exceptions.**

## Quick Reference

```bash
# Standard format
git commit -m "type: brief description"

# With co-author
git commit -m "$(cat <<'EOF'
feat: add user authentication

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: stavxyz <hi@stav.xyz>
EOF
)"
```

## Commit Types

**Required prefix:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Add/update tests
- `refactor:` - Code restructuring (no behavior change)
- `style:` - Formatting, whitespace (no code change)
- `chore:` - Build, dependencies, tooling
- `perf:` - Performance improvement

## Patterns

### Pattern 1: Simple Commit

```bash
git commit -m "feat: add user login endpoint"
git commit -m "fix: resolve database connection timeout"
git commit -m "docs: update API documentation"
```

### Pattern 2: Multi-line with Context

```bash
git commit -m "$(cat <<'EOF'
feat: add user authentication system

Implements JWT-based authentication with refresh tokens.
Includes login, signup, and password reset endpoints.

Co-Authored-By: stavxyz <hi@stav.xyz>
EOF
)"
```

### Pattern 3: AI-Generated Commit

```bash
git commit -m "$(cat <<'EOF'
fix: resolve race condition in cache invalidation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: stavxyz <hi@stav.xyz>
EOF
)"
```

## AI Assistant Checklist

**When creating commits:**
- [ ] Use semantic prefix (feat:, fix:, docs:, etc.)
- [ ] Brief description (50 chars or less)
- [ ] Imperative mood: "add" not "added" or "adds"
- [ ] No period at end of subject line
- [ ] Include co-author for AI contributions
- [ ] Always use HEREDOC for multi-line messages

**Co-author format:**
```bash
Co-Authored-By: Name <email@example.com>
```

**AI-generated indicator:**
```bash
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Good vs Bad Examples

**Good:**
```bash
feat: add user authentication
fix: resolve login redirect loop
docs: update installation instructions
test: add integration tests for API
refactor: extract database logic to separate module
```

**Bad:**
```bash
# ❌ No type prefix
git commit -m "added authentication"

# ❌ Too vague
git commit -m "fix: fix bug"

# ❌ Past tense
git commit -m "feat: added user login"

# ❌ Too long subject
git commit -m "feat: add user authentication system with JWT tokens and refresh token rotation"

# ❌ Period at end
git commit -m "feat: add user authentication."
```

## HEREDOC Format

**Why use HEREDOC:**
- Handles multi-line messages correctly
- Preserves formatting
- No escaping issues
- Required for AI co-author attribution

**Template:**
```bash
git commit -m "$(cat <<'EOF'
type: brief description

Optional longer explanation of what changed and why.
Can include multiple paragraphs.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: stavxyz <hi@stav.xyz>
EOF
)"
```

## Commit Message Structure

```
type: brief description (50 chars max)
<blank line>
Optional detailed explanation (72 chars per line).
Can span multiple paragraphs.
<blank line>
🤖 Generated with [Claude Code](https://claude.com/claude-code)
<blank line>
Co-Authored-By: Name <email>
Co-Authored-By: Name <email>
```

## Type Selection Guide

**feat:** Wholly new functionality
```bash
feat: add user profile page
feat: implement password reset flow
```

**fix:** Correcting existing behavior
```bash
fix: resolve database connection leak
fix: handle null values in user query
```

**docs:** Documentation only (no code changes)
```bash
docs: update API endpoint documentation
docs: add architecture decision record
```

**refactor:** Restructure code (same behavior)
```bash
refactor: extract authentication logic
refactor: simplify error handling
```

**test:** Add/modify tests only
```bash
test: add unit tests for user service
test: add integration tests for API
```

**chore:** Tooling, dependencies, build
```bash
chore: update dependencies
chore: configure prettier
```

## Common Workflows

### Workflow 1: Single File Change

```bash
git add src/auth.py
git commit -m "feat: add JWT token validation"
```

### Workflow 2: Multiple Related Changes

```bash
git add src/auth.py src/models.py tests/test_auth.py
git commit -m "feat: add user authentication system"
```

### Workflow 3: Bug Fix with Context

```bash
git commit -m "$(cat <<'EOF'
fix: resolve race condition in cache invalidation

The cache was being invalidated before the database
transaction completed, causing stale data reads.

Now waits for transaction commit before invalidation.
EOF
)"
```

## Gotchas

**"Commit message too short"**
- Add meaningful description
- Minimum: type + description

**"Lost multi-line formatting"**
- Use HEREDOC format
- Don't use multiple `-m` flags

**"Co-author not showing"**
- Blank line before Co-Authored-By
- Exact format: `Co-Authored-By: Name <email>`

## View Commit History

```bash
# View recent commits
git log --oneline

# View with stats
git log --stat

# View specific file history
git log --follow src/auth.py

# Search commits
git log --grep="authentication"
```

## Amending Commits

```bash
# Fix last commit message
git commit --amend -m "new message"

# Add to last commit
git add forgotten-file.py
git commit --amend --no-edit
```

**WARNING:** Only amend commits that haven't been pushed!

## Related

- **Pull Request Workflow:** [git/pull-request-workflow.md](pull-request-workflow.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** Use semantic commit format (type: description) with co-authors for AI contributions. Always use HEREDOC for multi-line messages.
