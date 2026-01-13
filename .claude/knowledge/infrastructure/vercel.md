# Vercel Infrastructure with Pulumi

<!--
MAINTENANCE: Review pricing quarterly (March, June, September, December)
Last reviewed: 2025-01
Next review: 2025-04
-->

## When to Use

**Use Vercel for:**
- Next.js applications (best-in-class support)
- React/Vue/Svelte static sites
- Serverless functions (Edge and Node.js)
- Preview deployments for every PR
- Global CDN with zero configuration

**Don't use Vercel for:**
- Long-running processes (30s limit on Hobby, 300s on Pro)
- Large file uploads (4.5MB request limit)
- Complex backend APIs (consider separate backend)
- Cost-sensitive high-traffic apps (can get expensive at scale)

## Pricing Overview

**Hobby (Free):**
- Personal/non-commercial projects
- Unlimited deployments
- 100 GB bandwidth/month
- Serverless function execution: 100 GB-hours
- No custom domains on free tier (vercel.app only)

**Pro ($20/month):**
- Commercial use allowed
- 1 TB bandwidth/month
- 1000 GB-hours execution
- Custom domains
- Password protection
- Analytics

**Enterprise (Custom pricing):**
- Advanced collaboration
- SSO/SAML
- 99.99% SLA
- Dedicated support

**Cost at scale:**
- Bandwidth: $40/TB after included amount
- Execution: $40/100 GB-hours after included
- 1M page views ≈ $50-150/month (depends on traffic patterns)
- 10M page views ≈ $500-1500/month

## Pulumi Setup

```python
import pulumi
import pulumi_vercel as vercel

# Configure Vercel provider
config = pulumi.Config("vercel")
vercel_provider = vercel.Provider(
    "vercel",
    api_token=config.require_secret("apiToken"),
)

# Create project
project = vercel.Project(
    "my-app",
    name="my-app",
    framework="nextjs",
    git_repository=vercel.ProjectGitRepositoryArgs(
        type="github",
        repo="my-org/my-app",
    ),
    opts=pulumi.ResourceOptions(provider=vercel_provider),
)

# Configure environment variables
vercel.ProjectEnvironmentVariable(
    "next-public-api-url",
    project_id=project.id,
    key="NEXT_PUBLIC_API_URL",
    value="https://api.example.com",
    target=["production", "preview", "development"],
    opts=pulumi.ResourceOptions(provider=vercel_provider),
)

# Configure secrets
vercel.ProjectEnvironmentVariable(
    "database-url",
    project_id=project.id,
    key="DATABASE_URL",
    value=database_url,  # Pulumi secret
    target=["production"],
    sensitive=True,
    opts=pulumi.ResourceOptions(provider=vercel_provider),
)

pulumi.export("project_url", project.id.apply(
    lambda id: f"https://{project.name}.vercel.app"
))
```

## Cost Management

### Monitoring Usage

**Check current usage:**

```bash
# Vercel CLI
vercel teams switch  # Select team
vercel domains ls    # List domains
vercel deployments ls  # List deployments

# Via API (requires Vercel API token)
curl https://api.vercel.com/v1/teams/{teamId}/usage \
  -H "Authorization: Bearer ${VERCEL_TOKEN}"
```

**Pulumi cost estimation:**

```python
"""
Vercel Cost Estimate:

Development:
- Tier: Hobby (Free)
- Bandwidth: <100 GB/month
- Cost: $0/month

Staging:
- Tier: Pro
- Base: $20/month
- Bandwidth: ~200 GB/month (within included 1 TB)
- Execution: ~500 GB-hours/month (within included 1000)
- Cost: ~$20/month

Production:
- Tier: Pro
- Base: $20/month
- Bandwidth: ~2 TB/month (1 TB overage = $40)
- Execution: ~1500 GB-hours/month (500 overage = $20)
- Cost: ~$80/month

Total estimated: ~$100/month
"""
```

### Cost Optimization

**1. Use appropriate tier:**

```python
import pulumi

stack = pulumi.get_stack()

# Hobby for dev, Pro for staging/prod
use_hobby_tier = stack == "dev"

if use_hobby_tier:
    print("WARNING: Using Hobby tier - commercial use not allowed")
```

**2. Optimize bandwidth:**

```typescript
// next.config.js
module.exports = {
  // Enable compression
  compress: true,

  // Optimize images
  images: {
    formats: ['image/avif', 'image/webp'],
    minimumCacheTTL: 60,
  },

  // Asset prefix for CDN
  assetPrefix: process.env.CDN_URL,
}
```

**3. Cache aggressively:**

```typescript
// pages/api/data.ts
export default function handler(req, res) {
  // Cache for 1 hour
  res.setHeader('Cache-Control', 's-maxage=3600, stale-while-revalidate')
  res.json({ data: 'example' })
}
```

**4. Use Edge Functions sparingly:**

```python
# Edge Functions have lower limits and different pricing
# Use Node.js serverless functions for most use cases
# Only use Edge for:
# - Geolocation
# - A/B testing
# - Request/response modification
```

### Budget Alerts

**Vercel doesn't have programmatic budget alerts.**
**Set up manual monitoring:**

1. **Vercel Dashboard > Settings > Billing**
   - Check spending periodically
   - Set calendar reminders

