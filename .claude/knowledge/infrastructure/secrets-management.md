<!-- MAINTENANCE: Review pricing quarterly (Jan/Apr/Jul/Oct) -->

# Secrets Management for Infrastructure as Code

**When to use this guide**: Setting up secure secrets management for API keys, tokens, database credentials, and other sensitive configuration in infrastructure deployments.

**See also**: [Secrets Cloud Providers](./secrets-cloud-providers.md) for AWS, GCP, and HashiCorp Vault integration.

## Core Principles

### Never Commit Secrets to Git

**Critical Rule**: API tokens, database passwords, and other secrets must NEVER be committed to version control.

**Why it matters**:
- Git history is permanent (even after deletion)
- Public repositories expose secrets to the internet
- Private repos can become public or be accessed by unauthorized users
- Automated scanners constantly search GitHub for leaked credentials

### Assume Breach Mindset

Design your secrets management as if:
- Your git repository will become public tomorrow
- A team member's laptop will be compromised
- Your CI/CD logs will be exposed
- Your cloud account will be accessed by an attacker

## Secrets Management Solutions

### Pulumi Secrets (Recommended for IaC)

**Strengths**:
- Encrypted at rest in state files
- Encrypted in transit
- Integrated with infrastructure code
- Per-stack encryption keys
- Works with all cloud providers

**Cost** (as of 2025-01): Free for self-managed state, $1/secret/month for Pulumi Cloud

**Basic Usage**:

```python
"""Pulumi secrets management example."""

import pulumi

# Set secrets via CLI (encrypted in stack config)
# $ pulumi config set --secret databasePassword "super-secret-123"

config = pulumi.Config()

# Access secrets in code
database_password = config.require_secret("databasePassword")
api_key = config.require_secret("apiKey")

# Secrets are automatically masked in logs
pulumi.export("dbHost", "db.example.com")  # This appears in logs
pulumi.export("dbPassword", database_password)  # This shows [secret] in logs
```

**Setting Secrets**:

```bash
# Interactive (password hidden)
pulumi config set --secret myApiKey

# From environment variable
pulumi config set --secret cloudflareToken "${CLOUDFLARE_TOKEN}"

# From file
pulumi config set --secret sshPrivateKey < ~/.ssh/id_rsa

# List config (secrets show as [secret])
pulumi config
```

**Best Practices**:

```python
"""Comprehensive secrets management with Pulumi."""

import pulumi
from typing import Any


def get_secret(key: str, default: str | None = None) -> pulumi.Output[str]:
    """Get a secret with validation.

    Args:
        key: Secret key in config
        default: Optional default value (NOT for production secrets)

    Returns:
        Secret value as Pulumi Output

    Raises:
        pulumi.RunError: If secret is required but not set
    """
    config = pulumi.Config()

    if default is not None:
        return config.get_secret(key) or pulumi.Output.secret(default)

    # Fail fast if secret is missing
    return config.require_secret(key)


def validate_secret_format(
    secret: pulumi.Output[str],
    pattern: str,
    name: str
) -> None:
    """Validate secret matches expected format.

    Args:
        secret: Secret value to validate
        pattern: Regex pattern the secret should match
        name: Name of secret (for error messages)
    """
    import re

    def check(value: str) -> None:
        if not re.match(pattern, value):
            raise ValueError(
                f"Secret '{name}' does not match expected format. "
                f"Expected pattern: {pattern}"
            )

    secret.apply(check)


# Usage
api_token = get_secret("apiToken")
validate_secret_format(
    api_token,
    r"^sk-[a-zA-Z0-9]{48}$",
    "apiToken"
)
```

### Environment Variables

**When to use**:
- Local development
- CI/CD pipelines
- Application runtime configuration
- Non-IaC deployments

**Security Warnings**:
- Never commit `.env` files to git
- Never log environment variables
- Never pass secrets in command-line arguments (visible in `ps`)
- Use `.envrc` with direnv for local development
- Rotate secrets if they appear in logs

**Setup**:

```bash
# .envrc (git-ignored, loaded by direnv)
export DATABASE_URL="postgresql://user:pass@localhost/db"
export API_KEY="sk-abc123..."
export CLOUDFLARE_TOKEN="xyz789..."

# Load with direnv
direnv allow

# Or source manually
source .envrc
```

