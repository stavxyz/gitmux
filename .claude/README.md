# Claude Code Automation System

This directory contains the complete automation system for streamlined software development with Claude Code.

## Overview

**Goal**: Maximize development velocity by automating repetitive tasks while maintaining high code quality.

**Philosophy**: Strive for objective excellence, elegance over bloat, and world-class software engineering practices.

## System Components

### 1. Permission System

**Hierarchical configuration**:
- `~/.claude/settings.json` - Global baseline (read-only operations)
- `.claude/settings.json` - Project-specific permissions (write operations)
- `.claude/settings.local.json` - Personal overrides (gitignored)

**Benefits**:
- No permission prompts for 90%+ of operations
- Secure by default (sensitive files blocked)
- Consistent experience across all projects

### 2. Automated PR Review Loop

**Automatic workflow**:
1. Create PR with `gh pr create`
2. Hook initializes monitoring
3. System detects new reviews via GitHub API
4. Claude automatically addresses feedback
5. Commits and pushes fixes
6. Adds PR comment summarizing changes
7. Repeats until reviews resolved

**Manual trigger**:
```bash
/iterate-pr [PR_NUMBER]
```

## Quick Start

### First Time Setup

1. **Global permissions** are already configured in `~/.claude/settings.json`

2. **Project is ready** - this directory structure is complete

3. **Test the system**:
   ```bash
   # Make some changes
   git checkout -b test-automation
   echo "# Test" >> test.md
   git add test.md
   git commit -m "test: automation system"

   # Create PR (hook will trigger automatically)
   gh pr create --title "Test automation" --body "Testing the system"

   # You should see:
   # ✓ PR monitoring initialized for #X
   # ✓ PR URL: https://github.com/.../pull/X
   # 🤖 Automated review monitoring is active
   ```

4. **Try manual iteration**:
   ```bash
   # Add a review comment on GitHub, then:
   /iterate-pr
   ```

## Directory Structure

```
.claude/
├── settings.json           # Project permissions + hooks
├── settings.local.json     # Personal overrides (create if needed)
│
├── commands/               # Slash commands
│   └── iterate-pr.md      # Manual review iteration
│
├── docs/                   # AI-optimized documentation (synced to all projects)
│   ├── CLAUDE_CODE_RULES.md       # Non-negotiable requirements
│   ├── DESTINATION_PATH_MAPPING.md # Sync engine destination mapping
│   └── ENGINEERING_STANDARDS.md    # Coding standards
│
├── git-hooks/              # Git hooks (tracked in version control)
│   ├── pre-push           # Prevents direct pushes to main/master
│   └── README.md          # Git hooks documentation
│
├── hooks/                  # Claude Code event handlers
│   └── post-pr-create.sh  # Initializes PR monitoring
│
├── knowledge/              # Tactical knowledge base (synced to all projects)
│   ├── automation/        # PR iteration, sync tool usage
│   ├── claude-code/       # Permissions, focused prompts
│   ├── git/               # PR workflow, commit messages
│   ├── python/            # Virtual environments, type hints
│   ├── testing/           # pytest basics, test structure
│   └── README.md          # Knowledge base index
│
├── prompts/                # AI instructions
│   └── iterate-pr-reviews.md # Review iteration workflow
│
├── scripts/                # Utility scripts
│   ├── sync-to-project.py # Main sync tool entry point
│   ├── install-git-hooks.sh # Legacy hook installer (deprecated)
│   ├── setup-webhook.sh   # Webhook configuration
│   ├── check-pr-reviews.sh # Detect new reviews
│   ├── verify-pr-ready.sh # PR readiness checks
│   ├── analyze-check-runs.sh # CI check analysis
│   ├── sync_engine/       # Sync tool Python modules
│   │   ├── __init__.py
│   │   ├── backup.py      # Backup/restore functionality
│   │   ├── cli.py         # CLI commands (sync, doctor, rollback)
│   │   ├── constants.py   # File rules, categories, patterns
│   │   ├── core.py        # Core sync logic
│   │   ├── file_ops.py    # File operations, destination mapping
│   │   ├── reporter.py    # Rich console output
│   │   ├── settings_merger.py # JSON settings merge logic
│   │   └── validators.py  # Validation utilities
│   └── tests/             # Python unit tests
│       ├── test_destination_mapping.py
│       ├── test_file_ops.py
│       ├── test_integration_git_hooks.py
│       └── test_settings_merger.py
│
├── state/                  # Runtime state (gitignored)
│   └── pr_*_monitor.json  # PR monitoring state
│
├── logs/                   # Debug logs (gitignored)
│
└── README.md              # This file
```

## How It Works

### PR Creation Flow

```
Developer runs: gh pr create
    ↓
PostToolUse hook triggers: .claude/hooks/post-pr-create.sh
    ↓
Hook extracts PR number and URL
    ↓
Creates monitoring state: .claude/state/pr_123_monitor.json
    ↓
Runs webhook setup: .claude/scripts/setup-webhook.sh
    ↓
System ready to detect reviews
```

### Review Iteration Flow

```
Developer runs: /iterate-pr (or reviews posted automatically trigger it)
    ↓
Check for reviews: .claude/scripts/check-pr-reviews.sh
    ↓
If new reviews found:
    ↓
Load iteration prompt: .claude/prompts/iterate-pr-reviews.md
    ↓
Claude analyzes all feedback
    ↓
Makes necessary code changes
    ↓
Commits with descriptive message
    ↓
Pushes to PR branch
    ↓
Posts PR comment summarizing changes
    ↓
Checks for more reviews → repeat if found
```

