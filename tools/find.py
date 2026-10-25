#!/usr/bin/env python3
"""Read-only lookups: text, one function, a route card, scenes, facades, file stats, changed files.

`python tools/find.py` lists the subcommands; `python tools/find.py SUB --help` prints that one's flags.
The work lives in tools/lib/lookup/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("xref",     "lookup/list_xref",              "Text search in the project (TEXT, --regex, --path, --include)"),
    ("func",     "lookup/show_func",              "One GDScript or Python declaration (PATH NAME)"),
    ("route",    "lookup/list_route",             "One routes.yaml door or job card (--door, --job, --digest)"),
    ("scenes",   "lookup/list_scenes",            ".tscn nodes and scripts without dumping scenes"),
    ("facade",   "lookup/list_facade_cluster",    "A facade and its stem-folder helpers by bytes"),
    ("stat",     "lookup/file_stat",              "Bytes, BOM, EOL and indent for a path or glob"),
    ("scripts",  "lookup/summarize_scripts",      "Func inventory per .gd (--path, --top-funcs)"),
    ("changed",  "lookup/list_changed",           "Git-changed paths with bytes; --history PATH"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
