"""Slice state for start_build_slice.py (library; import only): what this worktree's slice has done, so a later run answers "where am I" in a few lines.

The first run in a worktree writes `_logs/slice-state.json` (under _logs/, so it is never committed): area, mode, time, session id, and what
open_slice.py started the session with (the prompt's length and time, read from the session's prompt_history.jsonl). Every later run prints
`SLICE ALREADY STARTED` with the steps found on disk and the next one; `--full` prints the whole start card again. Steps are read from the
tree and the git common dir at the time of the run, never kept as a claim: import (.godot/imported), baseline shots (_logs/shot-flow),
checkpoint (retry_lib), handoff (_logs/handoff/handoff.md).
"""
from __future__ import annotations

import datetime as dt
import json
import os
from pathlib import Path

import handoff_lib
import retry_lib
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


def new(root: Path, door: str, job: str, area: str, mode: str, sdir: Path | None) -> dict:
    """The state a first run records."""
    st = {"v": 1, "first_run": now(), "door": door, "job": job, "area": area, "mode": mode, "session": os.environ.get("GROK_SESSION_ID", "")}
    pf = session_lib.prompt_facts(sdir)
    if pf:
        st["prompt"] = pf
    return st


def save(root: Path, st: dict) -> None:
    p = path(root)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(st, indent=1) + "\n", encoding="utf-8")


def steps(root: Path) -> dict:
    """Steps seen on disk right now: door run (the state file itself), import, baseline shots, checkpoint, handoff ('none' | 'skeleton' | 'ready')."""
    hp = handoff_lib.handoff_path(root)
    ho = "none"
    if hp.is_file():
        ho = "skeleton" if handoff_lib.check(root, hp.read_text(encoding="utf-8-sig")) else "ready"
    shots = root / "_logs" / "shot-flow"
    return {"door run": True, "import": (root / ".godot" / "imported").is_dir(),
            "baseline shots": shots.is_dir() and any(shots.glob("*/flow.json")),
            "checkpoint": bool(retry_lib.gather_for(root).get("session")), "handoff": ho}


def next_step(st: dict, s: dict) -> str:
    if st.get("mode") == "survey":
        if s["handoff"] == "ready":
            return "stop: the handoff passed; tell her to run the open_slice command `--handoff` printed"
        if s["handoff"] == "skeleton":
            return "fill the handoff skeleton, then `python tools/start_build_slice.py --handoff`"
        return "the survey message, Q0 and the first ask (nothing to shoot); after her answers `python tools/start_build_slice.py --handoff`"
    if not s["import"]:
        return "`python tools/check_gd_load.py` and `python tools/run_godot_import_check.py`"
    if not s["baseline shots"]:
        return "the baseline (the handoff's PNGs, else shoot the flows), look at it, `python tools/show_png.py`, then the restate and Q0"
    if not s["checkpoint"]:
        return "gather, then `python tools/start_build_slice.py --checkpoint`"
    return "the unit in hand: edit, prove, then the next ask (message first)"


def short(root: Path, st: dict) -> str:
    """The SLICE ALREADY STARTED text for a later run."""
    s = steps(root)
    area = st.get("job") or st.get("door") or st.get("area") or "?"
    pf = st.get("prompt") or {}
    by = f"; opened by open_slice at {clock(pf.get('time', ''))} with a prompt of {pf['chars']} chars" if pf.get("chars") is not None else "; open_slice prompt not verified"
    sid = os.environ.get("GROK_SESSION_ID", "")
    other = f" (first run by session {st['session']}; this is {sid})" if st.get("session") and sid and sid != st["session"] else ""
    done = "; ".join(f"{k} {'yes' if v is True else 'no' if v is False else v}" for k, v in s.items())
    return (f"SLICE ALREADY STARTED: {area} ({st.get('mode', '?')} session), first run {clock(st.get('first_run', ''))}{by}{other}.\n"
            f"Steps found now: {done}.\n"
            f"Resuming at: {next_step(st, s)}.\n"
            "Nothing to redo. `python tools/start_build_slice.py --door D --full` prints the whole card again.")
