#!/usr/bin/env python3
"""Light and art bakes: camp light map, ground wear, frame art, and the bake hash check.

`python tools/bake.py` lists the subcommands; `python tools/bake.py SUB --help` prints that one's flags.
The work lives in tools/lib/bake/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("camp",    "bake/run_bake_camp",          "Bake hub_light.png (and ground wear) on a real renderer"),
    ("ground",  "bake/bake_ground_wear",       "Bake the tileable ground_wear.png sheet"),
    ("frames",  "bake/bake_frame_art",         "Bake object-frame art PNGs under assets/ui/frames and verify them"),
    ("check",   "bake/check_hub_bake",         "Committed bake hashes vs HUB_BAKE_STAMP (the game crashes on a mismatch)"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
