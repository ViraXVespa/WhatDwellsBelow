#!/usr/bin/env python3
"""List a facade and its cluster helpers by byte size: the facade `<dir>/<stem>.gd` plus every `<dir>/<stem>/*.gd`
(cluster folder layout, design/refactor.md). Also lists legacy loose `<stem>_*.gd` beside the facade if any remain.
A helper path inside a cluster folder resolves to its facade. Facade-less families (no `<stem>.gd`): pass the cluster folder itself (lists its *.gd).

    python3 tools/list_facade_cluster.py --facade scripts/combat/enemy.gd
Summary: _logs/facade-cluster/summary.txt. Old spelling: -Facade.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List a facade + stem-folder helpers by size (no body reads).", json_out=True)
    ap.add_argument("facade_pos", nargs="?", default="", help="Facade .gd path or cluster folder (same as --facade).")
    ap.add_argument("--facade", "-Facade", default="", help="Facade .gd path or cluster folder (or pass it as the argument).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    facade = args.facade or args.facade_pos
    if not facade:
        agent_log.fail("pass --facade scripts/<dir>/<stem>.gd (or a cluster folder)")
    full = Path(facade)
    full = (full if full.is_absolute() else root / full)
    if full.is_dir():
        sibs = sorted(full.glob("*.gd"), key=lambda p: -p.stat().st_size)
        body = [f"root=. folder={agent_log.rel(root, full.resolve())}", f"siblings={len(sibs)}", ""] + [f"{agent_log.rel(root, p)} bytes={p.stat().st_size}" for p in sibs]
        return agent_log.finish("facade-cluster", root, "\n".join(body), "INFO", args=args, siblings=len(sibs), total_bytes=sum(p.stat().st_size for p in sibs))
    if not full.is_file():
        agent_log.fail(f"missing facade: {facade} (give the repo-relative facade .gd path, example: scripts/app.gd)")
    full = full.resolve()
    outer = full.parent.parent / (full.parent.name + ".gd")
    if full.stem != full.parent.name and (full.parent.parent / full.parent.name).is_dir() and outer.is_file():
        full = outer  # helper inside <stem>/ -> its facade beside the folder
    stem = full.stem
    found = [p for p in full.parent.glob("*.gd") if p.stem == stem or p.stem.startswith(stem + "_")]
    folder = full.parent / stem
    if folder.is_dir():
        found += list(folder.glob("*.gd"))
    elif full.parent.name != stem and not found:
        found = [full]
    sibs = sorted(found, key=lambda p: -p.stat().st_size)
    total = sum(p.stat().st_size for p in sibs)
    body = [f"root=. facade={agent_log.rel(root, full)}", f"stem={stem} dir={agent_log.rel(root, full.parent)}",
            f"siblings={len(sibs)}", ""] + [f"{agent_log.rel(root, p)} bytes={p.stat().st_size}" for p in sibs]
    return agent_log.finish("facade-cluster", root, "\n".join(body), "INFO", args=args, siblings=len(sibs), total_bytes=total)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
