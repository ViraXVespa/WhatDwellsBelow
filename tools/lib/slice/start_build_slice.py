#!/usr/bin/env python3
"""First command of a Grok Build slice, run inside the slice worktree: resolve one routes.yaml door/job and print the start card (route, smokes, shot flows,
the first-message rules). A later run in the same worktree prints `SLICE ALREADY STARTED` with the steps found and the next one; `--full` reprints the card.
`GROK_SESSION_ID` is set in a session's tool environment; `grok sessions list` (current directory) and `/session-info` show it.

    python tools/slice.py start --door dungeon | --job ui.pause | --area player [--full] [--ref REF] [--dry-run]
    python tools/slice.py start --unit-done                                    (unit queue, at Complete: mark this unit done; a task file keeps the queue)
    python tools/slice.py start --failed                                       (the Did not work lines for your next message, from this session's failed tool results)
    python tools/slice.py start --handoff [--task ID] [--door D] [--job J] [--area A]   (survey session, after her answers to the first ask)
    python tools/slice.py start --door D --from-handoff PATH                   (the fresh implementation session)
    python tools/slice.py start --door D --from-task ID                        (resume a committed task, design/tasks/ID.md)
The first run writes _logs/slice-state.json (never committed) and a postcard _logs/slice-boot/<stamp>-slice-boot.txt. A door with several jobs and no
--job is a survey slice (text survey, ends in --handoff); a job is an implementation slice. Run in a main checkout it only says so: the User starts a
slice with `python tools/slice.py open [AREA]`. A ui / theme / visual slice with no shot_flows for its job prints a STEP 0 note (creating the flow is the
first job step; exit 0). A job maps only to its own shot_flows key, never to the door's.
The first run also records this session's id ($GROK_SESSION_ID): the original session, the reset point after the User's `/fork` at the end of
Gather. A red prove prints `grok -r <original-session-id> --fork-session` from it (retry_lib). This tool never starts grok.
--handoff is for survey -> implement: it writes (first run) or validates (later runs) the task file design/tasks/ID.md (ID: --task, else the door),
saves it and the survey's shot-flow / routes.yaml edits to _logs/handoff/survey-edits, and prints the one command she runs from the main checkout (`python tools/slice.py open AREA --prompt-file PATH`). The fresh session's
first command, --from-handoff, prints the compact start summary, puts the saved edits back and points the task's first command at --from-task
(a later session the User opens with the task's `resume:` line, `slice.py open AREA --task ID`, starts there).
--selftest runs the cases below in a throwaway repo.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import handoff_lib
import repo_lib
import session_lib
import slice_lib
import slice_state
import task_lib
import unit_lib
from load_routes import check_route, job_flow_map, load_routes, shot_flows, smoke_phases

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
    path = handoff_lib.handoff_path(root, args.task.strip())
    old = handoff_lib.parse(path.read_text(encoding="utf-8-sig"))[0] if path.is_file() else {}
    st = slice_state.load(root)
    door, job = args.door.strip() or old.get("door", "") or st.get("door", ""), args.job.strip() or old.get("job", "") or st.get("job", "")
    area = args.area.strip() or old.get("area", "") or st.get("area", "") or job or door
    if not path.is_file():
        if not area:
            return end("no slice state found here: pass --door D (or --job / --area) so the handoff names the area: " + (slice_lib.doors_hint(root) or "see design/routes.yaml"), "FAIL", "handoff-no-area")
        if not args.dry_run:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(handoff_lib.skeleton(root, area, door, "" if st.get("units") else job, os.environ.get("GROK_SESSION_ID", ""), st.get("units"), st.get("done"), path.stem), encoding="utf-8")
            task_lib.write_index(root)
        return end(f"HANDOFF skeleton written: {path}\nFill every <fill ...> line (write `none` where nothing applies; baselines are `absolute PNG path - what is on it`, only the chosen surface's), "
                   "then run `python tools/slice.py start --handoff` again. It is a task file (design/tasks/README.md); the fresh session commits it with its first unit. After it passes this session stops; it does not implement.", "INFO", "handoff-skeleton")
    bad = handoff_lib.check(root, path.read_text(encoding="utf-8-sig"))
    if bad:
        return end("HANDOFF not ready (" + str(path) + "):\n- " + "\n- ".join(bad), "FAIL", "handoff-incomplete")
    saved, other = handoff_lib.save_edits(root) if not args.dry_run else ([], handoff_lib.survey_edits(root))
    lines = [f"HANDOFF ready: {path}",
             "Survey edits saved for the fresh session (it puts them back): " + (", ".join(saved) if saved else "none"),
             not_carried(other),
             "THIS SESSION STOPS HERE; it does not implement. Tell the User to run, from the main checkout (not here):",
             handoff_lib.command(root, area, path),
             "(The file is the new session's first message.)"]
    return end("\n".join(lines), "PASS", "handoff-ready")

def unit_state_note(job: str, units: list[str]) -> str:
    """' state NAME' for a unit that is one shot of a shared flow, else ''."""
    if not units or job not in units:
        return ""
    state = unit_lib.job_state(load_routes(Path(__file__).resolve().parents[3]), job)
    return f" state {state}" if state else ""

def queue_task(root: Path, st: dict, done: list[str]) -> str:
    """Units remain and the slice has no task file: write design/tasks/<door>-units.md (queue + done) and refresh the README index. Returns its path."""
    door = st.get("door", "") or "slice"
    tid = f"{door}-units"
    tp = task_lib.task_path(root, tid)
    if not tp.is_file():
        units = ", ".join(st.get("units") or [])
        body = (f"area: {st.get('area') or door}\ndoor: {door}\nunits: {units}\ndone: {', '.join(done) or 'none'}\n\n"
                "## Notes\nWritten by `slice.py start --unit-done`, so a new session can resume the queue if the rest does not fit one session.")
        text = task_lib.skeleton(tid, "build", f"{door} unit queue", "every unit in `units:` is done", handoff_lib.launch_cmd(door, tid), [], "")
        text = text.replace("\n\n## Notes\nnone yet", "\n" + body)
        tp.parent.mkdir(parents=True, exist_ok=True)
        tp.write_text(text, encoding="utf-8")
        task_lib.write_index(root)
    else:
        task_lib.set_head(tp, "done", ", ".join(done) or "none")
    st["task"] = tid
    slice_state.save(root, st)
    return f"{task_lib.TASKS_REL}/{tid}.md"

def task_units(root: Path, args, st: dict) -> tuple[list[str], list[str], str]:
    """--task ID (not --handoff): the task's own `units:` header (plain labels, no dots) is this slice's queue. Done: the slice state, else the task's `done:`."""
    tid = args.task.strip()
    if not tid or args.handoff or args.from_task:
        return [], [], ""
    t = task_lib.load(root).get(tid)
    if t is None:
        agent_log.fail(f"no task {tid}; open tasks: `python tools/docs.py task list`")
    units = task_lib.split(t.get("units", ""))
    if not units or any("." in u for u in units):
        return [], [], ""
    done = list(st.get("done") or []) if st.get("task_units") and st.get("task") == tid else [d for d in task_lib.split(t.get("done", "")) if d != "none"]
    return units, done, unit_lib.pick(units, done)

