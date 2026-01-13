# pytest Basics

## When to Use

**Before every commit. Every time you write code.**

## Quick Reference

```bash
# Run all tests
pytest tests/ -v

# Run specific file
pytest tests/unit/test_auth.py -v

# Run specific test
pytest tests/unit/test_auth.py::test_login -v

# Run with coverage
pytest tests/ --cov=src --cov-report=term-missing

# Skip slow tests
pytest -m "not e2e"

# Stop on first failure
pytest -x

# Show print statements
pytest -s
```

## Why This Matters

- **Catch bugs early:** Find issues before they reach production
- **Confidence:** Refactor without breaking things
- **Documentation:** Tests show how code should work
- **CI/CD:** Automated testing in pipelines
- **Regression:** Prevent old bugs from returning

## Patterns

### Pattern 1: Basic Test

```python
# tests/unit/test_math.py
def test_addition():
    result = 2 + 2
    assert result == 4

def test_division():
    result = 10 / 2
    assert result == 5.0
```

**Run:**
```bash
pytest tests/unit/test_math.py -v
```

### Pattern 2: Test with Fixture

```python
# tests/conftest.py
import pytest

@pytest.fixture
def user_data():
    return {"username": "test", "email": "test@example.com"}

# tests/unit/test_user.py
def test_create_user(user_data):
    user = create_user(user_data)
    assert user.username == "test"
    assert user.email == "test@example.com"
```

### Pattern 3: Testing Exceptions

```python
import pytest

def test_division_by_zero():
    with pytest.raises(ZeroDivisionError):
        result = 10 / 0

def test_invalid_email():
    with pytest.raises(ValueError, match="Invalid email"):
        validate_email("notanemail")
```

### Pattern 4: Parametrized Tests

```python
import pytest

@pytest.mark.parametrize("input,expected", [
    (2, 4),
    (3, 9),
    (4, 16),
    (5, 25),
])
def test_square(input, expected):
    assert input ** 2 == expected
```

## AI Assistant Checklist

**Before committing:**
- [ ] Run: `pytest tests/ -v`
- [ ] ALL tests must pass
- [ ] No skipped tests (unless intentional)
- [ ] Fix failures immediately
- [ ] NEVER commit failing tests

**When writing tests:**
- [ ] Test file: `test_*.py`
- [ ] Test function: `def test_*():`
- [ ] Use descriptive names
- [ ] Test edge cases
- [ ] One assertion per concept

**Running tests:**
- [ ] Use `-v` for verbose output
- [ ] Use `--cov=src` to check coverage
- [ ] Use `-x` to stop on first failure (debugging)
- [ ] Use `-s` to see print statements (debugging)

## Common Commands

### Run Tests

```bash
# All tests, verbose
pytest tests/ -v

# Specific directory
pytest tests/unit/ -v

# Specific file
pytest tests/unit/test_auth.py -v

# Specific test function
pytest tests/unit/test_auth.py::test_login -v

# Match pattern
pytest tests/ -k "login" -v
```

### Coverage Reports

```bash
# Coverage with missing lines
pytest tests/ --cov=src --cov-report=term-missing

# HTML coverage report
pytest tests/ --cov=src --cov-report=html
open htmlcov/index.html

# Fail if coverage below threshold
pytest tests/ --cov=src --cov-fail-under=80
```

### Test Markers

```bash
# Run only unit tests
pytest -m unit

# Skip integration tests
pytest -m "not integration"

# Skip slow tests
pytest -m "not e2e"
```

### Debugging

```bash
# Stop on first failure
pytest -x

# Show print statements
pytest -s

# Enter debugger on failure
pytest --pdb

# Verbose output
pytest -vv
```

## Assertions

### Basic Assertions

```python
# Equality
assert result == expected
assert user.name == "Alice"

# Inequality
assert result != 0
assert len(items) > 0

# Boolean
assert is_valid
assert not is_empty

# Membership
assert "key" in dictionary
assert item not in list
```

### Advanced Assertions

```python
# Approximate equality (floats)
assert result == pytest.approx(3.14159, rel=1e-5)

# Exception matching
with pytest.raises(ValueError, match="Invalid input"):
    function_that_raises()

# Multiple conditions
assert all([condition1, condition2, condition3])
```

## Fixtures

### Basic Fixture

