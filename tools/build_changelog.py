#!/usr/bin/env python3
"""Build scripts/data/changelog.json from design/changelog/{epoch}.{series}.*.md.

Git assigns the version number. This script only packs the current series'
player-facing notes for the game. Do not treat changelog.json as the ledger.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHANGELOG_DIR = ROOT / "design" / "changelog"
VERSION_PATH = ROOT / "scripts" / "data" / "version.json"
OUT_PATH = ROOT / "scripts" / "data" / "changelog.json"

HEAD_RE = re.compile(r"^##\s+(\d+\.\d+\.\d+)\s*$")
POINT_RE = re.compile(r"^-\s+(.*)$")
SUB_RE = re.compile(r"^--\s+(.*)$")
SUMMARY_RE = re.compile(r"^Summary:\s+(.*)$", re.I)


def load_version() -> dict:
    if not VERSION_PATH.is_file():
        return {"epoch": 0, "series": 2, "patch": 0, "label": "0.2.0"}
    return json.loads(VERSION_PATH.read_text(encoding="utf-8"))


def parse_md(path: Path) -> dict | None:
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    player, _, _agent = text.partition("\n## Agent")
    label = ""
    points: list[dict] = []
    summary = ""
    current: dict | None = None
    for raw in player.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        m = HEAD_RE.match(line)
        if m:
            label = m.group(1)
            continue
        m = SUMMARY_RE.match(line)
        if m:
            summary = m.group(1).strip()
            continue
        m = SUB_RE.match(line)
        if m and current is not None:
            current.setdefault("subs", []).append(m.group(1).strip())
            continue
        m = POINT_RE.match(line)
        if m:
            current = {"text": m.group(1).strip(), "subs": []}
            points.append(current)
            continue
    if not label:
        stem = path.stem
        if re.fullmatch(r"\d+\.\d+\.\d+", stem):
            label = stem
    if not label:
        return None
    for p in points:
        if not p.get("subs"):
            p.pop("subs", None)
    return {"label": label, "points": points, "summary": summary}


def ver_tuple(label: str) -> tuple[int, int, int]:
    bits = label.split(".")
    out = [0, 0, 0]
    for i, b in enumerate(bits[:3]):
        if b.isdigit():
            out[i] = int(b)
    return out[0], out[1], out[2]


def main() -> int:
    ver = load_version()
    epoch = int(ver.get("epoch", 0))
    series = int(ver.get("series", 0))
    prefix = f"{epoch}.{series}."
    entries: list[dict] = []
    if CHANGELOG_DIR.is_dir():
        for path in sorted(CHANGELOG_DIR.glob(f"{epoch}.{series}.*.md")):
            if path.name.startswith("week-"):
                continue
            parsed = parse_md(path)
            if parsed is None:
                continue
            if not parsed["label"].startswith(prefix):
                continue
            entries.append(parsed)
    entries.sort(key=lambda e: ver_tuple(e["label"]), reverse=True)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "series": f"{epoch}.{series}",
        "generated_from": "design/changelog",
        "entries": entries,
    }
    OUT_PATH.write_text(json.dumps(payload, indent="\t") + "\n", encoding="utf-8")
    print(f"wrote {OUT_PATH.relative_to(ROOT)} ({len(entries)} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())