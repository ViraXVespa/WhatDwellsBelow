"""Task/session-scoped visual-reference grants; project workflow, not host security.

No grant authorizes generation, shell readers, writes, text/OCR exceptions or secrets.
The hook and slice.py references share canonical path and content validation.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import time
from pathlib import Path

GRANT = "_logs/reference-access.json"
STATE = "_logs/slice-state.json"
TTL = 2 * 60 * 60
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif"}


def contained(root: Path, value: str, *, exists: bool = True) -> Path:
    """Reject traversal, symlinks (including parents), hidden names and outside paths."""
    raw = Path(value)
    if ".." in raw.parts:
        raise ValueError("parent traversal is not a reference path")
    path = raw if raw.is_absolute() else root / raw
    rel = path.relative_to(root)
    if any(part.startswith(".") for part in rel.parts):
        raise ValueError("hidden paths are not references")
    cur = root
    for part in rel.parts:
        cur /= part
        if cur.is_symlink():
            raise ValueError("symlinks are not reference paths")
    path.resolve().relative_to(root)
    if exists and not path.is_file():
        raise ValueError("reference file does not exist")
    return path


def read_json(root: Path, name: str) -> dict:
    value = json.loads(contained(root, name).read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("expected an object")
    return value


def task_file(root: Path, task: str) -> Path:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", task):
        raise ValueError("a task id is required")
    path = contained(root, f"design/tasks/{task}.md")
    text = path.read_text(encoding="utf-8").split("\n## ", 1)[0]
    for key, expected in (("id", task), ("owner", "build")):
        if not re.search(rf"^{key}: {re.escape(expected)}$", text, re.M):
            raise ValueError("reference grants require the named Build task")
    if not re.search(r"^status: (open|active)$", text, re.M):
        raise ValueError("task must be open or active")
    return path


def reference(root: Path, task: str, value: str) -> Path:
    path = contained(root, value)
    rel = path.relative_to(root).as_posix()
    roots = ("assets/", "_src/", f"design/refs/{task}/", f"_logs/references/{task}/")
    if path.suffix.lower() not in IMAGE_EXT or not rel.startswith(roots):
        raise ValueError("select image files in assets, _src or this task's reference folders")
    return path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def session_id(event: dict | None = None) -> str:
    event = event or {}
    explicit = str(event.get("sessionId") or event.get("session_id") or "")
    inherited = os.environ.get("GROK_SESSION_ID", "")
    if explicit and inherited and explicit != inherited:
        return ""
    return explicit or inherited


def context(root: Path, task: str, session: str) -> dict:
    task_file(root, task)
    state = read_json(root, STATE)
    if not session or state.get("session") != session or state.get("task") != task:
        raise ValueError("grant requires this slice's active task and original GROK_SESSION_ID")
    return state


def make_grant(root: Path, task: str, session: str, reason: str, paths: list[str]) -> dict:
    state = context(root, task, session)
    if not 12 <= len(reason.strip()) <= 500 or "\n" in reason or not paths or len(paths) > 128:
        raise ValueError("give a specific one-line reason (12-500 chars) and 1-128 exact paths")
    files = {}
    for value in paths:
        path = reference(root, task, value)
        files[path.relative_to(root).as_posix()] = digest(path)
    return {"version": 1, "root": str(root), "task": task, "unit": state.get("unit", ""),
            "session": session, "reason": reason.strip(), "purpose": "visual-reference",
            "created": time.time(), "expires": time.time() + TTL, "files": files}


def active(root: Path, session: str) -> dict:
    try:
        grant = read_json(root, GRANT)
        state = context(root, grant.get("task", ""), session)
        now = time.time()
        if (grant.get("version") != 1 or grant.get("root") != str(root)
                or grant.get("session") != session or grant.get("unit", "") != state.get("unit", "")
                or grant.get("purpose") != "visual-reference" or not grant.get("reason")
                or not 0 <= now - grant["created"] < TTL
                or not now < grant["expires"] <= grant["created"] + TTL + 1
                or not isinstance(grant.get("files"), dict) or not 1 <= len(grant["files"]) <= 128):
            return {}
        return grant
    except (OSError, ValueError, TypeError, KeyError, RuntimeError):
        return {}


def permits(root: Path, session: str, value: str) -> bool:
    grant = active(root, session)
    if not grant:
        return False
    try:
        path = reference(root, grant["task"], value)
        return grant["files"].get(path.relative_to(root).as_posix()) == digest(path)
    except (OSError, ValueError, RuntimeError):
        return False


def image_candidate(root: Path, value: str, cwd: Path | None = None) -> bool:
    """Also catch an innocuous-looking symlink to an image; never authorize that alias."""
    try:
        path = Path(value)
        return path.suffix.lower().split("?", 1)[0] in IMAGE_EXT or ((cwd or root) / path).resolve().suffix.lower() in IMAGE_EXT
    except (OSError, ValueError, RuntimeError):
        return False
