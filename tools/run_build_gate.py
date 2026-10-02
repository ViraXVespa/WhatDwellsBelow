#!/usr/bin/env python3
"""Grok Build post-slice gate: editor import check; script cap is opt-in.

    python3 tools/run_build_gate.py [--skip-import] [--force] [--script-cap --over-kb 10]
Refuses (exit 2) if Godot is already on this --path unless --force. Old spellings:
-SkipImport -Force -ScriptCap -OverKb -ImportTimeoutSec. Summary: _logs/build-gate/summary.txt
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def child(root: Path, script: str, job: str, *flags: str) -> tuple[int, list[str]]:
    p = subprocess.run([sys.executable, str(Path(__file__).resolve().parent / script), "--root", str(root), *flags],
                       cwd=root)
    s = agent_log.agent_summary_path(job, root)
    return p.returncode, (s.read_text(encoding="utf-8").splitlines() if s.is_file() else [])


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Post-slice gate: import check (+ optional script cap).", json_out=True)
    ap.add_argument("--over-kb", "-OverKb", type=float, default=10)
    ap.add_argument("--import-timeout-sec", "-ImportTimeoutSec", type=int, default=180)
    ap.add_argument("--skip-import", "-SkipImport", action="store_true")
    ap.add_argument("--force", "-Force", action="store_true", help="Continue even if Godot is on this path.")
    ap.add_argument("--script-cap", "-ScriptCap", action="store_true", help="Also run check_script_cap --git-changed.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if not args.force and not args.skip_import:
        pids = [p["pid"] for p in godot_lib.procs_on_path(root)]
        if pids:
            msg = f"Godot already on this --path (pids={','.join(map(str, pids))}). Pass --force to continue, or --skip-import."
            agent_log.write_summary("build-gate", root, msg)
            print(msg, file=sys.stderr)
            agent_log.emit_result("FAIL", "_logs/build-gate/summary.txt", busy=1)
            return 2
    body = [f"root=. overKb={args.over_kb} skipImport={args.skip_import} force={args.force} scriptCap={args.script_cap}", ""]
    fail = 0
    if args.script_cap:
        print("== script cap (git changed) ==")
        code, lines = child(root, "check_script_cap.py", "script-cap", "--over-kb", str(args.over_kb), "--git-changed")
        body += [f"--- script cap exit={code} ---"] + (lines or ["(missing script-cap summary)"]) + [""]
        fail += int(code != 0) + int(not lines)
    else:
        body += ["--- script cap skipped ---", ""]
    if not args.skip_import:
        print("== import check ==")
        code, lines = child(root, "run_godot_import_check.py", "godot-import-check", "--timeout-sec", str(args.import_timeout_sec))
        body += [f"--- import check exit={code} ---"] + (lines or ["(missing import summary)"]) + [""]
        fail += int(code != 0) + int(not lines)
    else:
        body += ["--- import skipped ---", ""]
    return agent_log.finish("build-gate", root, "\n".join(body), "FAIL" if fail else "PASS", args=args, fail_signals=fail)


if __name__ == "__main__":
    raise SystemExit(main())
