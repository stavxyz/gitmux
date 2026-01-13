<!-- MAINTENANCE: Review pricing quarterly (Jan/Apr/Jul/Oct) -->

# Cloud Provider Secret Managers

**When to use this guide**: Integrating with AWS Secrets Manager, GCP Secret Manager, or HashiCorp Vault for centralized secrets management.

**See also**: [Secrets Management](./secrets-management.md) for core principles and Pulumi secrets.

## AWS Secrets Manager

**When to use**:
- AWS-native applications
- Automatic rotation required
- Need RDS integration
- VPC-restricted access

**Cost** (as of 2025-01):
- $0.40/secret/month
- $0.05 per 10,000 API calls

### Basic Usage

```python
"""AWS Secrets Manager integration."""

import boto3
import json
from typing import Any


def get_aws_secret(secret_name: str, region: str = "us-east-1") -> dict[str, Any]:
    """Retrieve secret from AWS Secrets Manager.

    Args:
        secret_name: Name of the secret
        region: AWS region

    Returns:
        Secret value as dictionary

    Raises:
        ClientError: If secret doesn't exist or access denied
    """
    client = boto3.client("secretsmanager", region_name=region)

    try:
        response = client.get_secret_value(SecretId=secret_name)
    except client.exceptions.ResourceNotFoundException:
        raise ValueError(f"Secret '{secret_name}' not found in {region}")
    except client.exceptions.AccessDeniedException:
        raise PermissionError(
            f"Access denied to secret '{secret_name}'. "
            "Check IAM permissions."
        )

    # Parse JSON secrets
    if "SecretString" in response:
        return json.loads(response["SecretString"])

    raise ValueError(f"Secret '{secret_name}' is binary (not supported)")


# Usage
db_creds = get_aws_secret("prod/database/credentials")
database_url = (
    f"postgresql://{db_creds['username']}:{db_creds['password']}"
    f"@{db_creds['host']}/{db_creds['database']}"
)
```

### Pulumi Integration

```python
"""Create and use AWS Secrets Manager with Pulumi."""

import pulumi
import pulumi_aws as aws
import json


# Create a secret
db_secret = aws.secretsmanager.Secret(
    "database-credentials",
    description="Database credentials for production",
    tags={
        "Environment": "production",
        "Application": "my-app",
    }
)

# Store secret value
db_secret_version = aws.secretsmanager.SecretVersion(
    "database-credentials-version",
    secret_id=db_secret.id,
    secret_string=json.dumps({
        "username": "admin",
        "password": "super-secret-password",  # Use Pulumi secret instead
        "host": "db.example.com",
        "database": "myapp"
    })
)

# Use secret in RDS instance
db_instance = aws.rds.Instance(
    "database",
    engine="postgres",
    instance_class="db.t3.medium",
    username=db_secret_version.secret_string.apply(
        lambda s: json.loads(s)["username"]
    ),
    password=db_secret_version.secret_string.apply(
        lambda s: json.loads(s)["password"]
    ),
)
```

### Automatic Rotation

```python
"""Enable automatic secret rotation."""

import pulumi_aws as aws

# Lambda function for rotation (simplified)
rotation_lambda = aws.lambda_.Function(
    "secret-rotation",
    runtime="python3.11",
    handler="index.handler",
    role=rotation_role.arn,
    code=pulumi.FileArchive("./rotation_lambda"),
)

# Enable rotation
rotation_config = aws.secretsmanager.SecretRotation(
    "database-rotation",
    secret_id=db_secret.id,
    rotation_lambda_arn=rotation_lambda.arn,
    rotation_rules={
        "automatically_after_days": 90,  # Rotate every 90 days
    }
)
```

## Google Cloud Secret Manager

**When to use**:
- GCP-native applications
- Need versioning
- Global replication required
- Cost-sensitive (cheaper than AWS)

**Cost** (as of 2025-01):
- $0.06 per 10,000 access operations
- Free for first 6 secret versions per secret
- $0.03/month per additional version

### Basic Usage

