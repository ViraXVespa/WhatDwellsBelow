"""Survey -> implement handoff for Grok Build (library for start_build_slice.py and open_slice.py; import only).

A survey session ends when she has answered its first ask: Build writes the handoff as a task file, `design/tasks/<id>.md` (task_lib; the id
defaults to the door), and stops.
`python tools/start_build_slice.py --handoff` writes the skeleton, then validates the filled file and prints the one command she runs from the
main checkout: `python tools/open_slice.py AREA --prompt-file PATH`. The file becomes the first message of a NEW session, whose first command
`start_build_slice.py --door D --from-handoff PATH` prints a compact start summary and points the file's first command at `--from-task ID`, so
the committed task resumes from any checkout. This is not the checkpoint: `--checkpoint` saves the id of an
implementation session so a red prove can fork it; the handoff moves a survey into a fresh implementation session.
The fresh worktree is cut from the week branch, so survey-session edits to shot-flow files and the routes.yaml mapping are saved to
`_logs/handoff/survey-edits/` (the task file with them) and put back by `--from-handoff` (a file that differs is only listed when the week branch moved).
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import task_lib

EDITS_REL = "_logs/handoff/survey-edits"
CARRY = ("tools/shot-flows/", "design/routes.yaml", "design/tasks/")  # the only files a survey session may change before she answers
FILL = "<fill"
SECTIONS = [
    ("Task (her words)", "<fill: the task as she wrote it>"),
    ("Q0 answers so far", "- result look: <fill>\n- reference: <fill or none>\n- out of bounds, incl. frames or layouts already built: <fill>"),
    ("Her decisions", "<fill: each answer she gave, one line each, or none>"),
    ("Chosen surfaces, in order", "<fill: one per line, the first is this session's unit>"),
    ("Ledger", "Decisions I made that were yours: <fill or none>\nAssumptions carried from memory or docs: <fill or none>\nAlso changed: <fill or none>"),
    ("Baselines for the chosen surface", "<fill: absolute PNG path - one line on what is on it; or `none` and the flow names to shoot>"),
    ("Files and functions to touch", "<fill: path: function>"),
    ("Did not work", "<fill or none>"),
    ("Open questions", "<fill or none>"),
]


def task_id(root: Path, task: str = "") -> str:
    """The handoff's task id: given, else the slice state's task, else its door."""
    if task:
        return task
    try:
        st = json.loads((root / "_logs" / "slice-state.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        st = {}
    return str(st.get("task") or st.get("door") or "")


def handoff_path(root: Path, task: str = "") -> Path:
    return task_lib.task_path(root, task_id(root, task) or "handoff")


def edits_dir(handoff: Path) -> Path:
    """Where a handoff's survey edits live: <survey root>/_logs/handoff/survey-edits (an old _logs handoff kept them beside itself)."""
    if handoff.parent.name == "tasks" and handoff.parent.parent.name == "design":
        return handoff.parents[2] / EDITS_REL
    return handoff.parent / "survey-edits"


def from_task_cmd(door: str, tid: str) -> str:
    return f"python tools/start_build_slice.py --door {door or '<door>'} --from-task {tid}"


def _git(root: Path, *a: str) -> str:
    p = subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.stdout.strip() if p.returncode == 0 else ""


def skeleton(root: Path, area: str, door: str, job: str, session: str = "", units: list[str] | None = None, done: list[str] | None = None, task: str = "") -> str:
    path = handoff_path(root, task)
    first = f'python tools/start_build_slice.py --door {door or "<door>"}' + (f" --job {job}" if job else "") + f' --from-handoff "{path}"'
    head = [f"# Handoff: {area}", f"id: {path.stem}", "owner: build", "status: active", "done-when: <fill: when this task is finished, in her words>",
            f"area: {area}", f"door: {door}", f"job: {job}"]
    if units:  # a door worked as a queue of units: the order and what is done travel with the handoff
        head += ["units: " + ", ".join(units), "done: " + (", ".join(done) if done else "none")]
    head += [f"from: survey session {session or '(id unknown)'} in {root}",
             f"Your first command, before any file read or memory topic: {first}",
             "The survey is done and the answers below stand; ask again only what Open questions lists or what a discovery changes. "
             "Open no pictures except the baselines listed for the chosen surface.", ""]
    body: list[str] = []
    for title, hint in SECTIONS:
        body += [f"## {title}", hint, ""]
    return "\n".join(head + body)


