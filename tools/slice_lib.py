"""start_build_slice.py helpers: the FORK lines, --launch, and the selftest (`python tools/start_build_slice.py --selftest`)."""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import agent_log
import retry_lib

CONFIRM = ("CONFIRM (Vira): the Grok docs do not say whether `-r ID` finds a session saved under another working directory "
           "(sessions are stored per directory). If grok reports the session missing, tell Vira.")


VISUAL = {"ui", "theme", "visual"}


def visual_gap(door: str, job: str, area: str, flows: str) -> str:
    """Loud failure text for a visual slice (a ui / theme / visual word in the door, job or area name, split on . - / space)
    whose routes.yaml `shot_flows` maps no flow; '' otherwise. It never picks or invents a flow."""
    words = {w for name in (door, job, area) for w in re.split(r"[.\-/\s]+", name.lower()) if w}
    if flows or not words & VISUAL:
        return ""
    name = job or door or area
    return (f"NO SHOT FLOW: {name} is a visual slice and routes.yaml `shot_flows` maps no flow to it, so a visual change could not be shot, opened and shown. "
            "Nothing is started and no FORK line is printed. Ask the User in a question prompt which screen or state to show, or create the flow first "
            "(tools may be created: tools.md rule 5; `shot-flows.md` gap process; `run_shot_flow.py --list` shows what exists). Then rerun this command.")


def fork_text(wt: str, ref: str, session: str) -> tuple[str, str]:
    """(FORK line(s), note). With a gather session: create the worktree, then fork the session into it. Without: a fresh --worktree session."""
    if not session:
        return f"FORK grok --worktree={wt} --ref {ref}", ""
    return (f"FORK 1 (prints the new worktree path): grok worktree create {wt} --ref {ref}\n"
            f"FORK 2 (forks the gather session into it, gather context kept): grok --cwd <that path> -r {session} --fork-session", CONFIRM)


