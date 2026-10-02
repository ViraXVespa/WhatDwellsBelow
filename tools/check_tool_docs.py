#!/usr/bin/env python3
"""Check the tools catalog (design/tools*.md) against tools/ and tools/bot_allow.txt."""

from __future__ import annotations

import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib

CATALOGS = ("tools.md", "tools-build.md", "tools-media.md")
ROW = re.compile(r"^\|\s*`([^`|]+)`\s*\|.*\|\s*([BWD]+)\s*\|[^|]*\|\s*([YN])\s*\|\s*$")


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check the tools catalog (design/tools*.md) against tools/ and tools/bot_allow.txt.", json_out=True)
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    tools = root / "tools"
    files = {f.name for f in tools.iterdir() if f.is_file() and f.name != "_scratch.py"}
    allow = {g[len("tools/"):] for g in repo_lib.load_allowlist(root) if g.startswith("tools/")}
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
    head = f"tool-docs: tools={len(files)} rows={len(rows)} allowlisted={len(allow)} problems={len(bad)}"
    return agent_log.finish("tool-docs", root, "\n".join(bad + [head]), "FAIL" if bad else "PASS", args=args,
                            legacy=False, tools=len(files), rows=len(rows), problems=len(bad))


if __name__ == "__main__":
    raise SystemExit(main())
