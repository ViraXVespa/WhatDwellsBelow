#!/usr/bin/env python3
"""Placeholdia -> Dungeon load-timing smoke. Per-path Godot lock; never kills godot*.

    python tools/run_dungeon_load_timing.py [--timeout-sec 180]
Summary: _logs/dungeon-load-timing/<stamp>-dungeon-load-timing.txt.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def main(argv: list[str] | None = None) -> int:
    args = godot_lib.timing_parser("Placeholdia to Dungeon load-timing smoke.").parse_args(argv)
    return godot_lib.timing_job(args, "dungeon-load-timing", "dungeon load timing", "--wdb-dungeon-load-timing-smoke",
                                "Running Placeholdia to Dungeon load timing...")


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
