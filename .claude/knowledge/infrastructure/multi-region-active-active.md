<!-- MAINTENANCE: Review pricing quarterly (Jan/Apr/Jul/Oct) -->

# Multi-Region Active-Active Deployment

**When to use this pattern**: Global user base, performance requirements, 99.99%+ availability, multi-primary database replication.

**See also**: [Multi-Region Overview](./multi-region-overview.md) for pattern comparison.

## Architecture Overview

```
Region A (us-east-1)          Region B (eu-west-1)
    ├─ Application (active)       ├─ Application (active)
    ├─ Database (primary)         ├─ Database (primary)
    └─ Users (Americas)           └─ Users (Europe/Asia)
```

**Key Characteristics**:
- Both regions handle production traffic simultaneously
- Global load balancing routes users to nearest region
- Multi-primary database replication (Aurora Global Database)
- Full capacity in each region
- Sub-second replication lag
- Automatic traffic shifting on failure

## Implementation

### Full Pulumi Example

```python
"""Active-Active multi-region deployment with global load balancing."""

import pulumi
import pulumi_aws as aws
import pulumi_cloudflare as cloudflare
from typing import Any, Literal


class ActiveActiveDeployment:
    """Multi-region active-active deployment with global load balancing."""

    def __init__(
        self,
        name: str,
        regions: list[str],
        traffic_policy: Literal["latency", "geolocation", "weighted"] = "latency"
    ) -> None:
        """Initialize active-active deployment.

        Args:
            name: Deployment name
            regions: List of AWS regions to deploy to
            traffic_policy: Route53 routing policy
        """
        self.name = name
        self.regions = regions
        self.deployments = {}

        # Deploy full stack to each region
        for region in regions:
            self.deployments[region] = self._deploy_to_region(region)

        # Setup global load balancing
        self.global_lb = self._setup_global_load_balancing(traffic_policy)

        # Setup database replication
        self.db_replication = self._setup_multi_primary_replication()

    def _deploy_to_region(self, region: str) -> dict[str, Any]:
        """Deploy full application stack to a region."""
        provider = aws.Provider(f"{self.name}-{region}", region=region)

        # VPC
        vpc = aws.ec2.Vpc(
            f"{self.name}-{region}-vpc",
            cidr_block="10.0.0.0/16",
            enable_dns_hostnames=True,
            enable_dns_support=True,
            tags={"Name": f"{self.name}-{region}-vpc"},
            opts=pulumi.ResourceOptions(provider=provider)
        )

        # Application Load Balancer
        alb = aws.lb.LoadBalancer(
            f"{self.name}-{region}-alb",
            load_balancer_type="application",
            subnets=[],  # Add subnet IDs
            tags={"Region": region},
            opts=pulumi.ResourceOptions(provider=provider)
        )

        # Auto Scaling Group
        asg = aws.autoscaling.Group(
            f"{self.name}-{region}-asg",
            min_size=2,
            max_size=10,
            desired_capacity=4,
            vpc_zone_identifiers=[],  # Add subnet IDs
            tags=[{
                "key": "Name",
                "value": f"{self.name}-{region}-instance",
                "propagate_at_launch": True,
            }],
            opts=pulumi.ResourceOptions(provider=provider)
        )

        # Aurora Global Database (supports multi-primary)
        db_cluster = aws.rds.Cluster(
            f"{self.name}-{region}-db",
            engine="aurora-postgresql",
            engine_mode="provisioned",
            database_name=self.name,
            master_username="admin",
            master_password=pulumi.Config().require_secret("dbPassword"),
            global_cluster_identifier=f"{self.name}-global",
            opts=pulumi.ResourceOptions(provider=provider)
        )

        return {
            "vpc": vpc,
            "alb": alb,
            "asg": asg,
            "db_cluster": db_cluster,
            "region": region,
        }

    def _setup_global_load_balancing(
        self,
        policy: Literal["latency", "geolocation", "weighted"]
    ) -> list[aws.route53.Record]:
        """Setup global load balancing with Route53."""
        records = []

        for region, deployment in self.deployments.items():
            record = aws.route53.Record(
                f"{self.name}-{region}-record",
                zone_id="Z1234567890ABC",
                name=f"{self.name}.example.com",
                type="A",
                set_identifier=region,
                ttl=60,
                # Routing policy based on parameter
                **self._get_routing_policy(policy, region)
            )
            records.append(record)

        return records

    def _get_routing_policy(
        self,
        policy: str,
        region: str
    ) -> dict[str, Any]:
        """Get Route53 routing policy configuration."""
        if policy == "latency":
            return {
                "latency_routing_policies": [{"region": region}],
            }
        elif policy == "geolocation":
            # Map regions to continents
            geo_map = {
                "us-east-1": "NA",
                "eu-west-1": "EU",
                "ap-southeast-1": "AS",
            }
            return {
                "geolocation_routing_policies": [{
                    "continent": geo_map.get(region, "NA"),
                }],
            }
        else:  # weighted
            return {
                "weighted_routing_policies": [{
                    "weight": 100,  # Equal weight
                }],
            }

    def _setup_multi_primary_replication(self) -> aws.rds.GlobalCluster:
        """Setup Aurora Global Database for multi-primary replication."""
        global_cluster = aws.rds.GlobalCluster(
            f"{self.name}-global-db",
            global_cluster_identifier=f"{self.name}-global",
            engine="aurora-postgresql",
            engine_version="14.6",
            database_name=self.name,
        )

        return global_cluster
```

