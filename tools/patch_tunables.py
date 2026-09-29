#!/usr/bin/env python3
"""Set the Live cell on one design/tunables.md row.

    python tools/patch_tunables.py --key CAM_PITCH --set -58

Writes _logs/sess/<id>/tunable-patch/summary.txt. Agents read that file only.
Do not open design/tunables.md to change one number.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

import agent_log

sys.path.insert(0, str(Path(__file__).resolve().parent))
import md_format_lib as md
import tunables_lib as tl


def main() -> int:
    ap = argparse.ArgumentParser(description="Patch one design/tunables.md Live cell.")
    ap.add_argument("--key", required=True, help="Tunable key or unique alias")
    ap.add_argument("--set", dest="value", required=True, help="New Live cell text")
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    path = root / "design" / "tunables.md"
    out_dir = agent_log.ensure_agent_log_dir("tunable-patch", root)
    summary = out_dir / "summary.txt"

    stamp = datetime.now(timezone.utc).isoformat()
    lines = [
        "tunable patch %s" % stamp,
        "root=%s" % root,
        "key=%s" % args.key,
        "set=%s" % args.value,
    ]
    if not path.is_file():
        lines += ["", "RESULT changed=0 error=missing-tunables"]
        md.write_lines(summary, lines)
        print("Summary -> %s" % summary)
        return 1

    raw = path.read_text(encoding="utf-8")
    all_hits = tl.parse_hits(raw)
    hits = tl.find_hits(all_hits, args.key)
    lines.append("matches=%d" % len(hits))
    if len(hits) != 1:
        lines.append("sections=%s" % ", ".join(h.section for h in hits))
        lines += ["", "RESULT changed=0 error=%s" % ("no-row" if not hits else "ambiguous")]
        md.write_lines(summary, lines)
        print("Summary -> %s" % summary)
        return 1

    hit = hits[0]
    lines.extend(tl.format_hit(hit))
    if hit.live_cell == args.value:
        lines += ["", "RESULT changed=0 skipped=already"]
        md.write_lines(summary, lines)
        print("changed=0")
        print("Summary -> %s" % summary)
        return 0

    file_lines = raw.splitlines(keepends=True)
    file_lines[hit.index] = tl.set_live_cell(file_lines[hit.index], hit.live_col, args.value)
    md.write_utf8(path, md.join_lines_keep_trailing(raw, file_lines))
    lines.append("live_was=%s" % hit.live_cell)
    lines.append("live_now=%s" % args.value)
    lines.append("measure=mutate one tunables Live cell; do not read the rest of the file")
    lines += ["", "RESULT changed=1"]
    md.write_lines(summary, lines)
    print("changed=1 live=%s" % args.value)
    print("Summary -> %s" % summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
