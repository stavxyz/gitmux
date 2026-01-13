# Virtual Environments

## When to Use

**ALWAYS.** Before any Python development, running scripts, or installing packages.

## Quick Reference

```bash
# Create venv (one time)
python3 -m venv .venv

# Activate (every session)
source .venv/bin/activate  # macOS/Linux
.venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Verify active
which python  # Must show .venv/bin/python

# Deactivate when done
deactivate
```

## Why This Matters

- **System Protection:** Prevents corruption of system Python
- **Isolation:** No conflicts between projects
- **Reproducibility:** Everyone uses same package versions
- **PEP 668:** Required by modern Python (externally-managed-environment)

## Patterns

### Pattern 1: Fresh Project Setup

```bash
cd my-project
python3 -m venv .venv
source .venv/bin/activate
pip install click rich
pip freeze > requirements.txt
```

### Pattern 2: Existing Project

```bash
cd existing-project
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Pattern 3: Verify Venv Active

```bash
# Check which Python is active
which python
# Output must be: /path/to/project/.venv/bin/python

# Or check Python location
python -c "import sys; print(sys.prefix)"
# Output must contain .venv
```

## AI Assistant Checklist

**Before running `pip install`:**
- [ ] Run `which python`
- [ ] Verify output shows `.venv/bin/python`
- [ ] If not active: Create venv first
- [ ] Never use `--user` flag
- [ ] Never use `sudo pip`

**If no venv exists:**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Prohibited Commands

```bash
# ❌ NEVER run these
pip install <package>              # Modifies system Python
python3 -m pip install --user <package>  # User-level pollution
sudo pip install <package>         # System-wide corruption
```

## Gotchas

**"Command not found: python"**
- Use `python3` instead of `python`

**Activation doesn't work**
- Must use `source`, not execute: `source .venv/bin/activate`
- Not: `./venv/bin/activate`

**Terminal doesn't show (.venv)**
- Some shells don't show indicator
- Use `which python` to verify

**Requirements.txt missing**
- Create it: `pip freeze > requirements.txt`
- Or manually list dependencies

## .gitignore

**Always ignore venv directories:**

```gitignore
# Virtual environments
venv/
.venv/
env/
```

## Related

- **Type Hints:** [python/type-hints.md](type-hints.md)
- **Engineering Standards:** `.claude/docs/ENGINEERING_STANDARDS.md`
- **Critical Rules:** `.claude/docs/CLAUDE_CODE_RULES.md`

---

**Key Takeaway:** NEVER use system Python. ALWAYS create and activate .venv before any Python work.