### Usage Example

```python
"""Deploy active-active infrastructure across 3 regions."""

import pulumi

# Create active-active deployment
deployment = ActiveActiveDeployment(
    name="my-app",
    regions=["us-east-1", "eu-west-1", "ap-southeast-1"],
    traffic_policy="latency"  # Route to lowest latency region
)

# Export global endpoint
pulumi.export("global_endpoint", f"{deployment.name}.example.com")
pulumi.export("regions", deployment.regions)
```

## Data Replication Strategies

### Aurora Global Database

**Recommended for**: Multi-primary writes, sub-second replication, automatic failover

```python
"""Aurora Global Database with multi-primary writes."""

import pulumi_aws as aws
import pulumi

# Primary cluster (us-east-1)
global_cluster = aws.rds.GlobalCluster(
    "app-global-db",
    global_cluster_identifier="app-global",
    engine="aurora-postgresql",
    engine_version="14.6",
)

primary_cluster = aws.rds.Cluster(
    "app-primary-cluster",
    engine="aurora-postgresql",
    global_cluster_identifier=global_cluster.id,
    master_username="admin",
    master_password=pulumi.Config().require_secret("dbPassword"),
    opts=pulumi.ResourceOptions(provider=us_east_provider)
)

# Secondary cluster (eu-west-1)
secondary_cluster = aws.rds.Cluster(
    "app-secondary-cluster",
    engine="aurora-postgresql",
    global_cluster_identifier=global_cluster.id,
    opts=pulumi.ResourceOptions(
        provider=eu_west_provider,
        depends_on=[primary_cluster]
    )
)
```

**Cost** (as of 2025-01):
- Aurora Global Database: +$0.20/million writes replicated
- Storage: Same as regional Aurora
- Cross-region network: $0.02/GB
- Typical replication lag: < 1 second

### CockroachDB (Alternative)

**Recommended for**: True multi-region SQL, geo-partitioning, strong consistency

**Cost** (as of 2025-01):
- Dedicated: $0.50/vCPU/hour (~$3,240/month for 3 regions)
- Serverless: $1/million Request Units

**Trade-offs**: Higher cost than Aurora, application changes required, learning curve for geo-partitioning.

### S3 Cross-Region Replication

**Recommended for**: File/object storage, static assets, backups

```python
"""S3 bucket replication across regions."""

import pulumi_aws as aws

# Source bucket (us-east-1)
source_bucket = aws.s3.Bucket(
    "app-source-bucket",
    versioning={"enabled": True},  # Required for replication
    opts=pulumi.ResourceOptions(provider=us_east_provider)
)

# Destination bucket (eu-west-1)
dest_bucket = aws.s3.Bucket(
    "app-dest-bucket",
    versioning={"enabled": True},
    opts=pulumi.ResourceOptions(provider=eu_west_provider)
)

# Replication configuration
replication = aws.s3.BucketReplicationConfigurationV2(
    "app-replication",
    bucket=source_bucket.id,
    role=replication_role.arn,
    rules=[{
        "id": "replicate-all",
        "status": "Enabled",
        "destination": {
            "bucket": dest_bucket.arn,
            "storage_class": "STANDARD_IA",  # Cost optimization
        },
    }],
    opts=pulumi.ResourceOptions(provider=us_east_provider)
)
```

**Cost** (as of 2025-01):
- Replication: $0.02/GB transferred
- Storage: Normal S3 pricing per region
- PUT requests: $0.005/1000 requests

## Deployment Strategies

### Blue/Green Deployment Across Regions

