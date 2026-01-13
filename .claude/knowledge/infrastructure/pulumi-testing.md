# Pulumi Testing: Infrastructure Code Testing with pytest

## When to Use

**Test your infrastructure code when:**
- Defining reusable components
- Implementing cost controls or policies
- Setting up production infrastructure
- Making significant infrastructure changes
- Working with critical infrastructure

## Why Test Infrastructure

**Benefits:**
- Catch configuration errors before deployment
- Verify cost controls are enforced
- Ensure environment-specific settings are correct
- Document expected infrastructure behavior
- Enable confident refactoring

## Testing Approaches

### Unit Tests

**Test individual components in isolation:**

```python
# tests/test_web_service.py
import pytest
import pulumi

@pulumi.runtime.test
def test_web_service_has_required_tags() -> None:
    """Ensure web service resources have required tags."""
    from components.web_service import WebService

    # Mock Pulumi runtime
    pulumi.runtime.settings.set_mocked()

    # Create component
    service = WebService(
        "test-service",
        vpc_id="vpc-12345",
        subnet_ids=["subnet-1", "subnet-2"],
        container_image="test:latest",
    )

    # Verify tags
    assert service.cluster.tags["Environment"]
    assert service.cluster.tags["ManagedBy"] == "pulumi"
```

### Integration Tests

**Test actual deployments:**

```python
# tests/test_integration.py
import pytest
from pulumi import automation as auto

@pytest.mark.integration
def test_deploy_dev_stack() -> None:
    """Test deploying dev stack."""
    stack = auto.select_stack(
        stack_name="dev",
        project_name="my-infrastructure",
    )

    # Deploy
    up_result = stack.up()

    # Verify outputs
    assert "api_url" in up_result.outputs
    assert "database_endpoint" in up_result.outputs

    # Cleanup
    stack.destroy()
```

## Testing Components

### Testing Resource Configuration

```python
# tests/test_database.py
import pytest
import pulumi
from typing import Any

@pulumi.runtime.test
def test_dev_database_uses_small_instance() -> None:
    """Ensure dev database uses cost-effective instance."""
    import os
    os.environ["PULUMI_STACK"] = "dev"

    from components.database import create_database

    db = create_database(name="test-db")

    # Dev should use small instances
    assert db.instance_class.startswith("db.t3.micro") or db.instance_class.startswith("db.t4g.micro")
    assert db.multi_az is False
    assert db.backup_retention_days <= 7

@pulumi.runtime.test
def test_production_database_has_ha() -> None:
    """Ensure production database has high availability."""
    import os
    os.environ["PULUMI_STACK"] = "production"

    from components.database import create_database

    db = create_database(name="test-db")

    # Production should have HA and backups
    assert db.multi_az is True
    assert db.backup_retention_days >= 30
```

### Testing Cost Controls

```python
# tests/test_cost_estimates.py
import pytest
import os

def test_dev_stack_is_cheap() -> None:
    """Ensure dev stack stays within budget."""
    os.environ["PULUMI_STACK"] = "dev"

    from config import AppConfig

    config = AppConfig.from_pulumi_config()

    # Dev budget should be low
    assert config.monthly_budget_usd <= 100
    assert config.db_instance_class.startswith("db.t3.micro")
    assert config.web_min_tasks == 1

def test_production_has_adequate_budget() -> None:
    """Ensure production has adequate budget."""
    os.environ["PULUMI_STACK"] = "production"

    from config import AppConfig

    config = AppConfig.from_pulumi_config()

    # Production should have realistic budget
    assert config.monthly_budget_usd >= 500
    assert config.web_min_tasks >= 2
```

### Testing Tags

```python
# tests/test_tags.py
import pytest
import pulumi

@pulumi.runtime.test
def test_all_resources_have_required_tags() -> None:
    """Ensure all resources have cost allocation tags."""
    import pulumi_aws as aws

    # Create a test resource
    bucket = aws.s3.Bucket(
        "test-bucket",
        tags={
            "Environment": "test",
            "CostCenter": "engineering",
            "ManagedBy": "pulumi",
        },
    )

    # Verify required tags
    required_tags = ["Environment", "CostCenter", "ManagedBy"]
    for tag in required_tags:
        assert tag in bucket.tags
```

## Testing with Automation API

### Programmatic Stack Management

```python
# tests/test_automation.py
from typing import Callable
import pytest
from pulumi import automation as auto

@pytest.fixture
def stack() -> auto.Stack:
    """Create test stack."""
    stack_name = "test"
    project_name = "my-infrastructure"

    # Create or select stack
    stack = auto.create_or_select_stack(
        stack_name=stack_name,
        project_name=project_name,
        program=lambda: None,  # Empty program for testing
    )

    yield stack

    # Cleanup
    try:
        stack.workspace.remove_stack(stack_name)
    except Exception:
        pass

def test_stack_config(stack: auto.Stack) -> None:
    """Test stack configuration."""
    # Set config
    stack.set_config("monthlyBudget", auto.ConfigValue(value="100"))
    stack.set_config("costCenter", auto.ConfigValue(value="engineering"))

    # Get config
    config = stack.get_config("monthlyBudget")
    assert config.value == "100"
```

### Testing Deployments

