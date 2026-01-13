# Python Virtual Environment Auto-Activation

## Overview

Claude Code automatically detects and activates Python virtual environments for your projects. This ensures you never accidentally corrupt your system Python and provides a seamless development experience.

## How It Works

### Automatic Detection

When you start a Claude Code session, the system automatically:

1. **Checks for existing activation** - Respects venvs activated via direnv or manual activation
2. **Looks for named venv** - Searches `~/.virtualenvs/<project-name>` (virtualenvwrapper-style)
3. **Falls back to local venv** - Uses `.venv` if it exists in your project
4. **Creates new venv** - Creates `~/.virtualenvs/<project-name>` if nothing found

### What You See

**Session Start:**
```
🔍 Checking for virtual environment...
✅ Virtual environment ready: my-project (Python 3.11.6)
```

**Statusline:**
```
[Claude Sonnet] my-project | feature/auth | 🐍 my-project (3.11.6)
```

**Safety Protection:**
```
❌ ERROR: No Python virtual environment active

To protect your system Python, pip operations require an active virtual environment.
```

## Virtual Environment Location

### Preferred: Named Environments

By default, venvs are created in `~/.virtualenvs/<project-name>/`:

```bash
~/.virtualenvs/
├── my-project/           # Created automatically
├── another-project/      # Created automatically
└── old-project/          # Old venv (will warn if orphaned)
```

**Benefits:**
- Centralized management (all venvs in one place)
- Compatible with virtualenvwrapper workflow
- Easy to clean up (`rm -rf ~/.virtualenvs/<project>`)
- Survives project directory renames (with orphan detection)

### Fallback: Local Environments

If `.venv` exists in your project, Claude Code will use it:

```bash
my-project/
├── .venv/               # Will be used if it exists
├── src/
└── tests/
```

**When to use:**
- You prefer local venvs (`.venv` in project directory)
- Project-specific Python version management
- Compatibility with other tools expecting `.venv`

## Configuration

### Environment Variables

Configure behavior via `.envrc` or environment:

```bash
# Disable safety hook (not recommended)
export CLAUDE_VENV_SAFETY_HOOK=false

# Auto-install requirements on venv creation (future feature)
# export CLAUDE_VENV_REQUIREMENTS="requirements.txt"
```

### Python Version Selection

Create `.python-version` in your project root:

```bash
# .python-version
3.11.6
```

**Note:** This assumes `python3` resolves correctly (via pyenv, system, etc.). Claude Code doesn't manage Python versions - it uses whatever `python3` resolves to.

## Common Scenarios

### New Project

```bash
cd ~/code/my-new-project
# Start Claude Code session
# → Automatically creates ~/.virtualenvs/my-new-project/
# → Activates it for all bash commands
# → Shown in statusline
```

### Existing Project with .venv

```bash
cd ~/code/existing-project
# Has .venv/ directory
# Start Claude Code session
# → Detects .venv/, activates it
# → Shown in statusline
```

### Using direnv

```bash
cd ~/code/direnv-project
# .envrc contains: layout python python3
# Start Claude Code session
# → Detects VIRTUAL_ENV already set
# → Uses existing activation
# → No conflicts
```

### Renamed Directory

```bash
mv ~/code/old-name ~/code/new-name
cd ~/code/new-name
# Start Claude Code session
# → Detects venv mismatch
# → Warns about orphaned venv
# → Creates new venv for new name
# → Suggests cleanup: rm -rf ~/.virtualenvs/old-name
```

## Safety Features

### Pre-Command Validation

All `pip install` and `pip uninstall` commands are validated before execution:

```bash
# ✅ Safe (venv active)
pip install requests

# ❌ Blocked (no venv active)
pip install requests
→ ERROR: No Python virtual environment active
```

**Disable safety check:**
```bash
# In .envrc
export CLAUDE_VENV_SAFETY_HOOK=false
```

### Orphan Detection

Claude Code tracks which venv belongs to which project:

```bash
# If you rename a directory:
mv ~/code/project-old ~/code/project-new

# Claude will warn:
⚠️  Found orphaned virtual environment from renamed directory:
  Old venv: project-old
  Current project: project-new
  You may want to delete the old venv: rm -rf ~/.virtualenvs/project-old
```