def unit_done(root: Path, args) -> int:
    """--unit-done (Complete, before slice.py commit): mark the slice's current unit done in the slice state and the task's done: line. Nothing moves on."""
    st = slice_state.load(root)
    if not st.get("units"):
        agent_log.fail("no unit queue in this slice. Start one with `--door D` (a door with unit_queue in routes.yaml) or `--task ID` (a task whose header lists `units:`).")
    done = list(st.get("done") or [])
    if st.get("unit") and st["unit"] not in done:
        done.append(st["unit"])
    nxt = unit_lib.pick(st["units"], done)
    cur = st.get("unit", "?")
    st.update({"done": done, "unit": nxt or st.get("unit", "")})
    if not st.get("task_units"):
        st["job"] = nxt or st.get("job", "")
    if not args.dry_run:
        slice_state.save(root, st)
    tp = task_lib.task_path(root, st["task"]) if st.get("task") else None
    made = ""
    if tp and tp.is_file() and not args.dry_run:
        task_lib.set_head(tp, "done", ", ".join(done) or "none")
    elif nxt and not args.dry_run:
        made = queue_task(root, st, done)
    msg = (f"UNIT DONE: {cur}; done: {', '.join(done)}. " + (f"Next unit: {nxt}. If the request still fits this session, Complete this unit (commit, push) and continue: `python tools/slice.py start {('--job ' + st['job']) if st.get('task_units') and st.get('job') else '--door ' + st.get('door', 'D')} --full` prints its card{(' (with --task ' + st['task'] + ')') if st.get('task_units') else ''}. If it cannot fit, stop after Complete; a new session resumes the queue. " if nxt else "All units are done" + (f": close the task in this commit (`python tools/docs.py task done {st['task']}`). " if st.get("task") else ". "))
           + (f"Queue recorded in the task file {made} (commit it with this unit); if the rest does not fit, the User opens a new session with its `resume:` line (never run or print it). " if made else "")
           + "Complete this unit now: slice.py commit, then plain push. The done notice follows the last unit this session does.")
    return agent_log.finish("slice-boot", root, msg, "PASS", args=args, write=not args.dry_run, echo=msg, route="unit-done")

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Resolve a route and print the grok commands that open a Build slice (never starts grok).", writes=True)
    ap.add_argument("--door", default="", help="routes.yaml door to start from.")
    ap.add_argument("--job", default="", help="routes.yaml door.job to start from.")
    ap.add_argument("--area", default="", help="Slice name for the worktree slug (default: job, else door).")
    ap.add_argument("--ref", default="", help="Base ref for the retry diff (recorded on the first run) and the merge-back line (default: the week branch grok-build-w{series}).")
    ap.add_argument("--full", action="store_true", help="Reprint the whole start card in a slice that already started (a later run prints where the slice stands).")
    ap.add_argument("--failed", action="store_true", help="Print the `Did not work:` lines built from this session's failed tool results since your last ask.")
    ap.add_argument("--handoff", action="store_true", help="Survey session, after her answers to the first ask: write the handoff skeleton, or validate the filled one and print the open_slice command.")
    ap.add_argument("--unit-done", dest="unit_done", action="store_true", help="Unit queue, at Complete (before slice.py commit): mark the current unit done; the queue is kept in a task file for a later session.")
    ap.add_argument("--from-handoff", default="", metavar="PATH", help="Fresh implementation session: print the compact start summary from this handoff file.")
    ap.add_argument("--from-task", dest="from_task", default="", metavar="ID", help="Resume a committed Build task: the summary from design/tasks/ID.md (no survey edits restored).")
    ap.add_argument("--task", default="", metavar="ID", help="The task this slice works (open_slice puts it in the first command): a `units:` header of plain labels is the slice's unit queue (--unit-done). With --handoff: the task id (default: the slice's task, else its door).")
    ap.add_argument("--selftest", action="store_true", help="Run the boot / unit / retry cases in a throwaway repo.")
    args = ap.parse_args(argv)
    if args.selftest:
        code = slice_lib.selftest(boot.cmd("start_build_slice"))
        extra = handoff_lib.selftest(boot.cmd("start_build_slice"))
        for b in extra:
            print("FAIL " + b)
        return code if not extra else agent_log.emit_result("FAIL", None, cmd="selftest", problems=len(extra))
    root = agent_log.resolve_root(args)
    if args.failed:
        print(session_lib.failed_block())
        return agent_log.emit_result("PASS", cmd="failed")
    if args.unit_done:
        return unit_done(root, args)
    if args.handoff:
        return write_handoff(root, args)
    if args.from_task:
        tp = task_lib.task_path(root, args.from_task.strip())
        if not tp.is_file():
            agent_log.fail(f"no task file {task_lib.TASKS_REL}/{args.from_task.strip()}.md; open tasks: `python tools/docs.py task list --owner build`")
        args.from_handoff = str(tp)
    raw = (args.area or args.job or args.door).strip()
    if not raw:
        agent_log.fail("pass --door D, --job door.job, or --area NAME (example: python tools/slice.py start --door ui). "
                       + (slice_lib.doors_hint(root) or "doors and jobs are in design/routes.yaml"))
    if args.door or args.job:
        bad_route = check_route(load_routes(root), args.door, args.job)
        if bad_route:
            agent_log.fail(bad_route)
    kind = slice_lib.worktree_kind(root)
    wt = root.name
    st = slice_state.load(root) if kind else {}
    units: list[str] = []
    done: list[str] = []
    if kind and args.door.strip() and not args.job.strip() and not args.area.strip() and unit_lib.queue(load_routes(root), args.door.strip()):
        qt = task_lib.task_path(root, f"{args.door.strip()}-units")
        if not st and not args.from_handoff and qt.is_file():  # a queue --unit-done recorded: resume it, not unit 1
            args.from_task, args.from_handoff = qt.stem, str(qt)
        try:
            head = handoff_lib.parse(Path(args.from_handoff).read_text(encoding="utf-8-sig"))[0] if args.from_handoff else {}
        except OSError:
            head = {}
        units, done = unit_lib.plan(load_routes(root), args.door.strip(), st, head)
        args.job = unit_lib.pick(units, done)
        if not args.job:
            msg = f"ALL UNITS DONE for door {args.door}: {', '.join(units)}. Nothing is queued. Finished: `python tools/docs.py task done ID` in the last unit's commit; more to hand on: `python tools/slice.py start --handoff`."
            return agent_log.finish("slice-boot", root, msg, "PASS", args=args, write=not args.dry_run, echo=msg, worktree=wt, route="units-done")
    tunits, tdone, tcur = task_units(root, args, st)
    if tunits and not tcur:
        msg = f"ALL TASK UNITS DONE for {args.task}: {', '.join(tunits)}. Close it in this commit: `python tools/docs.py task done {args.task}`."
        return agent_log.finish("slice-boot", root, msg, "PASS", args=args, write=not args.dry_run, echo=msg, worktree=wt, route="units-done")
    same = not st or not (args.door or args.job) or (st.get("door", ""), st.get("job", "")) == (args.door.strip(), args.job.strip())
    if st and same and not args.full and not args.dry_run:
        text = slice_state.short(root, st)
        return agent_log.finish("slice-boot", root, text, "PASS", args=args, write=True, echo=text, worktree=wt, route="already-started")
    route_lines, route = [], "skipped"
    if args.door or args.job:
        if args.dry_run:
            route, route_lines = "whatif", [f"list_route whatif door={args.door} job={args.job}"]
        else:
            cmd = [*boot.cmd("list_route"), "--root", str(root)]
            cmd += (["--door", args.door] if args.door else []) + (["--job", args.job] if args.job else [])
            cmd += (["--units", ",".join(units), "--done", ",".join(done)] if units else [])
            p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
            route = "ok" if p.returncode == 0 else f"exit={p.returncode}"
            route_lines = (p.stdout + p.stderr).splitlines()
    if not kind:
        msg = ("MAIN CHECKOUT: no slice starts here. A slice is a Grok worktree; the User starts it with `python tools/slice.py open [AREA]` from this checkout "
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
    per_job = ""
    if args.door and not args.job:
        try:
            per_job = job_flow_map(load_routes(root), args.door.strip())
        except Exception:
            per_job = ""
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
    screen = bool(flows) or bool(note)
    start = slice_lib.in_worktree_text(root, sdir, mode, screen)
    hand = handoff_lib.start_block(root, Path(args.from_handoff), bool(units), restore=not args.from_task) if args.from_handoff else []
    tfile = Path(args.from_handoff) if args.from_handoff else None
    tid = tfile.stem if tfile and tfile.parent.name == "tasks" else ""
    warn = slice_lib.area_warning(root, args.area, args.door, args.job)
    if not args.dry_run:
        first = slice_state.new(root, args.door.strip(), args.job.strip(), args.area.strip(), mode, sdir, units, done, args.ref)
        if st:
            first.update({k: st[k] for k in ("first_run", "session", "ref", "prompt", "task") if k in st})
        if tunits:
            first.update({"units": tunits, "done": tdone, "unit": tcur, "task": args.task.strip(), "task_units": True})
        if tid:
            first["task"] = tid
            local = task_lib.task_path(root, tid)
            if local.is_file() and task_lib.set_head(local, "first", handoff_lib.from_task_cmd(args.door.strip(), tid, args.job.strip())):
                hand.append(f"task {task_lib.TASKS_REL}/{tid}.md: its first command now reads --from-task {tid}; commit it with this unit")
            if local.is_file():
                task_lib.ensure_head(local, "resume", handoff_lib.launch_cmd(args.door.strip(), tid, args.job.strip()))
        slice_state.save(root, first)
    card = [f"door={args.door} job={args.job} area={args.area} ref={ref} ({ref_note}) worktree={wt} mode={mode}",
            f"smokes={smokes or 'n/a'} (run: tools/gate.py smokes --door/--job; add or update asserts for new systems)",
            f"flows={('per job: ' + per_job) if per_job else (flows or 'none mapped to this job')}{unit_state_note(args.job, units)} (pictures: tools/shots.py flow --job J, one boot; UI states: tools/shots.py gaps --changed)",
            "cycle=Gather (no code, no new tools; outcome + signal; then she runs /fork) > Prepare > Change (gate.py gd-load once the edits are complete) > Prove (final verification: compile check, the job's shot flows + UI load check if visual, run_build_gate --batch; one small corrective edit, one rerun) > Complete (docs, task, commit, push, done notice); build-job-cycle.md",
            slice_lib.merge_back_text(week or ref)]
    if tunits:
        unit_line = (f"unit={tcur} ({tunits.index(tcur) + 1} of {len(tunits)}, task {args.task.strip()}); done: {', '.join(tdone) or 'none'}. "
                     "Work this unit only; at Complete, before slice.py commit: `python tools/slice.py start --unit-done`.")
        card.append(unit_line)
        hand.append(unit_line)
    body = card + ([warn] if warn else []) + ["", start, ""] + (hand + [""] if hand else []) + ([note, ""] if note else []) + (["--- route ---"] + route_lines + [""] if route_lines else [])
    if route == "ok":
        head = "\n".join(l for l in route_lines if not l.startswith(("Summary", "RESULT")))
    elif route.startswith("exit"):
        head = "route failed:\n" + "\n".join(route_lines)
    else:
        head = f"smokes={smokes or 'n/a'} flows={('per job: ' + per_job) if per_job else (flows or 'n/a')}" + ("" if smokes else " (--area has no route card; name a door/job for smokes)")
    echo = f"worktree={wt} ref={ref} ({ref_note}) mode={mode}\n{head}" + ("" if route.startswith("exit") else f"\n{start}\n{slice_lib.merge_back_text(week or ref)}" + (f"\n{note}" if note else "")) + (f"\n{warn}" if warn else "") + ("\n" + "\n".join(hand) if hand else "")
    return agent_log.finish("slice-boot", root, "\n".join(body), "FAIL" if route.startswith("exit") else "PASS",
                            args=args, write=not args.dry_run, echo=echo, worktree=wt, route=route)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
