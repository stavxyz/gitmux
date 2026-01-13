# Sync Tool Usage

## When to Use

**Syncing .claude/ automation to target projects.**

## Quick Reference

```bash
# Dry-run (preview changes)
./.claude/scripts/sync-to-project.py sync --dry-run ~/my-project

# Actual sync
./.claude/scripts/sync-to-project.py sync ~/my-project

# List backups
./.claude/scripts/sync-to-project.py list-backups ~/my-project

# Rollback to previous state
./.claude/scripts/sync-to-project.py rollback ~/my-project
```

## Why This Matters

- **Consistency:** All projects use same standards
- **Updates:** Easy to propagate improvements
- **Safety:** Dry-run and rollback available
- **Validation:** Checks permissions, gitignore compliance
- **Educational:** Reports what changed and why

## Patterns

### Pattern 1: First-Time Sync (New Project)

```bash
# 1. Preview what will happen
./.claude/scripts/sync-to-project.py sync --dry-run ~/my-project

# 2. Review output, ensure looks correct

# 3. Run actual sync
./.claude/scripts/sync-to-project.py sync ~/my-project

# 4. Verify in target project
cd ~/my-project
ls -la .claude/
cat .claude/settings.json
```

### Pattern 2: Update Existing Project

```bash
# Project already has .claude/ directory

# 1. Dry-run to see what will change
./.claude/scripts/sync-to-project.py sync --dry-run ~/existing-project

# 2. Review changes (especially settings.json merge)

# 3. Apply updates
./.claude/scripts/sync-to-project.py sync ~/existing-project

# 4. Check merged settings
cat ~/existing-project/.claude/settings.json
```

### Pattern 3: Safe Experimentation

```bash
# 1. Sync to project
./.claude/scripts/sync-to-project.py sync ~/my-project

# 2. Test changes in project
cd ~/my-project
# ... test automation, run commands, etc ...

# 3. If something went wrong, rollback
./.claude/scripts/sync-to-project.py rollback ~/my-project
```

## What Gets Synced

### SYNC_ALWAYS (Overwrite Every Time)
```bash
.claude/
├── commands/*.md        # Slash commands
├── hooks/*.sh           # Git hooks
├── prompts/*.md         # AI prompts
├── scripts/*.sh         # Shell scripts
├── scripts/*.py         # Python scripts
├── docs/*.md            # Engineering standards
├── knowledge/**/*.md    # Knowledge base
├── context/*            # Project context
├── integrations/*       # Integrations
└── metrics/*            # Metrics
```

### MERGE_SMART (Intelligent Merge)
```bash
.claude/
└── settings.json        # Merged with project settings
```

### COPY_IF_MISSING (Only If Doesn't Exist)
```bash
.claude/
├── README.md            # Don't overwrite custom docs
└── CLAUDE.md            # Don't overwrite project-specific rules
```

### SKIP_ALWAYS (Never Touch)
```bash
.claude/
├── settings.local.json  # User-specific settings
├── state/*              # Runtime state
└── logs/*               # Log files
```

## Understanding Sync Categories

### Why Different Categories?

Not all files should be synced the same way. Some must stay synchronized (scripts), others need customization (templates), and some should never sync (local state).

### SYNC_ALWAYS - Critical Dependencies

Files that **must stay synchronized** with the template:

**Examples:**
- `.claude/scripts/requirements.txt` - Script dependencies must match scripts
- `.github/workflows/*.txt` - CI tool versions must match workflow expectations
- `.claude/scripts/*.py` - Automation scripts themselves

**Rationale:**
- If `.claude/scripts/sync-to-project.py` imports `typer` but project's `requirements.txt` doesn't have it → import failure
- If workflow runs `ruff check` but `requirements-quality.txt` has wrong version → CI breaks

**What happens:**
- Every sync overwrites project version with template version
- No customization allowed
- Ensures template and dependencies stay in lockstep

### COPY_IF_MISSING - Customizable Standards

Files that provide **defaults but allow customization**:

**Examples:**
- `.github/PULL_REQUEST_TEMPLATE.md` - Teams may have custom PR checklists
- `.github/SECURITY.md` - Organizations may have specific security policies
- `.github/ISSUE_TEMPLATE/*.yml` - Projects may need custom issue forms
- `.envrc.example` - Projects have unique environment variables
- `.claude/CLAUDE.md` - Project-specific AI instructions

