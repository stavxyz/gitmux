# Automatic Virtual Environment Activation

## Technical Implementation

Claude Code automatically detects and activates Python virtual environments using SessionStart hooks and persistent bash environment configuration.

## Architecture

### Components

1. **Detection Script:** `.claude/scripts/venv-detect.sh`
   - Runs at session start
   - Implements priority-based detection strategy
   - Writes activation to `$CLAUDE_ENV_FILE`

2. **Safety Validator:** `.claude/scripts/check-venv.sh`
   - Runs before pip operations (PreToolUse hook)
   - Blocks operations if no venv active
   - Configurable via `CLAUDE_VENV_SAFETY_HOOK`

3. **Statusline Integration:** `.claude/scripts/statusline.sh`
   - Displays active venv name and Python version
   - Updates in real-time as venv changes

4. **Hook Configuration:** `.claude/settings.json`
   - SessionStart: Runs detection script
   - PreToolUse: Validates venv before pip commands

## Detection Strategy

### Priority Order

```bash
1. Active venv ($VIRTUAL_ENV set)
   → Use existing, respect user's explicit activation

2. Named venv exists (~/.virtualenvs/<project-name>)
   → Use virtualenvwrapper-style centralized venv

3. Local venv exists (.venv in project root)
   → Use local venv as fallback

4. No venv found
   → Create new named venv in ~/.virtualenvs/<project-name>
```

### Implementation Details

**Project Name Derivation:**
```bash
PROJECT_NAME=$(basename "$CLAUDE_PROJECT_DIR")
# No sanitization - literal directory name
# "my-project" → "my-project"
# "project.old" → "project.old"
```

**Venv Paths:**
```bash
NAMED_VENV="$HOME/.virtualenvs/$PROJECT_NAME"
LOCAL_VENV="$CLAUDE_PROJECT_DIR/.venv"
```

**Validation:**
```bash
# Before using existing venv, validate structure
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    # Corrupted venv, recreate
    rm -rf "$VENV_PATH"
    python3 -m venv "$VENV_PATH"
fi
```

## Persistent Activation

### CLAUDE_ENV_FILE

Claude Code provides `$CLAUDE_ENV_FILE` for persistent bash environment:

```bash
# venv-detect.sh writes:
{
    echo "source \"$VENV_PATH/bin/activate\""
    echo "export VIRTUAL_ENV=\"$VENV_PATH\""
    echo "export VIRTUAL_ENV_PROMPT=\"($VENV_NAME)\""
} >> "$CLAUDE_ENV_FILE"
```

**Effect:** All subsequent bash commands in the session inherit the activated venv.

### Environment Variables Set

| Variable | Example Value | Purpose |
|----------|---------------|---------|
| `VIRTUAL_ENV` | `/home/user/.virtualenvs/my-project` | Venv path |
| `VIRTUAL_ENV_PROMPT` | `(my-project)` | Display name |
| `PATH` | `$VENV_PATH/bin:$PATH` | Modified by activate script |

## Metadata Tracking

### Project Path Storage

Each venv stores its associated project path:

```bash
# Stored in: ~/.virtualenvs/<project>/.ccc-project-path
echo "$CLAUDE_PROJECT_DIR" > "$VENV_PATH/.ccc-project-path"
```

**Uses:**
- Orphan detection (renamed directories)
- Future: Auto-migration, venv management commands

### Orphan Detection

**Scenario:** User renames directory from `old-project` to `new-project`

**Detection Logic:**
```bash
# Check all venvs in ~/.virtualenvs/
for venv_dir in "$VIRTUALENVS_DIR"/*/; do
    metadata_file="$venv_dir/.ccc-project-path"
    if [ -f "$metadata_file" ]; then
        stored_path=$(cat "$metadata_file")
        if [ "$stored_path" = "$CLAUDE_PROJECT_DIR" ]; then
            # This venv was created for current project
            # but has different name → orphan
            log_warn "Orphaned venv: $(basename $venv_dir)"
        fi
    fi
done
```

**User Experience:**
```
⚠️  Found orphaned virtual environment from renamed directory:
  Old venv: old-project
  Current project: new-project
  You may want to delete the old venv: rm -rf ~/.virtualenvs/old-project
```

## Safety Hook

### PreToolUse Hook

Configured in `.claude/settings.json`:

```json
"PreToolUse": [
  {
    "matcher": "Bash(pip install :*)|Bash(pip uninstall :*)|Bash(python -m pip install :*)|Bash(python -m pip uninstall :*)",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/scripts/check-venv.sh"
      }
    ]
  }
]
```

### Validation Logic

```bash
# check-venv.sh
if [ "${CLAUDE_VENV_SAFETY_HOOK:-true}" = "false" ]; then
    exit 0  # Disabled, allow
fi

if [ -n "${VIRTUAL_ENV:-}" ]; then
    exit 0  # Venv active, allow
fi

# No venv, block
exit 1
```

