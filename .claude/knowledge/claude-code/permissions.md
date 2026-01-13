# Permissions

## When to Use

**Configuring Claude Code's allowed operations in .claude/settings.json.**

## Quick Reference

```json
{
  "allowlist": [
    "Read",
    "Write",
    "Edit",
    "Bash(git:*)",
    "Bash(pytest:*)",
    "Bash(npm run:*)"
  ],
  "denylist": [
    "Bash(rm -rf:*)",
    "Bash(sudo:*)"
  ]
}
```

## Why This Matters

- **Safety:** Control what Claude can execute
- **Trust:** Allow common operations, deny dangerous ones
- **Flexibility:** Customize per-project needs
- **Security:** Prevent accidental system damage

## Wildcard Syntax

### Basic Pattern: `:*`

**Format:** `Tool(command:*)` or `Tool(command with spaces:*)`

```json
{
  "allowlist": [
    "Bash(git:*)",           // Allow: git status, git add, git commit, etc.
    "Bash(npm run:*)",       // Allow: npm run test, npm run build, etc.
    "Bash(pytest:*)"         // Allow: pytest tests/, pytest -v, etc.
  ]
}
```

### Exact Match (No Wildcard)

```json
{
  "allowlist": [
    "Bash(git status)",      // ONLY allows: git status
    "Bash(npm install)"      // ONLY allows: npm install
  ]
}
```

### Tools Without Parameters

```json
{
  "allowlist": [
    "Read",         // File reading
    "Write",        // File writing
    "Edit",         // File editing
    "Glob",         // File pattern matching
    "Grep"          // Content search
  ]
}
```

## Common Patterns

### Pattern 1: Safe Development

```json
{
  "allowlist": [
    "Read",
    "Write",
    "Edit",
    "Glob",
    "Grep",
    "Bash(git status:*)",
    "Bash(git diff:*)",
    "Bash(git log:*)",
    "Bash(git branch:*)",
    "Bash(pytest:*)",
    "Bash(npm test:*)"
  ],
  "denylist": [
    "Bash(rm:*)",
    "Bash(sudo:*)",
    "Bash(git push:*)"
  ]
}
```

### Pattern 2: Full Git Workflow

```json
{
  "allowlist": [
    "Bash(git:*)",           // All git commands
    "Bash(gh pr:*)",         // GitHub CLI for PRs
    "Bash(gh issue:*)"       // GitHub CLI for issues
  ],
  "denylist": [
    "Bash(git push --force:*)"  // Prevent force push
  ]
}
```

### Pattern 3: Python Development

```json
{
  "allowlist": [
    "Bash(python:*)",        // Run Python scripts
    "Bash(pytest:*)",        // Run tests
    "Bash(pip install:*)",   // Install packages (ensure venv!)
    "Bash(mypy:*)",          // Type checking
    "Bash(ruff:*)"           // Linting and formatting
  ]
}
```

### Pattern 4: Strict Approval

```json
{
  "allowlist": [
    "Read",
    "Glob",
    "Grep"
  ],
  "denylist": [
    "Write",
    "Edit",
    "Bash:*"
  ]
}
```

## AI Assistant Checklist

**When configuring permissions:**
- [ ] Start restrictive, expand as needed
- [ ] Use wildcards (`:*`) for flexibility
- [ ] Deny dangerous commands explicitly
- [ ] Test permissions work as expected
- [ ] Document why specific permissions needed

**Common safe operations:**
- [ ] `Read`, `Glob`, `Grep` - Always safe
- [ ] `Bash(git status:*)` - Read-only git
- [ ] `Bash(pytest:*)` - Running tests
- [ ] `Bash(ls:*)` - Listing files

**Common dangerous operations:**
- [ ] `Bash(rm:*)` - File deletion
- [ ] `Bash(sudo:*)` - System modifications
- [ ] `Bash(git push --force:*)` - Force push
- [ ] `Bash(npm install:*)` - Without venv check

## Wildcard Examples

### Git Commands

```json
{
  "allowlist": [
    "Bash(git status:*)",       // git status, git status --short
    "Bash(git diff:*)",         // git diff, git diff --cached
    "Bash(git log:*)",          // git log, git log --oneline
    "Bash(git add:*)",          // git add ., git add file.py
    "Bash(git commit:*)",       // git commit -m "...", git commit --amend
    "Bash(git push:*)",         // git push, git push origin branch
    "Bash(git checkout:*)",     // git checkout -b branch, git checkout main
    "Bash(gh pr:*)"             // gh pr list, gh pr create, gh pr view
  ]
}
```

### Testing Commands

```json
{
  "allowlist": [
    "Bash(pytest:*)",           // pytest tests/, pytest -v, pytest --cov
    "Bash(npm test:*)",         // npm test, npm test -- --watch
    "Bash(npm run test:*)",     // npm run test:unit, npm run test:e2e
    "Bash(go test:*)",          // go test ./..., go test -v
    "Bash(cargo test:*)"        // cargo test, cargo test --release
  ]
}
```

