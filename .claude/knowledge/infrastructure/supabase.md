# Supabase Infrastructure with Pulumi

<!--
MAINTENANCE: Review pricing quarterly (March, June, September, December)
Last reviewed: 2025-01
Next review: 2025-04
-->

## When to Use

**Use Supabase for:**
- PostgreSQL database with automatic APIs
- Authentication (email, OAuth, magic links)
- Real-time subscriptions
- Storage buckets for user uploads
- Edge Functions (Deno runtime)
- Row Level Security (RLS) for multi-tenant apps
- Rapid prototyping and MVPs

**Don't use Supabase for:**
- Extremely large databases (>500GB without Enterprise)
- Applications requiring MySQL/MongoDB (Supabase is PostgreSQL only)
- Complex backend logic (limited to Edge Functions)
- Highly custom authentication flows

## Pricing Overview

**Pricing as of 2025-01:**

**Free Tier:**
- 500 MB database
- 1 GB file storage
- 50k monthly active users (MAU)
- 2 GB bandwidth/month
- 2M Edge Function invocations
- Social OAuth providers
- 7-day log retention

**Pro ($25/month):**
- 8 GB database included ($0.125/GB after)
- 100 GB storage included ($0.021/GB after)
- No MAU limits
- 250 GB bandwidth ($0.09/GB after)
- 2M Edge Function invocations ($2 per million after)
- Daily backups (7-day retention)
- Email support

**Team ($599/month):**
- Everything in Pro plus:
- SOC2 compliance
- 28-day backups
- Priority support

**Enterprise (Custom):**
- 99.95% SLA
- Dedicated infrastructure
- Custom contracts

**Cost at scale:**
- Small app (<10k users): $0-25/month
- Medium app (100k users): $50-150/month
- Large app (1M users): $300-1000/month

## Pulumi Setup

```python
import pulumi
import requests

# Supabase doesn't have official Pulumi provider yet
# Use Management API or supabase CLI

SUPABASE_ACCESS_TOKEN = pulumi.Config("supabase").require_secret("accessToken")
SUPABASE_API = "https://api.supabase.com/v1"

def create_project(name: str, region: str, db_password: str):
    """Create Supabase project via Management API."""
    response = requests.post(
        f"{SUPABASE_API}/projects",
        headers={
            "Authorization": f"Bearer {SUPABASE_ACCESS_TOKEN}",
            "Content-Type": "application/json",
        },
        json={
            "name": name,
            "organization_id": "your-org-id",
            "plan": "pro",  # or "free"
            "region": region,  # us-east-1, eu-west-1, etc.
            "db_password": db_password,
        },
    )
    return response.json()

# Or use supabase CLI
"""
supabase login
supabase projects create my-project --db-password xxx --region us-east-1
"""

# Export connection details
pulumi.export("supabase_url", "https://xxx.supabase.co")
pulumi.export("supabase_anon_key", anon_key)  # Public key
```

## Cost Management

### Monitoring Usage

```bash
# Supabase CLI
supabase projects list
supabase projects api-keys --project-ref xxx

# Check database size
psql postgresql://postgres:[YOUR-PASSWORD]@db.xxx.supabase.co:5432/postgres \
  -c "SELECT pg_size_pretty(pg_database_size('postgres'));"

# Via SQL
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

**Cost estimation:**

```python
"""
Supabase Cost Estimate:

Development:
- Tier: Free
- Database: 200 MB
- Storage: 500 MB
- Bandwidth: 1 GB/month
- MAU: 1000
- Cost: $0/month

Staging:
- Tier: Pro
- Base: $25/month
- Database: 5 GB (within 8 GB included)
- Storage: 50 GB (within 100 GB included)
- Bandwidth: 100 GB (within 250 GB included)
- MAU: 5000
- Cost: $25/month

Production:
- Tier: Pro
- Base: $25/month
- Database: 15 GB (7 GB overage = $0.88)
- Storage: 200 GB (100 GB overage = $2.10)
- Bandwidth: 400 GB (150 GB overage = $13.50)
- MAU: 50000
- Edge Functions: 5M invocations (3M overage = $6)
- Cost: ~$47/month

Total estimated: ~$72/month
"""
```

### Cost Optimization

**1. Optimize database storage:**

```sql
-- Remove old data
DELETE FROM logs WHERE created_at < NOW() - INTERVAL '30 days';

-- Vacuum to reclaim space
VACUUM FULL;

-- Use partitioning for large tables
CREATE TABLE logs_2025_01 PARTITION OF logs
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- Drop old partitions
DROP TABLE logs_2024_01;
```

**2. Optimize storage buckets:**

```sql
-- Set up lifecycle policy (via SQL or Dashboard)
-- Delete files older than 90 days
CREATE POLICY "Delete old files"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'uploads' AND
  created_at < NOW() - INTERVAL '90 days'
);

-- Or use storage triggers to move to cheaper storage
```

**3. Use free tier for development:**

```python
import pulumi

stack = pulumi.get_stack()

# Free tier for dev
supabase_plan = "free" if stack == "dev" else "pro"

if supabase_plan == "free":
    print("WARNING: Free tier has 500 MB database limit")
```

**4. Optimize bandwidth:**

```javascript
// Client-side caching
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(url, key, {
  db: {
    schema: 'public',
  },
  global: {
    headers: {
      'Cache-Control': 'max-age=3600',  // Cache for 1 hour
    },
  },
})

// Use Cloudflare CDN for static assets
// Store large files in Cloudflare R2 instead of Supabase Storage
```

### Budget Alerts

**Supabase doesn't have built-in budget alerts.**
**Monitor via SQL:**

```sql
-- Check database size daily
SELECT pg_size_pretty(pg_database_size('postgres')) as db_size;