**Exit Codes:**
- `0`: Safe to proceed
- `1`: Block operation

### Bypass Mechanism

```bash
# In .envrc
export CLAUDE_VENV_SAFETY_HOOK=false
```

**Use Cases:**
- Intentional system Python usage
- Debugging
- Alternative package managers (conda, etc.)

## Statusline Integration

### Implementation

```bash
# .claude/scripts/statusline.sh
if [ -n "${VIRTUAL_ENV:-}" ]; then
    VENV_NAME=$(basename "$VIRTUAL_ENV")
    PYTHON_VERSION=$(${VIRTUAL_ENV}/bin/python --version 2>&1 | cut -d' ' -f2)
    STATUS="${STATUS} | 🐍 ${VENV_NAME} (${PYTHON_VERSION})"
fi
```

### Example Output

```
[Claude Sonnet] my-project | feature/auth | 🐍 my-project (3.11.6)
```

**Components:**
- Model name: `[Claude Sonnet]`
- Project: `my-project`
- Branch: `feature/auth`
- Venv: `🐍 my-project (3.11.6)`

## Python Version Handling

### Strategy: Assume Correct Resolution

Claude Code **does not** parse `.python-version` or manage Python versions.

**Rationale:**
- pyenv already handles `.python-version` globally
- Avoids duplicating pyenv's complex logic
- Simple, predictable behavior

**Implementation:**
```bash
# Always use python3 (whatever it resolves to)
python3 -m venv "$VENV_PATH"
```

**If .python-version exists:**
- User has likely configured pyenv
- `python3` resolves to correct version automatically
- No Claude Code intervention needed

### Future Enhancement

If version management is needed:

```bash
# Read .python-version
if [ -f .python-version ]; then
    VERSION=$(cat .python-version)
    MAJOR_MINOR="${VERSION%.*}"  # 3.11.6 → 3.11
    PYTHON_BIN="python${MAJOR_MINOR}"

    if command -v "$PYTHON_BIN" &>/dev/null; then
        $PYTHON_BIN -m venv "$VENV_PATH"
    else
        # Fallback to python3
        python3 -m venv "$VENV_PATH"
    fi
fi
```

## Integration Patterns

> **Note:** The following integrations describe expected behavior based on
> how these tools set environment variables. While direnv compatibility
> has been validated through `$VIRTUAL_ENV` detection, other tools (virtualenvwrapper,
> poetry, pipenv) follow the same pattern but haven't been explicitly tested.
> Please report any issues.

### direnv Compatibility (Validated)

**Scenario:** User has `.envrc` with `layout python python3`

**Behavior:**
1. direnv activates venv before Claude Code session starts
2. `$VIRTUAL_ENV` is set
3. venv-detect.sh sees existing activation (Priority 1)
4. Uses existing venv, doesn't create new one
5. No conflicts

### virtualenvwrapper Compatibility (Expected)

**Without virtualenvwrapper installed:**
- Claude creates venvs in `~/.virtualenvs/` by convention
- Activates directly: `source ~/.virtualenvs/<name>/bin/activate`
- No dependency on `workon` command

**With virtualenvwrapper installed:**
- User can use `workon` to activate manually
- Claude detects `$VIRTUAL_ENV` and respects it
- Both approaches work seamlessly

### poetry / pipenv (Expected)

**These tools manage their own venvs:**

```bash
# poetry creates: /path/to/.venv or ~/.cache/pypoetry/virtualenvs/<name>
poetry shell
# Sets VIRTUAL_ENV

# Claude detects it (Priority 1)
# Uses poetry's venv, doesn't create new one
```

## Error Handling

### Missing Python

```bash
if ! command -v python3 &>/dev/null; then
    log_error "python3 not found in PATH"
    exit 1
fi
```

**User sees:**
```
❌ python3 not found in PATH
Install Python 3 or ensure it's in your PATH
```

### Corrupted Venv

```bash
if [ ! -f "$VENV_PATH/bin/activate" ]; then
    log_warn "Venv corrupted, recreating..."
    rm -rf "$VENV_PATH"
    python3 -m venv "$VENV_PATH"
fi
```

**User sees:**
```
⚠️  Named venv exists but is corrupted (missing activate script)
🔍 Recreating virtual environment...
✅ Created virtual environment: ~/.virtualenvs/my-project
```

### Permission Denied

```bash
if ! python3 -m venv "$NAMED_VENV"; then
    log_error "Failed to create virtual environment"
    exit 1
fi
```

**Fallback:** None. Exits with error. User must fix permissions.

## Logging Philosophy

### Verbose by Default

**Rationale:** New feature needs high observability for:
- Debugging issues
- Understanding behavior
- Building user trust
- Collecting feedback

**Implementation:**
```bash
log_info() { echo "🔍 $*" >&2; }
log_success() { echo "✅ $*" >&2; }
log_warn() { echo "⚠️  $*" >&2; }
log_error() { echo "❌ $*" >&2; }
```

