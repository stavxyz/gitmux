# PR Titles and Descriptions

**When to use:** Every pull request
**Key principle:** Clear communication of what changed and why
**Critical:** Good PR descriptions accelerate reviews

---

## PR Title Format

### Semantic Prefix Format

Use semantic prefixes to categorize changes:

```
<type>: <concise description>
```

### Available Prefixes

| Prefix | When to Use | Example |
|--------|-------------|---------|
| `feat:` | New feature or functionality | `feat: add user authentication` |
| `fix:` | Bug fix | `fix: resolve memory leak in parser` |
| `docs:` | Documentation only | `docs: update API documentation` |
| `refactor:` | Code restructuring (no behavior change) | `refactor: extract validation logic` |
| `test:` | Test additions or changes | `test: add unit tests for API client` |
| `chore:` | Maintenance tasks | `chore: update dependencies` |
| `perf:` | Performance improvements | `perf: optimize database queries` |
| `style:` | Code style/formatting | `style: apply ruff formatting` |
| `ci:` | CI/CD changes | `ci: add GitHub Actions workflow` |
| `build:` | Build system changes | `build: update webpack config` |
| `revert:` | Revert previous commit | `revert: revert "add feature X"` |

### Title Best Practices

**Good titles:**
- ✅ `feat: add JWT authentication to API`
- ✅ `fix: resolve race condition in data processing`
- ✅ `docs: add examples to authentication guide`
- ✅ `refactor: split large parser module into submodules`

**Bad titles:**
- ❌ `Update code` (too vague)
- ❌ `Fix bug` (which bug?)
- ❌ `Changes` (what changes?)
- ❌ `feat: add feature, fix bugs, update docs` (too many things)

**Guidelines:**
- Be concise but descriptive (50-72 characters ideal)
- Use imperative mood ("add" not "added" or "adds")
- Don't end with period
- One primary change per PR (one prefix)
- If multiple changes, consider splitting into separate PRs

---

## PR Description Structure

### Basic Template

```markdown
## Description

[Clear explanation of what this PR does]

### What Changed
[Bullet points of specific changes]

### Why
[Motivation for these changes]

### Related Issues
Fixes #123
Relates to #456
```

### Comprehensive Template

```markdown
## Description

[1-3 sentence summary of the changes]

### What Changed
- [Specific change 1]
- [Specific change 2]
- [Specific change 3]

### Why
[Explain the problem being solved or feature being added]
[Provide context and motivation]

### How
[For complex changes, explain the approach taken]
[Mention any alternatives considered]

### Related Issues
Fixes #123
Relates to #456

---

## Documentation Checklist

- [x] Code changes have corresponding doc updates
- [x] README updated (if user-facing)
- [x] API docs updated (if endpoints changed)
- [x] Docstrings added/updated
- [x] Comments added for complex logic
- [ ] No documentation needed (explain below)

---

## Breaking Changes

[If applicable, describe breaking changes and migration path]

---

## Testing

**Tests run:**
- `pytest tests/ -v` ✅
- `pytest tests/ --cov=src` ✅ (87% coverage)

**Manual testing:**
- Tested authentication flow with valid/invalid tokens
- Verified error handling for edge cases

---

## Screenshots

[For UI changes, include before/after screenshots]

---

## Additional Context

[Any other relevant information for reviewers]
```

---

## Good vs Bad Descriptions

### Example 1: New Feature

**❌ Bad:**
```markdown
## Description

Added authentication

Fixes #123
```

**✅ Good:**
```markdown
## Description

Implement JWT-based authentication for API endpoints.

### What Changed
- Add JWT token generation and validation
- Create `/auth/login` and `/auth/refresh` endpoints
- Add authentication middleware for protected routes
- Update API documentation with authentication examples
- Add docstrings to all new authentication functions

### Why
Users need secure authentication to access protected resources. JWT tokens
provide stateless authentication without server-side session storage, which
improves scalability and simplifies deployment.

### How
- Use `pyjwt` library for token generation/validation
- Tokens expire after 1 hour, refresh tokens valid for 7 days
- Passwords hashed with bcrypt (12 rounds)
- Middleware validates token on each protected request

### Related Issues
Fixes #123
Relates to #124 (will enable role-based access control)

---

## Documentation Checklist

- [x] README updated with authentication setup guide
- [x] API docs updated with auth endpoints
- [x] All functions have docstrings
- [x] Added comments for token validation logic

---

## Testing

**Tests run:**
- `pytest tests/ -v` ✅ (all 127 tests passing)
- `pytest tests/ --cov=src` ✅ (91% coverage, up from 85%)

**Manual testing:**
- Tested login with valid credentials → Success
- Tested login with invalid credentials → 401 error
- Tested protected endpoint without token → 401 error
- Tested protected endpoint with valid token → Success
- Tested protected endpoint with expired token → 401 error
- Tested token refresh flow → Success

---

## Breaking Changes

**None**. New functionality only, all existing endpoints unchanged.
```

### Example 2: Bug Fix

**❌ Bad:**
```markdown
## Description

Fixed the bug

Fixes #456
```

