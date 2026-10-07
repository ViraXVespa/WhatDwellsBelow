"""start_build_slice.py / open_slice.py helpers: the start-card text, the area check, the worktree checkpoint, the STEP 0 (missing flow) note and the selftests (`python tools/start_build_slice.py --selftest`)."""
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
            "shows what exists; copy the nearest flow (shot-flows.md, New UI state checklist), point it at the screen, map it by job, shoot it and look at it. "
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


Q0 = ("Q0, in every slice, even when the prompt gives a look: what should the result look like; is there a reference (a picture, a game, a screen); what is out of bounds, "
      "including frames or layouts already built. A layout or frame inherited from earlier work is a Q0 item, never only a ledger line. "
      "Look options differ in kind (one look shared by every screen, a look per screen or object, a new look, her words), not in detail, and are not all built on one existing look. "
      "Each option says `reuse <the existing asset or look>` or `draw new`; an option that only names an asset (\"the stall prop\") is not an option yet.")


def is_survey(root: Path, door: str, job: str, area: str, handoff: bool) -> bool:
    """A survey slice: a door (not a job) with several jobs and no handoff yet. It surveys from text and ends in `--handoff`."""
    if handoff or job.strip() or area.strip() or not door.strip():
        return False
    try:
        from load_routes import load_routes

        data = load_routes(root)
        if (data.get("unit_queue") or {}).get(door.strip()):
            return False  # a door worked as a unit queue is not surveyed: the first unit not done is the slice
        jobs = ((data.get("doors") or {}).get(door.strip()) or {}).get("jobs") or {}
        return len(jobs) >= 2
    except Exception:
        return False


