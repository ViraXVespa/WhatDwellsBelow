#!/usr/bin/env python3
"""Shim (one release): use `python3 tools/make_sfx.py --prefix p9_` instead. Same cues, byte-identical wavs."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_sfx

if __name__ == "__main__":
    raise SystemExit(make_sfx.main(["--prefix", "p9_"] + sys.argv[1:]))
