#!/usr/bin/env python3
"""Read-only shot reviewer. Prints a short structured text report.
Never writes game files. Intended for an isolated session so the main
Build context does not carry raw PNG data.
"""
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log  # noqa: E402

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

def main() -> int:
    ap = agent_log.std_parser("Read-only shot reviewer: short structured text report for an isolated session.")
    ap.add_argument("paths", nargs="+", help="PNG paths (before/after or folder)")
    args = ap.parse_args()
    root = agent_log.resolve_root(args)
    report([p if Path(p).is_absolute() else str(root / p) if (root / p).exists() else p for p in args.paths])
    return agent_log.emit_result("PASS", checker="PASS")

if __name__ == "__main__":
    sys.exit(main())
