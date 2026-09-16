#!/usr/bin/env python3
"""Print the one design/code-map.md system row that names a live path.

    python tools/list_code_map_row.py --path scripts/app.gd
    python tools/list_code_map_row.py --path player.gd --root .

Writes _logs/code-map-row/summary.txt. Agents read that file only.
"""
from __future__ import annotations

import argparse
import re
from datetime import datetime, timezone
from pathlib import Path

TICK_RE = re.compile(r"`([^`]+)`")
ROW_RE = re.compile(r"^\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$")


def posix(rel: str) -> str:
    return rel.replace("\\", "/").lstrip("./")


def row_paths(live_cell: str) -> list[str]:
    found: list[str] = []
    last_dir = ""
    for raw in TICK_RE.findall(live_cell):
        token = posix(raw.strip())
        if not token:
            continue
        if "/" in token:
            last_dir = token.rsplit("/", 1)[0]
            found.append(token)
            continue
        if last_dir:
            found.append(f"{last_dir}/{token}")
        found.append(token)
    return found


def matches(needle: str, listed: list[str]) -> bool:
    n = posix(needle)
    base = n.rsplit("/", 1)[-1]
    for item in listed:
        if item == n or item.endswith("/" + n):
            return True
        if item == base or item.rsplit("/", 1)[-1] == base:
            return True
    return False


def parse_rows(text: str) -> list[tuple[str, str, list[str]]]:
    rows: list[tuple[str, str, list[str]]] = []
    seen_header = False
    for line in text.splitlines():
        m = ROW_RE.match(line)
        if not m:
            continue
        left, right = m.group(1).strip(), m.group(2).strip()
        if left.lower() == "system" and "live" in right.lower():
            seen_header = True
            continue
        if not seen_header:
            continue
        if set(left.replace("-", "")) == set() or left.startswith("-"):
            continue
        rows.append((left, right, row_paths(right)))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Print the matching design/code-map.md system row."
    )
    ap.add_argument("--path", required=True, help="Live script or scene path")
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    code_map = root / "design" / "code-map.md"
    out_dir = root / "_logs" / "code-map-row"
    summary = out_dir / "summary.txt"
    out_dir.mkdir(parents=True, exist_ok=True)

    needle = posix(args.path)
    stamp = datetime.now(timezone.utc).isoformat()
    lines = [
        f"code-map row {stamp}",
        f"root={root}",
        f"path={needle}",
    ]

    if not code_map.is_file():
        lines += ["", "RESULT matches=0 error=missing-code-map"]
        summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"Summary -> {summary}")
        return 1

    rows = parse_rows(code_map.read_text(encoding="utf-8"))
    hits = [row for row in rows if matches(needle, row[2])]
    lines.append(f"rows_scanned={len(rows)} matches={len(hits)}")
    lines.append("measure=parse design/code-map.md table; do not read the rest of the map")
    lines.append("")
    if not hits:
        lines.append("NO_ROW")
    for system, live, _listed in hits:
        lines.append(f"system={system}")
        lines.append(f"live={live}")
        lines.append("")
    lines.append(f"RESULT matches={len(hits)}")
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"matches={len(hits)}")
    print(f"Summary -> {summary}")
    return 0 if hits else 1


if __name__ == "__main__":
    raise SystemExit(main())