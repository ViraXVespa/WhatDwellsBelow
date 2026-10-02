#!/usr/bin/env python3
"""Dungeon generation map smoke (--wdb-dungeon-map-smoke). Per-path Godot lock.

    python3 tools/run_dungeon_map.py [--seed 42 --floor 1 --scale 8 --timeout-sec 180]
Old spellings: -Seed -Floor -Scale -TimeoutSec. Summary: _logs/dungeon-map/summary.txt
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Dungeon generation map smoke.", json_out=True)
    ap.add_argument("--seed", "-Seed", type=int, default=42)
    ap.add_argument("--floor", "-Floor", type=int, default=1)
    ap.add_argument("--scale", "-Scale", type=int, default=8)
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=180)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    d = agent_log.ensure_agent_log_dir("dungeon-map", root)
    out_log, err_log = d / "out.log", d / "err.log"
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
    body += maps or ["(no MAP: lines - check err.log if TIMEOUT)"]
    body += ["", "--- errors ---"] + (errs[:40] or ["(none)"])
    return agent_log.finish("dungeon-map", root, "\n".join(body), "FAIL" if fail else "PASS", args=args,
                            fail_signals=fail, spec_fail=spec_fail, map_ok=str(has_ok))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
