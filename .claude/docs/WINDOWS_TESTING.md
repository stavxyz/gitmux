# Windows Testing Status

## Current Status

**Windows Support**: Partial
**Windows Testing**: Manual/Untested in CI

## Quick Start for Windows Users

**Want to use editable mode on Windows?** Follow these steps:

### 1. Enable Developer Mode (Required)

Editable mode uses symlinks, which require Developer Mode on Windows:

1. Press `Win + I` to open Windows Settings
2. Navigate to: **Settings → Privacy & Security → For Developers**
   - On older Windows 10: **Settings → Update & Security → For Developers**
3. Toggle **Developer Mode** to ON
4. Restart your terminal (PowerShell/CMD)

**Why?** Windows restricts symlink creation without Developer Mode for security reasons.

### 2. Verify Your Setup

Test symlink creation works:

```powershell
# Create test files
mkdir test_symlink
echo "test" > test_symlink\source.txt
mklink test_symlink\link.txt test_symlink\source.txt

# If successful, you'll see: "symbolic link created"
# Clean up
rm -r test_symlink
```

### 3. Run the Sync Tool with Editable Mode

```powershell
# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Sync with editable mode enabled
python .claude\scripts\sync-to-project.py path\to\target\project -e
```

### 4. Common Issues

**Error: "Insufficient permissions to create symlink"**
- ✅ **Solution**: Enable Developer Mode (see step 1)
- ✅ **Verify**: Restart terminal after enabling

**Error: "Cannot create symlink across different drives"**
- ✅ **Solution**: Tool automatically falls back to absolute symlinks
- ℹ️ **Note**: This is expected behavior on Windows

**Symlinks not working in Git Bash**
- ✅ **Solution**: Use PowerShell or CMD instead
- ℹ️ **Why**: Git Bash may not respect Windows Developer Mode

### 5. Testing (Optional)

Run the test suite to verify everything works:

```powershell
# Unit tests (should pass without Developer Mode)
pytest tests\unit\claude\scripts\test_sync_engine_file_ops.py -v

# Integration tests (requires Developer Mode)
pytest tests\integration\test_editable_workflow.py -v
```

---

## Symlink Support on Windows

### Requirements

Windows symlink support requires **Developer Mode** to be enabled:

1. Open Windows Settings
2. Navigate to: Settings → Update & Security → For Developers
3. Enable "Developer Mode"

**Documentation**: https://learn.microsoft.com/windows/dev-environment

### Implementation Details

The `create_symlink_with_fallback()` function in `symlink_ops.py` handles Windows-specific requirements:

```python
# On Windows, directory symlinks need target_is_directory=True
is_dir = source.is_dir()
os.symlink(symlink_target, target, target_is_directory=is_dir)
```

**Critical Parameter**: `target_is_directory=True` is required for directory symlinks on Windows.

### Error Handling

When Developer Mode is not enabled, users receive a clear error message:

```python
raise PermissionError(
    f"Insufficient permissions to create symlink. "
    f"On Windows, enable Developer Mode in Settings. "
    f"See: https://learn.microsoft.com/windows/dev-environment. Error: {e}"
)
```

## Testing Approach

### Unit Tests

All unit tests in `tests/unit/claude/scripts/test_sync_engine_file_ops.py` are **platform-agnostic**:

- ✅ **44 unit tests** covering symlink operations, marker management, validation
- ✅ Tests use `tmp_path` fixtures (works on all platforms)
- ✅ Tests mock `os.symlink()` for permission error scenarios
- ✅ Tests verify `target_is_directory` parameter is passed correctly

**Run on Windows:**
```powershell
pytest tests/unit/claude/scripts/test_sync_engine_file_ops.py -v
```

### Integration Tests

Integration tests in `tests/integration/test_editable_workflow.py` test full sync workflows:

- ✅ **5 integration tests** (3 passing, 2 xfailed)
- ✅ Tests use real symlink creation (requires Developer Mode on Windows)
- ⚠️ **Not tested on Windows in CI** - requires Developer Mode setup

**Run on Windows (requires Developer Mode):**
```powershell
pytest tests/integration/test_editable_workflow.py -v
```

### Manual Testing

**Windows-specific manual test checklist:**

1. ✅ Symlink creation with Developer Mode enabled
2. ✅ Error message when Developer Mode disabled
3. ✅ Relative symlinks vs absolute symlinks
4. ✅ Directory symlinks (`target_is_directory=True`)
5. ⚠️ Cross-drive symlinks (C: → D:)
6. ⚠️ UNC path handling (`\\server\share`)
7. ⚠️ Long path support (>260 characters)

## CI/CD Considerations

### Why Windows is not in CI Matrix

**Reasons:**
1. **Developer Mode Requirement**: Windows symlinks require Developer Mode, which may not be enabled in all CI environments
2. **CI Environment Variability**: Different CI providers (GitHub Actions, GitLab CI, Azure Pipelines) have different Windows configurations
3. **Maintenance Burden**: Adding Windows to CI matrix increases build time and complexity
4. **Manual Testing Coverage**: Current manual testing on Windows validates core functionality

