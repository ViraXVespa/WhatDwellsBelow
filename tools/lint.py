#!/usr/bin/env python3
"""Code hygiene: duplicates, dead code, script splits and moves, host pitfalls, blank lines.

`python tools/lint.py` lists the subcommands; `python tools/lint.py SUB --help` prints that one's flags.
The work lives in tools/lib/lint/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("dupes",    "lint/list_dupes",             "Duplicate functions and repeated blocks (read-only)"),
    ("unused",   "lint/list_unused_funcs",      "Dead-code report: unused and shadowed funcs"),
    ("split",    "lint/split_funcs",            "Split a GDScript into a facade plus helpers"),
    ("requal",   "lint/facade_requal",          "Qualify names that moved to helpers"),
    ("move",     "lint/move_script_cluster",    "git mv a facade cluster and rewrite references"),
    ("hostify",  "lint/lint_hostify",           "Advisory scan for := inference and host pitfalls"),
    ("blanks",   "lint/normalize_blanks",       "Collapse repeated blank lines (BOM/EOL kept)"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
