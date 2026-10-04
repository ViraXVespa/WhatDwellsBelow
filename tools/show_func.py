#!/usr/bin/env python3
"""Extract one GDScript func/const into _logs/show-func/<stamp>-show-func.txt (first 80 lines)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import gd_lib

MAX_LINES = 80


def main(argv: list[str] | None = None) -> int:
    p = agent_log.std_parser("Extract one GDScript declaration.", json_out=True)
    p.add_argument("pos", nargs="*", metavar="PATH NAME", help="Same as --path and --name")
    p.add_argument("--path", default="", help="Repo-relative .gd path")
    p.add_argument("--name", default="", help="func / const / var name")
    args = p.parse_args(argv)
    if len(args.pos) > 2:
        agent_log.fail("pass at most PATH NAME (example: show_func.py scripts/app.gd _ready)")
    if args.pos and not args.path:
        args.path = args.pos[0]
    if len(args.pos) > 1 and not args.name:
        args.name = args.pos[1]
    if not (args.path and args.name):
        agent_log.fail("pass PATH and NAME (example: show_func.py scripts/app.gd _ready)")
    root, where = agent_log.cwd_scan_root(args)
    rel = args.path.replace("\\", "/").lstrip("/")
    src = root / rel
    head = [f"show_func path={rel} name={args.name}", where]
    if not src.is_file():
        agent_log.finish("show-func", root, "\n".join(head), "FAIL", args=args, legacy=False, error="missing")
        return 2
    body = src.read_text(encoding="utf-8-sig").splitlines()
    span = gd_lib.decl_span(body, args.name)
    if span is None:
        names = sorted({m.group(1) for ln in body if (m := re.match(r"(?:static\s+)?(?:func|const|var|signal|enum)\s+(\w+)", ln))})
        print(f"error: no declaration {args.name!r} in {rel}; declared: {', '.join(names[:40])}" + (" ..." if len(names) > 40 else ""), file=sys.stderr)
        return agent_log.finish("show-func", root, "\n".join(head), "FAIL", args=args, error="not_found")
    start, end = span
    chunk = body[start:end]
    truncated = len(chunk) > MAX_LINES
    chunk = chunk[:MAX_LINES]
    out = head + [f"lines={start + 1}-{start + len(chunk)} of {len(body)}", f"truncated={truncated}", ""] + chunk
    return agent_log.finish("show-func", root, "\n".join(out), "PASS", args=args,
                            lines=len(chunk), truncated=truncated)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
