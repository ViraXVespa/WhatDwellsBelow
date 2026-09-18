#!/usr/bin/env python3
"""Add a grok_web_wN catalog row for HEAD. Does not bump version.json."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--id", required=True)
    ap.add_argument("--label", required=True)
    ap.add_argument("--desc", required=True)
    ap.add_argument("--commit", required=True)
    args = ap.parse_args()
    root = Path(args.root).resolve()
    cat_path = root / "scripts" / "data" / "archive_catalog.json"
    data = json.loads(cat_path.read_text(encoding="utf-8"))
    builds = data.get("builds") or data.get("archives") or data
    if isinstance(data, list):
        builds = data
        wrapper = None
    else:
        wrapper = data
        if "builds" in data:
            builds = data["builds"]
        else:
            data["builds"] = []
            builds = data["builds"]
    if any(b.get("id") == args.id for b in builds):
        print(f"exists {args.id}")
        return 0
    docs = []
    design = root / "design"
    if design.is_dir():
        for p in sorted(design.rglob("*")):
            if p.suffix.lower() in {".md", ".yaml", ".yml"}:
                docs.append(p.relative_to(root).as_posix())
    builds.append(
        {
            "id": args.id,
            "label": args.label,
            "desc": args.desc,
            "commit": args.commit,
            "pages_slug": f"archives/{args.id}",
            "video": "",
            "docs": docs,
        }
    )
    if wrapper is None:
        cat_path.write_text(json.dumps(builds, indent="\t") + "\n", encoding="utf-8")
    else:
        cat_path.write_text(json.dumps(wrapper, indent="\t") + "\n", encoding="utf-8")
    print(f"added {args.id} commit={args.commit} docs={len(docs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())