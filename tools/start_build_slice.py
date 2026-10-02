#!/usr/bin/env python3
"""Slice boot for Grok Build: resolve one routes.yaml door/job, print the grok fork argv.

    python3 tools/start_build_slice.py --door dungeon | --job ui.pause | --area player [--ref main] [--launch] [--dry-run]
Writes a postcard to _logs/slice-boot/summary.txt and prints FORK/RETRY lines. Does not edit the live
tree or kill Godot; spawns grok only with --launch. Gather session id: --session or $GROK_SESSION_ID
(optional: without it the FORK/RETRY lines carry a <gather-session-id> placeholder, RESULT INFO, exit 0; the User fills it in). Old spellings: -Door -Job -Area -Ref -Launch -WhatIf.
"""
from __future__ import annotations

import datetime as dt
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
from load_routes import load_routes, shot_flows, smoke_phases


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Resolve a route and print the grok fork argv for a Build slice.", writes=True)
    ap.add_argument("--door", "-Door", default="", help="routes.yaml door to start from.")
    ap.add_argument("--job", "-Job", default="", help="routes.yaml door.job to start from.")
    ap.add_argument("--area", "-Area", default="", help="Slice name for the worktree slug (default: job, else door).")
    ap.add_argument("--ref", "-Ref", default="main", help="Git ref to branch from (default main).")
    ap.add_argument("--session", default="", help="Gather session id (default: $GROK_SESSION_ID).")
    ap.add_argument("--launch", "-Launch", action="store_true", help="Actually start grok with the fork argv.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    raw = (args.area or args.job or args.door).strip()
    if not raw:
        agent_log.fail("pass --door, --job, or --area")
    slug = re.sub(r"[^a-z0-9._-]+", "-", raw.lower()).strip("-")[:48].strip("-")
    if not slug:
        agent_log.fail("area slug is empty after sanitize")
    wt = f"wdb-{slug}-{dt.datetime.now():%Y%m%d-%H%M}"
    session = args.session or os.environ.get("GROK_SESSION_ID", "")
    session = session.strip() if re.fullmatch(r"[A-Za-z0-9._-]{1,128}", session.strip()) else ""
    route_lines, route = [], "skipped"
    if args.door or args.job:
        if args.dry_run:
            route, route_lines = "whatif", [f"list_route whatif door={args.door} job={args.job}"]
        else:
            cmd = [sys.executable, str(Path(__file__).resolve().parent / "list_route.py"), "--root", str(root)]
            cmd += (["--door", args.door] if args.door else []) + (["--job", args.job] if args.job else [])
            p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
            route = "ok" if p.returncode == 0 else f"exit={p.returncode}"
            route_lines = (p.stdout + p.stderr).splitlines()
    smokes = flows = ""
    if args.door or args.job:
        try:
            smokes = ",".join(map(str, smoke_phases(load_routes(root), door=args.door.strip(), job=args.job.strip())))
        except Exception:
            smokes = ""
        try:
            flows = ",".join(shot_flows(load_routes(root), door=args.door.strip(), job=args.job.strip()))
        except Exception:
            flows = ""
    resume = session or "<gather-session-id>"
    fork = f"grok --worktree={wt} --ref {args.ref} -r {resume} --fork-session"
    retry = f"grok -r {resume} --fork-session"
    launch = "skipped"
    if args.launch and not args.dry_run:
        grok = shutil.which("grok")
        if not session:
            launch = "blocked-no-session"
        elif not grok:
            launch = "blocked-no-grok"
        else:
            subprocess.Popen([grok, f"--worktree={wt}", "--ref", args.ref, "-r", session, "--fork-session"], cwd=root)
            launch = "started"
    body = [f"root=. door={args.door} job={args.job} area={args.area} slug={slug}", f"ref={args.ref} worktree={wt}",
            f"session={resume} session_ready={bool(session)} route={route}", f"dry_run={args.dry_run} launch={launch}",
            "boot=list_route (door resolve; not gather)",
            "gather=planned list_xref + planned show_func + one code_map row when a live script is in the slice",
            "outside_gather=list_changed (git inventory)", "change=worktree only; do not edit live checkout",
            "prove=one run_build_gate (import check) or one listed smoke set, or both once",
            f"smokes={smokes or 'n/a'} (run: tools/run_smokes.py --door/--job; add or update asserts for new systems)",
            f"flows={flows or 'n/a'} (headless: tools/bot_smokes.py --flows; pictures: tools/run_shot_flow.py --flow N; UI states: tools/check_shot_gaps.py --changed)",
            "return=you launch the fork argv; CLI does not auto-resume this pin", "", f"FORK {fork}", f"RETRY {retry}", ""]
    if route_lines:
        body += ["--- route ---"] + route_lines + [""]
    if route == "ok":
        head = "\n".join(l for l in route_lines if not l.startswith(("Summary", "RESULT")))
    elif route.startswith("exit"):
        head = "route failed:\n" + "\n".join(route_lines)
    else:
        head = f"smokes={smokes or 'n/a'} flows={flows or 'n/a'}" + ("" if smokes else " (--area has no route card; name a door/job for smokes)")
    tail = "" if route.startswith("exit") else f"\nFORK {fork}\nRETRY {retry}\nlaunch={launch}"
    code = agent_log.finish("slice-boot", root, "\n".join(body), "FAIL" if route.startswith("exit") else ("PASS" if session else "INFO"),
                            args=args, write=not args.dry_run, echo=f"worktree={wt}\n{head}{tail}",
                            worktree=wt, session_ready=bool(session), route=route, launch=launch)
    return code


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
