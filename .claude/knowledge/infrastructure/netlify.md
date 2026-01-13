# Netlify Infrastructure with Pulumi

<!--
MAINTENANCE: Review pricing quarterly (March, June, September, December)
Last reviewed: 2025-01
Next review: 2025-04
-->

## When to Use

**Use Netlify for:**
- Static sites (React, Vue, Svelte, Hugo, Jekyll)
- JAMstack applications
- Forms and user submissions
- Serverless functions (AWS Lambda under the hood)
- Split testing and analytics
- Large build processes (25,000 minutes/month on Pro)

**Don't use Netlify for:**
- Server-side rendered apps (use Vercel for Next.js)
- Long-running processes (10s background function limit)
- High-bandwidth video streaming (expensive)
- Complex backend APIs (consider separate backend)

## Pricing Overview

**Free Tier:**
- 100 GB bandwidth/month
- 300 build minutes/month
- 125k serverless function requests/month
- Community support only

**Pro ($19/month per member):**
- 1 TB bandwidth/month
- 25,000 build minutes/month
- Unlimited serverless function requests
- Form submissions (10k/month)
- Analytics
- Deploy previews with password protection

**Business ($99/month per member):**
- Same as Pro plus:
- Role-based access control
- Audit logs
- 99.9% SLA upfront

**Cost at scale:**
- Bandwidth: $55/TB after included
- Build minutes: $7/500 after included
- Function execution: Included (unlimited on Pro)
- 1M page views ≈ $20-50/month
- 10M page views ≈ $100-400/month

## Pulumi Setup

```python
import pulumi
import json

# Netlify doesn't have official Pulumi provider yet
# Use Netlify API directly or netlify-cli

# Configuration via netlify.toml (checked into repo)
netlify_config = {
    "build": {
        "command": "npm run build",
        "publish": "out",
        "environment": {
            "NODE_VERSION": "18",
        },
    },
    "functions": {
        "directory": "netlify/functions",
    },
    "redirects": [
        {
            "from": "/api/*",
            "to": "/.netlify/functions/:splat",
            "status": 200,
        },
    ],
}

# Write netlify.toml
with open("netlify.toml", "w") as f:
    import toml
    toml.dump(netlify_config, f)

# For programmatic control, use Netlify API
import requests

NETLIFY_TOKEN = pulumi.Config("netlify").require_secret("token")
NETLIFY_API = "https://api.netlify.com/api/v1"

def create_site(name: str, repo_url: str):
    """Create Netlify site via API."""
    response = requests.post(
        f"{NETLIFY_API}/sites",
        headers={"Authorization": f"Bearer {NETLIFY_TOKEN}"},
        json={
            "name": name,
            "custom_domain": f"{name}.netlify.app",
            "repo": {
                "provider": "github",
                "repo": repo_url,
                "private": False,
                "branch": "main",
            },
        },
    )
    return response.json()

# Or use Netlify CLI in CI/CD
"""
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod --dir=out
"""
```

## Cost Management

### Monitoring Usage

```bash
# Netlify CLI
netlify status
netlify sites:list
netlify deploy --dry-run  # Check what would be deployed

# Via API
curl https://api.netlify.com/api/v1/accounts \
  -H "Authorization: Bearer ${NETLIFY_TOKEN}"

curl https://api.netlify.com/api/v1/sites/{site_id}/usage \
  -H "Authorization: Bearer ${NETLIFY_TOKEN}"
```

**Cost estimation:**

```python
"""
Netlify Cost Estimate:

Development:
- Tier: Free
- Bandwidth: ~50 GB/month
- Build minutes: ~200/month
- Cost: $0/month

Staging:
- Tier: Pro
- Base: $19/month
- Bandwidth: ~300 GB/month (within 1 TB)
- Build minutes: ~5000/month (within 25k)
- Cost: ~$19/month

Production:
- Tier: Pro
- Base: $19/month
- Bandwidth: ~1.5 TB/month (500 GB overage = $27.50)
- Build minutes: ~8000/month (within 25k)
- Analytics: Included
- Cost: ~$46.50/month

Total estimated: ~$65/month
"""
```

