# Focused Prompts

## When to Use

**Communicating effectively with Claude Code.**

## Quick Reference

**Good prompts:**
- Be specific about what you want
- Reference file paths when relevant
- Provide context about why
- Include expected outcome

**Bad prompts:**
- Vague: "fix this"
- No context: "update the function"
- Too broad: "make it better"

## Why This Matters

- **Efficiency:** Clear prompts get better results faster
- **Accuracy:** Specific requests reduce misunderstandings
- **Quality:** Context helps Claude make better decisions
- **Speed:** Less back-and-forth clarification

## Patterns

### Pattern 1: Specific File Reference

```
✅ Good:
"Add type hints to the login() function in src/auth.py"

❌ Bad:
"Add type hints"
```

### Pattern 2: Clear Goal with Context

```
✅ Good:
"Refactor the database connection logic in src/db.py to use a connection pool. Currently it creates a new connection for each query which is causing performance issues."

❌ Bad:
"Make the database faster"
```

### Pattern 3: Expected Outcome

```
✅ Good:
"Add a test in tests/unit/test_auth.py that verifies login() raises ValueError when given an empty password"

❌ Bad:
"Add some tests for auth"
```

### Pattern 4: Constraints Included

```
✅ Good:
"Update the README.md installation section to use Python 3.11+. Keep the existing structure and don't change other sections."

❌ Bad:
"Update README"
```

## Effective Prompt Structure

### Structure 1: Request + Location + Context

```
<What you want> + <Where it is> + <Why/context>

Examples:
"Extract the validation logic from src/models.py into a new src/validators.py file. The validation is getting complex and should be separated for maintainability."

"Add error handling to the API call in src/client.py. Currently when the API is down, the app crashes instead of showing a user-friendly error."
```

### Structure 2: Problem + Desired Solution

```
<Current problem> + <What you want instead>

Examples:
"The tests in tests/integration/test_api.py are failing with a database connection error. Please fix them to use a test database fixture."

"The sync tool is slow when processing large directories. Optimize it to skip __pycache__ and .git directories."
```

### Structure 3: Task + Constraints + Acceptance Criteria

```
<What to do> + <Limits/rules> + <How to verify success>

Examples:
"Add a new command /analyze-code that shows code complexity metrics. It should work with Python files only and output to stdout. Success means I can run it on src/ and see cyclomatic complexity scores."

"Implement user authentication in src/auth.py using JWT tokens. Must follow the existing project patterns in src/database.py. Tests must pass and coverage must stay above 80%."
```

## Prompt Types

### Type 1: Implementation Request

```
"Implement a password reset flow in src/auth.py with the following:
- Function reset_password(email: str) -> bool
- Send reset token via email
- Token expires in 1 hour
- Use existing email_service from src/email.py"
```

### Type 2: Bug Fix

```
"Fix the bug in src/utils.py:45 where parse_date() raises AttributeError on None input. It should return None instead of crashing."
```

### Type 3: Refactoring

```
"Refactor src/handlers.py to extract the duplicate error handling code into a decorator. The pattern appears in handle_create(), handle_update(), and handle_delete()."
```

### Type 4: Testing

```
"Add unit tests for the User model in src/models.py. Focus on:
- Valid user creation
- Email validation
- Password hashing
- Edge cases (empty strings, None values)"
```

### Type 5: Documentation

```
"Update the docstring for calculate_score() in src/scoring.py to explain:
- What the score represents
- Valid input ranges
- Return value meaning
- Example usage"
```

### Type 6: Exploration

```
"Show me all functions in the codebase that make database queries. I want to audit them for N+1 query issues."
```

## Reference Techniques

### File Paths with Line Numbers

```
"Fix the type error at src/auth.py:127"
"Explain the logic in src/database.py:45-67"
"Why is src/utils.py:89 raising an exception?"
```

### Project Context

```
"Following the pattern used in src/handlers/user.py, implement a similar handler for posts in src/handlers/post.py"

"Use the same error handling approach as src/api/errors.py"
```

### External References

```
"Implement JWT authentication following the example at https://jwt.io/introduction"

"Add logging like the Python logging cookbook shows"
```

## AI Assistant Checklist

**For implementation requests:**
- [ ] Specify exact file paths
- [ ] Include function/class names
- [ ] Provide context about existing code
- [ ] Mention any patterns to follow
- [ ] State expected behavior

