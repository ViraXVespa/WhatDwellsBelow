#!/usr/bin/env python3
"""Run run_dungeon_map over several seeds; one sweep table.

    python3 tools/run_dungeon_map_sweep.py [--count 10] [--seed-list 42,7,9 | --seeds 42 7 9] [--floor 1 --scale 8]
Old spellings: -Count -Floor -Scale -TimeoutSec -Seeds -SeedList. Output: _logs/dungeon-map-sweep/<stamp>-dungeon-map-sweep.txt
"""
from __future__ import annotations

import random
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Dungeon map smoke across seeds.", json_out=True)
    ap.add_argument("--count", "-Count", type=int, default=10, help="Number of seeds to sweep (default 10).")
    ap.add_argument("--floor", "-Floor", type=int, default=1, help="Floor number (default 1).")
    ap.add_argument("--scale", "-Scale", type=int, default=8, help="Pixels per cell in the map PNGs (default 8).")
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=180, help="Godot timeout per seed in seconds (default 180).")
    ap.add_argument("--seeds", "-Seeds", nargs="+", default=[], help="Seeds, 1,2,3 or 1 2 3.")
    ap.add_argument("--seed-list", "-SeedList", default="", help="Comma list; wins over --seeds.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    seeds = agent_log.split_list([args.seed_list] if args.seed_list else args.seeds, int)
    if not seeds:
        seeds = [42]
        while len(seeds) < max(1, args.count):
            s = random.randint(1, 99999)
            if s not in seeds:
                seeds.append(s)
    runner = Path(__file__).resolve().parent / "run_dungeon_map.py"
    rows, fail_n = [], 0
    for i, seed in enumerate(seeds, 1):
        print(f"sweep {i}/{len(seeds)} seed={seed}")
        code = subprocess.run([sys.executable, str(runner), "--root", str(root), "--seed", str(seed), "--floor", str(args.floor),
                               "--scale", str(args.scale), "--timeout-sec", str(args.timeout_sec)]).returncode
        summary = agent_log.agent_summary_path("dungeon-map", root)  # the run that just finished
        found = {"spec": "?", "rim": "?", "span": "?", "gates": "?", "ok": "?"}
        names = {"rim_closed": "rim", "span_on_solid": "span", "gates_placed": "gates"}
        for ln in (summary.read_text(encoding="utf-8").splitlines() if summary.is_file() else []):
            m = re.search(r"spec (rim_closed|span_on_solid|gates_placed) (.+)$", ln)
            if m:
                found[names[m.group(1)]] = m.group(2).strip()
            if ln.startswith("RESULT "):
                found["ok"] = ln
            m = re.search(r"spec_fail=(\d+)", ln)
            if m:
                found["spec"] = m.group(1)
        fail_n += code != 0
        row = f"seed={seed} exit={code} spec_fail={found["spec"]} rim={found["rim"]} span={found["span"]} gates={found["gates"]} {found["ok"]}"
        rows.append(row)
        print(row)
    body = [f"floor={args.floor} scale={args.scale} n={len(seeds)}", f"seeds={','.join(map(str, seeds))}", ""] + rows
    return agent_log.finish("dungeon-map-sweep", root, "\n".join(body), "FAIL" if fail_n else "PASS", args=args,
                            sweep_fail=fail_n, n=len(seeds))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
