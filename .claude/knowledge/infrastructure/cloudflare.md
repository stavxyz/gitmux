# Cloudflare Infrastructure with Pulumi

<!--
MAINTENANCE: Review pricing quarterly (March, June, September, December)
Last reviewed: 2025-01
Next review: 2025-04
-->

## When to Use

**Use Cloudflare for:**
- DNS management (fast, reliable, free)
- CDN and DDoS protection (unlimited bandwidth on all tiers)
- Workers for edge computing (serverless at global scale)
- R2 object storage (S3-compatible, no egress fees)
- Pages for static sites (free tier excellent)
- D1 SQLite databases at the edge
- WAF and security rules

**Don't use Cloudflare for:**
- Long-running processes (Workers have CPU time limits)
- Large compute workloads (Workers optimized for edge, not compute)
- Complex state management (Workers are stateless)
- Traditional databases (use D1 for SQLite, or connect to external DB)

## Pricing Overview

**Pricing as of 2025-01:**

**Free Tier:**
- Unlimited bandwidth (no overage charges!)
- 100k Workers requests/day
- 10 Workers
- DNS (unlimited domains)
- DDoS protection
- SSL certificates
- Page Rules (3)

**Pro ($20/month per domain):**
- Everything in Free plus:
- Advanced DDoS
- Web Application Firewall (WAF)
- Image optimization
- 20 Page Rules

**Workers Paid ($5/month):**
- 10M requests/month included
- $0.50 per additional million requests
- No CPU time limits (was 50ms free, unlimited paid)
- KV storage: $0.50/GB/month
- Durable Objects: $0.15/million requests