### Adding Windows to CI (Future)

To add Windows to the CI matrix, the following would be required:

#### GitHub Actions Example

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        python-version: ['3.10', '3.11', '3.12']
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      # Windows: Enable Developer Mode for symlinks
      - name: Enable Developer Mode (Windows)
        if: runner.os == 'Windows'
        run: |
          # Set registry key to enable Developer Mode
          # WARNING: Requires admin privileges
          reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"
        shell: pwsh

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/ -v
```

**Challenges:**
- Registry modification requires admin privileges
- Not all CI runners allow registry modification
- Alternative: Skip symlink tests on Windows in CI (mark with `@pytest.mark.skipif(sys.platform == 'win32')`)

### Alternative: Skip Windows-Specific Features

```python
import sys
import pytest

@pytest.mark.skipif(sys.platform == 'win32', reason="Symlinks require Developer Mode on Windows")
def test_symlink_creation(tmp_path):
    # Test code here
    pass
```

**Trade-off**: Reduces test coverage on Windows but allows CI to run on Windows without special setup.

## Known Limitations on Windows

1. **Relative Symlinks Across Drives**:
   - Cannot create relative symlinks from C: to D:
   - Fallback to absolute symlinks automatically
   - Logged as warning: `cannot_create_relative_symlink`

2. **UNC Path Handling**:
   - Symlinks to UNC paths (`\\server\share`) may fail
   - Not tested in current test suite

3. **Long Path Support**:
   - Windows has 260-character path limit (unless long path support enabled)
   - Deep directory structures may fail
   - Recommendation: Enable long path support in Windows Registry

4. **Junction Points vs Symlinks**:
   - Windows supports both junction points and symlinks for directories
   - Current implementation uses `os.symlink()` (creates symlinks, not junctions)
   - Symlinks require Developer Mode; junctions do not
   - Future: Consider using junctions for directories as fallback

### Junction Points vs Symlinks: Detailed Tradeoff Analysis

Windows provides two distinct mechanisms for creating directory links:

#### Symlinks (Current Implementation)

**Advantages:**
- **Cross-platform compatibility**: Same API (`os.symlink()`) works on Linux, macOS, and Windows
- **File and directory support**: Can link both files and directories
- **Relative and absolute paths**: Supports both relative and absolute targets
- **POSIX-compliant**: Behaves consistently with Unix symlinks
- **Portable code**: Single code path for all platforms

**Disadvantages:**
- **Requires Developer Mode**: On Windows 10/11, requires Developer Mode to be enabled
- **Permission barrier**: End-users may not want to enable Developer Mode
- **Security concerns**: Developer Mode reduces security restrictions system-wide
- **Setup friction**: Additional configuration step before using editable mode

#### Junction Points (Alternative for Directories)

**Advantages:**
- **No special permissions required**: Works without Developer Mode
- **Widely supported**: Available since Windows 2000
- **Reliable**: Well-tested and stable on Windows
- **No user configuration**: End-users can use immediately
- **Better for directories**: Optimized for directory links specifically

**Disadvantages:**
- **Windows-only**: Not available on Linux/macOS (platform-specific code required)
- **Directory-only**: Cannot link files (would need symlinks for files anyway)
- **Absolute paths only**: Junctions always use absolute paths (less portable across moves)
- **Complexity**: Requires platform detection and dual code paths
- **No relative links**: Cannot create relative junctions (symlinks can)

#### Implementation Comparison

**Current (Symlinks Only):**
```python
# Single code path for all platforms
os.symlink(source, target, target_is_directory=is_dir)
```

**Hybrid Approach (Junctions + Symlinks):**
```python
import sys
import _winapi  # Windows-specific module

if sys.platform == 'win32' and source.is_dir():
    # Use junction for directories on Windows (no permissions needed)
    _winapi.CreateJunction(str(source), str(target))
else:
    # Use symlink for files or on non-Windows platforms
    os.symlink(source, target, target_is_directory=is_dir)
