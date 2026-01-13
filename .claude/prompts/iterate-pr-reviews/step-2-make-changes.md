# Step 2: Make Changes

## Priority Order

1. Fix status check failures (CI must pass)
2. Address critical human review feedback
3. Fix status check warnings (even if check passed)
4. Address high/medium human review feedback
5. Address low-priority feedback and nitpicks

## For Each Actionable Item

1. **Understand context**: Read relevant files completely
2. **Plan the fix**: Think through implications
3. **Make changes**: Use Edit or Write tools
4. **Verify locally if possible**:
   - Run tests: `pytest tests/ -v`
   - Run linters: `ruff check --fix .`
   - Run formatters: `ruff format .`
   - Run type checker: `mypy src/`
5. **Follow principles**:
   - Strive for elegance, not bloat
   - Anticipate edge cases
   - Design for testability
   - Avoid anti-patterns
   - Think ahead - what could break?

## Status Check Fixes

- Read full error output from logs
- Fix root cause, not just symptoms
- Ensure tests pass locally before pushing
- Address warnings even if not critical

---

## Commit and Push

Create a well-structured commit:

```bash
git add <changed-files>

git commit -m "$(cat <<'EOF'
<type>: <brief summary>

Addresses review feedback:
- <specific comment 1> - <what you did>
- <specific comment 2> - <what you did>

<optional additional context>

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: stavxyz <{CO_AUTHOR_EMAIL}>
EOF
)"

git push
```

## Commit Message Guidelines

- Type: fix, feat, refactor, test, docs, style
- Reference specific review comments when possible
- Explain WHY, not just WHAT
- Keep under 72 characters for summary
