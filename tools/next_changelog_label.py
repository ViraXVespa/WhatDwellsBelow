#!/usr/bin/env python3
"""Shim (one release): print the next design/changelog label. Same as `doc_patch.py next-label`.

Reads scripts/data/version.json (epoch.series.(patch + 1)); never writes changelog files.
Writes _logs/changelog-label/summary.txt.
"""
from __future__ import annotations

import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Print the next design/changelog/{label} value.", json_out=True)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if not (root / repo_lib.VERSION_FILE).is_file():
        return agent_log.finish("changelog-label", root, f"source={repo_lib.VERSION_FILE}", "FAIL", args=args, error="missing-version-json")
    v = repo_lib.read_version(root)
    nxt = repo_lib.next_label(root)
    body = "\n".join([
        "changelog label", "root=.", f"source={repo_lib.VERSION_FILE}",
        f"current={v.get('label') or '%s.%s.%s' % (v['epoch'], v['series'], v['patch'])}",
        f"next={nxt}", f"write_path=design/changelog/{nxt}.md",
        "measure=baked version.json patch + 1; do not read design/changelog/",
    ])
    return agent_log.finish("changelog-label", root, body, "PASS", args=args, echo=f"next={nxt}", next=nxt)


if __name__ == "__main__":
    raise SystemExit(main())
