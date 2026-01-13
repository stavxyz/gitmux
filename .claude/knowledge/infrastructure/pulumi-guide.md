# Pulumi Guide: Infrastructure as Code with Python

## When to Use

**Use Pulumi when:**
- Python is your primary language (leverage existing skills)
- You need type safety and IDE support
- You want to test infrastructure code with pytest
- You need to integrate infrastructure with application code
- You're building multi-cloud or complex architectures

## Why Pulumi for Python Shops

**Advantages over Terraform:**
- Write in Python, not HCL (new language to learn)
- Full programming language features (loops, functions, classes)
- Type hints and IDE autocomplete
- Test with pytest, not specialized tools
- Share code between infrastructure and application
- Better secrets management
- Native async/await support

**Trade-offs:**
- Smaller community than Terraform
- Fewer pre-built modules
- State management requires Pulumi Cloud or self-hosted backend

## Quick Start

```bash
# Install Pulumi CLI
curl -fsSL https://get.pulumi.com | sh

# Login to Pulumi Cloud (free for individuals)
pulumi login

# Or use local state
pulumi login --local

# Create new project
mkdir my-infrastructure && cd my-infrastructure
pulumi new python --name my-infrastructure

# Install dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Deploy
pulumi up
```

## Project Structure

```
my-infrastructure/
├── Pulumi.yaml              # Project definition
├── Pulumi.dev.yaml          # Dev stack config
├── Pulumi.production.yaml   # Production stack config
├── __main__.py              # Entry point
├── components/              # Reusable components
│   ├── __init__.py
│   ├── web_service.py       # Web service component
│   └── database.py          # Database component
├── policies/                # Pulumi CrossGuard policies
│   ├── __init__.py
│   └── cost_controls.py     # Cost limit policies
├── scripts/                 # Helper scripts
│   └── check_cost_threshold.py
├── tests/                   # Infrastructure tests
│   ├── test_web_service.py
│   └── test_cost_estimates.py
├── requirements.txt         # Python dependencies
└── venv/                    # Virtual environment
```

## Core Concepts

### Resources

**Resources are infrastructure components:**

```python
from typing import Any
import pulumi
import pulumi_aws as aws

# Simple resource
bucket = aws.s3.Bucket(
    "my-bucket",
    acl="private",
    versioning=aws.s3.BucketVersioningArgs(enabled=True),
    tags={
        "Environment": pulumi.get_stack(),
        "ManagedBy": "pulumi",
    },
)

# Export outputs
pulumi.export("bucket_name", bucket.id)
pulumi.export("bucket_arn", bucket.arn)
```

### Stacks

**Stacks are isolated environments:**

```bash
# Create stacks
pulumi stack init dev
pulumi stack init staging
pulumi stack init production

# Switch between stacks
pulumi stack select dev

# List stacks
pulumi stack ls
```

**Stack-specific configuration:**

```python
import pulumi

# Get stack name
stack = pulumi.get_stack()

# Stack-specific sizing
db_instance_class = {
    "dev": "db.t3.micro",
    "staging": "db.t3.small",
    "production": "db.t3.large",
}[stack]

# Stack-specific features
enable_multi_az = stack == "production"
backup_retention = 30 if stack == "production" else 7
```

### Configuration

**Manage secrets and config:**

```bash
# Set configuration
pulumi config set database:instanceClass db.t3.medium
pulumi config set --secret database:password <password>

# Set stack-specific config
pulumi config set costCenter engineering
pulumi config set owner platform-team
```

**Access in code:**

```python
import pulumi

config = pulumi.Config()

# Required config
db_password = config.require_secret("password")

# Optional config with defaults
db_instance_class = config.get("instanceClass") or "db.t3.micro"
cost_center = config.get("costCenter") or "engineering"
```

### Outputs

**Export values for consumption:**

```python
import pulumi

# Export simple values
pulumi.export("api_url", f"https://{domain_name}")

# Export complex objects
pulumi.export("database", {
    "host": db.endpoint,
    "port": db.port,
    "name": db.name,
})

# Use outputs in other stacks
stack_ref = pulumi.StackReference(f"org/project/production")
prod_db_host = stack_ref.get_output("database")["host"]
```

## Python Best Practices

### Type Hints

```python
from typing import Optional, Any
import pulumi
import pulumi_aws as aws

def create_bucket(
    name: str,
    *,  # Force keyword arguments
    versioning: bool = False,
    lifecycle_rules: Optional[list[aws.s3.BucketLifecycleRuleArgs]] = None,
    tags: Optional[dict[str, str]] = None,
) -> aws.s3.Bucket:
    """Create S3 bucket with standard configuration.

    Args:
        name: Bucket name (must be globally unique)
        versioning: Enable versioning (default: False)
        lifecycle_rules: Optional lifecycle rules
        tags: Resource tags

    Returns:
        S3 Bucket resource
    """
    return aws.s3.Bucket(
        name,
        versioning=aws.s3.BucketVersioningArgs(enabled=versioning) if versioning else None,
        lifecycle_rules=lifecycle_rules or [],
        tags={
            **get_default_tags(),
            **(tags or {}),
        },
    )

def get_default_tags() -> dict[str, str]:
    """Get default resource tags."""
    return {
        "Environment": pulumi.get_stack(),
        "ManagedBy": "pulumi",
    }
```

### Component Resources

**Encapsulate related resources:**

