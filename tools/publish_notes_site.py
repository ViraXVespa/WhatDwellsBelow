#!/usr/bin/env python3
"""Copy baked version/changelog JSON onto the Pages site as loose /data files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _load(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return raw if isinstance(raw, dict) else {}


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def publish(root: Path, site: Path) -> dict:
    version = _load(root / "scripts" / "data" / "version.json")
    changelog = _load(root / "scripts" / "data" / "changelog.json")
    data_dir = site / "data"
    _write(data_dir / "version.json", json.dumps(version, ensure_ascii=False, indent=2))
    _write(
        data_dir / "changelog.json",
        json.dumps(changelog, ensure_ascii=False, indent=2),
    )
    payload = {"version": version, "changelog": changelog}
    body = "window.__wdbNotes = %s;\n" % json.dumps(payload, ensure_ascii=False)
    _write(data_dir / "notes.js", body)
    label = str(version.get("label") or "")
    entries = changelog.get("entries") if isinstance(changelog.get("entries"), list) else []
    summary = (
        "notes site %s\n"
        "site=%s\n"
        "label=%s entries=%s\n"
        "wrote data/version.json data/changelog.json data/notes.js\n"
        % (label, site, label, len(entries))
    )
    _write(root / "_logs" / "notes-site" / "summary.txt", summary)
    return {"label": label, "entries": len(entries), "site": str(site)}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Publish loose version/changelog files for GitHub Pages."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--site", default="site")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = Path(args.root).expanduser().resolve()
    site = Path(args.site)
    if not site.is_absolute():
        site = (root / site).resolve()
    info = publish(root, site)
    print("label=%s entries=%s site=%s" % (info["label"], info["entries"], info["site"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())