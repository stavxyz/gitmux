# Engineering Standards (AI-Optimized)

> **For AI Assistants**: This is a concise, actionable version of organizational standards.
> **Human developers**: See `/docs/ENGINEERING_STANDARDS.md` for comprehensive version.

---

## Core Principles

### Simple > Complex
Choose straightforward solutions. Avoid clever code.

```python
# GOOD
numbers = [int(x) for x in data.split()]
odd_numbers = [n for n in numbers if n % 2 == 1]
result = sum(odd_numbers)
```

### Explicit > Implicit
Use enums, type hints, clear names. No magic.

```python
# GOOD
class ProcessingMode(Enum):
    NORMALIZE = "normalize"
    VALIDATE = "validate"

def process_data(df: pd.DataFrame, mode: ProcessingMode) -> pd.DataFrame:
    match mode:
        case ProcessingMode.NORMALIZE:
            return normalize_columns(df)
```

### DRY (Don't Repeat Yourself)
Extract shared logic immediately.

### Fail Fast
Validate inputs early. Raise specific exceptions with clear messages.

### YAGNI (You Aren't Gonna Need It)
Build what's needed now. Add features when actually required.

### File Size Limits
- **Python/Code files**: 500 lines max - split if exceeded
- **Markdown documentation**: 600 lines max - for comprehensive guides
If limits exceeded: extract helpers, create submodules, or split into focused docs.

---

## ⚠️ CRITICAL: Python Requirements

### Virtual Environments - MANDATORY

**ALWAYS use virtual environments. NEVER modify system Python.**

```bash
# Required workflow
python3 -m venv .venv
source .venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
```

**AI Assistant Checklist:**
- [ ] Before `pip install`: Verify `which python` shows `.venv/bin/python`
- [ ] NEVER use: `pip install` (without venv), `--user`, `sudo pip`
- [ ] If no venv exists: Create it first, then activate, then install

### Type Hints - REQUIRED

All functions MUST have type hints.

```python
from typing import Protocol
from pathlib import Path
import pandas as pd

# Required
def process_data(
    data: pd.DataFrame,
    threshold: float = 0.8
) -> tuple[pd.DataFrame, list[str]]:
    """Process dataframe and return (result, errors)."""
    ...

# Data classes with types
@dataclass
class User:
    id: str
    name: str
    email: str
    created_at: date
    is_active: bool = True
```

### Error Handling - Explicit Only

**Only catch exceptions you expect and can handle.**

```python
# GOOD: Explicit validation
def parse_file(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"File not found: {path}")

    if path.stat().st_size > 100_000_000:
        raise ValueError(f"File too large (>100MB): {path}")

    try:
        df = pd.read_excel(path)  # Expected: BadZipFile for corrupt files
    except BadZipFile as e:
        raise ValueError(f"Corrupt Excel file: {path}") from e

    return df

# BAD: Catching everything
try:
    return process_dataframe(df)
except Exception:  # Don't do this
    return None
```

**When to use try/except:**
- ✅ File operations (FileNotFoundError expected)
- ✅ External APIs (network errors expected)
- ✅ Parsing user input (ValueError expected)
- ❌ Regular Python logic (bugs should crash)

### Logging - Structured Only

**Always use structured logging. NEVER use `print()`.**

```python
import structlog

logger = structlog.get_logger()

def process_batch(batch_id: str, items: list[Item]) -> BatchResult:
    logger.info(
        "batch_processing_started",
        batch_id=batch_id,
        item_count=len(items)
    )

    # ... processing ...

    logger.info(
        "batch_processing_completed",
        batch_id=batch_id,
        success_count=len(results),
        error_count=len(errors)
    )

    return BatchResult(results, errors)
```

---

## Code Style

- **Line length**: 100 characters max
- **Formatter**: Ruff
- **Type checker**: mypy with --strict
- **Docstrings**: Google-style for public functions/classes

### Naming Conventions

```python
# Constants
MAX_RETRY_COUNT = 3

# Functions and variables
def calculate_total_price(items: list[Item]) -> Decimal:
    total_price = sum(item.price for item in items)
    return total_price

# Classes
class DataProcessor:
    pass

# Private methods
class MyClass:
    def _internal_helper(self):
        pass
```

