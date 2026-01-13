# Pulumi Cost Controls: Financial Governance with CrossGuard

## When to Use

**Use cost controls when:**
- Managing cloud infrastructure with budget constraints
- Deploying infrastructure across multiple environments
- Preventing accidental overspending
- Enforcing organizational cost policies
- Automating infrastructure deployments

## Cost Control Strategies

### 1. Pre-Deployment Cost Estimation

**Estimate costs before deploying:**

```yaml
# Pulumi.yaml
name: my-infrastructure
runtime:
  name: python
  options:
    virtualenv: venv

description: Infrastructure with cost controls

# Pre-deployment hooks
scripts:
  pre-up:
    - infracost breakdown --path . --format json --out-file infracost.json
    - python scripts/check_cost_threshold.py
```

**scripts/check_cost_threshold.py:**

```python
#!/usr/bin/env python3
"""Check if estimated infrastructure cost exceeds threshold.

Cost Estimate (as of 2025-01):
Uses Infracost to estimate monthly costs before deployment.
"""

import json
import os
import sys
from pathlib import Path
from typing import Any


def main() -> int:
    """Check cost threshold."""
    # Load Infracost estimate
    infracost_file = Path("infracost.json")
    if not infracost_file.exists():
        print("ERROR: infracost.json not found. Run 'infracost breakdown' first.")
        return 1

    try:
        with open(infracost_file) as f:
            data: dict[str, Any] = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"ERROR: Failed to load infracost.json: {e}")
        return 1

    # Get total monthly cost
    total_monthly_cost = float(data.get("totalMonthlyCost", 0))

    # Load threshold from Pulumi config
    import pulumi
    config = pulumi.Config()
    threshold = config.get_int("monthlyBudget") or 1000

    print(f"Estimated monthly cost: ${total_monthly_cost:.2f}")
    print(f"Budget threshold: ${threshold:.2f}")

    if total_monthly_cost > threshold:
        print(f"ERROR: Estimated cost ${total_monthly_cost:.2f} exceeds threshold ${threshold:.2f}")
        print("To proceed anyway, increase monthlyBudget config or skip with SKIP_COST_CHECK=1")
        if not os.getenv("SKIP_COST_CHECK"):
            return 1

    print("✓ Cost estimate within budget")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

### 2. Policy as Code with CrossGuard

**Enforce cost policies automatically:**

**policies/cost_controls.py:**

```python
"""
Cost governance policies for Pulumi.

Cost Estimate (as of 2025-01):
Prevents expensive instance types in non-production environments.
"""

import os
from typing import Any
from pulumi_policy import (
    EnforcementLevel,
    PolicyPack,
    ResourceValidationPolicy,
    ResourceValidationArgs,
)


def expensive_instance_validator(
    args: ResourceValidationArgs,
    report_violation: Any
) -> None:
    """Prevent expensive instance types in non-production."""
    if args.resource_type in ["aws:ec2/instance:Instance", "aws:rds/instance:Instance"]:
        instance_class = args.props.get("instanceClass") or args.props.get("instanceType")

        if not instance_class:
            return

        # Get stack from environment
        stack = os.getenv("PULUMI_STACK", "unknown")

        # Expensive instance types
        expensive_classes = ["r6g", "r6i", "r5", "x1", "x2", "db.r6", "db.r5", "db.x1"]

        if stack != "production" and any(str(instance_class).startswith(ec) for ec in expensive_classes):
            report_violation(
                f"Instance class '{instance_class}' is too expensive for {stack} environment. "
                f"Use t3/t4g instances for dev/staging."
            )


def untagged_resource_validator(
    args: ResourceValidationArgs,
    report_violation: Any
) -> None:
    """Ensure all resources have required cost allocation tags."""
    # Resources that support tagging
    taggable_types = [
        "aws:ec2/instance:Instance",
        "aws:rds/instance:Instance",
        "aws:s3/bucket:Bucket",
        "aws:dynamodb/table:Table",
        "aws:ecs/cluster:Cluster",
        "aws:lb/loadBalancer:LoadBalancer",
    ]

    if args.resource_type in taggable_types:
        tags = args.props.get("tags") or {}

        required_tags = ["Environment", "CostCenter", "ManagedBy"]
        missing_tags = [tag for tag in required_tags if tag not in tags]

        if missing_tags:
            report_violation(
                f"Resource missing required cost allocation tags: {', '.join(missing_tags)}"
            )


