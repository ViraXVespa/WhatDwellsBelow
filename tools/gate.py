#!/usr/bin/env python3
"""Godot gates: the batch build gate and its parts (compile, import, smokes, release smoke, warnings).

`python tools/gate.py` lists the subcommands; `python tools/gate.py SUB --help` prints that one's flags.
The work lives in tools/lib/gates/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("build",       "gates/run_build_gate",         "The one batch gate (--batch); commit_slice needs its PASS"),
    ("gd-load",     "gates/check_gd_load",          "Compile check of changed .gd files (--files, --all, --base)"),
    ("import",      "gates/run_godot_import_check", "Editor import / script-reload check"),
    ("smokes",      "gates/run_smokes",             "Phase smokes on the PC (--door, --job, --phases)"),
    ("bot-smokes",  "gates/bot_smokes",             "Headless smokes on the Linux box (--phases, --door, --flows)"),
    ("release",     "gates/run_release_smoke",      "Release-mode proof on a scratch project copy"),
    ("warnscan",    "gates/bot_warnscan",           "Warning sweep by area (--list, --save-baseline, --baseline)"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
