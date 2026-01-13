<!-- MAINTENANCE: Review pricing quarterly (Jan/Apr/Jul/Oct) -->

# Multi-Region Active-Passive Deployment

**When to use this pattern**: Disaster recovery requirements, cost optimization, simpler multi-region architecture with automatic failover.

**See also**: [Multi-Region Overview](./multi-region-overview.md) for pattern comparison.

## Architecture Overview

```
Primary Region (us-east-1)     Standby Region (eu-west-1)
    ├─ Application (active)       ├─ Application (standby)
    ├─ Database (primary)         ├─ Database (replica)
    └─ Users → Primary            └─ Failover only
```

**Key Characteristics**:
- Primary region handles 100% of traffic
- Standby region runs at 50% capacity
- Automatic failover via Route53 health checks
- Database read replicas in standby
- RTO: 5-30 minutes (depends on health check frequency)
- RPO: Near-zero (continuous replication)

## Implementation

### Full Pulumi Example

```python
"""Active-Passive multi-region setup with Pulumi."""

import pulumi
import pulumi_aws as aws
from typing import Literal, Any

RegionName = Literal["us-east-1", "eu-west-1"]


class ActivePassiveDeployment:
    """Multi-region active-passive deployment."""

    def __init__(
        self,
        name: str,
        primary_region: RegionName,
        standby_region: RegionName,
        standby_capacity_percent: int = 50
    ) -> None:
        """Initialize active-passive deployment.

        Args:
            name: Deployment name
            primary_region: Primary AWS region
            standby_region: Standby AWS region
            standby_capacity_percent: Standby capacity (% of primary)
        """
        self.name = name
        self.primary_region = primary_region
        self.standby_region = standby_region

        # Primary region deployment
        self.primary = self._create_regional_deployment(
            primary_region,
            capacity=100,
            is_primary=True
        )

        # Standby region deployment (reduced capacity)
        self.standby = self._create_regional_deployment(
            standby_region,
            capacity=standby_capacity_percent,
            is_primary=False
        )

        # Route53 health checks and failover
        self.dns_failover = self._setup_dns_failover()

    def _create_regional_deployment(
        self,
        region: RegionName,
        capacity: int,
        is_primary: bool
    ) -> dict[str, Any]:
        """Create deployment in a single region."""
        provider = aws.Provider(f"{self.name}-{region}", region=region)

        # Application tier
        instance_count = max(1, capacity // 25)  # Scale with capacity

        instances = []
        for i in range(instance_count):
            instance = aws.ec2.Instance(
                f"{self.name}-{region}-app-{i}",
                instance_type="t3.medium" if capacity >= 50 else "t3.small",
                ami="ami-12345678",  # Replace with actual AMI
                tags={
                    "Name": f"{self.name}-{region}-app-{i}",
                    "Region": region,
                    "Role": "primary" if is_primary else "standby",
                },
                opts=pulumi.ResourceOptions(provider=provider)
            )
            instances.append(instance)

        # Database replication
        if is_primary:
            db = aws.rds.Instance(
                f"{self.name}-{region}-db",
                engine="postgres",
                instance_class="db.t3.medium",
                allocated_storage=100,
                backup_retention_period=7,
                opts=pulumi.ResourceOptions(provider=provider)
            )
        else:
            # Read replica in standby region
            db = aws.rds.Instance(
                f"{self.name}-{region}-db-replica",
                replicate_source_db=self.primary["db"].arn,
                instance_class="db.t3.small",  # Smaller for standby
                opts=pulumi.ResourceOptions(provider=provider)
            )

        return {
            "instances": instances,
            "db": db,
            "region": region,
        }

    def _setup_dns_failover(self) -> aws.route53.Record:
        """Configure Route53 health check and failover."""
        # Health check for primary region
        health_check = aws.route53.HealthCheck(
            f"{self.name}-health-check",
            type="HTTPS",
            resource_path="/health",
            fqdn=f"{self.name}.example.com",
            port=443,
            failure_threshold=3,
            request_interval=30,
        )

        # Primary record (failover primary)
        primary_record = aws.route53.Record(
            f"{self.name}-primary",
            zone_id="Z1234567890ABC",  # Replace with your hosted zone
            name=f"{self.name}.example.com",
            type="A",
            set_identifier="primary",
            failover_routing_policies=[{
                "type": "PRIMARY",
            }],
            health_check_id=health_check.id,
            records=[self.primary["instances"][0].public_ip],
            ttl=60,
        )

        # Standby record (failover secondary)
        standby_record = aws.route53.Record(
            f"{self.name}-standby",
            zone_id="Z1234567890ABC",
            name=f"{self.name}.example.com",
            type="A",
            set_identifier="standby",
            failover_routing_policies=[{
                "type": "SECONDARY",
            }],
            records=[self.standby["instances"][0].public_ip],
            ttl=60,
        )

        return primary_record
```

### Usage Example

```python
"""Deploy active-passive infrastructure."""

import pulumi

# Create active-passive deployment
deployment = ActivePassiveDeployment(
    name="my-app",
    primary_region="us-east-1",
    standby_region="eu-west-1",
    standby_capacity_percent=50
)

# Export endpoints
pulumi.export("primary_endpoint", deployment.primary["instances"][0].public_ip)
pulumi.export("standby_endpoint", deployment.standby["instances"][0].public_ip)
pulumi.export("dns_endpoint", f"{deployment.name}.example.com")
```

## Cost Analysis

**Estimated Cost** (as of 2025-01):

