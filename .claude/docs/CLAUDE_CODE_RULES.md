# Critical Rules for AI Assistants

> **NON-NEGOTIABLE**: These rules MUST be followed without exception.
> Violating these standards is a critical error.

---

## 1. NEVER Push Directly to Main Branch

**ALWAYS use pull requests. NEVER push to main/master.**

### Prohibited Commands

```bash
# ❌ NEVER do this
git push origin main
git commit && git push  # when on main branch
```

### Required Workflow

```bash
# ✅ ALWAYS do this
git checkout -b feature/my-change
# Make changes
git add .
git commit -m "feat: description

Co-Authored-By: Claude <noreply@anthropic.com>
Co-Authored-By: stavxyz <hi@stav.xyz>"
git push -u origin feature/my-change
gh pr create
```

### AI Assistant Requirements

**Before pushing any code:**
- [ ] Check current branch: `git branch --show-current`
- [ ] If on main/master: STOP and create feature branch first
- [ ] Never use `git push` when on main branch
- [ ] Always create PR, never merge directly
- [ ] Include proper commit message with co-authors

**Recovery if accidentally on main:**
```bash
# If you realize you're on main
git checkout -b feature/fix-name
# Continue work on feature branch
```

---

## 2. NEVER Modify System Python

**ALWAYS use virtual environments. NEVER install packages globally.**

### Automatic Virtual Environment Activation

**Claude Code automatically detects and activates virtual environments:**

- ✅ Activates at session start (no manual intervention needed)
- ✅ Creates `~/.virtualenvs/<project-name>` if none exists
- ✅ Falls back to `.venv` if it exists
- ✅ Respects direnv and manual activations
- ✅ Blocks pip operations if no venv active (safety hook)

**See:** `.claude/docs/VIRTUAL_ENVIRONMENT_SETUP.md` for details

### Prohibited Commands

```bash
# ❌ NEVER run these - they corrupt user's system
pip install <package>                      # Blocked by safety hook
python3 -m pip install --user <package>    # Blocked by safety hook
sudo pip install <package>                 # Prohibited
pip3 install <package>                     # Blocked by safety hook
```

### Required Workflow

```bash
# ✅ Automatic activation (preferred)
# Session starts → venv auto-activated
pip install -r requirements.txt  # Just works!

# ✅ Manual activation (if needed)
source ~/.virtualenvs/my-project/bin/activate  # Named venv
# or
source .venv/bin/activate                      # Local venv

# Now safe to install
pip install -r requirements.txt
```

### AI Assistant Requirements

**Virtual environment is automatically activated, but verify:**
- [ ] Check if venv active: `which python`
- [ ] Verify output shows venv path (not system Python)
- [ ] If not active: Session hook failed, investigate why
- [ ] NEVER use `--user` flag
- [ ] NEVER use `sudo pip`
- [ ] NEVER disable safety hook without good reason

**Safety hook will block unsafe operations:**
- If venv not active, pip install/uninstall will fail with clear error
- Disable only if intentional: `export CLAUDE_VENV_SAFETY_HOOK=false`

---

## 3. File Operations

**Read before write. Verify paths exist.**

### Requirements

- [ ] Use Read tool before Edit/Write on existing files
- [ ] Verify file paths with Glob before operations
- [ ] Check directory exists before creating files
- [ ] Preserve exact indentation when editing

### Pattern

```bash
# 1. Read first
Read file_path

# 2. Then edit
Edit file_path old_string new_string

# Or write for new files (but prefer Edit for existing)
Write file_path content
```

---

## 4. Testing

**Run tests before committing. Verify changes don't break existing functionality.**

### Requirements

- [ ] Run `pytest tests/ -v` before every commit
- [ ] Fix failing tests immediately
- [ ] Don't commit if tests fail (unless explicitly acceptable)
- [ ] Check coverage for new code

### Commands

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=src

# Run specific test file
pytest tests/unit/test_file.py -v

# Skip slow tests
pytest -m "not e2e"
```

---

## 5. Code Quality

**Run linting and formatting before committing.**

### Requirements

- [ ] Run `ruff check --fix` before commit
- [ ] Run `ruff format` before commit
- [ ] Run `mypy src/` for type checking
- [ ] Fix all errors before pushing

### Commands

```bash
# Lint and auto-fix
ruff check --fix src/ tests/

# Format code
ruff format src/ tests/

# Type check
mypy src/

# All in sequence
ruff check --fix . && ruff format . && mypy src/ && pytest tests/
```

---

## 6. Structured Logging

**Use logging, never print().**

### Prohibited

```python
# ❌ NEVER use print() for logging
print(f"Processing {item_id}")
print("Error:", error)
```

### Required

```python
# ✅ ALWAYS use structured logging
import structlog

logger = structlog.get_logger()

