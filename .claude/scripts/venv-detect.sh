#!/bin/bash
# Claude Code Python Virtual Environment Detection and Activation
# Implements automatic venv detection with "use or make" behavior
#
# Detection Strategy (priority order):
#   1. Already activated ($VIRTUAL_ENV set) → Use existing
#   2. Named venv exists (~/.virtualenvs/<project-name>) → Use named
#   3. Local venv exists (.venv) → Use local
#   4. Neither exists → Create named venv
#
# Outputs:
#   - Writes activation commands to $CLAUDE_ENV_FILE
#   - Logs verbose status to stderr for user visibility
#   - Stores project path metadata for orphan detection
#
# Exit codes:
#   0 - Success (venv detected or created)
#   1 - Critical error (no Python, permissions, etc.)

# Check that we're running in bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash" >&2
    exit 1
fi

set -euo pipefail

# Configuration
VIRTUALENVS_DIR="${HOME}/.virtualenvs"
VENV_CREATED=false
VENV_ACTIVATED=false
CLAUDE_VENV_QUIET="${CLAUDE_VENV_QUIET:-false}"

# Handle --status flag for debugging
if [ "${1:-}" = "--status" ]; then
    echo "Virtual Environment Status"
    echo "=========================="
    echo ""
    echo "Environment Variables:"
    echo "  VIRTUAL_ENV: ${VIRTUAL_ENV:-<not set>}"
    echo "  CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-<not set>}"
    echo "  CLAUDE_ENV_FILE: ${CLAUDE_ENV_FILE:-<not set>}"
    echo "  CLAUDE_VENV_QUIET: ${CLAUDE_VENV_QUIET:-false}"
    echo "  CLAUDE_VENV_SAFETY_HOOK: ${CLAUDE_VENV_SAFETY_HOOK:-true}"
    echo ""

    if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
        PROJECT_NAME=$(basename "$CLAUDE_PROJECT_DIR")
        echo "Project:"
        echo "  Name: $PROJECT_NAME"
        echo "  Directory: $CLAUDE_PROJECT_DIR"
        echo ""

        echo "Virtual Environment Paths:"
        NAMED_VENV="$VIRTUALENVS_DIR/$PROJECT_NAME"
        LOCAL_VENV="$CLAUDE_PROJECT_DIR/.venv"

        if [ -d "$NAMED_VENV" ]; then
            echo "  Named venv (~/.virtualenvs/$PROJECT_NAME): ✓ exists"
            if [ -f "$NAMED_VENV/.ccc-project-path" ]; then
                STORED_PATH=$(cat "$NAMED_VENV/.ccc-project-path")
                echo "    Stored project path: $STORED_PATH"
                if [ "$STORED_PATH" != "$CLAUDE_PROJECT_DIR" ]; then
                    echo "    ⚠️  Orphan: stored path doesn't match current directory"
                fi
            fi
        else
            echo "  Named venv (~/.virtualenvs/$PROJECT_NAME): ✗ not found"
        fi

        if [ -d "$LOCAL_VENV" ]; then
            echo "  Local venv (.venv): ✓ exists"
        else
            echo "  Local venv (.venv): ✗ not found"
        fi
    fi

    echo ""
    echo "Python:"
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo "  Version: $PYTHON_VERSION"
        echo "  Path: $(which python3)"
    else
        echo "  ✗ python3 not found in PATH"
    fi

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        echo ""
        echo "Active Virtual Environment:"
        echo "  Path: $VIRTUAL_ENV"
        if [ -x "$VIRTUAL_ENV/bin/python" ]; then
            VENV_PYTHON_VERSION=$("$VIRTUAL_ENV/bin/python" --version 2>&1 | cut -d' ' -f2)
            echo "  Python: $VENV_PYTHON_VERSION"
        fi
    fi

    exit 0
fi

# Logging functions
log_info() {
    if [ "$CLAUDE_VENV_QUIET" != "true" ]; then
        echo "🔍 $*" >&2
    fi
}

log_success() {
    if [ "$CLAUDE_VENV_QUIET" != "true" ]; then
        echo "✅ $*" >&2
    fi
}

log_warn() {
    echo "⚠️  $*" >&2
}

log_error() {
    echo "❌ $*" >&2
}

# Validate required environment variables
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
    log_error "CLAUDE_PROJECT_DIR not set - this script must be run from Claude Code SessionStart hook"
    exit 1
fi

if [ -z "${CLAUDE_ENV_FILE:-}" ]; then
    log_error "CLAUDE_ENV_FILE not set - cannot persist venv activation"
    exit 1
fi

# Verify CLAUDE_ENV_FILE is writable (create parent directory if needed)
ENV_DIR=$(dirname "$CLAUDE_ENV_FILE")
if [ ! -d "$ENV_DIR" ]; then
    if ! mkdir -p "$ENV_DIR" 2>/dev/null; then
        log_error "Cannot create directory for CLAUDE_ENV_FILE: $ENV_DIR"
        log_error "Check filesystem permissions"
        exit 1
    fi
fi

