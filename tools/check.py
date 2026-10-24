#!/usr/bin/env python3
"""Static repo checks: script names, doc routing, tool contract and catalog, doc sizes, load audit.

`python tools/check.py` lists the subcommands; `python tools/check.py SUB --help` prints that one's flags.
The work lives in tools/lib/checks/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("script-cap",  "checks/check_script_cap",       "Duplicate script names; with --bot also the size caps"),
    ("load-graph",  "checks/check_load_graph",       "Doc routing vs design/routes.yaml"),
    ("tool-cli",    "checks/check_tool_cli",         "Tool CLI contract (help, --out names, RESULT last, line budget; --smoke-run)"),
    ("tool-docs",   "checks/check_tool_docs",        "Tool catalog vs the entry tools; --stale-refs for dead doc references"),
    ("load-audit",  "checks/bot_load_audit",         "Audit one Grok Build session's reads before its first ask"),
    ("docs-size",   "checks/list_oversize_docs",     "Bot-only doc size sweep (--boot, --dupes)"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
