"""slice.py start / slice.py open helpers: the start-card text, the area check, the STEP 0 (missing flow) note and the selftests (`python tools/slice.py start --selftest`)."""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import agent_log
import repo_lib
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
            "and flow files (tools/data/shot-flows/) plus the routes.yaml mapping may be edited before the User answers. In the worktree: `python tools/shots.py flow --list` "
            "shows what exists; copy the nearest flow (shot-flows.md, New UI state checklist), point it at the screen, and map it by job. The session changing the screen shoots and reviews it (`shots.py review`). "
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

Q0 = ("Q0 (only if the task leaves it open): ask for the desired look, reference and bounds. "
      "Do not repeat settled questions. If options are needed, distinguish reuse from new art; do not recommend a look as a technical necessity.")

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

def in_worktree_text(root: Path, sdir: Path | None = None, mode: str = "implement", screen: bool = True) -> str:
    """Lean startup instructions; detailed rules have one owner in the Build guides."""
    lines = ["IN A WORKTREE: this directory is the slice; do not create another. This tool is the first command; later runs report saved progress (--full reprints)."]
    lines.append("DEFAULT: load the existing repository pc-offload skill once after this command; use it throughout the Build task, not once per operation. If absent, report it and use documented equivalents only when sufficient. This grants no machine/runtime permissions; no automatic MCP substitution.")
    if mode == "survey":
        lines += ["ORDER (survey): inspect text with `shots.py flow --survey` and `find.py route --digest --door D`. State the findings, ask about missing intent and which group first. No imports or shots yet; an absent survey baseline is not a `Did not work` item.",
                  Q0, "After the answers, `slice.py start --handoff`; fill and validate the task, then stop. build-handoff.md owns this procedure."]
    else:
        label = "ORDER (handoff)" if mode == "handoff" else "ORDER"
        lines += [f"{label}: for game work run `python tools/gate.py gd-load` and `python tools/gate.py import`; read the task and the route's code/docs, then state the outcome and unresolved questions. Continue in this session."]
        if mode == "handoff":
            lines.append("Restore only the saved survey edits and inspect its listed baselines; do not repeat the survey. Keep prior answers unless new evidence changes them.")
        if screen:
            lines.append("When this unit needs its screen, shoot the baseline and use `shots.py review PNG --question Q`; invalid or stale frames must be fixed, not called pre-existing. Do not capture unrelated screens during shared reading.")
        else:
            lines.append("NO PLAY CAMERA: no invented shot flow, play-camera baseline or --visual gate. Use the task's check; a keyed still uses `media.py rekey-preview` against its source plate. A rejected image is not an accepted reference.")
        lines += [Q0,
                  "CYCLE: understand outcome and cause; prepare missing evidence; implement; final verification; finish. CHANGE: `python tools/gate.py gd-load` once the edits are complete. Context breaks follow build-job-cycle.md: save state at a good stopping point and resume in this same session, not at a fixed verification milestone. Do not `/fork`.",
                  "VERIFY: relevant checks, the unit's flow/UI load check if visual, then `gate.py build --batch`. One small corrective edit and one rerun; still red, report the log. Read each result/summary. build-job-cycle.md and prove.md own verification.",
                  "FINISH: update docs/task; --unit-done for a queue; revoke temporary reference grants; `slice.py commit`, plain push to the week branch, then the done notice. Record red/skipped gates honestly. Finish the whole request in this session when it fits; save unfinished work in the task."]
    lines += ["EVERY ASK has its own message first: current result, relevant paths/descriptions, proposed change and unknowns. Option labels are not the message. Use `shots.py show PATH=description ...` when the User should see images; before/after of one area share a sheet.",
              "DID NOT WORK: put `Did not work: COMMAND REASON` first. `slice.py start --failed` supplies failed tool results since the last ask; paste them first, not from memory. ASK BEFORE THE CODE for unsettled design or behavior, even with always-allow access.",
              "IMAGES: isolated review by default; necessary direct visual references use `slice.py references grant` (build-references.md). OCR-first is for text. A reference grant does not authorize generation or change host permissions.",
              f"FILES: temporary scripts under `{(root / '_logs/agent-py').as_posix()}` use `session.py py`; reusable scripts belong in tools/ with a catalog row. Commit message: `{(root / '_logs/commit-msg.txt').as_posix()}`. Disclose assumptions, shared effects and outside-worktree writes; do not claim none without checking.",
              "This tool never starts grok. Only the User opens implementation sessions. After the push, show required evidence and state whether playtest confirmation is required, recommended or not needed; do not ask permission just to commit. Stop after the task."]
    return "\n".join(lines)