**✅ Good:**
```markdown
## Description

Fix race condition causing intermittent data corruption in concurrent processing.

### What Changed
- Add mutex lock to `DataProcessor.process_batch()`
- Update docstring to document thread-safety guarantees
- Add integration test for concurrent processing
- Add comment explaining lock acquisition order

### Why
In production, multiple workers process batches concurrently. Without proper
locking, two workers could read and modify the same batch state simultaneously,
leading to corrupted output. This manifested as ~1% of batches having invalid
checksums.

### How
- Acquire `batch_lock` before reading batch state
- Hold lock during entire processing operation
- Release lock in finally block to ensure cleanup
- Lock is per-batch, so different batches can still process concurrently

### Root Cause
Originally assumed batch processing was single-threaded. When we added
multi-worker support in v2.0, we didn't add proper synchronization.

### Related Issues
Fixes #456
Fixes #457 (duplicate report of same issue)

---

## Documentation Checklist

- [x] Updated docstring to document thread-safety
- [x] Added comment explaining locking strategy
- [x] No README/API doc changes needed (internal fix)

---

## Testing

**Tests run:**
- `pytest tests/ -v` ✅
- `pytest tests/test_concurrent_processing.py -v` ✅ (new test, runs 100 iterations)

**Manual testing:**
- Ran stress test with 50 concurrent workers for 1 hour
- Processed 10,000 batches with 0 checksum failures
- Before fix: ~100 failures in same test

---

## Breaking Changes

**None**. Same API, just fixed behavior.
```

### Example 3: Documentation Only

**❌ Bad:**
```markdown
## Description

Updated docs
```

**✅ Good:**
```markdown
## Description

Improve authentication documentation with step-by-step setup guide and examples.

### What Changed
- Add "Authentication Setup" section to README with numbered steps
- Fix typos in API documentation (authetication → authentication)
- Add code examples for login, token refresh, and protected requests
- Add troubleshooting section for common auth issues
- Update architecture docs to explain JWT flow with diagram

### Why
User feedback indicated authentication setup was confusing. Issue #789 reported
3 common misconfigurations. This update addresses all reported pain points.

### Related Issues
Fixes #789 (confusion about auth setup)
Fixes #790 (missing code examples)

---

## Documentation Checklist

- [x] README updated with step-by-step guide
- [x] API docs fixed and enhanced
- [x] Architecture docs updated with flow diagram
- [x] No code changes (docs only)

---

## Screenshots

![Authentication flow diagram](https://...)
![README before/after comparison](https://...)
```

---

## Breaking Changes Documentation

When PR includes breaking changes:

```markdown
## ⚠️ BREAKING CHANGES

### What Breaks

**Old API:**
```python
result = process_data(data, validate=True)
```

**New API:**
```python
from myproject.validators import SchemaValidator

result = process_data(
    data,
    validator=SchemaValidator()  # Required parameter now
)
```

### Why Breaking

The old `validate=True` boolean was too simplistic. It only checked basic
types, not business rules. New validator system allows custom validation logic.

### Migration Guide

**Step 1:** Install validation package
```bash
pip install myproject[validators]
```

**Step 2:** Update code
```python
# Old (will fail)
result = process_data(data, validate=True)

# New (required)
from myproject.validators import SchemaValidator

validator = SchemaValidator.from_file("schema.json")
result = process_data(data, validator=validator)
```

**Step 3:** Create schema file (if using SchemaValidator)
```json
{
  "columns": ["id", "name", "email"],
  "types": {"id": "int", "name": "str", "email": "str"}
}
```

### Deprecation Timeline

- v2.0: Old API removed (this PR)
- v1.9: Old API deprecated, warnings issued
- v1.8: New API introduced alongside old API

### Alternatives Considered

- Keep both APIs → Too complex, confusing for users
- Make validator optional → Would allow invalid data through
- Auto-detect validation → Too implicit, hard to debug
```

---

## Tips for Writing Good Descriptions

### For the "What Changed" Section

- List specific, concrete changes
- Use bullet points for readability
- Group related changes together
- Include both code and documentation changes

### For the "Why" Section

- Explain the problem being solved
- Provide business context
- Mention user impact
- Reference data/metrics if available

### For the "How" Section

- Explain approach for complex changes
- Mention design decisions
- Note alternatives considered
- Highlight trade-offs made

### For the "Testing" Section

- List all test commands run
- Show test results (pass/fail, coverage)
- Describe manual testing performed
- Include edge cases tested

---

## PR Description Checklist

Before submitting PR, verify:

- [ ] Title uses semantic prefix (`feat:`, `fix:`, etc.)
- [ ] Title is concise but descriptive
- [ ] Description explains "what" and "why"
- [ ] All specific changes listed
- [ ] Documentation checklist completed
- [ ] Breaking changes documented (if any)
- [ ] Test results included
- [ ] Related issues linked
- [ ] Screenshots included (for UI changes)

---

## Common Mistakes

### Mistake: Vague descriptions

❌ **Bad:**
"Made some changes to improve things"

✅ **Good:**
"Optimize database queries by adding indexes on user_id and created_at columns, reducing average query time from 2s to 200ms"

### Mistake: Only "what", no "why"

❌ **Bad:**
"Added caching layer to API"

✅ **Good:**
"Added Redis caching layer to API to reduce database load and improve response times. API was timing out during peak hours (>1000 req/min) due to repeated expensive queries."

### Mistake: Missing documentation updates

❌ **Bad:**
Changes code, forgets to update docs

✅ **Good:**
Updates code, docs, and docstrings in same commit; notes it in PR checklist

### Mistake: Combining unrelated changes

❌ **Bad:**
"feat: add authentication, fix bug in parser, update dependencies"

✅ **Good:**
Separate PRs:
- `feat: add authentication`
- `fix: resolve parser memory leak`
- `chore: update dependencies`

---

## Related Documentation

- **Commit Messages**: `.claude/knowledge/git/commit-messages.md`
- **Pull Request Workflow**: `.claude/knowledge/git/pull-request-workflow.md`
- **Documentation Guide**: `.claude/knowledge/documentation/keeping-docs-updated.md`
- **Engineering Standards**: `.claude/docs/ENGINEERING_STANDARDS.md`

---

**Status**: Knowledge entry for PR titles and descriptions. Updated: 2026-01-07