## Slash Commands

### /iterate-pr

Manually check for and address PR review feedback.

```bash
/iterate-pr          # Auto-detect current branch's PR
/iterate-pr 123      # Explicit PR number
```

## Configuration

### Adding Project-Specific Permissions

Edit `.claude/settings.json` to add permissions for project-specific tools:

```json
{
  "permissions": {
    "allow": [
      "Bash(make test)",
      "Bash(docker-compose up -d)"
    ]
  }
}
```

### Personal Overrides

Create `.claude/settings.local.json` (gitignored) for personal preferences:

```json
{
  "permissions": {
    "allow": [
      "Bash(my-custom-script.sh)"
    ]
  }
}
```

## State Files

### PR Monitor State

`.claude/state/pr_123_monitor.json`:
```json
{
  "pr_number": "123",
  "pr_url": "https://github.com/owner/repo/pull/123",
  "repo_owner": "owner",
  "repo_name": "repo",
  "started_at": "2025-12-03T20:00:00Z",
  "last_review_check": "2025-12-03T20:15:00Z",
  "iterations": 2,
  "status": "monitoring",
  "new_items_found": 3,
  "webhook_mode": "api_polling"
}
```

## Workflow Policies

### Review Conflict Resolution

When multiple reviewers give conflicting feedback:
- **Most recent feedback wins** (our policy)
- Claude posts PR comment explaining chosen approach
- Tags reviewers if clarification needed

### CI Integration

- Reviews addressed immediately (don't wait for CI)
- CI failures are analyzed and fixed if straightforward
- Complex failures trigger PR comment asking for help

### Iteration Limits

- Maximum 10 iterations per PR review cycle
- Prevents infinite loops
- Triggers human intervention when limit reached

## Safety Mechanisms

1. **Explicit permissions**: All write operations require project-level approval
2. **Audit trail**: Every change committed with clear attribution
3. **State tracking**: Prevents duplicate processing of same review
4. **Iteration limits**: Stops after 10 cycles, asks for guidance
5. **Denied operations**: Force push, hard reset explicitly blocked

## Troubleshooting

### Hook not triggering

Check hook file is executable:
```bash
ls -la .claude/hooks/post-pr-create.sh
# Should show -rwxr-xr-x

# If not:
chmod +x .claude/hooks/post-pr-create.sh
```

### Reviews not detected

Manually run the check script:
```bash
bash .claude/scripts/check-pr-reviews.sh <PR_NUMBER>
```

Check state file exists:
```bash
ls -la .claude/state/
```

### Commands not updated after sync

Claude Code caches command files (`.claude/commands/*.md`) at session start. If you sync new command content to a project while Claude Code is open:

**Solution**: Restart Claude Code in the target project to pick up changes.

The sync tool now prints a reminder about this after successful syncs.

### Permission denied errors

Check your permissions in `.claude/settings.json` allow the operation.

View current permissions:
```bash
/permissions
```

### Cleanup tracked runtime files (one-time migration)

If you previously had runtime files tracked in git (e.g., `.claude/state/*.json`, `.claude/settings.local.json`), you need to untrack them once:

```bash
# Remove tracked runtime files (preserves local copies)
# Note: These commands are safe to run even if the patterns match no files.
# If you see "No such file or directory", you're already clean!
git rm --cached .claude/state/*.json 2>/dev/null || true
git rm --cached .claude/settings.local.json 2>/dev/null || true
git rm --cached .claude/logs/* 2>/dev/null || true
git rm --cached .claude/.backup/* 2>/dev/null || true

# Catch-all for any subdirectories or nested files (ensures complete cleanup)
git rm --cached -r .claude/state/ .claude/logs/ .claude/.backup/ 2>/dev/null || true

# Commit the cleanup (only if there are changes to commit)
git commit -m "chore: untrack runtime files per gitignore updates"
```

**Why?** Files added to `.gitignore` after being tracked remain tracked. This one-time cleanup ensures runtime files stay local only.

**Note:** The nested `.gitignore` files in each directory (`.claude/state/.gitignore`, `.claude/logs/.gitignore`, `.claude/.backup/.gitignore`) are managed by the sync tool and should not be modified.

**Timeline:** These migration instructions are needed during the PR #51 transition period. They can be removed from this README after all target projects have synced (circa Q1 2025).

## Next Steps

### Phase 2: Intelligence (Coming Soon)

- Pre-PR quality gates (auto-lint, format, security scan)
- Test generation when reviewers request tests
- Review pattern learning and knowledge base
- Predictive feedback analysis

### Phase 3: The /ship Command (Future)

End-to-end automation from code to production:
```bash
/ship "Add new feature"
```

See `.claude/plans/sparkling-chasing-aurora.md` for complete roadmap.

## Tips for Success

1. **Trust the system**: Let automation handle routine review feedback
2. **Review the commits**: Check what Claude did, learn from it
3. **Provide clear feedback**: The clearer review comments are, the better Claude performs
4. **Iterate quickly**: Faster feedback cycles = faster shipping
5. **Monitor metrics**: Track how much time automation saves

## Support

- Documentation: `.claude/plans/sparkling-chasing-aurora.md`
- Example configs: `.claude/plans/example-*.json`
- Issues: Report in GitHub issues

## Philosophy

> "Code that strives for perfection is not bloated and is written by a developer or AI that is thinking hard and thoughtfully to see ahead of the curve, anticipating edge cases, making it test-friendly, avoiding anti-patterns and generally following world-class software development principles."

This automation system embodies these principles - helping you ship faster while maintaining exceptional quality.
