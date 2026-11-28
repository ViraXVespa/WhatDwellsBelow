"""Step flow per subject type: Start, one step per store section, then Send to the game.

What each step holds and does comes from registry.py. Steps run in order; steps that share a
group open together and may be approved in any order, and the next step waits for the whole group.
A step is Done only when the user approves it and its needs are met. Lock state lives on the
record under `studio.steps` until the schema adopts it.
"""
from __future__ import annotations

from . import registry

# Actions that read the step's prompt or settings (what an Adjust override changes).
PROMPT_ACTIONS = {"generate", "tune", "smooth", "body", "edit", "variant", "icon", "tile"}
PICTURE_MAKERS = {a for a, s in registry.ACTIONS.items() if s["makes"] in ("still", "mesh", "clip") and a not in ("reference", "preview")}
LABELS = {"start": "Start", "export": "Send to the game"}
ACTION_LABELS = {a: s["label"] for a, s in registry.ACTIONS.items()}
EMPTY = (None, "", [], {})


def label(step_id: str) -> str:
    return LABELS.get(step_id) or step_id.replace("-", " ").replace("_", " ").capitalize()


def plan(subject_type: str) -> list[dict]:
    rows = []
    for sid in ["start", *registry.TYPES[subject_type]["steps"], "export"]:
        spec = registry.step_spec(subject_type, sid)
        if sid in ("start", "export"):
            kind = sid
        elif any(a in PICTURE_MAKERS for a in spec["actions"]):
            kind = "pictures"
        else:
            kind = "fields"
        rows.append({"id": sid, "label": label(sid), "kind": kind, "actions": list(spec["actions"]), "needs": list(spec["needs"]),
                     "group": spec["group"], "open_question": spec["open"], "fields": spec["fields"]})
    return rows


def find(subject_type: str, step_id: str) -> dict | None:
    return next((s for s in plan(subject_type) if s["id"] == step_id), None)


def missing_fields(fields: list[dict], data: dict) -> list[str]:
    out = [fd["label"] for fd in fields if fd.get("required") and (data or {}).get(fd["key"]) in EMPTY]
    for fd in fields:
        have = (data or {}).get(fd["key"]) or []
        out += [f"{fd['label']}: {m}" for m in fd.get("must") or [] if isinstance(have, list) and have and m not in have]
    return out


def wanted_clips(row: dict, data: dict) -> list[str]:
    spec = next((fd for fd in row["fields"] if fd["key"] == "clips"), None)
    if not spec:
        return []
    return [str(c) for c in ((data or {}).get("clips") or [])]


def _blocker(row: dict, mine: list[dict], data: dict) -> tuple[str | None, list[str]]:
    if row["kind"] in ("start", "export"):
        return None, []
    live = [s for s in mine if s.get("state") != "hidden"]
    if any(s.get("state") == "pending" for s in live):
        return "pending", []
    if any(s.get("state") == "rejected" for s in live):
        return "rejected", []
    gaps = missing_fields(row["fields"], data)
    if gaps:
        return "fields", gaps
    if row["fields"] and not any(v not in EMPTY for v in (data or {}).values()):
        return "empty", []
    approved = [s for s in live if s.get("state") == "approved"]
    if "pictures" in row["needs"] and not any(s.get("kind") == "still" for s in approved):
        return "no_approved", []
    if "mesh" in row["needs"] and not any(s.get("kind") == "mesh" for s in approved):
        return "no_mesh", []
    if "clips" in row["needs"]:
        have = {s.get("clip") for s in approved if s.get("kind") == "clip"}
        lack = [c for c in wanted_clips(row, data) if c not in have]
        if lack:
            return "no_clips", lack
    return None, []


def states(doc: dict, stills: list[dict], busy: dict[str, str] | None = None) -> list[dict]:
    """Status of every step. busy maps step id -> running job id."""
    busy = busy or {}
    ui = doc.get("studio") or {}
    marks = ui.get("steps") or {}
    rows = plan(doc["type"])
    out: list[dict] = []
    blocked_by: str | None = None
    group_gate: dict[str, str | None] = {}
    for i, row in enumerate(rows):
        sid = row["id"]
        mark = marks.get(sid) or {}
        done_at = mark.get("done_at") or ""
        mine = [s for s in stills if s.get("step") == sid]
        live = [s for s in mine if s.get("state") != "hidden"]
        pending = [s for s in live if s.get("state") == "pending"]
        approved = [s for s in live if s.get("state") == "approved"]
        data = ((doc.get("sections") or {}).get(sid) or {}).get("data") if row["kind"] not in ("start", "export") else None
        started = bool(live) or bool(data) or sid in busy or (sid == "start" and bool(ui.get("reference")))
        if done_at:
            status = "done"
        elif sid in busy:
            status = "in_progress"
        elif pending:
            status = "needs_ok"
        elif started:
            status = "in_progress"
        else:
            status = "not_started"
        grp = row["group"]
        if grp:
            gate = group_gate.setdefault(grp, blocked_by)
        else:
            gate = blocked_by
        blocker, lack = _blocker(row, mine, data or {}) if not done_at else (None, [])
        out.append({**row, "status": status, "done_at": done_at or None, "available": gate is None,
                    "blocked_by": gate, "blocked_by_label": label(gate) if gate else None,
                    "pictures": len(live), "pending": len(pending), "approved": len(approved),
                    "job": busy.get(sid), "can_finish": gate is None and not done_at and blocker is None and sid != "export",
                    "finish_blocker": blocker, "finish_missing": lack, "stale": False, "stale_because": None,
                    "autotune": bool(mark.get("autotune"))})
        last_in_group = grp and (i + 1 >= len(rows) or rows[i + 1]["group"] != grp)
        if grp:
            if last_in_group and blocked_by is None:
                first_open = next((s["id"] for s in out if s["group"] == grp and not s["done_at"]), None)
                blocked_by = first_open
        elif not done_at and blocked_by is None:
            blocked_by = sid
    # A Done step after an earlier step that is open again, or was approved again later, might need a look.
    for i, st in enumerate(out):
        if st["status"] != "done":
            continue
        for prev in out[:i]:
            if st["group"] and prev["group"] == st["group"]:
                continue
            if prev["status"] != "done" or (prev["done_at"] or "") > (st["done_at"] or ""):
                st["stale"], st["stale_because"] = True, prev["label"]
                break
    return out
