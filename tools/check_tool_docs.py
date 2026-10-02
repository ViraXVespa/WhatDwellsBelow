#!/usr/bin/env python3
"""Check the tools catalog (design/tools*.md) against tools/ and tools/bot_allow.txt."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CATALOGS = ("tools.md", "tools-build.md", "tools-media.md")
ROW = re.compile(r"^\|\s*`([^`|]+)`\s*\|.*\|\s*([BWD]+)\s*\|[^|]*\|\s*([YN])\s*\|\s*$")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=".")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = Path(args.root).expanduser().resolve()
    tools = root / "tools"
    files = {f.name for f in tools.iterdir() if f.is_file() and f.name != "_scratch.py"}
    allow = {
        ln.strip()[len("tools/"):]
        for ln in (tools / "bot_allow.txt").read_text(encoding="utf-8").splitlines()
        if ln.strip().startswith("tools/")
    }
    rows: dict[str, tuple[str, str]] = {}
    bad: list[str] = []
    for cat in CATALOGS:
        for ln in (root / "design" / cat).read_text(encoding="utf-8").splitlines():
            m = ROW.match(ln)
            if not m:
                continue
            name, surf, a = m.groups()
            if name in rows:
                bad.append(f"DUP     {name} (also in another row)")
            rows[name] = (surf, a)
    for n in sorted(files - rows.keys()):
        bad.append(f"MISSING {n}: no catalog row")
    for n in sorted(rows.keys() - files):
        bad.append(f"STALE   {n}: catalog row but no such file")
    for n in sorted(allow - files):
        bad.append(f"ALLOW   {n}: on bot_allow.txt but no such file")
    for n, (surf, a) in sorted(rows.items()):
        if n in files and (n in allow) != (a == "Y"):
            bad.append(f"ALLOWED {n}: catalog A={a}, allowlist={'yes' if n in allow else 'no'}")
        if a == "Y" and "B" not in surf and "D" not in surf:
            bad.append(f"SURF    {n}: allowlisted but no B/D surface")
        if a == "Y" and n.endswith(".py") and n in files:
            t = (tools / n).read_text(encoding="utf-8-sig", errors="replace")
            if '"""' not in t[:600] and "argparse" not in t:
                bad.append(f"HELP    {n}: allowlisted .py without docstring or argparse")
    for b in bad:
        print(b)
    print(f"tool-docs: tools={len(files)} rows={len(rows)} allowlisted={len(allow)} problems={len(bad)}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