**Rationale:**
- One-size-fits-all templates don't work for these files
- Organizations have different standards
- Projects have unique requirements

**What happens:**
1. First sync: Template version copied to project
2. You customize in your project
3. Future syncs: **Your version preserved** (not overwritten)
4. Want template updates? Manually merge or delete and re-sync

### How to Customize COPY_IF_MISSING Files

**Pattern 1: Start with template, then customize**
```bash
# 1. First sync copies template
./.claude/scripts/sync-to-project.py sync ~/my-project

# 2. Customize in your project
cd ~/my-project
vi .github/PULL_REQUEST_TEMPLATE.md
git commit -m "chore: customize PR template for our team"

# 3. Future syncs won't overwrite
./.claude/scripts/sync-to-project.py sync ~/my-project
# Your customizations preserved ✅
```

**Pattern 2: Want template updates later**
```bash
# Option A: Delete and re-sync (loses customizations)
rm ~/my-project/.github/PULL_REQUEST_TEMPLATE.md
./.claude/scripts/sync-to-project.py sync ~/my-project

# Option B: Manual merge (keeps customizations)
diff ~/persuade/.github/PULL_REQUEST_TEMPLATE.md \
     ~/my-project/.github/PULL_REQUEST_TEMPLATE.md
# Manually merge changes
```

### MERGE_SMART - Intelligent Merge

Files that **combine template and project values**:

**Examples:**
- `.claude/settings.json` - Permissions and allowlists

**Rationale:**
- Template provides baseline permissions
- Projects need project-specific additions
- Can't just overwrite or ignore

**What happens:**
- Allowlists: Combined (template + project)
- Denylists: Template overrides project (security)
- Other fields: Project values preserved

See "Settings Merge Behavior" section for details.

### SKIP_ALWAYS - Never Touch

Files that **should never sync**:

**Examples:**
- `.claude/settings.local.json` - Personal overrides
- `.claude/state/*` - Runtime state
- `.claude/logs/*` - Debug logs

**Rationale:**
- Local-only configuration
- Ephemeral data
- Should be gitignored

**What happens:**
- Completely skipped during sync
- No backup, no copy, no comparison

## AI Assistant Checklist

**Before syncing:**
- [ ] ALWAYS dry-run first: `--dry-run`
- [ ] Review what will change
- [ ] Check if settings.json needs manual merge
- [ ] Verify target directory exists
- [ ] Ensure backup will be created

**After syncing:**
- [ ] Check `.claude/.backup/` exists
- [ ] Verify permissions on `.claude/hooks/*.sh`
- [ ] Review `.gitignore` compliance warnings
- [ ] Test automation in target project

**If problems occur:**
- [ ] Use rollback: `rollback ~/project`
- [ ] Check backup timestamp
- [ ] Review sync report output

## Command Options

### sync

```bash
# Basic usage
./.claude/scripts/sync-to-project.py sync <target>

# Options
--dry-run               # Preview changes without applying
--no-backup             # Skip backup (not recommended)
--force                 # Skip confirmation prompts
```

### list-backups

```bash
# Show all backups for project
./.claude/scripts/sync-to-project.py list-backups ~/my-project

# Output:
# Backups for /Users/you/my-project:
# 1. 2025-12-04_14-30-45 (2.3 MB)
# 2. 2025-12-03_10-15-20 (2.1 MB)
```

### rollback

```bash
# Rollback to most recent backup
./.claude/scripts/sync-to-project.py rollback ~/my-project

# Rollback to specific backup
./.claude/scripts/sync-to-project.py rollback ~/my-project --backup 2025-12-03_10-15-20
```

## Understanding Sync Output

### Dry-Run Output

```
🔍 DRY RUN - No changes will be made

📋 Sync Plan:
  ✅ Dependencies: jq, gh, bash (all found)
  📁 Target: /Users/you/my-project/.claude/
  💾 Backup: /Users/you/my-project/.claude/.backup/2025-12-04_14-30-45

📝 Files to sync (23 files):
  • commands/iterate-pr.md → NEW
  • hooks/pre-commit.sh → UPDATED
  • scripts/sync-to-project.py → UPDATED
  • settings.json → MERGE

🔧 Permissions to set:
  • hooks/pre-commit.sh → executable

⚠️  .gitignore compliance:
  • .claude/settings.local.json should be ignored but is tracked
  • Fix: git rm --cached .claude/settings.local.json
```

### Actual Sync Output

