#!/usr/bin/env python3
"""Open a Build slice: the USER runs this (PowerShell on Windows). It starts grok in a NEW worktree cut from the week branch.

    python tools/open_slice.py [AREA_OR_NAME] [--prompt TEXT | --prompt-file PATH] [--ref REF] [--dry-run]
It prints the prompt it passes as one info line (length, first 60 characters, sha256) and logs it. --prompt-file reads a file as is; --prompt takes text. A prompt that starts `# Handoff:` is a survey handoff (start_build_slice.py --handoff): it must be filled in, and the line `handoff:` summarizes it.
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
start_build_slice.py inside the worktree.
--task ID reads design/tasks/ID.md (AREA defaults to its `resume:` line): with no prompt given it writes a short first message (`start_build_slice.py --job|--door AREA --task ID`, then `task.py show ID`; read that file whole).
`_src` is in the repo, so the worktree already has it. `needs-local` is retired: a task that still sets it fails loudly and nothing is linked.
This is the only tool that launches grok for a Build slice (the isolated-media runner is the other launcher, under its own gate).
--selftest: dry-run cases in a throwaway repo; no grok is ever started.
"""
from __future__ import annotations

import datetime as dt
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
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

def session_argv(grok: str, wt: str, prompt: str) -> list[str]:
    """Trust this folder. `grok --worktree --trust` trusts the source checkout, not the new one."""
    return [grok, "--cwd", wt, "--trust"] + ([prompt] if prompt else [])

