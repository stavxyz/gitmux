# Budget Alerts for Cloud Infrastructure

<!--
MAINTENANCE: Review pricing quarterly (March, June, September, December)
Last reviewed: 2025-01
Next review: 2025-04
-->

## When to Use

**Set up budget alerts when:**
- Deploying any cloud infrastructure
- Before resources go live
- Managing multiple environments
- Working with auto-scaling resources
- Using consumption-based pricing

> ⚠️ **Critical**: Always set up budget alerts BEFORE deploying infrastructure, not after.

## AWS Budget Alerts

### CloudWatch Billing Alarms

```python
"""
AWS billing alarms (as of 2025-01).

Sets up alerts at 50%, 80%, and 100% of monthly budget.
"""

from typing import Any
import pulumi
import pulumi_aws as aws


def create_billing_alarms(budget_usd: int, alert_email: str) -> tuple[aws.sns.Topic, list[aws.cloudwatch.MetricAlarm]]:
    """Create billing alarms at multiple thresholds."""
    # Create SNS topic for billing alerts
    billing_alarm_topic = aws.sns.Topic(
        "billing-alarm-topic",
        display_name="Billing Alarm Notifications",
    )

    # Subscribe email to topic
    aws.sns.TopicSubscription(
        "billing-alarm-subscription",
        topic=billing_alarm_topic.arn,
        protocol="email",
        endpoint=alert_email,
    )

    # Create alarms at different thresholds
    thresholds = [
        (50, "warning"),
        (80, "critical"),
        (100, "emergency"),
    ]

    alarms = []
    for percentage, severity in thresholds:
        threshold_amount = budget_usd * (percentage / 100)

        alarm = aws.cloudwatch.MetricAlarm(
            f"billing-alarm-{percentage}pct",
            alarm_description=f"{severity.upper()}: Estimated charges exceed {percentage}% (${threshold_amount:.2f})",
            comparison_operator="GreaterThanThreshold",
            evaluation_periods=1,
            metric_name="EstimatedCharges",
            namespace="AWS/Billing",
            period=21600,  # 6 hours
            statistic="Maximum",
            threshold=threshold_amount,
            alarm_actions=[billing_alarm_topic.arn],
            dimensions={
                "Currency": "USD",
            },
            tags={
                "Severity": severity,
                "Environment": pulumi.get_stack(),
            },
        )
        alarms.append(alarm)

    return billing_alarm_topic, alarms
```

### AWS Budgets

```python
"""
AWS Budgets configuration (as of 2025-01).

More flexible than CloudWatch alarms, supports forecasted costs.
"""

import pulumi_aws as aws


def create_aws_budget(budget_amount: int, alert_emails: list[str]) -> aws.budgets.Budget:
    """Create AWS Budget with notifications."""
    budget = aws.budgets.Budget(
        "monthly-budget",
        budget_type="COST",
        limit_amount=str(budget_amount),
        limit_unit="USD",
        time_unit="MONTHLY",
        cost_filters={
            "TagKeyValue": [f"Environment${pulumi.get_stack()}"],
        },
        notifications=[
            # Alert at 50% actual spend
            aws.budgets.BudgetNotificationArgs(
                comparison_operator="GREATER_THAN",
                threshold=50,
                threshold_type="PERCENTAGE",
                notification_type="ACTUAL",
                subscriber_email_addresses=alert_emails,
            ),
            # Alert at 80% actual spend
            aws.budgets.BudgetNotificationArgs(
                comparison_operator="GREATER_THAN",
                threshold=80,
                threshold_type="PERCENTAGE",
                notification_type="ACTUAL",
                subscriber_email_addresses=alert_emails,
            ),
            # Alert at 100% actual spend
            aws.budgets.BudgetNotificationArgs(
                comparison_operator="GREATER_THAN",
                threshold=100,
                threshold_type="PERCENTAGE",
                notification_type="ACTUAL",
                subscriber_email_addresses=alert_emails + ["finance@example.com"],
            ),
            # Alert at 90% forecasted spend
            aws.budgets.BudgetNotificationArgs(
                comparison_operator="GREATER_THAN",
                threshold=90,
                threshold_type="PERCENTAGE",
                notification_type="FORECASTED",
                subscriber_email_addresses=alert_emails,
            ),
        ],
    )

    return budget
```

## GCP Budget Alerts

