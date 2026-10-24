#!/usr/bin/env python3
"""Screenshots: capture, scripted flows, compare and inspect PNGs, show them, flow coverage.

`python tools/shots.py` lists the subcommands; `python tools/shots.py SUB --help` prints that one's flags.
The work lives in tools/lib/shots/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("capture",   "shots/run_shots",              "Posed-camera postcard of one scene (--scene, --mode build|web|user, --zoom, --px/--pz)"),
    ("flow",      "shots/run_shot_flow",          "Scripted shot flows from tools/data/shot-flows/*.json (--flow, --job door.job)"),
    ("diff",      "shots/shot_diff",              "Before/after pixel diff of two PNGs or folders (--tol, --mask, --max-ratio)"),
    ("crop",      "shots/shot_crop",              "Crop and enlarge one region of a shot (PNG --box X,Y,W,H --zoom N)"),
    ("inspect",   "shots/img_inspect",            "Named image checks: describe, layout, contrast, grid, zoom, diff, montage"),
    ("gaps",      "shots/check_shot_gaps",        "UI states with no shot flow; flow and published-shot problems (--changed)"),
    ("show",      "shots/show_png",               "Stage pictures for the User in one prove folder and open them"),
    ("review",    "shots/review_shots",           "Second opinion on PNGs from an isolated Grok session (--question)"),
    ("tutorial",  "shots/tutorial_shots",         "How-to-Play screenshots: check tutorial_shots.json, --run shoots and stages them"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
