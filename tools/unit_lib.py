"""Unit queue for a door (library for start_build_slice.py, list_route.py, run_shot_flow.py and handoff_lib.py; import only).

A door that lists `unit_queue` in design/routes.yaml is worked one unit (one job) at a time, in the order listed. Which units are done is carried
in the slice state (`_logs/slice-state.json`: units, done, unit) and in a handoff's `units:` / `done:` header lines. A unit's card prints only
its own flow (with the shot state it cuts at), docs (path plus line range of the one section) and files; `start_build_slice.py --next` marks the
current unit done and prints the next card without a new survey.
"""
from __future__ import annotations

import re
from pathlib import Path

from load_routes import job_read_when, shot_flows


def _map(data: dict, key: str) -> dict:
    raw = data.get(key)
    return raw if isinstance(raw, dict) else {}


def split(text: str, sep: str = ",") -> list[str]:
    return [x.strip() for x in str(text or "").split(sep) if x.strip()]


def queue(data: dict, door: str) -> list[str]:
    """The door's ordered unit jobs (door.job ids); empty when the door has no unit queue."""
    return split(_map(data, "unit_queue").get(door, ""))


def job_state(data: dict, job: str) -> str:
    """The top-level shot a unit's flow is cut at ('' = the whole flow)."""
    return str(_map(data, "shot_states").get(job, "")).strip()


def section(root: Path, spec: str) -> str:
    """'path L7-15 (## Heading)' for a `path#Heading` entry; 'path (all, N lines)' for a bare path."""
    path, _, head = spec.partition("#")
    f = root / path.strip()
    if not f.is_file():
        return f"{path} (MISSING)"
    lines = f.read_text(encoding="utf-8-sig").splitlines()
    if not head:
        return f"{path.strip()} (all, {len(lines)} lines)"
    fence, start, level = False, 0, 0
    for n, line in enumerate(lines, 1):
        if line.startswith("```"):
            fence = not fence
        m = None if fence else re.match(r"(#+)\s+(.*?)\s*$", line)
        if not m:
            continue
        if not start and m.group(2) == head.strip():
            start, level = n, len(m.group(1))
        elif start and len(m.group(1)) <= level:
            return f"{path.strip()} L{start}-{n - 1} ({'#' * level} {head.strip()})"
    return f"{path.strip()} L{start}-{len(lines)} ({'#' * level} {head.strip()})" if start else f"{path.strip()}#{head.strip()} (HEADING NOT FOUND)"


def pick(units: list[str], done: list[str]) -> str:
    """The first unit not done ('' when all are)."""
    return next((u for u in units if u not in done), "")


def plan(data: dict, door: str, st: dict, head: dict | None = None) -> tuple[list[str], list[str]]:
    """(units, done): this worktree's slice state first, then a handoff's header, then the door's queue from the start."""
    if st.get("units") and st.get("door") == door:
        return list(st["units"]), list(st.get("done") or [])
    if head and head.get("units"):
        return split(head["units"]), [d for d in split(head.get("done", "")) if d != "none"]
    return queue(data, door), []


def lines(root: Path, data: dict, job: str, units: list[str] | None = None, done: list[str] | None = None) -> list[str]:
    """The unit block of a card: position in the queue, its flow and state, its docs (line ranges) and files. Empty for a job with no unit entries."""
    docs, files = _map(data, "unit_docs"), _map(data, "unit_files")
    door = job.split(".", 1)[0]
    if job not in docs and job not in files and job not in queue(data, door):
        return []
    out = []
    if units and job in units:
        left = [u for u in units[units.index(job) + 1:] if u not in (done or [])]
        out.append(f"unit\t{job} ({units.index(job) + 1} of {len(units)}); done: {', '.join(done or []) or 'none'}; after it: {', '.join(left) or 'none (last)'}")
    flows = shot_flows(data, door=door, job=job, job_only=True)
    state = job_state(data, job)
    if flows:
        out.append(f"flow\t{','.join(flows)}" + (f" state {state}" if state else " (whole flow)") + f"  run: python tools/run_shot_flow.py --job {job}")
    jobs = ((data.get("doors") or {}).get(door) or {}).get("jobs") or {}
    stub = jobs.get(job.split(".", 1)[1]) if isinstance(jobs, dict) else ""
    specs = split(docs.get(door, ""), ";") + ([str(stub)] if stub else []) + split(docs.get(job, ""), ";")
    out.append("read\t" + " | ".join(section(root, s) for s in specs) + "  (nothing else: `list_route.py --digest --job` lists a doc's headings)")
    if job in files:
        out.append("files\t" + str(files[job]) + "  (show_func.py / code_map.py row, not whole files)")
    return out


def unit_fails(root: Path, data: dict) -> list[str]:
    """Lint for check_load_graph.py: queue ids are jobs of their door, doc sections and files exist, every unit has a real flow, each state is a top-level shot of it."""
    import json

    from load_routes import job_index

    fails: list[str] = []
    jobs = set(job_index(data)["by_id"])
    doors = set(data.get("doors") or {})
    for door, raw in _map(data, "unit_queue").items():
        for jid in split(raw):
            if jid not in jobs or jid.split(".", 1)[0] != door:
                fails.append(f"unit_queue.{door}: {jid} is not a job of that door")
            if not shot_flows(data, door=door, job=jid, job_only=True):
                fails.append(f"unit_queue.{door}: {jid} has no shot_flows entry")
    for key, raw in _map(data, "unit_docs").items():
        if key not in jobs | doors:
            fails.append(f"unit_docs key is not a door or job: {key}")
        for spec in split(raw, ";"):
            text = section(root, spec)
            if "MISSING" in text or "NOT FOUND" in text:
                fails.append(f"unit_docs.{key}: {text}")
    for key, raw in _map(data, "unit_files").items():
        if key not in jobs:
            fails.append(f"unit_files key is not a job: {key}")
        for spec in split(raw, ";"):
            if not (root / spec.split(":", 1)[0].strip()).is_file():
                fails.append(f"unit_files.{key}: no file {spec.split(':', 1)[0].strip()}")
    for key, state in _map(data, "shot_states").items():
        names = shot_flows(data, door=key.split(".", 1)[0], job=key, job_only=True)
        if key not in jobs or len(names) != 1:
            fails.append(f"shot_states.{key}: needs a job that maps exactly one flow")
            continue
        f = root / "tools" / "shot-flows" / f"{names[0]}.json"
        steps = json.loads(f.read_text(encoding="utf-8-sig")).get("steps", []) if f.is_file() else []
        shots = [s.get("name") for s in steps if isinstance(s, dict) and s.get("op") == "shot"]
        if str(state) not in shots:
            fails.append(f"shot_states.{key}: {state!r} is not a top-level shot of {names[0]} ({', '.join(map(str, shots)) or 'none'})")
    return fails
