#!/usr/bin/env python3
"""Post-split gate: import check, then optional smokes. One summary.

    python3 tools/run_post_split_gate.py [--with-smokes [--phases 1,2,6]] [--force]
Refuses (exit 2) if any Godot is running unless --force (it never kills it). Old spellings:
-WithSmokes -Phases -ImportTimeoutSec -SmokeTimeoutSec -Force. Summary: _logs/post-split-gate/summary.txt
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib
from run_build_gate import child


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Import check, then optional phase smokes.", json_out=True)
    ap.add_argument("--with-smokes", "-WithSmokes", action="store_true")
    ap.add_argument("--phases", "-Phases", nargs="+", default=["1,2,3,4,5,6,7,8,9"])
    ap.add_argument("--import-timeout-sec", "-ImportTimeoutSec", type=int, default=180)
    ap.add_argument("--smoke-timeout-sec", "-SmokeTimeoutSec", type=int, default=120)
    ap.add_argument("--force", "-Force", action="store_true")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    pids = [p["pid"] for p in godot_lib.procs_on_path(root)]
    if pids and not args.force:
        msg = f"Godot already running on this path (pids={','.join(map(str, pids))}). Pass --force to continue, or wait."
        agent_log.write_summary("post-split-gate", root, msg)
        print(msg, file=sys.stderr)
        agent_log.emit_result("FAIL", "_logs/post-split-gate/summary.txt", busy=1)
        return 2
    body = [f"root=. withSmokes={args.with_smokes} force={args.force}", ""]
    fail = 0
    print("== import check ==")
    code, lines = child(root, "run_godot_import_check.py", "godot-import-check", "--timeout-sec", str(args.import_timeout_sec))
    body += [f"--- import check exit={code} ---"] + (lines or ["(missing import summary)"]) + [""]
    fail += int(code != 0) + int(not lines)
    if args.with_smokes:
        print("== smokes ==")
        phases = [str(n) for n in agent_log.split_list(args.phases, int)]
        code, lines = child(root, "run_smokes.py", "smokes", "--timeout-sec", str(args.smoke_timeout_sec), "--phases", *phases)
        body += [f"--- smokes exit={code} ---"] + (lines or ["(missing smoke summary)"]) + [""]
        fail += int(code != 0) + int(not lines)
    else:
        body += ["--- smokes skipped (pass --with-smokes to run) ---", ""]
    return agent_log.finish("post-split-gate", root, "\n".join(body), "FAIL" if fail else "PASS", args=args, fail_signals=fail)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
