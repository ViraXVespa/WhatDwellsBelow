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

import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib

LABEL_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def load_version(root: Path) -> tuple[int, int, str]:
    if not (root / repo_lib.VERSION_FILE).is_file():
        return 0, 3, "0.3.0"
    ver = repo_lib.read_version(root)
    epoch = int(ver.get("epoch", 0))
    series = int(ver.get("series", 0))
    return epoch, series, str(ver.get("label", f"{epoch}.{series}.0"))


def main() -> int:
    ap = agent_log.std_parser("Move prior-series design/changelog/*.md into archive/<epoch>.<series>/.", writes=True, json_out=True)
    args = ap.parse_args()
    ROOT = agent_log.resolve_root(args)
    CHANGELOG_DIR = repo_lib.changelog_dir(ROOT)
    ARCHIVE_DIR = CHANGELOG_DIR / "archive"
    epoch, series, label = load_version(ROOT)
    current_prefix = f"{epoch}.{series}."

    lines: list[str] = [
        f"changelog archive {datetime.now().astimezone().isoformat()}",
        "root=.",
        f"current={label} prefix={current_prefix} dry_run={args.dry_run}",
        "",
    ]
    moved = 0
    skipped = 0
    if not CHANGELOG_DIR.is_dir():
        return agent_log.finish("changelog-archive", ROOT, "\n".join(lines), "INFO", args=args, legacy=False, moved=0, note="no_changelog_dir")

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
                agent_log.fail(f"destination exists: {dest.relative_to(ROOT).as_posix()}", 1)
            # prefer git mv when in a repo; fall back to rename
            try:
                subprocess.run(
                    ["git", "mv", "--", str(path), str(dest)],
                    cwd=ROOT,
                    check=True,
                    capture_output=True,
                )
            except Exception:
                shutil.move(str(path), str(dest))
        moved += 1

    return agent_log.finish("changelog-archive", ROOT, "\n".join(lines), "PASS", args=args, moved=moved, skipped=skipped, dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
