<!-- MAINTENANCE: Review pricing quarterly (Jan/Apr/Jul/Oct) -->

# Cost Tracking and Variance Analysis

**When to use this guide**: Monitoring actual infrastructure costs vs. estimates, detecting cost drift, and maintaining accurate cost predictions.

**See also**: [Cost Dashboards](./cost-dashboards.md) for reporting and visualization.

## Why Track Actual vs. Estimated Costs

**Problem**: Cost estimates in documentation become stale:
- Provider pricing changes
- Usage patterns evolve
- Architecture changes accumulate
- Optimization opportunities are missed

**Solution**: Continuous cost tracking and variance analysis.

## Cost Tracking Architecture

### Data Collection

```python
"""Cost data collection from cloud providers."""

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any
import boto3
import json


@dataclass
class CostData:
    """Cloud cost data point."""

    provider: str
    service: str
    cost: float
    currency: str
    period_start: datetime
    period_end: datetime
    tags: dict[str, str]


def get_aws_costs(
    start_date: datetime,
    end_date: datetime,
    granularity: str = "MONTHLY"
) -> list[CostData]:
    """Retrieve AWS cost data via Cost Explorer API.

    Args:
        start_date: Start of cost period
        end_date: End of cost period
        granularity: DAILY, MONTHLY, or HOURLY

    Returns:
        List of cost data points

    Cost (as of 2025-01): $0.01 per API request to Cost Explorer
    """
    client = boto3.client("ce")

    try:
        response = client.get_cost_and_usage(
            TimePeriod={
                "Start": start_date.strftime("%Y-%m-%d"),
                "End": end_date.strftime("%Y-%m-%d"),
            },
            Granularity=granularity,
            Metrics=["UnblendedCost"],
            GroupBy=[
                {"Type": "DIMENSION", "Key": "SERVICE"},
                {"Type": "TAG", "Key": "Environment"},
            ]
        )
    except Exception as e:
        raise RuntimeError(f"Failed to fetch AWS costs: {e}")

    results = []
    for period in response["ResultsByTime"]:
        period_start = datetime.strptime(period["TimePeriod"]["Start"], "%Y-%m-%d")
        period_end = datetime.strptime(period["TimePeriod"]["End"], "%Y-%m-%d")

        for group in period.get("Groups", []):
            service = group["Keys"][0]
            environment = group["Keys"][1] if len(group["Keys"]) > 1 else "unknown"

            cost = float(group["Metrics"]["UnblendedCost"]["Amount"])
            currency = group["Metrics"]["UnblendedCost"]["Unit"]

            results.append(CostData(
                provider="aws",
                service=service,
                cost=cost,
                currency=currency,
                period_start=period_start,
                period_end=period_end,
                tags={"environment": environment}
            ))

    return results


def get_gcp_costs(
    project_id: str,
    start_date: datetime,
    end_date: datetime
) -> list[CostData]:
    """Retrieve GCP cost data via BigQuery billing export.

    Requires: BigQuery billing export enabled
    Cost (as of 2025-01): Free (uses existing BigQuery billing data)

    Args:
        project_id: GCP project ID
        start_date: Start of cost period
        end_date: End of cost period

    Returns:
        List of cost data points
    """
    from google.cloud import bigquery

    client = bigquery.Client(project=project_id)

    query = f"""
        SELECT
            service.description as service,
            SUM(cost) as total_cost,
            currency,
            DATE(usage_start_time) as usage_date,
            labels
        FROM `{project_id}.billing_export.gcp_billing_export_v1_*`
        WHERE DATE(usage_start_time) BETWEEN @start_date AND @end_date
        GROUP BY service, currency, usage_date, labels
    """

    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter(
                "start_date", "DATE", start_date.date()
            ),
            bigquery.ScalarQueryParameter(
                "end_date", "DATE", end_date.date()
            ),
        ]
    )

    try:
        results = client.query(query, job_config=job_config).result()
    except Exception as e:
        raise RuntimeError(f"Failed to fetch GCP costs: {e}")

    cost_data = []
    for row in results:
        cost_data.append(CostData(
            provider="gcp",
            service=row.service,
            cost=float(row.total_cost),
            currency=row.currency,
            period_start=datetime.combine(row.usage_date, datetime.min.time()),
            period_end=datetime.combine(
                row.usage_date + timedelta(days=1),
                datetime.min.time()
            ),
            tags=dict(row.labels) if row.labels else {}
        ))

    return cost_data
```