```python
"""
GCP Budget configuration (as of 2025-01).

Integrates with Pub/Sub for programmatic responses.
"""

import pulumi
import pulumi_gcp as gcp


def create_gcp_budget(budget_amount: int) -> gcp.billing.Budget:
    """Create GCP budget with Pub/Sub integration."""
    # Create Pub/Sub topic for budget alerts
    budget_topic = gcp.pubsub.Topic(
        "budget-alerts",
        name="budget-alerts",
    )

    # Create budget alert
    budget = gcp.billing.Budget(
        "monthly-budget",
        billing_account=gcp.billing.get_account().id,
        display_name="Monthly Budget Alert",
        budget_filter=gcp.billing.BudgetBudgetFilterArgs(
            projects=[f"projects/{pulumi.Config('gcp').require('project')}"],
            labels={
                "environment": pulumi.get_stack(),
            },
        ),
        amount=gcp.billing.BudgetAmountArgs(
            specified_amount=gcp.billing.BudgetAmountSpecifiedAmountArgs(
                currency_code="USD",
                units=str(budget_amount),
            ),
        ),
        threshold_rules=[
            gcp.billing.BudgetThresholdRuleArgs(
                threshold_percent=0.5,  # 50%
                spend_basis="CURRENT_SPEND",
            ),
            gcp.billing.BudgetThresholdRuleArgs(
                threshold_percent=0.8,  # 80%
                spend_basis="CURRENT_SPEND",
            ),
            gcp.billing.BudgetThresholdRuleArgs(
                threshold_percent=1.0,  # 100%
                spend_basis="CURRENT_SPEND",
            ),
            # Forecasted alert
            gcp.billing.BudgetThresholdRuleArgs(
                threshold_percent=0.9,  # 90%
                spend_basis="FORECASTED_SPEND",
            ),
        ],
        all_updates_rule=gcp.billing.BudgetAllUpdatesRuleArgs(
            pubsub_topic=budget_topic.id,
            schema_version="1.0",
        ),
    )

    return budget
```

## Azure Cost Alerts

```python
"""
Azure Budget configuration (as of 2025-01).

Uses Azure Monitor for cost alerts.
"""

import pulumi_azure_native as azure


def create_azure_budget(budget_amount: int) -> azure.consumption.Budget:
    """Create Azure budget with email notifications."""
    budget = azure.consumption.Budget(
        "monthly-budget",
        budget_name="MonthlyBudget",
        amount=budget_amount,
        category="Cost",
        time_grain="Monthly",
        time_period=azure.consumption.BudgetTimePeriodArgs(
            start_date="2025-01-01T00:00:00Z",
        ),
        notifications={
            "Actual_50_Percent": azure.consumption.NotificationArgs(
                enabled=True,
                operator="GreaterThan",
                threshold=50,
                contact_emails=["team@example.com"],
                threshold_type="Actual",
            ),
            "Actual_80_Percent": azure.consumption.NotificationArgs(
                enabled=True,
                operator="GreaterThan",
                threshold=80,
                contact_emails=["team@example.com"],
                threshold_type="Actual",
            ),
            "Actual_100_Percent": azure.consumption.NotificationArgs(
                enabled=True,
                operator="GreaterThan",
                threshold=100,
                contact_emails=["team@example.com", "finance@example.com"],
                threshold_type="Actual",
            ),
        },
    )

    return budget
```

## Platform-Specific Alerts

### Vercel

**Vercel doesn't have programmatic budget API.**

Set limits manually in dashboard:
1. Go to Settings > Billing > Usage Limits
2. Set maximum monthly spend
3. Configure email alerts at thresholds
4. Enable hard cap (optional)

Document in code:

```python
"""
Vercel Spending Limits (as of 2025-01):

Set manually in Vercel Dashboard:
- Maximum monthly spend: $100
- Email alerts at: $50, $80, $100
- Hard cap enabled: Yes

Settings > Billing > Usage Limits
"""
```

### Supabase

**Supabase doesn't have built-in budget alerts.**

Monitor via SQL and custom scripts:

```sql
-- Check database size daily
SELECT pg_size_pretty(pg_database_size('postgres')) as db_size;

-- Check storage usage
SELECT
  bucket_id,
  COUNT(*) as file_count,
  SUM((metadata->>'size')::bigint) / (1024*1024) as size_mb
FROM storage.objects
GROUP BY bucket_id;

-- Automated alert function
CREATE OR REPLACE FUNCTION check_database_size()
RETURNS void AS $$
DECLARE
  db_size_gb numeric;
BEGIN
  SELECT pg_database_size('postgres') / (1024^3) INTO db_size_gb;

  IF db_size_gb > 7 THEN
    -- Send webhook alert
    PERFORM http_post(
      'https://hooks.slack.com/your-webhook',
      json_build_object('text', 'Database exceeds 7 GB: ' || db_size_gb || ' GB')::text
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Schedule with pg_cron
SELECT cron.schedule('check-db-size', '0 9 * * *', 'SELECT check_database_size()');
```

### Cloudflare

**Cloudflare doesn't have built-in budget alerts.**

Monitor via API:

```python
"""
Cloudflare usage monitoring (as of 2025-01).

Check Workers usage and estimate costs.
"""

import os
import requests


def check_cloudflare_costs() -> dict[str, float]:
    """Check Cloudflare usage and estimate costs."""
    token = os.getenv("CLOUDFLARE_TOKEN")
    account_id = os.getenv("CLOUDFLARE_ACCOUNT_ID")

    # Get Workers analytics
    response = requests.get(
        f"https://api.cloudflare.com/client/v4/accounts/{account_id}/analytics_engine/sql",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "query": """
                SELECT SUM(requests) as total_requests
                FROM WorkersInvocationsAdaptive
                WHERE date >= date_trunc('month', now())
            """
        },
    )

    data = response.json()
    total_requests = data["data"][0]["total_requests"]

    # Calculate costs (as of 2025-01)
    base_cost = 5.0  # Workers Paid plan
    included_requests = 10_000_000
    overage_requests = max(0, total_requests - included_requests)
    overage_cost = (overage_requests / 1_000_000) * 0.50

    total_cost = base_cost + overage_cost

    return {
        "total_requests": total_requests,
        "base_cost": base_cost,
        "overage_cost": overage_cost,
        "total_cost": total_cost,
    }
```

## Automated Monitoring

### Daily Cost Check Script

```bash
#!/bin/bash
# Check daily costs and send alerts

# AWS
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "yesterday" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --output json | jq '.ResultsByTime[0].Total.UnblendedCost.Amount'

# Send to Slack if over threshold
```

### Weekly Cost Report

```python
"""
Weekly cost report (as of 2025-01).

Sends cost summary to team.
"""

import boto3
from datetime import datetime, timedelta
from typing import Any


def generate_weekly_report() -> dict[str, Any]:
    """Generate weekly cost report."""
    ce = boto3.client('ce')

    end = datetime.now()
    start = end - timedelta(days=7)

    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': start.strftime('%Y-%m-%d'),
            'End': end.strftime('%Y-%m-%d'),
        },
        Granularity='DAILY',
        Metrics=['UnblendedCost'],
        GroupBy=[
            {'Type': 'TAG', 'Key': 'Environment'},
            {'Type': 'SERVICE'},
        ],
    )

    # Process and format report
    report = {
        'period': f"{start.date()} to {end.date()}",
        'total_cost': 0,
        'by_environment': {},
        'by_service': {},
    }

    # ... format report data ...

    return report
```

## Best Practices

### 1. Multiple Alert Thresholds

Set alerts at:
- 50% - Early warning
- 80% - Critical warning
- 100% - Budget exceeded
- 90% forecasted - Proactive alert

### 2. Different Recipients by Severity

```python
alert_config = {
    50: ["devops@example.com"],
    80: ["devops@example.com", "engineering-lead@example.com"],
    100: ["devops@example.com", "engineering-lead@example.com", "finance@example.com"],
}
```

### 3. Environment-Specific Budgets

```python
budgets = {
    "dev": 100,      # $100/month
    "staging": 300,  # $300/month
    "production": 2000,  # $2000/month
}
```

### 4. Include Forecasted Alerts

Catch cost trends before they become problems.

## Related Documentation

- [Financial Governance](financial-governance.md) - Cost management principles
- [Cost Estimation](cost-estimation.md) - Estimating infrastructure costs
- [Pulumi Cost Controls](pulumi-cost-controls.md) - Policy enforcement

---

**Key Takeaway**: Set up budget alerts BEFORE deploying infrastructure. Use multiple thresholds (50%, 80%, 100%), different recipients by severity, and environment-specific budgets. Include both actual and forecasted alerts.
