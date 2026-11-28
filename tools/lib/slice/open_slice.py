#!/usr/bin/env python3
"""Open a Build slice: the USER runs this (PowerShell on Windows). It starts grok in a NEW worktree cut from the week branch.

    python tools/slice.py open [AREA_OR_NAME] [--task ID] [--prompt TEXT | --prompt-file PATH] [--ref REF | --in WT] [--no-gather | --review | --seed-only] [--dry-run]
    python tools/slice.py open --launch WT [--review]    (main session in a gathered worktree, after --review or a hand gather)
It prints the prompt it passes as one info line (length, first 60 characters, sha256) and logs it. --prompt-file reads a file as is; --prompt takes text. A prompt that starts `# Handoff:` is a survey handoff (slice.py start --handoff): it must be filled in, and the line `handoff:` summarizes it.
Finds the repo from this file's location and the week branch grok-build-w{N} (none and no --ref: fails). The worktree name is
generated (wdb-<area or slice>-<YYYYMMDD-HHMM>). It prints, then runs from the repo root with a plain args list (no shell):
    grok worktree create NAME --ref WEEKBRANCH
    grok --cwd PATH --trust [PROMPT]
handing the terminal over (inherited stdio; the exit code of grok on Windows, os.execvp elsewhere). PROMPT is optional: with none
the session starts blank. The prompt is read by this tool and passed as one argument. It never uses --fork-session, -p,
--prompt-file or --max-turns (those make single-turn headless runs). If grok is not on PATH, or the launch fails, the command
is printed to copy and the exit code is 1. `--trust` is on the session whose cwd is the new folder: `grok --worktree --trust`
records trust for the source checkout, and the new session then loads no Agents.md, project skills, or hooks.
With AREA (a routes.yaml door, door.job, or a free name) the area is resolved first; a visual slice with no shot_flows prints a STEP 0
note (creating the flow is the first job step, not a stop) and the launch continues. Without AREA there are no checks: Build runs
slice.py start inside the worktree.
--task ID reads design/tasks/ID.md (AREA defaults to its `resume:` line): with no prompt given it writes a short first message (`slice.py start --job|--door AREA --task ID`, or `--door D --from-task ID` for a handoff, then `docs.py task show ID`; read that file whole).
`_src` is in the repo, so the worktree already has it. `needs-local` is retired: a task that still sets it fails loudly and nothing is linked.
`addons/` is gitignored (the Godot AI plugin from the Asset Library). After the worktree exists, this tool junctions
`worktree/addons` to this checkout's `addons/` so the new checkout loads the same install. A copy is only the fallback when
that junction cannot be created. Remove worktrees with `grok worktree rm` or `git worktree remove` (those drop the junction
and leave the checkout install). Do not recursively delete the worktree folder in PowerShell 5.1.
Gather (an AREA or --task that resolves to a routes.yaml door or job, and no handoff prompt): after the worktree exists, open runs
`slice.py start` there for the main session (pre-assigned id, `grok -s SID`), then `slice.py gather-pick --chain` (local Ollama
role sessions). A pick sets `gather: agent` and the packet inlines those func bodies (tools/data/gather/packet-refined.md). A chain
that chooses nothing, or invalid JSON on mark, leaves the mechanical seed (packet-seed.md) and the launch still happens. A scout
page that returns no final answer is skipped. While it runs, it prints
each step as it starts (`open: ...`). --no-gather turns that off: no start, no chain, no session-context.md, and the main session
gets the pre-gather command (it runs slice.py start itself). --review stops after the packet; --launch WT then starts the main
session there (--launch WT --review: check and packet only). --review never starts grok. An area that is not a door or job fails before any grok command. A halt file or a failed expand check refuses the launch. --seed-only
stops after start and the seed (no chain, packet, or launch) for a gather done by hand; --in WT uses an existing slice worktree
instead of creating one (it may be run from inside that worktree; the worktree's own branch is the ref).
This is the only tool that launches grok for a Build slice. The isolated-media runner is the other launcher, under its own gate.
--selftest: dry-run cases in a throwaway repo; no grok is ever started.
"""
from __future__ import annotations

import contextlib
import datetime as dt
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import gather_agent
import handoff_lib
import repo_lib
import slice_lib
import task_lib

BANNED = ("--fork-session", "--max-turns", "--prompt-file", "-p")

def show(argv: list[str]) -> str:
    import shlex

    return subprocess.list2cmdline(argv) if os.name == "nt" else shlex.join(argv)