def launch(root: Path, wt: str, ref: str, session: str) -> tuple[str, str]:
    """Start grok for --launch: (status, worktree path or ''). Needs `grok` on PATH."""
    grok = shutil.which("grok")
    if not grok:
        return "blocked-no-grok", ""
    if not session:
        subprocess.Popen([grok, f"--worktree={wt}", "--ref", ref], cwd=root)
        return "started-fresh", ""
    made = subprocess.run([grok, "worktree", "create", wt, "--ref", ref], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = made.stdout.strip().splitlines()
    if made.returncode != 0 or not lines:
        return "blocked-worktree-create", ""
    path = lines[-1].strip()
    subprocess.Popen([grok, "--cwd", path, "-r", session, "--fork-session"], cwd=root)
    return "started", path


def selftest(script: Path) -> int:
    """No week branch fails with no FORK line; a week branch gives FORK; --session adds -r/--fork-session and is saved."""
    me = str(script)
    bad: list[str] = []

    def run(root: Path, *a: str) -> tuple[int, str]:
        p = subprocess.run([sys.executable, me, "--root", str(root), "--area", "demo", *a], capture_output=True, text=True, encoding="utf-8", errors="replace", env={**os.environ, "GROK_SESSION_ID": ""})
        return p.returncode, p.stdout + p.stderr

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        for a in (("init", "-q"), ("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "a")):
            subprocess.run(["git", *a], cwd=root, check=True, capture_output=True)
        (root / "project.godot").write_text("")
        (root / "scripts" / "data").mkdir(parents=True)
        (root / "scripts" / "data" / "version.json").write_text('{"epoch": 0, "series": 9, "patch": 0}\n')
        code, out = run(root, "--dry-run")
        if code == 0 or "FORK 1" in out or "FORK grok" in out or "NO WEEK BRANCH" not in out or "week_start.py" not in out:
            bad.append(f"no week branch: code={code} must fail loudly without a FORK line")
        code, out = run(root, "--area", "ui-demo", "--ref", "HEAD", "--dry-run")
        if code == 0 or "NO SHOT FLOW" not in out or "FORK 1" in out or "FORK grok" in out or "Ask the User" not in out:
            bad.append("a visual area with no shot flow must fail loudly with no FORK line")
        if visual_gap("ui", "ui.pause", "", "camp-pause-menu") or visual_gap("audio_visual", "", "", "") or visual_gap("hub", "", "", ""):
            bad.append("flows mapped, or a non-visual name, must not fail")
        code, out = run(root, "--ref", "HEAD", "--dry-run")
        if code != 0 or "FORK grok --worktree=wdb-demo-" not in out or "--ref HEAD" not in out or "--fork-session" in out:
            bad.append("--ref HEAD without a session must print the fresh --worktree FORK line")
        subprocess.run(["git", "branch", "grok-build-w9"], cwd=root, check=True, capture_output=True)
        code, out = run(root, "--dry-run")
        if code != 0 or "--ref grok-build-w9" not in out or "main" in out.split("FORK", 1)[1].split("\n", 1)[0] or "WARN no gather session" not in out:
            bad.append("week branch must give FORK --ref grok-build-w9 and the no-session WARN")
        if code == 0 and "--fork-session" in out:
            bad.append("no session must not print a fork")
        code, out = run(root, "--session", "sess-1")
        if code != 0 or "FORK 1" not in out or "grok worktree create wdb-demo-" not in out or "-r sess-1 --fork-session" not in out or "--worktree=" in out or "CONFIRM" not in out:
            bad.append("--session must print worktree create, then grok --cwd PATH -r ID --fork-session (never --worktree with -r)")
        saved = retry_lib.state_path(root)
        if saved is None or not saved.is_file() or "sess-1" not in saved.read_text(encoding="utf-8"):
            bad.append("gather session was not saved")
        code, out = run(root, "--session", "sess-2", "--dry-run")
        if saved and saved.is_file() and "sess-2" in saved.read_text(encoding="utf-8"):
            bad.append("--dry-run saved a session")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


def retry_selftest() -> int:
    """Save/lookup/block in a throwaway git repo: with session, without session, without base."""
    def git(cwd: Path, *a: str) -> None:
        subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *a], cwd=cwd, check=True, capture_output=True)

    bad: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        main = Path(td) / "main"
        main.mkdir()
        git(main, "init", "-q")
        (main / "a.txt").write_text("a\n")
        git(main, "add", "-A")
        git(main, "commit", "-qm", "a")
        git(main, "branch", "grok-build-w9")
        wt = Path(td) / "wdb-x-1"
        git(main, "worktree", "add", "-q", "--detach", str(wt), "grok-build-w9")
        (wt / "b.txt").write_text("b\n")
        git(wt, "add", "-A")
        git(wt, "commit", "-qm", "b")
        red = ["SCRIPT ERROR: Parse Error: x"]
        no_ses = retry_lib.block(wt, "gate", red)
        for need in ("NO MATCHING GATHER SESSION", "git diff grok-build-w9", "No fresh session"):
            if need not in no_ses:
                bad.append(f"no-session block lacks {need!r}")
        if "abc-123" in no_ses:
            bad.append("no-session block names a session")
        if not retry_lib.save_gather(main, "wdb-x-1", "abc-123", ""):
            bad.append("save_gather wrote nothing")
        other = Path(td) / "wdb-other"
        git(main, "worktree", "add", "-q", "--detach", str(other), "grok-build-w9")
        miss = retry_lib.block(other, "gate", red)
        if "START wdb-x-1" not in miss or f"grok --cwd {other} -r abc-123 --fork-session" not in miss or "Paste only after" not in miss:
            bad.append("a worktree with no entry must list the saved sessions to pick from")
        retry_lib.save_gather(main, "label-only", "path-456", "", str(wt))
        if f"-r {retry_lib.gather_for(wt).get('session')} " not in retry_lib.block(wt, "gate", red) or retry_lib.gather_for(wt).get("session") != "path-456":
            bad.append("the saved path must win over the folder name")
        retry_lib.save_gather(main, "label-only", "", "")
        data = retry_lib._load(retry_lib.state_path(main))
        data.pop("label-only", None)
        retry_lib.state_path(main).write_text(__import__("json").dumps(data), encoding="utf-8")
        with_ses = retry_lib.block(wt, "gate", red)
        for need in (f"grok --cwd {wt} -r abc-123 --fork-session", "git diff grok-build-w9", "b.txt", "one diagnosis"):
            if need not in with_ses:
                bad.append(f"session block lacks {need!r}")
        if retry_lib.save_gather(main, "wdb-x-2", "", "r"):
            bad.append("empty session was saved")
        (wt / "a.txt").write_text("edited\n")
        (wt / "new.txt").write_text("untracked\n")
        dirty = retry_lib.block(wt, "gate", red)
        if "a.txt" not in dirty or "new.txt" not in dirty:
            bad.append("uncommitted and untracked files must be listed")
        if retry_lib.strip(["top", *dirty.splitlines(), "bottom"]) != ["top", "bottom"]:
            bad.append("a nested RETRY block must be stripped")
        git(main, "branch", "-D", "grok-build-w9")
        gone = retry_lib.block(wt, "gate", red)
        if "NO BASE" not in gone or "git diff" in gone:
            bad.append("no-base block wrong")
        retry_lib.save_gather(main, "wdb-x-1", "abc-123", "my-ref")
        if "git diff my-ref`" not in retry_lib.block(wt, "gate", red):
            bad.append("saved ref not used as base")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))
