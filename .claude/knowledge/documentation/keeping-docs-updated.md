# Keeping Documentation Updated

**When to use:** Every code change
**Key principle:** Document as you code, not after
**Critical:** Documentation is not optional

---

## Why Documentation Matters

Documentation prevents:
- Knowledge loss when developers leave
- Confusion for new contributors
- Wasted time figuring out how things work
- Bugs from misunderstanding code intent
- AI assistants making incorrect assumptions

Documentation enables:
- Faster onboarding of new team members
- Better code reviews
- Easier maintenance and debugging
- Effective AI-assisted development
- Confident refactoring

---

## When Documentation is Required

### Always Required

- **New public APIs/functions/classes**
  - Add docstrings with parameters, returns, exceptions
  - Update API documentation if external-facing
  - Add usage examples for complex APIs

- **Changed function signatures**
  - Update docstrings to reflect new parameters
  - Update any documentation that shows usage
  - Add migration notes if breaking change

- **New user-facing features**
  - Update README with feature description
  - Add usage examples and screenshots
  - Document configuration options
  - Update CHANGELOG if maintained

- **Breaking changes**
  - Document what breaks and why
  - Provide migration guide
  - Update all affected documentation
  - Mark clearly in PR description

- **Complex logic or algorithms**
  - Add inline comments explaining WHY
  - Document any non-obvious optimizations
  - Explain business logic rationale
  - Add references to algorithms if applicable

### Sometimes Required

- **Bug fixes**
  - If behavior changes noticeably: Update docs
  - If fix is non-obvious: Add comment explaining
  - If user-visible: Update README/docs

- **Refactoring**
  - If API changes: Update docs
  - If usage pattern changes: Update examples
  - If architecture changes: Update architecture docs

- **Performance optimizations**
  - If user-visible: Document improvements
  - If changes usage patterns: Update docs
  - If introduces complexity: Add comments

### Not Required (but docstrings still are)

- **Internal-only changes**
  - Still need docstrings on functions
  - May need inline comments for complex parts
  - External docs usually don't need updates

- **Test-only changes**
  - Tests should be self-documenting
  - May need comments for complex test setups

- **Trivial fixes**
  - Typos in code (not docs)
  - Whitespace or formatting
  - Simple one-line fixes

---

## Types of Documentation

### 1. Inline Documentation

**Docstrings** (required for all functions):

```python
def validate_data(
    data: pd.DataFrame,
    schema: Schema,
    strict: bool = False
) -> ValidationResult:
    """Validate dataframe against schema.

    Args:
        data: DataFrame to validate
        schema: Schema defining expected structure and types
        strict: If True, fail on any warnings (not just errors)

    Returns:
        ValidationResult with errors, warnings, and validation status

    Raises:
        SchemaError: If schema is invalid
        ValueError: If data is empty

    Example:
        >>> schema = Schema.from_file("schema.json")
        >>> result = validate_data(df, schema)
        >>> if result.is_valid:
        ...     print("Data is valid!")
    """
    ...
```

**Code comments** (for complex logic):

```python
# Use binary search instead of linear scan for large datasets
# Assumes data is sorted by timestamp (enforced in data loading)
index = bisect_left(sorted_data, target_value)
```

### 2. External Documentation

**README.md:**
- Project overview and purpose
- Installation/setup instructions
- Quick start guide
- Common usage examples
- Links to detailed documentation

**docs/api.md:**
- API endpoint descriptions
- Request/response formats
- Authentication requirements
- Error codes and handling
- Code examples for each endpoint

**docs/architecture.md:**
- System design overview
- Key design decisions and rationale
- Component interaction diagrams
- Data flow explanations
- Technology choices

**CHANGELOG.md:**
- What changed in each version
- Breaking changes and migrations
- Bug fixes and improvements
- Deprecated features

### 3. PR Documentation

**PR Title:**
- Use semantic prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Be concise but descriptive
- Example: `feat: add JWT authentication to API`

**PR Description:**
- **What**: Describe the changes made
- **Why**: Explain the motivation/problem solved
- **How**: For complex changes, explain the approach
- **Breaking Changes**: Call out anything that breaks
- **Testing**: Describe how you tested

---

## Documentation Workflow

### Step 1: Before Coding

Identify what documentation exists:

```bash
# Read existing docs to understand current state
cat README.md
ls docs/
grep -r "function_name" docs/  # Find references to what you're changing
```

### Step 2: While Coding

Update documentation as you write code:

```python
# ✅ GOOD: Add docstring immediately when writing function
def new_feature(param: str) -> Result:
    """Process new feature request.

    Args:
        param: Feature parameter

    Returns:
        Result of processing
    """
    # Add comments for complex logic as you write it
    # This ensures you document while context is fresh
    ...
```

### Step 3: After Coding

Update external documentation:

```bash
# Update README if user-facing
Edit README.md  # Add usage section

# Update API docs if endpoints changed
Edit docs/api.md  # Document new endpoint

# Update architecture docs if design changed
Edit docs/architecture.md  # Explain new pattern
```

### Step 4: Before Committing

Verify documentation is complete:

```bash
# Checklist:
# [ ] All new functions have docstrings
# [ ] Complex logic has comments
# [ ] README updated (if user-facing)
# [ ] API docs updated (if endpoints changed)
# [ ] Architecture docs updated (if design changed)
# [ ] CHANGELOG updated (if maintained)

# Commit code and docs together
git add src/ docs/ README.md
git commit -m "feat: add user authentication

- Implement JWT-based auth
- Add login/refresh endpoints
- Update API docs with auth examples
- Add authentication section to README

Co-Authored-By: Name <email>"
```

### Step 5: In PR

Complete the documentation checklist in PR template.

---

## Common Patterns

### Pattern: New Feature

```bash
# 1. Write feature code with docstrings
Edit src/features/new_feature.py

# 2. Update README with usage
Edit README.md  # Add "Using the New Feature" section

# 3. Update API docs if applicable
Edit docs/api.md  # Document new endpoints

# 4. Add examples
Edit examples/new_feature_example.py

# 5. Commit together
git add src/features/ README.md docs/ examples/
git commit -m "feat: add new feature with full documentation"
```

### Pattern: Bug Fix

```bash
# 1. Fix bug and update docstring if behavior changed
Edit src/module.py

# 2. Add comment explaining fix if non-obvious
# Example: "# Fix race condition by acquiring lock before read"

# 3. Update README only if user-visible fix
Edit README.md  # If necessary

# 4. Commit
git commit -m "fix: resolve race condition in data processing

Added mutex lock to prevent concurrent access to shared state.
This fixes intermittent data corruption issues."
```

### Pattern: Refactoring

```bash
# 1. Refactor code, update docstrings
Edit src/module.py

# 2. Update architecture docs if patterns changed
Edit docs/architecture.md

# 3. Update examples if usage changed
Edit examples/

# 4. Verify all docs still accurate
grep -r "old_function_name" docs/  # Find stale references

# 5. Commit
git commit -m "refactor: extract data validation into separate service

Improves testability and separation of concerns.
Updated architecture docs to reflect new service layer."
```

### Pattern: Documentation-Only

```bash
# 1. Fix or improve documentation
Edit README.md docs/api.md

# 2. Use docs: prefix
git commit -m "docs: clarify authentication setup instructions

Added step-by-step guide with examples.
Fixed typos in API documentation."
```

---

## Documentation Quality Checklist

### Good Documentation

- ✅ **Accurate**: Matches current code behavior exactly
- ✅ **Clear**: Easy to understand for target audience
- ✅ **Concise**: No unnecessary verbosity
- ✅ **Complete**: Covers all important aspects
- ✅ **Current**: Updated with every code change
- ✅ **Examples**: Shows real usage patterns
- ✅ **Searchable**: Uses good keywords and titles

### Bad Documentation

- ❌ Outdated (doesn't match code)
- ❌ Unclear or confusing
- ❌ Too verbose or too brief
- ❌ Missing critical information
- ❌ No examples
- ❌ Written after the fact (often incomplete)

---

## Tips for AI Assistants

When working on code changes:

1. **Read docs first**: Use Read tool to check existing documentation
2. **Update together**: Make doc changes in same commit as code
3. **Complete checklist**: Fill out PR template documentation checklist
4. **Write docstrings**: Add them as you write functions, not after
5. **Explain complex logic**: Add comments for non-obvious code
6. **Check for stale docs**: Search for references to changed functions

### Example AI Workflow

```
User: "Add a function to calculate user statistics"

AI: Let me first read existing documentation to understand patterns
[Reads README.md, docs/api.md]

AI: [Writes function with complete docstring]
AI: [Updates README.md with usage example]
AI: [Updates docs/api.md if function is part of API]
AI: [Commits code + docs together]
AI: [Notes in PR that docs were updated]
```

---

## Common Mistakes

### Mistake: "I'll document it later"

❌ **Wrong approach:**
```python
# TODO: Add documentation
def process_data(data):
    # Complex logic here
    ...
```

✅ **Right approach:**
```python
def process_data(data: pd.DataFrame) -> ProcessedData:
    """Process raw data into structured format.

    Args:
        data: Raw input dataframe

    Returns:
        ProcessedData with cleaned and validated results
    """
    # Use vectorized operations for performance on large datasets
    ...
```

### Mistake: Docs in separate commit

❌ **Wrong approach:**
```bash
git commit -m "feat: add authentication"
# ... later ...
git commit -m "docs: document authentication"  # Separate commit
```

✅ **Right approach:**
```bash
git add src/ docs/ README.md
git commit -m "feat: add authentication

- Implement JWT authentication
- Update API docs with auth endpoints
- Add authentication section to README"
```

### Mistake: Assuming docs are optional

❌ **Wrong approach:**
"It's just a small change, no docs needed"

✅ **Right approach:**
"Even small changes may need docs. Let me check:
- Is it user-facing? → Update README
- Does it change an API? → Update API docs
- Is it complex? → Add comments
- Is it a new function? → Add docstring (always required)"

---

## Related Documentation

- **Critical Rules**: `.claude/docs/CLAUDE_CODE_RULES.md` (Rule #11: Documentation Updates)
- **Engineering Standards**: `.claude/docs/ENGINEERING_STANDARDS.md` (Documentation Requirements section)
- **PR Workflow**: `.claude/knowledge/git/pull-request-workflow.md`
- **Commit Messages**: `.claude/knowledge/git/commit-messages.md`

---

**Status**: Core knowledge entry for documentation practices. Updated: 2026-01-07