```python
"""Environment variable secrets with validation."""

import os
import sys
from typing import Optional


def get_required_env(key: str) -> str:
    """Get required environment variable.

    Args:
        key: Environment variable name

    Returns:
        Environment variable value

    Raises:
        SystemExit: If environment variable is not set
    """
    value = os.getenv(key)
    if not value:
        print(
            f"Error: Required environment variable '{key}' not set",
            file=sys.stderr
        )
        print(f"Set it with: export {key}='your-value'", file=sys.stderr)
        sys.exit(1)
    return value


def get_env_with_default(key: str, default: str) -> str:
    """Get environment variable with fallback.

    WARNING: Only use default for non-sensitive config!

    Args:
        key: Environment variable name
        default: Default value if not set

    Returns:
        Environment variable value or default
    """
    return os.getenv(key, default)


# Usage
database_url = get_required_env("DATABASE_URL")
api_key = get_required_env("API_KEY")
log_level = get_env_with_default("LOG_LEVEL", "INFO")  # OK for non-secrets
```

**`.gitignore` Patterns**:

```gitignore
# Secrets and credentials
.env
.env.*
!.env.example
.envrc
.envrc.local

# Cloud provider credentials
.aws/credentials
.gcp/credentials.json
.azure/credentials

# Pulumi secrets
Pulumi.*.yaml  # Stack configs may contain encrypted secrets (OK to commit)
```

## Security Best Practices

### Rotation

**Recommended rotation schedule**:

| Secret Type | Rotation Frequency |
|------------|-------------------|
| API keys (production) | 90 days |
| Database passwords | 90 days |
| SSH keys | 1 year |
| TLS certificates | Per certificate lifetime (typically 90 days) |
| Service account tokens | 90 days |
| Development/staging secrets | 180 days |

**Automated rotation example**:

```python
"""Automated secret rotation with Pulumi."""

import pulumi
import pulumi_random as random
from datetime import datetime, timedelta


def create_rotating_password(name: str, rotation_days: int = 90) -> pulumi.Output[str]:
    """Create a password that rotates automatically.

    Args:
        name: Resource name
        rotation_days: How often to rotate (days)

    Returns:
        Generated password
    """
    # Keepers trigger new password generation
    rotation_date = (datetime.now() + timedelta(days=rotation_days)).isoformat()

    password = random.RandomPassword(
        f"{name}-password",
        length=32,
        special=True,
        override_special="!#$%&*()-_=+[]{}<>:?",
        keepers={
            "rotation_date": rotation_date,
        }
    )

    return password.result
```

### Least Privilege Access

**Principle**: Grant minimum permissions needed.

```python
"""Example: Scope secrets to specific resources."""

import pulumi
import pulumi_aws as aws
import json

# BAD: Admin access to all secrets
bad_policy = aws.iam.Policy(
    "bad-secrets-policy",
    policy=json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": "secretsmanager:*",
            "Resource": "*"
        }]
    })
)

# GOOD: Read-only access to specific secret
good_policy = aws.iam.Policy(
    "good-secrets-policy",
    policy=json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "arn:aws:secretsmanager:us-east-1:123456789:secret:prod/api-key"
        }]
    })
)
```

### Audit Logging

**Track secret access**:

```python
"""CloudWatch logging for secret access."""

import json
import pulumi_aws as aws

# Enable CloudWatch logging for Secrets Manager
trail = aws.cloudtrail.Trail(
    "secrets-audit-trail",
    s3_bucket_name=audit_bucket.id,
    enable_logging=True,
    event_selectors=[{
        "readWriteType": "All",
        "includeManagementEvents": True,
        "dataResources": [{
            "type": "AWS::SecretsManager::Secret",
            "values": ["arn:aws:secretsmanager:*:*:secret:*"]
        }]
    }]
)
```

## Common Pitfalls

### Hardcoded Secrets

```python
# DON'T DO THIS
DATABASE_URL = "postgresql://admin:password123@db.example.com/prod"
API_KEY = "sk-abc123def456"
```

### Secrets in Code Comments

```python
# DON'T DO THIS
# TODO: Replace with actual API key: sk-test-abc123...
api_key = get_env("API_KEY")
```

### Secrets in Error Messages

```python
# DON'T DO THIS
try:
    authenticate(api_key)
except AuthError:
    print(f"Authentication failed with key: {api_key}")
```

### Secrets in URLs

```python
# DON'T DO THIS
requests.get(f"https://api.example.com/data?api_key={api_key}")

# DO THIS
requests.get(
    "https://api.example.com/data",
    headers={"Authorization": f"Bearer {api_key}"}
)
```

## Related Documentation

- **Cloud Providers**: [Secrets Cloud Providers](./secrets-cloud-providers.md) - AWS, GCP, Vault integration
- **Cost Management**: [Financial Governance](./financial-governance.md) - Cost management and tagging
- **Infrastructure**: [Pulumi Guide](./pulumi-guide.md) - Infrastructure as Code with Python
- **Monitoring**: [Budget Alerts](./budget-alerts.md) - Monitoring and cost alerts