-- Check storage usage
SELECT
  bucket_id,
  COUNT(*) as file_count,
  SUM(metadata->>'size')::bigint / (1024*1024) as size_mb
FROM storage.objects
GROUP BY bucket_id;

-- Set up automated monitoring
CREATE OR REPLACE FUNCTION check_database_size()
RETURNS void AS $$
DECLARE
  db_size_gb numeric;
BEGIN
  SELECT pg_database_size('postgres') / (1024^3) INTO db_size_gb;

  IF db_size_gb > 7 THEN
    -- Send alert (implement webhook)
    PERFORM http_post(
      'https://hooks.slack.com/...',
      json_build_object('text', 'Database exceeds 7 GB: ' || db_size_gb || ' GB')::text
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Schedule daily check (use pg_cron extension)
SELECT cron.schedule('check-db-size', '0 9 * * *', 'SELECT check_database_size()');
```

## Database Management

### Schema Migrations

```bash
# Initialize migrations
supabase init
supabase migration new create_users_table

# Edit migration file: supabase/migrations/xxx_create_users_table.sql
```

**Example migration:**

```sql
-- Create users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own data"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own data"
  ON users FOR UPDATE
  USING (auth.uid() = id);

-- Create indexes
CREATE INDEX idx_users_email ON users(email);

-- Create updated_at trigger
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION moddatetime(updated_at);
```

**Apply migrations:**

```bash
supabase db push
# or
supabase migration up
```

### Row Level Security (RLS)

```sql
-- Enable RLS on table
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see published posts or their own drafts
CREATE POLICY "View posts policy"
  ON posts FOR SELECT
  USING (
    status = 'published' OR
    auth.uid() = author_id
  );

-- Policy: Users can only update their own posts
CREATE POLICY "Update posts policy"
  ON posts FOR UPDATE
  USING (auth.uid() = author_id);

-- Policy: Users can only delete their own posts
CREATE POLICY "Delete posts policy"
  ON posts FOR DELETE
  USING (auth.uid() = author_id);

-- Multi-tenant policy: Users can only see data from their organization
CREATE POLICY "Organization isolation"
  ON documents FOR ALL
  USING (
    organization_id IN (
      SELECT organization_id
      FROM user_organizations
      WHERE user_id = auth.uid()
    )
  );
```

## Authentication

### Email/Password and OAuth

**Email/Password**: Use `supabase.auth.signUp()`, `.signInWithPassword()`, and `.signOut()`

**OAuth**: Use `supabase.auth.signInWithOAuth({ provider: 'google' })` with providers configured in Dashboard

Configure in Settings > Authentication in Supabase Dashboard.

## Storage

### Create Buckets

```sql
-- Create public bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true);

-- Create private bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false);
```

### Storage Policies

```sql
-- Policy: Anyone can view avatars
CREATE POLICY "Public avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- Policy: Users can upload their own avatars
CREATE POLICY "Upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Policy: Users can only access their own documents
CREATE POLICY "Access own documents"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

### Upload Files

Use `supabase.storage.from('bucket').upload(path, file)` and `.getPublicUrl(path)` for file operations.

## Edge Functions

Supabase Edge Functions run on Deno. Deploy with `supabase functions deploy <name>`. **Cost**: 2M invocations included on Pro, $2 per million after.

## Real-time Subscriptions

Subscribe to changes with `supabase.channel().on('postgres_changes', config, callback).subscribe()`

Enable per table: `ALTER PUBLICATION supabase_realtime ADD TABLE tablename;`

## Integration with Other Platforms

**Vercel/Netlify**: Use `@supabase/supabase-js` with environment variables (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`)

**Cloudflare Workers**: Use `@supabase/supabase-js` in Workers with `createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY)`

See platform-specific guides for complete integration examples.

## Cost Comparison

**Supabase vs Alternatives:**

| Feature | Supabase Pro | Firebase Blaze | AWS RDS | Neon (Serverless Postgres) |
|---------|-------------|----------------|---------|---------------------------|
| Base cost | $25/month | Pay-per-use | ~$50/month (db.t3.small) | $19/month |
| Database | 8 GB included | 1 GB free then $0.18/GB | Provisioned size | 3 GB included |
| Storage | 100 GB included | 5 GB free then $0.026/GB | Separate (S3) | 10 GB included |
| Auth | Included | Included | Build your own | Not included |
| Real-time | Included | Included ($$) | Build your own | Not included |
| Best for | Full-stack apps | Mobile apps | Enterprise apps | Serverless apps |

**When to choose Supabase:**
- Need PostgreSQL + Auth + Storage + Real-time in one platform
- Want RLS for multi-tenant security
- Prefer open-source (self-hostable)
- Rapid development / MVPs

**When to choose alternatives:**
- Firebase: Mobile-first apps, Firestore (NoSQL) preferred
- RDS: Enterprise compliance, full PostgreSQL control
- Neon: Serverless workloads, true scale-to-zero

## Related Documentation

- [Vercel](vercel.md) - Next.js integration
- [Netlify](netlify.md) - JAMstack integration
- [Cloudflare](cloudflare.md) - CDN and Workers integration
- [Financial Governance](financial-governance.md) - Cost management
- [Cost Estimation](cost-estimation.md) - Detailed pricing
- [Pulumi Guide](pulumi-guide.md) - Infrastructure as Code

---

**Key Takeaway**: Supabase provides PostgreSQL database with built-in Auth, Storage, and Real-time for $25/month (as of 2025-01). Excellent for full-stack applications requiring multi-tenancy via Row Level Security. Monitor database size and bandwidth to avoid overages.
