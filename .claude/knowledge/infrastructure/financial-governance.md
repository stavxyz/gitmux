# Financial Governance for Infrastructure as Code

<!--
MAINTENANCE: Review pricing quarterly (March, June, September, December)
Last reviewed: 2025-01
Next review: 2025-04
-->

## When to Use

**ALWAYS** consider financial implications when:
- Provisioning any cloud infrastructure
- Making architectural decisions
- Reviewing infrastructure PRs
- Setting up development/staging environments
- Automating infrastructure deployments

## Quick Reference

```bash
# Estimate cost before deployment
infracost breakdown --path .

# Set up billing alerts (AWS)
pulumi config set cost-alert-threshold 1000  # $1000/month

# Tag resources for cost tracking
pulumi config set project:costCenter "engineering"
pulumi config set project:environment "production"
```

## Why This Matters

**Cloud infrastructure involves real money**:
- Automated deployments can become automated spending
- A single configuration error can cost thousands
- Forgotten dev environments compound costs monthly
- Lack of visibility leads to budget overruns
- AI assistants need financial context for recommendations

## Core Principles

### 1. Estimate Before Deploy

**NEVER deploy infrastructure without cost estimation.**

```yaml
# pulumi/Pulumi.yaml
name: my-infrastructure
runtime: python
description: My infrastructure project

# Pre-deployment hooks
scripts:
  pre-up:
    - infracost breakdown --path . --format json --out-file infracost.json
    - python scripts/check_cost_threshold.py
```

### 2. Cost-Aware by Default

Every infrastructure decision should include:
- **Estimated monthly cost** (baseline, normal, peak)
- **Cost-saving alternatives** for non-production
- **Budget alerts** for the resource type
- **Cleanup automation** to prevent orphaned resources

### 3. Tag Everything

**Cost allocation requires consistent tagging:**

```python
"""
Cost allocation tagging (as of 2025-01).

Ensures all resources have proper tags for cost tracking.
"""

from typing import Any
import pulumi


# Standard cost allocation tags
def get_default_tags() -> dict[str, str]:
    """Get default cost allocation tags."""
    return {
        "CostCenter": pulumi.Config().get("costCenter") or "engineering",
        "Environment": pulumi.get_stack(),  # dev, staging, production
        "Project": pulumi.get_project(),
        "ManagedBy": "pulumi",
        "Owner": pulumi.Config().get("owner") or "platform-team",
    }


# Apply to all resources
def auto_tag_transform(args: pulumi.ResourceTransformationArgs) -> pulumi.ResourceTransformationResult:
    """Auto-tag resources with cost allocation tags."""
    if args.type_.startswith("aws:") or args.type_.startswith("gcp:"):
        default_tags = get_default_tags()

        # Merge with existing tags
        if "tags" in args.props:
            args.props["tags"] = {**default_tags, **args.props["tags"]}
        elif "labels" in args.props:  # GCP uses labels
            args.props["labels"] = {**default_tags, **args.props["labels"]}
        else:
            args.props["tags"] = default_tags

    return pulumi.ResourceTransformationResult(args.props, args.opts)


pulumi.runtime.register_stack_transformation(auto_tag_transform)
```

> ⚠️ **Security Warning**: Never commit API tokens to git. Always use Pulumi secrets or environment variables.

### 4. Monitor and Alert

**Set up billing alerts BEFORE resources go live:**

See [Budget Alerts](budget-alerts.md) for detailed configuration examples for AWS, GCP, and Azure.

## Cost Optimization Patterns

### Development vs Production

**ALWAYS use cheaper alternatives for non-production:**

```python
"""
Environment-specific sizing (as of 2025-01).

Cost Estimate:
- Dev: ~$50/month
- Staging: ~$200/month
- Production: ~$1000/month
"""

import pulumi

stack = pulumi.get_stack()
is_production = stack == "production"

# Database sizing
db_instance_class = "db.t3.medium" if is_production else "db.t3.micro"

# Auto-scaling
min_instances = 2 if is_production else 1
max_instances = 10 if is_production else 2

# Backup retention
backup_retention_days = 30 if is_production else 7

# High availability
enable_multi_az = is_production  # Multi-AZ costs 2x

# Storage tier
storage_class = "gp3" if is_production else "gp2"  # gp3 is cheaper for production workloads
```

### Auto-Shutdown for Dev Environments

