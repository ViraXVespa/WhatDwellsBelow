#!/usr/bin/env python3
"""Shim (one release): use `python3 tools/tunables.py set` instead. Same flags and exit codes."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tunables

if __name__ == "__main__":
    raise SystemExit(tunables.main(["set", *sys.argv[1:]]))
