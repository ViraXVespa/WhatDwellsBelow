"""start_build_slice.py / open_slice.py helpers: the START lines, the area check, the worktree checkpoint, the STEP 0 (missing flow) note and the selftests (`python tools/start_build_slice.py --selftest`)."""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import agent_log
import retry_lib
import session_lib

VISUAL = {"ui", "theme", "visual"}


def step0_note(door: str, job: str, area: str, flows: str, near: str = "") -> str:
    """STEP 0 text for a visual slice (a ui / theme / visual word in the door, job or area name, split on . - / space) whose routes.yaml
    `shot_flows` maps no flow to it; '' otherwise. A note, never a stop: creating the flow is the first job step. `near` = flows mapped
    to the door only, shown as possibly another screen."""
    words = {w for name in (door, job, area) for w in re.split(r"[.\-/\s]+", name.lower()) if w}
    if flows or not words & VISUAL:
        return ""
    name = job or door or area
    return (f"STEP 0 (not a stop): no shot flow is mapped to {name} in routes.yaml `shot_flows`. Creating or adjusting the flow for the exact screen is the first job step, "
            "and flow files (tools/shot-flows/) plus the routes.yaml mapping may be edited before the User answers. In the worktree: `python tools/run_shot_flow.py --list` "
            "shows what exists; copy the nearest flow (shot-flows.md, New UI state checklist), point it at the screen, map it by job, shoot it and OPEN the PNG. "
            "Say whether that PNG is the screen being changed, and send its path with the ask."
            + (f" Mapped to the door only, so possibly another screen: {near}." if near else ""))


def slice_check(root: Path, name: str) -> tuple[str, str, str, str]:
    """(door, job, flows, note) for an area the user typed: a routes.yaml job or door when it is one, else a free area name.
    flows = the job's own mapping (no door fallback); note = the STEP 0 text for a visual slice with no flow, else ''."""
    door = job = flows = near = ""
    try:
        from load_routes import check_route, load_routes, shot_flows

        data = load_routes(root)
        if "." in name and not check_route(data, "", name):
            job = name
        elif name and not check_route(data, name, ""):
            door = name
        if door or job:
            flows = ",".join(shot_flows(data, door=door, job=job, job_only=True))
            near = ",".join(shot_flows(data, door=door or job.split(".", 1)[0])) if job and not flows else ""
    except Exception:
        pass
    return door, job, flows, step0_note(door, job, "" if (door or job) else name, flows, near)


FORK_FACT = ("A fork keeps the directory of the session it forks, and --fork-session cannot be combined with --worktree, so a session "
             "cannot be moved into a worktree. Only a session that already lives in the worktree is forked.")


def start_text(wt: str, ref: str) -> str:
    """The START lines for the main-checkout session: the user runs them; this session then stops."""
    return (f"START 1 (creates the worktree and prints its path): grok worktree create {wt} --ref {ref}\n"
            "START 2 (a NEW session; its directory is then the worktree): cd <that path>   then   grok\n"
            f"Or both in one step: grok --worktree={wt} --ref {ref}\n"
            "This session stops here: no gather, no edits, and it never starts grok (no fork, no headless run, no --prompt-file, no --max-turns).\n"
            "Paste the task into the new session: open the baseline picture, show the restate, ask your questions, gather, then `python tools/start_build_slice.py --checkpoint`.\n" + FORK_FACT)