---

## Documentation Requirements

Documentation includes code comments, docstrings, README files, API docs—**and commit messages**. Commit messages are permanent documentation that explain *why* changes were made.

### Inline Documentation

**All functions require docstrings in Google-style format:**

```python
def process_file(
    path: Path,
    threshold: float = 0.8,
    validate: bool = True
) -> tuple[pd.DataFrame, list[str]]:
    """Process file and return results with validation errors.

    Args:
        path: Path to file to process
        threshold: Minimum quality threshold (0.0 to 1.0)
        validate: Whether to run validation checks

    Returns:
        Tuple of (processed_dataframe, error_messages)

    Raises:
        FileNotFoundError: If file doesn't exist
        ValueError: If threshold not in valid range
        ValidationError: If validation fails

    Example:
        >>> result, errors = process_file(Path("data.csv"))
        >>> if not errors:
        ...     print("Success!")
    """
    ...
```

**Requirements:**
- Parameter types and descriptions
- Return value explained
- Exceptions documented
- Examples for complex functions
- Clear, concise language

### Code Comments

**Add comments for complex or non-obvious logic:**

```python
# ✅ GOOD: Explains WHY
# Use exponential backoff to avoid overwhelming the API
# Max 5 retries with 2^n second delays (2s, 4s, 8s, 16s, 32s)
for attempt in range(5):
    delay = 2 ** attempt
    ...

# ❌ BAD: States the obvious
# Loop 5 times
for attempt in range(5):
    ...
```

**When to add comments:**
- Complex algorithms or business logic
- Non-obvious optimizations
- Workarounds for known issues
- Security-sensitive code
- Performance-critical sections

**When NOT to add comments:**
- Code that is self-explanatory
- Redundant descriptions of what code does
- Outdated comments (remove instead of keeping)

### External Documentation

**Must be updated with code changes:**

| Document | When to Update | What to Include |
|----------|----------------|-----------------|
| **README.md** | User-facing changes | Feature description, usage examples, setup instructions |
| **docs/api.md** | API changes | Endpoint signatures, parameters, responses, examples |
| **docs/architecture.md** | Design changes | Architecture decisions, patterns used, diagrams |
| **CHANGELOG.md** | Version changes | What changed, breaking changes, migration guide |

### PR Documentation

**Every PR must include:**

- **Clear title** in semantic format:
  - `feat:` - New feature
  - `fix:` - Bug fix
  - `docs:` - Documentation only
  - `refactor:` - Code restructuring
  - `test:` - Test changes
  - `chore:` - Maintenance tasks

- **Description explaining:**
  - What changed (the changes made)
  - Why it changed (the motivation)
  - How it works (for complex changes)

- **Documentation checklist completed:**
  - All affected docs identified
  - All affected docs updated
  - Docs reviewed and accurate

- **Breaking changes called out:**
  - What breaks
  - Why it was necessary
  - How to migrate

### Documentation Workflow

**Document as you code, not after:**

```bash
# 1. Before coding: Review existing docs
Read README.md docs/api.md

# 2. While coding: Update docstrings
# Add docstrings to functions as you write them

# 3. After coding: Update external docs
Edit README.md  # Add usage example
Edit docs/api.md  # Document new endpoint

# 4. Commit together
git add src/ docs/ README.md
git commit -m "feat: add user authentication

- Implement JWT-based authentication
- Add /auth/login and /auth/refresh endpoints
- Update API documentation with auth examples
- Add authentication section to README"
```

### Commit Messages as Documentation

**Commit messages explain WHY changes were made.**

```bash
# ❌ BAD: Only describes what
git commit -m "fix: change timeout to 30"

# ✅ GOOD: Explains why
git commit -m "fix: increase API timeout to prevent false failures

Default 10s timeout caused intermittent failures when API slow."
```

**Key points:**
- Discoverable via `git log`, `git blame`, `git bisect`
- Use semantic prefixes (`feat:`, `fix:`, `docs:`)
- Subject line under 50 characters
- Add body for complex changes

See `.claude/knowledge/git/commit-messages.md` for format details.

### Documentation Quality

