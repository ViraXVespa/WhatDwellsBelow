#!/usr/bin/env python3
"""Print the next design/changelog label. Does not write changelog files.

    python tools/next_changelog_label.py
    python tools/next_changelog_label.py --root .

Reads scripts/data/version.json. Next label is epoch.series.(patch + 1).
Stamp commits are ignored because this uses the baked JSON, not git log.
Writes _logs/changelog-label/summary.txt. Agents read that file only.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import agent_log


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Print the next design/changelog/{label} value."
    )
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    baked = root / "scripts" / "data" / "version.json"
    out_dir = agent_log.ensure_agent_log_dir("changelog-label", root)
    summary = out_dir / "summary.txt"
    out_dir.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now(timezone.utc).isoformat()
    lines = [
        f"changelog label {stamp}",
        f"root={root}",
        f"source={baked.as_posix()}",
    ]

    if not baked.is_file():
        lines += ["", "RESULT error=missing-version-json"]
        summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"Summary -> {summary}")
        return 1

    data = json.loads(baked.read_text(encoding="utf-8"))
    epoch = int(data["epoch"])
    series = int(data["series"])
    patch = int(data["patch"])
    current = str(data.get("label") or f"{epoch}.{series}.{patch}")
    nxt_patch = patch + 1
    nxt = f"{epoch}.{series}.{nxt_patch}"
    dest = f"design/changelog/{nxt}.md"

    lines += [
        f"current={current}",
        f"epoch={epoch} series={series} patch={patch}",
        f"next={nxt}",
        f"write_path={dest}",
        "measure=baked version.json patch + 1; do not read design/changelog/",
        "",
        f"RESULT next={nxt}",
    ]
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"next={nxt}")
    print(f"Summary -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())