**All output to stderr** (visible to user, not captured as command output).

### Future: Dial Down

After 2 months of usage:

```bash
# Minimal mode (default)
✅ venv: my-project (3.11.6)

# Verbose mode (opt-in)
export CLAUDE_VENV_VERBOSE=true
# Shows full current output
```

## Testing Considerations

### CI Environment Challenges

**Problem:** GitHub Actions doesn't have user's `~/.virtualenvs/`

**Solution:** Tests should:
- Mock `$CLAUDE_PROJECT_DIR`
- Mock `$CLAUDE_ENV_FILE` to temp file
- Create temp `~/.virtualenvs/` for testing
- Clean up after tests

**Example Test:**
```bash
# test_venv_detection.sh
export CLAUDE_PROJECT_DIR="/tmp/test-project"
export CLAUDE_ENV_FILE="/tmp/test-env"
mkdir -p ~/.virtualenvs

bash .claude/scripts/venv-detect.sh

# Verify venv created
test -d ~/.virtualenvs/test-project
# Verify activation written
grep "source.*test-project.*activate" /tmp/test-env
```

### Edge Cases to Test

1. **No venv exists** → Creates named venv
2. **Named venv exists** → Uses it
3. **Local .venv exists** → Uses it (lower priority than named)
4. **Both exist** → Prefers named
5. **VIRTUAL_ENV set** → Uses existing
6. **Corrupted venv** → Recreates
7. **Renamed directory** → Detects orphan, creates new
8. **Permission denied** → Fails gracefully
9. **No python3** → Clear error message
10. **direnv active** → Respects existing activation

## Performance

### SessionStart Impact

**Overhead (approximate):** ~100-200ms per session start on a typical local development machine (based on informal measurements; actual values will vary by system and project size).

**Breakdown (approximate):**
- Venv existence checks: ~10ms
- Creating new venv: ~1-2s (only first time)
- Writing activation: ~5ms
- Orphan detection: ~50ms (if `~/.virtualenvs/` has many dirs)

**Acceptable:** SessionStart runs once, acceptable latency for most development workflows.

### Statusline Impact

**Overhead (approximate, cumulative for the typical path):** ~35-45ms per update on a typical local development setup (based on informal measurements; actual values will vary by system and configuration).

**Breakdown (approximate, cumulative):**
- Check `VIRTUAL_ENV`: ~0ms (effectively instant/negligible)
- Run `python --version`: ~30-40ms (only when not cached)
- Format and output statusline: ~5ms

**Acceptable:** Statusline updates infrequently and may be faster when the Python version is cached (skipping `python --version`).

### Optimization Opportunities

**Cache Python version:**
```bash
# Write to CLAUDE_ENV_FILE
echo "export CLAUDE_VENV_PYTHON_VERSION='3.11.6'" >> "$CLAUDE_ENV_FILE"

# Statusline reads cached version
PYTHON_VERSION="${CLAUDE_VENV_PYTHON_VERSION:-$(python --version)}"
```

## Future Enhancements

### Auto-Install Requirements

```bash
# If CLAUDE_VENV_REQUIREMENTS set and venv newly created
if [ "$VENV_CREATED" = true ] && [ -n "$CLAUDE_VENV_REQUIREMENTS" ]; then
    IFS=':' read -ra REQ_FILES <<< "$CLAUDE_VENV_REQUIREMENTS"
    for req_file in "${REQ_FILES[@]}"; do
        pip install -r "$CLAUDE_PROJECT_DIR/$req_file"
    done
fi
```

**Configuration:**
```bash
# .envrc
export CLAUDE_VENV_REQUIREMENTS="requirements.txt"
# or multiple
export CLAUDE_VENV_REQUIREMENTS="requirements/dev.txt:requirements/test.txt"
```

### Auto-Rename Venvs

```bash
# Detect renamed directory, offer to rename venv
if orphan detected:
    prompt: "Rename venv from 'old-name' to 'new-name'? (y/n)"
    if yes:
        mv ~/.virtualenvs/old-name ~/.virtualenvs/new-name
```

### Extract to `ccc` CLI

```bash
# ccc venv commands
ccc venv init       # Create/detect venv
ccc venv status     # Show active venv
ccc venv activate   # Output activation command
ccc venv rename     # Rename venv
ccc venv delete     # Delete venv
ccc venv list       # List all venvs

# Hooks call ccc commands
bash -c "ccc venv init"
```

## Related Files

- **User Guide:** `.claude/docs/VIRTUAL_ENVIRONMENT_SETUP.md`
- **Implementation:** `.claude/scripts/venv-detect.sh`
- **Safety Check:** `.claude/scripts/check-venv.sh`
- **Statusline:** `.claude/scripts/statusline.sh`
- **Configuration:** `.claude/settings.json`

---

**Key Takeaway:** Automatic venv detection uses hooks, persistent environment, and convention over configuration to provide seamless Python isolation without user intervention.
