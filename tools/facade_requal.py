#!/usr/bin/env python3
"""Qualify moved symbols in a facade after a size split (stdlib only).

  python tools/facade_requal.py scripts/x.gd --sym DIRS=Grid --sym _thin_arr=Grid
  python tools/facade_requal.py scripts/x.gd --sym DIRS=Grid --dry-run

Each NAME=Mod rewrites bare NAME to Mod.NAME (not after a dot or word char).
Keeps BOM and line endings. Prints the replacement count per symbol.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("file")
    p.add_argument("--sym", action="append", default=[], metavar="NAME=Mod")
    p.add_argument("--dry-run", action="store_true")
    ns = p.parse_args()
    path = Path(ns.file)
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    for spec in ns.sym:
        if "=" not in spec:
            print(f"bad --sym {spec!r}", file=sys.stderr)
            return 2
        name, mod = spec.split("=", 1)
        text, n = re.subn(r"(?<![\w.])" + re.escape(name) + r"\b", f"{mod}.{name}", text)
        print(f"{name} -> {mod}.{name}: {n}")
    if not ns.dry_run:
        path.write_bytes(text.encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