```python
"""
Auto-shutdown for dev instances (as of 2025-01).

Cost Savings:
- Shutting down dev instances overnight saves ~60% on compute costs
- Example: $720/month -> $288/month for 24/7 dev instance
"""

import pulumi
import pulumi_aws as aws
from typing import Any


def create_dev_shutdown_schedule(lambda_role: aws.iam.Role) -> tuple[aws.lambda_.Function, aws.lambda_.Function]:
    """Create Lambda functions to shut down/start dev instances."""
    # Lambda function to stop dev instances at night
    shutdown_lambda = aws.lambda_.Function(
        "dev-instance-shutdown",
        runtime="python3.11",
        handler="index.handler",
        role=lambda_role.arn,
        code=pulumi.AssetArchive({
            ".": pulumi.FileArchive("./lambda/shutdown"),
        }),
        environment=aws.lambda_.FunctionEnvironmentArgs(
            variables={
                "ENVIRONMENT": "dev",
            },
        ),
    )

    # CloudWatch Event Rule: Stop at 6 PM weekdays
    aws.cloudwatch.EventRule(
        "dev-shutdown-schedule",
        description="Stop dev instances at 6 PM on weekdays",
        schedule_expression="cron(0 18 ? * MON-FRI *)",  # 6 PM UTC
        event_targets=[
            aws.cloudwatch.EventTargetArgs(
                arn=shutdown_lambda.arn,
            ),
        ],
    )

    # Lambda function to start instances
    startup_lambda = aws.lambda_.Function(
        "dev-instance-startup",
        runtime="python3.11",
        handler="index.handler",
        role=lambda_role.arn,
        code=pulumi.AssetArchive({
            ".": pulumi.FileArchive("./lambda/startup"),
        }),
    )

    # CloudWatch Event Rule: Start at 8 AM weekdays
    aws.cloudwatch.EventRule(
        "dev-startup-schedule",
        description="Start dev instances at 8 AM on weekdays",
        schedule_expression="cron(0 8 ? * MON-FRI *)",  # 8 AM UTC
        event_targets=[
            aws.cloudwatch.EventTargetArgs(
                arn=startup_lambda.arn,
            ),
        ],
    )

    return shutdown_lambda, startup_lambda
```

### Spot Instances / Preemptible VMs

```python
"""
Spot instance configuration (as of 2025-01).

Cost Savings:
- Spot instances typically 60-90% cheaper than on-demand
- Example: c5.xlarge on-demand $0.17/hr -> spot $0.05/hr
"""

import pulumi_aws as aws

# Use spot instances for non-critical workloads
spot_instance = aws.ec2.Instance(
    "batch-processor-spot",
    instance_type="c5.xlarge",
    ami="ami-12345678",
    # Spot instance configuration
    instance_market_options=aws.ec2.InstanceInstanceMarketOptionsArgs(
        market_type="spot",
        spot_options=aws.ec2.InstanceInstanceMarketOptionsSpotOptionsArgs(
            max_price="0.10",  # Maximum hourly price
            spot_instance_type="one-time",
            instance_interruption_behavior="terminate",
        ),
    ),
    tags={
        "Name": "batch-processor-spot",
        "CostOptimized": "spot-instance",
    },
)
```

### Storage Lifecycle Policies

```python
"""
S3 lifecycle rules (as of 2025-01).

Cost Savings:
- Standard: $0.023/GB/month
- Standard-IA: $0.0125/GB/month
- Glacier: $0.004/GB/month
- Deep Archive: $0.00099/GB/month
"""

import pulumi_aws as aws

# S3 bucket with lifecycle rules
bucket = aws.s3.Bucket(
    "data-archive",
    lifecycle_rules=[
        # Move to Infrequent Access after 30 days
        aws.s3.BucketLifecycleRuleArgs(
            enabled=True,
            transitions=[
                aws.s3.BucketLifecycleRuleTransitionArgs(
                    days=30,
                    storage_class="STANDARD_IA",
                ),
                # Move to Glacier after 90 days
                aws.s3.BucketLifecycleRuleTransitionArgs(
                    days=90,
                    storage_class="GLACIER",
                ),
                # Move to Deep Archive after 365 days
                aws.s3.BucketLifecycleRuleTransitionArgs(
                    days=365,
                    storage_class="DEEP_ARCHIVE",
                ),
            ],
            expiration=aws.s3.BucketLifecycleRuleExpirationArgs(
                days=2555,  # Delete after 7 years
            ),
        ),
    ],
)
```

## Cost Monitoring

### Daily Cost Reports

```python
"""
AWS cost reporting (as of 2025-01).

Uses AWS Cost Explorer API to track daily costs.
"""

import boto3
from datetime import datetime, timedelta
from typing import Any


def get_daily_costs() -> list[dict[str, Any]]:
    """Get cost for last 7 days."""
    ce = boto3.client('ce', region_name='us-east-1')

    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d'),
            'End': datetime.now().strftime('%Y-%m-%d'),
        },
        Granularity='DAILY',
        Metrics=['UnblendedCost'],
        GroupBy=[
            {'Type': 'TAG', 'Key': 'Environment'},
            {'Type': 'TAG', 'Key': 'CostCenter'},
        ],
    )

    results = []
    for result in response['ResultsByTime']:
        results.append({
            'date': result['TimePeriod']['Start'],
            'cost': float(result['Total']['UnblendedCost']['Amount']),
        })

    return results
```

