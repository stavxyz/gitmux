# Integrations

## Purpose

This directory is reserved for integration configurations that connect
Claude Code with external tools, services, and APIs.

## Status

🚧 **Placeholder for future feature**

## Future Usage

Integration configurations placed here may enable Claude Code to interact
with external systems such as:

- **Issue trackers**: Jira, Linear, GitHub Issues
- **CI/CD platforms**: GitHub Actions, GitLab CI, CircleCI
- **Monitoring**: Datadog, Sentry, New Relic
- **Documentation**: Confluence, Notion, ReadTheDocs
- **Communication**: Slack, Discord, Microsoft Teams
- **Code quality**: SonarQube, CodeClimate, Snyk
- **Testing**: Playwright, Cypress, BrowserStack

## Configuration Format

Integration configs may follow a standard format like:

```json
{
  "name": "integration-name",
  "type": "issue-tracker|ci-cd|monitoring|...",
  "config": {
    "api_key_env": "ENV_VAR_NAME",
    "base_url": "https://api.example.com",
    ...
  }
}
```

## Notes

- This directory is synced across projects via the sync-to-project tool
- Files placed here will be distributed to target projects
- The sync behavior is `SYNC_ALWAYS` - updates will overwrite target files
- Sensitive credentials should be stored in environment variables, not in config files