def create_argv(grok: str, name: str, ref: str) -> list[str]:
    return [grok, "worktree", "create", name, "--ref", ref]

def session_argv(grok: str, wt: str, prompt: str, sid: str = "") -> list[str]:
    """Trust this folder. `grok --worktree --trust` trusts the source checkout, not the new one. sid: the id open pre-assigned."""
    return [grok, "--cwd", wt, "--trust"] + (["-s", sid] if sid else []) + ([prompt] if prompt else [])

def launch(exe: str, cmd: list[str], wt: Path, review: bool = False) -> int:
    if review:
        gather_agent.live("open: review, not launching\n")
        return 0
    sys.stdout.flush()
    cmd = gather_agent.runnable(cmd)
    exe = cmd[0]
    try:
        if os.name == "nt":
            return subprocess.call(cmd, cwd=wt)
        os.chdir(wt)
        os.execvp(exe, cmd)
    except OSError as exc:
        print(f"error: launch failed ({exc}). Copy and run: {show(cmd)}", file=sys.stderr)
        return 1
    return 0

def gathered_launch(root: Path, wt: Path, exe: str | None, end, lines: list[str], review: bool, extra: str = "") -> int:
    """After start + gather in wt: halt check, open's own validation, packet, then the main session (`-s SID`)."""
    meta = gather_agent.meta(wt)
    if not meta:
        return end(f"NOT GATHERED: {wt} has no _logs/gather/open.json (run `python tools/slice.py open AREA` first).", "FAIL", route="not-gathered")
    halt = gather_agent.halted(wt)
    if halt:
        gather_agent.live("open: halted, not launching\n")
        return end("\n".join(lines + [gather_agent.report(wt), f"HALT: {halt}. Not launched. Fix the cause, or delete {wt / gather_agent.GATHER / 'halt'}, then: python tools/slice.py open --launch {wt}"]), "FAIL", route="halt")
    ok, bad = gather_agent.finish(wt, bool(meta.get("agent_warn")))
    if ok and not meta.get("agent_ok") and gather_agent.gathered(wt):
        gather_agent.set_meta(wt, agent_ok=True)  # a gather outside open (seed-only, then adjust as the gather role)
    if not ok:
        return end("\n".join(lines + [gather_agent.report(wt)] + bad), "FAIL", route="invalid")
    notes = [meta["agent_warn"]] if meta.get("agent_warn") else []
    lines = lines + [gather_agent.report(wt)] + [n for n in notes if n not in lines]
    refined = bool(meta.get("agent_ok")) or gather_agent.gathered(wt)
    cmd = session_argv(exe or "grok", str(wt), gather_agent.first_message(meta["start"], meta.get("task", ""), notes, extra or meta.get("extra", ""), refined), meta["sid"])
    if review:
        gather_agent.live("open: review, not launching\n")
        return end("\n".join(lines + [f"review: stopped before the main session. Launch: python tools/slice.py open --launch {wt}"]), "PASS", route="review")
    if not exe:
        return end("\n".join(lines + [f"GROK NOT FOUND on PATH. Run: {show(cmd)}"]), "FAIL", route="no-grok")
    gather_agent.live("open: starting main session\n")
    end("\n".join(lines + [f"SESSION: {show(cmd)}", "Starting grok now (this terminal is handed over)."]), "PASS", route="launch")
    return launch(exe, cmd, wt, review)

def _reparse(path: Path) -> bool:
    """True for a symlink or a Windows directory junction. os.path.islink does not see junctions."""
    if path.is_symlink():
        return True
    if os.name != "nt" or not os.path.lexists(path):
        return False
    import ctypes

    get_attrs = ctypes.windll.kernel32.GetFileAttributesW
    get_attrs.argtypes = [ctypes.c_wchar_p]
    get_attrs.restype = ctypes.c_uint32
    attrs = get_attrs(str(path))
    return attrs != 0xFFFFFFFF and bool(attrs & 0x400)