### Cost Optimization

**1. Optimize build minutes:**

```toml
# netlify.toml
[build]
  command = "npm run build"
  publish = "out"

# Cache dependencies
[build.environment]
  NPM_FLAGS = "--prefer-offline --no-audit"

# Skip builds when unnecessary
[build]
  ignore = "git diff --quiet HEAD^ HEAD -- src/"
```

**2. Reduce bandwidth:**

```javascript
// next.config.js or similar
module.exports = {
  // Asset optimization
  compress: true,

  // Image optimization
  images: {
    formats: ['image/avif', 'image/webp'],
  },

  // Static file headers
  async headers() {
    return [
      {
        source: '/static/(.*)',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ]
  },
}
```

**3. Use free tier for dev:**

```python
import pulumi

stack = pulumi.get_stack()

# Free tier for development
use_free_tier = stack == "dev"

if use_free_tier:
    print("Using Netlify Free tier for dev environment")
else:
    print("Using Netlify Pro tier for staging/production")
```

### Budget Alerts

**Netlify doesn't have built-in budget alerts.**
**Manual monitoring:**

```python
# scripts/check_netlify_usage.py
import requests
import os

NETLIFY_TOKEN = os.getenv("NETLIFY_TOKEN")
SITE_ID = os.getenv("NETLIFY_SITE_ID")

# Get usage
response = requests.get(
    f"https://api.netlify.com/api/v1/sites/{SITE_ID}/usage",
    headers={"Authorization": f"Bearer {NETLIFY_TOKEN}"},
)

usage = response.json()

# Check bandwidth (Pro includes 1 TB = 1,000,000 MB)
bandwidth_mb = usage.get("bandwidth", 0)
bandwidth_limit_mb = 1_000_000  # 1 TB

if bandwidth_mb > bandwidth_limit_mb * 0.8:
    print(f"WARNING: Bandwidth at {bandwidth_mb / 1000:.1f} GB (80% of 1 TB)")

# Check build minutes (Pro includes 25,000)
build_minutes = usage.get("build_minutes", 0)
build_limit = 25_000

if build_minutes > build_limit * 0.8:
    print(f"WARNING: Build minutes at {build_minutes} (80% of {build_limit})")
```

## Integration with Supabase

```javascript
// netlify/functions/api.ts
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!
)

export async function handler(event, context) {
  const { data, error } = await supabase
    .from('items')
    .select('*')

  return {
    statusCode: 200,
    body: JSON.stringify(data),
  }
}
```

**Environment variables in netlify.toml:**

```toml
[build.environment]
  SUPABASE_URL = "https://xxx.supabase.co"
  SUPABASE_ANON_KEY = "eyJ..." # Public anon key is safe in repo

# Secrets via Netlify UI or CLI
# netlify env:set SUPABASE_SERVICE_ROLE_KEY "secret-key"
```

## Integration with Cloudflare

**Use Cloudflare as CDN in front of Netlify:**

```python
import pulumi
import pulumi_cloudflare as cloudflare

zone = cloudflare.get_zone(name="example.com")

# CNAME to Netlify
cloudflare.Record(
    "netlify-cname",
    zone_id=zone.id,
    name="app",
    type="CNAME",
    value="mysite.netlify.app",
    proxied=True,  # Enable Cloudflare CDN/WAF
    comment="Netlify app with Cloudflare CDN",
)

# Set up Cloudflare Workers for advanced logic
# (Cheaper than Netlify Edge Functions at scale)
```

## Common Patterns

### Forms with Serverless Backend

```html
<!-- Contact form (built-in Netlify Forms) -->
<form name="contact" method="POST" data-netlify="true">
  <input type="text" name="name" required />
  <input type="email" name="email" required />
  <textarea name="message" required></textarea>
  <button type="submit">Send</button>
</form>
```

**Pro tier includes 10k form submissions/month.**

### Background Functions

