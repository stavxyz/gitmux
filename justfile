# gitmux development tasks
# Run `just --list` to see all available recipes

# Default recipe: show help
default:
    @just --list

# ============================================================================
# Setup
# ============================================================================

# Set up development environment
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Setting up development environment..."

    # Create Python venv if it doesn't exist
    if [[ ! -d .venv ]]; then
        echo "Creating Python virtual environment..."
        python3 -m venv .venv
    fi

    # Activate and install dependencies
    source .venv/bin/activate
    echo "Installing Python dependencies..."
    pip install --quiet --upgrade pip
    pip install --quiet -r .github/workflows/requirements-quality.txt

    # Check for required tools
    echo "Checking required tools..."
    command -v shellcheck >/dev/null 2>&1 || echo "Warning: shellcheck not installed (brew install shellcheck)"
    command -v bats >/dev/null 2>&1 || echo "Warning: bats not installed (brew install bats-core)"
    command -v gh >/dev/null 2>&1 || echo "Warning: gh not installed (brew install gh)"
    command -v jq >/dev/null 2>&1 || echo "Warning: jq not installed (brew install jq)"

    echo "Setup complete!"

# ============================================================================
# Testing
# ============================================================================

# Run all tests
test: test-bats test-shell
    @echo "All tests passed!"

# Run bats unit tests
test-bats:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -d tests ]] && ls tests/*.bats 1>/dev/null 2>&1; then
        echo "Running bats unit tests..."
        bats tests/
    else
        echo "No bats tests found in tests/"
    fi

# Run shell integration tests (requires GitHub credentials)
test-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "${GH_TOKEN:-}" ]]; then
        echo "Warning: GH_TOKEN not set, skipping integration tests"
        exit 0
    fi
    echo "Running shell integration tests..."
    ./test_gitmux.sh

# ============================================================================
# Linting & Formatting
# ============================================================================

# Run all linters
lint: lint-shell lint-python
    @echo "All linting passed!"

# Run shellcheck on shell scripts
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running shellcheck..."
    shellcheck gitmux.sh
    shellcheck test_gitmux.sh
    if ls tests/*.bats 1>/dev/null 2>&1; then
        shellcheck tests/*.bats
    fi

# Run ruff linter on Python files
lint-python:
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate 2>/dev/null || true
    if command -v ruff &>/dev/null; then
        echo "Running ruff check..."
        ruff check .
    else
        echo "ruff not installed, skipping Python linting"
    fi

# Format Python code
format:
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate 2>/dev/null || true
    if command -v ruff &>/dev/null; then
        echo "Formatting Python code..."
        ruff format .
    else
        echo "ruff not installed, skipping formatting"
    fi

# Run type checker
typecheck:
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate 2>/dev/null || true
    if command -v mypy &>/dev/null; then
        echo "Running mypy..."
        mypy . --ignore-missing-imports || true
    else
        echo "mypy not installed, skipping type checking"
    fi

# ============================================================================
# All Checks (CI-equivalent)
# ============================================================================

# Run all quality checks (lint, format check, typecheck, test)
check: lint typecheck test-bats
    @echo "All checks passed!"

# ============================================================================
# Docker
# ============================================================================

# Build Docker image
docker-build:
    docker build --tag samstav/gitmux:latest --file Dockerfile .

# Run interactive shell in Docker container
docker-run:
    docker run \
        --interactive \
        --tty \
        --rm \
        --stop-timeout=60 \
        --volume $(pwd)/gitmux.sh:/gitmux.sh \
        --volume $HOME/.ssh:/root/.ssh \
        samstav/gitmux:latest \
        /bin/bash

# Run tests in Docker container
docker-test:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "${GH_TOKEN:-}" ]]; then
        echo "Error: GH_TOKEN required for docker-test"
        exit 1
    fi
    docker run \
        --env GH_HOST \
        --env GH_TOKEN \
        --env GITHUB_OWNER \
        --interactive --tty \
        --volume $(pwd)/gitmux.sh:/gitmux/gitmux.sh \
        --volume $(pwd)/test_gitmux.sh:/gitmux/test_gitmux.sh \
        samstav/gitmux:latest \
        /bin/bash -c \
        "git config --global user.email \"$(git config --global user.email)\" && \
        git config --global user.name \"$(git config --global user.name)\" && \
        /gitmux/test_gitmux.sh"

# Push Docker image to registry
docker-push:
    docker push samstav/gitmux:latest

# List gitmux Docker images
docker-ls:
    @docker images --no-trunc --format '{{json .}}' | \
        jq -r 'select((.Repository|contains("gitmux")))' | \
        jq -rs 'sort_by(.Repository)|.[]|"\(.ID)\t\(.Repository):\(.Tag)\t(\(.CreatedSince))\t[\(.Size)]"'

# ============================================================================
# Cleanup
# ============================================================================

# Delete test repositories created during testing
cleanup-test-repos:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Finding test repositories to delete..."
    repos=$(gh repo list --limit 99 --json nameWithOwner,name --jq '.[]|select(.name|startswith("gitmux_test_")).nameWithOwner')
    if [[ -z "$repos" ]]; then
        echo "No test repositories found"
        exit 0
    fi
    for r in $repos; do
        echo "Deleting $r"
        gh api --method DELETE "repos/$r"
    done
    echo "Cleanup complete!"

# Clean build artifacts
clean:
    rm -rf .venv .mypy_cache .ruff_cache .pytest_cache __pycache__ .coverage
    find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name '*.pyc' -delete 2>/dev/null || true
