#!/usr/bin/env python3
"""Shim (one release): same as `python3 tools/doc_patch.py write FILE [--b64 S] [--bom] [--append]`.

Writes UTF-8 text from stdin or --b64 without shell expansion. Keeps the file's own
line ending (CRLF for new files). Flags: --path (required), --b64, --bom, --append.
"""
from __future__ import annotations

import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import doc_patch


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Write UTF-8 text from stdin or --b64.", writes=True)
    ap.add_argument("--path", required=True, help="Output path (repo-relative or absolute)")
    ap.add_argument("--b64", default=None, help="Base64 body instead of stdin")
    ap.add_argument("--bom", action="store_true", help="Prepend UTF-8 BOM")
    ap.add_argument("--append", action="store_true", help="Append instead of overwrite")
    args = ap.parse_args(argv)
    cmd = ["write", args.path] + (["--b64", args.b64] if args.b64 is not None else []) + (["--bom"] if args.bom else []) + (["--append"] if args.append else [])
    pre = (["--root", args.root] if args.root else []) + (["--dry-run"] if args.dry_run else [])
    return doc_patch.main(pre + cmd)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
