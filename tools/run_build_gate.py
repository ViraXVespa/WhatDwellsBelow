#!/usr/bin/env python3
"""Grok Build post-slice gate: editor import check. One batch gate for a fix pass:

    python tools/run_build_gate.py [--skip-import] [--force]
    python tools/run_build_gate.py --batch --warnscan-baseline B.json [--areas p6,static]
    python tools/run_build_gate.py --batch --visual ui.pause     (the job's shot flows in the same call; look at the frames, then show_png.py)
--batch = import + restore `.import` churn + check_load_graph + the script-name check (duplicate
basenames) + check_hub_bake (png vs HUB_BAKE_STAMP) + `--warnscan-baseline` adds `bot_warnscan --non-leak-diff B` (same --areas as the baseline). Run it once
per batch. Refuses (exit 2) if Godot is already on this --path unless --force. Each run writes _logs/build-gate/<stamp>-build-gate.txt; read it with read_summary.py --job build-gate.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import bot_gate_lib
import godot_lib


def child(root: Path, script: str, job: str, *flags: str) -> tuple[int, list[str]]:
    p = subprocess.run([sys.executable, str(Path(__file__).resolve().parent / script), "--root", str(root), *flags],
                       cwd=root)
    s = agent_log.agent_summary_path(job, root)
    return p.returncode, (s.read_text(encoding="utf-8").splitlines() if s.is_file() else [])


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Post-slice gate: editor import check, load graph and script names.", json_out=True)
    bot_gate_lib.add_flag(ap)
    ap.add_argument("--import-timeout-sec", type=int, default=180, help="Editor import timeout in seconds (default 180).")
    ap.add_argument("--skip-import", action="store_true", help="Skip the editor import step.")
    ap.add_argument("--force", action="store_true", help="Continue even if Godot is on this path.")
    ap.add_argument("--script-cap", action="store_true", help=argparse.SUPPRESS)
    ap.add_argument("--batch", action="store_true", help="Import + restore .import churn + check_load_graph + script names (duplicate basenames).")
    ap.add_argument("--visual", default="", metavar="JOB", help="Also run the shot flows routes.yaml maps to JOB (door.job, or a door) in one call (run_shot_flow.py --job) and list the frames.")
    ap.add_argument("--warnscan-baseline", default="", help="Also run bot_warnscan --non-leak-diff against this --save-baseline file.")
    ap.add_argument("--areas", default="", help="bot_warnscan areas for --warnscan-baseline (must match the baseline run).")
    ap.add_argument("--shot-gaps", choices=("required", "advisory", "off"), default="",
                    help="check_shot_gaps --changed at the END of a slice: required FAILS on a new uncovered UI state (the flow must exist by now), advisory only prints. "
                         "Default: routes.yaml shot_gaps (bot=required with --batch, build=required otherwise).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if not args.force and not args.skip_import:
        pids = [p["pid"] for p in godot_lib.procs_on_path(root)]
        if pids:
            msg = f"Godot already on this --path (pids={','.join(map(str, pids))}). Pass --force to continue, or --skip-import."
            path = agent_log.write_summary("build-gate", root, msg, "FAIL", "busy=1")
            print(msg, file=sys.stderr)
            agent_log.emit_result("FAIL", agent_log.rel(root, path), busy=1)
            return 2
    bot = bot_gate_lib.enabled(args)
    bot_flag = ["--bot"] if args.bot else []
    body = [f"root=. skipImport={args.skip_import} force={args.force}", ""]
    fail = 0
    if bot and args.script_cap:
        print("== bot checks (changed scripts) ==")
        code, lines = child(root, "check_script_cap.py", "script-cap", *bot_flag, "--git-changed")
        body += [f"--- bot checks exit={code} ---"] + (lines or ["(missing summary)"]) + [""]
        fail += int(code != 0) + int(not lines)
    if not args.skip_import:
        print("== import check ==")
        code, lines = child(root, "run_godot_import_check.py", "godot-import-check", "--timeout-sec", str(args.import_timeout_sec))
        body += [f"--- import check exit={code} ---"] + (lines or ["(missing import summary)"]) + [""]
        fail += int(code != 0) + int(not lines)
    else:
        body += ["--- import skipped ---", ""]
    if not args.skip_import and (args.batch or args.warnscan_baseline):
        n, gone = godot_lib.restore_import_churn(root)
        body += [f"--- restored {n} .import files, removed {gone} stray ones ---", ""]
    if args.batch:
        print("== load graph ==")
        code, lines = child(root, "check_load_graph.py", "load-graph", *bot_flag)
        body += [f"--- load graph exit={code} ---"] + (lines or ["(missing load-graph summary)"]) + [""]
        fail += int(code != 0)
        if not (bot and args.script_cap):
            print("== script names ==")
            code, lines = child(root, "check_script_cap.py", "script-cap", *bot_flag)
            body += [f"--- script names exit={code} ---"] + (lines or ["(missing summary)"]) + [""]
            fail += int(code != 0)
        print("== hub bake stamp ==")
        code, lines = child(root, "check_hub_bake.py", "hub-bake")
        body += [f"--- hub bake stamp exit={code} ---"] + lines[-3:] + [""]
        fail += int(code != 0)
    if args.visual:
        print("== visual prove (%s) ==" % args.visual)
        p = subprocess.run([sys.executable, str(Path(__file__).resolve().parent / "run_shot_flow.py"), "--root", str(root), "--job", args.visual],
                           cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
        out = (p.stdout + p.stderr).strip().splitlines()
        print("\n".join(out))
        body += [f"--- visual {args.visual} exit={p.returncode} ---"] + out + [""]
        fail += int(p.returncode != 0)
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
    what = "run_build_gate.py" + (" --batch" if args.batch else "")
    return agent_log.finish("build-gate", root, "\n".join(body), "FAIL" if fail else "PASS", args=args, retry=(what, body), fail_signals=fail)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