### Variance Detection

```python
"""Detect cost variance between estimated and actual costs."""

from typing import NamedTuple


class CostVariance(NamedTuple):
    """Cost variance analysis result."""

    service: str
    estimated: float
    actual: float
    variance: float
    variance_percent: float
    is_significant: bool


def calculate_variance(
    estimated: float,
    actual: float,
    threshold_percent: float = 20.0
) -> CostVariance:
    """Calculate cost variance.

    Args:
        estimated: Estimated cost from documentation
        actual: Actual cost from provider
        threshold_percent: Variance threshold for significance

    Returns:
        Variance analysis result
    """
    variance = actual - estimated
    variance_percent = (variance / estimated * 100) if estimated > 0 else 0
    is_significant = abs(variance_percent) > threshold_percent

    return CostVariance(
        service="",  # To be filled by caller
        estimated=estimated,
        actual=actual,
        variance=variance,
        variance_percent=variance_percent,
        is_significant=is_significant
    )


def analyze_cost_drift(
    estimated_costs: dict[str, float],
    actual_costs: list[CostData],
    threshold: float = 20.0
) -> list[CostVariance]:
    """Analyze drift between estimated and actual costs.

    Args:
        estimated_costs: Service -> estimated monthly cost
        actual_costs: Actual cost data from providers
        threshold: Variance threshold percentage

    Returns:
        List of significant variances
    """
    # Aggregate actual costs by service
    actual_by_service: dict[str, float] = {}
    for cost in actual_costs:
        if cost.service not in actual_by_service:
            actual_by_service[cost.service] = 0.0
        actual_by_service[cost.service] += cost.cost

    # Calculate variances
    variances = []
    for service, estimated in estimated_costs.items():
        actual = actual_by_service.get(service, 0.0)

        variance = calculate_variance(estimated, actual, threshold)
        variances.append(
            variance._replace(service=service)
        )

    # Return only significant variances
    return [v for v in variances if v.is_significant]
```

### Alerting on Cost Drift

```python
"""Alert when actual costs deviate from estimates."""

import json
import sys


def send_cost_drift_alert(
    variances: list[CostVariance],
    webhook_url: str | None = None
) -> None:
    """Send alert for significant cost drift.

    Args:
        variances: Cost variances to report
        webhook_url: Optional Slack/Teams webhook URL
    """
    if not variances:
        return

    total_variance = sum(v.variance for v in variances)

    message = f"Cost Drift Alert: ${total_variance:,.2f} variance detected\n\n"

    for variance in sorted(variances, key=lambda v: abs(v.variance), reverse=True):
        direction = "↑" if variance.variance > 0 else "↓"
        message += (
            f"{direction} {variance.service}: "
            f"${variance.actual:,.2f} actual vs ${variance.estimated:,.2f} estimated "
            f"({variance.variance_percent:+.1f}%)\n"
        )

    if webhook_url:
        import requests

        try:
            requests.post(
                webhook_url,
                json={"text": message},
                timeout=10
            )
        except Exception as e:
            print(f"Failed to send webhook: {e}", file=sys.stderr)

    # Always log to console
    print(message)


# Example usage
if __name__ == "__main__":
    # Estimated costs from documentation
    estimates = {
        "Amazon EC2": 150.00,
        "Amazon RDS": 200.00,
        "Amazon S3": 50.00,
    }

    # Fetch actual costs
    actual = get_aws_costs(
        start_date=datetime.now() - timedelta(days=30),
        end_date=datetime.now()
    )

    # Analyze drift
    drift = analyze_cost_drift(estimates, actual, threshold=20.0)

    if drift:
        send_cost_drift_alert(drift, webhook_url=None)
        sys.exit(1)  # Fail CI/CD if drift detected
```

