#!/usr/bin/env python3
"""List live scripts/**/*.gd by on-disk bytes (no body reads), largest first.

    python3 tools/list_oversize_scripts.py [--over-kb 5] [--under-kb 0]
10KB is the ship floor, 5KB the sweep target. Summary: _logs/oversize/summary.txt.
Old spellings: -OverKb -UnderKb -Glob (ignored).
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List oversize GDScript files by byte size.", json_out=True)
    ap.add_argument("--over-kb", "-OverKb", type=float, default=5)
    ap.add_argument("--under-kb", "-UnderKb", type=float, default=0)
    ap.add_argument("--glob", "-Glob", default="", help="Ignored (kept for the old .ps1 flags).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    lo = args.over_kb * 1000
    hi = args.under_kb * 1000 if args.under_kb > 0 else float("inf")
    rows = []
    for p in (root / "scripts").rglob("*.gd"):
        parts = p.relative_to(root).parts
        if "archives" in parts or ".archive_worktrees" in parts:
            continue
        n = p.stat().st_size
        if lo <= n < hi:
            rows.append((n, p.relative_to(root).as_posix()))
    rows.sort(key=lambda r: (-r[0], r[1]))
    under = f"{args.under_kb:g}" if args.under_kb > 0 else "none"
    body = ["root=.", f"overKb={args.over_kb:g} underKb={under} count={len(rows)}",
            "measure=on-disk bytes", "", "bytes\tkb\tpath"] + [f"{n}\t{n / 1000:.2f}\t{r}" for n, r in rows]
    echo = [f"Over {args.over_kb:g}KB: {len(rows)} files"] + [f"{n:6d}  {r}" for n, r in rows[:30]]
    if len(rows) > 30:
        echo.append(f"... +{len(rows) - 30} more (see summary)")
    return agent_log.finish("oversize", root, "\n".join(body), "INFO", args=args, echo="\n".join(echo), count=len(rows))


if __name__ == "__main__":
    raise SystemExit(main())
