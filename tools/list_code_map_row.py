#!/usr/bin/env python3
"""Print the one design/code-map.md system row that names a live path.

    python tools/list_code_map_row.py --path scripts/app.gd
    python tools/list_code_map_row.py --path player.gd --root .

Writes _logs/code-map-row/summary.txt. Agents read that file only.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

import agent_log

sys.path.insert(0, str(Path(__file__).resolve().parent))
import code_map_lib as cm


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Print the matching design/code-map.md system row."
    )
    ap.add_argument("--path", required=True, help="Live script or scene path")
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    code_map = root / "design" / "code-map.md"
    out_dir = agent_log.ensure_agent_log_dir("code-map-row", root)
    summary = out_dir / "summary.txt"
    out_dir.mkdir(parents=True, exist_ok=True)

    needle = cm.posix(args.path)
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

    rows = cm.parse_rows(code_map.read_text(encoding="utf-8"))
    hits = [row for row in rows if cm.matches(needle, row.listed)]
    lines.append(f"rows_scanned={len(rows)} matches={len(hits)}")
    lines.append("measure=parse design/code-map.md table; do not read the rest of the map")
    lines.append("")
    if not hits:
        lines.append("NO_ROW")
    for row in hits:
        lines.append(f"system={row.system}")
        lines.append(f"live={row.live}")
        lines.append("")
    lines.append(f"RESULT matches={len(hits)}")
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"matches={len(hits)}")
    print(f"Summary -> {summary}")
    return 0 if hits else 1


if __name__ == "__main__":
    raise SystemExit(main())