```python
"""Blue/Green deployment with traffic shifting."""

import pulumi
import pulumi_aws as aws


def blue_green_deployment(
    name: str,
    blue_version: str,
    green_version: str,
    traffic_split: int = 0  # 0 = all blue, 100 = all green
) -> None:
    """Deploy blue/green across multiple regions.

    Args:
        name: Application name
        blue_version: Current (blue) version
        green_version: New (green) version
        traffic_split: Percentage of traffic to green (0-100)
    """
    # Route53 weighted routing for gradual shift
    blue_record = aws.route53.Record(
        f"{name}-blue",
        name=f"{name}.example.com",
        type="A",
        set_identifier="blue",
        weighted_routing_policies=[{
            "weight": 100 - traffic_split,
        }],
        records=["1.2.3.4"],  # Blue endpoint
    )

    green_record = aws.route53.Record(
        f"{name}-green",
        name=f"{name}.example.com",
        type="A",
        set_identifier="green",
        weighted_routing_policies=[{
            "weight": traffic_split,
        }],
        records=["5.6.7.8"],  # Green endpoint
    )

# Deployment sequence:
# 1. Deploy green (traffic_split=0)
# 2. Test green endpoint directly
# 3. Shift 10% traffic (traffic_split=10)
# 4. Monitor metrics for 30 minutes
# 5. Gradually increase to 50%, then 100%
# 6. Decommission blue after validation
```

## Monitoring and Alerts

### Health Checks and Alerting

```python
"""Multi-region health monitoring."""

import pulumi_aws as aws
from typing import Any


def create_regional_health_checks(
    regions: list[str],
    endpoints: dict[str, str]
) -> dict[str, aws.route53.HealthCheck]:
    """Create health checks for each region.

    Args:
        regions: List of region identifiers
        endpoints: Region -> endpoint URL mapping

    Returns:
        Region -> HealthCheck mapping
    """
    health_checks = {}

    for region in regions:
        endpoint = endpoints[region]

        health_check = aws.route53.HealthCheck(
            f"health-{region}",
            type="HTTPS",
            resource_path="/health",
            fqdn=endpoint,
            port=443,
            failure_threshold=3,
            request_interval=30,
            measure_latency=True,
            tags={"Region": region},
        )

        # CloudWatch alarm for health check
        alarm = aws.cloudwatch.MetricAlarm(
            f"health-alarm-{region}",
            comparison_operator="LessThanThreshold",
            evaluation_periods=2,
            metric_name="HealthCheckStatus",
            namespace="AWS/Route53",
            period=60,
            statistic="Minimum",
            threshold=1,
            alarm_description=f"Health check failed for {region}",
            alarm_actions=[],  # Add SNS topic ARN
        )

        health_checks[region] = health_check

    return health_checks
```

### Replication Lag Monitoring

```python
"""Monitor Aurora Global Database replication lag."""

import pulumi_aws as aws

# Monitor replication lag between regions
for region in regions:
    replication_lag_alarm = aws.cloudwatch.MetricAlarm(
        f"aurora-replication-lag-{region}",
        comparison_operator="GreaterThanThreshold",
        evaluation_periods=2,
        metric_name="AuroraGlobalDBReplicationLag",
        namespace="AWS/RDS",
        period=60,
        statistic="Average",
        threshold=1000,  # 1 second in milliseconds
        alarm_description=f"Aurora replication lag > 1s in {region}",
        alarm_actions=[],  # Add SNS topic ARN
    )
```

## Cost Analysis

**Estimated Cost** (as of 2025-01):

```python
"""
Active-Active Cost Estimate (2 regions):

Per Region:
- EC2 Auto Scaling (4 × t3.medium): $120/month
- Application Load Balancer: $25/month
- Aurora Global Database (2 instances): $200/month
- Data transfer (intra-region): $30/month
Subtotal per region: $375/month

Total (2 regions): $750/month

Global Services:
- Route53 latency routing: $10/month
- Cross-region data transfer: $100/month
- Aurora Global Database writes: $50/month
Subtotal: $160/month

Total: $910/month (284% of single-region baseline)

For 3 regions:
- Regional costs: $375 × 3 = $1,125/month
- Global services: $200/month
- Total: $1,325/month (414% of baseline)
"""
```

**Cost Optimization**:
- Use Reserved Instances (40-59% savings)
- Optimize Aurora instance sizes per region usage
- Use S3 Intelligent-Tiering for replicated objects
- Minimize cross-region data transfer (cache aggressively)
- Consider spot instances for non-critical workloads

## Related Documentation

- [Multi-Region Overview](./multi-region-overview.md) - Pattern comparison and selection
- [Multi-Region Active-Passive](./multi-region-active-passive.md) - Alternative lower-cost pattern
- [Financial Governance](./financial-governance.md) - Cost management principles
- [Pulumi Guide](./pulumi-guide.md) - Infrastructure as Code basics
- [Cost Estimation](./cost-estimation.md) - Estimating deployment costs
- [Secrets Management](./secrets-management.md) - Multi-region secret distribution