def in_worktree_text(sdir: Path | None = None, handoff: bool = False) -> str:
    """The first-message text Build reads when this tool is its first command. `sdir` = the running session's folder (session_lib), when known.
    `handoff`: the session was opened from a survey handoff, so the survey ORDER and Q0 lines give way to the handoff line."""
    start = [
        "IN A WORKTREE: this directory is the slice; do not create another. This tool is the first command of a slice.",
        session_lib.statement(sdir),
    ]
    if handoff:
        start.append("ORDER (handoff): `python tools/check_gd_load.py` once and `python tools/run_godot_import_check.py` (a fresh worktree has nothing imported); open the baselines the handoff lists "
                     "(re-shoot only one that is missing or band=fail); read the files it lists; then the first unit. Ask about what Open questions lists or what a discovery changes.")
    return "\n".join(start + ([] if handoff else [
        "ORDER: `python tools/check_gd_load.py` once and `python tools/run_godot_import_check.py` (a fresh worktree has nothing imported); shoot and OPEN the baseline "
        "(band=fail is invalid: fix the cause, re-shoot); write the survey or restate as visible text; then Q0; then your other questions.",
        "Q0, in every slice, even when the prompt gives a look: what should the result look like; is there a reference (a picture, a game, a screen); what is out of bounds, "
        "including frames or layouts already built. A layout or frame inherited from earlier work is a Q0 item, never only a ledger line.",
    ]) + [
        "AN ASK IS ALWAYS PRECEDED BY ITS MESSAGE: the survey or restate, every PNG path with a one-line description of it, the ledger lists, and `Did not work:` if any. "
        "Option labels are not the message; an ask with no text is a protocol break. Realise it was not sent: send it before your next tool call. In a survey of several surfaces the "
        "survey comes first; which group, the order and what she wants for each are separate questions after it.",
        "LEDGER, three lines, in every ask: \"Decisions I made that were yours\" (incl. new assets, fonts, dependencies, generated images); \"Assumptions carried from memory or docs\"; "
        "\"Also changed\" (shared code and the other screens that use it, filled from `python tools/list_xref.py NAME` for each shared script you touched; states not shot; "
        "writes outside the worktree, Grok memory files included; windows or programs opened on her PC). Build writes nothing outside the worktree except tools/run_isolated_grok.py and the checkpoint file.",
        "DID NOT WORK: any non-zero exit, `RESULT FAIL`, or skipped step, exploratory ones too, opens your next message as `Did not work: <command> <one line>`. "
        "`python tools/did_not_work.py` lists them from the session.",
        "SHOWING: opening a file on her PC (explorer, Start-Process) is not showing it; put the paths and descriptions in the message. Opening one needs a ledger entry.",
        "Then gather and run `python tools/start_build_slice.py --checkpoint` (the point a red prove forks back to)."
        + ("" if handoff else " A survey of several surfaces ends at her answers to its first ask: `python tools/start_build_slice.py --handoff`, then stop; a fresh session implements.")
        + " This tool never starts grok.",
    ])


def doors_hint(root: Path) -> str:
    """'doors: a, b, c; jobs are door.job (python tools/list_route.py lists them)' from routes.yaml, or ''."""
    try:
        from load_routes import load_routes

        doors = sorted((load_routes(root).get("doors") or {}).keys())
    except Exception:
        return ""
    return f"doors: {', '.join(doors)}; jobs are door.job (`python tools/list_route.py` lists them)" if doors else ""


def area_warning(root: Path, area: str, door: str = "", job: str = "") -> str:
    """WARN text when --area is neither a routes.yaml door nor a job: it then only names the worktree and gives no route card."""
    area = area.strip()
    if not area or area in (door, job):
        return ""
    try:
        from load_routes import check_route, load_routes

        data = load_routes(root)
        if ("." in area and not check_route(data, "", area)) or (not check_route(data, area, "")):
            return ""
    except Exception:
        return ""
    return (f"WARN: --area {area!r} is not a routes.yaml door or job, so it only names the worktree and gives no route card, smokes or flows. "
            f"Valid: {doors_hint(root) or 'see design/routes.yaml'}. Use --door / --job for the card; a free name is fine for a new, undocumented system (ask the User).")


def worktree_kind(root: Path) -> str:
    """Which worktree shape root is: 'clone' = a Grok worktree (a full clone: `.git` is a directory, git dir == common dir, HEAD on the week
    branch), found by its place `<...>/.grok/worktrees/<repo>/<name>` (seen in a real session: C:\\Users\\Vira\\.grok\\worktrees\\repos-whatdwellsbelow\\wdb-...);
    'linked' = a true `git worktree add` (git dir differs from the shared one); '' = a main checkout."""
    try:
        parts = [p.lower() for p in root.resolve().parts]
    except OSError:
        parts = []
    for i in range(1, len(parts)):
        if parts[i] == "worktrees" and parts[i - 1] == ".grok" and len(parts) - i - 1 == 2 and (root / ".git").exists():
            return "clone"
    out = [subprocess.run(["git", "rev-parse", f"--{k}"], cwd=root, capture_output=True, text=True).stdout.strip() for k in ("git-dir", "git-common-dir")]
    return "linked" if bool(out[0] and out[1]) and (root / out[0]).resolve() != (root / out[1]).resolve() else ""