def multi_az_in_dev_validator(
    args: ResourceValidationArgs,
    report_violation: Any
) -> None:
    """Prevent expensive multi-AZ deployment in dev/staging."""
    if args.resource_type == "aws:rds/instance:Instance":
        stack = os.getenv("PULUMI_STACK", "unknown")

        multi_az = args.props.get("multiAz", False)

        if stack in ["dev", "staging"] and multi_az:
            report_violation(
                f"Multi-AZ is expensive (2x cost) and not needed for {stack} environment."
            )


def backup_retention_validator(
    args: ResourceValidationArgs,
    report_violation: Any
) -> None:
    """Ensure appropriate backup retention for environment."""
    if args.resource_type == "aws:rds/instance:Instance":
        stack = os.getenv("PULUMI_STACK", "unknown")
        retention = args.props.get("backupRetentionDays", 0)

        if stack == "production" and retention < 30:
            report_violation(
                f"Production databases must have >= 30 days backup retention (got {retention})"
            )
        elif stack in ["dev", "staging"] and retention > 7:
            report_violation(
                f"{stack.capitalize()} databases should use <= 7 days backup retention to save costs (got {retention})"
            )


PolicyPack(
    name="cost-governance",
    enforcement_level=EnforcementLevel.MANDATORY,
    policies=[
        ResourceValidationPolicy(
            name="expensive-instances",
            description="Prevent expensive instance types in non-production",
            validate=expensive_instance_validator,
        ),
        ResourceValidationPolicy(
            name="required-tags",
            description="Ensure cost allocation tags are present",
            validate=untagged_resource_validator,
        ),
        ResourceValidationPolicy(
            name="no-multi-az-in-dev",
            description="Prevent multi-AZ in dev/staging",
            validate=multi_az_in_dev_validator,
        ),
        ResourceValidationPolicy(
            name="backup-retention",
            description="Enforce appropriate backup retention",
            validate=backup_retention_validator,
        ),
    ],
)
```

**Enable policies:**

```bash
# Run with policies
pulumi up --policy-pack policies/

# Or configure in Pulumi.yaml
config:
  pulumi:policies:
    - policies/
```

### 3. Auto-Tagging Transformation

**Automatically tag all resources:**

```python
"""
Auto-tagging transformation for cost tracking.

Cost Estimate (as of 2025-01):
Applies cost allocation tags to all resources automatically.
"""

from typing import Any
import pulumi


def auto_tag_transform(args: pulumi.ResourceTransformationArgs) -> pulumi.ResourceTransformationResult:
    """Automatically add cost allocation tags to all resources."""
    if args.type_.startswith("aws:"):
        # Default tags
        default_tags: dict[str, str] = {
            "Environment": pulumi.get_stack(),
            "Project": pulumi.get_project(),
            "ManagedBy": "pulumi",
            "CostCenter": pulumi.Config().get("costCenter") or "engineering",
            "Owner": pulumi.Config().get("owner") or "platform-team",
        }

        # Merge with existing tags
        if "tags" in args.props:
            args.props["tags"] = {**default_tags, **args.props["tags"]}
        else:
            args.props["tags"] = default_tags

    return pulumi.ResourceTransformationResult(args.props, args.opts)


# Register transformation
pulumi.runtime.register_stack_transformation(auto_tag_transform)
```

### 4. Environment-Specific Sizing

**Right-size resources for each environment:**

```python
"""
Environment-specific resource sizing.

Cost Estimate (as of 2025-01):
- Dev: ~$50/month (minimal resources)
- Staging: ~$200/month (mid-tier resources)
- Production: ~$1000/month (full-scale resources)
"""

from dataclasses import dataclass
from typing import Any
import pulumi