```python
"""Google Cloud Secret Manager integration."""

from google.cloud import secretmanager


def get_gcp_secret(project_id: str, secret_id: str, version: str = "latest") -> str:
    """Retrieve secret from GCP Secret Manager.

    Args:
        project_id: GCP project ID
        secret_id: Secret identifier
        version: Secret version (default: latest)

    Returns:
        Secret value as string

    Raises:
        google.api_core.exceptions.NotFound: If secret doesn't exist
    """
    client = secretmanager.SecretManagerServiceClient()

    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version}"

    try:
        response = client.access_secret_version(request={"name": name})
    except Exception as e:
        raise ValueError(
            f"Failed to access secret '{secret_id}' in project '{project_id}': {e}"
        )

    return response.payload.data.decode("UTF-8")


# Usage
api_key = get_gcp_secret("my-project", "api-key")
```

### Pulumi Integration

```python
"""Create and use GCP Secret Manager with Pulumi."""

import pulumi
import pulumi_gcp as gcp

# Create a secret
api_secret = gcp.secretmanager.Secret(
    "api-key",
    secret_id="api-key",
    replication={
        "automatic": {},  # Replicate automatically across regions
    },
    labels={
        "environment": "production",
        "application": "my-app",
    }
)

# Add secret version
api_secret_version = gcp.secretmanager.SecretVersion(
    "api-key-v1",
    secret=api_secret.id,
    secret_data=pulumi.Config().require_secret("apiKey"),
)

# Grant access to service account
secret_iam = gcp.secretmanager.SecretIamMember(
    "api-key-access",
    secret_id=api_secret.id,
    role="roles/secretmanager.secretAccessor",
    member=f"serviceAccount:{service_account.email}",
)
```

### Secret Versioning

GCP Secret Manager supports versioning natively. Use `add_secret_version()` to create new versions and `access_secret_version()` with specific version IDs to retrieve them. First 6 versions per secret are free.

## HashiCorp Vault

**When to use**:
- Large-scale deployments
- Dynamic secrets (database credentials that rotate)
- Complex access control requirements
- Audit logging requirements
- Multi-cloud environments

**Cost** (as of 2025-01):
- Open source: Free (self-hosted)
- HCP Vault: $0.03/hour per cluster + $0.03/hour per client
- Typical 3-node cluster: ~$65/month

### Basic Usage

```python
"""HashiCorp Vault integration example."""

import hvac
from typing import Any


def get_vault_secret(
    vault_url: str,
    token: str,
    path: str
) -> dict[str, Any]:
    """Retrieve secret from HashiCorp Vault.

    Args:
        vault_url: Vault server URL
        token: Vault authentication token
        path: Secret path (e.g., 'secret/data/myapp/config')

    Returns:
        Secret data dictionary

    Raises:
        hvac.exceptions.InvalidPath: If secret doesn't exist
    """
    client = hvac.Client(url=vault_url, token=token)

    if not client.is_authenticated():
        raise PermissionError("Vault authentication failed")

    try:
        response = client.secrets.kv.v2.read_secret_version(path=path)
    except hvac.exceptions.InvalidPath:
        raise ValueError(f"Secret not found at path: {path}")

    return response["data"]["data"]


# Usage
vault_secret = get_vault_secret(
    vault_url="https://vault.example.com",
    token=get_required_env("VAULT_TOKEN"),
    path="myapp/config"
)
```

### Dynamic Database Credentials

```python
"""Generate dynamic database credentials with Vault."""

import hvac
from datetime import timedelta


def get_dynamic_db_credentials(
    vault_url: str,
    token: str,
    db_role: str,
    ttl: timedelta = timedelta(hours=1)
) -> dict[str, str]:
    """Generate dynamic database credentials.

    Args:
        vault_url: Vault server URL
        token: Vault authentication token
        db_role: Database role name
        ttl: Credential time-to-live

    Returns:
        Dictionary with username and password
    """
    client = hvac.Client(url=vault_url, token=token)

    # Generate credentials
    response = client.secrets.database.generate_credentials(
        name=db_role,
        ttl=str(int(ttl.total_seconds())) + "s"
    )

    return {
        "username": response["data"]["username"],
        "password": response["data"]["password"],
        "lease_id": response["lease_id"],
        "lease_duration": response["lease_duration"],
    }


# Usage - credentials auto-expire after TTL
creds = get_dynamic_db_credentials(
    vault_url="https://vault.example.com",
    token=get_required_env("VAULT_TOKEN"),
    db_role="readonly",
    ttl=timedelta(hours=2)
)

database_url = (
    f"postgresql://{creds['username']}:{creds['password']}"
    f"@db.example.com/myapp"
)
```

