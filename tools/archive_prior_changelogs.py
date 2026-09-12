#!/usr/bin/env python3
"""Move non-current-series changelog markdown out of design/changelog/ root.

Live authoring stays flat: design/changelog/{label}.md for the current series.
Prior series live under design/changelog/archive/{epoch}.{series}/{label}.md.

Idempotent. Safe to run on every stamp / new-week / locally:
  python tools/archive_prior_changelogs.py
  python tools/archive_prior_changelogs.py --dry-run

Reads scripts/data/version.json for current epoch.series. Files whose stem is
not {epoch}.{series}.* are moved into the matching archive subfolder.
Non-semver names in the root are left alone.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHANGELOG_DIR = ROOT / "design" / "changelog"
ARCHIVE_DIR = CHANGELOG_DIR / "archive"
VERSION_PATH = ROOT / "scripts" / "data" / "version.json"
OUT_DIR = ROOT / "_logs" / "changelog-archive"
SUMMARY = OUT_DIR / "summary.txt"
LABEL_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def load_version() -> tuple[int, int, str]:
    if not VERSION_PATH.is_file():
        return 0, 3, "0.3.0"
    ver = json.loads(VERSION_PATH.read_text(encoding="utf-8"))
    epoch = int(ver.get("epoch", 0))
    series = int(ver.get("series", 0))
    label = str(ver.get("label", f"{epoch}.{series}.0"))
    return epoch, series, label


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    epoch, series, label = load_version()
    current_prefix = f"{epoch}.{series}."

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines: list[str] = [
        f"changelog archive {datetime.now().astimezone().isoformat()}",
        f"root={ROOT}",
        f"current={label} prefix={current_prefix} dry_run={args.dry_run}",
        "",
    ]
    moved = 0
    skipped = 0
    if not CHANGELOG_DIR.is_dir():
        lines.append("RESULT moved=0 note=no_changelog_dir")
        SUMMARY.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(lines[-1])
        return 0

    for path in sorted(CHANGELOG_DIR.glob("*.md")):
        m = LABEL_RE.fullmatch(path.stem)
        if not m:
            skipped += 1
            lines.append(f"SKIP non-semver {path.name}")
            continue
        file_epoch, file_series, _patch = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        if path.stem.startswith(current_prefix):
            skipped += 1
            continue
        dest_dir = ARCHIVE_DIR / f"{file_epoch}.{file_series}"
        dest = dest_dir / path.name
        lines.append(f"MOVE {path.relative_to(ROOT).as_posix()} -> {dest.relative_to(ROOT).as_posix()}")
        if not args.dry_run:
            dest_dir.mkdir(parents=True, exist_ok=True)
            if dest.exists():
                raise SystemExit(f"destination exists: {dest}")
            # prefer git mv when in a repo; fall back to rename
            try:
                import subprocess

                subprocess.run(
                    ["git", "mv", "--", str(path), str(dest)],
                    cwd=ROOT,
                    check=True,
                    capture_output=True,
                )
            except Exception:
                shutil.move(str(path), str(dest))
        moved += 1

    lines.append("")
    lines.append(f"RESULT moved={moved} skipped={skipped} dry_run={args.dry_run}")
    SUMMARY.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Summary -> {SUMMARY}")
    print(lines[-1])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
