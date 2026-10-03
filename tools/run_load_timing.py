#!/usr/bin/env python3
"""Title -> Placeholdia load-timing smoke. Per-path Godot lock; never kills godot*.

    python3 tools/run_load_timing.py [--timeout-sec 180]
Summary: _logs/load-timing/summary.txt (python twin of run_load_timing.ps1).
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def main(argv: list[str] | None = None) -> int:
    args = godot_lib.timing_parser("Title to Placeholdia load-timing smoke.").parse_args(argv)
    return godot_lib.timing_job(args, "load-timing", "load timing", "--wdb-load-timing-smoke",
                                "Running Title to Placeholdia load timing...")


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
