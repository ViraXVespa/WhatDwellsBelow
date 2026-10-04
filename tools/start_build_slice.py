#!/usr/bin/env python3
"""Slice boot for Grok Build: resolve one routes.yaml door/job, print the commands that open the slice worktree and a NEW session in it.
Flags checked against the Grok CLI docs (docs.x.ai/build/cli/reference, /build/features/worktrees, /build/features/sessions and
the grok-build user guide 17-sessions.md): `grok worktree create NAME --ref REF` makes the worktree and prints its path;
`grok --worktree=NAME --ref REF` does both in one step; `-r ID --fork-session` forks into a new id but keeps the directory of the
session it forks, and `--fork-session` cannot be combined with `--worktree`, so a session can never be moved into a worktree.
`GROK_SESSION_ID` is set in a session's tool environment; `grok sessions list` (current directory) and `/session-info` show it.

    python tools/start_build_slice.py --door dungeon | --job ui.pause | --area player [--ref REF] [--dry-run]
    python tools/start_build_slice.py --checkpoint [--session ID] [--ref REF]
    python tools/start_build_slice.py --handoff [--door D] [--job J] [--area A]      (survey session, after her answers to the first ask)
    python tools/start_build_slice.py --door D --from-handoff PATH                   (the fresh implementation session)
Boot (main checkout): writes a postcard (a new _logs/slice-boot/<stamp>-slice-boot.txt per run) and prints the START lines and the
job card. The main-checkout session then stops: no gather, no edits. The user runs START; the gather happens in the NEW session,
whose directory is the worktree. Worktrees come from the week branch grok-build-w{series} (series from scripts/data/version.json);
--ref overrides. No week branch and no --ref: RESULT FAIL, no START line, ask Vira whether to start a new week
(`python tools/week_start.py`). A ui / theme / visual slice with no shot_flows for its job prints a STEP 0 note (creating the flow is the first job step; exit 0). A job maps only to its own shot_flows key, never to the door's.
--checkpoint (worktree session, when gather is done): saves this session's id ($GROK_SESSION_ID, else --session ID) for this worktree
in the git common dir (retry_lib.save_gather; nothing is added to the tree). A red prove then prints `grok -r ID --fork-session` to
run from the worktree. Run in the main checkout, or with no id: RESULT FAIL. This tool never starts grok.
--checkpoint is for retries of an IMPLEMENTATION session (a red prove forks back to it). --handoff is for survey -> implement: it writes (first run) or validates
(later runs) _logs/handoff/handoff.md, saves the survey's shot-flow / routes.yaml edits next to it, and prints the one command she runs from the main checkout
(`python tools/open_slice.py AREA --prompt-file PATH`). The fresh session's first command, --from-handoff, prints the compact start summary and puts the saved edits back.
--selftest runs the cases below in a throwaway repo. Old spellings: -Door -Job -Area -Ref -WhatIf.
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
import handoff_lib
import repo_lib
import session_lib
import slice_lib
from load_routes import check_route, load_routes, shot_flows, smoke_phases


def write_handoff(root: Path, args) -> int:
    """--handoff: in the survey worktree, write the skeleton (first run) or validate the filled file, save the survey edits and print the launch command."""
    def end(msg: str, status: str, route: str) -> int:
        return agent_log.finish("slice-boot", root, msg, status, args=args, write=not args.dry_run, route=route)

    if not slice_lib.worktree_kind(root):
        return end("NOT A WORKTREE: --handoff belongs in the survey session's worktree (a Grok clone under .grok/worktrees). In a main checkout there is no survey to hand off.", "FAIL", "handoff-main")
    path = handoff_lib.handoff_path(root)
    old = handoff_lib.parse(path.read_text(encoding="utf-8-sig"))[0] if path.is_file() else {}
    door, job = args.door.strip() or old.get("door", ""), args.job.strip() or old.get("job", "")
    area = args.area.strip() or old.get("area", "") or job or door
    if not path.is_file():
        if not area:
            return end("pass --door D (or --job / --area) so the handoff names the area: " + (slice_lib.doors_hint(root) or "see design/routes.yaml"), "FAIL", "handoff-no-area")
        if not args.dry_run:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(handoff_lib.skeleton(root, area, door, job, os.environ.get("GROK_SESSION_ID", "")), encoding="utf-8")
        return end(f"HANDOFF skeleton written: {path}\nFill every <fill ...> line (write `none` where nothing applies; baselines are `absolute PNG path - what is on it`, only the chosen surface's), "
                   "then run `python tools/start_build_slice.py --handoff` again. The file is under _logs/, so it is not committed. After it passes this session stops; it does not implement.", "INFO", "handoff-skeleton")
    bad = handoff_lib.check(root, path.read_text(encoding="utf-8-sig"))
    if bad:
        return end("HANDOFF not ready (" + str(path) + "):\n- " + "\n- ".join(bad), "FAIL", "handoff-incomplete")
    saved, other = handoff_lib.save_edits(root) if not args.dry_run else ([], handoff_lib.survey_edits(root))
    lines = [f"HANDOFF ready: {path}",
             "Survey edits saved for the fresh session (it puts them back): " + (", ".join(saved) if saved else "none"),
             ("Changed here but not carried (the fresh worktree is cut from the week branch and will not have them): " + ", ".join(other)) if other else "No other changes here.",
             "THIS SESSION STOPS HERE; it does not implement. Tell the User to run, from the main checkout (not here):",
             handoff_lib.command(root, area, path),
             "(The file is the new session's first message. `--checkpoint` is different: it saves an implementation session for a red prove's retry fork.)"]
    return end("\n".join(lines), "PASS", "handoff-ready")


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Resolve a route and print the grok commands that open a Build slice (never starts grok).", writes=True)
    ap.add_argument("--door", "-Door", default="", help="routes.yaml door to start from.")
    ap.add_argument("--job", "-Job", default="", help="routes.yaml door.job to start from.")
    ap.add_argument("--area", "-Area", default="", help="Slice name for the worktree slug (default: job, else door).")
    ap.add_argument("--ref", "-Ref", default="", help="Git ref to branch from (default: the week branch grok-build-w{series}; none exists: the run fails).")
    ap.add_argument("--checkpoint", action="store_true", help="In the worktree session, after gather: save this session's id for a red prove's fork.")
    ap.add_argument("--session", default="", help="With --checkpoint: the session id (default: $GROK_SESSION_ID; else `grok sessions list` in this directory).")
    ap.add_argument("--handoff", action="store_true", help="Survey session, after her answers to the first ask: write the handoff skeleton, or validate the filled one and print the open_slice command.")
    ap.add_argument("--from-handoff", default="", metavar="PATH", help="Fresh implementation session: print the compact start summary from this handoff file.")
    ap.add_argument("--selftest", action="store_true", help="Run the boot / checkpoint / retry cases in a throwaway repo.")
    args = ap.parse_args(argv)
    if args.selftest:
        code = slice_lib.selftest(Path(__file__).resolve())
        extra = handoff_lib.selftest(Path(__file__).resolve())
        for b in extra:
            print("FAIL " + b)
        return code if not extra else agent_log.emit_result("FAIL", None, cmd="selftest", problems=len(extra))
    root = agent_log.resolve_root(args)
    if args.checkpoint:
        return slice_lib.checkpoint(root, args)
    if args.handoff:
        return write_handoff(root, args)
    raw = (args.area or args.job or args.door).strip()
    if not raw:
        agent_log.fail("pass --door D, --job door.job, or --area NAME (example: python tools/start_build_slice.py --door ui); after gather: --checkpoint. "
                       + (slice_lib.doors_hint(root) or "doors and jobs are in design/routes.yaml"))
    if args.door or args.job:
        bad_route = check_route(load_routes(root), args.door, args.job)
        if bad_route:
            agent_log.fail(bad_route)
    slug = re.sub(r"[^a-z0-9._-]+", "-", raw.lower()).strip("-")[:48].strip("-")
    if not slug:
        agent_log.fail("area slug is empty after sanitize")
    kind = slice_lib.worktree_kind(root)
    wt = root.name if kind else f"wdb-{slug}-{dt.datetime.now():%Y%m%d-%H%M}"
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
            flows = ",".join(shot_flows(load_routes(root), door=args.door.strip(), job=args.job.strip(), job_only=True))
        except Exception:
            flows = ""
    near = ""
    if args.job and not flows:
        try:
            near = ",".join(shot_flows(load_routes(root), door=args.job.split(".", 1)[0]))
        except Exception:
            near = ""
    note = slice_lib.step0_note(args.door, args.job, args.area, flows, near) if kind else ""
    week = repo_lib.week_branch(root)
    if not args.ref and not week:
        msg = ("NO WEEK BRANCH: no grok-build-w* branch exists, and no --ref was given. Nothing is started and no START line is printed (main is never the fallback). "
               "Ask Vira in a question prompt whether to start a new week; she runs `python tools/week_start.py`. Then rerun this command (or pass --ref REF if she names one).")
        return agent_log.finish("slice-boot", root, msg, "FAIL", args=args, write=not args.dry_run, worktree=wt, route="no-week-branch")
    ref = args.ref or week
    ref_note = "--ref given" if args.ref else f"week branch {week}"
    start = slice_lib.in_worktree_text(session_lib.session_dir(), handoff=bool(args.from_handoff)) if kind else slice_lib.start_text(wt, ref)
    hand = handoff_lib.start_block(root, Path(args.from_handoff)) if args.from_handoff and kind else []
    warn = slice_lib.area_warning(root, args.area, args.door, args.job)
    card = [f"door={args.door} job={args.job} area={args.area} ref={ref} ({ref_note}) worktree={wt}",
            f"smokes={smokes or 'n/a'} (run: tools/run_smokes.py --door/--job; add or update asserts for new systems)",
            f"flows={flows or 'none mapped to this job'} (headless: tools/bot_smokes.py --flows; pictures: tools/run_shot_flow.py --flow N; UI states: tools/check_shot_gaps.py --changed)",
            "gather=read what the route card below names (not sibling docs); list_xref (an index: --expand FILE) / show_func / code_map row for the code; visual work follows the first-message text below",
            "prove=every pass python tools/check_gd_load.py; visual: one unit, open before and after, stop and ask with the PNG paths in the message; gate: run_build_gate once (build-job-cycle.md)",
            slice_lib.merge_back_text(kind or "linked", week or ref),
            "retry=a red prove prints `grok -r CHECKPOINT --fork-session` to run from the worktree, with the diff to read"]
    body = card + ([warn] if warn else []) + ["", start, ""] + (hand + [""] if hand else []) + ([note, ""] if note else []) + (["--- route ---"] + route_lines + [""] if route_lines else [])
    if route == "ok":
        head = "\n".join(l for l in route_lines if not l.startswith(("Summary", "RESULT")))
    elif route.startswith("exit"):
        head = "route failed:\n" + "\n".join(route_lines)
    else:
        head = f"smokes={smokes or 'n/a'} flows={flows or 'n/a'}" + ("" if smokes else " (--area has no route card; name a door/job for smokes)")
    merge = slice_lib.merge_back_text(kind, week or ref) if kind else ""
    echo = f"worktree={wt} ref={ref} ({ref_note})\n{head}" + ("" if route.startswith("exit") else f"\n{start}" + (f"\n{merge}" if merge else "") + (f"\n{note}" if note else "")) + (f"\n{warn}" if warn else "") + ("\n" + "\n".join(hand) if hand else "")
    return agent_log.finish("slice-boot", root, "\n".join(body), "FAIL" if route.startswith("exit") else "PASS",
                            args=args, write=not args.dry_run, echo=echo, worktree=wt, route=route)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
