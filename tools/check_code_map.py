#!/usr/bin/env python3
"""Diff live scripts/**/*.gd against ticks in design/code-map.md.

    python tools/check_code_map.py
    python tools/check_code_map.py --root .

Advisory: unmapped files and missing listed paths. Not a ship gate.
Writes _logs/code-map-check/summary.txt. Agents read that file only.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import code_map_lib as cm


def _iter_scripts(root: Path) -> list[str]:
    scripts = root / "scripts"
    out: list[str] = []
    if not scripts.is_dir():
        return out
    for path in scripts.rglob("*.gd"):
        if not path.is_file():
            continue
        out.append(cm.posix(path.relative_to(root).as_posix()))
    out.sort()
    return out


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Diff live .gd files against design/code-map.md ticks."
    )
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    code_map = root / "design" / "code-map.md"
    out_dir = root / "_logs" / "code-map-check"
    summary = out_dir / "summary.txt"
    out_dir.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now(timezone.utc).isoformat()
    lines = [
        f"code-map check {stamp}",
        f"root={root}",
    ]

    if not code_map.is_file():
        lines += ["", "RESULT unmapped=0 missing=0 error=missing-code-map"]
        summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"Summary -> {summary}")
        return 1

    rows = cm.parse_rows(code_map.read_text(encoding="utf-8"))
    scripts = _iter_scripts(root)
    unmapped = [rel for rel in scripts if not cm.file_is_mapped(rel, rows)]
    missing: list[str] = []
    for rel in cm.listed_file_paths(rows):
        if not (root / rel).is_file():
            missing.append(rel)

    mapped = len(scripts) - len(unmapped)
    lines.append(f"rows_scanned={len(rows)} scripts={len(scripts)} mapped={mapped}")
    lines.append(
        "measure=scripts/**/*.gd vs code-map ticks; "
        "directory ticks cover children; do not read the map"
    )
    lines.append("")
    for rel in unmapped:
        lines.append(f"UNMAPPED {rel}")
    for rel in missing:
        lines.append(f"MISSING {rel}")
    if unmapped or missing:
        lines.append("")
    lines.append(
        f"RESULT unmapped={len(unmapped)} missing={len(missing)} "
        f"mapped={mapped} scripts={len(scripts)}"
    )
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(
        f"unmapped={len(unmapped)} missing={len(missing)} "
        f"mapped={mapped} scripts={len(scripts)}"
    )
    print(f"Summary -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