@dataclass
class EnvironmentConfig:
    """Environment-specific configuration."""

    # Database
    db_instance_class: str
    db_allocated_storage: int
    db_multi_az: bool
    db_backup_retention_days: int

    # Compute
    instance_type: str
    min_instances: int
    max_instances: int

    # Storage
    storage_tier: str

    @classmethod
    def for_stack(cls, stack: str) -> "EnvironmentConfig":
        """Get configuration for stack."""
        configs: dict[str, EnvironmentConfig] = {
            "dev": cls(
                db_instance_class="db.t3.micro",
                db_allocated_storage=20,
                db_multi_az=False,
                db_backup_retention_days=7,
                instance_type="t3.micro",
                min_instances=1,
                max_instances=2,
                storage_tier="gp2",
            ),
            "staging": cls(
                db_instance_class="db.t3.small",
                db_allocated_storage=50,
                db_multi_az=False,
                db_backup_retention_days=7,
                instance_type="t3.small",
                min_instances=1,
                max_instances=3,
                storage_tier="gp3",
            ),
            "production": cls(
                db_instance_class="db.t3.large",
                db_allocated_storage=100,
                db_multi_az=True,
                db_backup_retention_days=30,
                instance_type="t3.medium",
                min_instances=2,
                max_instances=10,
                storage_tier="gp3",
            ),
        }

        return configs.get(stack, configs["dev"])


# Usage
env_config = EnvironmentConfig.for_stack(pulumi.get_stack())
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/infrastructure.yml
name: Infrastructure

on:
  pull_request:
    paths:
      - 'infrastructure/**'
  push:
    branches: [main]

jobs:
  cost-check:
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

      - name: Setup Infracost
        uses: infracost/actions/setup@v2
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Generate cost estimate
        run: |
          cd infrastructure
          infracost breakdown --path . --format json --out-file infracost.json

      - name: Check cost threshold
        run: |
          cd infrastructure
          source venv/bin/activate
          python scripts/check_cost_threshold.py

      - name: Comment PR with cost estimate
        uses: infracost/actions/comment@v2
        with:
          path: infrastructure/infracost.json
          github-token: ${{ secrets.GITHUB_TOKEN }}

  policy-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Pulumi policy check
        uses: pulumi/actions@v4
        with:
          command: preview
          stack-name: dev
          policy-pack: infrastructure/policies/
        env:
          PULUMI_ACCESS_TOKEN: ${{ secrets.PULUMI_ACCESS_TOKEN }}
```

## Monitoring and Alerts

### Cost Anomaly Detection

```python
"""
Cost anomaly detection setup.

Cost Estimate (as of 2025-01):
AWS Cost Anomaly Detection: Free
"""

import pulumi_aws as aws

# Enable AWS Cost Anomaly Detection
cost_anomaly_monitor = aws.ce.AnomalyMonitor(
    "cost-anomaly-monitor",
    monitor_name="DailyCostMonitor",
    monitor_type="DIMENSIONAL",
    monitor_dimension="SERVICE",
)

cost_anomaly_subscription = aws.ce.AnomalySubscription(
    "cost-anomaly-alerts",
    subscription_name="TeamAlerts",
    threshold_expression=aws.ce.AnomalySubscriptionThresholdExpressionArgs(
        dimension=aws.ce.AnomalySubscriptionThresholdExpressionDimensionArgs(
            key="ANOMALY_TOTAL_IMPACT_ABSOLUTE",
            values=["100"],  # Alert if anomaly > $100
            match_options=["GREATER_THAN_OR_EQUAL"],
        ),
    ),
    frequency="DAILY",
    monitor_arn_lists=[cost_anomaly_monitor.arn],
    subscribers=[
        aws.ce.AnomalySubscriptionSubscriberArgs(
            type="EMAIL",
            address="devops@example.com",
        ),
    ],
)
```

## Best Practices

### 1. Always Estimate Before Deploying

```bash
# Run cost estimation
infracost breakdown --path .

# Check against threshold
python scripts/check_cost_threshold.py

# Then deploy
pulumi up
```

### 2. Use Policies for All Stacks

```bash
# Enable policies for all deployments
pulumi up --policy-pack policies/
```

### 3. Tag Everything

```python
# Use auto-tagging transformation
pulumi.runtime.register_stack_transformation(auto_tag_transform)
```

### 4. Monitor Regularly

```bash
# Weekly cost check
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "7 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost
```

## Related Documentation

- [Pulumi Guide](pulumi-guide.md) - Core concepts and setup
- [Pulumi Testing](pulumi-testing.md) - Testing infrastructure code
- [Financial Governance](financial-governance.md) - Comprehensive cost management
- [Managing IaC Playbook](../../playbooks/managing-infrastructure-as-code.md) - Complete workflow

---

**Key Takeaway**: Cost controls prevent overspending through pre-deployment estimation, policy enforcement, auto-tagging, and environment-specific sizing. Always estimate costs before deploying and enforce policies via CrossGuard.