```python
import pytest

@pytest.fixture
def sample_data():
    return [1, 2, 3, 4, 5]

def test_sum(sample_data):
    assert sum(sample_data) == 15
```

### Fixture with Setup/Teardown

```python
@pytest.fixture
def database():
    # Setup
    db = Database(":memory:")
    db.create_tables()

    # Provide to test
    yield db

    # Teardown
    db.close()

def test_insert(database):
    database.insert("users", {"name": "Alice"})
    assert database.count("users") == 1
```

### Fixture Scopes

```python
# Function scope (default) - new for each test
@pytest.fixture
def data():
    return {"key": "value"}

# Module scope - shared across file
@pytest.fixture(scope="module")
def app():
    return create_app()

# Session scope - shared across all tests
@pytest.fixture(scope="session")
def config():
    return load_config()
```

## Test Markers

```python
import pytest

# Mark as unit test
@pytest.mark.unit
def test_function():
    ...

# Mark as integration test
@pytest.mark.integration
def test_api():
    ...

# Mark as slow
@pytest.mark.slow
def test_large_dataset():
    ...

# Skip test
@pytest.mark.skip(reason="Not implemented yet")
def test_future_feature():
    ...

# Skip conditionally
@pytest.mark.skipif(sys.version_info < (3, 10), reason="Requires Python 3.10+")
def test_new_syntax():
    ...
```

## Common Patterns

### Testing Functions

```python
# src/math_utils.py
def add(a: int, b: int) -> int:
    return a + b

# tests/unit/test_math_utils.py
def test_add_positive_numbers():
    assert add(2, 3) == 5

def test_add_negative_numbers():
    assert add(-2, -3) == -5

def test_add_mixed_numbers():
    assert add(-2, 3) == 1
```

### Testing Classes

```python
# src/user.py
class User:
    def __init__(self, name: str, email: str):
        self.name = name
        self.email = email

    def is_valid_email(self) -> bool:
        return "@" in self.email

# tests/unit/test_user.py
def test_user_creation():
    user = User("Alice", "alice@example.com")
    assert user.name == "Alice"
    assert user.email == "alice@example.com"

def test_valid_email():
    user = User("Alice", "alice@example.com")
    assert user.is_valid_email() is True

def test_invalid_email():
    user = User("Alice", "notanemail")
    assert user.is_valid_email() is False
```

### Mocking External Dependencies

```python
from unittest.mock import Mock, patch

def test_api_call():
    # Mock external API
    with patch('src.api.requests.get') as mock_get:
        mock_get.return_value.json.return_value = {"status": "ok"}

        result = fetch_data()
        assert result["status"] == "ok"
        mock_get.assert_called_once()
```

## Coverage

**Target:** 80%+ code coverage

```bash
# Check coverage
pytest tests/ --cov=src --cov-report=term-missing

# Output example:
# Name                Stmts   Miss  Cover   Missing
# -------------------------------------------------
# src/auth.py            45      5    89%   23-27
# src/database.py        67      0   100%
# src/models.py          34      8    76%   12, 45-51
# -------------------------------------------------
# TOTAL                 146     13    91%
```

**Interpret:**
- `Stmts`: Total lines of code
- `Miss`: Lines not covered by tests
- `Cover`: Percentage covered
- `Missing`: Specific line numbers not tested

## Gotchas

**"No tests found"**
- Check file naming: `test_*.py`
- Check function naming: `def test_*():`
- Ensure `__init__.py` in test directories

**"Fixture not found"**
- Verify fixture name matches parameter
- Check conftest.py location
- Ensure `@pytest.fixture` decorator

**"Import errors"**
- Install in editable mode: `pip install -e .`
- Or set PYTHONPATH: `export PYTHONPATH=src`

**"Tests pass locally but fail in CI"**
- Check environment differences
- Verify dependencies in requirements.txt
- Check for hardcoded paths

**"Slow tests"**
- Mark slow tests: `@pytest.mark.slow`
- Skip during development: `pytest -m "not slow"`
- Run in CI: `pytest -m slow`

## Integration with CI/CD

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pytest tests/ -v --cov=src --cov-fail-under=80
```

## Related

- **Test Structure:** [testing/test-structure.md](test-structure.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** Run `pytest tests/ -v` before every commit. ALL tests must pass. 80%+ coverage required.