**Good documentation is:**
- **Accurate**: Matches current code behavior
- **Clear**: Easy to understand for target audience
- **Concise**: No unnecessary verbosity
- **Complete**: Covers all important aspects
- **Current**: Updated with code changes

**Bad documentation is:**
- Outdated or incorrect
- Overly verbose or unclear
- Missing critical information
- Not maintained with code

---

## Architecture Patterns

### Separation of Concerns

Each module/class/function has ONE clear responsibility.

```
src/myproject/
├── parsers/        # Read and parse files
├── validators/     # Validate data quality
├── processors/     # Transform data
├── exporters/      # Export formats
├── models/         # Data models (Pydantic)
├── services/       # Business logic orchestration
└── utils/          # Shared utilities
```

### Dependency Injection

Don't create dependencies inside; inject from outside.

```python
# GOOD
class ProcessingService:
    def __init__(
        self,
        parser: DataParser,
        validator: DataValidator,
    ):
        self.parser = parser
        self.validator = validator
```

### Composition Over Inheritance

Build complex behavior by combining simple objects.

### Immutability Where Possible

```python
# Immutable data classes
@dataclass(frozen=True)
class User:
    id: str
    name: str

# Pure functions
def normalize_name(name: str) -> str:
    return name.strip().upper()
```

---

## Testing Requirements

### Structure

```
tests/
├── unit/           # Fast, isolated, mocked dependencies
├── integration/    # Multi-component workflows
└── fixtures/       # Test data
```

### Running Tests

```bash
# All tests
pytest tests/ -v

# With coverage
pytest tests/ --cov=src --cov-report=term-missing

# Skip slow tests
pytest -m "not e2e"
```

### Test Quality

- Test behavior, not implementation
- One assertion per test
- Descriptive names: `test_<what>_<when>_<expected>`
- Mock external dependencies
- Aim for >80% coverage

---

## ⚠️ CRITICAL: Development Workflow

### Pull Request Requirement

**ALWAYS use pull requests. NEVER push to main.**

```bash
# Required workflow
git checkout -b feature/my-feature
# Make changes
pytest tests/ -v
git add .
git commit -m "feat: add feature"
git push -u origin feature/my-feature
gh pr create
```

**AI Assistant Checklist:**
- [ ] Before pushing: Verify current branch is NOT main/master
- [ ] If on main: Immediately create feature branch
- [ ] Always create PR, never merge directly

### Atomic Commits - Required

**Each commit = ONE logical, complete change.**

#### The "AND" Test

```bash
# ❌ BAD
git commit -m "feat: add auth and fix bug and update docs"

# ✅ GOOD
git commit -m "feat: add user authentication"
git commit -m "fix: resolve login redirect loop"
git commit -m "docs: update API authentication guide"
```

#### Commit Sequences

**Feature:**
```bash
git commit -m "feat: add UserService skeleton"
git commit -m "feat: implement validation logic"
git commit -m "test: add UserService tests"
git commit -m "docs: add UserService documentation"
```

**Bug Fix:**
```bash
git commit -m "test: add failing test for race condition"
git commit -m "fix: resolve cache invalidation race"
```

**Refactor:**
```bash
git commit -m "refactor: add new module skeleton"
git commit -m "refactor: migrate existing logic"
git commit -m "refactor: update callers"
git commit -m "chore: remove deprecated code"
```

#### When to Commit

- ✅ Added a function/class
- ✅ Fixed a single bug
- ✅ Added tests for specific functionality
- ✅ Made one refactoring change
- ✅ Updated documentation
- ✅ Applied formatting (its own commit)

**Never commit:**
- ❌ Broken/incomplete changes
- ❌ Multiple unrelated changes
- ❌ WIP without a complete logical unit

### Pre-Commit Checks

Run before committing:

```bash
# Lint and fix
ruff check --fix src/ tests/

# Format
ruff format src/ tests/

# Type check
mypy src/

# Run tests
pytest tests/ -v
```

### Commit Messages

```bash
# Format: <type>: <description>
feat: add user authentication
fix: resolve database connection issue
docs: update API documentation
refactor: simplify data processing logic
test: add unit tests for parser

# Include co-authors
Co-Authored-By: Name <email@example.com>
```

---

## Code Quality Tools

### Ruff Configuration

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

