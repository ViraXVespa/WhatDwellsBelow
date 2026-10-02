#!/usr/bin/env python3
"""List .tscn nodes and attached scripts without dumping scene files into chat.

    python3 tools/list_scenes.py [--path scenes/dungeon.tscn] [--max-nodes 200]
Summary: _logs/scenes/summary.txt. Old spellings: -Path -MaxNodes.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log

EXT = re.compile(r'^\[ext_resource[^\]]*\bpath="([^"]+)"[^\]]*\bid="([^"]+)"')
NODE = re.compile(r'^\[node\s+name="([^"]+)"(?:\s+type="([^"]*)")?(?:\s+parent="([^"]*)")?')
SCRIPT = re.compile(r'^script\s*=\s*ExtResource\("([^"]+)"\)')


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List .tscn nodes + scripts (headers only).", json_out=True)
    ap.add_argument("--path", "-Path", nargs="+", default=["scenes"], help="Scene file(s) or dir(s).")
    ap.add_argument("--max-nodes", "-MaxNodes", type=int, default=200)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    paths = agent_log.split_list(args.path)
    scenes: list[Path] = []
    for raw in paths:
        p = Path(raw)
        p = p if p.is_absolute() else root / p
        if p.is_dir():
            scenes += [s for s in p.rglob("*.tscn") if "archives" not in s.parts and ".archive_worktrees" not in s.parts]
        elif p.suffix.lower() == ".tscn" and p.is_file():
            scenes.append(p)
    body = [f"root=. path={','.join(paths)} scenes={len(scenes)} maxNodes={args.max_nodes}",
            "measure=parse .tscn headers; do not open scene bodies in chat", ""]
    nodes = scripts = 0
    trunc = False
    for scene in sorted(scenes):
        if nodes >= args.max_nodes:
            trunc = True
            break
        body.append(f"SCENE {agent_log.rel(root, scene)} bytes={scene.stat().st_size}")
        res: dict[str, str] = {}
        for raw in scene.read_text(encoding="utf-8", errors="replace").splitlines():
            m = EXT.match(raw)
            if m:
                res[m.group(2)] = m.group(1)
                continue
            m = NODE.match(raw)
            if m:
                if nodes >= args.max_nodes:
                    trunc = True
                    break
                nodes += 1
                body.append(f"NODE {m.group(1)} type={m.group(2) or '?'} parent={m.group(3) or '.'}")
                continue
            m = SCRIPT.match(raw)
            if m:
                scripts += 1
                body.append(f"SCRIPT {res.get(m.group(1), m.group(1))}")
        body.append("")
    echo = f"scenes={len(scenes)} nodes={nodes} scripts={scripts} truncated={trunc}"
    return agent_log.finish("scenes", root, "\n".join(body), "INFO", args=args, echo=echo, scenes=len(scenes),
                            nodes=nodes, scripts=scripts, truncated=trunc)


if __name__ == "__main__":
    raise SystemExit(main())