def parse(text: str) -> tuple[dict[str, str], dict[str, str]]:
    """(header key -> value, section title -> body)"""
    head: dict[str, str] = {}
    secs: dict[str, str] = {}
    cur = None
    for line in text.splitlines():
        if line.startswith("## "):
            cur = line[3:].strip()
            secs[cur] = ""
        elif cur is None:
            m = re.match(r"(area|door|job|units|done):\s*(.*)$", line)
            if m:
                head[m.group(1)] = m.group(2).strip()
        else:
            secs[cur] += line + "\n"
    return head, {k: v.strip() for k, v in secs.items()}


def baselines(root: Path, body: str) -> list[tuple[str, bool, str]]:
    """(path, exists, note) per non-empty line of the baselines section; the note follows ' - ' or an em dash."""
    out = []
    for line in body.splitlines():
        line = line.strip().lstrip("-* ").strip()
        if not line or line.lower().startswith("none"):
            continue
        m = re.split(r"\s+(?:-|\u2014|\u2013)\s+", line, maxsplit=1)
        p, note = m[0].strip().strip('"`'), (m[1].strip() if len(m) > 1 else "")
        q = Path(p)
        out.append((p, (q if q.is_absolute() else root / q).is_file(), note))
    return out


def code_names(root: Path, body: str) -> list[str]:
    """Problems with `path: name, name` lines of the Files and functions section: the file must exist, and each plain identifier listed must be in it (a func, const or var)."""
    bad: list[str] = []
    for line in body.splitlines():
        m = re.match(r"[-*\s]*`?([\w./-]+\.(?:gd|py))`?\s*:\s*(.+)$", line.strip())
        if not m:
            continue
        f = root / m.group(1)
        if not f.is_file():
            bad.append(f"Files and functions: no file {m.group(1)}")
            continue
        src = f.read_text(encoding="utf-8-sig", errors="replace")
        for piece in re.split(r"\.\s", m.group(2), maxsplit=1)[0].split(","):
            name = piece.strip().strip("`")
            if re.fullmatch(r"[A-Za-z_]\w*", name) and not re.search(r"\b%s\b" % re.escape(name), src):
                bad.append(f"Files and functions: {m.group(1)} has no {name}")
    return bad


def check(root: Path, text: str) -> list[str]:
    """Problems that stop the handoff from being ready."""
    head, secs = parse(text)
    bad: list[str] = []
    if any(FILL in line for line in text.split("\n## ", 1)[0].splitlines()):
        bad.append("header has an unfilled line (done-when)")
    if not head.get("area"):
        bad.append("header has no `area:` line")
    if head.get("units"):
        units = [u.strip() for u in head["units"].split(",") if u.strip()]
        done = [u.strip() for u in head.get("done", "").split(",") if u.strip() and u.strip() != "none"]
        if any("." not in u for u in units) or [d for d in done if d not in units]:
            bad.append("header `units:` / `done:` must be door.job ids, and done a subset of units")
    for title, _ in SECTIONS:
        body = secs.get(title)
        if body is None:
            bad.append(f"section missing: {title}")
        elif not body or FILL in body:
            bad.append(f"section not filled in: {title}")
    bad += code_names(root, secs.get("Files and functions to touch", ""))
    for p, ok, note in baselines(root, secs.get("Baselines for the chosen surface", "")):
        if not ok:
            bad.append(f"baseline not found: {p}")
        elif not note:
            bad.append(f"baseline has no one-line description: {p}")
    return bad


