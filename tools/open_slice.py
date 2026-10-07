#!/usr/bin/env python3
"""Open a Build slice: the USER runs this (PowerShell on Windows). It starts grok in a NEW worktree cut from the week branch.

    python tools/open_slice.py [AREA_OR_NAME] [--prompt TEXT | --prompt-file PATH] [--ref REF] [--dry-run]
It prints the prompt it passes as one info line (length, first 60 characters, sha256) and logs it. --prompt-file reads a file as is; --prompt takes text. A prompt that starts `# Handoff:` is a survey handoff (start_build_slice.py --handoff): it must be filled in, and the line `handoff:` summarizes it.
Finds the repo from this file's location and the week branch grok-build-w{N} (none and no --ref: fails). The worktree name is
generated (wdb-<area or slice>-<YYYYMMDD-HHMM>). It prints, then runs from the repo root with a plain args list (no shell):
    grok --worktree=NAME --ref WEEKBRANCH [PROMPT]
handing the terminal over (inherited stdio; the exit code of grok on Windows, os.execvp elsewhere). PROMPT is optional: with none
the session starts blank. The prompt is read by this tool and passed as one argument. It never uses --fork-session (cannot be
combined with --worktree), -p, --prompt-file or --max-turns (those make single-turn headless runs). If grok is not on PATH, or
the launch fails, the command is printed to copy and the exit code is 1.
With AREA (a routes.yaml door, door.job, or a free name) the area is resolved first; a visual slice with no shot_flows prints a STEP 0
note (creating the flow is the first job step, not a stop) and the launch continues. Without AREA there are no checks: Build runs
start_build_slice.py inside the worktree.
--task ID reads design/tasks/ID.md: with no prompt given it writes a short first message (the start command for AREA, then `task.py show ID`).
A task with `needs-local: _src` (or --local _src) gets the main checkout's gitignored `_src/` linked into the worktree (a directory junction on
Windows, a symlink elsewhere). `grok --worktree` makes its folder itself, so that launch is three steps instead:
    grok worktree create NAME --ref WEEKBRANCH   (prints the worktree path)   ->   link PATH/_src to ROOT/_src   ->   grok --cwd PATH [PROMPT]
A missing `_src`, a link that git would not ignore, or a create that prints no folder fails loudly. Only a task that names it gets the link.
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


def build_argv(grok: str, name: str, ref: str, prompt: str) -> list[str]:
    return [grok, f"--worktree={name}", "--ref", ref] + ([prompt] if prompt else [])


def link_local(src: Path, dst: Path) -> None:
    """dst -> src: a directory junction on Windows (no admin needed), a symlink elsewhere. An existing link to src is kept."""
    if dst.is_symlink() or dst.exists():
        if dst.resolve() == src.resolve():
            return
        raise OSError(f"{dst} already exists and is not a link to {src}")
    if os.name == "nt":
        p = subprocess.run(["cmd", "/c", "mklink", "/J", str(dst), str(src)], capture_output=True, text=True)
        if p.returncode != 0:
            raise OSError(f"mklink /J failed: {(p.stdout + p.stderr).strip()}")
    else:
        os.symlink(src, dst, target_is_directory=True)


def attach_local(root: Path, wt: Path, names: list[str]) -> list[str]:
    """Link each main-checkout folder into the worktree and check git ignores it there; returns the lines to print."""
    out = []
    for n in names:
        link_local(root / n, wt / n)
        if subprocess.run(["git", "check-ignore", "-q", n], cwd=wt).returncode != 0:
            os.unlink(wt / n) if os.name != "nt" else os.rmdir(wt / n)
            raise OSError(f"git does not ignore {n} in {wt}; the link was removed")
        out.append(f"linked {wt / n} -> {root / n} (read only by rule: edits change the main checkout's {n})")
    return out


def task_prompt(tid: str, path: str, area: str, names: list[str]) -> str:
    start = (f"python tools/start_build_slice.py {'--job' if '.' in area else '--door'} {area}, then " if area else "") + f"python tools/task.py show {tid}"
    text = f"Task {tid} ({path}). Your first command, before any file read or memory topic: {start}; read that task file whole."
    for n in names:
        text += f" `{n}` here is a link to the main checkout's {n} (source plates): read from it only; never edit, move or delete anything in it, because that changes the real {n}."
    return text


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Start grok in a new worktree from the week branch (user-run launcher).", writes=True)
    ap.add_argument("area", nargs="?", default="", help="routes.yaml door, door.job, or a free slice name (runs the slice-boot checks).")
    ap.add_argument("--prompt", default="", help="First message for the new session (optional).")
    ap.add_argument("--prompt-file", default="", help="Read the first message from this file (this tool reads it; grok gets it as one argument).")
    ap.add_argument("--ref", default="", help="Git ref to base the worktree on (default: the week branch grok-build-w{N}).")
    ap.add_argument("--task", default="", metavar="ID", help="A design/tasks task: its needs-local folders are linked in; with no prompt, a short first message names it.")
    ap.add_argument("--local", action="append", default=[], choices=task_lib.LOCAL, help="Link this main-checkout folder into the worktree (repeatable).")
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
    local = list(dict.fromkeys(args.local))
    if args.task:
        t = task_lib.load(root).get(args.task.strip())
        if not t:
            return end(f"NO TASK {args.task}: open tasks are `python tools/task.py list`.", "FAIL", route="no-task")
        local = list(dict.fromkeys(local + task_lib.split(t.get("needs-local", ""))))
        prompt = prompt or task_prompt(args.task.strip(), t["path"], area, local)
        if subprocess.run(["git", "cat-file", "-e", f"{ref}:{t['path']}"], cwd=root, capture_output=True).returncode != 0:
            note = (note + "\n" if note else "") + f"WARN: {t['path']} is not on {ref}, so the new worktree will not have it. Merge main into {ref} first, or pass --ref."
    missing = [n for n in local if not (root / n).is_dir()]
    if missing:
        return end(f"LOCAL FOLDER MISSING: {', '.join(missing)} is not in {root}. This task needs the main checkout's source plates there; restore them, then rerun.", "FAIL", route="no-local")
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
            hand_note += f"; unit queue {len(us)} (done {len(dn)}), next = {next((u for u in us if u not in dn), 'none')}; the session walks it with start_build_slice.py --next"
    if prompt.startswith("-") or len(prompt) > 30000:
        return end("BAD PROMPT: it must not start with '-' (grok would read a flag) and must fit on a command line. Shorten it or start blank.", "FAIL", route="bad-prompt")
    slug = re.sub(r"[^a-z0-9._-]+", "-", (area or "slice").lower()).strip("-")[:48].strip("-") or "slice"
    name = f"wdb-{slug}-{dt.datetime.now():%Y%m%d-%H%M}"
    exe = shutil.which("grok")
    cmd = build_argv(exe or "grok", name, ref, prompt)
    lines = [f"repo={root} ref={ref} worktree={name}", f"COMMAND (run from the repo root): {show(cmd)}"]
    import hashlib

    warn = slice_lib.area_warning(root, area) if area else ""
    lines.append(f"prompt: {len(prompt)} chars, starts {prompt[:60]!r}, sha256 {hashlib.sha256(prompt.encode('utf-8')).hexdigest()[:12]}" if prompt else "prompt: none (a blank session)")
    lines += [hand_note] if hand_note else []
    lines.append((f"area={area}: resolved." + (f"\n{warn}" if warn else "") + (f"\n{note}" if note else "")) if area else
                 "No area given, so no route checks ran. In the new session Build runs `python tools/start_build_slice.py --door <door>` (the card; a later run says where the slice stands).")
    if local:
        create = [exe or "grok", "worktree", "create", name, "--ref", ref]
        lines[1] = f"COMMANDS (run from the repo root; {', '.join(local)} needs a pre-made worktree): 1) {show(create)}  2) link PATH/{local[0]} to {root / local[0]} (Windows: mklink /J)  3) {show([exe or 'grok', '--cwd', 'PATH'] + ([prompt] if prompt else []))}"
        if dry:
            return end("\n".join(lines + ["dry run: grok was not started; no worktree or link was made."]), "PASS", route="dry-run-local")
        if not exe:
            return end("\n".join(lines + ["GROK NOT FOUND on PATH. Run the three COMMANDS above yourself from the repo root."]), "FAIL", route="no-grok")
        p = subprocess.run(create, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
        wt = Path((p.stdout.strip().splitlines() or [""])[-1].strip())
        if p.returncode != 0 or not str(wt) or not wt.is_dir():
            return end("\n".join(lines + [f"WORKTREE CREATE FAILED (exit {p.returncode}): {(p.stdout + p.stderr).strip()[:400]}"]), "FAIL", route="create-failed")
        try:
            lines += attach_local(root, wt, local)
        except OSError as exc:
            return end("\n".join(lines + [f"LINK FAILED: {exc}. The worktree is at {wt}; nothing was started."]), "FAIL", route="link-failed")
        cmd = [exe, "--cwd", str(wt)] + ([prompt] if prompt else [])
        end("\n".join(lines + [f"worktree {wt}", "Starting grok now (this terminal is handed over)."]), "PASS", route="launch-local")
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
    if dry:
        return end("\n".join(lines + ["dry run: grok was not started."]), "PASS", route="dry-run")
    if not exe:
        return end("\n".join(lines + ["GROK NOT FOUND on PATH. Copy the COMMAND above and run it yourself from the repo root."]), "FAIL", route="no-grok")
    code = end("\n".join(lines + ["Starting grok now (this terminal is handed over)."]), "PASS", route="launch")
    sys.stdout.flush()
    try:
        if os.name == "nt":
            return subprocess.call(cmd, cwd=root)
        os.chdir(root)
        os.execvp(exe, cmd)
    except OSError as exc:
        print(f"error: launch failed ({exc}). Copy and run: {show(cmd)}", file=sys.stderr)
        return 1
    return code


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
        if code != 0 or "--worktree=wdb-slice-" not in out or "--ref grok-build-w9" not in out or "No area given" not in out:
            bad.append("a blank launch must print grok --worktree=NAME --ref WEEK and say no checks ran")
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
        (root / ".gitignore").write_text("_src\n", encoding="utf-8")
        (root / "design" / "tasks").mkdir(parents=True)
        (root / "design" / "tasks" / "art.md").write_text("# Art\n\nid: art\nowner: build\nstatus: open\ndone-when: x\nresume: y\nneeds-local: _src\n", encoding="utf-8")
        code, out = run(root, "--dry-run", "player", "--task", "art")
        if code == 0 or "LOCAL FOLDER MISSING" not in out:
            bad.append("a task that needs _src must fail loudly when the main checkout has none")
        (root / "_src").mkdir()
        code, out = run(root, "--dry-run", "art_pipeline.pack", "--task", "art")
        if code != 0 or "worktree create wdb-art_pipeline.pack-" not in out or "--cwd" not in out or "start_build_slice.py --job art_pipeline.pack" not in out or "never edit" not in out:
            bad.append("a task with needs-local must print create / link / --cwd steps and a first message with the start command and the read-only rule")
        code, out = run(root, "--dry-run", "player")
        if "worktree create" in out:
            bad.append("no task and no --local: the plain --worktree launch, no link")
        lw = Path(td) / "lw"
        git(root, "add", ".gitignore")
        git(root, "commit", "-qm", "ign")
        git(Path(td), "clone", "-q", str(root), str(lw))
        try:
            attach_local(root, lw, ["_src"])
            if not (lw / "_src").is_symlink() or "_src" in subprocess.run(["git", "status", "--porcelain"], cwd=lw, capture_output=True, text=True).stdout:
                bad.append("the linked _src must be a link and not show in git status")
        except OSError as exc:
            bad.append(f"attach_local failed: {exc}")
        (lw / ".gitignore").write_text("", encoding="utf-8")
        os.unlink(lw / "_src")
        try:
            attach_local(root, lw, ["_src"])
            bad.append("a link git would not ignore must fail")
        except OSError:
            if (lw / "_src").is_symlink():
                bad.append("a refused link must be removed")
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