## Automated Documentation Updates

### Update Cost Estimates in Docs

```python
"""Automatically update cost estimates in documentation."""

import re
from pathlib import Path


def update_cost_in_docs(
    doc_path: Path,
    service: str,
    new_cost: float,
    old_cost: float | None = None
) -> bool:
    """Update cost estimate in documentation file.

    Args:
        doc_path: Path to markdown file
        service: Service name to update
        new_cost: New cost estimate
        old_cost: Optional old cost (for validation)

    Returns:
        True if update successful
    """
    content = doc_path.read_text()

    # Pattern: "Service: $123.45/month" or "Cost: $123.45"
    pattern = rf'({re.escape(service)}.*?\$)(\d+\.?\d*)(/month)?'

    def replace_cost(match: re.Match[str]) -> str:
        prefix = match.group(1)
        suffix = match.group(3) or ""

        # Validate old cost if provided
        if old_cost is not None:
            current = float(match.group(2))
            if abs(current - old_cost) > 0.01:
                print(
                    f"Warning: Expected ${old_cost}, found ${current} "
                    f"for {service} in {doc_path.name}"
                )

        return f"{prefix}{new_cost:.2f}{suffix}"

    new_content = re.sub(pattern, replace_cost, content)

    if new_content != content:
        doc_path.write_text(new_content)
        return True

    return False
```

## Cost Trend Analysis

### Track Trends Over Time

```python
"""Analyze cost trends and forecast future costs."""

from statistics import mean, stdev
import numpy as np
from sklearn.linear_model import LinearRegression


def analyze_cost_trend(
    historical_costs: list[tuple[datetime, float]],
    forecast_days: int = 30
) -> dict[str, Any]:
    """Analyze cost trends and forecast future costs.

    Requires: numpy, scikit-learn
    Install with: pip install numpy scikit-learn

    Args:
        historical_costs: List of (date, cost) tuples
        forecast_days: Days to forecast into future

    Returns:
        Trend analysis with forecast
    """
    if len(historical_costs) < 2:
        raise ValueError("Need at least 2 data points for trend analysis")

    # Sort by date
    historical_costs.sort(key=lambda x: x[0])

    # Convert to days since start
    start_date = historical_costs[0][0]
    X = np.array([
        (date - start_date).days
        for date, _ in historical_costs
    ]).reshape(-1, 1)
    y = np.array([cost for _, cost in historical_costs])

    # Fit linear regression
    model = LinearRegression()
    model.fit(X, y)

    # Calculate trend
    slope = float(model.coef_[0])
    daily_change = slope
    monthly_change = slope * 30

    # Forecast
    last_date = historical_costs[-1][0]
    forecast_date = last_date + timedelta(days=forecast_days)
    forecast_days_since_start = (forecast_date - start_date).days
    forecast_cost = float(model.predict([[forecast_days_since_start]])[0])

    # Calculate volatility
    residuals = y - model.predict(X)
    volatility = float(stdev(residuals)) if len(residuals) > 1 else 0.0

    return {
        "current_cost": float(y[-1]),
        "trend": "increasing" if slope > 0 else "decreasing",
        "daily_change": daily_change,
        "monthly_change": monthly_change,
        "forecast_cost": forecast_cost,
        "forecast_date": forecast_date.isoformat(),
        "volatility": volatility,
        "r_squared": float(model.score(X, y))
    }
```

## Related Documentation

- **Visualization**: [Cost Dashboards](./cost-dashboards.md) - Reporting and CI/CD integration
- **Foundation**: [Financial Governance](./financial-governance.md) - Cost management principles
- **Planning**: [Cost Estimation](./cost-estimation.md) - How to estimate infrastructure costs
- **Monitoring**: [Budget Alerts](./budget-alerts.md) - Setting up cost alerts
- **Enforcement**: [Pulumi Cost Controls](./pulumi-cost-controls.md) - Policy as Code for costs
