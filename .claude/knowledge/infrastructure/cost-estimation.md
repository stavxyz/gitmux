# Cost Estimation for Infrastructure

<!--
MAINTENANCE: Review pricing quarterly (March, June, September, December)
Last reviewed: 2025-01
Next review: 2025-04
-->

## When to Use

**Use cost estimation when:**
- Planning new infrastructure deployments
- Making architectural decisions
- Reviewing infrastructure changes in PRs
- Setting budgets for projects
- Comparing cloud providers or services

## Cost Estimation Tools

### Infracost

**Infracost provides automated cost estimates for Terraform and Pulumi:**

```bash
# Install
brew install infracost
# or
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Configure API key (free for individuals/small teams)
infracost auth login

# Generate cost estimate
infracost breakdown --path .

# Compare with baseline
infracost diff --path . --compare-to infracost-base.json

# CI/CD integration
infracost breakdown --path . --format json --out-file infracost.json
```

**Example output:**

```
Project: my-infrastructure

 Name                                     Monthly Qty  Unit   Monthly Cost

 aws_instance.web_server
 ├─ Instance usage (Linux/UNIX, on-demand, t3.medium)  730  hours        $30.37
 └─ root_block_device
    └─ Storage (general purpose SSD, gp3)               50  GB            $4.00

 aws_db_instance.postgres
 ├─ Database instance (on-demand, db.t3.medium)        730  hours        $62.78
 └─ Storage (general purpose SSD, gp3)                 100  GB            $11.50

 OVERALL TOTAL                                                          $108.65
```

### Manual Estimation

**For platforms without Infracost support:**

**1. Use provider pricing calculators:**
- AWS: https://calculator.aws/
- GCP: https://cloud.google.com/products/calculator
- Azure: https://azure.microsoft.com/en-us/pricing/calculator/
- Vercel: https://vercel.com/pricing
- Netlify: https://www.netlify.com/pricing/
- Cloudflare: https://www.cloudflare.com/plans/

**2. Document estimates in infrastructure code:**

```python
"""
Cost Estimate (as of 2025-01):

Production:
- Vercel Pro: $20/month (base)
- Supabase Pro: $25/month (base)
- Cloudflare Workers: ~$5/month (estimated usage)
- Total: ~$50/month baseline

Development:
- Vercel Hobby: $0/month (free tier)
- Supabase Free: $0/month (free tier)
- Cloudflare Workers: ~$0/month (free tier)
- Total: $0/month

Scaling estimates:
- 100K requests/month: ~$50/month
- 1M requests/month: ~$150/month
- 10M requests/month: ~$800/month
"""
```

## Estimation Best Practices

### Include All Cost Components

**Don't forget hidden costs:**

```python
"""
Complete cost breakdown (as of 2025-01):

Compute:
- EC2 instances: $100/month
- Load balancers: $20/month

Storage:
- EBS volumes: $15/month
- S3 storage: $10/month
- S3 requests: $2/month

Data Transfer:
- Outbound data transfer: $30/month (critical!)
- Cross-AZ traffic: $5/month

Databases:
- RDS instance: $60/month
- RDS storage: $10/month
- RDS backups: $5/month

Monitoring & Logs:
- CloudWatch: $10/month
- CloudWatch Logs: $5/month

Total: ~$272/month
"""
```

### Estimate for Different Usage Levels

**Plan for baseline, normal, and peak:**

```python
"""
Usage-based cost estimate (as of 2025-01):

Baseline (10K users, 100K req/month):
- Infrastructure: $150/month
- Bandwidth: $20/month
- Total: ~$170/month

Normal (100K users, 1M req/month):
- Infrastructure: $400/month
- Bandwidth: $80/month
- Total: ~$480/month

Peak (1M users, 10M req/month):
- Infrastructure: $1,200/month
- Bandwidth: $300/month
- Total: ~$1,500/month

Scaling factor: ~3x cost per 10x users
"""
```

### Environment-Specific Estimates

```python
"""
Environment cost breakdown (as of 2025-01):

Development:
- Compute: t3.micro instances = $15/month
- Database: db.t3.micro = $13/month
- Storage: 50 GB = $5/month
- Total: ~$33/month

Staging:
- Compute: t3.small instances = $30/month
- Database: db.t3.small = $26/month
- Storage: 100 GB = $10/month
- Total: ~$66/month

Production:
- Compute: t3.medium instances (2x) = $120/month
- Database: db.t3.large (multi-AZ) = $210/month
- Storage: 500 GB = $50/month
- Load balancer: $20/month
- Backups: $30/month
- Total: ~$430/month

Grand Total: ~$529/month
"""
```

## Cost Estimation Scripts

### Automated Cost Check

