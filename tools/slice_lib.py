"""start_build_slice.py / open_slice.py helpers: the START lines, the area check, the worktree checkpoint, the NO SHOT FLOW check and the selftests (`python tools/start_build_slice.py --selftest`)."""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import agent_log
import retry_lib

VISUAL = {"ui", "theme", "visual"}


def visual_gap(door: str, job: str, area: str, flows: str) -> str:
    """Loud failure text for a visual slice (a ui / theme / visual word in the door, job or area name, split on . - / space)
    whose routes.yaml `shot_flows` maps no flow; '' otherwise. It never picks or invents a flow."""
    words = {w for name in (door, job, area) for w in re.split(r"[.\-/\s]+", name.lower()) if w}
    if flows or not words & VISUAL:
        return ""
    name = job or door or area
    return (f"NO SHOT FLOW: {name} is a visual slice and routes.yaml `shot_flows` maps no flow to it, so a visual change could not be shot, opened and shown. "
            "Nothing is started and no START line is printed. Ask the User in a question prompt which screen or state to show, or create the flow first "
            "(tools may be created: tools.md rule 5; `shot-flows.md` gap process; `run_shot_flow.py --list` shows what exists). Then rerun this command.")


def slice_check(root: Path, name: str) -> tuple[str, str, str, str]:
    """(door, job, flows, gap) for an area the user typed: a routes.yaml job or door when it is one, else a free area name.
    gap is the NO SHOT FLOW text for a visual slice with no mapped flow, else ''."""
    door = job = ""
    flows = ""
    try:
        from load_routes import check_route, load_routes, shot_flows

        data = load_routes(root)
        if "." in name and not check_route(data, "", name):
            job = name
        elif name and not check_route(data, name, ""):
            door = name
        flows = ",".join(shot_flows(data, door=door, job=job)) if (door or job) else ""
    except Exception:
        pass
    return door, job, flows, visual_gap(door, job, "" if (door or job) else name, flows)


FORK_FACT = ("A fork keeps the directory of the session it forks, and --fork-session cannot be combined with --worktree, so a session "
             "cannot be moved into a worktree. Only a session that already lives in the worktree is forked.")


def start_text(wt: str, ref: str) -> str:
    """The START lines for the main-checkout session: the user runs them; this session then stops."""
    return (f"START 1 (creates the worktree and prints its path): grok worktree create {wt} --ref {ref}\n"
            "START 2 (a NEW session; its directory is then the worktree): cd <that path>   then   grok\n"
            f"Or both in one step: grok --worktree={wt} --ref {ref}\n"
            "This session stops here: no gather, no edits, and it never starts grok (no fork, no headless run, no --prompt-file, no --max-turns).\n"
            "Paste the task into the new session: restate the ask, gather, then `python tools/start_build_slice.py --checkpoint`.\n" + FORK_FACT)


def in_worktree_text() -> str:
    return ("IN A WORKTREE: this directory is the slice; do not create another. Restate the ask, gather, then run "
            "`python tools/start_build_slice.py --checkpoint`. This tool never starts grok.")


def is_linked(root: Path) -> bool:
    """True when root is a linked git worktree (its git dir differs from the shared one)."""
    out = [subprocess.run(["git", "rev-parse", f"--{k}"], cwd=root, capture_output=True, text=True).stdout.strip() for k in ("git-dir", "git-common-dir")]
    return bool(out[0] and out[1]) and (root / out[0]).resolve() != (root / out[1]).resolve()


def checkpoint(root: Path, args) -> int:
    """--checkpoint: save this (worktree) session's id so a red prove can fork it later from the worktree directory."""
    def fail(msg: str, route: str) -> int:
        return agent_log.finish("slice-boot", root, msg, "FAIL", args=args, write=not args.dry_run, route=route)

    if not is_linked(root):
        return fail("NOT A WORKTREE: this is the main checkout, so no checkpoint is saved. Run `python tools/start_build_slice.py --door <door>`, "
                    "have the User run its START lines, and run --checkpoint in that NEW session after gather.", "checkpoint-main")
    session = (args.session or os.environ.get("GROK_SESSION_ID", "")).strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", session):
        return fail("NO SESSION ID: $GROK_SESSION_ID is empty in this session and no --session was given. Nothing is saved. Ask the User in a question prompt "
                    "for this session's id (`/session-info` in grok, or `grok sessions list` run in this directory), then rerun with --session ID.", "checkpoint-no-id")
    saved = "" if args.dry_run else retry_lib.save_gather(root, root.name, session, args.ref, str(root))
    msg = (f"CHECKPOINT saved: session {session} for worktree {root}. A red prove prints `grok -r {session} --fork-session` to run from this directory; "
           "the fork stays in this worktree because this session already lives here.")
    return agent_log.finish("slice-boot", root, msg, "PASS", args=args, write=not args.dry_run, route="checkpoint", saved="yes" if saved else "dry-run")


