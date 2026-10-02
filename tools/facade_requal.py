#!/usr/bin/env python3
"""Qualify moved symbols in a facade after a size split (stdlib only).

  python tools/facade_requal.py scripts/x.gd --sym DIRS=Grid --sym _thin_arr=Grid
  python tools/facade_requal.py scripts/x.gd --sym DIRS=Grid --dry-run
  python tools/facade_requal.py scripts/x.gd --sym DIRS=Grid --check

Each NAME=Mod rewrites bare NAME to Mod.NAME (not after a dot or word char).
Only CODE matches are rewritten; matches inside comments or strings are
listed separately (add --all to rewrite them too). Keeps BOM and line endings.
--check changes nothing: it lists bare code matches left in FILE (exit 1 if any)
and other scripts/**/*.gd that call X.NAME (they need NAME kept on the facade).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def kinds(text: str) -> list[str]:
    """Per-char class: c code, m comment, s string (single-line and triple quotes)."""
    out = ["c"] * len(text)
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch == "#":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out[i:j] = "m" * (j - i)
            i = j
        elif ch in "\"'":
            tri = text.startswith(ch * 3, i)
            q = ch * 3 if tri else ch
            j = i + len(q)
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text.startswith(q, j):
                    j += len(q)
                    break
                if not tri and text[j] == "\n":
                    break
                j += 1
            j = min(j, n)
            out[i:j] = "s" * (j - i)
            i = j
        else:
            i += 1
    return out


def find(text: str, name: str, cls: list[str]) -> dict[str, list[int]]:
    hits: dict[str, list[int]] = {"c": [], "m": [], "s": []}
    for m in re.finditer(r"(?<![\w.])" + re.escape(name) + r"\b", text):
        line_start = text.rfind("\n", 0, m.start()) + 1
        if re.match(r"\s*(static\s+)?func\s+$", text[line_start:m.start()]):
            continue
        hits[cls[m.start()]].append(m.start())
    return hits


def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("file")
    p.add_argument("--sym", action="append", default=[], metavar="NAME=Mod")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--check", action="store_true")
    p.add_argument("--all", action="store_true", help="also rewrite comment/string matches")
    ns = p.parse_args()
    path = Path(ns.file)
    text = path.read_bytes().decode("utf-8")
    syms = []
    for spec in ns.sym:
        if "=" not in spec:
            print(f"bad --sym {spec!r}", file=sys.stderr)
            return 2
        syms.append(tuple(spec.split("=", 1)))
    if ns.check:
        cls = kinds(text)
        left = 0
        for name, _ in syms:
            h = find(text, name, cls)
            for pos in h["c"]:
                left += 1
                print(f"BARE {path}:{line_of(text, pos)}: {name}")
            for k, label in (("m", "comment"), ("s", "string")):
                for pos in h[k]:
                    print(f"note {label} {path}:{line_of(text, pos)}: {name}")
        names = {n for n, _ in syms}
        root = Path(__file__).resolve().parent.parent / "scripts"
        for f in sorted(root.rglob("*.gd")):
            if f.resolve() == path.resolve():
                continue
            t = f.read_text(encoding="utf-8-sig", errors="replace")
            for n in names:
                for m in re.finditer(r"\w\." + re.escape(n) + r"\b", t):
                    print(f"caller {f.relative_to(root.parent)}:{line_of(t, m.start())}: {m.group(0)}")
        print(f"check: bare={left}")
        return 1 if left else 0
    for name, mod in syms:
        cls = kinds(text)
        h = find(text, name, cls)
        todo = h["c"] + (h["m"] + h["s"] if ns.all else [])
        print(f"{name} -> {mod}.{name}: code={len(h['c'])} comment={len(h['m'])} string={len(h['s'])}")
        for k, label in (("m", "comment"), ("s", "string")):
            for pos in h[k]:
                print(f"  {label} line {line_of(text, pos)}{'' if ns.all else ' (left as is)'}")
        for pos in sorted(todo, reverse=True):
            text = text[:pos] + f"{mod}." + text[pos:]
    if not ns.dry_run:
        path.write_bytes(text.encode("utf-8"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
