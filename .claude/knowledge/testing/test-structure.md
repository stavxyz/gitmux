# Test Structure

## When to Use

**Organizing tests in any Python project.**

## Quick Reference

```
project/
├── src/
│   ├── __init__.py
│   ├── auth.py
│   └── database.py
└── tests/
    ├── __init__.py
    ├── conftest.py          # Shared fixtures
    ├── unit/
    │   ├── __init__.py
    │   ├── test_auth.py     # Mirrors src/auth.py
    │   └── test_database.py
    └── integration/
        ├── __init__.py
        └── test_api.py
```

## Why This Matters

- **Discoverability:** Tests easy to find by mirroring src/
- **Isolation:** Unit tests separate from integration tests
- **Fixtures:** Shared test setup in conftest.py
- **CI/CD:** Clear separation for different test suites
- **Maintenance:** Changes to code clearly map to test files

## Patterns

### Pattern 1: Basic Test Structure

```
tests/
├── conftest.py              # pytest fixtures
├── unit/
│   ├── test_models.py       # Tests for src/models.py
│   └── test_utils.py        # Tests for src/utils.py
└── integration/
    └── test_api_endpoints.py
```

### Pattern 2: Mirror Source Structure

```
src/
├── auth/
│   ├── __init__.py
│   ├── login.py
│   └── signup.py

tests/
└── unit/
    └── auth/
        ├── test_login.py    # Mirrors src/auth/login.py
        └── test_signup.py   # Mirrors src/auth/signup.py
```

### Pattern 3: Fixtures in conftest.py

```python
# tests/conftest.py
import pytest
from src.database import Database

@pytest.fixture
def db():
    """Provide test database."""
    database = Database(":memory:")
    yield database
    database.close()

@pytest.fixture
def user_data():
    """Provide test user data."""
    return {
        "username": "testuser",
        "email": "test@example.com"
    }
```

## Test Types

### Unit Tests
**Purpose:** Test individual functions/classes in isolation

**Location:** `tests/unit/`

**Characteristics:**
- Fast (milliseconds)
- No external dependencies (mock them)
- Test single function/method
- No database, API calls, file I/O

**Example:**
```python
# tests/unit/test_auth.py
def test_hash_password():
    result = hash_password("secret123")
    assert result != "secret123"
    assert len(result) == 64
```

### Integration Tests
**Purpose:** Test components working together

**Location:** `tests/integration/`

**Characteristics:**
- Slower (seconds)
- May use test database
- Test multiple components
- Verify real interactions

**Example:**
```python
# tests/integration/test_api.py
def test_user_registration_flow(client, db):
    response = client.post("/signup", json={"email": "test@example.com"})
    assert response.status_code == 201
    user = db.query(User).filter_by(email="test@example.com").first()
    assert user is not None
```

### End-to-End Tests (Optional)
**Purpose:** Test complete user workflows

**Location:** `tests/e2e/`

**Characteristics:**
- Slowest (minutes)
- Full system setup
- Browser automation (if web app)
- Test real user scenarios

## File Naming

**Convention:** `test_*.py` or `*_test.py`

**Recommended:** `test_*.py` (pytest default)

```python
# ✅ Good
test_auth.py
test_user_model.py
test_database_connection.py

# ❌ Avoid
auth_tests.py
user_test.py
database.py
```

## Test Function Naming

**Convention:** `test_<what>_<condition>_<expected>`

```python
# ✅ Good - descriptive
def test_login_with_valid_credentials_returns_token():
    ...

def test_login_with_invalid_password_raises_error():
    ...

def test_create_user_with_duplicate_email_fails():
    ...

# ❌ Bad - vague
def test_login():
    ...

def test_user():
    ...
```

## AI Assistant Checklist

**When creating tests:**
- [ ] Place in `tests/unit/` or `tests/integration/`
- [ ] Mirror source structure: `src/auth.py` → `tests/unit/test_auth.py`
- [ ] Name file: `test_*.py`
- [ ] Name functions: `test_<descriptive_name>`
- [ ] Use fixtures from conftest.py
- [ ] Import from `src/` not relative imports

**When organizing fixtures:**
- [ ] Shared fixtures → `tests/conftest.py`
- [ ] Module-specific → `tests/unit/conftest.py`
- [ ] Use `@pytest.fixture` decorator
- [ ] Use `yield` for cleanup

## Example Project Structure

```
my_project/
├── src/
│   ├── __init__.py
│   ├── auth.py
│   ├── database.py
│   ├── models.py
│   └── utils.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py           # Shared fixtures
│   ├── unit/
│   │   ├── __init__.py
│   │   ├── test_auth.py      # Tests src/auth.py
│   │   ├── test_database.py  # Tests src/database.py
│   │   ├── test_models.py    # Tests src/models.py
│   │   └── test_utils.py     # Tests src/utils.py
│   └── integration/
│       ├── __init__.py
│       └── test_api.py
├── pytest.ini
└── requirements.txt
```

## pytest Configuration

**File:** `pytest.ini` or `pyproject.toml`

```ini
# pytest.ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
markers =
    unit: Unit tests (fast, isolated)
    integration: Integration tests (slower, dependencies)
    e2e: End-to-end tests (slowest, full system)
```

**Usage:**
```bash
# Run only unit tests
pytest -m unit

# Skip slow tests
pytest -m "not e2e"

# Run specific directory
pytest tests/unit/
```

## Common Fixtures

```python
# tests/conftest.py
import pytest
from src.database import Database
from src.app import create_app

@pytest.fixture
def app():
    """Create test Flask app."""
    app = create_app({"TESTING": True})
    return app

@pytest.fixture
def client(app):
    """Create test client."""
    return app.test_client()

@pytest.fixture
def db():
    """Create test database."""
    database = Database(":memory:")
    database.create_tables()
    yield database
    database.close()

@pytest.fixture
def sample_user():
    """Provide sample user data."""
    return {
        "username": "testuser",
        "email": "test@example.com",
        "password": "secret123"
    }
```

## Gotchas

**"Tests not discovered"**
- Ensure `__init__.py` in test directories
- Check file naming: `test_*.py`
- Verify `testpaths` in pytest.ini

**"Import errors"**
- Install package in editable mode: `pip install -e .`
- Or add to PYTHONPATH: `export PYTHONPATH=src:$PYTHONPATH`

**"Fixture not found"**
- Check conftest.py location
- Ensure fixture name matches parameter name
- Verify `@pytest.fixture` decorator

## Related

- **pytest Basics:** [testing/pytest-basics.md](pytest-basics.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** Mirror src/ structure in tests/. Separate unit and integration tests. Use conftest.py for shared fixtures.
