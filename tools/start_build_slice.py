#!/usr/bin/env python3
"""First command of a Grok Build slice, run inside the slice worktree: resolve one routes.yaml door/job and print the start card (route, smokes, shot flows,
the first-message rules). A later run in the same worktree prints `SLICE ALREADY STARTED` with the steps found and the next one; `--full` reprints the card.
`GROK_SESSION_ID` is set in a session's tool environment; `grok sessions list` (current directory) and `/session-info` show it.

    python tools/start_build_slice.py --door dungeon | --job ui.pause | --area player [--full] [--ref REF] [--dry-run]
    python tools/start_build_slice.py --checkpoint [--session ID] [--ref REF]
    python tools/start_build_slice.py --handoff [--door D] [--job J] [--area A]      (survey session, after her answers to the first ask)
    python tools/start_build_slice.py --door D --from-handoff PATH                   (the fresh implementation session)
The first run writes _logs/slice-state.json (never committed) and a postcard _logs/slice-boot/<stamp>-slice-boot.txt. A door with several jobs and no
--job is a survey slice (text survey, ends in --handoff); a job is an implementation slice. Run in a main checkout it only says so: the User starts a
slice with `python tools/open_slice.py [AREA]`. A ui / theme / visual slice with no shot_flows for its job prints a STEP 0 note (creating the flow is the
first job step; exit 0). A job maps only to its own shot_flows key, never to the door's.
--checkpoint (implementation session, when gather is done): saves this session's id ($GROK_SESSION_ID, else --session ID) for this worktree
in the git common dir (retry_lib.save_gather; nothing is added to the tree). A red prove then prints `grok -r ID --fork-session` to
run from the worktree. Run in the main checkout, or with no id: RESULT FAIL. This tool never starts grok.
--handoff is for survey -> implement: it writes (first run) or validates (later runs) _logs/handoff/handoff.md, saves the survey's shot-flow / routes.yaml
edits next to it, and prints the one command she runs from the main checkout (`python tools/open_slice.py AREA --prompt-file PATH`). The fresh session's
first command, --from-handoff, prints the compact start summary and puts the saved edits back.
--selftest runs the cases below in a throwaway repo.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import handoff_lib
import repo_lib
import session_lib
import slice_lib
import slice_state
from load_routes import check_route, load_routes, shot_flows, smoke_phases


def not_carried(other: list[str]) -> str:
    """The 'changed here but not carried' line: files listed by name; Godot .import sidecars only counted."""
    files, n = handoff_lib.sidecars(other)
    if not files and not n:
        return "No other changes here."
    return ("Changed here but not carried (the fresh worktree is cut from the week branch and will not have them): " + (", ".join(files) or "no files")
            + (f"; plus {n} Godot .import sidecars (import churn, not carried)" if n else ""))


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
             not_carried(other),
             "THIS SESSION STOPS HERE; it does not implement. Tell the User to run, from the main checkout (not here):",
             handoff_lib.command(root, area, path),
             "(The file is the new session's first message. `--checkpoint` is different: it saves an implementation session for a red prove's retry fork.)"]
    return end("\n".join(lines), "PASS", "handoff-ready")


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Resolve a route and print the grok commands that open a Build slice (never starts grok).", writes=True)
    ap.add_argument("--door", default="", help="routes.yaml door to start from.")
    ap.add_argument("--job", default="", help="routes.yaml door.job to start from.")
    ap.add_argument("--area", default="", help="Slice name for the worktree slug (default: job, else door).")
    ap.add_argument("--ref", default="", help="Base ref for the retry diff and the merge-back line (default: the week branch grok-build-w{series}).")
    ap.add_argument("--full", action="store_true", help="Reprint the whole start card in a slice that already started (a later run prints where the slice stands).")
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
    kind = slice_lib.worktree_kind(root)
    wt = root.name
    st = slice_state.load(root) if kind else {}
    same = not st or not (args.door or args.job) or (st.get("door", ""), st.get("job", "")) == (args.door.strip(), args.job.strip())
    if st and same and not args.full and not args.dry_run:
        text = slice_state.short(root, st)
        return agent_log.finish("slice-boot", root, text, "PASS", args=args, write=True, echo=text, worktree=wt, route="already-started")
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
    if not kind:
        msg = ("MAIN CHECKOUT: no slice starts here. A slice is a Grok worktree; the User starts it with `python tools/open_slice.py [AREA]` from this checkout "
               "(it prints the grok command), and this tool is the first command inside that worktree.")
        return agent_log.finish("slice-boot", root, "\n".join([msg, ""] + route_lines), "FAIL" if route.startswith("exit") else "PASS", args=args, write=not args.dry_run, echo=msg,
                                worktree=wt, route="main-checkout")
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
    note = slice_lib.step0_note(args.door, args.job, args.area, flows, near)
    week = repo_lib.week_branch(root)
    ref = args.ref or week
    ref_note = "--ref given" if args.ref else f"week branch {week or 'none found'}"
    survey = slice_lib.is_survey(root, args.door, args.job, args.area, bool(args.from_handoff))
    mode = "handoff" if args.from_handoff else "survey" if survey else "implement"
    sdir = session_lib.session_dir()
    start = slice_lib.in_worktree_text(root, sdir, mode)
    hand = handoff_lib.start_block(root, Path(args.from_handoff)) if args.from_handoff else []
    warn = slice_lib.area_warning(root, args.area, args.door, args.job)
    if not args.dry_run:
        first = slice_state.new(root, args.door.strip(), args.job.strip(), args.area.strip(), mode, sdir)
        if st:
            first.update({k: st[k] for k in ("first_run", "session", "prompt") if k in st})
        slice_state.save(root, first)
    card = [f"door={args.door} job={args.job} area={args.area} ref={ref} ({ref_note}) worktree={wt} mode={mode}",
            f"smokes={smokes or 'n/a'} (run: tools/run_smokes.py --door/--job; add or update asserts for new systems)",
            f"flows={flows or 'none mapped to this job'} (pictures: tools/run_shot_flow.py --job J, one boot; UI states: tools/check_shot_gaps.py --changed)",
            "prove=every pass python tools/check_gd_load.py; visual: one unit, shot and shown (show_png.py) before and after, then ask with the paths in the message; gate: run_build_gate once (build-job-cycle.md)",
            slice_lib.merge_back_text(week or ref),
            "retry=a red prove prints `grok -r CHECKPOINT --fork-session` to run from the worktree, with the diff to read"]
    body = card + ([warn] if warn else []) + ["", start, ""] + (hand + [""] if hand else []) + ([note, ""] if note else []) + (["--- route ---"] + route_lines + [""] if route_lines else [])
    if route == "ok":
        head = "\n".join(l for l in route_lines if not l.startswith(("Summary", "RESULT")))
    elif route.startswith("exit"):
        head = "route failed:\n" + "\n".join(route_lines)
    else:
        head = f"smokes={smokes or 'n/a'} flows={flows or 'n/a'}" + ("" if smokes else " (--area has no route card; name a door/job for smokes)")
    echo = f"worktree={wt} ref={ref} ({ref_note}) mode={mode}\n{head}" + ("" if route.startswith("exit") else f"\n{start}\n{slice_lib.merge_back_text(week or ref)}" + (f"\n{note}" if note else "")) + (f"\n{warn}" if warn else "") + ("\n" + "\n".join(hand) if hand else "")
    return agent_log.finish("slice-boot", root, "\n".join(body), "FAIL" if route.startswith("exit") else "PASS",
                            args=args, write=not args.dry_run, echo=echo, worktree=wt, route=route)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