**R2 Storage:**
- $0.015/GB/month (storage)
- No egress fees (vs S3's $0.09/GB egress)
- $4.50 per million Class A operations
- $0.36 per million Class B operations

**Cost at scale:**
- 1M page views ≈ $0-5/month (mostly free)
- 10M page views ≈ $5-20/month
- 100M page views ≈ $50-100/month
- **Significantly cheaper than Vercel/Netlify at scale**

## Pulumi Setup

```python
import pulumi
import pulumi_cloudflare as cloudflare

# Configure Cloudflare provider
config = pulumi.Config("cloudflare")
cloudflare_provider = cloudflare.Provider(
    "cloudflare",
    api_token=config.require_secret("apiToken"),
)

# Get zone (domain)
zone = cloudflare.get_zone(name="example.com")

# DNS records
cloudflare.Record(
    "www",
    zone_id=zone.id,
    name="www",
    type="CNAME",
    value="example.com",
    proxied=True,  # Enable Cloudflare CDN
    comment="WWW subdomain",
    opts=pulumi.ResourceOptions(provider=cloudflare_provider),
)

# Export zone ID
pulumi.export("zone_id", zone.id)
```

## Cost Management

### Monitoring Usage

```bash
# Cloudflare CLI (wrangler)
npm install -g wrangler
wrangler login

# Check Workers usage
wrangler usage

# Check R2 usage
wrangler r2 bucket list

# Via API
curl https://api.cloudflare.com/client/v4/accounts/{account_id}/usage \
  -H "Authorization: Bearer ${CLOUDFLARE_TOKEN}"
```

**Cost estimation:**

```python
"""
Cloudflare Cost Estimate:

Development:
- DNS: Free
- Workers: Free (100k requests/day)
- Pages: Free
- R2: $0 (no data yet)
- Total: $0/month

Production:
- DNS: Free
- Workers Paid: $5/month base
  - 50M requests/month = 40M overage = $20
- R2 Storage: 100 GB = $1.50/month
- R2 Operations: ~10M Class B = $3.60
- Pages Pro: $20/month (optional)
- Total: ~$50/month

Key advantage: No bandwidth charges!
Compare to AWS S3: 100 GB egress = $9/GB × 100 = $900/month
Cloudflare R2: $0 egress
"""
```

### Cost Optimization

**1. Use Workers efficiently:**

```javascript
// workers/api.ts

// Cache responses at edge
export default {
  async fetch(request, env, ctx) {
    const cache = caches.default

    // Check cache first
    let response = await cache.match(request)
    if (response) return response

    // Generate response
    response = await generateResponse(request)

    // Cache for 1 hour
    const cacheResponse = response.clone()
    cacheResponse.headers.set('Cache-Control', 'max-age=3600')
    ctx.waitUntil(cache.put(request, cacheResponse))

    return response
  }
}
```

**2. Use KV for cheap storage:**

```javascript
// Workers KV is cheaper than Durable Objects for read-heavy workloads

// wrangler.toml
kv_namespaces = [
  { binding = "CACHE", id = "xxx", preview_id = "yyy" }
]

// Worker code
export default {
  async fetch(request, env) {
    // Read from KV (cheap)
    const cached = await env.CACHE.get('key')
    if (cached) return new Response(cached)

    // Compute and store
    const result = await expensiveOperation()
    await env.CACHE.put('key', result, { expirationTtl: 3600 })

    return new Response(result)
  }
}
```

**3. Use R2 instead of S3:**

```python
import pulumi_cloudflare as cloudflare

# Create R2 bucket
r2_bucket = cloudflare.R2Bucket(
    "assets",
    account_id=cloudflare_account_id,
    name="my-app-assets",
)

# No egress fees!
# S3 charges $0.09/GB for data transfer
# R2 charges $0 for data transfer
# Savings on 1 TB egress: $90/month
```

**4. Combine with Pages (free tier):**

```bash
# Cloudflare Pages is free for unlimited sites
# Use for static assets, Workers for dynamic logic

wrangler pages publish out/ --project-name my-app
```

### Budget Alerts

**Cloudflare doesn't have built-in budget alerts.** Monitor via API using Analytics Engine SQL or dashboard metrics.

For usage monitoring script examples, see `.claude/knowledge/infrastructure/cost-tracking.md`

## DNS Management

### Basic Records

```python
import pulumi_cloudflare as cloudflare

zone_id = cloudflare.get_zone(name="example.com").id

# A record
cloudflare.Record(
    "root-a",
    zone_id=zone_id,
    name="@",  # Root domain
    type="A",
    value="192.0.2.1",
    proxied=True,  # Enable CDN/DDoS protection
)

# CNAME
cloudflare.Record(
    "www-cname",
    zone_id=zone_id,
    name="www",
    type="CNAME",
    value="example.com",
    proxied=True,
)

# MX records for email
cloudflare.Record(
    "mx1",
    zone_id=zone_id,
    name="@",
    type="MX",
    value="mx1.emailprovider.com",
    priority=10,
    proxied=False,  # MX records cannot be proxied
)
```

### Advanced DNS

```python
# Geo-steering (route users to nearest server)
cloudflare.LoadBalancer(
    "global-lb",
    zone_id=zone_id,
    name="app.example.com",
    fallback_pool_id=default_pool.id,
    default_pool_ids=[us_pool.id, eu_pool.id, asia_pool.id],
    proxied=True,
    steering_policy="geo",  # Route by geography
)

# Health checks
us_pool = cloudflare.LoadBalancerPool(
    "us-pool",
    name="us-servers",
    origins=[
        cloudflare.LoadBalancerPoolOriginArgs(
            name="us-east-1",
            address="us-east.example.com",
            enabled=True,
        ),
    ],
    monitor_id=health_check.id,
)

health_check = cloudflare.LoadBalancerMonitor(
    "health-check",
    type="https",
    path="/health",
    interval=60,
    timeout=5,
    retries=2,
)
```

## Cloudflare Workers

### Basic Worker

```javascript
// workers/hello.ts
export default {
  async fetch(request, env, ctx) {
    try {
      return new Response('Hello from Cloudflare Workers!', {
        headers: { 'Content-Type': 'text/plain' },
      })
    } catch (error) {
      console.error('Worker error:', error)
      return new Response('Internal Server Error', { status: 500 })
    }
  }
}
```

**Deploy with Pulumi:**

```python
import pulumi
import pulumi_cloudflare as cloudflare

# Upload Worker script
worker_script = cloudflare.WorkerScript(
    "api-worker",
    account_id=cloudflare_account_id,
    name="api-worker",
    content=open("workers/api.js").read(),
)

# Route traffic to Worker
cloudflare.WorkerRoute(
    "api-route",
    zone_id=zone_id,
    pattern="api.example.com/*",
    script_name=worker_script.name,
)

# Or use wrangler CLI
"""
wrangler deploy
"""
```

### Workers with Database (D1)

D1 provides SQLite at the edge. Access via `env.DB.prepare(query).bind(params).all()`

**Setup**: `wrangler d1 create production-db` and configure binding in `wrangler.toml`

### Workers with KV Storage

KV provides fast key-value storage. Access via `env.KV.get(key)` and `env.KV.put(key, value)`

See Cloudflare docs for complete API reference.

## R2 Object Storage

### Create R2 Bucket

```python
import pulumi_cloudflare as cloudflare

# Create R2 bucket
r2_bucket = cloudflare.R2Bucket(
    "media-bucket",
    account_id=cloudflare_account_id,
    name="my-app-media",
)

pulumi.export("r2_bucket_name", r2_bucket.name)
```

### Access R2 from Workers

Access R2 via `env.BUCKET.get(key)` for reads and `env.BUCKET.put(key, data)` for writes.

Configure binding in `wrangler.toml` with `[[r2_buckets]]`

## Cloudflare Pages

### Deploy Static Site

```bash
# Install wrangler
npm install -g wrangler

# Build your site
npm run build

# Deploy to Pages
wrangler pages publish out/ --project-name my-app

# Automatic deployments via GitHub integration
# Connect repo in Cloudflare Dashboard > Pages
```

**With Pulumi (using Pages API):**

```python
# Cloudflare Pages doesn't have Pulumi provider yet
# Use wrangler CLI or GitHub integration

# For git integration, configure in Dashboard:
# 1. Connect GitHub repo
# 2. Set build command: npm run build
# 3. Set output directory: out
# 4. Add environment variables
```

### Pages Functions

Pages Functions are Workers with file-based routing: `functions/api/hello.ts` → `/api/hello`

## WAF and Security

### Firewall Rules

```python
import pulumi_cloudflare as cloudflare

# Block specific countries
cloudflare.FirewallRule(
    "block-countries",
    zone_id=zone_id,
    description="Block high-risk countries",
    filter_id=cloudflare.Filter(
        "country-filter",
        zone_id=zone_id,
        expression='(ip.geoip.country in {"CN" "RU" "KP"})',
        description="High-risk countries",
    ).id,
    action="block",
)

# Rate limiting
cloudflare.RateLimit(
    "api-rate-limit",
    zone_id=zone_id,
    threshold=100,  # Max 100 requests
    period=60,  # Per 60 seconds
    match=cloudflare.RateLimitMatchArgs(
        request=cloudflare.RateLimitMatchRequestArgs(
            url_pattern="api.example.com/*",
        ),
    ),
    action=cloudflare.RateLimitActionArgs(
        mode="challenge",  # Show CAPTCHA
    ),
)
```

## Integration with Other Platforms

**Vercel/Netlify**: Point CNAME to their DNS and enable Cloudflare proxy for DDoS protection + WAF

**Supabase**: Use Workers to proxy requests with `@supabase/supabase-js`

See platform-specific guides for detailed integration examples.

## Cost Comparison

**Cloudflare vs AWS/GCP/Azure:**

| Feature | Cloudflare | AWS | GCP | Azure |
|---------|-----------|-----|-----|-------|
| CDN bandwidth | Unlimited free | $0.085/GB | $0.08/GB | $0.087/GB |
| Object storage (1TB) | R2: $15/month | S3: $23/month | GCS: $20/month | Blob: $18/month |
| Egress (1TB) | R2: $0 | S3: $90 | GCS: $120 | Blob: $87 |
| Edge compute (10M req) | $5 | Lambda@Edge: $50 | Cloud Functions: $40 | Functions: $45 |

**Cloudflare is significantly cheaper at scale, especially for high-bandwidth applications.**

## Related Documentation

- [Vercel](vercel.md) - Next.js deployments
- [Netlify](netlify.md) - JAMstack sites
- [Supabase](supabase.md) - PostgreSQL database integration
- [Financial Governance](financial-governance.md) - Cost management
- [Cost Estimation](cost-estimation.md) - Detailed pricing breakdown
- [Pulumi Guide](pulumi-guide.md) - Infrastructure as Code basics

---

**Key Takeaway**: Cloudflare offers unbeatable value for CDN, DNS, and edge compute. R2's zero egress fees make it ideal for high-bandwidth applications. Workers provide global edge compute at $0.50 per million requests (as of 2025-01).
