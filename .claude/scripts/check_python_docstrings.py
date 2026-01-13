#!/usr/bin/env python3
"""
Simple wrapper script for the docstring checker.

This script delegates to the persuade package's check-docstrings command.
All logic lives in persuade.docstring_checker module.
"""

import sys
from pathlib import Path

# Try to use the persuade CLI
try:
    from persuade.docstring_checker import check_files

    # Convert command line args to Path objects
    filepaths = [Path(arg) for arg in sys.argv[1:]]
    sys.exit(check_files(filepaths))

except ImportError:
    print(
        "Error: persuade package not installed. Install with: pip install -e .",
        file=sys.stderr,
    )
    sys.exit(2)