logger.info("item_processing_started", item_id=item_id)
logger.error("processing_failed", item_id=item_id, error=str(error))
```

---

## 7. Type Hints

**All functions require type hints.**

### Requirements

- [ ] Function parameters have types
- [ ] Return types specified
- [ ] Use `typing` module for complex types
- [ ] Data classes use type annotations

### Pattern

```python
from typing import Optional
from pathlib import Path

def process_file(
    path: Path,
    threshold: float = 0.8
) -> tuple[pd.DataFrame, list[str]]:
    """Process file and return (result, errors)."""
    ...
```

---

## 8. Error Handling

**Only catch expected exceptions. Let unexpected errors bubble up.**

### Requirements

- [ ] Only catch specific exception types
- [ ] Never use bare `except:` or `except Exception:`
- [ ] Provide clear error messages
- [ ] Re-raise with context using `from e`

### Pattern

```python
# ✅ GOOD
try:
    df = pd.read_excel(path)
except BadZipFile as e:
    raise ValueError(f"Corrupt Excel file: {path}") from e

# ❌ BAD
try:
    df = pd.read_excel(path)
except Exception:  # Too broad
    return None
```

---

## 9. File Size Limit

**No file should exceed 500 lines.**

### Requirements

- [ ] Check line count of modified files
- [ ] If >500 lines: Extract functions, split into submodules
- [ ] Move constants to separate config file
- [ ] Create subpackage if module grows too large

### Recovery

```bash
# Check file size
wc -l src/myproject/large_file.py

# If >500 lines, split it
# Create src/myproject/module/
# Move functions to separate files
```

---

## 10. Dependency Injection

**Don't create dependencies inside classes. Inject them.**

### Requirements

- [ ] Classes accept dependencies as constructor parameters
- [ ] Makes testing easy (inject mocks)
- [ ] No hard-coded dependency instantiation

### Pattern

```python
# ✅ GOOD
class ProcessingService:
    def __init__(
        self,
        parser: DataParser,
        validator: DataValidator
    ):
        self.parser = parser
        self.validator = validator

# Usage with real dependencies
service = ProcessingService(
    parser=ExcelParser(),
    validator=SchemaValidator()
)

# Testing with mocks
service = ProcessingService(
    parser=Mock(spec=DataParser),
    validator=Mock(spec=DataValidator)
)
```

---

## 11. Documentation Updates

**Update documentation whenever you change code behavior.**

### Requirements

- [ ] README.md updated if user-facing changes
- [ ] API documentation updated if endpoints/interfaces changed
- [ ] Architecture docs updated if design patterns changed
- [ ] Code comments added for complex/non-obvious logic
- [ ] Docstrings updated for modified functions/classes
- [ ] CHANGELOG.md updated (if exists)
- [ ] PR description explains what changed and why

### Prohibited

❌ NEVER merge code without corresponding docs
❌ NEVER assume documentation is optional
❌ NEVER leave "TODO: Add docs" comments

### Required Workflow

```bash
# 1. Identify affected docs
cat README.md docs/api.md  # Review existing docs

# 2. Make code changes + update docs together
# Edit src/api.py
# Edit docs/api.md

# 3. Commit together
git add src/api.py docs/api.md
git commit -m "feat: add user endpoint and update API docs"
```

### Pattern

```python
# ✅ GOOD: Code with documentation
def process_user_data(user_id: str, options: ProcessingOptions) -> ProcessedData:
    """Process user data with specified options.

    Args:
        user_id: Unique identifier for the user
        options: Processing configuration options

    Returns:
        ProcessedData object with results and metadata

    Raises:
        UserNotFoundError: If user_id doesn't exist
        ValidationError: If options are invalid

    Example:
        >>> result = process_user_data("user123", ProcessingOptions(normalize=True))
        >>> print(result.status)
        'success'
    """
    # Complex logic explained with comments
    # 1. Validate user exists and is active
    user = get_user(user_id)  # Raises UserNotFoundError if not found
    if not user.is_active:
        raise ValidationError("User is not active")

    # 2. Apply normalization if requested
    # Normalization ensures consistent formatting across systems
    data = user.get_data()
    if options.normalize:
        data = normalize_data(data)

    return ProcessedData(data=data, user_id=user_id, status="success")
```

### AI Assistant Checklist

Before committing:
- [ ] Read existing documentation first (use Read tool)
- [ ] Update README if user-facing changes
- [ ] Update docstrings for modified functions
- [ ] Update API docs if endpoints changed
- [ ] Add code comments for complex logic
- [ ] Include docs in same commit as code
- [ ] PR description references doc updates
- [ ] PR template checklist completed

### When Documentation is Required

**Always required:**
- New public APIs, functions, or classes
- Changed function signatures or behavior
- New user-facing features
- Breaking changes
- Complex algorithms or business logic
- Configuration options

**Sometimes required:**
- Bug fixes (if behavior changed noticeably)
- Refactoring (if API or usage changed)
- Performance optimizations (if user-visible)

**Not required:**
- Internal-only code changes (still need docstrings though)
- Test-only changes
- Trivial fixes (typos in code, not user-facing)

---

## 12. Atomic Commits

**Every commit should represent ONE logical change.**

### The "AND" Test

If your commit message uses "and", split it into multiple commits.

```bash
# BAD: Multiple concerns
git commit -m "feat: add login form and fix validation bug and update styles"