def survey_edits(root: Path) -> list[str]:
    """Changed or new paths outside _logs/ (what the fresh worktree will not have)."""
    p = subprocess.run(["git", "status", "--porcelain=v1", "-uall"], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = p.stdout if p.returncode == 0 else ""
    paths = []
    for line in out.splitlines():
        p = line[3:].strip().strip('"')
        if " -> " in p:
            p = p.split(" -> ", 1)[1]
        if p and not p.startswith("_logs/"):
            paths.append(p)
    return paths


def sidecars(paths: list[str]) -> tuple[list[str], int]:
    """(paths without Godot `.import` sidecars, how many sidecars there were): the sidecars are import churn, so they are counted, not listed."""
    keep = [p for p in paths if not p.endswith(".import")]
    return keep, len(paths) - len(keep)


def save_edits(root: Path) -> tuple[list[str], list[str]]:
    """Copy the carried survey edits (the task file too) to _logs/handoff/survey-edits; returns (saved, not_carried)."""
    dest = root / EDITS_REL
    if dest.exists():
        shutil.rmtree(dest)
    saved, other = [], []
    for p in survey_edits(root):
        if any(p == c or p.startswith(c) for c in CARRY) and (root / p).is_file():
            t = dest / "files" / p
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / p, t)
            saved.append(p)
        else:
            other.append(p)
    if saved:
        (dest / "base.txt").write_text(_git(root, "rev-parse", "HEAD") + "\n", encoding="utf-8")
    return saved, other


def restore_edits(handoff: Path, root: Path) -> list[str]:
    """Put the saved survey edits into this (fresh) worktree: new files always; a file that exists is replaced only when HEAD is the survey's base."""
    src = edits_dir(handoff)
    files = src / "files"
    if not files.is_dir():
        return []
    base = (src / "base.txt").read_text(encoding="utf-8").strip() if (src / "base.txt").is_file() else ""
    same = bool(base) and base == _git(root, "rev-parse", "HEAD")
    lines = []
    for f in sorted(x for x in files.rglob("*") if x.is_file()):
        rel = f.relative_to(files).as_posix()
        t = root / rel
        if not t.exists() or (same and t.read_bytes() != f.read_bytes()):
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, t)
            lines.append(f"restored {rel}")
        elif t.read_bytes() != f.read_bytes():
            lines.append(f"DIFFERS, not copied (the week branch moved since the survey): {rel}; the survey's copy is {f}")
    return lines


def command(root: Path, area: str, path: Path) -> str:
    return f'python tools/open_slice.py {area} --prompt-file "{path}"'


def start_block(root: Path, path: Path, queue: bool = False, restore: bool = True) -> list[str]:
    """What a fresh session prints for --from-handoff: where it came from and what to open; the full text is already its first message."""
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        return [f"HANDOFF: cannot read {path} ({exc}). Ask the User; do not re-run the survey."]
    head, secs = parse(text)
    lines = [f"HANDOFF from {path}: survey done. area={head.get('area', '')} door={head.get('door', '')} job={head.get('job', '')}",
             "Do not re-run the survey and do not open pictures other than the baselines below. Q0 answers, decisions and the ledger are in the handoff; they stand."]
    if head.get("units"):
        units = [u.strip() for u in head["units"].split(",") if u.strip()]
        done = [u.strip() for u in head.get("done", "").split(",") if u.strip() and u.strip() != "none"]
        cur = next((u for u in units if u not in done), "")
        lines.append(f"Units, her order: {', '.join(units)}. Done: {', '.join(done) or 'none'}. Current: {cur or 'all done'}. "
                     "After a unit is committed and shown, `python tools/start_build_slice.py --next` prints the next unit's card (no new survey).")
    for title in (() if queue else ("Chosen surfaces, in order", "Files and functions to touch", "Did not work", "Open questions")):  # a queue: those sections are in the first message already
        lines.append(f"{title}: " + " | ".join(l.strip().lstrip("-* ") for l in secs.get(title, "").splitlines() if l.strip()))
    bl = baselines(root, secs.get("Baselines for the chosen surface", ""))
    lines.append("Open these baselines (only these): " + ("; ".join(f"{p}{'' if ok else ' (MISSING: re-shoot it)'} - {n}" for p, ok, n in bl)
                                                           or "none listed (the Baselines section names the flows to shoot)"))
    lines += restore_edits(path, root) if restore else []
    bad = check(root, text)
    if bad:
        lines.append("HANDOFF problems: " + "; ".join(bad))
    return lines


