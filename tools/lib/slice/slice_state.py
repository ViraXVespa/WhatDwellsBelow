"""Slice state for slice.py start (library; import only): what this worktree's slice has done, so a later run answers "where am I" in a few lines.

The first run in a worktree writes `_logs/slice-state.json` (under _logs/, so it is never committed): area, mode, time, session id, and what
slice.py open started the session with (the prompt's length and time, read from the session's prompt_history.jsonl). Every later run prints
`SLICE ALREADY STARTED` with the steps found on disk and the next one; `--full` prints the whole start card again. Steps are read from the
tree and the git common dir at the time of the run, never kept as a claim: import (.godot/imported), baseline shots (_logs/shot-flow),
the original session id (the reset point a red prove's retry forks), handoff (the task file design/tasks/ID.md).
"""
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

import handoff_lib
import session_lib

REL = "_logs/slice-state.json"

def path(root: Path) -> Path:
    return root / REL

def load(root: Path) -> dict:
    try:
        d = json.loads(path(root).read_text(encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}

def now() -> str:
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")

def clock(iso: str) -> str:
    """'17:23' (local clock) from an ISO time, or '?'."""
    try:
        return dt.datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone().strftime("%H:%M")
    except ValueError:
        return "?"

def new(root: Path, door: str, job: str, area: str, mode: str, sdir: Path | None, units: list[str] | None = None, done: list[str] | None = None, ref: str = "") -> dict:
    """The state a first run records. A door worked as a unit queue also carries the ordered units, which are done and the current one (the job)."""
    st = {"v": 1, "first_run": now(), "door": door, "job": job, "area": area, "mode": mode, "session": os.environ.get("GROK_SESSION_ID", ""), "ref": ref}
    if units:
        st.update({"units": units, "done": done or [], "unit": job})
    pf = session_lib.prompt_facts(sdir)
    if pf:
        st["prompt"] = pf
    return st

def save(root: Path, st: dict) -> None:
    p = path(root)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(st, indent=1) + "\n", encoding="utf-8")

def steps(root: Path, st: dict | None = None) -> dict:
    """Steps seen now: door run (the state file itself), import, baseline shots, original session (recorded id), forked (this session is not it), handoff ('none' | 'skeleton' | 'ready')."""
    hp = handoff_lib.handoff_path(root)
    ho = "none"
    if hp.is_file() and hp.read_text(encoding="utf-8-sig").lstrip().startswith("# Handoff:"):
        ho = "skeleton" if handoff_lib.check(root, hp.read_text(encoding="utf-8-sig")) else "ready"
    shots = root / "_logs" / "shot-flow"
    return {"door run": True, "import": (root / ".godot" / "imported").is_dir(),
            "baseline shots": shots.is_dir() and any(shots.glob("*/flow.json")),
            "original session": (st or {}).get("session") or "not recorded", "forked": _forked(st or {}), "handoff": ho}

def _forked(st: dict) -> bool:
    """True when this session is not the one that ran the first card (the User ran `/fork` at the end of Gather)."""
    sid = os.environ.get("GROK_SESSION_ID", "")
    return bool(st.get("session") and sid and sid != st["session"])

def next_step(st: dict, s: dict) -> str:
    if st.get("mode") == "survey":
        if s["handoff"] == "ready":
            return "stop: the handoff passed; tell her to run the open_slice command `--handoff` printed"
        if s["handoff"] == "skeleton":
            return "fill the handoff skeleton, then `python tools/slice.py start --handoff`"
        return "the survey message, Q0 and the first ask (nothing to shoot); after her answers `python tools/slice.py start --handoff`"
    if not s["import"]:
        return "`python tools/gate.py gd-load` and `python tools/gate.py import`"
    if not s["baseline shots"]:
        return "the baseline (the handoff's PNGs, else shoot the flows), look at it, `python tools/shots.py show`, then the restate and Q0"
    unit = f" ({st['unit']})" if st.get("units") and st.get("unit") else ""
    if not s["forked"]:
        return f"Gather{unit}: restate, Q0 and her answers, the observable outcome and its signal; then tell her to run `/fork` and continue in the new peer session"
    tail = " (`python tools/slice.py start --unit-done` updates the task's done: line)" if unit else ""
    return f"Prepare / Change / Prove / Complete for the unit in hand{unit}{tail}; then the done notice (finish the whole request in this session when it fits; queue the rest for a new session only when it cannot)"

def short(root: Path, st: dict) -> str:
    """The SLICE ALREADY STARTED text for a later run."""
    s = steps(root, st)
    area = st.get("job") or st.get("door") or st.get("area") or "?"
    pf = st.get("prompt") or {}
    by = f"; opened by open_slice at {clock(pf.get('time', ''))} with a prompt of {pf['chars']} chars" if pf.get("chars") is not None else "; open_slice prompt not verified"
    sid = os.environ.get("GROK_SESSION_ID", "")
    other = f" (first run by session {st['session']}; this is {sid})" if st.get("session") and sid and sid != st["session"] else ""
    done = "; ".join(f"{k} {'yes' if v is True else 'no' if v is False else v}" for k, v in s.items())
    queue = (f"Units: {st.get('unit', '?')} is current ({(st['units'].index(st['unit']) + 1) if st.get('unit') in st['units'] else '?'} of {len(st['units'])}); done: {', '.join(st.get('done') or []) or 'none'}. "
             + (f"`--job {st.get('job')} --task {st.get('task')} --full` reprints this unit's card" if st.get("task_units") else "`--door D --full` reprints this unit's card")
             + "; at Complete `--unit-done` marks it done (more units fit: the same start command again; else a new session).\n") if st.get("units") else ""
    return (f"SLICE ALREADY STARTED: {area} ({st.get('mode', '?')} session), first run {clock(st.get('first_run', ''))}{by}{other}.\n" + queue +
            f"Steps found now: {done}.\n"
            f"Resuming at: {next_step(st, s)}.\n"
            "Nothing to redo. `python tools/slice.py start --door D --full` prints the whole card again.")
