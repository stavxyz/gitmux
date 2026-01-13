# Context Files

## Purpose

This directory is reserved for context files that can be used to provide
additional information to Claude Code during interactions.

## Status

🚧 **Placeholder for future feature**

## Future Usage

Context files placed here may be automatically included in Claude Code
sessions to provide project-specific context, background information, or
reference material that helps the AI assistant better understand your
project's domain and requirements.

## Examples of Potential Context

- Domain-specific glossaries or terminology
- Business rules and constraints
- Architecture decision records (ADRs)
- Project background and history
- API reference documentation
- Database schema descriptions

## Notes

- This directory is synced across projects via the sync-to-project tool
- Files placed here will be distributed to target projects
- The sync behavior is `SYNC_ALWAYS` - updates will overwrite target files
