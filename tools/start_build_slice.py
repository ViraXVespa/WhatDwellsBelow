#!/usr/bin/env python3
"""Slice boot for Grok Build: resolve one routes.yaml door/job, print the grok commands that open the slice worktree.
Flags checked against the Grok CLI docs (docs.x.ai/build/cli/reference, /build/features/worktrees, /build/features/sessions and
the grok-build user guide 14-headless-mode.md, 17-sessions.md): `grok worktree create NAME --ref REF` makes the worktree without a
session and prints its path (the only stdout); `grok --cwd PATH -r ID --fork-session` forks a session into a new id there;
`--worktree` with `-r` resumes into a NEW worktree and cannot be combined with --fork-session, so it is used only for a fresh
session. REF = clean checkout of that branch/tag/commit. A worktree is DETACHED at its base commit: commit there, merge back.

    python tools/start_build_slice.py --door dungeon | --job ui.pause | --area player [--ref REF] [--launch] [--dry-run]
Writes a postcard (a new _logs/slice-boot/<stamp>-slice-boot.txt per run) and prints the FORK and RETRY lines.
Worktrees come from the week branch grok-build-w{series} (series from scripts/data/version.json); --ref overrides.
No week branch and no --ref: RESULT FAIL, no FORK line, and the message says to ask Vira (a question prompt) whether
to start a new week (`python tools/week_start.py`). Does not edit the live tree or kill Godot; spawns grok only with
--launch. Gather session id: --session or $GROK_SESSION_ID. It is saved (retry_lib.save_gather, in the git common
dir) so a red prove can fork it back into the worktree: the gather session is the point retries return to. Without
one the FORK line starts a fresh session (--worktree=NAME), WARN says so, and a retry says there is no gather session.
--launch runs `grok worktree create`, saves the printed path (the retry matches on it), then starts the fork.
--selftest runs the cases below in a throwaway repo. Old spellings: -Door -Job -Area -Ref -Launch -WhatIf.
"""
from __future__ import annotations

import datetime as dt
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import repo_lib
import retry_lib
import slice_lib
from load_routes import check_route, load_routes, shot_flows, smoke_phases


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Resolve a route and print the grok fork argv for a Build slice.", writes=True)
    ap.add_argument("--door", "-Door", default="", help="routes.yaml door to start from.")
    ap.add_argument("--job", "-Job", default="", help="routes.yaml door.job to start from.")
    ap.add_argument("--area", "-Area", default="", help="Slice name for the worktree slug (default: job, else door).")
    ap.add_argument("--ref", "-Ref", default="", help="Git ref to branch from (default: the week branch grok-build-w{series}; none exists: the run fails).")
    ap.add_argument("--session", default="", help="Gather session id (default: $GROK_SESSION_ID); saved so a red prove can fork it into the worktree.")
    ap.add_argument("--launch", "-Launch", action="store_true", help="Actually start grok with the fork argv.")
    ap.add_argument("--selftest", action="store_true", help="Run the week-branch / FORK / saved-session cases in a throwaway repo.")
    args = ap.parse_args(argv)
    if args.selftest:
        return slice_lib.selftest(Path(__file__).resolve())
    root = agent_log.resolve_root(args)
    raw = (args.area or args.job or args.door).strip()
    if not raw:
        agent_log.fail("pass --door, --job, or --area")
    if args.door or args.job:
        bad_route = check_route(load_routes(root), args.door, args.job)
        if bad_route:
            agent_log.fail(bad_route)
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
    week = repo_lib.week_branch(root)
    if not args.ref and not week:
        msg = ("NO WEEK BRANCH: no grok-build-w* branch exists, and no --ref was given. Nothing is started and no FORK line is printed (main is never the fallback). "
               "Ask Vira in a question prompt whether to start a new week; she runs `python tools/week_start.py`. Then rerun this command (or pass --ref REF if she names one).")
        return agent_log.finish("slice-boot", root, msg, "FAIL", args=args, write=not args.dry_run, worktree=wt, session_ready=bool(session), route="no-week-branch")
    ref = args.ref or week
    ref_note = "--ref given" if args.ref else f"week branch {week}"
    fork, note = slice_lib.fork_text(wt, ref, session)
    warn = note if session else ("WARN no gather session id: this FORK starts a fresh session in the worktree, without your gather context, and a red prove will have no gather session to fork from. "
                               "Pass --session ID or set $GROK_SESSION_ID to fork from the gather session.")
    launch, path = "skipped", ""
    if args.launch and not args.dry_run:
        launch, path = slice_lib.launch(root, wt, ref, session)
    saved = "" if args.dry_run else retry_lib.save_gather(root, wt, session, args.ref, path)
    retry = ("RETRY a red prove prints a fork of the saved gather session into this worktree "
             f"(`grok --cwd <worktree path> -r {session} --fork-session`, with the diff `git diff {args.ref or week}...HEAD`)." if session else
             f"RETRY no gather session: a red prove will say there is none to fork from and start nothing; ask Vira for the session id.")
    body = [f"root=. door={args.door} job={args.job} area={args.area} slug={slug}", f"ref={ref} ({ref_note}) worktree={wt}",
            f"session={session or 'none'} session_ready={bool(session)} route={route}", f"dry_run={args.dry_run} launch={launch}",
            "boot=list_route (door resolve; not gather)",
            "read-first=more than one system: list every system the job touches, read each one's doc and code-map row, then change",
            "gather=list_xref / show_func / code_map row for what the job needs; list_changed --history compares docs and code",
            "change=worktree only; this session does not cd. Stop after the FORK lines. Edits belong to the grok process started with --cwd <worktree path>",
            "prove=run_build_gate (import check) and/or the listed smoke set; gates once per batch (tools.md rule 10)",
            f"smokes={smokes or 'n/a'} (run: tools/run_smokes.py --door/--job; add or update asserts for new systems)",
            f"flows={flows or 'n/a'} (headless: tools/bot_smokes.py --flows; pictures: tools/run_shot_flow.py --flow N; UI states: tools/check_shot_gaps.py --changed)",
            f"merge-back=on a green prove: commit in the worktree (its HEAD is detached, there is no branch), then in the checkout that holds {week or 'grok-build-w{N}'} (git worktree list): git merge --no-ff <worktree HEAD sha> (never main); balance, audio, visuals, controls: ask_user_question for playtest approval first",
            "revert=a retry forks the saved gather session into the worktree; git history holds the code", f"gather-session-saved={saved or 'no'}",
            "return=you run the FORK line(s); the CLI does not start it for you", "",
            fork, *([warn] if warn else []), retry, ""]
    if route_lines:
        body += ["--- route ---"] + route_lines + [""]
    if route == "ok":
        head = "\n".join(l for l in route_lines if not l.startswith(("Summary", "RESULT")))
    elif route.startswith("exit"):
        head = "route failed:\n" + "\n".join(route_lines)
    else:
        head = f"smokes={smokes or 'n/a'} flows={flows or 'n/a'}" + ("" if smokes else " (--area has no route card; name a door/job for smokes)")
    tail = "" if route.startswith("exit") else f"\n{fork}" + (f"\n{warn}" if warn else "") + f"\n{retry}\nlaunch={launch}"
    code = agent_log.finish("slice-boot", root, "\n".join(body), "FAIL" if route.startswith("exit") else ("PASS" if session else "INFO"),
                            args=args, write=not args.dry_run, echo=f"worktree={wt} ref={ref} ({ref_note})\n{head}{tail}",
                            worktree=wt, session_ready=bool(session), route=route, launch=launch)
    return code


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