def in_worktree_text(root: Path, sdir: Path | None = None, mode: str = "implement") -> str:
    """The first-message text Build reads when this tool is its first command. `sdir` = the running session's folder (session_lib).
    `mode`: 'implement' (a job), 'survey' (a door with several jobs: text survey, ends in --handoff) or 'handoff' (a fresh session from a handoff)."""
    start = [
        "IN A WORKTREE: this directory is the slice; do not create another. This tool is the first command of a slice; a later run says where the slice stands (`--full` reprints this).",
        session_lib.statement(sdir),
    ]
    if mode == "handoff":
        order = [("ORDER (handoff): `python tools/check_gd_load.py` once and `python tools/run_godot_import_check.py` (a fresh worktree has nothing imported; it takes about a minute: start it with "
                  "`block_until_ms 0` and poll the output once, no skill needed); open the baselines the handoff lists (re-shoot only one that is missing or band=fail); read the files it lists; "
                  "then the first unit. Ask about what Open questions lists or what a discovery changes.")]
    elif mode == "survey":
        order = [("ORDER (survey): no import check and no shots yet. Survey from text: `python tools/run_shot_flow.py --survey`, `python tools/list_route.py --digest --door D`; write the survey as visible text, "
                  "then Q0, then which group first. A baseline you did not shoot in a survey is not a `Did not work` item. After her answers to the first ask: `python tools/start_build_slice.py --handoff`, then stop."),
                 Q0]
    else:
        order = [("ORDER: `python tools/check_gd_load.py` once and `python tools/run_godot_import_check.py` (a fresh worktree has nothing imported; it takes about a minute: start it with "
                  "`block_until_ms 0` and poll the output once, no skill needed); shoot the baseline and look at it yourself (band=fail is invalid: fix the cause, re-shoot); "
                  "write the restate as visible text; then Q0; then your other questions."),
                 Q0]
    return "\n".join(start + order + [
        "EVERY ASK has its own message first, a re-ask after changes included (\"same as before\" is not a message): the survey or restate, every PNG path with a one-line description "
        "(a changed set of pictures is a new list), the three ledger lines and `Did not work:` if any. Order: shoot, look at the pictures yourself, "
        "`python tools/show_png.py PATH=description ...` (opens them for her; expected, not a ledger item), the message, the ask. Option labels are not the message. "
        "Realise it was not sent: send it before your next tool call. In a survey of several surfaces the survey comes first; which group, the order and what she wants for each are separate questions after it.",
        "LEDGER, three lines, in every ask: \"Decisions I made that were yours\" (incl. new assets, fonts, dependencies, generated images, and look details you chose inside her rule: never \"none\" for those); \"Assumptions carried from memory or docs\"; "
        "\"Also changed\" (shared code and the other screens that use it, filled from `python tools/list_xref.py NAME` for each shared script you touched; states not shot; "
        "every write outside the worktree, Grok memory files included; temp files; reverts of generated churn such as `git checkout -- docs`). "
        f"Temp files go under `{(root / '_logs').as_posix()}/`; the commit message file is `{(root / '_logs' / 'commit-msg.txt').as_posix()}` (`git commit -F`). "
        "Before you write \"nothing was written outside this worktree\", check what you wrote and say exactly that.",
        "DID NOT WORK: any non-zero exit, `RESULT FAIL`, failed edit or skipped step, exploratory ones too, opens your next message. Do not write it from memory: "
        "`python tools/start_build_slice.py --failed` prints the lines from this session's failed tool results since your last ask (`show_png.py` prints them too); paste them first, and say so when there are none. "
        "A step this card's ORDER leaves out (a survey's baseline) is not skipped.",
        "ASK BEFORE THE CODE, not in a ledger line: a change in what a control does or in save or entry behaviour (a button that now saves, a changed trade) is her decision.",
        ("This tool never starts grok." if mode == "survey" else
         "COMMIT only when she says so, with `python tools/commit_slice.py` (it needs a passing `python tools/run_build_gate.py --batch --visual JOB` after your last edit; gate not run: "
         "`--gate-skipped \"why\"`, and open your final message with `Did not work: gate not run (why)`). "
         "THE END OF A UNIT: the settle ask shows the before and after PNG paths together, offers \"Good for now: commit, push, next unit\" and \"Change it\" (no \"Recommended\" on approving your own work), and your final message names the frames you opened. "
         "After her yes: gate, `commit_slice.py`, the push from the merge-back line, then `python tools/start_build_slice.py --next` for the next unit of a queue (its card, no new survey), or `--handoff` to write the next handoff (queue and done prefilled). "
         "Gates pass; that is not proof of a screen you did not open. This tool never starts grok."),
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


def merge_back_text(week: str) -> str:
    """The merge-back card line: a Grok worktree is a full clone on the week branch, so a green prove ends in a plain push of it."""
    ask = "balance, audio, visuals, controls: ask the User for playtest approval first. Commit and push only after she says the final shot is settled (or told you to commit now)"
    return (f"merge-back=this worktree is a full clone ON the week branch {week or 'grok-build-w{N}'} (not detached, no separate branch): on a green prove and her OK, commit here "
            f"and `git push origin {week or 'grok-build-w{N}'}` (plain push, never main, no force); nothing to merge by hand. {ask}")


def checkpoint(root: Path, args) -> int:
    """--checkpoint: save this (worktree) session's id so a red prove can fork it later from the worktree directory."""
    def fail(msg: str, route: str) -> int:
        return agent_log.finish("slice-boot", root, msg, "FAIL", args=args, write=not args.dry_run, route=route)

    if not is_linked(root):
        return fail("NOT A WORKTREE: this directory is a main checkout (not under .grok/worktrees/, and not a Grok worktree), so no checkpoint is saved. "
                    "Say so in your next message to the User (\"Did not work: --checkpoint, not a worktree\"). A slice is a Grok worktree: she starts one with `python tools/open_slice.py`, and --checkpoint runs in that session after gather.", "checkpoint-main")
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
    """Main checkout says no slice starts there; a Grok clone prints the card, then SLICE ALREADY STARTED (--full reprints); survey vs implementation ORDER; checkpoint."""
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
        if not step0_note("", "", "ui-demo", "") or "not a stop" not in step0_note("ui", "ui.x", "", "", "camp-a") or "camp-a" not in step0_note("ui", "ui.x", "", "", "camp-a"):
            bad.append("a visual slice with no flow must give the STEP 0 note (naming the door-only flows)")
        if step0_note("ui", "ui.pause", "", "camp-pause-menu") or step0_note("audio_visual", "", "", "") or step0_note("hub", "", "", ""):
            bad.append("flows mapped, or a non-visual name, must give no note")
        code, out = run(root, "--dry-run")
        if code != 0 or "MAIN CHECKOUT" not in out or "open_slice.py" not in out or "IN A WORKTREE" in out or "START 1" in out:
            bad.append("a main checkout must say no slice starts there and name open_slice.py")
        code, out = run(root, "--checkpoint", env="sess-1")
        if code == 0 or "NOT A WORKTREE" not in out:
            bad.append("--checkpoint in the main checkout must fail")
        git(root, "branch", "grok-build-w9")
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
        if code != 0 or "IN A WORKTREE" not in out or "full clone ON the week branch" not in out or "git push origin grok-build-w9" not in out:
            bad.append("boot in a Grok clone must say IN A WORKTREE and give the merge-back (push of the week branch)")
        if "worktree=wdb-demo-2" not in out or "Did not work:" not in out:
            bad.append("boot in a worktree must name the folder as the worktree and state the Did not work rule")
        for need in ("This tool is the first command", "Session facts", "not verified", "/session-info", "Q0", "EVERY ASK has its own message first", "Option labels are not the message",
                     "Also changed", "Grok memory files", "DID NOT WORK", "show_png.py", "not a ledger item", "commit-msg.txt", "check what you wrote", "block_until_ms 0", "inherited from earlier work",
                     "start_build_slice.py --failed", "ASK BEFORE THE CODE", "reuse <the existing asset or look>", "commit_slice.py", "gate not run", "before your next tool call"):
            if need.lower() not in out.lower():
                bad.append(f"the worktree first-message text lacks {need!r}")
        for banned in ("--checkpoint", "retry=", "did_not_work", "windows or programs opened", "is not showing it", "read by hand", "found by path", "shoot and open"):
            if banned in out.lower():
                bad.append(f"the worktree first-message text must not contain {banned!r}")
        rows = [{"type": "assistant", "tool_calls": [{"id": "a", "name": "run_terminal_command", "arguments": '{"command": "python tools/x.py"}'}]},
                {"type": "tool_result", "tool_call_id": "a", "content": "exit: 2\nx.py: error: bad flag"},
                {"type": "assistant", "tool_calls": [{"id": "b", "name": "search_replace", "arguments": '{"file_path": "f.gd"}'}]},
                {"type": "tool_result", "tool_call_id": "b", "content": "The string to replace was not found in the file"},
                {"type": "assistant", "tool_calls": [{"id": "c", "name": "run_terminal_command", "arguments": '{"command": "python tools/ok.py"}'}]},
                {"type": "tool_result", "tool_call_id": "c", "content": "exit: 0\nfine"},
                {"type": "assistant", "tool_calls": [{"id": "q", "name": "ask_user_question", "arguments": "{}"}]},
                {"type": "tool_result", "tool_call_id": "q", "content": "answer"},
                {"type": "assistant", "tool_calls": [{"id": "d", "name": "run_terminal_command", "arguments": '{"command": "python tools/y.py"}'}]},
                {"type": "tool_result", "tool_call_id": "d", "content": "exit: 0\nRESULT FAIL x=1"}]
        got = session_lib.failed_since_ask(rows[:6])
        if [g["what"] for g in got] != ["python tools/x.py", "f.gd"]:
            bad.append(f"failed steps before any ask: the non-zero exit and the failed edit, not the pass: {got}")
        got = session_lib.failed_since_ask(rows)
        if [g["what"] for g in got] != ["python tools/y.py"]:
            bad.append(f"failed steps after the last ask: only the RESULT FAIL one: {got}")
        # first run (not dry) writes the state; the second run says where the slice stands; --full reprints the card; a dry run always prints the card
        code, out = run(clone)
        if code != 0 or "IN A WORKTREE" not in out or not (clone / "_logs" / "slice-state.json").is_file():
            bad.append("the first run must print the card and write _logs/slice-state.json")
        code, out = run(clone)
        if code != 0 or "SLICE ALREADY STARTED" not in out or "Resuming at" not in out or "IN A WORKTREE" in out or "open_slice prompt not verified" not in out:
            bad.append("a second run must print SLICE ALREADY STARTED, the steps and the next one, not the card")
        code, out = run(clone, "--full")
        if code != 0 or "IN A WORKTREE" not in out or "SLICE ALREADY STARTED" in out:
            bad.append("--full must reprint the whole card")
        code, out = run(clone, "--dry-run")
        if "IN A WORKTREE" not in out:
            bad.append("a dry run must preview the card even when the slice started")
        # checkpoint in the clone
        code, out = run(clone, "--checkpoint")
        if code == 0 or "NO SESSION ID" not in out or "Did not work: --checkpoint" not in out or "/session-info" not in out or "grok sessions list" not in out:
            bad.append("--checkpoint in a clone with no id must fail with the Did not work line and where to get the id")
        code, out = run(clone, "--checkpoint", "--dry-run", env="sess-1")
        saved = retry_lib.state_path(clone)
        if code != 0 or (saved and saved.is_file() and "sess-1" in saved.read_text(encoding="utf-8")):
            bad.append("--checkpoint --dry-run must pass and save nothing")
        code, out = run(clone, "--checkpoint", env="sess-2")
        if code != 0 or "grok -r sess-2 --fork-session" not in out or "--cwd" in out or retry_lib.gather_for(clone).get("session") != "sess-2":
            bad.append("--checkpoint must save and print `grok -r ID --fork-session` without --cwd")
        code, out = run(clone)
        if "checkpoint yes" not in out:
            bad.append("the second run must show the checkpoint it finds")
        # routes fixture: a door with two jobs is a survey (text ORDER, no baseline shot); a job is an implementation slice; the flow is created first, then no STEP 0
        (clone / "design").mkdir(exist_ok=True)
        routes = clone / "design" / "routes.yaml"
        routes.write_text('version: 1\ndoors:\n  ui:\n    file: design/ui.md\n    read_when: "x"\n    jobs:\n      pause: design/ui-pause.md\n      menu: design/ui-menu.md\nshot_flows:\n  ui: "door-flow"\n', encoding="utf-8")
        code, out = run(clone, "--door", "ui", "--dry-run", area="")
        if code != 0 or "ORDER (survey)" not in out or "not a `Did not work` item" not in out or "shoot the baseline" in out or "mode=survey" not in out:
            bad.append("a door with several jobs must print the survey ORDER (text survey, the unshot baseline is not a Did-not-work item)")
        code, out = run(clone, "--job", "ui.pause", "--dry-run", area="")
        if code != 0 or "IN A WORKTREE" not in out or "STEP 0 (not a stop)" not in out or "door-flow" not in out or out.index("IN A WORKTREE") > out.index("STEP 0"):
            bad.append("a visual job with no flow of its own must print IN A WORKTREE, then STEP 0 naming the door-level flows")
        if "ORDER: " not in out or "ORDER (survey)" in out or "mode=implement" not in out:
            bad.append("a job is an implementation slice (the baseline ORDER)")
        routes.write_text(routes.read_text(encoding="utf-8") + '  ui.pause: "own-flow"\n', encoding="utf-8")
        code, out = run(clone, "--job", "ui.pause", "--dry-run", area="")
        if code != 0 or "STEP 0" in out:
            bad.append("once the flow is created and mapped by job, the door must print no STEP 0")
        code, out = run(clone, "--door", "ui", "--dry-run", area="")
        if code != 0 or "per job: ui.pause=own-flow" not in out:
            bad.append("a door with several jobs must show each job's own flows on the card")
        code, out = run(clone, "--door", "ui", "--area", "ui-redesign", "--dry-run", area="")
        if code != 0 or "WARN: --area 'ui-redesign'" not in out or "doors: ui" not in out:
            bad.append("an unknown --area must warn and list the valid doors")
        code, out = run(clone, area="", *())
        if code == 0 or "--door D" not in out or "doors: ui" not in out:
            bad.append("no --door/--job/--area must fail with the usage and the valid doors (so --help is not needed)")
        # unit queue: a door with unit_queue is not surveyed; the first unit not done is the slice; --next moves on once the unit is committed
        (clone / "design" / "ui-pause.md").write_text("# Pause\n\n## Inventory tab\n- x\n", encoding="utf-8")
        routes.write_text(routes.read_text(encoding="utf-8") + '  ui.menu: "menu-flow"\nunit_queue:\n  ui: "ui.pause, ui.menu"\nunit_docs:\n  ui.pause: "design/ui-pause.md#Inventory tab"\nshot_states:\n  ui.menu: "open"\n', encoding="utf-8")
        (clone / "_logs" / "slice-state.json").unlink()
        code, out = run(clone, "--door", "ui", area="")
        st_units = (__import__("json").loads((clone / "_logs" / "slice-state.json").read_text(encoding="utf-8")).get("units") or []) if (clone / "_logs" / "slice-state.json").is_file() else []
        if code != 0 or "ORDER (survey)" in out or "ui.pause (1 of 2)" not in out or "design/ui-pause.md L3-4 (## Inventory tab)" not in out or st_units != ["ui.pause", "ui.menu"]:
            bad.append("a door with unit_queue must start its first unit (not a survey): the unit line, the doc line range, the units in the state")
        code, out = run(clone, "--door", "ui", area="")
        if code != 0 or "SLICE ALREADY STARTED" not in out or "ui.pause is current (1 of 2)" not in out or "--next" not in out:
            bad.append("a second run on a unit queue must say which unit is current and name --next")
        code, out = run(clone, "--next", area="")
        if code == 0 or "uncommitted" not in out:
            bad.append("--next with the unit's changes uncommitted must fail and advance nothing")
        git(clone, "add", "-A")
        git(clone, "commit", "-qm", "unit")
        code, out = run(clone, "--next", area="")
        if code != 0 or "ui.menu (2 of 2)" not in out or "done: ui.pause" not in out or "state open" not in out or "RULES: unchanged" not in out or "IN A WORKTREE" in out:
            bad.append("--next must mark the unit done and print the next unit's card (its flow state included)")
        code, out = run(clone, "--next", area="")
        if code != 0 or "ALL UNITS DONE" not in out:
            bad.append("--next after the last unit must say all units are done")
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