def doors_hint(root: Path) -> str:
    """'doors: a, b, c; jobs are door.job (python tools/find.py route lists them)' from routes.yaml, or ''."""
    try:
        from load_routes import load_routes

        doors = sorted((load_routes(root).get("doors") or {}).keys())
    except Exception:
        return ""
    return f"doors: {', '.join(doors)}; jobs are door.job (`python tools/find.py route` lists them)" if doors else ""

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
    note = ("after the push, say whether a playtest confirmation is required (balance, audio, visuals, controls), "
            "recommended (feel, hitch, or timing the gates do not score), or not needed (a refactor, tool, doc, or test). "
            "Do not ask, and do not wait for a reply before the commit or the push")
    return (f"merge-back=this worktree is a full clone ON the week branch {week or 'grok-build-w{N}'} (not detached, no separate branch): "
            f"cleanup + gate + slice.py commit + plain `git push origin {week or 'grok-build-w{N}'}` finish first; then that notice. {note}")

def selftest(script: list[str]) -> int:
    """Main checkout says no slice starts there; a Grok clone prints the card, then SLICE ALREADY STARTED (--full reprints); survey vs implementation ORDER; forked session; retry block; unit queue."""
    me = list(script)
    from build_docs_test import check as check_docs
    bad: list[str] = check_docs(Path(__file__).resolve().parents[3])

    def run(root: Path, *a: str, area: str = "demo", env: str = "") -> tuple[int, str]:
        cmd = [*me, "--root", str(root)] + (["--area", area] if area else []) + list(a)
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", env={**os.environ, "GROK_SESSION_ID": env})
        return p.returncode, p.stdout + p.stderr

    git = repo_lib.git_test

    with tempfile.TemporaryDirectory() as td:
        root = repo_lib.selftest_repo(td, empty_commit=True)
        if not step0_note("", "", "ui-demo", "") or "not a stop" not in step0_note("ui", "ui.x", "", "", "camp-a") or "camp-a" not in step0_note("ui", "ui.x", "", "", "camp-a"):
            bad.append("a visual slice with no flow must give the STEP 0 note (naming the door-only flows)")
        if step0_note("ui", "ui.pause", "", "camp-pause-menu") or step0_note("audio_visual", "", "", "") or step0_note("hub", "", "", ""):
            bad.append("flows mapped, or a non-visual name, must give no note")
        code, out = run(root, "--dry-run")
        if code != 0 or "MAIN CHECKOUT" not in out or "slice.py open" not in out or "IN A WORKTREE" in out or "START 1" in out:
            bad.append("a main checkout must say no slice starts there and name slice.py open")
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
        for need in ("This tool is the first command", "Q0", "EVERY ASK has its own message first", "Option labels are not the message",
                     "DID NOT WORK", "shots.py show", "commit-msg.txt", "slice.py start --failed", "ASK BEFORE THE CODE",
                     "slice.py commit", "Do not `/fork`", "resume in this same session", "final verification",
                     "gate.py gd-load` once the edits are complete", "whole request in this session", "references grant"):
            if need.lower() not in out.lower():
                bad.append(f"the worktree first-message text lacks {need!r}")
        for banned in ("--checkpoint", "retry=", "did_not_work", "windows or programs opened", "is not showing it", "read by hand", "found by path", "shoot and open"):
            if banned in out.lower():
                bad.append(f"the worktree first-message text must not contain {banned!r}")
        if "NO PLAY CAMERA" not in out or "shoot the baseline" in out:
            bad.append("a job with no shot flow must not ask for a play-camera baseline")
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
        bg = [{"type": "assistant", "tool_calls": [{"id": "r", "name": "run_terminal_command", "arguments": '{"command": "python tools/shots.py review a.png"}'}]},
              {"type": "tool_result", "tool_call_id": "r", "content": "Status: failed\nExit Code: 1\nRESULT FAIL reason=isolated session exited 1"}]
        got = session_lib.failed_since_ask(bg)
        if [g["what"] for g in got] != ["python tools/shots.py review a.png"]:
            bad.append(f"a background Exit Code must count as Did not work: {got}")
        # first run (not dry) writes the state; the second run says where the slice stands; --full reprints the card; a dry run always prints the card
        code, out = run(clone, env="sess-1")
        if code != 0 or "IN A WORKTREE" not in out or not (clone / "_logs" / "slice-state.json").is_file() or retry_lib.original(clone).get("session") != "sess-1":
            bad.append("the first run must print the card and write _logs/slice-state.json")
        code, out = run(clone, env="sess-1")
        (clone / ".godot" / "imported").mkdir(parents=True)
        (clone / "_logs" / "shot-flow" / "f").mkdir(parents=True)
        (clone / "_logs" / "shot-flow" / "f" / "flow.json").write_text("{}")
        code, out = run(clone, env="sess-1")
        if code != 0 or "SLICE ALREADY STARTED" not in out or "Resuming at" not in out or "IN A WORKTREE" in out or "open_slice prompt not verified" not in out:
            bad.append("a second run must print SLICE ALREADY STARTED, the steps and the next one, not the card")
        if "original session sess-1" not in out or "forked no" not in out or "resume in this same session" not in out:
            bad.append("a second run in the original session must name its id and resume in this same session")
        code, out = run(clone, env="sess-2")
        if "forked yes" not in out or "Prepare / Change / Prove / Complete" not in out or "(first run by session sess-1; this is sess-2)" not in out:
            bad.append("a run in the forked peer session must say so and resume at Prepare / Change / Prove / Complete")
        run(clone, "--full", env="sess-2")
        if retry_lib.original(clone).get("session") != "sess-1":
            bad.append("a --full run in the forked peer must not overwrite the original session id")
        code, out = run(clone, "--full")
        if code != 0 or "IN A WORKTREE" not in out or "SLICE ALREADY STARTED" in out:
            bad.append("--full must reprint the whole card")
        code, out = run(clone, "--dry-run")
        if "IN A WORKTREE" not in out:
            bad.append("a dry run must preview the card even when the slice started")
        rb = retry_lib.block(clone, "gate", ["SCRIPT ERROR: x"])
        if "Retry stays in this session (sess-1)" not in rb or "Do not run `grok -r sess-1 --fork-session`" not in rb or "--cwd" in rb or "--checkpoint" in rb:
            bad.append("the RETRY block must stay in this session (the first run's id) and must not tell the User to fork")
        # routes fixture: a door with two jobs is a survey (text ORDER, no baseline shot); a job is an implementation slice; the flow is created first, then no STEP 0
        (clone / "design").mkdir(exist_ok=True)
        routes = clone / "design" / "routes.yaml"
        routes.write_text('version: 1\ndoors:\n  ui:\n    file: design/ui.md\n    read_when: "x"\n    jobs:\n      pause: design/ui-pause.md\n      menu: design/ui-menu.md\nshot_flows:\n  ui: "door-flow"\n', encoding="utf-8")
        code, out = run(clone, "--door", "ui", "--dry-run", area="")
        if code != 0 or "ORDER (survey)" not in out or "not a `Did not work` item" not in out or "shoot the baseline" in out or "mode=survey" not in out:
            bad.append("a door with several jobs must print the survey ORDER (text survey, the unshot baseline is not a Did-not-work item)")
        code, out = run(clone, "--job", "ui.pause", "--dry-run", area="")
        if code != 0 or "IN A WORKTREE" not in out or "STEP 0 (not a stop)" not in out or "door-flow" not in out or out.index("IN A WORKTREE") > out.index("STEP 0") or "shoot the baseline" not in out:
            bad.append("a visual job with no flow of its own must print IN A WORKTREE, then STEP 0 naming the door-level flows, and still ask for the baseline")
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
        # unit queue: a door with unit_queue is not surveyed; the first unit not done is the slice; --unit-done marks it done (the next unit is a new session)
        (clone / "design" / "ui-pause.md").write_text("# Pause\n\n## Inventory tab\n- x\n", encoding="utf-8")
        routes.write_text(routes.read_text(encoding="utf-8") + '  ui.menu: "menu-flow"\nunit_queue:\n  ui: "ui.pause, ui.menu"\nunit_docs:\n  ui.pause: "design/ui-pause.md#Inventory tab"\nshot_states:\n  ui.menu: "open"\n', encoding="utf-8")
        (clone / "_logs" / "slice-state.json").unlink()
        code, out = run(clone, "--door", "ui", area="")
        st_units = (__import__("json").loads((clone / "_logs" / "slice-state.json").read_text(encoding="utf-8")).get("units") or []) if (clone / "_logs" / "slice-state.json").is_file() else []
        if code != 0 or "ORDER (survey)" in out or "ui.pause (1 of 2)" not in out or "design/ui-pause.md L3-4 (## Inventory tab)" not in out or st_units != ["ui.pause", "ui.menu"]:
            bad.append("a door with unit_queue must start its first unit (not a survey): the unit line, the doc line range, the units in the state")
        code, out = run(clone, "--door", "ui", area="")
        if code != 0 or "SLICE ALREADY STARTED" not in out or "ui.pause is current (1 of 2)" not in out or "--unit-done" not in out or "--next" in out:
            bad.append("a second run on a unit queue must say which unit is current and name --unit-done (never --next)")
        code, out = run(clone, "--unit-done", area="")
        st = __import__("json").loads((clone / "_logs" / "slice-state.json").read_text(encoding="utf-8"))
        qt = clone / "design" / "tasks" / "ui-units.md"
        if code != 0 or "UNIT DONE: ui.pause" not in out or "Next unit: ui.menu" not in out or "IN A WORKTREE" in out or st.get("done") != ["ui.pause"] or st.get("unit") != "ui.menu":
            bad.append("--unit-done must mark the unit done, make the next one current and print no card")
        if not qt.is_file() or "done: ui.pause" not in qt.read_text(encoding="utf-8") or "units: ui.pause, ui.menu" not in qt.read_text(encoding="utf-8") or st.get("task") != "ui-units" or "design/tasks/ui-units.md" not in out:
            bad.append("--unit-done with units left and no task file must write design/tasks/ui-units.md (queue + done) and name it")
        code, out = run(clone, "--door", "ui", "--full", area="")
        if code != 0 or "ui.menu (2 of 2)" not in out:
            bad.append("after --unit-done, `--door ui` must print the next unit's card in the same session")
        (clone / "_logs" / "slice-state.json").unlink()
        code, out = run(clone, "--door", "ui", area="", env="new-sess")
        if retry_lib.original(clone).get("session") != "new-sess":
            bad.append("a new session resuming from a task file runs its own Gather: it is the original for its unit")
        if code != 0 or "ui.menu (2 of 2)" not in out:
            bad.append("a new session on the door must resume the queue from design/tasks/ui-units.md, not unit 1")
        if "RESUMING UNIT QUEUE from task ui-units" not in out or "unit 2 of 2 (ui.menu)" not in out or "survey done" in out:
            bad.append("a queue resumed from a task must say so (unit N of M), not 'survey done'")
        plain = Path(td) / "plain" / "worktrees" / "repos-demo" / "wdb-demo-3"
        plain.parent.mkdir(parents=True)
        git(Path(td), "clone", "-q", str(root), str(plain))
        if worktree_kind(plain) != "" or worktree_kind(root) != "":
            bad.append("a full clone outside .grok/worktrees, and the main checkout, are not worktrees")
        (clone / "design/tasks/model.md").write_text("# Model\nid: model\nowner: build\nstatus: open\n\n## Goal\nMatch references.\n")
        code, out = run(clone, "--job", "ui.pause", "--task", "model", "--full", area="", env="new-sess")
        bound = __import__("json").loads((clone / "_logs/slice-state.json").read_text())
        if code or bound.get("task") != "model":
            bad.append("a normal --task without a unit queue must bind reference access to that active task")
    return agent_log.selftest_result(bad)

