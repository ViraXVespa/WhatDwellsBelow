#!/usr/bin/env python3
"""List design/*.md (not changelog/) by byte size, largest first. Read-only; Python twin of list_oversize_docs.ps1."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List design/*.md by os.path.getsize; OVER marks files at or over --over-kb.", json_out=True)
    ap.add_argument("--over-kb", "-OverKb", type=float, default=8.0, help="limit = round(kb * 1000) bytes (default 8)")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    limit = round(args.over_kb * 1000)
    files = sorted((f for f in (root / "design").glob("*.md")), key=lambda f: -f.stat().st_size)
    lines = [f"root=. over_kb={args.over_kb} limit_bytes={limit}", ""]
    over = 0
    for f in files:
        n = f.stat().st_size
        hit = n >= limit
        over += hit
        lines.append(f"{'OVER ' if hit else ''}{f.relative_to(root).as_posix()} bytes={n}")
    return agent_log.finish("oversize-docs", root, "\n".join(lines), "INFO", args=args, legacy=False, over=over, files=len(files))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