# GOOD: Atomic commits
git commit -m "feat: add login form component"
git commit -m "fix: resolve email validation error"
git commit -m "style: update form input styling"
```

### Requirements

- [ ] Each commit does exactly ONE thing
- [ ] Commit message doesn't contain "and" (linking unrelated changes)
- [ ] Tests pass after each commit
- [ ] Formatting/linting changes are separate commits
- [ ] Refactoring is separate from new features
- [ ] Bug fixes are separate from feature work

### Commit Sequence Examples

**New Feature:**
```bash
git commit -m "feat: add User model with auth fields"
git commit -m "feat: implement password hashing"
git commit -m "feat: add login endpoint"
git commit -m "test: add auth endpoint tests"
git commit -m "docs: document authentication API"
```

**Bug Fix:**
```bash
git commit -m "test: add failing test for cache bug"
git commit -m "fix: resolve cache race condition"
```

**Refactoring:**
```bash
git commit -m "refactor: create PaymentService skeleton"
git commit -m "refactor: move payment logic to service"
git commit -m "refactor: update controllers to use service"
git commit -m "chore: remove deprecated helpers"
```

### AI Assistant Checklist

**Before EVERY commit:**
- [ ] Does this commit do ONE thing only?
- [ ] Would someone understand this from just the message?
- [ ] Are formatting changes in a separate commit?
- [ ] Are refactors separate from features?
- [ ] Do tests pass?

**See:** `.claude/knowledge/git/atomic-commits.md` for detailed guidance.

---

## Pre-Operation Checklist

**Run this checklist before ANY operation:**

1. [ ] Read project-specific `.claude/CLAUDE.md` (if exists)
2. [ ] Check virtual environment active: `which python`
3. [ ] Check current git branch: `git branch --show-current`
4. [ ] Verify not on main/master branch
5. [ ] Read relevant files before editing
6. [ ] Run tests after changes
7. [ ] Update documentation with code changes
8. [ ] Use atomic commits (one logical change per commit)
9. [ ] Create PR, never push to main

---

## Common Mistakes

**These are the most frequent critical errors:**

1. ❌ Running `pip install` without checking venv is active
2. ❌ Pushing to main branch instead of creating PR
3. ❌ Using `print()` instead of structured logging
4. ❌ Catching generic `Exception` instead of specific types
5. ❌ Writing files over 500 lines
6. ❌ Functions without type hints
7. ❌ Committing without running tests
8. ❌ Using bare `except:` clauses
9. ❌ Changing code without updating documentation
10. ❌ Missing docstrings on new functions
11. ❌ Committing multiple unrelated changes together (non-atomic commits)
12. ❌ Mixing formatting changes with logic changes in same commit

---

## Emergency Recovery

**If you realize you've violated a critical rule:**

### Pushed to main accidentally

```bash
# 1. Immediately revert
git revert HEAD --no-edit
git push origin main

# 2. Create feature branch from the commit
git checkout -b feature/fix-accidental-push <commit-hash>
git push -u origin feature/fix-accidental-push

# 3. Create PR
gh pr create
```

### Installed packages without venv

```bash
# Can't undo, but prevent future mistakes:
# 1. Create venv now
python3 -m venv .venv
source .venv/bin/activate

# 2. Reinstall in venv
pip install -r requirements.txt

# 3. Inform user to check system Python
# (User may need to clean up system packages)
```

---

## Questions to Ask Yourself

**Before executing any command, ask:**

1. Am I in a virtual environment? (`which python`)
2. Am I on a feature branch? (`git branch --show-current`)
3. Have I read the file I'm about to edit? (Use Read tool)
4. Will this change break tests? (Run `pytest` before commit)
5. Is this file growing too large? (Check `wc -l`)
6. Am I using type hints? (Check function signatures)
7. Am I catching specific exceptions? (Not generic `Exception`)
8. What documentation needs to be updated? (README, API docs, docstrings)
9. Have I added docstrings to new functions? (Required for all functions)
10. Is this commit atomic? (ONE logical change only)
11. Does my commit message avoid "and"? (If not, split the commit)

---

## Related Documentation

- **Engineering Standards**: `.claude/docs/ENGINEERING_STANDARDS.md`
- **Knowledge Base**: `.claude/knowledge/` (tactical tips)
- **Full Standards**: `/docs/ENGINEERING_STANDARDS.md` (human-facing)

---

**Status**: These rules are NON-NEGOTIABLE. Updated: 2026-01-12
