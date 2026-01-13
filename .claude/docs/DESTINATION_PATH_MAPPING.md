# Destination Path Mapping

The sync engine supports **destination path mapping**, which allows files to be synced to arbitrary locations relative to the project root, not just within `.claude/`.

## Overview

By default, files in `.claude/` are synced to the same relative path in the target project's `.claude/` directory. Destination path mapping allows you to override this behavior and sync files to anywhere in the project.

## Use Cases

### 1. Git Hooks (Primary Use Case)

Git hooks must live in `.git/hooks/` to function, but `.git/` is not tracked in version control. We track hooks in `.claude/git-hooks/` and sync them to `.git/hooks/`:

```python
".claude/git-hooks/*": {
    "category": FileCategory.SYNC_ALWAYS,
    "destination": ".git/hooks/{filename}",
    "exclude": ["*.md", "README*"],
}
```

**Result:**
- `.claude/git-hooks/pre-push` → `.git/hooks/pre-push` ✅
- `.claude/git-hooks/README.md` → `.claude/git-hooks/README.md` ✅ (excluded from mapping)

### 2. Editor Configuration

Sync VS Code settings:

```python
".claude/config/vscode-settings.json": {
    "category": FileCategory.SYNC_ALWAYS,
    "destination": ".vscode/settings.json",
}
```

### 3. GitHub Templates

Sync PR templates:

```python
".claude/templates/pull_request_template.md": {
    "category": FileCategory.SYNC_ALWAYS,
    "destination": ".github/pull_request_template.md",
}
```

### 4. CI Configuration

Sync GitHub Actions workflows (note: `.github/workflows/*.yml` is actually configured at root level):

```python
".github/workflows/test.yml": {
    "category": FileCategory.COPY_IF_MISSING,
    "destination": ".github/workflows/test.yml",
}
```

## Configuration Schema

### Simple Rule (Backwards Compatible)

```python
".claude/commands/*.md": FileCategory.SYNC_ALWAYS
```

Files sync to `.claude/commands/*.md` in target project (default behavior).

### Dict Rule with Destination

```python
".claude/source/pattern/*": {
    "category": FileCategory.SYNC_ALWAYS,
    "destination": "custom/destination/{filename}",
    "exclude": ["pattern1", "pattern2"],  # Optional
}
```

**Fields:**
- `category` (required): `FileCategory` enum value
- `destination` (optional): Path relative to project root
  - Can include `{filename}` placeholder for glob patterns
- `exclude` (optional): List of filename patterns to exclude from this rule

## Template Variables

### `{filename}`

Used with glob patterns to preserve the filename:

```python
".claude/git-hooks/*": {
    "destination": ".git/hooks/{filename}",
}
```

**Resolves to:**
- `.claude/git-hooks/pre-push` → `.git/hooks/pre-push`
- `.claude/git-hooks/pre-commit` → `.git/hooks/pre-commit`

Without `{filename}`, the destination would be literal:
```python
".claude/git-hooks/*": {
    "destination": ".git/hooks/pre-push",  # ❌ All hooks → same file
}
```

## Exclude Patterns

Exclude specific files from a pattern-based destination mapping:

```python
".claude/git-hooks/*": {
    "category": FileCategory.SYNC_ALWAYS,
    "destination": ".git/hooks/{filename}",
    "exclude": ["*.md", "README*"],  # Don't sync docs to .git/hooks/
}
```

**Behavior:**
- `.claude/git-hooks/pre-push` → matches pattern, not excluded → `.git/hooks/pre-push`
- `.claude/git-hooks/README.md` → matches pattern, but excluded → falls through to next rule or default

Excluded files fall through to other rules or default behavior (synced to `.claude/`).

## Security Features

### Path Validation

All destination paths are validated to prevent security issues:

1. **Path Traversal Prevention**: Paths containing `..` or escaping the project root are rejected
2. **Resolution Check**: Paths are resolved and verified to be within the project
3. **Explicit Rejection**: Suspicious patterns trigger `ValueError` with clear messages

**Example:**
```python
"evil/*": {
    "destination": "../../etc/passwd",  # ❌ ValueError: escapes project root
}
```

### Permission Preservation

File permissions are preserved during sync, including:
- Executable bits (critical for git hooks and scripts)
- Metadata (timestamps, etc.)

The `copy_file_with_permissions()` function ensures:
```python
# Preserve executable bit
if source.stat().st_mode & 0o111:
    target.chmod(current_mode | 0o111)
```

## Implementation Details

### File Scanning

`scan_source_directory()` returns `FileInfo` objects:

```python
@dataclass
class FileInfo:
    category: FileCategory
    destination: Optional[str] = None
```

### Change Computation

`compute_changes()` uses destination paths to check for existing files:

```python
if file_info.destination:
    target_file = target_path / file_info.destination
else:
    target_file = target_path / ".claude" / rel_path
```

### File Copying

`apply_file_changes()` validates and copies to destination:

```python
if file_info.destination:
    validate_destination_path(file_info.destination, target_path)
    target_file = target_path / file_info.destination
else:
    target_file = target_claude / rel_path
```

## Backwards Compatibility

Destination path mapping is **fully backwards compatible**:

1. Existing rules without destination work unchanged
2. Files sync to `.claude/` by default
3. No breaking changes to existing configurations
4. Opt-in feature via explicit configuration

## Testing

Comprehensive tests in:
- `tests/test_destination_mapping.py` - Unit tests for core functionality
- `tests/test_integration_git_hooks.py` - End-to-end integration tests

Run tests:
```bash
python .claude/scripts/tests/test_destination_mapping.py
python .claude/scripts/tests/test_integration_git_hooks.py
```

## Future Enhancements

Potential improvements (not currently implemented):

1. **More template variables**: `{project_name}`, `{branch}`, etc.
2. **Conditional destinations**: Different paths based on project type
3. **Directory-level mappings**: Map entire directories with pattern preservation
4. **Post-sync hooks**: Run commands after syncing specific files

## Related Documentation

- `.claude/git-hooks/README.md` - Git hooks documentation
- `.claude/scripts/sync_engine/constants.py` - Configuration file
- `.claude/scripts/sync_engine/file_ops.py` - Implementation
