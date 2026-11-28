"""Step flow per subject type: Start, one step per store section, then Export.

Steps run in order. A step opens when every earlier step is approved (Done). Each step owns
the actions in ACTIONS and the pictures its jobs made. Lock state lives on the record under
`studio.steps` until the schema adopts it.
"""
from __future__ import annotations

from media.pipeline import store

PICTURE_ACTIONS = ["tune", "review", "frame", "proportion", "smooth", "body", "mesh", "edit"]
ART_ACTIONS = ["tune", "review", "frame"]
ART_SECTIONS = {"art", "portrait", "skin"}
LATER_SECTIONS = {"animation"}
# Actions that read the step's prompt or settings (what an Adjust override changes).
PROMPT_ACTIONS = {"tune", "smooth", "body", "edit"}

LABELS = {
    "start": "Start", "export": "Send to the game",
}
ACTION_LABELS = {
    "tune": "Auto-tune to the locked look",
    "review": "Check a picture",
    "frame": "Center and trim a picture",
    "proportion": "Measure proportions",
    "smooth": "Make the four body pictures",
    "body": "Build the 3D body",
    "mesh": "Check the 3D model",
    "edit": "Change something",
    "reference": "Read the reference picture",
    "export": "Send to the game",
}


def label(step_id: str) -> str:
    return LABELS.get(step_id) or step_id.replace("-", " ").replace("_", " ").capitalize()


def plan(subject_type: str) -> list[dict]:
    rows = [{"id": "start", "label": "Start", "kind": "start", "actions": ["reference"], "skeleton": False}]
    for sec, skeleton in store.SECTIONS.get(subject_type, ()):
        if subject_type == "character" and sec in ("body", "model"):
            kind, actions = "pictures", list(PICTURE_ACTIONS)
        elif sec in ART_SECTIONS:
            kind, actions = "pictures", list(ART_ACTIONS)
        elif sec in LATER_SECTIONS:
            kind, actions = "later", []
        else:
            kind, actions = "fields", []
        rows.append({"id": sec, "label": label(sec), "kind": kind, "actions": actions, "skeleton": bool(skeleton)})
    rows.append({"id": "export", "label": "Send to the game", "kind": "export", "actions": ["export"], "skeleton": False})
    return rows


def find(subject_type: str, step_id: str) -> dict | None:
    return next((s for s in plan(subject_type) if s["id"] == step_id), None)


def states(doc: dict, stills: list[dict], busy: dict[str, str] | None = None) -> list[dict]:
    """Status of every step. busy maps step id -> running job id."""
    busy = busy or {}
    ui = doc.get("studio") or {}
    marks = ui.get("steps") or {}
    out: list[dict] = []
    blocked_by: str | None = None
    for row in plan(doc["type"]):
        sid = row["id"]
        mark = marks.get(sid) or {}
        done_at = mark.get("done_at") or ""
        mine = [s for s in stills if s.get("step") == sid]
        pending = [s for s in mine if s.get("state") == "pending"]
        approved = [s for s in mine if s.get("state") == "approved"]
        data = ((doc.get("sections") or {}).get(sid) or {}).get("data") if row["kind"] not in ("start", "export") else None
        started = bool(mine) or bool(data) or sid in busy or (sid == "start" and bool(ui.get("reference")))
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
        blocker = None
        if not done_at and sid != "export":
            if pending:
                blocker = "pending"
            elif row["kind"] == "pictures" and not approved:
                blocker = "no_approved"
        out.append({**row, "status": status, "done_at": done_at or None, "available": blocked_by is None,
                    "blocked_by": blocked_by, "blocked_by_label": label(blocked_by) if blocked_by else None,
                    "pictures": len(mine), "pending": len(pending), "approved": len(approved),
                    "job": busy.get(sid), "can_finish": blocked_by is None and not done_at and blocker is None and sid != "export",
                    "finish_blocker": blocker, "stale": False, "stale_because": None})
        if not done_at and blocked_by is None:
            blocked_by = sid
    # A Done step after an earlier step that is open again, or was approved again later, might need a look.
    for i, st in enumerate(out):
        if st["status"] != "done":
            continue
        for prev in out[:i]:
            if prev["status"] != "done" or (prev["done_at"] or "") > (st["done_at"] or ""):
                st["stale"], st["stale_because"] = True, prev["label"]
                break
    return out
