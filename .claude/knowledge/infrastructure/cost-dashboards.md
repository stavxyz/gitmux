<!-- MAINTENANCE: Review pricing quarterly (Jan/Apr/Jul/Oct) -->

# Cost Dashboards and Reporting

**When to use this guide**: Visualizing cost data, generating reports, and integrating cost tracking into CI/CD pipelines.

**See also**: [Cost Tracking](./cost-tracking.md) for data collection and variance detection.

## Cost Dashboard Visualization

### Generate Cost Comparison Dashboard

```python
"""Generate cost tracking dashboard."""

import matplotlib.pyplot as plt
from io import BytesIO
from pathlib import Path
from typing import Any


def generate_cost_dashboard(
    actual_costs: list[CostData],
    estimated_costs: dict[str, float],
    output_path: Path
) -> None:
    """Generate cost comparison dashboard.

    Args:
        actual_costs: Actual cost data
        estimated_costs: Estimated costs by service
        output_path: Path to save dashboard image
    """
    # Aggregate actual by service
    actual_by_service: dict[str, float] = {}
    for cost in actual_costs:
        if cost.service not in actual_by_service:
            actual_by_service[cost.service] = 0.0
        actual_by_service[cost.service] += cost.cost

    # Prepare data
    services = list(estimated_costs.keys())
    estimated = [estimated_costs[s] for s in services]
    actual = [actual_by_service.get(s, 0.0) for s in services]

    # Create chart
    fig, ax = plt.subplots(figsize=(12, 6))

    x = range(len(services))
    width = 0.35

    ax.bar([i - width/2 for i in x], estimated, width, label="Estimated")
    ax.bar([i + width/2 for i in x], actual, width, label="Actual")

    ax.set_xlabel("Service")
    ax.set_ylabel("Cost ($)")
    ax.set_title("Estimated vs Actual Costs")
    ax.set_xticks(x)
    ax.set_xticklabels(services, rotation=45, ha="right")
    ax.legend()

    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()
```

### Time Series Cost Visualization

```python
"""Visualize cost trends over time."""

import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime


def generate_cost_trend_chart(
    historical_costs: list[tuple[datetime, float]],
    output_path: Path,
    title: str = "Cost Trend Over Time"
) -> None:
    """Generate cost trend chart.

    Args:
        historical_costs: List of (date, cost) tuples
        output_path: Path to save chart
        title: Chart title
    """
    # Sort by date
    historical_costs.sort(key=lambda x: x[0])

    dates = [date for date, _ in historical_costs]
    costs = [cost for _, cost in historical_costs]

    fig, ax = plt.subplots(figsize=(12, 6))

    ax.plot(dates, costs, marker='o', linewidth=2)
    ax.fill_between(dates, costs, alpha=0.3)

    ax.set_xlabel("Date")
    ax.set_ylabel("Cost ($)")
    ax.set_title(title)

    # Format x-axis dates
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d'))
    ax.xaxis.set_major_locator(mdates.WeekdayLocator(interval=1))
    plt.xticks(rotation=45)

    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()
```

### Multi-Service Comparison

```python
"""Compare costs across multiple services."""

import matplotlib.pyplot as plt
import pandas as pd


def generate_service_breakdown(
    cost_data: list[CostData],
    output_path: Path
) -> None:
    """Generate service cost breakdown pie chart.

    Args:
        cost_data: Cost data from providers
        output_path: Path to save chart
    """
    # Aggregate by service
    service_costs: dict[str, float] = {}
    for cost in cost_data:
        if cost.service not in service_costs:
            service_costs[cost.service] = 0.0
        service_costs[cost.service] += cost.cost

    # Sort by cost (descending)
    sorted_services = sorted(
        service_costs.items(),
        key=lambda x: x[1],
        reverse=True
    )

    services = [s for s, _ in sorted_services]
    costs = [c for _, c in sorted_services]

    # Create pie chart
    fig, ax = plt.subplots(figsize=(10, 8))

    ax.pie(
        costs,
        labels=services,
        autopct='%1.1f%%',
        startangle=90
    )

    ax.set_title("Cost Breakdown by Service")

    plt.tight_layout()
    plt.savefig(output_path)
    plt.close()
```

## HTML Reporting

### Generate Interactive HTML Report

```python
"""Generate interactive HTML cost report."""

from datetime import datetime
from pathlib import Path


def generate_html_report(
    estimated_costs: dict[str, float],
    actual_costs: list[CostData],
    variances: list[CostVariance],
    output_path: Path
) -> None:
    """Generate HTML cost report with summary and detailed table.

    Creates a styled HTML page showing:
    - Summary cards (estimated, actual, variance)
    - Warning alerts for significant variances
    - Detailed service-by-service cost table

    Args:
        estimated_costs: Estimated costs by service
        actual_costs: Actual cost data
        variances: Cost variances
        output_path: Path to save HTML report
    """
    # Calculate totals
    total_estimated = sum(estimated_costs.values())

    actual_by_service: dict[str, float] = {}
    for cost in actual_costs:
        actual_by_service[cost.service] = actual_by_service.get(cost.service, 0.0) + cost.cost

    total_actual = sum(actual_by_service.values())
    total_variance = total_actual - total_estimated
    variance_percent = (total_variance / total_estimated * 100) if total_estimated > 0 else 0

    # Build HTML with summary, alerts, and cost table
    # Full implementation available in cost-tracking repository examples
    html = f"""<!DOCTYPE html>
<html>
<head><title>Cost Report - {datetime.now().strftime('%Y-%m-%d')}</title>
<style>/* CSS styles for report layout */</style>
</head>
<body>
<h1>Infrastructure Cost Report</h1>
<div class="summary">
    <div>Estimated: ${total_estimated:,.2f}</div>
    <div>Actual: ${total_actual:,.2f}</div>
    <div>Variance: {variance_percent:+.1f}%</div>
</div>
<table><!-- Service cost breakdown --></table>
</body>
</html>"""

    output_path.write_text(html)
```

