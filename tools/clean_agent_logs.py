#!/usr/bin/env python3
"""Housekeep _logs/ so runners do not clog the disk. Never touches files outside _logs/.

    python3 tools/clean_agent_logs.py [--keep-raw] [--max-age-hours 24] [--dry-run]
    python3 tools/clean_agent_logs.py --new-week     # human-only: wipes old summaries + scratch dirs
Default: delete raw *.log / *.err (keep summary.txt). Summary: _logs/clean/summary.txt.
Old spellings: -KeepRaw -MaxAgeHours -WhatIf -NewWeek.
"""
from __future__ import annotations

import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Delete raw logs (and with --new-week old summaries) under _logs/.", writes=True, json_out=True)
    ap.add_argument("--keep-raw", "-KeepRaw", action="store_true")
    ap.add_argument("--max-age-hours", "-MaxAgeHours", type=float, default=0)
    ap.add_argument("--new-week", "-NewWeek", action="store_true")
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
        for d in sorted(p for p in logs.iterdir() if p.is_dir() and p.name not in ("sess", "patch-scratch", "patch-lock", "clean")):
            remove(d / "summary.txt", "DEL")
        for f in sorted(p for p in logs.iterdir() if p.is_file()):
            remove(f, "DEL")
    else:
        cutoff = time.time() - args.max_age_hours * 3600 if args.max_age_hours > 0 else None
        for f in sorted(p for p in logs.rglob("*") if p.is_file()):
            raw = f.suffix in (".log", ".err")
            old = cutoff is not None and f.stat().st_mtime < cutoff
            if f.name.lower() != "summary.txt" and ((raw and not args.keep_raw) or old):
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
    raise SystemExit(main())