if ! touch "$CLAUDE_ENV_FILE" 2>/dev/null; then
    log_error "CLAUDE_ENV_FILE is not writable: $CLAUDE_ENV_FILE"
    log_error "Check file permissions"
    exit 1
fi

# Validate Python is available
if ! command -v python3 &>/dev/null; then
    log_error "python3 not found in PATH"
    log_error "Install Python 3 or ensure it's in your PATH"
    exit 1
fi

# Get Python version
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
log_info "Python version: $PYTHON_VERSION"

# Derive project name from directory (literal, no sanitization)
PROJECT_NAME=$(basename "$CLAUDE_PROJECT_DIR")

# Validate project name is non-empty and not root
if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" = "/" ]; then
    log_error "Invalid project name derived from: $CLAUDE_PROJECT_DIR"
    exit 1
fi

# Warn if project name contains characters that may be unsafe in shell contexts
if [[ "$PROJECT_NAME" =~ [[:space:]\"\'\\$\`] ]]; then
    log_warn "Project directory name '$PROJECT_NAME' contains spaces or shell-special characters."
    log_warn "This may cause issues in some shell operations. Consider renaming the project directory."
fi

log_info "Project: $PROJECT_NAME"

# Define venv paths
NAMED_VENV="$VIRTUALENVS_DIR/$PROJECT_NAME"
LOCAL_VENV="$CLAUDE_PROJECT_DIR/.venv"

# Check if .python-version exists
if [ -f "$CLAUDE_PROJECT_DIR/.python-version" ]; then
    PYTHON_VERSION_FILE=$(cat "$CLAUDE_PROJECT_DIR/.python-version")
    log_info "Detected .python-version: $PYTHON_VERSION_FILE"
    log_info "Assuming python3 resolves correctly (via pyenv or system)"
fi

# --- Detection Logic ---

# Priority 1: Check if venv already activated
if [ -n "${VIRTUAL_ENV:-}" ]; then
    log_success "Virtual environment already active: $VIRTUAL_ENV"
    VENV_PATH="$VIRTUAL_ENV"
    VENV_NAME=$(basename "$VIRTUAL_ENV")

    # Verify it's still valid
    if [ ! -f "$VENV_PATH/bin/activate" ]; then
        log_warn "Active venv path is invalid (missing activate script)"
        log_warn "Will attempt to find or create valid venv"
        unset VIRTUAL_ENV
    else
        VENV_ACTIVATED=true
    fi
fi

# Priority 2: Check for named venv if not already activated
if [ "$VENV_ACTIVATED" = false ] && [ -d "$NAMED_VENV" ]; then
    log_success "Found named virtual environment: $NAMED_VENV"
    VENV_PATH="$NAMED_VENV"
    VENV_NAME="$PROJECT_NAME"

    # Validate venv structure
    if [ ! -f "$VENV_PATH/bin/activate" ]; then
        log_warn "Named venv exists but is corrupted (missing activate script)"
        log_info "Recreating virtual environment..."
        rm -rf "$VENV_PATH"
        if ! python3 -m venv "$VENV_PATH" 2>&1; then
            log_error "Failed to recreate virtual environment at $VENV_PATH"
            log_error "Debug steps:"
            log_error "  1. Check Python: python3 -m venv --help"
            log_error "  2. Check permissions: ls -ld $VIRTUALENVS_DIR"
            log_error "  3. Check disk space: df -h $VIRTUALENVS_DIR"
            exit 1
        fi
        VENV_CREATED=true
    fi

    VENV_ACTIVATED=true
fi

# Priority 3: Check for local .venv if not already activated
if [ "$VENV_ACTIVATED" = false ] && [ -d "$LOCAL_VENV" ]; then
    log_success "Found local virtual environment: $LOCAL_VENV"
    VENV_PATH="$LOCAL_VENV"
    VENV_NAME=".venv"

    # Validate venv structure
    if [ ! -f "$VENV_PATH/bin/activate" ]; then
        log_warn "Local venv exists but is corrupted (missing activate script)"
        log_info "Recreating virtual environment..."
        rm -rf "$VENV_PATH"
        if ! python3 -m venv "$VENV_PATH" 2>&1; then
            log_error "Failed to recreate virtual environment at $VENV_PATH"
            log_error "Debug steps:"
            log_error "  1. Check Python: python3 -m venv --help"
            log_error "  2. Check permissions: ls -ld $(dirname "$VENV_PATH")"
            log_error "  3. Check disk space: df -h $(dirname "$VENV_PATH")"
            exit 1
        fi
        VENV_CREATED=true
    fi

    VENV_ACTIVATED=true
fi

# Priority 4: Create new named venv
if [ "$VENV_ACTIVATED" = false ]; then
    log_info "No virtual environment found"
    log_info "Creating named virtual environment: $NAMED_VENV"

    # Create virtualenvs directory if it doesn't exist
    if [ ! -d "$VIRTUALENVS_DIR" ]; then
        log_info "Creating virtualenvs directory: $VIRTUALENVS_DIR"
        mkdir -p "$VIRTUALENVS_DIR"
    fi

    # Create venv
    if python3 -m venv "$NAMED_VENV"; then
        log_success "Created virtual environment: $NAMED_VENV"
        VENV_PATH="$NAMED_VENV"
        VENV_NAME="$PROJECT_NAME"
        VENV_CREATED=true
        VENV_ACTIVATED=true
    else
        log_error "Failed to create virtual environment"
        exit 1
    fi
fi

# --- Store Project Path Metadata ---

# Store project path for orphan detection
METADATA_FILE="$VENV_PATH/.ccc-project-path"
if [ ! -f "$METADATA_FILE" ]; then
    echo "$CLAUDE_PROJECT_DIR" > "$METADATA_FILE"
    log_info "Stored project path metadata"
else
    # Verify stored path matches current path
    STORED_PATH=$(cat "$METADATA_FILE")
    if [ "$STORED_PATH" != "$CLAUDE_PROJECT_DIR" ]; then
        log_warn "Project path mismatch detected!"
        log_warn "  Stored path: $STORED_PATH"
        log_warn "  Current path: $CLAUDE_PROJECT_DIR"
        log_warn "  This may indicate a renamed or moved directory"
        log_warn "  Updating metadata to current path..."
        echo "$CLAUDE_PROJECT_DIR" > "$METADATA_FILE"
    fi
fi

# --- Check for Orphaned Venvs ---

# Only check if we're using a newly created or existing named venv
if [ "$VENV_PATH" != "${VIRTUAL_ENV:-}" ] && [ -d "$VIRTUALENVS_DIR" ]; then
    log_info "Checking for orphaned virtual environments..."

    ORPHANS_FOUND=false
    # Enable nullglob to handle empty directories gracefully
    shopt -s nullglob
    for venv_dir in "$VIRTUALENVS_DIR"/*/; do
        # Skip if not a directory or is a symlink
        [ -d "$venv_dir" ] || continue
        [ -L "$venv_dir" ] && continue

        venv_dir_name=$(basename "$venv_dir")
        metadata_file="$venv_dir/.ccc-project-path"

        # Skip current venv
        if [ "$venv_dir_name" = "$PROJECT_NAME" ]; then
            continue
        fi

        # Check if venv has metadata
        if [ -f "$metadata_file" ]; then
            stored_project_path=$(cat "$metadata_file")

            # Check if stored path matches current project
            if [ "$stored_project_path" = "$CLAUDE_PROJECT_DIR" ]; then
                if [ "$ORPHANS_FOUND" = false ]; then
                    log_warn "Found orphaned virtual environment from renamed directory:"
                    ORPHANS_FOUND=true
                fi
                log_warn "  Old venv: $venv_dir_name"
                log_warn "  Current project: $PROJECT_NAME"
                log_warn "  You may want to delete the old venv: rm -rf $venv_dir"
            fi
        fi
    done
    shopt -u nullglob

    if [ "$ORPHANS_FOUND" = false ]; then
        log_info "No orphaned virtual environments detected"
    fi
fi

# --- Write Activation to CLAUDE_ENV_FILE ---

log_info "Writing activation to persistent environment..."

# Write activation commands
{
    echo "# Python virtual environment activation (auto-detected by Claude Code)"
    echo "source \"$VENV_PATH/bin/activate\""
    echo "export VIRTUAL_ENV=\"$VENV_PATH\""
    echo "export VIRTUAL_ENV_PROMPT=\"($VENV_NAME)\""
} >> "$CLAUDE_ENV_FILE"

# Get actual Python version from venv
if [ -x "$VENV_PATH/bin/python" ]; then
    if VENV_PYTHON_VERSION_OUTPUT=$("$VENV_PATH/bin/python" --version 2>&1); then
        VENV_PYTHON_VERSION=$(printf '%s\n' "$VENV_PYTHON_VERSION_OUTPUT" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
        # Validate version format (e.g., 3.11.5 or 3.11)
        if [[ ! "$VENV_PYTHON_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            log_warn "Unexpected Python version format: $VENV_PYTHON_VERSION"
            VENV_PYTHON_VERSION="unknown"
        fi
    else
        log_warn "Failed to determine Python version for virtual environment at $VENV_PATH"
        VENV_PYTHON_VERSION="unknown"
    fi
else
    log_warn "Python executable not found in virtual environment at $VENV_PATH"
    VENV_PYTHON_VERSION="unknown"
fi

# --- Final Status Report ---

echo "" >&2
log_success "=== Virtual Environment Ready ==="
log_success "  Name: $VENV_NAME"
log_success "  Path: $VENV_PATH"
log_success "  Python: $VENV_PYTHON_VERSION"
if [ "$VENV_CREATED" = true ]; then
    log_success "  Status: Newly created"
else
    log_success "  Status: Existing (reused)"
fi
echo "" >&2

# Suggest next steps if venv was newly created
if [ "$VENV_CREATED" = true ]; then
    log_info "Next steps:"
    if [ -f "$CLAUDE_PROJECT_DIR/requirements.txt" ]; then
        log_info "  • Install dependencies: pip install -r requirements.txt"
    else
        log_info "  • Install packages: pip install <package-name>"
        log_info "  • Create requirements.txt: pip freeze > requirements.txt"
    fi
fi

exit 0