```python
import pulumi
import pulumi_aws as aws
from typing import Optional

class WebService(pulumi.ComponentResource):
    """Web service with ALB, ECS, and auto-scaling.

    Cost Estimate (as of 2025-01):
    - Dev: ~$30/month (1 task, t3.micro)
    - Production: ~$150/month (2-10 tasks, t3.small)
    """

    def __init__(
        self,
        name: str,
        *,
        vpc_id: pulumi.Input[str],
        subnet_ids: pulumi.Input[list[str]],
        container_image: pulumi.Input[str],
        container_port: int = 8080,
        min_tasks: int = 1,
        max_tasks: int = 3,
        opts: Optional[pulumi.ResourceOptions] = None,
    ) -> None:
        super().__init__("custom:WebService", name, {}, opts)

        # ALB
        self.alb = aws.lb.LoadBalancer(
            f"{name}-alb",
            load_balancer_type="application",
            subnets=subnet_ids,
            tags=get_default_tags(),
            opts=pulumi.ResourceOptions(parent=self),
        )

        # ECS Cluster
        self.cluster = aws.ecs.Cluster(
            f"{name}-cluster",
            tags=get_default_tags(),
            opts=pulumi.ResourceOptions(parent=self),
        )

        # Register outputs
        self.register_outputs({
            "alb_dns_name": self.alb.dns_name,
            "cluster_arn": self.cluster.arn,
        })

def get_default_tags() -> dict[str, str]:
    """Get default resource tags."""
    return {
        "Environment": pulumi.get_stack(),
        "ManagedBy": "pulumi",
    }
```

### Configuration Management

**Centralized configuration:**

```python
from dataclasses import dataclass
from typing import Any
import pulumi

@dataclass
class AppConfig:
    """Application configuration."""

    # Environment
    stack: str
    environment: str

    # Cost tracking
    cost_center: str
    owner: str

    # Database
    db_instance_class: str
    db_allocated_storage: int
    db_multi_az: bool
    db_backup_retention_days: int

    # Web service
    web_min_tasks: int
    web_max_tasks: int

    # Cost thresholds
    monthly_budget_usd: int
    cost_alert_threshold_pct: int = 80

    @classmethod
    def from_pulumi_config(cls) -> "AppConfig":
        """Load configuration from Pulumi config and stack."""
        config = pulumi.Config()
        stack = pulumi.get_stack()

        # Environment-specific defaults
        is_production = stack == "production"

        return cls(
            stack=stack,
            environment=config.get("environment") or stack,
            cost_center=config.get("costCenter") or "engineering",
            owner=config.get("owner") or "platform-team",
            db_instance_class=config.get("dbInstanceClass") or ("db.t3.large" if is_production else "db.t3.micro"),
            db_allocated_storage=config.get_int("dbStorage") or (100 if is_production else 20),
            db_multi_az=config.get_bool("dbMultiAz") if config.get("dbMultiAz") else is_production,
            db_backup_retention_days=config.get_int("dbBackupRetention") or (30 if is_production else 7),
            web_min_tasks=config.get_int("webMinTasks") or (2 if is_production else 1),
            web_max_tasks=config.get_int("webMaxTasks") or (10 if is_production else 3),
            monthly_budget_usd=config.require_int("monthlyBudget"),
            cost_alert_threshold_pct=config.get_int("costAlertThreshold") or 80,
        )

# Usage in __main__.py
app_config = AppConfig.from_pulumi_config()
```

## Common Patterns

### Environment-Specific Configuration

```python
import pulumi

stack = pulumi.get_stack()
is_prod = stack == "production"

# Sizing
instance_type = "t3.large" if is_prod else "t3.micro"
min_instances = 2 if is_prod else 1
max_instances = 10 if is_prod else 3

# Features
enable_multi_az = is_prod
enable_encryption = True  # Always encrypt
backup_retention = 30 if is_prod else 7

# Costs
enable_spot_instances = not is_prod  # Spot for dev/staging only
```

### Secrets Management

```python
import pulumi
import pulumi_aws as aws

# Store secrets in Pulumi config
config = pulumi.Config()
db_password = config.require_secret("dbPassword")

# Or use AWS Secrets Manager
secret = aws.secretsmanager.Secret(
    "db-password",
    description="Database password",
)

secret_version = aws.secretsmanager.SecretVersion(
    "db-password-version",
    secret_id=secret.id,
    secret_string=db_password,
)

# Reference in database
database = aws.rds.Instance(
    "database",
    password=db_password,  # Pulumi marks this as secret automatically
)
```

> ⚠️ **Security Warning**: Never commit API tokens to git. Always use Pulumi secrets or environment variables.

### Multi-Stack References

```python
import pulumi

# Reference outputs from another stack
shared_stack = pulumi.StackReference("my-org/shared-infrastructure/production")

# Get VPC from shared stack
vpc_id = shared_stack.get_output("vpc_id")
private_subnet_ids = shared_stack.get_output("private_subnet_ids")

# Use in current stack
app_service = create_app_service(
    vpc_id=vpc_id,
    subnet_ids=private_subnet_ids,
)
```

## Troubleshooting

### State Conflicts

```bash
# View state
pulumi stack export

# Recover from failed deployment
pulumi cancel

# Refresh state
pulumi refresh

# Import existing resource
pulumi import aws:s3/bucket:Bucket my-bucket my-bucket-name
```

### Cost Overruns

```bash
# Check current month's cost (AWS)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost

# List expensive resources
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "7 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## Related Documentation

- [Pulumi Testing](pulumi-testing.md) - Testing infrastructure code
- [Pulumi Cost Controls](pulumi-cost-controls.md) - CrossGuard policies and cost management
- [Financial Governance](financial-governance.md) - Cost estimation and budget alerts
- [Managing IaC Playbook](../../playbooks/managing-infrastructure-as-code.md) - Complete workflow

---

**Key Takeaway**: Use Pulumi with Python for type-safe, testable infrastructure code. Always integrate cost controls via Infracost, CrossGuard policies, and proper tagging.