select = [
    "E",   # pycodestyle errors
    "W",   # pycodestyle warnings
    "F",   # pyflakes
    "I",   # isort
    "N",   # pep8-naming
    "UP",  # pyupgrade
    "B",   # bugbear
    "C4",  # comprehensions
    "SIM", # simplify
]

[tool.ruff.format]
quote-style = "double"
```

### mypy Configuration

```toml
[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
disallow_untyped_defs = true
```

### pytest Configuration

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = ["-v", "--strict-markers", "--tb=short"]
markers = [
    "e2e: end-to-end tests (may be slow)",
    "unit: fast unit tests",
]
```

---

## ⚠️ CRITICAL: Infrastructure Cost Standards

### Infrastructure as Code Requirements

**ALWAYS estimate costs before deploying infrastructure.**

```bash
# Install Infracost
brew install infracost

# Generate cost estimate
infracost breakdown --path .

# Set budget threshold
pulumi config set monthlyBudget 100  # $100/month
```

**AI Assistant Checklist:**
- [ ] Before infrastructure deployment: Run cost estimation
- [ ] Verify estimated cost within budget threshold
- [ ] Tag all resources with: Environment, CostCenter, Owner, ManagedBy
- [ ] Set up budget alerts at 50%, 80%, 100%
- [ ] Use appropriate sizing for environment (dev < staging < production)

### Required Tags for All Cloud Resources

```python
# Standard tags
{
    "Environment": pulumi.get_stack(),  # dev/staging/production
    "CostCenter": "engineering",
    "Owner": "platform-team",
    "ManagedBy": "pulumi",
    "Project": pulumi.get_project(),
}
```

### Environment-Specific Sizing

```python
# Development: Minimal resources
- Use free tiers where possible
- Single-AZ deployment
- Minimal backup retention (7 days)
- Small instance sizes

# Staging: Mid-tier resources
- Paid tiers for realistic testing
- Single-AZ deployment
- 7-day backup retention
- Medium instance sizes

# Production: Production-grade resources
- Paid tiers with SLA
- Multi-AZ deployment for HA
- 30-day backup retention
- Right-sized instances based on load
```

### Cost Monitoring

**Required monitoring:**
- Weekly cost reviews via provider dashboards
- Automated alerts at budget thresholds
- Monthly optimization reviews
- Quarterly architecture audits

**Related Documentation:**
- **Financial Governance:** `.claude/knowledge/infrastructure/financial-governance.md`
- **Pulumi Guide:** `.claude/knowledge/infrastructure/pulumi-guide.md`
- **Managing IaC Playbook:** `playbooks/managing-infrastructure-as-code.md`

---

## AI Assistant Quick Reference

### Before Any Operation

1. Check virtual environment active: `which python`
2. Verify not on main branch: `git branch --show-current`
3. Read project CLAUDE.md for project-specific rules
4. Before infrastructure changes: Estimate costs with Infracost

### Common Operations

**Install packages:**
```bash
# Verify venv first
which python  # Must show .venv/bin/python
pip install package-name
```

**Create PR:**
```bash
git checkout -b feature/name
# Make changes
pytest tests/ -v
git add .
git commit -m "feat: description"
git push -u origin feature/name
gh pr create
```

**Run quality checks:**
```bash
ruff check --fix .
ruff format .
mypy src/
pytest tests/ -v
```

### Common Mistakes to Avoid

❌ `pip install` without checking venv
❌ `git push` when on main branch
❌ Using `print()` instead of logging
❌ Catching generic `Exception`
❌ Files over 500 lines
❌ Functions without type hints
❌ Committing without running tests
❌ Changing code without updating documentation
❌ Missing docstrings on functions
❌ Outdated comments or documentation
❌ Multiple unrelated changes in one commit (use atomic commits)
❌ Commit messages that don't explain why

---

## Related Documentation

- **Full Standards**: `/docs/ENGINEERING_STANDARDS.md` (human-facing, comprehensive)
- **Critical Rules**: `.claude/docs/CLAUDE_CODE_RULES.md` (non-negotiable requirements)
- **Knowledge Base**: `.claude/knowledge/` (tactical tips and patterns)

---

**Status**: These standards apply to all organizational projects. Updated: 2026-01-12