```python
# tests/test_deploy.py
import pytest
from pulumi import automation as auto

@pytest.mark.integration
@pytest.mark.slow
def test_full_deployment() -> None:
    """Test full infrastructure deployment."""
    # Create ephemeral stack
    stack = auto.create_or_select_stack(
        stack_name="integration-test",
        project_name="my-infrastructure",
    )

    try:
        # Set test config
        stack.set_config("monthlyBudget", auto.ConfigValue(value="50"))

        # Deploy
        up_result = stack.up()

        # Verify deployment
        assert up_result.summary.result == "succeeded"
        assert len(up_result.outputs) > 0

        # Verify outputs
        outputs = up_result.outputs
        assert "api_url" in outputs

    finally:
        # Always cleanup
        stack.destroy()
        stack.workspace.remove_stack("integration-test")
```

## Testing Policies

### CrossGuard Policy Tests

```python
# tests/test_policies.py
import pytest
from typing import Any
from pulumi_policy import (
    EnforcementLevel,
    PolicyPack,
    ResourceValidationArgs,
)

def test_expensive_instance_policy() -> None:
    """Test policy rejects expensive instances in dev."""
    from policies.cost_controls import expensive_instance_validator

    # Mock arguments
    class MockArgs:
        resource_type = "aws:ec2/instance:Instance"
        props = {"instanceType": "r6i.4xlarge"}

    import os
    os.environ["PULUMI_STACK"] = "dev"

    violations = []
    def report_violation(msg: str) -> None:
        violations.append(msg)

    # Run validator
    expensive_instance_validator(MockArgs(), report_violation)  # type: ignore

    # Should have violation
    assert len(violations) > 0
    assert "too expensive" in violations[0].lower()

def test_expensive_instance_allowed_in_production() -> None:
    """Test policy allows expensive instances in production."""
    from policies.cost_controls import expensive_instance_validator

    # Mock arguments
    class MockArgs:
        resource_type = "aws:ec2/instance:Instance"
        props = {"instanceType": "r6i.4xlarge"}

    import os
    os.environ["PULUMI_STACK"] = "production"

    violations = []
    def report_violation(msg: str) -> None:
        violations.append(msg)

    # Run validator
    expensive_instance_validator(MockArgs(), report_violation)  # type: ignore

    # Should have no violations
    assert len(violations) == 0
```

## Testing Best Practices

### Use Fixtures for Common Setup

```python
# tests/conftest.py
import pytest
import os
from typing import Generator

@pytest.fixture(autouse=True)
def mock_pulumi_env() -> Generator[None, None, None]:
    """Mock Pulumi environment for tests."""
    # Save original env
    original_stack = os.environ.get("PULUMI_STACK")

    # Set test defaults
    os.environ["PULUMI_STACK"] = "test"

    yield

    # Restore
    if original_stack:
        os.environ["PULUMI_STACK"] = original_stack
    else:
        os.environ.pop("PULUMI_STACK", None)

@pytest.fixture
def dev_stack() -> Generator[None, None, None]:
    """Set stack to dev."""
    os.environ["PULUMI_STACK"] = "dev"
    yield

@pytest.fixture
def prod_stack() -> Generator[None, None, None]:
    """Set stack to production."""
    os.environ["PULUMI_STACK"] = "production"
    yield
```

### Organize Tests by Concern

```
tests/
├── conftest.py                  # Shared fixtures
├── unit/                        # Unit tests
│   ├── test_components.py
│   ├── test_database.py
│   └── test_web_service.py
├── integration/                 # Integration tests
│   ├── test_deploy_dev.py
│   └── test_deploy_staging.py
├── policies/                    # Policy tests
│   ├── test_cost_controls.py
│   └── test_tagging.py
└── cost/                        # Cost-related tests
    ├── test_budget_limits.py
    └── test_environment_sizing.py
```

### Mark Slow Tests

```python
# pytest.ini or pyproject.toml
[tool.pytest.ini_options]
markers = [
    "integration: Integration tests (slow)",
    "unit: Unit tests (fast)",
    "policy: Policy tests",
]

# Run only fast tests
# pytest -m "not integration"

# Run all tests
# pytest
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/infrastructure-tests.yml
name: Infrastructure Tests

on:
  pull_request:
    paths:
      - 'infrastructure/**'
  push:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd infrastructure
          python -m venv venv
          source venv/bin/activate
          pip install -r requirements.txt
          pip install pytest pytest-cov

      - name: Run unit tests
        run: |
          cd infrastructure
          source venv/bin/activate
          pytest tests/unit -v --cov=components

      - name: Run policy tests
        run: |
          cd infrastructure
          source venv/bin/activate
          pytest tests/policies -v

  integration-tests:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd infrastructure
          python -m venv venv
          source venv/bin/activate
          pip install -r requirements.txt
          pip install pytest

      - name: Run integration tests
        run: |
          cd infrastructure
          source venv/bin/activate
          pytest tests/integration -v
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## Related Documentation

- [Pulumi Guide](pulumi-guide.md) - Core concepts and setup
- [Pulumi Cost Controls](pulumi-cost-controls.md) - CrossGuard policies
- [Financial Governance](financial-governance.md) - Cost management strategies

---

**Key Takeaway**: Test infrastructure code like application code. Use unit tests for components, integration tests for deployments, and policy tests for governance rules. Run fast tests in CI, slow tests before production deploys.
