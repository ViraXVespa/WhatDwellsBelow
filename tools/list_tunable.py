#!/usr/bin/env python3
"""Print one design/tunables.md row.

    python tools/list_tunable.py --key CAM_PITCH

Writes _logs/sess/<id>/tunable-row/summary.txt. Agents read that file only.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

import agent_log

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tunables_lib as tl


def main() -> int:
    ap = argparse.ArgumentParser(description="Print one design/tunables.md row.")
    ap.add_argument("--key", required=True, help="Tunable key or unique alias")
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    path = root / "design" / "tunables.md"
    out_dir = agent_log.ensure_agent_log_dir("tunable-row", root)
    summary = out_dir / "summary.txt"

    stamp = datetime.now(timezone.utc).isoformat()
    lines = [
        "tunable row %s" % stamp,
        "root=%s" % root,
        "key=%s" % args.key,
    ]
    if not path.is_file():
        lines += ["", "RESULT matches=0 error=missing-tunables"]
        summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print("Summary -> %s" % summary)
        return 1

    hits = tl.find_hits(tl.parse_hits(path.read_text(encoding="utf-8")), args.key)
    lines.append("matches=%d" % len(hits))
    lines.append("measure=parse tunables tables; do not read the rest of the file")
    lines.append("")
    if not hits:
        lines.append("NO_ROW")
    for hit in hits:
        lines.extend(tl.format_hit(hit))
        lines.append("")
    lines.append("RESULT matches=%d" % len(hits))
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("matches=%d" % len(hits))
    print("Summary -> %s" % summary)
    return 0 if hits else 1


if __name__ == "__main__":
    raise SystemExit(main())
