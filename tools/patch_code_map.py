#!/usr/bin/env python3
"""Shim (one release): use `python tools/code_map.py patch` instead. Same flags and exit codes."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import code_map

if __name__ == "__main__":
    raise SystemExit(code_map.main(["patch", *sys.argv[1:]]))