## Common Cost Pitfalls

### 1. Forgotten Resources

**Problem**: Orphaned resources running indefinitely

**Solution**: Automatic tagging and cleanup

```python
"""
Resource cleanup tracking (as of 2025-01).

Tags resources with creation timestamp for automatic cleanup.
"""

import pulumi
from datetime import datetime

# Tag all resources with creation timestamp
creation_timestamp = datetime.now().isoformat()

# Policy: Delete resources older than 30 days in dev
if pulumi.get_stack() == "dev":
    # Add termination protection = False
    # Use AWS Config rule or Lambda to auto-delete old resources
    pass
```

### 2. Data Transfer Costs

**Problem**: Cross-region or outbound data transfer

**Solution**: Keep data in same region, use CDN

```python
# BAD: Cross-region data transfer ($0.02/GB)
database_region = "us-east-1"
app_region = "eu-west-1"  # Expensive cross-region traffic

# GOOD: Same region ($0/GB internal)
database_region = "us-east-1"
app_region = "us-east-1"

# Use CloudFront/Cloudflare for global distribution
```

### 3. Over-Provisioned Databases

**Problem**: Using larger instances than needed

**Solution**: Right-size based on metrics

```python
"""
Database sizing (as of 2025-01).

Cost Estimate:
- db.t3.micro: $13/month
- db.t3.small: $26/month
- db.t3.medium: $52/month
- db.t3.large: $104/month
"""

import pulumi

# Start small in dev
db_instance_class_map = {
    "dev": "db.t3.micro",
    "staging": "db.t3.small",
    "production": "db.t3.medium",
}

db_instance_class = db_instance_class_map[pulumi.get_stack()]
```

### 4. Missing Reserved Instance Purchases

**Problem**: Paying on-demand prices for long-running workloads

**Solution**: Purchase Reserved Instances for stable workloads

**Cost Savings (as of 2025-01)**:
```
Reserved Instance Recommendations (based on 90-day usage):

1. Web servers (3x t3.medium, us-east-1)
   - Current cost: $65.66/month on-demand
   - RI cost: $39.42/month (1-year, no upfront)
   - Savings: $26.24/month (40%)

2. Database (1x db.t3.large, us-east-1)
   - Current cost: $104.48/month on-demand
   - RI cost: $62.69/month (1-year, no upfront)
   - Savings: $41.79/month (40%)

Total potential savings: $816.36/year
```

### 5. Unnecessary High Availability

**Problem**: Multi-AZ deployment in dev/staging

**Solution**: Single-AZ for non-production

```python
"""
High availability configuration (as of 2025-01).

Cost Impact:
- Single-AZ: 1x cost
- Multi-AZ: 2x cost (doubles database costs)
"""

import pulumi
import pulumi_aws as aws

# Production: High availability
enable_multi_az = pulumi.get_stack() == "production"

# Development: Single AZ (50% cost savings)
db = aws.rds.Instance(
    "database",
    instance_class="db.t3.medium",
    allocated_storage=100,
    engine="postgres",
    multi_az=enable_multi_az,  # Only production
)
```

## AI Assistant Guidelines

### Before Recommending Infrastructure

**ALWAYS include:**
1. **Estimated monthly cost** (baseline, normal, peak) with date stamp
2. **Cost comparison** with alternatives
3. **Cost-saving options** for dev/staging
4. **Budget alert recommendations**

### Example Response Format

```
I recommend using AWS RDS PostgreSQL for this use case.

**Cost Estimate (as of 2025-01):**
- Development: ~$13/month (db.t3.micro, single-AZ)
- Production: ~$105/month (db.t3.large, multi-AZ)

**Cost-Saving Options:**
- Use Aurora Serverless v2 for variable workloads ($43-100/month)
- Use managed Supabase instead ($0-25/month for small apps)

**Budget Alert:**
Set CloudWatch billing alarm at $150/month to catch anomalies early.

**Implementation:**
[Pulumi code here]
```

### Cost-Conscious Decision Making

When choosing between options, factor in:
- **Total Cost of Ownership** (not just infrastructure)
- **Hidden costs** (data transfer, API calls, storage)
- **Scaling costs** (what happens at 10x, 100x usage)
- **Operational costs** (maintenance, monitoring, backups)

## Related Documentation

- [Cost Estimation](cost-estimation.md) - Detailed cost estimation guides
- [Budget Alerts](budget-alerts.md) - AWS, GCP, Azure alert configurations
- [Pulumi Guide](pulumi-guide.md) - Infrastructure as code basics
- [Pulumi Cost Controls](pulumi-cost-controls.md) - CrossGuard policies

---

**Key Takeaway**: Cloud infrastructure is real money. Always estimate costs before deploying, set up budget alerts, and optimize for the environment (dev/staging/production). All cost estimates should include "as of 2025-01" date stamps.
