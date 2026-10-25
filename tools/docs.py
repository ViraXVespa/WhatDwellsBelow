#!/usr/bin/env python3
"""Design-doc edits: idempotent patches, task files, tunables rows, the code map.

`python tools/docs.py` lists the subcommands; `python tools/docs.py SUB --help` prints that one's flags.
The work lives in tools/lib/docs/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("patch",     "docs/doc_patch",              "Idempotent doc edits: replace, ensure-line, changelog, write, apply ..."),
    ("task",      "docs/task",                   "Task files in design/tasks/: list, show, new, update, done, index, check"),
    ("tunable",   "docs/tunables",               "Tunables: get, set (doc cell or code default), add (row or whole key), range, list, diff"),
    ("code-map",  "docs/code_map",               "Code map: check, row --path P, patch"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
