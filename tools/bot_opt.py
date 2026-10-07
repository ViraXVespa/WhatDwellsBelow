#!/usr/bin/env python3
"""Shim for one release: the Bot opt queue is now the owner-bot task files design/tasks/opt-N.md; use tools/task.py.

    python tools/bot_opt.py --list             ->  python tools/task.py list --owner bot
    python tools/bot_opt.py --id opt-003       ->  python tools/task.py show opt-003
    python tools/bot_opt.py --status opt-003=done  ->  python tools/task.py done opt-003
Adding an item: python tools/task.py new opt-next --owner bot --title ... --done-when ... --resume ...
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import task


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Shim: forwards the old opt-queue flags to tools/task.py.", writes=True)
    ap.add_argument("--list", action="store_true", help="task.py list --owner bot")
    ap.add_argument("--id", default="", help="task.py show ID (opt-3 or 3 also work)")
    ap.add_argument("--status", default="", help="opt-N=done -> task.py done opt-N")
    args = ap.parse_args(argv)
    head = (["--root", args.root] if args.root else []) + (["--json"] if args.json else []) + (["--dry-run"] if args.dry_run else [])

    def oid(raw: str) -> str:
        n = raw.strip().lower().removeprefix("opt-")
        return f"opt-{int(n):03d}" if n.isdigit() else raw.strip()

    if args.id:
        return task.main(head + ["show", oid(args.id)])
    if args.status:
        tid, _, st = args.status.partition("=")
        if st.strip().lower() not in ("done", "dropped"):
            agent_log.fail("--status takes opt-N=done (an open item just stays open); use tools/task.py")
        return task.main(head + ["done", oid(tid)])
    if args.list:
        return task.main(head + ["list", "--owner", "bot"])
    agent_log.fail("this tool is a shim now: use python tools/task.py (list / show / new opt-next / done)")
    return 2


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