```javascript
// netlify/functions/background-task.ts
export async function handler(event, context) {
  // This can run for up to 10 seconds (vs 10s for regular functions)
  // Triggered asynchronously
  await performLongTask()

  return {
    statusCode: 200,
  }
}

// Trigger background function
fetch('/.netlify/functions/background-task', {
  method: 'POST',
  headers: { 'x-nf-background': 'true' },  // Background mode
})
```

### Branch Deploys

```toml
# netlify.toml
[context.production]
  command = "npm run build:prod"

[context.staging]
  command = "npm run build:staging"

[context.branch-deploy]
  command = "npm run build:preview"

# Deploy previews for all branches
[build]
  publish = "out"
```

**Automatic deploys:**
- Production: `main` branch
- Staging: `staging` branch
- Preview: All other branches (PRs)

### Split Testing

```toml
# netlify.toml
[[redirects]]
  from = "/"
  to = "/variant-a"
  status = 200
  conditions = {Cookie = ["variant=a"]}

[[redirects]]
  from = "/"
  to = "/variant-b"
  status = 200
  conditions = {Cookie = ["variant=b"]}

# 50/50 split test
[[edge_handlers]]
  handler = "ab-test"
```

**Pro tier includes split testing via Netlify Analytics.**

## Cost Comparison

**Netlify vs Vercel vs Cloudflare Pages:**

| Feature | Netlify Pro | Vercel Pro | Cloudflare Pages Free |
|---------|------------|-----------|----------------------|
| Base cost | $19/month | $20/month | $0/month |
| Bandwidth | 1 TB | 1 TB | Unlimited |
| Build minutes | 25,000 | 6,000 | 500 (then $5/500) |
| Functions | Unlimited requests | 1000 GB-hours | 100k requests/day |
| Forms | 10k submissions | Not included | Not included |
| Best for | JAMstack + forms | Next.js apps | Static sites |

**When to choose Netlify:**
- You need forms (saves building custom backend)
- Large build processes (25k minutes > Vercel's 6k)
- Split testing built-in
- Prefer AWS Lambda (vs Cloudflare Workers)

**When to choose Vercel:**
- Next.js application (better integration)
- Edge Functions needed
- Tighter framework integration

**When to choose Cloudflare Pages:**
- Cost-sensitive projects
- Static sites + Workers
- Unlimited bandwidth critical

## Migration from Vercel

**Key differences:**

1. **Framework detection:**
   - Vercel: Automatic
   - Netlify: Configure in netlify.toml

2. **Environment variables:**
   - Vercel: UI or `vercel.json`
   - Netlify: UI, CLI, or `netlify.toml`

3. **Serverless functions:**
   - Vercel: `pages/api/` or `api/`
   - Netlify: `netlify/functions/`

4. **Redirects:**
   - Vercel: `next.config.js` or `vercel.json`
   - Netlify: `netlify.toml` or `_redirects` file

**Migration checklist:**
```bash
# 1. Create netlify.toml
cat > netlify.toml <<EOF
[build]
  command = "npm run build"
  publish = "out"

[[redirects]]
  from = "/api/*"
  to = "/.netlify/functions/:splat"
  status = 200
EOF

# 2. Move serverless functions
mv api/ netlify/functions/

# 3. Update imports
# Change: export default function handler(req, res)
# To: export async function handler(event, context)

# 4. Connect repo in Netlify UI
# 5. Set environment variables
# 6. Deploy
netlify deploy --prod
```

## Related Documentation

- **Vercel**: `.claude/knowledge/infrastructure/vercel.md`
- **Cloudflare**: `.claude/knowledge/infrastructure/cloudflare.md`
- **Supabase**: `.claude/knowledge/infrastructure/supabase.md`
- **Financial Governance**: `.claude/knowledge/infrastructure/financial-governance.md`

---

**Key Takeaway**: Netlify excels at JAMstack sites with built-in forms, generous build minutes, and split testing. More cost-effective than Vercel for large build processes and high-traffic static sites.