def link_addons(src: Path, wt: Path) -> str:
    """Point wt/addons at src/addons. Junction on Windows, symlink elsewhere. Copy only if that cannot be created."""
    src_addons = src / "addons"
    dest = wt / "addons"
    if not src_addons.is_dir():
        return ("ADDONS MISSING: this checkout has no addons/ (godot_ai is a local Asset Library install and is gitignored). "
                "The worktree will not load the Godot AI plugin.")
    if os.path.lexists(dest):
        if _reparse(dest):
            return "addons: worktree addons/ already points at an install; left it."
        return "ADDONS PRESENT: worktree addons/ is a real directory; left it in place."
    warn = "" if (src_addons / "godot_ai" / "plugin.cfg").is_file() else " WARN: addons/godot_ai/plugin.cfg is not in the checkout install."
    err = "junction failed"
    if os.name == "nt":
        proc = subprocess.run(["cmd", "/c", "mklink", "/J", str(dest), str(src_addons)],
                              capture_output=True, text=True, encoding="utf-8", errors="replace")
        if proc.returncode == 0 and dest.exists():
            return "addons: junction worktree/addons -> checkout addons/ (shared gitignored install)." + warn
        tail = (proc.stderr or proc.stdout or err).strip().splitlines()
        err = (tail[-1] if tail else err)[:180]
    else:
        try:
            dest.symlink_to(src_addons, target_is_directory=True)
            return "addons: symlink worktree/addons -> checkout addons/ (shared gitignored install)." + warn
        except OSError as exc:
            err = str(exc)[:180]
    try:
        shutil.copytree(src_addons, dest)
    except OSError as exc:
        return f"ADDONS FAILED: could not junction or copy addons/ ({err}; copy {exc})."
    return f"ADDONS COPIED: junction was not created ({err}). This copy will not follow later edits in the checkout addons/."

def prepare(wt: Path, flows: str, run=subprocess.run) -> list[str]:
    """In a new or reused worktree, before any edit: the Godot setup (addon + import; a fresh worktree fails Godot checks
    without it), then the before shots of the slice's flows (prove names them; no scratch worktree later). Never fatal."""
    if os.environ.get("WDB_OPEN_NO_PREPARE") == "1":  # the selftest's real (non-dry) opens: no Godot download, no shots
        gather_agent.live("open: prepare skipped\n")
        return ["prepare: skipped (WDB_OPEN_NO_PREPARE=1)"]
    py, out = gather_agent.py(), []

    def say(line: str) -> None:
        out.append(line)
        gather_agent.live(f"open: {line}\n")

    for label, argv, fix in (("setup", [py, "tools/gate.py", "bot-smokes", "--setup"], "python tools/gate.py bot-smokes --setup"),
                             ("before shots", [py, "tools/shots.py", "flow", "--flow", flows, "--before"],
                              f"python tools/shots.py flow --flow {flows} --before (before the first edit)")):
        if label == "before shots" and not flows:
            say("before shots: none (no shot flow mapped to this slice)")
            continue
        if label == "before shots":
            st = run(["git", "status", "--porcelain", "-uno"], cwd=wt, capture_output=True, text=True, encoding="utf-8", errors="replace")
            edited = [ln[3:] for ln in (st.stdout or "").splitlines() if len(ln) > 3 and not ln[3:].startswith("_logs/")]
            if (wt / "_logs/before-shots/before.json").is_file() or edited:
                why = "kept: _logs/before-shots/before.json exists" if not edited else f"skipped: {len(edited)} tracked path(s) already edited, so they would not be before shots"
                say(f"before shots: {why}")
                continue
        gather_agent.live(f"open: {label}\n")
        try:
            p = run(argv, cwd=wt, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900)
            code, text = p.returncode, (p.stdout or "") + (p.stderr or "")
        except (OSError, subprocess.TimeoutExpired) as exc:
            code, text = 1, str(exc)
        res = next((ln for ln in reversed(text.splitlines()) if ln.startswith("RESULT ")), text.strip().splitlines()[-1:] or ["no output"])
        res = res if isinstance(res, str) else res[0]
        say(f"{label}: {res[:160]}" if code == 0 else f"{label.upper()} FAILED (exit {code}): {res[:160]}. In the worktree run: {fix}")
    return out

ADDONS_NOTE = ("addons: after create, junction worktree/addons to this checkout's addons/ "
               "(gitignored godot_ai install; copy only if the junction cannot be created).")

def start_prompt(area: str) -> str:
    """Pre-gather first message for a door or job: this session runs slice.py start itself."""
    start = f"python tools/slice.py start {task_lib.start_flag(area)} {area}"
    return ("Your first command, before any file read or memory topic: " + start + ". "
            "The start command writes session-plan.md. Close that seed before editing: "
            "walk the edit, fix the index with slice.py adjust, and write the Approach with slice.py adjust approach. "
            "Do not look up as you go. Write Outcome, Open questions, Changed files and Latest results above the marker as facts land.")


