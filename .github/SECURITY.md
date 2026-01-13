# Security Policy

## Security Scanning Strategy

This project employs a three-tier security scanning approach in CI/CD:

### 1. pip-audit (Blocking)
- **Status**: Fails CI on any known vulnerabilities
- **Purpose**: Critical supply chain security - prevents merging code with known CVEs in dependencies
- **Rationale**: Known vulnerabilities in dependencies are objective security issues that must be addressed

### 2. safety (Non-blocking)
- **Status**: Reports issues but does not fail CI
- **Purpose**: Additional vulnerability database cross-reference
- **Rationale**: May have false positives or flag issues that require triage; provides defense-in-depth

### 3. bandit (Non-blocking)
- **Status**: Reports issues but does not fail CI
- **Purpose**: Static security analysis for common code security issues
- **Rationale**: Requires triage for false positives (e.g., B101 assert usage in appropriate contexts)

## Reporting Security Vulnerabilities

If you discover a security vulnerability in this project, please report it by:

1. **Do NOT open a public issue** - this could put users at risk
2. **Email the maintainers** at the address listed in `pyproject.toml`
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

## Security Update Schedule

### Dependency Updates
- **Security dependencies** (pip-audit, safety, bandit): Reviewed quarterly
- **Runtime dependencies**: Reviewed when security advisories are published
- **Critical CVEs**: Addressed within 48 hours of disclosure

### Response Timeline
- **Critical vulnerabilities** (CVSS 9.0-10.0): Patch within 48 hours
- **High severity** (CVSS 7.0-8.9): Patch within 1 week
- **Medium severity** (CVSS 4.0-6.9): Patch within 2 weeks
- **Low severity** (CVSS 0.1-3.9): Addressed in next regular release

## Security Best Practices

When contributing to this project:

1. **Never commit secrets** - Use environment variables or secret management
2. **Use explicit error handling** - Avoid assertions in production code (use explicit checks)
3. **Pin dependencies** - All dependencies should specify exact versions for reproducibility
4. **Run security scans locally** before pushing:
   ```bash
   pip-audit --skip-editable
   safety check --full-report
   bandit -r . -ll
   ```

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < main  | :x:                |

We currently only support the latest version from the `main` branch.
