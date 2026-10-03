#!/usr/bin/env python3
"""Add a grok_web_wN catalog row for HEAD. Does not bump version.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log


def main() -> int:
    ap = agent_log.std_parser("Add a grok_web_wN catalog row for HEAD (does not bump version.json).", writes=True)
    ap.add_argument("--id", required=True, help="Week id to pin.")
    ap.add_argument("--label", required=True, help="Week label.")
    ap.add_argument("--desc", required=True, help="Week description.")
    ap.add_argument("--commit", required=True, help="Commit SHA to pin.")
    args = ap.parse_args()
    root = agent_log.resolve_root(args)
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
        return agent_log.emit_result("PASS", id=args.id, added=0)
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
    if not args.dry_run:
        cat_path.write_text(json.dumps(builds if wrapper is None else wrapper, indent="\t") + "\n", encoding="utf-8")
    print(f"{'would add' if args.dry_run else 'added'} {args.id} commit={args.commit} docs={len(docs)}")
    return agent_log.emit_result("PASS", id=args.id, added=1, docs=len(docs), dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