def is_linked(root: Path) -> bool:
    """True when root is a slice worktree of either shape (see worktree_kind)."""
    return bool(worktree_kind(root))


def merge_back_text(kind: str, week: str) -> str:
    """The merge-back card line for the shape. The clone route is what a real session did (a push of the week branch); whether it is the intended route is the User's to confirm."""
    ask = "balance, audio, visuals, controls: ask the User for playtest approval first. Commit and push only after she says the final shot is settled (or told you to commit now)"
    if kind == "clone":
        return (f"merge-back=this worktree is a full clone ON the week branch {week or 'grok-build-w{N}'} (not detached, no separate branch): on a green prove and her OK, commit here "
                f"and `git push origin {week or 'grok-build-w{N}'}` (plain push, never main, no force); nothing to merge by hand. {ask}")
    wk = week or "grok-build-w{N}"
    return (f"merge-back=on a green prove and her OK: commit in the worktree (linked worktree, HEAD is detached), then in the checkout that holds {wk} (git worktree list): "
            f"git merge --no-ff <worktree HEAD sha> (never main). {ask}")


def checkpoint(root: Path, args) -> int:
    """--checkpoint: save this (worktree) session's id so a red prove can fork it later from the worktree directory."""
    def fail(msg: str, route: str) -> int:
        return agent_log.finish("slice-boot", root, msg, "FAIL", args=args, write=not args.dry_run, route=route)

    if not is_linked(root):
        return fail("NOT A WORKTREE: this directory is a main checkout (not under .grok/worktrees/, and not a linked git worktree), so no checkpoint is saved. "
                    "Say so in your next message to the User (\"Did not work: --checkpoint, not a worktree\"). Run `python tools/start_build_slice.py --door <door>`, "
                    "have the User run its START lines, and run --checkpoint in that NEW session after gather.", "checkpoint-main")
    session = (args.session or os.environ.get("GROK_SESSION_ID", "")).strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", session):
        return fail("NO SESSION ID: $GROK_SESSION_ID is empty in this session and no --session was given. Nothing is saved, so a red prove could not be forked. "
                    "Start your next message to the User with \"Did not work: --checkpoint (no session id)\", and ask her in a question prompt for this session's id "
                    "(she types `/session-info` in grok, or runs `grok sessions list` in this directory), then rerun with --session ID.", "checkpoint-no-id")
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
        if code == 0 or "NO WEEK BRANCH" not in out:
            bad.append("no week branch still fails for a visual area")
        if not step0_note("", "", "ui-demo", "") or "not a stop" not in step0_note("ui", "ui.x", "", "", "camp-a") or "camp-a" not in step0_note("ui", "ui.x", "", "", "camp-a"):
            bad.append("a visual slice with no flow must give the STEP 0 note (naming the door-only flows)")
        if step0_note("ui", "ui.pause", "", "camp-pause-menu") or step0_note("audio_visual", "", "", "") or step0_note("hub", "", "", ""):
            bad.append("flows mapped, or a non-visual name, must give no note")
        code, out = run(root, "--area", "ui-demo", "--ref", "HEAD", "--dry-run", area="")
        if code != 0 or "START 1" not in out:
            bad.append("a visual area with no flow must still print START in a main checkout, exit 0")
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
        if worktree_kind(wt) != "linked" or "HEAD is detached" not in out or "git merge --no-ff" not in out:
            bad.append("a linked worktree must be kind 'linked' and print the detached-HEAD merge-back")
        # Grok's real shape: a FULL CLONE under .grok/worktrees/<repo>/<name>: .git is a directory, git dir == common dir, HEAD on the week branch
        clone = Path(td) / "home" / ".grok" / "worktrees" / "repos-demo" / "wdb-demo-2"
        clone.parent.mkdir(parents=True)
        git(Path(td), "clone", "-q", str(root), str(clone))
        git(clone, "checkout", "-q", "-B", "grok-build-w9", "origin/grok-build-w9")
        (clone / "project.godot").write_text("")
        (clone / "scripts" / "data").mkdir(parents=True, exist_ok=True)
        (clone / "scripts" / "data" / "version.json").write_text('{"epoch": 0, "series": 9, "patch": 0}\n')
        if not (clone / ".git").is_dir() or worktree_kind(clone) != "clone" or not is_linked(clone):
            bad.append("a full clone under .grok/worktrees must be recognised as a Grok worktree")
        code, out = run(clone, "--dry-run")
        if code != 0 or "IN A WORKTREE" not in out or "START 1" in out or "full clone ON the week branch" not in out or "git push origin grok-build-w9" not in out or "HEAD is detached" in out:
            bad.append("boot in a Grok clone must say IN A WORKTREE and give the clone merge-back (push of the week branch), not the detached text")
        if "worktree=wdb-demo-2" not in out or "Did not work:" not in out:
            bad.append("boot in a worktree must name the folder as the worktree and state the Did not work rule")
        code, out = run(clone, "--dry-run", area="ui-demo")
        if code != 0 or "IN A WORKTREE" not in out or out.index("IN A WORKTREE") > out.index("STEP 0 (not a stop)"):
            bad.append("the worktree test must come before the STEP 0 note, and a Grok clone must pass with the note")
        code, out = run(root, "--dry-run", area="ui-demo")
        if "STEP 0" in out or "START 1" not in out:
            bad.append("a main checkout prints START lines and no STEP 0 note")
        code, out = run(clone, "--checkpoint")
        if code == 0 or "NO SESSION ID" not in out or "Did not work: --checkpoint" not in out or "/session-info" not in out or "grok sessions list" not in out:
            bad.append("--checkpoint in a clone with no id must fail with the Did not work line and where to get the id")
        code, out = run(clone, "--checkpoint", env="sess-2")
        if code != 0 or "grok -r sess-2 --fork-session" not in out or retry_lib.gather_for(clone).get("session") != "sess-2":
            bad.append("--checkpoint must work in a Grok clone")
        code, out = run(clone, "--dry-run")
        for need in ("This tool is the first command", "First-message statement", "not verified", "/session-info", "Q0", "AN ASK IS ALWAYS PRECEDED BY ITS MESSAGE", "Option labels are not the message",
                     "Also changed", "Grok memory files", "DID NOT WORK", "did_not_work.py", "opening a file on her PC", "inherited from earlier work"):
            if need.lower() not in out.lower():
                bad.append(f"the worktree first-message text lacks {need!r}")
        # routes fixture: a door with a visual job; the flow is created first (mapped), then the door prints no STEP 0; an unknown --area warns and lists the doors
        (clone / "design").mkdir(exist_ok=True)
        routes = clone / "design" / "routes.yaml"
        routes.write_text('version: 1\ndoors:\n  ui:\n    file: design/ui.md\n    read_when: "x"\n    jobs:\n      pause: design/ui-pause.md\nshot_flows:\n  ui: "door-flow"\n', encoding="utf-8")
        code, out = run(clone, "--job", "ui.pause", "--dry-run", area="")
        if code != 0 or "IN A WORKTREE" not in out or "STEP 0 (not a stop)" not in out or "door-flow" not in out or out.index("IN A WORKTREE") > out.index("STEP 0"):
            bad.append("a visual job with no flow of its own must print IN A WORKTREE, then STEP 0 naming the door-level flows")
        routes.write_text(routes.read_text(encoding="utf-8") + '  ui.pause: "own-flow"\n', encoding="utf-8")
        code, out = run(clone, "--job", "ui.pause", "--dry-run", area="")
        if code != 0 or "STEP 0" in out:
            bad.append("once the flow is created and mapped by job, the door must print no STEP 0")
        code, out = run(clone, "--door", "ui", "--area", "ui-redesign", "--dry-run", area="")
        if code != 0 or "WARN: --area 'ui-redesign'" not in out or "doors: ui" not in out:
            bad.append("an unknown --area must warn and list the valid doors")
        code, out = run(clone, area="", *())
        if code == 0 or "--door D" not in out or "doors: ui" not in out:
            bad.append("no --door/--job/--area must fail with the usage and the valid doors (so --help is not needed)")
        plain = Path(td) / "plain" / "worktrees" / "repos-demo" / "wdb-demo-3"
        plain.parent.mkdir(parents=True)
        git(Path(td), "clone", "-q", str(root), str(plain))
        if worktree_kind(plain) != "" or worktree_kind(root) != "":
            bad.append("a full clone outside .grok/worktrees, and the main checkout, are not worktrees")
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