```python
#!/usr/bin/env python3
"""
Check if estimated infrastructure cost exceeds threshold.

Cost Estimate (as of 2025-01):
Uses Infracost to estimate monthly costs before deployment.
"""

import json
import os
import sys
from pathlib import Path
from typing import Any


def load_infracost_estimate() -> dict[str, Any]:
    """Load Infracost estimate from JSON file."""
    infracost_file = Path("infracost.json")
    if not infracost_file.exists():
        raise FileNotFoundError("infracost.json not found. Run 'infracost breakdown' first.")

    with open(infracost_file) as f:
        return json.load(f)


def get_budget_threshold() -> int:
    """Get budget threshold from Pulumi config."""
    import pulumi
    config = pulumi.Config()
    return config.get_int("monthlyBudget") or 1000


def check_cost_threshold() -> int:
    """Check if estimated cost exceeds threshold."""
    try:
        data = load_infracost_estimate()
        total_monthly_cost = float(data.get("totalMonthlyCost", 0))
        threshold = get_budget_threshold()

        print(f"Estimated monthly cost: ${total_monthly_cost:.2f}")
        print(f"Budget threshold: ${threshold:.2f}")

        if total_monthly_cost > threshold:
            percentage = (total_monthly_cost / threshold) * 100
            print(f"ERROR: Cost exceeds threshold by {percentage - 100:.1f}%")

            if not os.getenv("SKIP_COST_CHECK"):
                print("To proceed anyway:")
                print("  1. Increase monthlyBudget: pulumi config set monthlyBudget <amount>")
                print("  2. Skip check: export SKIP_COST_CHECK=1")
                return 1

        print(f"✓ Cost estimate within budget ({total_monthly_cost/threshold*100:.1f}% of limit)")
        return 0

    except Exception as e:
        print(f"ERROR: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(check_cost_threshold())
```

### Cost Comparison Script

```python
#!/usr/bin/env python3
"""
Compare costs across environments.

Cost Estimate (as of 2025-01):
Helps identify cost optimization opportunities.
"""

import json
from pathlib import Path
from typing import Any


def compare_stack_costs() -> None:
    """Compare costs across different stacks."""
    stacks = ["dev", "staging", "production"]

    costs: dict[str, float] = {}
    for stack in stacks:
        cost_file = Path(f"infracost-{stack}.json")
        if cost_file.exists():
            with open(cost_file) as f:
                data: dict[str, Any] = json.load(f)
                costs[stack] = float(data.get("totalMonthlyCost", 0))

    print("Cost Comparison:")
    print("-" * 40)

    total = sum(costs.values())
    for stack, cost in sorted(costs.items(), key=lambda x: x[1], reverse=True):
        percentage = (cost / total * 100) if total > 0 else 0
        print(f"{stack:12} ${cost:8.2f}/mo ({percentage:5.1f}%)")

    print("-" * 40)
    print(f"{'TOTAL':12} ${total:8.2f}/mo")

    # Check ratios
    if "production" in costs and "dev" in costs:
        ratio = costs["production"] / costs["dev"] if costs["dev"] > 0 else 0
        print(f"\nProduction/Dev ratio: {ratio:.1f}x")
        if ratio < 5:
            print("⚠️  Warning: Dev environment may be over-provisioned")
        elif ratio > 20:
            print("⚠️  Warning: Production may be under-provisioned")


if __name__ == "__main__":
    compare_stack_costs()
```

## Provider-Specific Pricing

### AWS Cost Factors (as of 2025-01)

**Compute:**
- t3.micro: $0.0104/hour = $7.59/month
- t3.small: $0.0208/hour = $15.18/month
- t3.medium: $0.0416/hour = $30.37/month
- t3.large: $0.0832/hour = $60.74/month

**Database (RDS PostgreSQL):**
- db.t3.micro: $0.018/hour = $13.14/month
- db.t3.small: $0.036/hour = $26.28/month
- db.t3.medium: $0.073/hour = $53.29/month
- db.t3.large: $0.146/hour = $106.58/month
- Multi-AZ: 2x cost

**Storage:**
- gp3: $0.08/GB/month
- io2: $0.125/GB/month + IOPS charges
- S3 Standard: $0.023/GB/month
- S3 Glacier: $0.004/GB/month

**Data Transfer:**
- Inbound: Free
- Outbound (first 100 GB): Free
- Outbound (next 10 TB): $0.09/GB
- Cross-AZ: $0.01/GB each way

### Vercel Pricing (as of 2025-01)

**Hobby (Free):**
- Bandwidth: 100 GB/month
- Build execution: 100 hours/month
- Serverless function execution: 100 GB-hours

**Pro ($20/month):**
- Bandwidth: 1 TB included ($0.15/GB after)
- Build execution: 400 hours included ($40/100 hours after)
- Serverless: 1,000 GB-hours included ($0.18/GB-hour after)

### Supabase Pricing (as of 2025-01)

**Free:**
- 500 MB database
- 1 GB storage
- 50K MAU

**Pro ($25/month):**
- 8 GB database included ($0.125/GB after)
- 100 GB storage included ($0.021/GB after)
- No MAU limits
- 250 GB bandwidth included ($0.09/GB after)

### Cloudflare Pricing (as of 2025-01)

**Free:**
- Unlimited bandwidth (!)
- 100K Workers requests/day
- DNS for unlimited domains

**Workers Paid ($5/month):**
- 10M requests included ($0.50/million after)
- No CPU time limits

**R2 Storage:**
- $0.015/GB/month storage
- $0 egress (!!)

## Related Documentation

- [Financial Governance](financial-governance.md) - Cost management principles
- [Budget Alerts](budget-alerts.md) - Setting up cost alerts
- [Pulumi Cost Controls](pulumi-cost-controls.md) - Policy enforcement

---

**Key Takeaway**: Always estimate costs before deploying infrastructure. Use Infracost for automated estimation, provider calculators for manual estimates, and document all estimates with "as of 2025-01" date stamps. Include all cost components: compute, storage, data transfer, and hidden costs.
