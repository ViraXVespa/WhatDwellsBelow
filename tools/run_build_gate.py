#!/usr/bin/env python3
"""Grok Build post-slice gate: editor import check; script cap is opt-in. One batch gate for a fix pass:

    python3 tools/run_build_gate.py [--skip-import] [--force] [--script-cap --over-kb 10]
    python3 tools/run_build_gate.py --batch --warnscan-baseline B.json [--areas p6,static]
--batch = import + restore `.import` churn under assets/ + check_load_graph + check_script_cap (whole tree, with dupes) +
`--warnscan-baseline` adds `bot_warnscan --non-leak-diff B` (same --areas as the baseline). Run it once per batch.
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
    ap.add_argument("--batch", action="store_true", help="Import + restore assets/*.import churn + check_load_graph + whole-tree check_script_cap.")
    ap.add_argument("--warnscan-baseline", default="", help="Also run bot_warnscan --non-leak-diff against this --save-baseline file.")
    ap.add_argument("--areas", default="", help="bot_warnscan areas for --warnscan-baseline (must match the baseline run).")
    ap.add_argument("--shot-gaps", choices=("required", "advisory", "off"), default="",
                    help="check_shot_gaps --changed: required FAILS on a new uncovered UI state, advisory only prints. "
                         "Default: routes.yaml shot_gaps (bot=required with --batch, build=advisory otherwise).")
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
    if not args.skip_import and (args.batch or args.warnscan_baseline):
        ch = subprocess.run(["git", "status", "--porcelain", "--", "assets"], cwd=root, capture_output=True, text=True).stdout.splitlines()
        imp = [ln[3:].strip() for ln in ch if ln[:2].strip() == "M" and ln.rstrip().endswith(".import")]
        if imp:
            subprocess.run(["git", "checkout", "--", *imp], cwd=root)
        body += [f"--- restored {len(imp)} assets/*.import files ---", ""]
    if args.batch:
        print("== load graph ==")
        code, lines = child(root, "check_load_graph.py", "load-graph")
        body += [f"--- load graph exit={code} ---"] + (lines or ["(missing load-graph summary)"]) + [""]
        fail += int(code != 0)
        if not args.script_cap:
            print("== script cap (whole tree) ==")
            code, lines = child(root, "check_script_cap.py", "script-cap", "--over-kb", str(args.over_kb))
            body += [f"--- script cap exit={code} ---"] + (lines or ["(missing script-cap summary)"]) + [""]
            fail += int(code != 0)
    if args.warnscan_baseline:
        print("== warnscan non-leak diff ==")
        flags = ["--non-leak-diff", args.warnscan_baseline] + (["--areas", args.areas] if args.areas else [])
        code, lines = child(root, "bot_warnscan.py", "warnscan", *flags)
        body += [f"--- warnscan diff exit={code} (see its console RESULT line) ---", ""]
        fail += int(code != 0)
    sg = args.shot_gaps
    if not sg:
        from load_routes import load_routes, shot_gaps_mode
        sg = shot_gaps_mode(load_routes(root), "bot" if args.batch else "build")
    if sg != "off":
        print("== shot gaps (%s) ==" % sg)
        code, lines = child(root, "check_shot_gaps.py", "shot-gaps", "--changed", *(["--advisory"] if sg == "advisory" else []))
        body += [f"--- shot gaps {sg} exit={code} ---"] + lines[-6:] + [""]
        fail += int(code != 0 and sg == "required")
    return agent_log.finish("build-gate", root, "\n".join(body), "FAIL" if fail else "PASS", args=args, fail_signals=fail)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
