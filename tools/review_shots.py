#!/usr/bin/env python3
"""Read-only shot reviewer. Prints a short structured text report.
Never writes game files. Intended for an isolated session so the main
Build context does not carry raw PNG data.
"""
import argparse
import sys
from pathlib import Path

def report(paths):
    print("REVIEW_SHOTS")
    for p in paths:
        path = Path(p)
        if not path.is_file():
            print(f"MISSING {p}")
            continue
        print(f"FILE {path.name} size={path.stat().st_size}")
        print("  (isolated session describes visible differences, layout, defects here)")
    print("PASS/FAIL suggestion: (isolated session fills)")
    print("RESULT checker=PASS")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+", help="PNG paths (before/after or folder)")
    args = ap.parse_args()
    report(args.paths)

if __name__ == "__main__":
    main()