### Build Commands

```json
{
  "allowlist": [
    "Bash(npm run build:*)",    // npm run build, npm run build:prod
    "Bash(cargo build:*)",      // cargo build, cargo build --release
    "Bash(go build:*)",         // go build, go build -o output
    "Bash(docker build:*)"      // docker build -t tag .
  ]
}
```

### Code Quality

```json
{
  "allowlist": [
    "Bash(ruff check:*)",       // ruff check ., ruff check --fix
    "Bash(ruff format:*)",      // ruff format ., ruff format --check
    "Bash(mypy:*)",             // mypy src/, mypy --strict
    "Bash(eslint:*)",           // eslint ., eslint --fix
    "Bash(prettier:*)"          // prettier --write, prettier --check
  ]
}
```

## Denylist (Blocklist)

**Explicitly deny dangerous operations:**

```json
{
  "denylist": [
    "Bash(rm -rf:*)",           // Recursive delete
    "Bash(sudo:*)",             // System admin
    "Bash(chmod 777:*)",        // Overly permissive
    "Bash(git push --force:*)", // Force push
    "Bash(npm install -g:*)",   // Global install
    "Bash(pip install --user:*)", // User install (use venv!)
    "Bash(dd:*)",               // Disk operations
    "Bash(mkfs:*)",             // Format filesystem
    "Bash(reboot:*)",           // System reboot
    "Bash(shutdown:*)"          // System shutdown
  ]
}
```

## Project-Specific Overrides

**Use settings.local.json for personal preferences:**

```json
// .claude/settings.json (committed)
{
  "allowlist": [
    "Read",
    "Write",
    "Bash(git:*)"
  ]
}

// .claude/settings.local.json (not committed)
{
  "allowlist": [
    "Bash(docker:*)",     // Personal override
    "Bash(kubectl:*)"     // Personal override
  ]
}
```

**Result:** Both lists are merged (allowlists combined)

## Testing Permissions

### Test 1: Verify Allowed Command

```bash
# In Claude Code, try:
"Run git status"

# If allowed → executes
# If denied → asks for approval
```

### Test 2: Verify Denied Command

```bash
# In Claude Code, try:
"Delete all files with rm -rf"

# If denied → Claude refuses or asks approval
# If allowed → BE CAREFUL!
```

### Test 3: Wildcard Scope

```json
{
  "allowlist": ["Bash(git status:*)"]
}
```

```bash
# Should work:
git status
git status --short

# Should NOT work without approval:
git add .
git commit -m "test"
```

## Common Configurations

### Configuration 1: Read-Only Assistant

```json
{
  "allowlist": [
    "Read",
    "Glob",
    "Grep",
    "Bash(git status:*)",
    "Bash(git diff:*)",
    "Bash(git log:*)",
    "Bash(ls:*)"
  ],
  "denylist": [
    "Write",
    "Edit",
    "Bash(git add:*)",
    "Bash(git commit:*)"
  ]
}
```

### Configuration 2: Full Development

```json
{
  "allowlist": [
    "Read",
    "Write",
    "Edit",
    "Glob",
    "Grep",
    "Bash(git:*)",
    "Bash(gh:*)",
    "Bash(pytest:*)",
    "Bash(ruff:*)",
    "Bash(mypy:*)",
    "Bash(npm run:*)"
  ],
  "denylist": [
    "Bash(rm -rf:*)",
    "Bash(sudo:*)",
    "Bash(git push --force:*)"
  ]
}
```

### Configuration 3: Testing Only

```json
{
  "allowlist": [
    "Read",
    "Glob",
    "Grep",
    "Bash(pytest:*)",
    "Bash(npm test:*)",
    "Bash(coverage:*)"
  ],
  "denylist": [
    "Write",
    "Edit",
    "Bash(git:*)"
  ]
}
```

## Gotchas

**"Command works locally but not in Claude"**
- Check allowlist includes command
- Verify wildcard pattern matches
- Test with exact command

**"Wildcard too broad"**
- `Bash(git:*)` allows ALL git commands
- Be specific: `Bash(git status:*)`, `Bash(git diff:*)`

**"Denylist not working"**
- Denylist overrides allowlist
- But may still prompt for approval
- Check exact pattern matching

**"Permissions reset after sync"**
- Template settings.json gets synced
- Use settings.local.json for personal overrides
- Or customize template

## Security Best Practices

**DO:**
- Start with minimal permissions
- Add permissions as needed
- Use specific wildcards
- Deny dangerous commands explicitly
- Test thoroughly

**DON'T:**
- Allow `Bash:*` (too broad)
- Allow `sudo` without good reason
- Allow destructive commands by default
- Commit settings.local.json
- Skip testing new permissions

## Related

- **Focused Prompts:** [claude-code/focused-prompts.md](focused-prompts.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** Use wildcard syntax (`:*`) for flexible permissions. Deny dangerous commands explicitly. Start restrictive, expand as needed.
