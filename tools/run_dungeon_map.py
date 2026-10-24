#!/usr/bin/env python3
"""Dungeon generation map smoke (--wdb-dungeon-map-smoke), one seed or a seed sweep. Per-path Godot lock.

    python tools/run_dungeon_map.py [--seed 42] [--floor 1] [--scale 8] [--timeout-sec 180]
    python tools/run_dungeon_map.py --sweep [--count 10 | --seeds 42,7,9] [--floor 1] [--scale 8]
One seed:  _logs/dungeon-map/<stamp>-dungeon-map.txt (full dump _logs/dungeon-map/dump.txt).
--sweep:   one row per seed in _logs/dungeon-map-sweep/<stamp>-dungeon-map-sweep.txt.
"""
from __future__ import annotations

import random
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Dungeon generation map smoke: one seed, or --sweep over several.", json_out=True)
    ap.add_argument("--seed", type=int, default=42, help="Dungeon seed (default 42).")
    ap.add_argument("--sweep", action="store_true", help="Run every seed in --seeds (or --count random seeds after 42); one table.")
    ap.add_argument("--seeds", nargs="+", default=[], help="Sweep seeds, 42,7,9 or 42 7 9 (implies --sweep).")
    ap.add_argument("--count", type=int, default=10, help="Sweep size when --seeds is empty (default 10).")
    ap.add_argument("--floor", type=int, default=1, help="Floor number (default 1).")
    ap.add_argument("--scale", type=int, default=8, help="Pixels per cell in the map PNG (default 8).")
    ap.add_argument("--timeout-sec", type=int, default=180, help="Godot timeout in seconds (default 180).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.sweep or args.seeds:
        return sweep(args, root)
    out_log, err_log = agent_log.run_path("dungeon-map", root, "out.log"), agent_log.run_path("dungeon-map", root, "err.log")
    print(f"Running dungeon map smoke seed={args.seed} floor={args.floor} scale={args.scale}...")
    ga = godot_lib.headless_args(root, "--wdb-dungeon-map-smoke", f"--wdb-dungeon-map-seed={args.seed}",
                                 f"--wdb-dungeon-map-floor={args.floor}", f"--wdb-dungeon-map-scale={args.scale}")
    r = godot_lib.run_godot(root, root, ga, out_log, err_log, args.timeout_sec)
    maps = [m for lg in (err_log, out_log) for m in godot_lib.grep_logs([lg], r"^MAP:")]
    errs = godot_lib.grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to")
    has_ok, spec_fail = False, -1
    for h in maps:
        if "ok=true" in h and "spec " not in h:
            has_ok = True
        m = re.search(r"spec_fail=(\d+)", h)
        spec_fail = int(m.group(1)) if m else spec_fail
    fail = int(r["status"] == "TIMEOUT") + int(r["status"].startswith("EXIT=") and r["status"] != "EXIT=0")
    fail += int(bool(errs)) + int(not has_ok) + int(spec_fail != 0)
    body = ["dungeon map root=.",
            f"status={r['status']} wall_ms={r['ms']} errBytes={r['err_bytes']} outBytes={r['out_bytes']} "
            f"seed={args.seed} floor={args.floor} scale={args.scale}", "", "--- MAP lines ---"]
    body += maps or ["(no MAP: lines - check the err log if TIMEOUT)"]
    body += ["", "--- errors ---"] + (errs[:40] or ["(none)"])
    return agent_log.finish("dungeon-map", root, "\n".join(body), "FAIL" if fail else "PASS", args=args,
                            retry=("run_dungeon_map.py", body), fail_signals=fail, spec_fail=spec_fail, map_ok=str(has_ok))

def sweep(args, root: Path) -> int:
    """Run this tool once per seed in a child process; one row per seed from each run's summary."""
    seeds = agent_log.split_list(args.seeds, int)
    if not seeds:
        seeds = [42]
        while len(seeds) < max(1, args.count):
            s = random.randint(1, 99999)
            if s not in seeds:
                seeds.append(s)
    rows, fail_n = [], 0
    names = {"rim_closed": "rim", "span_on_solid": "span", "gates_placed": "gates"}
    for i, seed in enumerate(seeds, 1):
        code = subprocess.run([sys.executable, str(Path(__file__).resolve()), "--root", str(root), "--seed", str(seed),
                               "--floor", str(args.floor), "--scale", str(args.scale), "--timeout-sec", str(args.timeout_sec)],
                              capture_output=True, text=True).returncode
        summary = agent_log.agent_summary_path("dungeon-map", root)  # the run that just finished
        found = {"spec": "?", "rim": "?", "span": "?", "gates": "?", "ok": "?"}
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
        rows.append(f"seed={seed} exit={code} spec_fail={found['spec']} rim={found['rim']} span={found['span']} "
                    f"gates={found['gates']} {found['ok']}")
    body = [f"floor={args.floor} scale={args.scale} n={len(seeds)}", f"seeds={','.join(map(str, seeds))}", ""] + rows
    bad = [r for r in rows if " exit=0 " not in r]
    echo = [body[0], f"failed seeds: {len(bad)}"] + bad[:5]
    return agent_log.finish("dungeon-map-sweep", root, "\n".join(body), "FAIL" if fail_n else "PASS", args=args,
                            echo="\n".join(echo), sweep_fail=fail_n, n=len(seeds))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