## CI/CD Integration

### Pre-Deployment Cost Check

```python
"""CI/CD cost validation script."""

import sys


def validate_costs_before_deploy(
    estimated_new_cost: float,
    current_actual_cost: float,
    budget_limit: float
) -> bool:
    """Validate costs before deployment.

    Args:
        estimated_new_cost: Estimated cost after deployment
        current_actual_cost: Current actual cost
        budget_limit: Maximum allowed cost

    Returns:
        True if deployment should proceed
    """
    # Check if new deployment exceeds budget
    if estimated_new_cost > budget_limit:
        print(
            f"Deployment blocked: Estimated cost ${estimated_new_cost:.2f} "
            f"exceeds budget ${budget_limit:.2f}",
            file=sys.stderr
        )
        return False

    # Check if increase is reasonable (< 50% jump)
    if current_actual_cost > 0:
        increase_percent = (
            (estimated_new_cost - current_actual_cost) / current_actual_cost * 100
        )

        if increase_percent > 50:
            print(
                f"Warning: Cost increase of {increase_percent:.1f}% detected",
                file=sys.stderr
            )
            print(
                f"Current: ${current_actual_cost:.2f}, "
                f"Estimated: ${estimated_new_cost:.2f}",
                file=sys.stderr
            )
            # Could block deployment or require manual approval
            return False

    print(f"Cost check passed: ${estimated_new_cost:.2f} within budget")
    return True
```

### GitHub Actions Integration

```yaml
# .github/workflows/cost-check.yml
name: Cost Validation

on:
  pull_request:
    paths:
      - 'infrastructure/**'
      - 'pulumi/**'

jobs:
  cost-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install boto3 pulumi

      - name: Fetch actual costs
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          python scripts/fetch_costs.py --output costs_actual.json

      - name: Estimate new costs
        run: |
          pulumi preview --json > costs_estimated.json

      - name: Compare costs
        run: |
          python scripts/compare_costs.py \
            --actual costs_actual.json \
            --estimated costs_estimated.json \
            --budget ${{ vars.MONTHLY_BUDGET }} \
            --threshold 20

      - name: Comment on PR
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: 'Cost validation failed. Please review the cost changes.'
            })
```

### Slack/Teams Notification

```python
"""Send cost report to Slack or Teams."""

import requests
from typing import Any


def send_slack_notification(
    webhook_url: str,
    total_estimated: float,
    total_actual: float,
    variances: list[CostVariance]
) -> None:
    """Send cost report to Slack.

    Args:
        webhook_url: Slack webhook URL
        total_estimated: Total estimated cost
        total_actual: Total actual cost
        variances: List of cost variances
    """
    variance = total_actual - total_estimated
    variance_pct = (variance / total_estimated * 100) if total_estimated > 0 else 0

    color = "danger" if variance > 0 else "good"
    emoji = ":chart_with_upwards_trend:" if variance > 0 else ":chart_with_downwards_trend:"

    # Build variance list
    variance_text = ""
    for v in sorted(variances, key=lambda x: abs(x.variance), reverse=True)[:5]:
        direction = "↑" if v.variance > 0 else "↓"
        variance_text += f"\n{direction} *{v.service}*: ${v.actual:,.2f} ({v.variance_percent:+.1f}%)"

    payload = {
        "attachments": [{
            "color": color,
            "title": f"{emoji} Infrastructure Cost Report",
            "fields": [
                {
                    "title": "Estimated",
                    "value": f"${total_estimated:,.2f}",
                    "short": True
                },
                {
                    "title": "Actual",
                    "value": f"${total_actual:,.2f}",
                    "short": True
                },
                {
                    "title": "Variance",
                    "value": f"${variance:+,.2f} ({variance_pct:+.1f}%)",
                    "short": True
                },
                {
                    "title": "Top Variances",
                    "value": variance_text or "None",
                    "short": False
                }
            ]
        }]
    }

    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        response.raise_for_status()
    except Exception as e:
        print(f"Failed to send Slack notification: {e}", file=sys.stderr)
```

## Scheduled Reporting

Configure automated weekly cost reports using the visualization and alerting functions above. Schedule with cron or GitHub Actions to run weekly:

```bash
# Cron: Run every Monday at 9 AM
# 0 9 * * 1 python /path/to/weekly_report.py
```

Combine `generate_html_report()` with email or Slack notifications for automated distribution.

## Related Documentation

- **Data Collection**: [Cost Tracking](./cost-tracking.md) - Fetching and analyzing cost data
- **Foundation**: [Financial Governance](./financial-governance.md) - Cost management principles
- **Planning**: [Cost Estimation](./cost-estimation.md) - How to estimate infrastructure costs
- **Monitoring**: [Budget Alerts](./budget-alerts.md) - Setting up cost alerts
- **Enforcement**: [Pulumi Cost Controls](./pulumi-cost-controls.md) - Policy as Code for costs
