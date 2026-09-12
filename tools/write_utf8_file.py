#!/usr/bin/env python3
"""Write a UTF-8 text file without putting the body through PowerShell expansion.

Preferred (agents on Windows):
  @'
  ...body...
  '@ | python tools/write_utf8_file.py --path path/to/out.py

  # or base64 (safe in single-quoted PS strings):
  python tools/write_utf8_file.py --path path/to/out.py --b64 '....'

Options:
  --bom     prepend a single UTF-8 BOM (use when replacing a BOM'd design doc)
  --append  append instead of overwrite

Ephemeral agent scripts should go under _logs/agent-py/ and be run via
tools/run_agent_py.ps1 (deletes the script after run by default).
"""
from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description="Write UTF-8 text from stdin or --b64")
    ap.add_argument("--path", required=True, help="Output path (repo-relative or absolute)")
    ap.add_argument("--b64", default=None, help="Base64 body instead of stdin")
    ap.add_argument("--bom", action="store_true", help="Prepend UTF-8 BOM")
    ap.add_argument("--append", action="store_true", help="Append instead of overwrite")
    args = ap.parse_args()

    out = Path(args.path)
    if args.b64 is not None:
        body = base64.b64decode(args.b64)
    else:
        body = sys.stdin.buffer.read()

    # If stdin was text with a BOM already, keep at most one BOM when --bom set
    if body.startswith(b"\xef\xbb\xbf"):
        body = body[3:]

    out.parent.mkdir(parents=True, exist_ok=True)
    prefix = b"\xef\xbb\xbf" if args.bom else b""
    if args.append and out.is_file():
        existing = out.read_bytes()
        if existing.startswith(b"\xef\xbb\xbf"):
            # keep existing BOM; do not double
            data = existing + body
        else:
            data = prefix + existing + body if args.bom else existing + body
        out.write_bytes(data)
    else:
        out.write_bytes(prefix + body)

    print(f"wrote {out} bytes={out.stat().st_size} bom={args.bom} append={args.append}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