```

**Trade-offs of Hybrid Approach:**
- ✅ Better Windows experience (no Developer Mode needed)
- ❌ More complex code (platform-specific logic)
- ❌ Mixed link types (some absolute, some relative)
- ❌ Harder to test (Windows-specific behavior)

#### Recommendation

**Current Decision: Symlinks Only**

**Rationale:**
1. **Simplicity**: Single code path, easier to maintain and test
2. **Portability**: Identical behavior across Linux, macOS, Windows
3. **Consistency**: All links use same mechanism (relative symlinks preferred)
4. **Developer Target**: Editable mode is for developers who can enable Developer Mode
5. **Normal Mode**: Users who can't enable Developer Mode can use normal sync mode (copies)

**When to Reconsider:**
- If many Windows users report Developer Mode as a blocker
- If GitHub Actions/CI officially supports junctions without Developer Mode
- If Python's `os` module adds cross-platform junction support

**Alternative for End Users:**
- Use **shadow mode** instead of editable mode on Windows (copies files, no symlinks needed)
- Use **normal mode** and manually sync when template updates
- Enable **Developer Mode** (recommended for developers)

#### Detailed Comparison Table

| Aspect | Symlinks (Current) | Junctions (Alternative) |
|--------|-------------------|-------------------------|
| **Permissions** | Requires Developer Mode | No special permissions |
| **Platform Support** | Linux, macOS, Windows | Windows only |
| **Link Type** | Files + Directories | Directories only |
| **Path Type** | Relative or Absolute | Absolute only |
| **Code Complexity** | Low (cross-platform) | Medium (platform-specific) |
| **Portability** | High (repo moves work) | Low (absolute paths break) |
| **User Friction** | Medium (setup needed) | Low (works immediately) |
| **Test Coverage** | High (CI on Linux/macOS) | Low (Windows manual only) |
| **Maintenance** | Low (single code path) | Medium (dual code paths) |

**Conclusion**: Symlinks provide better **long-term maintainability** and **cross-platform consistency**, while junctions would provide better **immediate Windows UX**. For a developer-focused tool like editable mode, the symlink approach is the right trade-off.

## Recommendations

### For End Users (Windows)

1. **Enable Developer Mode** before using editable mode
2. **Verify symlink support** with test command:
   ```powershell
   python -c "import os; from pathlib import Path; p = Path('test_link'); p.symlink_to('.'); print('Symlinks work!'); p.unlink()"
   ```
3. **Use normal mode** if Developer Mode cannot be enabled (symlinks not supported)

### For Developers (Testing on Windows)

1. **Manual Testing Required**: Test symlink functionality on Windows before releases
2. **Document Windows Behavior**: Note any Windows-specific quirks in PR descriptions
3. **Error Message Validation**: Verify error messages are clear when symlinks fail

### For CI/CD (Future Enhancement)

1. **Option A: Add Windows to CI Matrix**
   - Requires registry modification or admin setup
   - Full test coverage on Windows
   - Increased build time and complexity

2. **Option B: Skip Symlink Tests on Windows**
   - Use `@pytest.mark.skipif(sys.platform == 'win32')`
   - Reduced test coverage but simpler CI setup
   - Rely on manual testing for Windows validation

3. **Option C: Use Mock Symlinks in CI**
   - Mock `os.symlink()` on Windows in CI
   - Tests logic but not actual symlink behavior
   - Cheapest option but least coverage

**Recommendation**: **Option B** (skip symlink tests on Windows in CI) + periodic manual testing.

**Decision Made**: For this project, we are **NOT adding Windows to the CI matrix** at this time due to:
1. **Complexity**: Windows symlinks require Developer Mode (registry modification in CI)
2. **Coverage**: All logic is tested on Linux/macOS; Windows-specific code is minimal (`target_is_directory` parameter)
3. **Maintenance**: Adding Windows increases CI time and complexity without proportional benefit
4. **Manual Testing**: Windows functionality can be validated manually before releases

**Future Consideration**: If Windows adoption increases significantly, revisit adding Windows to CI with skip markers for symlink-specific tests.

## Testing Checklist

Before marking Windows support as "Fully Tested":

- [ ] Add Windows to CI matrix (GitHub Actions, GitLab CI, etc.)
- [ ] Verify Developer Mode setup in CI
- [ ] Run full test suite on Windows in CI
- [ ] Test cross-drive symlink fallback (C: → D:)
- [ ] Test UNC path handling (`\\server\share`)
- [ ] Test long path support (>260 characters)
- [ ] Document any Windows-specific issues in troubleshooting guide
- [ ] Add Windows badge to README (if CI includes Windows)

## Current Status Summary

| Feature | Linux/macOS | Windows |
|---------|-------------|---------|
| Symlink Creation | ✅ Tested | ⚠️ Manual Only |
| Relative Symlinks | ✅ Tested | ⚠️ Manual Only |
| Directory Symlinks | ✅ Tested | ⚠️ Manual Only |
| Error Handling | ✅ Tested | ✅ Tested (mocked) |
| Integration Tests | ✅ Tested | ⚠️ Manual Only |
| CI Coverage | ✅ Yes | ❌ No |

**Legend:**
- ✅ Fully tested and working
- ⚠️ Manually tested, not in CI
- ❌ Not tested or not supported

## Related Documentation

- **Symlink Handling**: `.claude/scripts/sync_engine/symlink_ops.py`
- **Editable Mode**: `.claude/scripts/sync_engine/marker_ops.py`
- **Integration Tests**: `tests/integration/test_editable_workflow.py`
- **Windows Developer Mode**: https://learn.microsoft.com/windows/dev-environment
