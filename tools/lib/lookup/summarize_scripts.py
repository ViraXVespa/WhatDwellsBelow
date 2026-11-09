#!/usr/bin/env python3
"""Func-level script inventory for live .gd files. Agents read the summary, not bodies.

Usage (from repo root):
  python tools/find.py scripts
  python tools/find.py scripts --path scripts/combat/enemy.gd
  python tools/find.py scripts --top-funcs 8

  python tools/find.py scripts --names --path scripts/combat/enemy.gd
  python tools/find.py scripts --all-names --path scripts/combat/enemy.gd

--names prints function names only (no line ranges or byte sizes), still limited by --top-funcs.
--all-names prints every function name in source order and ignores --top-funcs.
Output: _logs/script-summary/<stamp>-script-summary.txt
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

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
    return gd_lib.live_gd(root)

def plain_names(text: str, top: int, all_names: bool) -> list[str]:
    """Function names only. all_names keeps source order; otherwise the largest `top` funcs."""
    fns = gd_lib.funcs_of(text)
    if all_names:
        return [name for name, _start, _end, _size in fns]
    ranked = sorted(fns, key=lambda item: item[3], reverse=True)
    return [name for name, _start, _end, _size in ranked[: max(0, top)]]

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Func-level script inventory for live .gd files.", json_out=True)
    ap.add_argument("--path", action="append", default=[], help="Limit to one or more .gd paths")
    ap.add_argument("--over-kb", type=float, default=0.0, help=argparse.SUPPRESS)
    ap.add_argument("--top-funcs", type=int, default=6, help="Largest funcs to list per file")
    ap.add_argument("--names", action="store_true", help="Print function names only, no line ranges or byte sizes. Limited by --top-funcs unless --all-names.")
    ap.add_argument("--all-names", action="store_true", help="Every function name in source order. Implies --names and ignores --top-funcs.")
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
        f"files={len(files)} top_funcs={args.top_funcs}",
        "",
    ]
    listed = 0
    for p in files:
        length = p.stat().st_size
        if over_bytes and length < over_bytes:
            continue
        rel = agent_log.rel(root, p)
        text = p.read_text(encoding="utf-8-sig")
        fns = gd_lib.funcs_of(text)
        if args.names or args.all_names:
            shown = plain_names(text, args.top_funcs, args.all_names)
            lines.append(f"{rel} funcs={len(fns)}")
            lines.append("  " + (", ".join(shown) if shown else "(none)"))
        else:
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
