<!-- MAINTENANCE: Review pricing quarterly (Jan/Apr/Jul/Oct) -->

# Multi-Region Deployment Patterns - Overview

**When to use this guide**: Deploying applications across multiple geographic regions for high availability, disaster recovery, or improved performance for global users.

## Why Multi-Region?

### Use Cases

**High Availability (HA)**:
- Survive regional outages
- Meet 99.99% or 99.999% SLA requirements
- Automatic failover between regions
- Zero-downtime deployments

**Disaster Recovery (DR)**:
- Business continuity requirements
- Regulatory compliance (data residency)
- Backup and restore strategies
- RTO (Recovery Time Objective) < 1 hour

**Performance**:
- Reduce latency for global users
- Edge caching and content delivery
- Regional data processing
- Compliance with data sovereignty laws

### Trade-offs

| Benefit | Cost |
|---------|------|
| 99.99% availability | 2-3x infrastructure cost |
| < 100ms global latency | Data replication costs + complexity |
| Regulatory compliance | Data residency restrictions |
| Zero-downtime deploys | Blue/green deployment overhead |

## Multi-Region Architectures

### Pattern Comparison

| Pattern | Availability | Cost Multiplier | Complexity | Best For |
|---------|--------------|-----------------|------------|----------|
| **Active-Passive** | 99.9-99.99% | 1.2-1.5x | Low | DR, cost optimization |
| **Active-Active** | 99.99-99.999% | 2.0-2.5x | High | Global users, HA |
| **Edge-First CDN** | 99.99%+ | 1.1-1.4x | Medium | Read-heavy, static content |

### Active-Passive (Warm Standby)

**When to use**: DR requirements, cost optimization, simpler architecture

**Architecture**:
```
Primary Region (us-east-1)     Standby Region (eu-west-1)
    ├─ Application (active)       ├─ Application (standby)
    ├─ Database (primary)         ├─ Database (replica)
    └─ Users → Primary            └─ Failover only
```

**Characteristics**:
- Primary region handles all traffic
- Standby region runs at reduced capacity (50%)
- Automatic failover via Route53 health checks
- Database read replicas in standby region
- Manual failover possible for planned maintenance

**Cost** (as of 2025-01):
- Baseline: 100% (single region)
- Active-Passive: 120-150% (standby runs at reduced capacity)

**Estimated Monthly Cost**:
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

**See**: [multi-region-active-passive.md](./multi-region-active-passive.md) for complete implementation.

### Active-Active (Multi-Primary)

**When to use**: Global user base, performance requirements, 99.99%+ availability

**Architecture**:
```
Region A (us-east-1)          Region B (eu-west-1)
    ├─ Application (active)       ├─ Application (active)
    ├─ Database (primary)         ├─ Database (primary)
    └─ Users (Americas)           └─ Users (Europe/Asia)
```

**Characteristics**:
- Both regions handle production traffic
- Global load balancing (latency/geo-based routing)
- Multi-primary database replication
- Full capacity in each region
- Automatic traffic shifting

**Cost** (as of 2025-01):
- Baseline: 100% (single region)
- Active-Active: 200-250% (full deployment in each region)

**Estimated Monthly Cost**:
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
"""
```

**See**: [multi-region-active-active.md](./multi-region-active-active.md) for complete implementation.

### Multi-Region CDN (Edge-First)

**When to use**: Static content, read-heavy workloads, global performance

**Architecture**:
```
Global Edge (Cloudflare/CloudFront)
    ├─ Edge locations (200+)
    ├─ Cache layer
    └─ Origin: Primary region(s)
```

**Characteristics**:
- Edge locations cache content globally
- Origin servers in 1-2 regions
- 95%+ cache hit rate for static content
- Dynamic content proxied to origin
- Automatic DDoS protection

**Cost** (as of 2025-01):
- Baseline: 100% (single region)
- CDN Edge: 110-140% (minimal origin cost increase)

**Estimated Monthly Cost**:
```python
"""
Edge-First CDN Cost Estimate:

Origins (2 regions):
- EC2 t3.small × 2: $30/month
- S3 storage (100GB): $5/month
- S3 requests: $2/month
Subtotal: $37/month

Cloudflare:
- Pro plan: $20/month
- Load Balancing: $5/month
- Workers (if needed): $5/month
- Bandwidth: $0 (unlimited)
Subtotal: $30/month

Total: $67/month (121% of single-region baseline)

Note: Massively cheaper than active-active for read-heavy workloads
"""
```

## Choosing the Right Pattern

### Decision Matrix

**Active-Passive** if:
- Primary goal is disaster recovery
- Budget is constrained
- Traffic is regional (not global)
- RTO of 5-30 minutes is acceptable

**Active-Active** if:
- Global user base with latency requirements
- 99.99%+ availability required
- Budget allows 2-3x infrastructure cost
- Data can be replicated globally

**Edge-First CDN** if:
- Content is mostly static or cacheable
- Read-heavy workload (95%+ reads)
- Global performance needed at low cost
- Origin can handle remaining traffic

### Cost Optimization Tips

**Reserved Instances** (active-passive/active-active):
```python
"""
Cost Savings with Reserved Instances (as of 2025-01):

On-Demand:
- t3.medium: $0.0416/hour = $30.37/month
- 4 instances × 2 regions = $243/month

1-Year Reserved (No Upfront):
- t3.medium: $0.0249/hour = $18.18/month
- 4 instances × 2 regions = $145/month
- Savings: $98/month (40% off)

3-Year Reserved (All Upfront):
- t3.medium: $0.0169/hour = $12.34/month
- 4 instances × 2 regions = $99/month
- Savings: $144/month (59% off)
"""
```

**Selective Replication** (active-active):
```python
"""Cost-optimized selective replication."""

# Replicate only critical data
replication_rules = [{
    "id": "critical-data-only",
    "status": "Enabled",
    "filter": {
        "prefix": "critical/",  # Only replicate critical/ prefix
    },
    "destination": {
        "bucket": dest_bucket.arn,
        "storage_class": "GLACIER_IR",  # Cheaper storage class
    },
}]

# Savings example (as of 2025-01):
# Full replication: 1TB × $0.02/GB = $20.48 transfer cost
# Selective (10%): 100GB × $0.02/GB = $2.05 transfer cost
# Savings: $18.43/month (90% reduction)
```

## Related Documentation

- **Implementation Guides:**
  - [Active-Passive Pattern](./multi-region-active-passive.md) - Complete implementation with failover
  - [Active-Active Pattern](./multi-region-active-active.md) - Global deployment with replication
- **Supporting Topics:**
  - [Financial Governance](./financial-governance.md) - Cost management principles
  - [Pulumi Guide](./pulumi-guide.md) - Infrastructure as Code
  - [Cost Estimation](./cost-estimation.md) - Estimating deployment costs
  - [Cloudflare](./cloudflare.md) - CDN and edge computing
  - [Secrets Management](./secrets-management.md) - Secure multi-region secrets
