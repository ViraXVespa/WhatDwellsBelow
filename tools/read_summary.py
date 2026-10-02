#!/usr/bin/env python3
"""Print one job summary (_logs/<job>/summary.txt) or any repo file.

    python3 tools/read_summary.py --job build-gate
    python3 tools/read_summary.py --path _logs/smokes/p1-err.log
No --job/--path lists the job dirs found under _logs/. Exit 0 ok, 1 missing, 2 usage.
Old spellings: -Job -Path -Root.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Print a job summary or a repo file.")
    ap.add_argument("job_pos", nargs="?", default="", help="Job name (same as --job).")
    ap.add_argument("--job", "-Job", default="", help="Job name, e.g. smokes.")
    ap.add_argument("--path", "-Path", default="", help="Repo-relative or absolute file to print.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    job = args.job or args.job_pos
    if not job and not args.path:
        logs = root / "_logs"
        names = sorted(d.name for d in logs.iterdir() if (d / "summary.txt").is_file()) if logs.is_dir() else []
        print("usage: python3 tools/read_summary.py --job <name>")
        print("jobs: " + (", ".join(names) or "(none yet)"))
        return 2
    full = Path(args.path) if args.path else agent_log.agent_summary_path(job, root)
    if not full.is_absolute():
        full = root / full
    if not full.is_file():
        print(f"missing {agent_log.rel(root, full)}")
        return 1
    sys.stdout.write(full.read_text(encoding="utf-8", errors="replace"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
