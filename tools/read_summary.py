#!/usr/bin/env python3
"""Print a job's runs: the index first (newest run first), then the newest run's summary.

    python tools/read_summary.py --job build-gate          # index + newest summary
    python tools/read_summary.py --job build-gate --index  # the index only
    python tools/read_summary.py --job build-gate --run 2  # the 2nd newest run (1 = newest)
    python tools/read_summary.py --path _logs/smokes/<stamp>-p1-err.log
Every run keeps its own timestamped file under _logs/<job>/ and index.txt lists the last 20 (run_log_lib.py).
No --job/--path lists the job dirs found under _logs/. Exit 0 ok, 1 missing, 2 usage.

"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import run_log_lib


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Print a job's run index and newest summary, or a repo file.")
    ap.add_argument("job_pos", nargs="?", default="", help="Job name (same as --job).")
    ap.add_argument("--job", default="", help="Job name, e.g. smokes.")
    ap.add_argument("--path", default="", help="Repo-relative or absolute file to print.")
    ap.add_argument("--index", action="store_true", help="Print only the run index of the job.")
    ap.add_argument("--run", type=int, default=1, help="Which run's summary to print: 1 = newest (default), 2 = the one before.")
    args = ap.parse_args(argv)
    root, where = agent_log.cwd_scan_root(args)
    job = args.job or args.job_pos
    logs = root / "_logs"
    names = sorted(d.name for d in logs.iterdir() if d.is_dir() and run_log_lib.latest(d)) if logs.is_dir() else []
    print(where)
    if not job and not args.path:
        print("usage: python tools/read_summary.py --job <name>")
        print("jobs: " + (", ".join(names) or "(none yet)"))
        return 2
    if args.path:
        full = Path(args.path)
        full = full if full.is_absolute() else root / full
    else:
        d = agent_log.agent_log_dir(job, root)
        rows = run_log_lib.entries(d)
        if rows:
            print(f"index _logs/{job}/index.txt (newest first)")
            for i, (stamp, status, _file, note) in enumerate(rows, 1):
                print(f"  {i:2d} {stamp} {status} {note}".rstrip())
            if args.index:
                return 0
            if not 1 <= args.run <= len(rows):
                print(f"error: --run {args.run} is outside 1-{len(rows)}", file=sys.stderr)
                return 2
            full = d / rows[args.run - 1][2]
            print(f"--- run {args.run}: {agent_log.rel(root, full)} ---")
        else:
            full = run_log_lib.latest(d) or d / run_log_lib.LEGACY
    if not full.is_file():
        print(f"error: missing {agent_log.rel(root, full)}; jobs with a summary: {', '.join(names) or '(none yet)'}", file=sys.stderr)
        return 1
    sys.stdout.write(full.read_text(encoding="utf-8", errors="replace"))
    return 0


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
