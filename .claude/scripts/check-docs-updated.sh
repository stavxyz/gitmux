#!/usr/bin/env bash

# Documentation Update Checker
# Verifies that code changes include corresponding documentation updates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
warnings=0
suggestions=0

echo -e "${BLUE}=== Documentation Update Checker ===${NC}\n"

# Get the comparison base (default to main branch)
BASE_BRANCH="${1:-main}"

echo "Comparing against: ${BASE_BRANCH}"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Validate that the base branch exists
if ! git rev-parse "${BASE_BRANCH}" &>/dev/null; then
    echo -e "${RED}Error: Base branch '${BASE_BRANCH}' not found${NC}"
    echo "Available branches:"
    git branch -a | head -10
    exit 1
fi

# Get list of changed files
echo -e "${BLUE}Analyzing changed files...${NC}\n"

# Get changed files (both staged and unstaged)
# More robust version that handles detached HEAD state and various CI scenarios
CHANGED_FILES=$(git diff --name-only "${BASE_BRANCH}...HEAD" 2>/dev/null || \
                git diff --name-only --cached 2>/dev/null || \
                git diff --name-only 2>/dev/null || \
                echo "")

if [ -z "$CHANGED_FILES" ]; then
    echo -e "${YELLOW}No changed files detected.${NC}"
    echo "This might mean:"
    echo "  - You're on the main branch (use a feature branch)"
    echo "  - No files have been modified yet"
    echo "  - All changes have been committed and pushed"
    exit 0
fi

echo "Changed files:"
if [ -n "$CHANGED_FILES" ]; then
    echo "$CHANGED_FILES" | while IFS= read -r file; do
        echo "  - $file"
    done
fi
echo ""

# Categorize changed files
# Supported languages: Python, JavaScript/TypeScript, Go, Java, Ruby, PHP, Rust
# Add more as needed (e.g., .c, .cpp, .h for C/C++, .cs for C#, .kt for Kotlin)
CODE_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(py|js|ts|tsx|jsx|go|java|rb|php|rs)$' || true)
TEST_FILES=$(echo "$CODE_FILES" | grep -E 'test|spec|_test\.' || true)
SRC_FILES=$(echo "$CODE_FILES" | grep -v -E 'test|spec|_test\.' || true)
DOC_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(md|rst|txt)$|^docs/' || true)
API_DOCS_CHANGED=$(echo "$CHANGED_FILES" | grep -E '^docs/api\.' || true)

# Analysis
echo -e "${BLUE}Analysis Results:${NC}\n"

if [ -n "$SRC_FILES" ]; then
    echo -e "${YELLOW}⚠ Source code files changed:${NC}"
    echo "$SRC_FILES" | while IFS= read -r file; do
        echo "  - $file"
    done
    echo ""

    # Check if documentation was also updated
    if [ -z "$DOC_FILES" ]; then
        echo -e "${RED}❌ WARNING: Source code changed but no documentation files updated${NC}"
        echo ""
        echo "Consider updating:"
        echo "  - README.md (if user-facing changes)"
        echo "  - docs/api.md (if API/endpoints changed)"
        echo "  - docs/architecture.md (if design patterns changed)"
        echo "  - Docstrings in modified functions"
        echo "  - Code comments for complex logic"
        echo ""
        ((warnings++))
    else
        echo -e "${GREEN}✓ Documentation files also changed:${NC}"
        echo "$DOC_FILES" | while IFS= read -r file; do
            echo "  - $file"
        done
        echo ""
    fi

    # Check for specific scenarios
    if echo "$SRC_FILES" | grep -qE 'api|endpoint|route'; then
        if [ -z "$API_DOCS_CHANGED" ]; then
            echo -e "${YELLOW}💡 SUGGESTION: API-related files changed${NC}"
            echo "   Consider updating docs/api.md"
            echo ""
            ((suggestions++))
        fi
    fi

    # Check for Python files (should have docstrings)
    PYTHON_FILES=$(echo "$SRC_FILES" | grep '\.py$' || true)
    if [ -n "$PYTHON_FILES" ]; then
        echo -e "${BLUE}Checking Python files for docstrings...${NC}"

        # Get the directory where this script lives
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        PYTHON_CHECKER="${SCRIPT_DIR}/check_python_docstrings.py"

        # Try to use Python AST-based checker if available
        if [ -x "$PYTHON_CHECKER" ] && command -v python3 &> /dev/null; then
            # Use the accurate Python AST-based checker
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    # Run the Python checker and capture output
                    if ! python3 "$PYTHON_CHECKER" "$file" 2>/dev/null; then
                        echo -e "${YELLOW}⚠ Warning: ${file} has missing docstrings${NC}"
                        echo "   Add Google-style docstrings to all public functions/classes"
                        echo "   See: .claude/docs/ENGINEERING_STANDARDS.md#documentation-requirements"
                        ((warnings++))
                    fi
                fi
            done <<< "$PYTHON_FILES"
        else
            # Fallback to regex-based checking
            echo -e "${YELLOW}ℹ Using fallback regex check (install Python 3 for accurate detection)${NC}"
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    # Check for function/class definitions (including indented ones)
                    # This improved pattern catches:
                    #   - Regular functions: def foo()
                    #   - Async functions: async def foo()
                    #   - Classes: class Foo
                    #   - Indented definitions (methods inside classes)
                    # Note: Still won't catch decorated functions where decorator comes first.
                    # For perfect detection, use Python AST parsing (see check_python_docstrings.py).
                    if grep -qE '^\s*(def |class |async def )' "$file"; then
                        if ! grep -qE '"""' "$file"; then
                            echo -e "${YELLOW}⚠ Warning: ${file} may be missing docstrings${NC}"
                            ((warnings++))
                        fi
                    fi
                fi
            done <<< "$PYTHON_FILES"
        fi
        echo ""
    fi
fi

# Check if only tests changed
if [ -n "$TEST_FILES" ] && [ -z "$SRC_FILES" ]; then
    echo -e "${GREEN}✓ Only test files changed - minimal documentation needed${NC}"
    echo ""
fi

# Check if only docs changed
if [ -n "$DOC_FILES" ] && [ -z "$CODE_FILES" ]; then
    echo -e "${GREEN}✓ Documentation-only changes${NC}"
    echo "  Remember to use 'docs:' prefix in commit message"
    echo ""
fi

# Summary
echo -e "${BLUE}=== Summary ===${NC}\n"

if [ $warnings -eq 0 ] && [ $suggestions -eq 0 ]; then
    echo -e "${GREEN}✓ No documentation issues detected${NC}"
    echo ""
    echo "Remember to:"
    echo "  - Add docstrings to all new/modified functions"
    echo "  - Update README if user-facing changes"
    echo "  - Update API docs if endpoints changed"
    echo "  - Complete PR documentation checklist"
    echo ""
    exit 0
else
    echo -e "${YELLOW}Found ${warnings} warning(s) and ${suggestions} suggestion(s)${NC}"
    echo ""
    echo "This is a reminder, not a blocker. Please:"
    echo "  1. Review the warnings/suggestions above"
    echo "  2. Update documentation if needed"
    echo "  3. Complete the PR template documentation checklist"
    echo ""
    echo "If documentation is truly not needed, explain why in the PR."
    echo ""

    # Exit with 0 (success) for informational mode - see DOCUMENTATION_AUTOMATION.md for blocking mode
    exit 0
fi