**For bug fixes:**
- [ ] Describe current behavior
- [ ] Describe expected behavior
- [ ] Include error messages if any
- [ ] Reference file:line if known
- [ ] Suggest potential causes if known

**For refactoring:**
- [ ] Explain what's wrong with current code
- [ ] Describe desired structure
- [ ] Mention patterns to use
- [ ] Note any constraints
- [ ] Specify if tests should be updated

## Example Conversations

### Good Conversation Flow

```
User: "Add user authentication to the API"

Claude: "I'll help with authentication. A few questions:
- Which authentication method? (JWT, sessions, API keys)
- Where should I add this? (new file or existing?)
- Any specific requirements? (token expiration, refresh tokens?)"

User: "JWT tokens in a new src/auth.py file. Tokens expire in 1 hour with refresh tokens that last 7 days."

Claude: "Perfect! I'll implement JWT authentication with:
- src/auth.py with login/refresh endpoints
- 1-hour access tokens
- 7-day refresh tokens
- Tests in tests/unit/test_auth.py
Creating now..."
```

### Bad Conversation Flow

```
User: "Make it work"

Claude: "I need more information. What specifically should I fix?"

User: "You know, the thing"

Claude: "I don't have enough context. Can you provide:
- What file/function has the issue?
- What error are you seeing?
- What should the correct behavior be?"
```

## Context Sharing

### Share Code Snippets

```
"This function is failing:

```python
def process(data):
    result = data.split()
    return result[0]
```

It crashes when data is None. Fix it to handle None gracefully."
```

### Share Error Messages

```
"Getting this error when running tests:

```
AttributeError: 'NoneType' object has no attribute 'split'
  File "src/utils.py", line 45, in process_data
```

Please fix the None handling in process_data()."
```

### Share Expected vs Actual

```
"The function calculate_total() in src/billing.py is returning 105.0 but I expect 100.0 for the input [25, 25, 25, 25]. Please investigate and fix."
```

## Common Prompting Mistakes

### Mistake 1: Too Vague

```
❌ "Fix the bug"
✅ "Fix the AttributeError in src/utils.py:45 where split() is called on None"
```

### Mistake 2: No Location

```
❌ "Add error handling"
✅ "Add try/except to the API call in src/client.py:67"
```

### Mistake 3: No Context

```
❌ "Make it faster"
✅ "Optimize the loop in src/processor.py:112-145. It's currently O(n²) and slow for large datasets."
```

### Mistake 4: Asking Multiple Unrelated Things

```
❌ "Fix the bug, add tests, update docs, and refactor the database code"
✅ "Fix the bug in src/auth.py:45" (then in next prompt:) "Now add tests for that fix"
```

### Mistake 5: No Success Criteria

```
❌ "Improve the tests"
✅ "Increase test coverage for src/auth.py from 60% to 80% by adding edge case tests"
```

## Advanced Techniques

### Technique 1: Provide Examples

```
"Add a new API endpoint for deleting users. Follow the same pattern as the create_user endpoint in src/api/users.py:25-40."
```

### Technique 2: Reference Standards

```
"Add type hints to all functions in src/models.py following our type hints standard in .claude/docs/ENGINEERING_STANDARDS.md"
```

### Technique 3: Incremental Requests

```
1. "First, show me where database queries happen in the codebase"
2. (after response) "Now optimize the query in src/handlers/user.py:89"
3. (after response) "Add a test to verify the optimization works"
```

### Technique 4: Clarifying Questions

```
User: "Add caching"

Claude: "Where should I add caching? Options:
1. Database query results in src/database.py
2. API responses in src/api/handlers.py
3. Computed values in src/utils.py"

User: "Option 1, cache database queries"
```

## Gotchas

**"Claude did something different than expected"**
- Prompt was too vague
- Missing context about existing patterns
- No example provided

**"Claude asks too many clarifying questions"**
- Provide more upfront context
- Reference specific files/functions
- Include expected outcome

**"Claude modified wrong file"**
- Always specify exact file path
- Use file:line notation when relevant
- Reference project structure

**"Claude's solution doesn't match project style"**
- Reference existing patterns
- Point to similar code to follow
- Mention style guide location

## Related

- **Permissions:** [claude-code/permissions.md](permissions.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** Be specific. Reference files. Provide context. State expected outcome. Clear prompts = better results.