```
🚀 Syncing automation to /Users/you/my-project

✅ Backup created: .backup/2025-12-04_14-30-45
✅ Files synced: 23
✅ Settings merged: settings.json
✅ Permissions set: 5 files
⚠️  Gitignore compliance issues detected (see above)

🎉 Sync complete!
```

## Settings Merge Behavior

**How settings.json is merged:**

1. **Allowlist merging:** Template rules + project rules (combined)
2. **Denylist merging:** Template rules override project rules
3. **Other fields:** Project values preserved

**Example:**

```json
// Template settings.json
{
  "allowlist": ["Read", "Write"],
  "denylist": ["Bash(rm -rf)"]
}

// Project settings.json
{
  "allowlist": ["Glob"],
  "custom_field": "project-specific"
}

// After merge
{
  "allowlist": ["Read", "Write", "Glob"],  // Combined
  "denylist": ["Bash(rm -rf)"],             // From template
  "custom_field": "project-specific"        // Preserved
}
```

## Gitignore Compliance

**Sync tool checks if these files are ignored:**
- `.claude/settings.local.json`
- `.claude/state/*`
- `.claude/logs/*`
- `.claude/.backup/*`

**If not ignored:**

```
⚠️  .gitignore compliance issues:

.claude/settings.local.json is tracked but should be ignored
  Fix: git rm --cached .claude/settings.local.json

.claude/state/ files are tracked but should be ignored
  Fix: git rm --cached -r .claude/state/
```

**Run fix commands:**
```bash
cd ~/my-project
git rm --cached .claude/settings.local.json
git rm --cached -r .claude/state/
git commit -m "chore: fix gitignore compliance"
```

## Common Workflows

### Workflow 1: Sync to Multiple Projects

```bash
# Create list of projects
projects=(
  ~/projects/api-server
  ~/projects/web-app
  ~/projects/cli-tool
)

# Dry-run all
for proj in "${projects[@]}"; do
  echo "Checking $proj..."
  ./.claude/scripts/sync-to-project.py sync --dry-run "$proj"
done

# Review output, then sync all
for proj in "${projects[@]}"; do
  ./.claude/scripts/sync-to-project.py sync "$proj"
done
```

### Workflow 2: Test Before Wide Rollout

```bash
# 1. Sync to test project
./.claude/scripts/sync-to-project.py sync ~/test-project

# 2. Test thoroughly
cd ~/test-project
./.claude/commands/iterate-pr.md  # Test commands
./.claude/hooks/pre-commit.sh     # Test hooks

# 3. If good, rollout to other projects
# 4. If bad, rollback and fix template
./.claude/scripts/sync-to-project.py rollback ~/test-project
```

### Workflow 3: Update After Template Changes

```bash
# Template repo: made changes to commands/
cd ~/persuade
git pull origin main

# Sync to projects using updated template
./.claude/scripts/sync-to-project.py sync ~/project-1
./.claude/scripts/sync-to-project.py sync ~/project-2
```

## Gotchas

**"Target directory does not exist"**
- Create parent directory first
- Or provide absolute path

**"Permission denied on hooks"**
- Sync tool automatically sets executable
- Check if sync completed successfully

**"Settings merge overwrote my custom rules"**
- Check if you modified allowlist/denylist
- Use `settings.local.json` for overrides instead

**"Can't find backup to rollback"**
- Check `.claude/.backup/` directory
- List backups: `list-backups ~/project`

**"Gitignore warnings persist"**
- Must run `git rm --cached` commands manually
- Then commit changes

## Validation Checks

**Sync tool validates:**

1. **Dependencies:** jq, gh, bash installed
2. **Target exists:** Directory is valid
3. **Permissions:** Scripts are executable
4. **Gitignore:** Sensitive files ignored
5. **Settings merge:** Valid JSON structure

**If validation fails:**
- Sync aborts with clear error
- No partial changes applied
- No backup created

## Rollback Safety

**What rollback restores:**
- All `.claude/` files from backup
- File permissions
- Directory structure

**What rollback DOESN'T restore:**
- Files outside `.claude/` directory
- Git commits made after sync
- Changes to project code

**Backup retention:**
- Backups kept indefinitely in `.claude/.backup/`
- Manually delete old backups if needed
- Each backup is timestamped

## Related

- **PR Iteration:** [automation/pr-iteration.md](pr-iteration.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** ALWAYS dry-run first. Review output carefully. Backups enable safe rollback.
