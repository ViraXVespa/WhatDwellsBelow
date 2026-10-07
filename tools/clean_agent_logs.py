#!/usr/bin/env python3
"""Housekeep _logs/ so runners do not clog the disk. Never touches files outside _logs/.

    python tools/clean_agent_logs.py [--keep-raw] [--max-age-hours 24] [--dry-run]
    python tools/clean_agent_logs.py --new-week     # human-only: wipes every run summary, index and raw log + scratch dirs
Default: delete raw *.log / *.err (run summaries and index.txt stay; each run keeps its own stamped files and the
newest 20 stay per folder, run_log_lib.py). Summary: _logs/clean/ (its own stamped run files).

"""
from __future__ import annotations

import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import run_log_lib


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Delete raw logs (and with --new-week old summaries) under _logs/.", writes=True, json_out=True)
    ap.add_argument("--keep-raw", action="store_true", help="Keep raw .log/.err files (summaries still follow --max-age-hours).")
    ap.add_argument("--max-age-hours", type=float, default=0, help="Only delete raw logs older than this many hours (default 0 = all).")
    ap.add_argument("--new-week", action="store_true", help="Also delete old summaries (start of a week).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    logs = root / "_logs"
    lines = [f"root=. keepRaw={args.keep_raw} maxAgeHours={args.max_age_hours:g} dryRun={args.dry_run} newWeek={args.new_week}", ""]
    st = {"deleted": 0, "kept": 0, "freed": 0}

    def size(p: Path) -> int:
        return sum(f.stat().st_size for f in p.rglob("*") if f.is_file()) if p.is_dir() else p.stat().st_size

    def remove(p: Path, kind: str) -> None:
        if not p.exists():
            return
        st["freed"] += size(p)
        lines.append(f"{kind} {agent_log.rel(root, p)}" + ("" if p.is_dir() else f" bytes={p.stat().st_size}"))
        if not args.dry_run:
            shutil.rmtree(p, ignore_errors=True) if p.is_dir() else p.unlink(missing_ok=True)
        st["deleted"] += 1

    if not logs.is_dir():
        lines.append("note=no_logs_dir")
    elif args.new_week:
        for d in ("sess", "patch-scratch"):
            remove(logs / d, "DELDIR")
        remove(logs / "patch-lock" / "apply.lock", "DEL")
        skip = ("sess", "patch-scratch", "patch-lock", "clean")
        for d in sorted(p for p in logs.rglob("*") if p.is_dir() and p.relative_to(logs).parts[0] not in skip):
            for f in sorted(f for f in d.iterdir() if f.is_file() and (run_log_lib.stamp_of(f.name) or f.name in (run_log_lib.INDEX, run_log_lib.LEGACY))):
                remove(f, "DEL")
        for f in sorted(p for p in logs.iterdir() if p.is_file()):
            remove(f, "DEL")
    else:
        cutoff = time.time() - args.max_age_hours * 3600 if args.max_age_hours > 0 else None
        for f in sorted(p for p in logs.rglob("*") if p.is_file()):
            raw = f.suffix in (".log", ".err")
            old = cutoff is not None and f.stat().st_mtime < cutoff
            keep_name = f.name.lower() in (run_log_lib.LEGACY, run_log_lib.INDEX) or (f.suffix == ".txt" and run_log_lib.stamp_of(f.name))
            if not keep_name and ((raw and not args.keep_raw) or old):
                remove(f, "DEL")
            else:
                st["kept"] += 1
        for d in sorted((p for p in logs.rglob("*") if p.is_dir()), key=lambda p: -len(str(p))):
            if not any(d.iterdir()):
                lines.append(f"RMDIR {agent_log.rel(root, d)}")
                if not args.dry_run:
                    d.rmdir()
    echo = f"deleted={st['deleted']} kept={st['kept']} bytes_freed={st['freed']}"
    return agent_log.finish("clean", root, "\n".join(lines), "INFO", args=args, echo=echo, deleted=st["deleted"],
                            kept=st["kept"], bytes_freed=st["freed"], new_week=str(args.new_week).lower())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
