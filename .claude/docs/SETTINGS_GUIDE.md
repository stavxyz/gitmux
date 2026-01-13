# Claude Code Settings Guide

This document explains the Claude Code settings configured for this organization and how to leverage them effectively.

## Overview

Our `.claude/settings.json` is carefully configured to enforce organizational standards and improve the Claude Code experience. This guide explains each configuration section.

## Model Configuration

**Default Model**: `opus`

This project uses **Claude Opus 4.5** for all operations:
- **All Operations**: Uses Claude Opus 4.5 for planning, execution, code generation, and analysis
- **Benefit**: Maximum reasoning power and highest quality code generation across all tasks
- **Priority**: Quality over speed/cost

### Why Opus?

Full Opus ensures consistent excellence:
- **Opus** provides maximum reasoning power for all operations
- **Best quality** code generation, analysis, and architectural decisions
- **No compromises** - every operation gets the most capable model
- **Override available** if speed or cost is a concern for specific workflows

### Overriding the Default Model

You can override the default model in several ways (listed by priority):

1. **Session Command** (highest priority, temporary):
   ```
   /model opusplan
   /model sonnet
   /model haiku
   ```

2. **Environment Variable** (local override):
   Add to your `.envrc` file:
   ```bash
   export ANTHROPIC_MODEL="opusplan"  # Or "sonnet" for faster execution
   ```

3. **Team Default** (lowest priority):
   Set in `.claude/settings.json` (already configured as `opus`)

### Available Models

- `opus` - Claude Opus 4.5 for all operations ⭐ **Default** (maximum quality)
- `opusplan` - Hybrid approach (Opus for planning, Sonnet for execution, balanced)
- `sonnet` - Claude Sonnet 4.5 for all operations (fast, cost-effective)
- `haiku` - Claude Haiku for simple tasks (fastest, most economical)
- `sonnet[1m]` - Sonnet with 1M token context window (for very large codebases)

### Cost Implications

Different models have different pricing:
- **Full Opus**: Highest cost, maximum quality (default)
- **OpusPlan**: Balanced cost (Opus only for planning phases)
- **Sonnet**: Most cost-effective for general development
- **Haiku**: Most economical for simple tasks

### When to Override

Consider overriding to a different model when:
- **OpusPlan**: Need faster execution while maintaining planning quality
- **Sonnet**: Quick bug fixes or straightforward implementations, cost-conscious
- **Haiku**: Simple file operations or basic code reviews

## Company Announcements

On session start, Claude will randomly display one of these reminders (ordered by priority):

- ⚠️ **Never push to main** - Always use feature branches and PRs (CRITICAL)
- ✅ **Run full test suite** - Execute `pytest tests/ -v` before commits (MANDATORY)
- 🐍 **Always use virtual environments** - Verify with `which python` (REQUIRED)
- 🔧 **Run quality checks** - Execute linting and type checking before commits (QUALITY)
- 📚 **Read the docs** - Familiarize yourself with `.claude/docs/CLAUDE_CODE_RULES.md` (REFERENCE)
- 🌿 **Use direnv** - Create `.envrc` for project environment variables (TIP)

## Environment Variables

### CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR

**Value**: `"true"`
**Type**: Claude Code internal setting

Ensures Claude returns to the project root directory after each bash command. This prevents directory drift during long sessions.

### PYTEST_ADDOPTS

**Value**: `"-v --strict-markers"`

Configures pytest to:
- Run in verbose mode (`-v`) for detailed test output
- Fail on unknown markers (`--strict-markers`) to catch typos

### RUFF_OUTPUT_FORMAT

**Value**: `"concise"`

Makes ruff output more concise and easier to read in Claude's responses.

## direnv Integration

