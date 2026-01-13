#!/usr/bin/env python3
"""Wrapper script for documentation validation.

This script invokes the persuade.docs.validate module as a command-line tool.
All command-line arguments are forwarded to the module.
"""

import subprocess
import sys


def main(argv: list[str] | None = None) -> int:
    """Invoke persuade.docs.validate module as a script.

    Args:
        argv: Command-line arguments to forward. If None, uses sys.argv[1:].

    Returns:
        Exit code from the validate module.
    """
    if argv is None:
        argv = sys.argv[1:]

    cmd = [sys.executable, "-m", "persuade.docs.validate", *argv]
    completed = subprocess.run(cmd)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