def selftest(script: Path) -> list[str]:
    """Handoff cases for start_build_slice.py --selftest; returns the failures."""
    import os
    import sys
    import tempfile

    bad: list[str] = []

    def run(root: Path, *a: str) -> tuple[int, str]:
        p = subprocess.run([sys.executable, str(script), "--root", str(root), *a], capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env={**os.environ, "GROK_SESSION_ID": ""})
        return p.returncode, p.stdout + p.stderr

    def git(cwd: Path, *a: str) -> None:
        subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *a], cwd=cwd, check=True, capture_output=True)

    with tempfile.TemporaryDirectory() as td:
        main = Path(td) / "main"
        main.mkdir()
        git(main, "init", "-q")
        (main / "project.godot").write_text("")
        (main / "scripts" / "data").mkdir(parents=True)
        (main / "scripts" / "data" / "version.json").write_text('{"epoch": 0, "series": 9, "patch": 0}\n')
        (main / "design").mkdir()
        (main / "design" / "routes.yaml").write_text("version: 1\ndoors:\n  ui:\n    file: design/ui.md\n    read_when: x\n    jobs:\n      pause: design/ui-pause.md\n", encoding="utf-8")
        git(main, "add", "-A")
        git(main, "commit", "-qm", "a")
        git(main, "branch", "grok-build-w9")
        survey = Path(td) / "h" / ".grok" / "worktrees" / "repos-demo" / "wdb-survey"
        survey.parent.mkdir(parents=True)
        git(Path(td), "clone", "-q", str(main), str(survey))
        git(survey, "checkout", "-q", "-B", "grok-build-w9", "origin/grok-build-w9")
        code, out = run(main, "--handoff", "--door", "ui")
        if code == 0 or "worktree" not in out.lower():
            bad.append("--handoff in a main checkout must fail and say it belongs in the survey worktree")
        sk = skeleton(survey, "ui", "ui", "", "s1", ["ui.a", "ui.b"], ["ui.a"])
        first_line = next((l for l in sk.splitlines() if l.startswith("Your first command")), "")
        if parse(sk)[0].get("units") != "ui.a, ui.b" or parse(sk)[0].get("done") != "ui.a" or "--job" in first_line:
            bad.append("a skeleton for a unit queue must carry units / done header lines and a first command without --job")
        if not any("units" in b for b in check(survey, "area: x\nunits: nodot\ndone: none\n")) or any("units" in b for b in check(survey, sk)):
            bad.append("check must reject units that are not door.job ids and accept a queue with done a subset of units")
        if not any("no file" in b for b in code_names(survey, "- scripts/none.gd: f")) or code_names(survey, "- design/ui.md: not an identifier here"):
            bad.append("Files and functions: a missing file must be named; a description that is not a plain name is not checked")
        hp = survey / "design" / "tasks" / "ui.md"
        (survey / "_logs").mkdir(exist_ok=True)
        (survey / "_logs" / "slice-state.json").write_text('{"door": "ui", "job": "", "area": ""}\n', encoding="utf-8")
        code, out = run(survey, "--handoff")
        if code != 0 or not hp.is_file() or "area: ui" not in hp.read_text(encoding="utf-8"):
            bad.append("a bare --handoff must take the door from _logs/slice-state.json")
        if hp.is_file():
            hp.unlink()
        code, out = run(survey, "--handoff", "--door", "ui", "--job", "ui.pause", "--area", "ui")
        if code != 0 or not hp.is_file() or "fill" not in out.lower() or "open_slice.py" in out:
            bad.append("--handoff with no file must write the skeleton, say what to fill, and print no launch command yet")
        code, out = run(survey, "--handoff")
        if code == 0 or "not filled in" not in out:
            bad.append("an unfilled handoff must fail naming the sections")
        (survey / "tools" / "shot-flows").mkdir(parents=True)
        (survey / "tools" / "shot-flows" / "new-flow.json").write_text('{"name": "new-flow"}\n', encoding="utf-8")
        (survey / "design" / "routes.yaml").write_text((survey / "design" / "routes.yaml").read_text(encoding="utf-8") + "shot_flows:\n  ui.pause: new-flow\n", encoding="utf-8")
        png = survey / "_logs" / "shot-flow" / "x" / "01-a.png"
        png.parent.mkdir(parents=True)
        png.write_bytes(b"png")
        text = hp.read_text(encoding="utf-8")
        for title, _ in SECTIONS:
            text = re.sub(r"(## " + re.escape(title) + r"\n)(.*?)(\n\n|\Z)", lambda m: m.group(1) + "filled line\n\n", text, count=1, flags=re.S)
        text = text.replace("<fill: when this task is finished, in her words>", "when she says so")
        text = re.sub(r"(## Baselines for the chosen surface\n)filled line", lambda m: m.group(1) + f"{png} - the pause page, before", text)
        hp.write_text(text, encoding="utf-8")
        (survey / "assets").mkdir()
        (survey / "assets" / "churn-one.png.import").write_text("x")
        (survey / "assets" / "churn-two.png.import").write_text("x")
        code, out = run(survey, "--handoff")
        if "churn-one" in out or "2 Godot .import sidecars" not in out:
            bad.append("Godot .import sidecars must be counted in the handoff output, not listed by name")
        if code != 0 or 'open_slice.py ui --prompt-file "' not in out or "new-flow.json" not in out or "routes.yaml" not in out:
            bad.append(f"a filled handoff must pass, print the open_slice command and name the saved survey edits (code={code})")
        if not (survey / EDITS_REL / "files" / "tools" / "shot-flows" / "new-flow.json").is_file():
            bad.append("the survey's new flow file must be saved next to the handoff")
        text2 = hp.read_text(encoding="utf-8").replace(f"{png} - the pause page, before", f"{png}")
        hp.write_text(text2, encoding="utf-8")
        code, out = run(survey, "--handoff")
        if code == 0 or "no one-line description" not in out:
            bad.append("a baseline with no description must fail")
        hp.write_text(text, encoding="utf-8")
        fresh = Path(td) / "h" / ".grok" / "worktrees" / "repos-demo" / "wdb-fresh"
        git(Path(td), "clone", "-q", str(main), str(fresh))
        git(fresh, "checkout", "-q", "-B", "grok-build-w9", "origin/grok-build-w9")
        code, out = run(fresh, "--door", "ui", "--from-handoff", str(hp), "--dry-run")
        if (code != 0 or "HANDOFF from" not in out or "Do not re-run the survey" not in out or "restored tools/shot-flows/new-flow.json" not in out
                or "restored design/routes.yaml" not in out or "pause page, before" not in out):
            bad.append(f"--from-handoff must print the compact summary, the listed baselines and restore the survey edits (code={code})")
        if "ORDER:" in out or "Q0, in every slice" in out:
            bad.append("--from-handoff must not print the survey ORDER/Q0 text again")
        if "ledger" not in out.lower() or "Did not work" not in out:
            bad.append("--from-handoff keeps the ledger and Did not work rules")
        if not (fresh / "tools" / "shot-flows" / "new-flow.json").is_file() or not (fresh / "design" / "tasks" / "ui.md").is_file():
            bad.append("the survey's flow file and task file must exist in the fresh worktree")
        code, out = run(fresh, "--door", "ui", "--from-task", "ui", "--dry-run")
        if code != 0 or "HANDOFF from" not in out or "restored" in out:
            bad.append(f"--from-task ID must print the summary from design/tasks/ID.md without restoring survey edits (code={code})")
        code, out = run(fresh, "--door", "ui", "--from-task", "nope", "--dry-run")
        if code == 0:
            bad.append("--from-task with no such task file must fail")
    return bad
