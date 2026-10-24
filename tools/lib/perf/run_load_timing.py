#!/usr/bin/env python3
"""Load-timing smoke for one leg. Per-path Godot lock; never kills godot*.

    python tools/perf.py load [--leg hub|dungeon] [--timeout-sec 180]
hub:     Title -> Placeholdia (--wdb-load-timing-smoke).        Summary: _logs/load-timing/<stamp>-load-timing.txt
dungeon: Placeholdia -> Dungeon (--wdb-dungeon-load-timing-smoke). Summary: _logs/dungeon-load-timing/<stamp>-dungeon-load-timing.txt
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import godot_lib

LEGS = {  # leg -> (job, title, app flag, running line)
    "hub": ("load-timing", "load timing", "--wdb-load-timing-smoke", "Running Title to Placeholdia load timing..."),
    "dungeon": ("dungeon-load-timing", "dungeon load timing", "--wdb-dungeon-load-timing-smoke",
                "Running Placeholdia to Dungeon load timing..."),
}

def main(argv: list[str] | None = None) -> int:
    ap = godot_lib.timing_parser("Load-timing smoke: Title to Placeholdia (hub) or Placeholdia to Dungeon (dungeon).")
    ap.add_argument("--leg", choices=sorted(LEGS), default="hub", help="hub: Title to Placeholdia (default). dungeon: Placeholdia to Dungeon.")
    args = ap.parse_args(argv)
    return godot_lib.timing_job(args, *LEGS[args.leg])

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
