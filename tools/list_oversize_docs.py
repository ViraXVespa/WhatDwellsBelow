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
    ap = argparse.ArgumentParser(description="List design/*.md by os.path.getsize; OVER marks files at or over --over-kb.")
    ap.add_argument("--root", default=".")
    ap.add_argument("--over-kb", type=float, default=8.0, help="limit = round(kb * 1000) bytes (default 8)")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = Path(args.root).expanduser().resolve()
    limit = round(args.over_kb * 1000)
    files = sorted((f for f in (root / "design").glob("*.md")), key=lambda f: -f.stat().st_size)
    lines = [f"root=. over_kb={args.over_kb} limit_bytes={limit}", ""]
    over = 0
    for f in files:
        n = f.stat().st_size
        hit = n >= limit
        over += hit
        lines.append(f"{'OVER ' if hit else ''}{f.relative_to(root).as_posix()} bytes={n}")
    lines += ["", f"RESULT over={over} files={len(files)}"]
    body = "\n".join(lines) + "\n"
    out = agent_log.ensure_agent_log_dir("oversize-docs", root) / "summary.txt"
    out.write_text(body, encoding="utf-8")
    sys.stdout.write(body)
    print(f"summary={out.relative_to(root).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
