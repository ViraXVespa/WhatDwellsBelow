#!/usr/bin/env python3
"""Bake camp.tscn headless. Per-path Godot lock; never kills godot*.

    python3 tools/run_bake_camp.py [--timeout-sec 180]
Summary: _logs/bake-camp/summary.txt; RESULT carries clean=true|false.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bake camp.tscn through the headless --wdb-bake-camp hook.", json_out=True)
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=180)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    d = agent_log.ensure_agent_log_dir("bake-camp", root)
    out_log, err_log = d / "bake-out.log", d / "bake-err.log"
    print("Baking camp.tscn...")
    r = godot_lib.run_godot(root, root, godot_lib.headless_args(root, "--wdb-bake-camp"), out_log, err_log, args.timeout_sec)
    hits = godot_lib.grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|bake_camp:")
    hard = any(godot_lib.HARD_RE.search(h) for h in hits)
    clean = r["status"] == "EXIT=0" and not hard
    body = ["bake camp root=.", f"status={r['status']} ms={r['ms']} errBytes={r['err_bytes']} outBytes={r['out_bytes']}",
            "", "--- highlights ---"] + (hits[:120] or ["(no SCRIPT ERROR / WARNING highlights)"])
    return agent_log.finish("bake-camp", root, "\n".join(body), "PASS" if clean else "FAIL", args=args,
                            clean=str(clean).lower())


if __name__ == "__main__":
    raise SystemExit(main())
