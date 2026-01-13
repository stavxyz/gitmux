# Type Hints

## When to Use

**REQUIRED:** All functions must have type hints for parameters and return values.

## Quick Reference

```python
from typing import Optional, Protocol
from pathlib import Path
from datetime import date
import pandas as pd

# Function with type hints
def process_data(
    data: pd.DataFrame,
    threshold: float = 0.8
) -> tuple[pd.DataFrame, list[str]]:
    """Process dataframe and return (result, errors)."""
    ...

# Data class with types
@dataclass
class User:
    id: str
    name: str
    email: str
    created_at: date
    is_active: bool = True

# Protocol for duck typing
class Processor(Protocol):
    def process(self, data: pd.DataFrame) -> pd.DataFrame:
        ...
```

## Patterns

### Pattern 1: Basic Function Types

```python
def calculate_total(items: list[dict], tax_rate: float) -> float:
    """Calculate total with tax."""
    subtotal = sum(item['price'] for item in items)
    return subtotal * (1 + tax_rate)
```

### Pattern 2: Optional Parameters

```python
from typing import Optional

def find_user(user_id: str, include_deleted: bool = False) -> Optional[User]:
    """Find user by ID. Returns None if not found."""
    ...
```

### Pattern 3: Complex Return Types

```python
def parse_file(path: Path) -> tuple[pd.DataFrame, list[str], dict[str, any]]:
    """Parse file and return (data, errors, metadata)."""
    ...
```

### Pattern 4: Type Aliases

```python
# Make complex types readable
UserID = str
ErrorMessage = str
ProcessingResult = tuple[pd.DataFrame, list[ErrorMessage]]

def process(user_id: UserID, data: pd.DataFrame) -> ProcessingResult:
    ...
```

### Pattern 5: Protocols for Interfaces

```python
from typing import Protocol

# Define interface without inheritance
class Validatable(Protocol):
    def validate(self) -> list[str]:
        """Return list of validation errors."""
        ...

# Any class with validate() method matches
class MyData:
    def validate(self) -> list[str]:
        return []  # Automatically matches Validatable

def validate_all(items: list[Validatable]) -> bool:
    """Works with any object that has validate()."""
    ...
```

## AI Assistant Checklist

**When writing functions:**
- [ ] All parameters have types
- [ ] Return type specified
- [ ] Use `Optional[T]` for values that can be None
- [ ] Complex types use type aliases
- [ ] Data classes have field types

**Type checking:**
```bash
# Run mypy
mypy src/

# Common flags
mypy src/ --strict
mypy src/ --ignore-missing-imports
```

## Common Type Patterns

```python
# Lists
items: list[str]
data: list[dict[str, any]]

# Dictionaries
config: dict[str, str]
mapping: dict[str, int]

# Tuples (fixed length)
point: tuple[float, float]
result: tuple[bool, str]  # (success, message)

# Optional (can be None)
user: Optional[User]
error: Optional[str]

# Union (one of multiple types)
from typing import Union
value: Union[int, str]

# Callable (function type)
from typing import Callable
processor: Callable[[str], int]  # Takes str, returns int

# Literal (specific values only)
from typing import Literal
mode: Literal['read', 'write', 'append']
```

## Benefits

- **IDE Support:** Autocomplete and inline docs
- **Error Detection:** Catch bugs before runtime
- **Self-Documentation:** Code explains itself
- **Refactoring Safety:** Know what breaks when changing types

## Gotchas

**"Type object is not subscriptable"**
- Old Python version (need 3.9+)
- Use `from __future__ import annotations` for 3.7-3.8

**Circular imports with types**
- Use `from __future__ import annotations`
- Or use string literals: `def process(self, user: "User")`

**Generic types**
```python
from typing import TypeVar, Generic

T = TypeVar('T')

class Container(Generic[T]):
    def __init__(self, value: T):
        self.value = value

# Use
container: Container[int] = Container(42)
```

## mypy Configuration

```toml
[tool.mypy]
python_version = "3.11"
strict = true
warn_return_any = true
disallow_untyped_defs = true

# For third-party packages without types
[[tool.mypy.overrides]]
module = "some_package.*"
ignore_missing_imports = true
```

## Related

- **Virtual Environments:** [python/virtual-environments.md](virtual-environments.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** Type hints are required, not optional. They catch bugs and make code self-documenting.