def task_prompt(tid: str, path: str, area: str) -> str:
    start = f"python tools/start_build_slice.py {task_lib.start_flag(area)} {area} --task {tid}, then python tools/task.py show {tid}"
    return f"Task {tid} ({path}). Your first command, before any file read or memory topic: {start}; read that task file whole."

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Start grok in a new worktree from the week branch (user-run launcher).", writes=True)
    ap.add_argument("area", nargs="?", default="", help="routes.yaml door, door.job, or a free slice name (runs the slice-boot checks).")
    ap.add_argument("--prompt", default="", help="First message for the new session (optional).")
    ap.add_argument("--prompt-file", default="", help="Read the first message from this file (this tool reads it; grok gets it as one argument).")
    ap.add_argument("--ref", default="", help="Git ref to base the worktree on (default: the week branch grok-build-w{N}).")
    ap.add_argument("--task", default="", metavar="ID", help="A design/tasks task. With no prompt, a short first message names it. needs-local is retired and fails.")
    ap.add_argument("--selftest", action="store_true", help="Run dry-run cases in a throwaway repo; never starts grok.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest(Path(__file__).resolve())
    root = agent_log.resolve_root(args)
    dry = args.dry_run

    def end(msg: str, status: str, **kv: object) -> int:
        return agent_log.finish("open-slice", root, msg, status, args=args, write=not dry, **kv)

    if slice_lib.is_linked(root):
        return end(f"IN A WORKTREE: {root} is already a worktree (a Grok clone under .grok/worktrees, or a linked git worktree). Run `python tools/open_slice.py` from the main checkout.", "FAIL", route="in-worktree")
    ref = args.ref or repo_lib.week_branch(root)
    if not ref:
        return end("NO WEEK BRANCH: no grok-build-w* branch exists and no --ref was given, so nothing is started (main is never the fallback). "
                   "Ask Vira whether to start a new week (`python tools/week_start.py`), or pass --ref REF.", "FAIL", route="no-week-branch")
    area = args.area.strip()
    note = ""
    if area:
        _, _, _, note = slice_lib.slice_check(root, area)
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
            return end(f"NO TASK {args.task}: open tasks are `python tools/task.py list`.", "FAIL", route="no-task")
        if task_lib.split(t.get("needs-local", "")):
            return end("DO NOT LINK: needs-local is retired. _src is in the repo, so a worktree already has it. Remove needs-local from the task and rerun.", "FAIL", route="no-link")
        if not area:
            area = task_lib.resume_area(t)
            if not area:
                return end(f"NO AREA for task {args.task}: its `resume:` line names no door or door.job (`python tools/task.py check`).", "FAIL", route="no-area")
            _, _, _, note = slice_lib.slice_check(root, area)
        prompt = prompt or task_prompt(args.task.strip(), t["path"], area)
        if subprocess.run(["git", "cat-file", "-e", f"{ref}:{t['path']}"], cwd=root, capture_output=True).returncode != 0:
            note = (note + "\n" if note else "") + f"WARN: {t['path']} is not on {ref}, so the new worktree will not have it. Merge main into {ref} first, or pass --ref."
    hand_note = ""
    if prompt.startswith("# Handoff:"):
        bad = handoff_lib.check(root, prompt)
        if bad:
            return end("HANDOFF NOT READY (" + (args.prompt_file or "--prompt") + "):\n- " + "\n- ".join(bad) + "\nFinish it in the survey session (`python tools/start_build_slice.py --handoff`), then rerun this.", "FAIL", route="bad-handoff")
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
    exe = shutil.which("grok")
    g = exe or "grok"
    create = create_argv(g, name, ref)
    session = session_argv(g, "PATH", prompt)
    steps = [show(create), show(session)]
    numbered = "  ".join(f"{i}) {step}" for i, step in enumerate(steps, 1))
    lines = [f"repo={root} ref={ref} worktree={name}", f"COMMANDS (run from the repo root): {numbered}"]
    import hashlib

    warn = slice_lib.area_warning(root, area) if area else ""
    lines.append(f"prompt: {len(prompt)} chars, starts {prompt[:60]!r}, sha256 {hashlib.sha256(prompt.encode('utf-8')).hexdigest()[:12]}" if prompt else "prompt: none (a blank session)")
    lines += [hand_note] if hand_note else []
    lines.append((f"area={area}: resolved." + (f"\n{warn}" if warn else "") + (f"\n{note}" if note else "")) if area else
                 "No area given, so no route checks ran. In the new session Build runs `python tools/start_build_slice.py --door <door>` (the card; a later run says where the slice stands).")
    if dry:
        return end("\n".join(lines + ["dry run: grok was not started."]), "PASS", route="dry-run")
    if not exe:
        return end("\n".join(lines + ["GROK NOT FOUND on PATH. Run the COMMANDS above yourself from the repo root."]), "FAIL", route="no-grok")
    p = subprocess.run(create, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
    wt = Path((p.stdout.strip().splitlines() or [""])[-1].strip())
    if p.returncode != 0 or not str(wt) or not wt.is_dir():
        return end("\n".join(lines + [f"WORKTREE CREATE FAILED (exit {p.returncode}): {(p.stdout + p.stderr).strip()[:400]}"]), "FAIL", route="create-failed")
    cmd = session_argv(exe, str(wt), prompt)
    end("\n".join(lines + [f"worktree {wt}", f"SESSION: {show(cmd)}", "Starting grok now (this terminal is handed over)."]), "PASS", route="launch")
    sys.stdout.flush()
    try:
        if os.name == "nt":
            return subprocess.call(cmd, cwd=wt)
        os.chdir(wt)
        os.execvp(exe, cmd)
    except OSError as exc:
        print(f"error: launch failed ({exc}). Copy and run: {show(cmd)}", file=sys.stderr)
        return 1
    return 0

def selftest(script: Path) -> int:
    """Dry-run cases in a throwaway repo; the one non-dry case runs with an empty PATH, so grok cannot start."""
    bad: list[str] = []

    def run(root: Path, *a: str, env: dict | None = None) -> tuple[int, str]:
        p = subprocess.run([sys.executable, str(script), "--root", str(root), *a], capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=env or os.environ)
        return p.returncode, p.stdout + p.stderr

    def git(cwd: Path, *a: str) -> None:
        subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *a], cwd=cwd, check=True, capture_output=True)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "main"
        root.mkdir()
        git(root, "init", "-q")
        git(root, "commit", "-q", "--allow-empty", "-m", "a")
        (root / "project.godot").write_text("")
        (root / "scripts" / "data").mkdir(parents=True)
        (root / "scripts" / "data" / "version.json").write_text('{"epoch": 0, "series": 9, "patch": 0}\n')
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
        code, out = run(root, "--dry-run", "art_pipeline.pack", "--task", "art")
        if code != 0 or "worktree create wdb-art_pipeline.pack-" not in out or "--cwd" not in out or "--trust" not in out or "start_build_slice.py --job art_pipeline.pack" not in out or "task.py show art" not in out or "mklink" in out or "never edit" in out:
            bad.append("a task must print the start command and task.py show, and must not link _src")
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
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