## Manual Operations

### Activate Venv Manually

```bash
# Named venv
source ~/.virtualenvs/my-project/bin/activate

# Local venv
source .venv/bin/activate
```

### Check Active Venv

```bash
which python
# Expected: ~/.virtualenvs/my-project/bin/python
# or: /path/to/project/.venv/bin/python

echo $VIRTUAL_ENV
# Expected: /home/user/.virtualenvs/my-project
```

### Delete Venv

```bash
# Delete named venv
rm -rf ~/.virtualenvs/my-project

# Delete local venv
rm -rf .venv

# Claude will recreate it on next session start
```

### Install Dependencies

```bash
# Automatically uses active venv
pip install -r requirements.txt

# Or install individual packages
pip install requests pandas
```

## Troubleshooting

### "No such file or directory: ~/.virtualenvs/"

**Solution:** Directory is created automatically on first use. If you see this error, ensure `CLAUDE_ENV_FILE` is set correctly.

### "python3: command not found"

**Solution:** Install Python 3 or ensure it's in your PATH:
```bash
which python3
# Should show path to python3 binary
```

### "Virtual environment corrupted"

**Symptoms:** Missing `activate` script, broken symlinks

**Solution:** Delete and recreate:
```bash
rm -rf ~/.virtualenvs/my-project
# Restart Claude Code session
# → Will recreate automatically
```

### Safety hook blocking legitimate use

**Scenario:** You intentionally want to use system Python

**Solution:** Disable safety hook:
```bash
# In .envrc
export CLAUDE_VENV_SAFETY_HOOK=false
```

### Venv not showing in statusline

**Possible causes:**
- Venv not activated (check `echo $VIRTUAL_ENV`)
- Statusline script error (check `.claude/scripts/statusline.sh`)

**Debug:**
```bash
bash .claude/scripts/statusline.sh
# Should show venv info if active
```

## Integration with Other Tools

### virtualenvwrapper

Claude Code is **compatible** with virtualenvwrapper but **doesn't require** it:

```bash
# If you use virtualenvwrapper:
workon my-project
# Claude will detect VIRTUAL_ENV and use it

# If you don't use virtualenvwrapper:
# Claude creates venvs in ~/.virtualenvs/ anyway
# Activates them directly via: source ~/.virtualenvs/<name>/bin/activate
```

### direnv

Fully compatible. Claude Code respects `VIRTUAL_ENV` set by direnv:

```bash
# .envrc
layout python python3

# Claude Code will detect this and use it
# No conflicts
```

### pyenv

Compatible. If you use `.python-version`, ensure `python3` resolves correctly:

```bash
# .python-version
3.11.6

# Ensure pyenv shims are in PATH
which python3
# Expected: ~/.pyenv/shims/python3
```

### poetry / pipenv

Not directly integrated. These tools manage their own venvs:

```bash
# poetry
poetry shell
# Sets VIRTUAL_ENV, Claude detects it

# pipenv
pipenv shell
# Sets VIRTUAL_ENV, Claude detects it
```

## Best Practices

### ✅ Do

- Let Claude Code manage venv activation automatically
- Use `.python-version` for version consistency
- Keep requirements.txt updated: `pip freeze > requirements.txt`
- Delete orphaned venvs when notified
- Use `.envrc` for project-specific environment variables

### ❌ Don't

- Manually create venvs in Claude Code sessions (unless needed)
- Disable safety hook without good reason
- Install packages outside venv (blocked by default)
- Ignore orphan warnings (wastes disk space)

## Related Documentation

- **Knowledge Base:** `.claude/knowledge/python/automatic-venv-activation.md` (technical details)
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`
- **Virtual Env Basics:** `.claude/knowledge/python/virtual-environments.md`

---

**Summary:** Claude Code automatically handles Python virtual environments so you can focus on coding. Named venvs in `~/.virtualenvs/` are preferred, with fallback to local `.venv` and automatic creation if needed. Safety hooks prevent system Python corruption.
