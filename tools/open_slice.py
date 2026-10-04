#!/usr/bin/env python3
"""Open a Build slice: the USER runs this (PowerShell on Windows). It starts grok in a NEW worktree cut from the week branch.

    python tools/open_slice.py [AREA_OR_NAME] [--prompt TEXT | --prompt-file PATH] [--ref REF] [--dry-run]
Finds the repo from this file's location and the week branch grok-build-w{N} (none and no --ref: fails). The worktree name is
generated (wdb-<area or slice>-<YYYYMMDD-HHMM>). It prints, then runs from the repo root with a plain args list (no shell):
    grok --worktree=NAME --ref WEEKBRANCH [PROMPT]
handing the terminal over (inherited stdio; the exit code of grok on Windows, os.execvp elsewhere). PROMPT is optional: with none
the session starts blank. The prompt is read by this tool and passed as one argument. It never uses --fork-session (cannot be
combined with --worktree), -p, --prompt-file or --max-turns (those make single-turn headless runs). If grok is not on PATH, or
the launch fails, the command is printed to copy and the exit code is 1.
With AREA (a routes.yaml door, door.job, or a free name) the slice-boot checks run first, so a visual slice with no shot_flows
fails (NO SHOT FLOW) before anything starts. Without AREA there are no checks: Build runs start_build_slice.py inside the worktree.
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
import repo_lib
import slice_lib

BANNED = ("--fork-session", "--max-turns", "--prompt-file", "-p")


def show(argv: list[str]) -> str:
    import shlex

    return subprocess.list2cmdline(argv) if os.name == "nt" else shlex.join(argv)


def build_argv(grok: str, name: str, ref: str, prompt: str) -> list[str]:
    return [grok, f"--worktree={name}", "--ref", ref] + ([prompt] if prompt else [])


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Start grok in a new worktree from the week branch (user-run launcher).", writes=True)
    ap.add_argument("area", nargs="?", default="", help="routes.yaml door, door.job, or a free slice name (runs the slice-boot checks).")
    ap.add_argument("--prompt", default="", help="First message for the new session (optional).")
    ap.add_argument("--prompt-file", default="", help="Read the first message from this file (this tool reads it; grok gets it as one argument).")
    ap.add_argument("--ref", default="", help="Git ref to base the worktree on (default: the week branch grok-build-w{N}).")
    ap.add_argument("--selftest", action="store_true", help="Run dry-run cases in a throwaway repo; never starts grok.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest(Path(__file__).resolve())
    root = agent_log.resolve_root(args)
    dry = args.dry_run

    def end(msg: str, status: str, **kv: object) -> int:
        return agent_log.finish("open-slice", root, msg, status, args=args, write=not dry, **kv)

    if slice_lib.is_linked(root):
        return end(f"IN A WORKTREE: {root} is a linked worktree. Run `python tools/open_slice.py` from the main checkout.", "FAIL", route="in-worktree")
    ref = args.ref or repo_lib.week_branch(root)
    if not ref:
        return end("NO WEEK BRANCH: no grok-build-w* branch exists and no --ref was given, so nothing is started (main is never the fallback). "
                   "Ask Vira whether to start a new week (`python tools/week_start.py`), or pass --ref REF.", "FAIL", route="no-week-branch")
    area = args.area.strip()
    if area:
        _, _, _, gap = slice_lib.slice_check(root, area)
        if gap:
            return end(gap, "FAIL", route="no-shot-flow")
    prompt = args.prompt
    if args.prompt_file:
        try:
            prompt = Path(args.prompt_file).read_text(encoding="utf-8-sig")
        except OSError as exc:
            return end(f"CANNOT READ --prompt-file: {exc}", "FAIL", route="bad-prompt")
    prompt = prompt.strip()
    if prompt.startswith("-") or len(prompt) > 30000:
        return end("BAD PROMPT: it must not start with '-' (grok would read a flag) and must fit on a command line. Shorten it or start blank.", "FAIL", route="bad-prompt")
    slug = re.sub(r"[^a-z0-9._-]+", "-", (area or "slice").lower()).strip("-")[:48].strip("-") or "slice"
    name = f"wdb-{slug}-{dt.datetime.now():%Y%m%d-%H%M}"
    exe = shutil.which("grok")
    cmd = build_argv(exe or "grok", name, ref, prompt)
    lines = [f"repo={root} ref={ref} worktree={name}", f"COMMAND (run from the repo root): {show(cmd)}"]
    lines.append(f"area={area}: slice-boot checks passed." if area else
                 "No area given, so no route checks ran. In the new session Build runs `python tools/start_build_slice.py --door <door>` (it says IN A WORKTREE).")
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
        (root / "p.txt").write_text("from file\n", encoding="utf-8")
        code, out = run(root, "--dry-run", "--prompt-file", str(root / "p.txt"))
        if code != 0 or "from file" not in out:
            bad.append("--prompt-file must be read by the tool and passed as the prompt")
        code, out = run(root, "--dry-run", "--prompt", "-p x")
        if code == 0 or "BAD PROMPT" not in out:
            bad.append("a prompt starting with '-' must fail")
        code, out = run(root, "--dry-run", "ui-demo")
        if code == 0 or "NO SHOT FLOW" not in out or "COMMAND" in out:
            bad.append("a visual area with no shot flow must fail before any command")
        code, out = run(root, "--dry-run", "player")
        if code != 0 or "wdb-player-" not in out or "slice-boot checks passed" not in out:
            bad.append("a plain area names the worktree and passes the checks")
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
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