This project uses [direnv](https://direnv.net/) for environment management. While Claude Code doesn't need explicit configuration to work with direnv, you can leverage it for consistent environment setup:

**How it works**:
1. Create a `.envrc` file in your project root (see `.envrc.example`)
2. Add your environment variables
3. direnv automatically loads these when you `cd` into the project
4. Your environment is consistently configured across all tools

**Example .envrc**:
```bash
# Activate Python virtual environment
layout python python3

# Set project-specific variables
export PROJECT_NAME="my-project"
export LOG_LEVEL="DEBUG"
```

**Note**: direnv handles environment loading automatically. Claude will see the environment variables that direnv sets without any additional configuration.

## Why direnv Instead of CLAUDE_ENV_FILE?

Claude Code's `settings.json` doesn't support variable expansion (like `${HOME}` or `${PROJECT_ROOT}`), which made the previous `CLAUDE_ENV_FILE` setting non-functional. Using direnv instead provides:

- **Native shell variable expansion**: Use `${HOME}`, `${PWD}`, and other shell variables
- **Automatic loading on directory change**: Environment sets up when you `cd` into the project
- **Standard tool support**: Works with all CLI tools, not just Claude Code
- **Project isolation**: Each project gets its own environment without conflicts
- **No configuration needed**: Claude Code automatically sees variables direnv loads

This approach aligns with standard development practices and provides a more robust environment management solution.

## Permissions

Our permission model follows the principle of **least privilege** with explicit allows:

### Allowed Tools
- **File operations**: Read, Grep, Glob, Edit, Write
- **Web access**: WebSearch, WebFetch
- **Git operations**: Comprehensive read/write git commands
- **GitHub CLI**: Full `gh` access for issues, PRs, workflows
- **Language tools**: npm, Python, pytest, ruff, mypy, poetry, cargo, go
- **Custom scripts**: `./.claude/scripts/*`

### Denied Operations
Explicitly blocked for safety:
- Reading secrets (`.env`, `credentials.json`, `.ssh/`, `.aws/`)
- Force pushing (`git push --force`)
- Hard resets (`git reset --hard`)
- Dangerous deletions (`rm -rf`)
- Admin PR merges (`gh pr merge --admin`)

## Hooks

### PostToolUse Hook: PR Creation

**Trigger**: `Bash(gh pr create :*)`

After creating a PR, automatically runs `.claude/hooks/post-pr-create.sh` to perform post-creation tasks (like updating tracking state).

### SessionStart Hook: Environment Check

**Trigger**: Session initialization

Checks if `.envrc` exists and provides feedback. This helps users remember to set up their environment configuration.

## Status Line

**Command**: `./.claude/scripts/statusline.sh`

Displays a custom status line with contextual information about:
- Current git branch
- Virtual environment status
- Other project-specific indicators

## Best Practices

### 1. Use direnv for Environment Management

Instead of hardcoding environment variables:
1. Copy `.envrc.example` to `.envrc`
2. Add your configuration
3. Let direnv automatically manage it

### 2. Leverage Company Announcements

These reminders are there to prevent common mistakes. If you see them repeatedly, it means they're protecting you from issues!

### 3. Understand Permission Boundaries

The deny list exists for your protection. If Claude can't access something:
- It might be a secret that shouldn't be in AI context
- It might be a dangerous operation that requires human oversight
- Check with the team if you need access adjusted

### 4. Extend with Local Settings

You can create `.claude/settings.local.json` for personal overrides without affecting the team:

```json
{
  "env": {
    "MY_PERSONAL_VAR": "value"
  }
}
```

## Settings Precedence

Settings are merged in this order (highest to lowest priority):
1. Remote managed settings (Enterprise)
2. File-based managed settings (System)
3. Command-line arguments
4. `.claude/settings.local.json` (Personal)
5. `.claude/settings.json` (Shared/Team)
6. `~/.claude/settings.json` (User)

## Configuration Sync

When running `sync-to-project.py`, all settings (including new ones like `companyAnnouncements` and `env`) are synced to test projects in **union mode**, meaning:
- Source settings are merged into target
- Target-specific customizations are preserved
- Output is automatically sorted for clean diffs

## Additional Configuration Options

For advanced use cases, see the [official Claude Code settings documentation](https://code.claude.com/docs/en/settings) which covers:
- MCP server management
- Plugin configuration
- Sandbox settings
- Advanced hooks
- Remote development environments

## Troubleshooting

### Environment Variables Not Loading

1. Check `.envrc` exists: `ls -la .envrc`
2. Verify syntax: `bash -n .envrc`
3. Ensure direnv is installed and configured

### Permissions Denied

1. Check if operation is in deny list
2. Verify the pattern matches (e.g., `Bash(npm install :*)` allows arguments)
3. Check `.claude/settings.local.json` isn't overriding

### Hooks Not Running

1. Verify hook script exists and is executable
2. Check hook matcher pattern
3. Review hook output in Claude's response

## Related Documentation

- **Critical Rules**: `.claude/docs/CLAUDE_CODE_RULES.md`
- **Engineering Standards**: `.claude/docs/ENGINEERING_STANDARDS.md`
- **Knowledge Base**: `.claude/knowledge/`

---

**Last Updated**: 2025-12-16
**Maintained By**: Engineering Team