def retry_selftest() -> int:
    """RETRY block in a throwaway git repo: with the original session recorded, without it, with a first-run --ref, without a base."""
    import json
    git = repo_lib.git_test

    def state(wt: Path, **kv: str) -> None:
        (wt / "_logs").mkdir(exist_ok=True)
        (wt / "_logs" / "slice-state.json").write_text(json.dumps(kv), encoding="utf-8")

    bad: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        main = Path(td) / "main"
        main.mkdir()
        git(main, "init", "-q")
        (main / ".gitignore").write_text("_logs/\n")
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
        for need in ("NO SESSION ID", "Retry stays in this session", "Do not `/fork`", "git diff grok-build-w9", "Nothing is started for you", "final verification"):
            if need not in no_ses:
                bad.append(f"no-session block lacks {need!r}")
        state(wt, session="abc-123", ref="")
        with_ses = retry_lib.block(wt, "gate", red)
        for need in ("Retry stays in this session (abc-123)", "Do not run `grok -r abc-123 --fork-session`", f"cd {wt}", "git diff grok-build-w9", "b.txt", "one small corrective edit", "report the log path"):
            if need not in with_ses:
                bad.append(f"session block lacks {need!r}")
        if "--cwd" in with_ses or "checkpoint" in with_ses.lower() or "diagnosis" in with_ses:
            bad.append("session block must not use --cwd, a checkpoint or the old one-diagnosis wording")
        other = Path(td) / "wdb-other"
        git(main, "worktree", "add", "-q", "--detach", str(other), "grok-build-w9")
        if "abc-123" in retry_lib.block(other, "gate", red):
            bad.append("another worktree must not name this worktree's session")
        (wt / "a.txt").write_text("edited\n")
        (wt / "new.txt").write_text("untracked\n")
        dirty = retry_lib.block(wt, "gate", red)
        if "a.txt" not in dirty or "new.txt" not in dirty:
            bad.append("uncommitted and untracked files must be listed")
        if retry_lib.strip(["top", *dirty.splitlines(), "bottom"]) != ["top", "bottom"]:
            bad.append("a nested RETRY block must be stripped")
        bot = Path(td) / "bot-wt"
        git(main, "worktree", "add", "-q", "-b", "vendor-fixes", str(bot), "grok-build-w9")
        state(bot, session="abc-123", ref="")
        if retry_lib.block(bot, "gate", red) or retry_lib.block(main, "gate", red):
            bad.append("a Bot branch (vendor-fixes, even with slice state) or main must get no Build RETRY block")
        if repo_lib.diff_base(bot) == "grok-build-w9" or repo_lib.head_kind(wt) != "build" or repo_lib.head_kind(bot) != "bot":
            bad.append("branch kind: detached wdb-* is Build (no changelog, week-branch base); vendor-fixes is Bot (never the week branch as base)")
        kinds = [repo_lib.branch_kind(n) for n in ("grok-build-w9", "grok-web-w3", "main", "bot/x", "vendor-fixes", "grok-build-w9-fix", "HEAD")]
        if kinds != ["build", "web", "main", "bot", "bot", "bot", "detached"]:
            bad.append(f"branch_kind table wrong: {kinds}")
        git(main, "worktree", "remove", "--force", str(bot))
        git(main, "branch", "-D", "grok-build-w9")
        gone = retry_lib.block(wt, "gate", red)
        if "NO BASE" not in gone or "git diff" in gone:
            bad.append("no-base block wrong")
        state(wt, session="abc-123", ref="my-ref")
        if "git diff my-ref`" not in retry_lib.block(wt, "gate", red):
            bad.append("the first run's --ref must be the base")
    return agent_log.selftest_result(bad)