```python
"""
Active-Passive Cost Estimate:

Primary Region (us-east-1):
- EC2 t3.medium × 4: $120/month
- RDS db.t3.medium: $150/month
- Data transfer: $50/month
Subtotal: $320/month

Standby Region (eu-west-1):
- EC2 t3.small × 2: $30/month
- RDS db.t3.small (replica): $75/month
- Data transfer (replication): $20/month
Subtotal: $125/month

Route53:
- Health checks: $1/month
- DNS queries: $5/month
Subtotal: $6/month

Total: $451/month (141% of single-region baseline)
"""
```

**Cost Optimization**:
- Use Reserved Instances for primary region (40-59% savings)
- Reduce standby capacity to 25% if RTO allows
- Use Spot Instances for non-critical standby workloads
- Minimize cross-region data transfer

## Failover Testing

### Manual Failover

```python
"""Trigger manual failover for testing."""

import pulumi_aws as aws

def trigger_manual_failover(health_check_id: str) -> None:
    """Manually trigger failover by disabling health check.

    Args:
        health_check_id: Route53 health check ID
    """
    client = boto3.client("route53")

    # Disable health check to force failover
    client.update_health_check(
        HealthCheckId=health_check_id,
        Disabled=True
    )

    print("Failover triggered. Traffic will redirect to standby region.")
    print("Monitor DNS propagation: dig your-domain.com")

    # Re-enable after testing
    input("Press Enter to re-enable primary region...")

    client.update_health_check(
        HealthCheckId=health_check_id,
        Disabled=False
    )

    print("Primary region re-enabled.")
```

### Automated Testing

```python
"""Automated failover testing script."""

import boto3
import time
import requests
from typing import Tuple


def test_failover(
    health_check_id: str,
    endpoint: str,
    timeout: int = 300
) -> Tuple[bool, float]:
    """Test automatic failover.

    Args:
        health_check_id: Route53 health check ID
        endpoint: Application endpoint to monitor
        timeout: Max time to wait for failover (seconds)

    Returns:
        (success, failover_time_seconds)
    """
    client = boto3.client("route53")

    # Disable health check
    client.update_health_check(
        HealthCheckId=health_check_id,
        Disabled=True
    )

    start_time = time.time()
    max_time = start_time + timeout

    # Wait for failover
    while time.time() < max_time:
        try:
            response = requests.get(endpoint, timeout=5)
            if response.status_code == 200:
                failover_time = time.time() - start_time
                print(f"✅ Failover successful in {failover_time:.1f}s")

                # Re-enable primary
                client.update_health_check(
                    HealthCheckId=health_check_id,
                    Disabled=False
                )

                return True, failover_time
        except requests.RequestException:
            pass

        time.sleep(5)

    print("❌ Failover timed out")
    return False, timeout


# Run test
success, duration = test_failover(
    health_check_id="abc123",
    endpoint="https://my-app.example.com/health"
)
```

## Monitoring and Alerts

### Health Check Monitoring

```python
"""Monitor health check status."""

import pulumi_aws as aws

# CloudWatch alarm for health check failures
health_alarm = aws.cloudwatch.MetricAlarm(
    "primary-health-alarm",
    comparison_operator="LessThanThreshold",
    evaluation_periods=2,
    metric_name="HealthCheckStatus",
    namespace="AWS/Route53",
    period=60,
    statistic="Minimum",
    threshold=1,
    alarm_description="Primary region health check failed",
    alarm_actions=[],  # Add SNS topic ARN
    dimensions={
        "HealthCheckId": health_check.id,
    }
)
```

### Replication Lag Monitoring

```python
"""Monitor database replication lag."""

import pulumi_aws as aws

# CloudWatch alarm for replication lag
replication_alarm = aws.cloudwatch.MetricAlarm(
    "replication-lag-alarm",
    comparison_operator="GreaterThanThreshold",
    evaluation_periods=2,
    metric_name="ReplicaLag",
    namespace="AWS/RDS",
    period=300,
    statistic="Average",
    threshold=30,  # 30 seconds lag
    alarm_description="Database replication lag exceeded 30s",
    alarm_actions=[],  # Add SNS topic ARN
    dimensions={
        "DBInstanceIdentifier": replica_db.id,
    }
)
```

## Operational Procedures

### Failover Checklist

**Automatic Failover** (health check triggered):
1. Route53 detects primary region failure
2. DNS records updated to standby region (TTL: 60s)
3. Traffic redirects to standby after DNS propagation
4. Monitor application metrics for issues
5. Investigate primary region failure
6. Restore primary when ready

**Manual Failover** (planned maintenance):
1. Announce maintenance window to users
2. Disable Route53 health check for primary
3. Verify traffic redirects to standby
4. Perform maintenance on primary region
5. Test primary region after maintenance
6. Re-enable health check
7. Monitor failback

### Recovery Procedures

**Primary Region Recovery**:
```bash
# 1. Verify standby is healthy
pulumi stack select standby
pulumi up --yes

# 2. Restore primary region
pulumi stack select primary
pulumi up --yes

# 3. Verify database replication
aws rds describe-db-instances \
    --db-instance-identifier my-app-standby-db \
    --query 'DBInstances[0].ReadReplicaSourceDBInstanceIdentifier'

# 4. Test primary endpoint
curl https://primary.my-app.example.com/health

# 5. Re-enable health check (automatic failback)
aws route53 update-health-check \
    --health-check-id abc123 \
    --disabled false
```

## Related Documentation

- [Multi-Region Overview](./multi-region-overview.md) - Pattern comparison and selection
- [Multi-Region Active-Active](./multi-region-active-active.md) - Alternative pattern for global traffic
- [Financial Governance](./financial-governance.md) - Cost management principles
- [Pulumi Guide](./pulumi-guide.md) - Infrastructure as Code basics
- [Budget Alerts](./budget-alerts.md) - Cost monitoring setup