2. **Email notifications:**
   - Vercel sends emails at 50%, 80%, 100% of plan limits

3. **Custom monitoring:**

```python
# scripts/check_vercel_usage.py
import requests
import os

VERCEL_TOKEN = os.getenv("VERCEL_TOKEN")
TEAM_ID = os.getenv("VERCEL_TEAM_ID")

response = requests.get(
    f"https://api.vercel.com/v1/teams/{TEAM_ID}/usage",
    headers={"Authorization": f"Bearer {VERCEL_TOKEN}"},
)

usage = response.json()

# Check bandwidth
bandwidth_gb = usage["bandwidth"]["total"] / (1024**3)
bandwidth_limit_gb = 1000  # Pro tier

if bandwidth_gb > bandwidth_limit_gb * 0.8:
    print(f"WARNING: Bandwidth at {bandwidth_gb:.1f} GB (80% of limit)")

# Check function execution
execution_hours = usage["executionTime"] / 3600
execution_limit_hours = 1000  # Pro tier

if execution_hours > execution_limit_hours * 0.8:
    print(f"WARNING: Execution at {execution_hours:.1f} hours (80% of limit)")
```

## Integration with Supabase

```python
import pulumi
import pulumi_vercel as vercel
import pulumi_supabase as supabase

# Create Supabase project
supabase_project = supabase.Project(
    "database",
    name="my-app-db",
    organization_id=supabase_org_id,
    database_password=db_password,
    region="us-east-1",
)

# Configure Vercel with Supabase credentials
vercel.ProjectEnvironmentVariable(
    "supabase-url",
    project_id=vercel_project.id,
    key="NEXT_PUBLIC_SUPABASE_URL",
    value=supabase_project.api_url,
    target=["production", "preview"],
)

vercel.ProjectEnvironmentVariable(
    "supabase-anon-key",
    project_id=vercel_project.id,
    key="NEXT_PUBLIC_SUPABASE_ANON_KEY",
    value=supabase_project.anon_key,
    target=["production", "preview"],
)

vercel.ProjectEnvironmentVariable(
    "supabase-service-key",
    project_id=vercel_project.id,
    key="SUPABASE_SERVICE_ROLE_KEY",
    value=supabase_project.service_role_key,
    target=["production"],
    sensitive=True,
)
```

## Integration with Cloudflare

```python
import pulumi
import pulumi_cloudflare as cloudflare
import pulumi_vercel as vercel

# Cloudflare DNS for custom domain
zone = cloudflare.get_zone(name="example.com")

# CNAME to Vercel
cloudflare.Record(
    "vercel-cname",
    zone_id=zone.id,
    name="app",
    type="CNAME",
    value="cname.vercel-dns.com",
    proxied=True,  # Enable Cloudflare CDN/WAF
)

# Add domain to Vercel project
vercel.ProjectDomain(
    "custom-domain",
    project_id=vercel_project.id,
    domain="app.example.com",
)
```

## Common Patterns

### Multi-Environment Setup

```python
import pulumi

stack = pulumi.get_stack()
git_branch = {
    "dev": "develop",
    "staging": "staging",
    "production": "main",
}[stack]

project = vercel.Project(
    f"my-app-{stack}",
    name=f"my-app-{stack}",
    framework="nextjs",
    git_repository=vercel.ProjectGitRepositoryArgs(
        type="github",
        repo="my-org/my-app",
        production_branch=git_branch,
    ),
)
```

### Preview Deployments

**Automatic preview deployments for every PR:**

```python
# Vercel automatically creates preview deployments
# Configure GitHub integration in Vercel dashboard

# Access preview URL in PR comments:
# https://my-app-git-feature-branch-my-team.vercel.app
```

### Serverless Functions

```typescript
// pages/api/hello.ts
import type { NextApiRequest, NextApiResponse } from 'next'

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  // Auto-deployed as serverless function
  res.status(200).json({ message: 'Hello from Vercel!' })
}

// Edge Function (runs on Cloudflare Workers)
export const config = {
  runtime: 'edge',
}
```

## Cost Comparison

**Vercel vs Alternatives:**

| Feature | Vercel Pro | Netlify Pro | Cloudflare Pages |
|---------|-----------|-------------|-----------------|
| Base cost | $20/month | $19/month | $0/month (free tier adequate) |
| Bandwidth | 1 TB included | 1 TB included | Unlimited |
| Build minutes | 6000 | 25000 | 500 (then $5/500) |
| Serverless | 1000 GB-hours | 125k function hours | 100k requests/day free |
| Best for | Next.js apps | JAMstack sites | Static sites + Workers |

**When to use each:**
- **Vercel**: Next.js apps, tight framework integration, best DX
- **Netlify**: Static sites, forms, split testing, large builds
- **Cloudflare Pages**: Cost-sensitive projects, static sites, global edge

## Related Documentation

- **Netlify**: `.claude/knowledge/infrastructure/netlify.md`
- **Cloudflare**: `.claude/knowledge/infrastructure/cloudflare.md`
- **Supabase**: `.claude/knowledge/infrastructure/supabase.md`
- **Financial Governance**: `.claude/knowledge/infrastructure/financial-governance.md`

---

**Key Takeaway**: Vercel excels at Next.js deployments with zero-config CDN and preview deployments. Monitor usage closely at scale - bandwidth and function execution costs can grow quickly.
