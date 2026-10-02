#!/usr/bin/env python3
"""List a facade and its same-folder sibling helpers (<stem>.gd, <stem>_*.gd) by byte size.

    python3 tools/list_facade_cluster.py --facade scripts/combat/enemy.gd
Summary: _logs/facade-cluster/summary.txt. Old spelling: -Facade.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List a facade + sibling helpers by size (no body reads).", json_out=True)
    ap.add_argument("facade_pos", nargs="?", default="", help="Facade .gd path (same as --facade).")
    ap.add_argument("--facade", "-Facade", default="")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    facade = args.facade or args.facade_pos
    if not facade:
        agent_log.fail("pass --facade scripts/<dir>/<stem>.gd")
    full = Path(facade)
    full = (full if full.is_absolute() else root / full)
    if not full.is_file():
        agent_log.fail(f"missing facade: {facade}")
    full = full.resolve()
    stem = full.stem
    sibs = sorted((p for p in full.parent.glob("*.gd") if p.stem == stem or p.stem.startswith(stem + "_")),
                  key=lambda p: -p.stat().st_size)
    total = sum(p.stat().st_size for p in sibs)
    body = [f"root=. facade={agent_log.rel(root, full)}", f"stem={stem} dir={agent_log.rel(root, full.parent)}",
            f"siblings={len(sibs)}", ""] + [f"{agent_log.rel(root, p)} bytes={p.stat().st_size}" for p in sibs]
    return agent_log.finish("facade-cluster", root, "\n".join(body), "INFO", args=args, siblings=len(sibs), total_bytes=total)


if __name__ == "__main__":
    raise SystemExit(main())