def selftest(script: Path) -> int:
    """Boot: no week branch fails; a week branch prints START (no fork); a visual area with no flow fails. Checkpoint: main refuses, a worktree saves."""
    me = str(script)
    bad: list[str] = []

    def run(root: Path, *a: str, area: str = "demo", env: str = "") -> tuple[int, str]:
        cmd = [sys.executable, me, "--root", str(root)] + (["--area", area] if area else []) + list(a)
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env={**os.environ, "GROK_SESSION_ID": env})
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
        if code == 0 or "START 1" in out or "NO WEEK BRANCH" not in out or "week_start.py" not in out:
            bad.append(f"no week branch: code={code} must fail loudly without a START line")
        code, out = run(root, "--dry-run", area="ui-demo")
        if code == 0 or "NO SHOT FLOW" not in out or "START 1" in out or "Ask the User" not in out:
            bad.append("a visual area with no shot flow must fail loudly with no START line")
        if visual_gap("ui", "ui.pause", "", "camp-pause-menu") or visual_gap("audio_visual", "", "", "") or visual_gap("hub", "", "", ""):
            bad.append("flows mapped, or a non-visual name, must not fail")
        code, out = run(root, "--ref", "HEAD", "--dry-run")
        if code != 0 or "grok worktree create wdb-demo-" not in out or "grok --worktree=wdb-demo-" not in out or "cd <that path>" not in out or "--ref HEAD" not in out:
            bad.append("--ref HEAD must print the worktree create, cd + grok, and one-step lines")
        git(root, "branch", "grok-build-w9")
        code, out = run(root, "--dry-run")
        if code != 0 or "--ref grok-build-w9" not in out or "main" in out.split("START 1", 1)[1].split("\n", 1)[0]:
            bad.append("a week branch must give START --ref grok-build-w9")
        for banned in ("--cwd", "--launch", "--max-turns", "--prompt-file\n"):
            if banned in out.replace("no --prompt-file, no --max-turns", ""):
                bad.append(f"START output must not contain {banned!r}")
        code, out = run(root, "--checkpoint", env="sess-1")
        if code == 0 or "NOT A WORKTREE" not in out:
            bad.append("--checkpoint in the main checkout must fail")
        wt = Path(td) / "wdb-demo-1"
        git(root, "worktree", "add", "-q", "--detach", str(wt), "grok-build-w9")
        (wt / "project.godot").write_text("")
        code, out = run(wt, "--checkpoint")
        if code == 0 or "NO SESSION ID" not in out or "grok sessions list" not in out:
            bad.append("--checkpoint with no id must fail and say where to get it")
        code, out = run(wt, "--checkpoint", "--dry-run", env="sess-1")
        saved = retry_lib.state_path(root)
        if code != 0 or (saved and saved.is_file() and "sess-1" in saved.read_text(encoding="utf-8")):
            bad.append("--checkpoint --dry-run must pass and save nothing")
        code, out = run(wt, "--checkpoint", env="sess-1")
        if code != 0 or "grok -r sess-1 --fork-session" not in out or "--cwd" in out:
            bad.append("--checkpoint must save and print `grok -r ID --fork-session` without --cwd")
        if retry_lib.gather_for(wt).get("session") != "sess-1":
            bad.append("the checkpoint was not saved for the worktree")
        code, out = run(wt, "--ref", "HEAD", "--dry-run")
        if code != 0 or "IN A WORKTREE" not in out or "START 1" in out:
            bad.append("boot inside a worktree must say it is the slice and print no START lines")
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
        for need in ("NO CHECKPOINT", "git diff grok-build-w9", "--checkpoint", "Nothing is forked or started"):
            if need not in no_ses:
                bad.append(f"no-session block lacks {need!r}")
        if "abc-123" in no_ses:
            bad.append("no-session block names a session")
        if not retry_lib.save_gather(main, "wdb-x-1", "abc-123", ""):
            bad.append("save_gather wrote nothing")
        other = Path(td) / "wdb-other"
        git(main, "worktree", "add", "-q", "--detach", str(other), "grok-build-w9")
        miss = retry_lib.block(other, "gate", red)
        if "NO CHECKPOINT" not in miss or "abc-123" in miss:
            bad.append("a worktree with no entry must say there is no checkpoint and name no other session")
        retry_lib.save_gather(main, "label-only", "path-456", "", str(wt))
        if "grok -r path-456 --fork-session" not in retry_lib.block(wt, "gate", red) or retry_lib.gather_for(wt).get("session") != "path-456":
            bad.append("the saved path must win over the folder name")
        retry_lib.save_gather(main, "label-only", "", "")
        data = retry_lib._load(retry_lib.state_path(main))
        data.pop("label-only", None)
        retry_lib.state_path(main).write_text(__import__("json").dumps(data), encoding="utf-8")
        with_ses = retry_lib.block(wt, "gate", red)
        for need in ("grok -r abc-123 --fork-session", f"cd {wt}", "git diff grok-build-w9", "b.txt", "one diagnosis"):
            if need not in with_ses:
                bad.append(f"session block lacks {need!r}")
        if "--cwd" in with_ses or "CONFIRM" in with_ses:
            bad.append("session block must not use --cwd or carry a CONFIRM note")
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
