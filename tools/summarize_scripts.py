#!/usr/bin/env python3
"""Func-level script inventory for live .gd files. Agents read the summary, not bodies.

Usage (from repo root):
  python tools/summarize_scripts.py
  python tools/summarize_scripts.py --path scripts/combat/enemy.gd
  python tools/summarize_scripts.py --over-kb 5 --top-funcs 8
  powershell -File tools/summarize_scripts.ps1

Output: _logs/script-summary/summary.txt
"""
from __future__ import annotations

import argparse
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
OUT_DIR = ROOT / "_logs" / "script-summary"
SUMMARY = OUT_DIR / "summary.txt"
SKIP = (".archive_worktrees", "archives")
RE_FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\(")


def iter_gd(paths: list[Path] | None) -> list[Path]:
    if paths:
        out = []
        for p in paths:
            p = p if p.is_absolute() else (ROOT / p)
            if p.is_file() and p.suffix == ".gd":
                out.append(p)
        return sorted(out)
    out = []
    for p in SCRIPTS.rglob("*.gd"):
        s = str(p)
        if any(x in s for x in SKIP):
            continue
        out.append(p)
    return sorted(out)


def funcs_of(path: Path) -> list[tuple[str, int, int, int]]:
    """Return list of (name, start_line, end_line, approx_utf8_bytes)."""
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(True)
    starts: list[tuple[str, int]] = []
    for i, line in enumerate(lines, 1):
        m = RE_FUNC.match(line)
        if m:
            starts.append((m.group(2), i))
    if not starts:
        return []
    out: list[tuple[str, int, int, int]] = []
    for idx, (name, start) in enumerate(starts):
        end = (starts[idx + 1][1] - 1) if idx + 1 < len(starts) else len(lines)
        chunk = "".join(lines[start - 1 : end])
        out.append((name, start, end, len(chunk.encode("utf-8"))))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", action="append", default=[], help="Limit to one or more .gd paths")
    ap.add_argument("--over-kb", type=float, default=0.0, help="Only list files >= this many KB (0=all)")
    ap.add_argument("--top-funcs", type=int, default=6, help="Largest funcs to list per file")
    args = ap.parse_args()
    paths = [Path(p) for p in args.path] if args.path else None
    files = iter_gd(paths)
    over_bytes = int(args.over_kb * 1000) if args.over_kb > 0 else 0

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines: list[str] = [
        f"script summary {datetime.now().astimezone().isoformat()}",
        f"root={ROOT}",
        f"files={len(files)} over_kb={args.over_kb} top_funcs={args.top_funcs}",
        "",
    ]
    listed = 0
    for p in files:
        length = p.stat().st_size
        if over_bytes and length < over_bytes:
            continue
        rel = str(p.relative_to(ROOT)).replace("/", "\\")
        fns = funcs_of(p)
        fns_sorted = sorted(fns, key=lambda t: t[3], reverse=True)
        top = fns_sorted[: max(0, args.top_funcs)]
        lines.append(f"{rel} bytes={length} funcs={len(fns)}")
        for name, start, end, b in top:
            lines.append(f"  {name} L{start}-{end} bytes={b}")
        lines.append("")
        listed += 1

    lines.append(f"RESULT files_listed={listed}")
    SUMMARY.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Listed {listed} scripts -> {SUMMARY}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