def task_prompt(tid: str, path: str, area: str, t: dict | None = None) -> str:
    """First message for --task: a committed handoff (it has `from:`) restarts with --from-task; any other task with --task."""
    t = t or {}
    if t.get("from") and t.get("door"):
        start = handoff_lib.from_task_cmd(t["door"], tid, t.get("job", "")) + f", then python tools/docs.py task show {tid}"
    else:
        start = f"python tools/slice.py start {task_lib.start_flag(area)} {area} --task {tid}, then python tools/docs.py task show {tid}"
    return (f"Task {tid} ({path}). Your first command, before any file read or memory topic: {start}; read that task file whole. "
            "The start command writes session-plan.md. Close that seed before editing: "
            "walk the edit, fix the index with slice.py adjust, and write the Approach with slice.py adjust approach. "
            "Do not look up as you go. Write Outcome, Open questions, Changed files and Latest results above the marker as facts land.")

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Start grok in a new worktree from the week branch (user-run launcher).", writes=True)
    ap.add_argument("area", nargs="?", default="", help="routes.yaml door, door.job, or a free slice name (runs the slice-boot checks).")
    ap.add_argument("--prompt", default="", help="First message for the new session (optional).")
    ap.add_argument("--prompt-file", default="", help="Read the first message from this file (this tool reads it; grok gets it as one argument).")
    ap.add_argument("--ref", default="", help="Git ref to base the worktree on (default: the week branch grok-build-w{N}).")
    ap.add_argument("--task", default="", metavar="ID", help="A design/tasks task. With no prompt, a short first message names it. needs-local is retired and fails.")
    ap.add_argument("--no-gather", dest="no_gather", action="store_true", help="Turn gathering off. No start, chain, or session-context; the main session runs slice.py start itself.")
    ap.add_argument("--review", action="store_true", help="Stop after the packet and print the report; launch later with --launch WT.")
    ap.add_argument("--launch", default="", metavar="WT", help="Start the main session in an already-gathered worktree (after --review). With --review: validate, write session-context.md and print the report only.")
    ap.add_argument("--in", dest="in_wt", default="", metavar="WT", help="Use this existing slice worktree (a linked git worktree or Grok clone) instead of creating one; may be run from inside it.")
    ap.add_argument("--seed-only", dest="seed_only", action="store_true", help="Stop after start and the mechanical seed: no local chain, no packet, no launch. Then `slice.py adjust`, and `open --launch WT --review` (or --launch WT).")
    ap.add_argument("--selftest", action="store_true", help="Run dry-run cases in a throwaway repo; never starts grok.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest(boot.cmd("open_slice"))
    root = agent_log.resolve_root(args)
    dry = args.dry_run

    def end(msg: str, status: str, **kv: object) -> int:
        return agent_log.finish("open-slice", root, msg, status, args=args, write=not dry, **kv)

    if args.launch:
        return gathered_launch(root, Path(args.launch).resolve(), gather_agent.grok_exe(), end, [f"launch: {args.launch}"], args.review, args.prompt)
    into = Path(args.in_wt).resolve() if args.in_wt else None
    if into and not (into.is_dir() and slice_lib.is_linked(into)):
        return end(f"NOT A SLICE WORKTREE: --in {args.in_wt} is not a linked git worktree or Grok clone.", "FAIL", route="bad-in")
    if slice_lib.is_linked(root) and not into:
        return end(f"IN A WORKTREE: {root} is already a worktree (a Grok clone under .grok/worktrees, or a linked git worktree). Run `python tools/slice.py open` from the main checkout.", "FAIL", route="in-worktree")
    ref = args.ref or (repo_lib.current_branch(into) or "HEAD" if into else repo_lib.week_branch(root))
    if not ref:
        return end("NO WEEK BRANCH: no grok-build-w* branch exists and no --ref was given, so nothing is started (main is never the fallback). "
                   "A new week starts in a Build session in the repo root told it is a new week (design/build-week-start.md); or pass --ref REF.", "FAIL", route="no-week-branch")
    area = args.area.strip()
    note = door = job = flows = ""
    if area:
        door, job, flows, note = slice_lib.slice_check(root, area)
    prompt = args.prompt
    if args.prompt_file:
        try:
            prompt = Path(args.prompt_file).read_text(encoding="utf-8-sig")
        except OSError as exc:
            return end(f"CANNOT READ --prompt-file: {exc}", "FAIL", route="bad-prompt")
    prompt = prompt.strip()
    if args.task:
        t = task_lib.load(root).get(args.task.strip())
        if not t:
            return end(f"NO TASK {args.task}: open tasks are `python tools/docs.py task list`.", "FAIL", route="no-task")
        if task_lib.split(t.get("needs-local", "")):
            return end("DO NOT LINK: needs-local is retired. _src is in the repo, so a worktree already has it. Remove needs-local from the task and rerun.", "FAIL", route="no-link")
        if not area:
            area = task_lib.resume_area(t)
            if not area:
                return end(f"NO AREA for task {args.task}: its `resume:` line names no door or door.job (`python tools/docs.py task check`).", "FAIL", route="no-area")
            door, job, flows, note = slice_lib.slice_check(root, area)
    if args.no_gather and (args.seed_only or args.review):
        return end("--no-gather turns gathering off, so it cannot be combined with --review or --seed-only.", "FAIL", route="bad-no-gather")
    gather = bool(door or job) and not prompt.startswith("# Handoff:") and not args.no_gather
    if args.seed_only and not gather:
        return end("SEED-ONLY NEEDS A DOOR OR JOB: pass AREA (door or door.job) or a --task that resolves to one.", "FAIL", route="bad-seed-only")
    if args.review and not gather:
        return end("--review does not start the main session. This open has no door or job, so there is no packet to review. "
                   "Pass a door, a door.job, or a --task whose resume: line names one.", "FAIL", route="bad-review")
    if args.task:
        if not gather:
            prompt = prompt or task_prompt(args.task.strip(), t["path"], area, t)
        if subprocess.run(["git", "cat-file", "-e", f"{ref}:{t['path']}"], cwd=root, capture_output=True).returncode != 0:
            note = (note + "\n" if note else "") + f"WARN: {t['path']} is not on {ref}, so the new worktree will not have it. Merge main into {ref} first, or pass --ref."
    if not gather and area and not prompt:
        prompt = start_prompt(area)
    hand_note = ""
    if prompt.startswith("# Handoff:"):
        bad = handoff_lib.check(root, prompt)
        if bad:
            return end("HANDOFF NOT READY (" + (args.prompt_file or "--prompt") + "):\n- " + "\n- ".join(bad) + "\nFinish it in the survey session (`python tools/slice.py start --handoff`), then rerun this.", "FAIL", route="bad-handoff")
        head, secs = handoff_lib.parse(prompt)
        n = len(handoff_lib.baselines(root, secs.get("Baselines for the chosen surface", "")))
        hand_note = f"handoff: survey done, area={head.get('area', '')}, {n} baseline(s) to open, first unit = {(secs.get('Chosen surfaces, in order', '').splitlines() or [''])[0].strip()!r}"
        if head.get("units"):
            us = [u.strip() for u in head["units"].split(",") if u.strip()]
            dn = [u.strip() for u in head.get("done", "").split(",") if u.strip() and u.strip() != "none"]
            hand_note += f"; unit queue {len(us)} (done {len(dn)}), next = {next((u for u in us if u not in dn), 'none')}; finish what fits, --unit-done after each unit"
    if prompt.startswith("-") or len(prompt) > 30000:
        return end("BAD PROMPT: it must not start with '-' (grok would read a flag) and must fit on a command line. Shorten it or start blank.", "FAIL", route="bad-prompt")
    slug = re.sub(r"[^a-z0-9._-]+", "-", (area or "slice").lower()).strip("-")[:48].strip("-") or "slice"
    name = f"wdb-{slug}-{dt.datetime.now():%Y%m%d-%H%M}"
    exe = gather_agent.grok_exe()
    g = exe or "grok"
    create = create_argv(g, name, ref)
    tid = args.task.strip()
    if gather:
        import uuid

        sid = str(uuid.uuid4())
        sargv = gather_agent.start_cmd(area, door, job, tid, t if args.task else None)
        extra, prompt = prompt, gather_agent.first_message(sargv, tid, [], prompt, False)
        session = session_argv(g, "PATH", prompt, sid)
        steps = [show(create), "(in PATH) " + show(sargv)]
        if not args.seed_only:
            steps += ["(in PATH) slice.py gather-pick --chain", "(in PATH) slice.py expand --check; expand --out session-context.md", show(session)]
    else:
        session = session_argv(g, "PATH", prompt)
        steps = [show(create), show(session)]
    if into:
        steps[0], name = f"(existing worktree {into}; nothing created)", into.name
        steps = [st.replace("PATH", str(into)) for st in steps]
    numbered = "  ".join(f"{i}) {step}" for i, step in enumerate(steps, 1))
    lines = [f"repo={root} ref={ref} worktree={name}", f"COMMANDS (run from the repo root): {numbered}"]
    import hashlib

    warn = slice_lib.area_warning(root, area) if area else ""
    lines.append(f"prompt: {len(prompt)} chars, starts {prompt[:60]!r}, sha256 {hashlib.sha256(prompt.encode('utf-8')).hexdigest()[:12]}" if prompt else "prompt: none (a blank session)")
    lines += [hand_note] if hand_note else []
    if gather and not args.seed_only:
        note = ("--review stops before the main session either way." if args.review else
                "A pick uses the refined first message; a miss keeps this seed message and still launches.")
        lines.append(f"gather: gather-pick --chain runs after start. {note}")
    lines.append(ADDONS_NOTE)
    lines.append(f"prepare: in the worktree, before any edit: gate.py bot-smokes --setup" + (f", then shots.py flow --flow {flows} --before" if flows else "") + ".")
    lines.append((f"area={area}: resolved." + (f"\n{warn}" if warn else "") + (f"\n{note}" if note else "")) if area else
                 "No area given, so no route checks ran. In the new session Build runs `python tools/slice.py start --door <door>` (the card; a later run says where the slice stands).")
    if dry:
        return end("\n".join(lines + ["dry run: grok was not started."]), "PASS", route="dry-run")
    needs_grok = not into or not args.seed_only
    if not exe and needs_grok:
        return end("\n".join(lines + ["GROK NOT FOUND on PATH. Run the COMMANDS above yourself from the repo root."]), "FAIL", route="no-grok")
    if into:
        gather_agent.live(f"open: using worktree {into}\n")
        if Path(root).resolve() != into:
            gather_agent.live("open: linking addons\n")
            addon_line = link_addons(Path(root), into)
        else:
            addon_line = "addons: --in from inside the worktree; left as it is."
        wt = into
    else:
        gather_agent.live(f"open: creating worktree {name}\n")
        p = subprocess.run(gather_agent.runnable(create), cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
        wt = Path((p.stdout.strip().splitlines() or [""])[-1].strip())
        if p.returncode != 0 or not str(wt) or not wt.is_dir():
            return end("\n".join(lines + [f"WORKTREE CREATE FAILED (exit {p.returncode}): {(p.stdout + p.stderr).strip()[:400]}"]), "FAIL", route="create-failed")
        gather_agent.live(f"open: worktree {wt}\n")
        gather_agent.live("open: linking addons\n")
        addon_line = link_addons(Path(root), wt)
    addon_line = "\n".join([addon_line, *prepare(wt, flows)])
    if gather:
        gather_agent.live("open: slice.py start\n")
        code, out = gather_agent.start(wt, sargv, sid, tid, extra)
        if code != 0:
            tail = " | ".join(out.strip().splitlines()[-4:])
            return end("\n".join(lines + [addon_line, f"worktree {wt}", f"START FAILED in the worktree (exit {code}): {tail}"]), "FAIL", route="start-failed")
        gather_agent.live("open: start done\n")
        lines = lines + [addon_line, f"worktree {wt}", "start: ran for the main session (" + " ".join(sargv[1:]) + ")"]
        if args.seed_only:
            py = gather_agent.py()
            gather_agent.live("open: seed-only, stopped after the seed\n")
            return end("\n".join(lines + [f"seed-only: stopped after the seed ({wt / 'session-plan.md'}). Gather with `{py} tools/slice.py adjust ...` "
                                           f"(WDB_ROLE=gather marks the index `gather: agent`), then `{py} tools/slice.py open --launch {wt} --review` "
                                           "(check, packet, report; no launch) or `--launch` alone to start the main session."]), "PASS", route="seed-only")
        gather_agent.set_meta(wt, agent_ok=False, agent_warn="")
        gather_agent.live("open: gather-pick --chain\n")
        marked = gather_agent.local_chain(wt, door, job, tid, gather_agent.live)
        if marked:
            gather_agent.live(f"open: chain marked {marked}\n")
            lines.append(f"gather: chain marked {marked}; the refined packet is the first message")
        else:
            gather_agent.live("open: seed packet (the main session closes the index)\n")
            lines.append("seed packet: the main session closes the index")
        return gathered_launch(root, wt, exe, end, lines, args.review)
    if args.review:
        gather_agent.live("open: review, not launching\n")
        return end("\n".join(lines + [addon_line, f"worktree {wt}", "review: stopped before the main session."]), "PASS", route="review")
    gather_agent.live("open: starting session\n")
    cmd = session_argv(exe, str(wt), prompt)
    end("\n".join(lines + [addon_line, f"worktree {wt}", f"SESSION: {show(cmd)}", "Starting grok now (this terminal is handed over)."]), "PASS", route="launch")
    return launch(exe, cmd, wt)

def _prepare_selftest(td: Path) -> list[str]:
    """prepare(): setup then before shots in a clean worktree; skipped when edited or already shot; failures say the fix."""
    bad, seen = [], []
    wt = td / "prep-wt"
    wt.mkdir()

    def fake(status: str = "", rc: int = 0):
        def run(argv, **_kw):
            seen.append(" ".join(argv[1:]))
            out = status if argv[0] == "git" else f"RESULT {'PASS' if rc == 0 else 'FAIL'} x=1\n"
            return subprocess.CompletedProcess(argv, 0 if argv[0] == "git" else rc, out, "")
        return run

    def prep(*a):  # quiet: the planted failure's live "SETUP FAILED" line became the sweep's FAIL detail (#87)
        with contextlib.redirect_stdout(io.StringIO()):
            return prepare(*a)
    lines = prep(wt, "camp-pause-pages", fake())
    if not any("bot-smokes --setup" in a for a in seen) or not any("flow --flow camp-pause-pages --before" in a for a in seen) \
            or lines != ["setup: RESULT PASS x=1", "before shots: RESULT PASS x=1"]:
        bad.append(f"prepare must run the setup, then the before shots of the slice flows: {lines} {seen}")
    if "skipped: 1 tracked path(s) already edited" not in " ".join(prep(wt, "f", fake(" M scripts/a.gd\n"))):
        bad.append("prepare must not shoot before shots in an edited worktree")
    if prep(wt, "", fake())[-1] != "before shots: none (no shot flow mapped to this slice)":
        bad.append("prepare with no flow must say so")
    if not prep(wt, "f", fake(rc=1))[0].startswith("SETUP FAILED (exit 1)"):
        bad.append("a failed setup must say so and print the fix")
    return bad

def selftest(script: list[str]) -> int:
    """Dry-run cases in a throwaway repo; the one non-dry case runs with an empty PATH, so grok cannot start."""
    bad: list[str] = []

    def run(root: Path, *a: str, env: dict | None = None) -> tuple[int, str]:
        p = subprocess.run([*script, "--root", str(root), *a], capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env={**(env or os.environ), "WDB_OPEN_NO_PREPARE": "1"})
        return p.returncode, p.stdout + p.stderr

    git = repo_lib.git_test

    with tempfile.TemporaryDirectory() as td:
        root = repo_lib.selftest_repo(td, empty_commit=True)
        code, out = run(root, "--dry-run")
        if code == 0 or "NO WEEK BRANCH" not in out or "COMMAND" in out:
            bad.append("no week branch must fail loudly with no command")
        git(root, "branch", "grok-build-w9")
        code, out = run(root, "--dry-run")
        if code != 0 or "worktree create wdb-slice-" not in out or "--ref grok-build-w9" not in out or "--cwd" not in out or "--trust" not in out or "No area given" not in out:
            bad.append("a blank launch must print worktree create, then grok --cwd PATH --trust, and say no checks ran")
        cmd = next((ln for ln in out.splitlines() if ln.startswith("COMMAND")), "")
        for b in BANNED:
            if f" {b} " in cmd + " " or cmd.endswith(" " + b):
                bad.append(f"command must not contain {b}")
        code, out = run(root, "--dry-run", "--prompt", "hello there")
        cmd = next((ln for ln in out.splitlines() if ln.startswith("COMMAND")), "")
        if code != 0 or not cmd.endswith(("hello there'", "hello there\"")):
            bad.append("--prompt must be the last argument")
        if "prompt: 11 chars, starts 'hello there'" not in out or "sha256 " not in out:
            bad.append("the prompt length, first 60 chars and sha must be printed")
        (root / "p.txt").write_text("from file\n", encoding="utf-8")
        code, out = run(root, "--dry-run", "--prompt-file", str(root / "p.txt"))
        if code != 0 or "from file" not in out:
            bad.append("--prompt-file must be read by the tool and passed as the prompt")
        (root / "hand.md").write_text("# Handoff: ui\narea: ui\n## Task (her words)\n<fill: x>\n", encoding="utf-8")
        code, out = run(root, "--dry-run", "--prompt-file", str(root / "hand.md"))
        if code == 0 or "HANDOFF NOT READY" not in out or "COMMAND" in out:
            bad.append("an unfilled handoff must fail with no command")
        code, out = run(root, "--dry-run", "--prompt", "-p x")
        if code == 0 or "BAD PROMPT" not in out:
            bad.append("a prompt starting with '-' must fail")
        code, out = run(root, "--dry-run", "ui-demo")
        if code != 0 or "STEP 0 (not a stop)" not in out or "COMMAND" not in out:
            bad.append("a visual area with no shot flow must print STEP 0 and still print the command")
        code, out = run(root, "--dry-run", "player")
        if code != 0 or "wdb-player-" not in out or "resolved" not in out:
            bad.append("a plain area names the worktree and passes the checks")
        (root / "design" / "tasks").mkdir(parents=True)
        (root / "design" / "tasks" / "art.md").write_text("# Art\n\nid: art\nowner: build\nstatus: open\ndone-when: x\nresume: y\nneeds-local: _src\n", encoding="utf-8")
        code, out = run(root, "--dry-run", "player", "--task", "art")
        if code == 0 or "DO NOT LINK" not in out or "mklink" in out:
            bad.append("needs-local must fail loudly and must not link")
        (root / "design" / "tasks" / "art.md").write_text("# Art\n\nid: art\nowner: build\nstatus: open\ndone-when: x\nresume: y\n", encoding="utf-8")
        code, out = run(root, "--dry-run", "content_pipeline.pack", "--task", "art")
        if code != 0 or "worktree create wdb-content_pipeline.pack-" not in out or "--cwd" not in out or "--trust" not in out or "slice.py start --job content_pipeline.pack" not in out or "docs.py task show art" not in out or "mklink" in out or "never edit" in out:
            bad.append("a task must print the start command and docs.py task show, and must not link _src")
        code, out = run(root, "--dry-run", "player")
        if "worktree create" not in out or "--trust" not in out or "mklink" in out or "link PATH" in out:
            bad.append("no task: create then --cwd --trust, no link")
        gitdir = str(Path(shutil.which("git") or "").parent)
        if not shutil.which("grok", path=gitdir):  # PATH = git's folder only, so grok cannot be found or started
            code, out = run(root, "player", env={**os.environ, "PATH": gitdir})
            if code == 0 or "GROK NOT FOUND" not in out or "COMMAND" not in out:
                bad.append("no grok on PATH must print the command and exit non-zero")
        wt = Path(td) / "wt"
        git(root, "worktree", "add", "-q", "--detach", str(wt), "grok-build-w9")
        (wt / "project.godot").write_text("")
        code, out = run(wt, "--dry-run")
        if code == 0 or "IN A WORKTREE" not in out:
            bad.append("inside a linked worktree it must refuse")
        clone = Path(td) / "h" / ".grok" / "worktrees" / "repos-x" / "wdb-clone"
        clone.parent.mkdir(parents=True)
        git(Path(td), "clone", "-q", str(root), str(clone))
        (clone / "project.godot").write_text("")
        code, out = run(clone, "--dry-run")
        if code == 0 or "IN A WORKTREE" not in out:
            bad.append("inside a Grok clone worktree (.git is a directory) it must refuse")
        src = root / "addons" / "godot_ai"
        src.mkdir(parents=True)
        (src / "plugin.cfg").write_text("[plugin]\n", encoding="utf-8")
        linked = Path(td) / "linked-wt"
        linked.mkdir()
        line = link_addons(root, linked)
        seen = linked / "addons" / "godot_ai" / "plugin.cfg"
        if not seen.is_file() or ("junction" not in line and "symlink" not in line and "ADDONS COPIED" not in line):
            bad.append(f"addons must be visible in the worktree through a junction, symlink, or copy ({line})")
        if _reparse(linked / "addons") and os.name == "nt":
            subprocess.run(["cmd", "/c", "rmdir", str(linked / "addons")], check=False)
        elif _reparse(linked / "addons"):
            (linked / "addons").unlink()  # a symlink off Windows: drops the link, not the install
        elif (linked / "addons").exists():
            shutil.rmtree(linked / "addons")
        if not (src / "plugin.cfg").is_file():
            bad.append("removing the worktree addons entry must keep the checkout install")
        missing = Path(td) / "no-addons-src"
        missing.mkdir()
        (missing / "keep.txt").write_text("x", encoding="utf-8")
        bare = Path(td) / "bare-wt"
        bare.mkdir()
        if not link_addons(missing, bare).startswith("ADDONS MISSING"):
            bad.append("a checkout with no addons/ must say ADDONS MISSING")
        bad += _prepare_selftest(Path(td))
        import gather_selftest

        bad += gather_selftest.run(script, Path(td))
    return agent_log.selftest_result(bad)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
