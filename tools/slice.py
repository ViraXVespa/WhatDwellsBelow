#!/usr/bin/env python3
"""Build slices: open a worktree, start the slice card, commit after the gate.

`python tools/slice.py` lists the subcommands; `python tools/slice.py SUB --help` prints that one's flags.
The work lives in tools/lib/slice/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("open",    "slice/open_slice",             "User-run launcher: open a slice worktree (AREA, --task ID)"),
    ("start",   "slice/start_build_slice",      "First command inside a slice worktree: the door card"),
    ("commit",  "slice/commit_slice",           "Commit the slice after a passing gate build"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
