#!/usr/bin/env python3
"""Performance: hub bench, exported-web perf, hitch sink, load bars and timing, desktop perf, dungeon map.

`python tools/perf.py` lists the subcommands; `python tools/perf.py SUB --help` prints that one's flags.
The work lives in tools/lib/perf/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("hub",      "perf/run_hub_bench",          "Hub frame-time bench, two ~30 s walks (--leg desktop|web)"),
    ("web",      "perf/web_perf",               "Advisory perf of the exported web build in a headless browser (--flow, --baseline)"),
    ("hitch",    "perf/hitch_sink",             "Serve a web export and log the game's hitch rows"),
    ("bars",     "perf/load_bars",              "Web landing bar and in-game loader progress vs time, cold then cached"),
    ("load",     "perf/run_load_timing",        "Load-timing smoke (--leg hub|dungeon)"),
    ("desktop",  "perf/run_desktop_perf",       "Desktop release vs debug perf (--export)"),
    ("map",      "perf/run_dungeon_map",        "Dungeon generation map smoke (--seeds, --sweep)"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