### AppRole Authentication

```python
"""Authenticate to Vault using AppRole."""

import hvac


def vault_approle_login(
    vault_url: str,
    role_id: str,
    secret_id: str
) -> str:
    """Login to Vault using AppRole.

    Args:
        vault_url: Vault server URL
        role_id: AppRole role ID
        secret_id: AppRole secret ID

    Returns:
        Client token
    """
    client = hvac.Client(url=vault_url)

    response = client.auth.approle.login(
        role_id=role_id,
        secret_id=secret_id,
    )

    return response["auth"]["client_token"]


# Usage
vault_token = vault_approle_login(
    vault_url="https://vault.example.com",
    role_id=get_required_env("VAULT_ROLE_ID"),
    secret_id=get_required_env("VAULT_SECRET_ID")
)

# Use token for subsequent requests
vault_secret = get_vault_secret(
    vault_url="https://vault.example.com",
    token=vault_token,
    path="myapp/config"
)
```

### Vault Policies

```hcl
# Example Vault policy for application
# Path: policies/myapp-read.hcl

# Read secrets under myapp/ path
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Read database credentials
path "database/creds/myapp-readonly" {
  capabilities = ["read"]
}

# Renew own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Lookup own token
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

## Comparison Matrix

| Feature | AWS Secrets Manager | GCP Secret Manager | HashiCorp Vault |
|---------|-------------------|-------------------|-----------------|
| **Cost** | $0.40/secret/month | $0.06/10k ops | Free (OSS) or ~$65/mo |
| **Rotation** | Automatic | Manual | Dynamic |
| **Versioning** | Yes | Yes (free) | Yes |
| **Replication** | Regional | Global | Manual |
| **Dynamic Secrets** | Limited | No | Yes |
| **Audit Logging** | CloudTrail | Cloud Audit Logs | Built-in |
| **Multi-cloud** | No | No | Yes |
| **Learning Curve** | Low | Low | Medium-High |

## Best Practices

### Choose the Right Tool

**AWS Secrets Manager** when:
- Already using AWS ecosystem
- Need RDS automatic rotation
- Budget allows (~$5/month for 10 secrets)

**GCP Secret Manager** when:
- Using GCP services
- Need global replication
- Cost-sensitive (cheaper than AWS)
- Want built-in versioning

**HashiCorp Vault** when:
- Multi-cloud deployment
- Need dynamic secrets
- Complex access policies required
- Have ops team to manage Vault

**Pulumi Secrets** when:
- Simple IaC secrets
- No external dependencies wanted
- Secrets scoped to infrastructure code

### Security Guidelines

1. **Least Privilege**: Grant minimal required permissions
2. **Audit Everything**: Enable logging for all secret access
3. **Rotate Regularly**: Automate rotation where possible
4. **Use Dynamic Secrets**: Prefer short-lived credentials (Vault)
5. **Encrypt Transit**: Always use TLS/HTTPS
6. **Monitor Access**: Alert on unusual patterns

## Related Documentation

- **Fundamentals**: [Secrets Management](./secrets-management.md) - Core principles and Pulumi secrets
- **Cost Management**: [Financial Governance](./financial-governance.md) - Cost tracking for secret managers
- **Infrastructure**: [Pulumi Guide](./pulumi-guide.md) - Infrastructure as Code with Python
- **Monitoring**: [Budget Alerts](./budget-alerts.md) - Alert on secret manager costs
