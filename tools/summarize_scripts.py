#!/usr/bin/env python3
"""Func-level script inventory for live .gd files. Agents read the summary, not bodies.

Usage (from repo root):
  python tools/summarize_scripts.py
  python tools/summarize_scripts.py --path scripts/combat/enemy.gd
  python tools/summarize_scripts.py --over-kb 5 --top-funcs 8
  powershell -File tools/summarize_scripts.ps1

Output: _logs/script-summary/summary.txt
"""
from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import gd_lib


def select(root: Path, paths: list[Path] | None) -> list[Path]:
    if paths:
        out = []
        for p in paths:
            p = p if p.is_absolute() else (root / p)
            if p.is_file() and p.suffix == ".gd":
                out.append(p)
        return sorted(out)
    return gd_lib.iter_gd(root)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Func-level script inventory for live .gd files.", json_out=True)
    ap.add_argument("--path", "-Path", action="append", default=[], help="Limit to one or more .gd paths")
    ap.add_argument("--over-kb", "-OverKb", type=float, default=0.0, help="Only list files >= this many KB (0=all)")
    ap.add_argument("--top-funcs", "-TopFuncs", type=int, default=6, help="Largest funcs to list per file")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    args.path = agent_log.split_list(args.path)
    paths = [Path(p) for p in args.path] if args.path else None
    for p in args.path:
        if not (root / p).exists() and not Path(p).exists():
            agent_log.fail(f"--path {p}: no such file or folder (give repo-relative .gd paths or a scripts/ folder)")
    files = select(root, paths)
    over_bytes = int(args.over_kb * 1000) if args.over_kb > 0 else 0

    lines: list[str] = [
        f"script summary {datetime.now().astimezone().isoformat()}",
        "root=.",
        f"files={len(files)} over_kb={args.over_kb} top_funcs={args.top_funcs}",
        "",
    ]
    listed = 0
    for p in files:
        length = p.stat().st_size
        if over_bytes and length < over_bytes:
            continue
        rel = agent_log.rel(root, p)
        fns = gd_lib.funcs_of(p.read_text(encoding="utf-8-sig"))
        fns_sorted = sorted(fns, key=lambda t: t[3], reverse=True)
        top = fns_sorted[: max(0, args.top_funcs)]
        lines.append(f"{rel} bytes={length} funcs={len(fns)}")
        for name, start, end, b in top:
            lines.append(f"  {name} L{start}-{end} bytes={b}")
        lines.append("")
        listed += 1

    return agent_log.finish("script-summary", root, "\n".join(lines), "PASS", args=args, legacy=False,
                            echo=f"Listed {listed} scripts", listed=listed)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
