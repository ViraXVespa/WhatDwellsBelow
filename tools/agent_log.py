#!/usr/bin/env python3
"""Session-keyed agent log paths for Python runners.

Resolve order: WDB_AGENT_SESSION, else newest updates.jsonl under
GROK_HOME/sessions/<url-encoded-repo-cwd>/ (same layout as pack).
No session -> raise. Never write a shared _logs/<job>/ singleton.
"""
from __future__ import annotations

import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

_SESSION_KEY = re.compile(r"^[A-Za-z0-9._-]{1,128}$")
_JOB_KEY = re.compile(r"^[A-Za-z0-9._-]+$")
_SESSION_FILES = (
    "summary.json",
    "signals.json",
    "updates.jsonl",
    "chat_history.jsonl",
    "system_prompt.txt",
    "prompt_context.json",
)


def repo_root(hint: str | Path | None = None) -> Path:
    if hint:
        cand = Path(hint).expanduser().resolve()
        if (cand / "project.godot").is_file():
            return cand
    here = Path(__file__).resolve().parent.parent
    if (here / "project.godot").is_file():
        return here
    cur = Path.cwd().resolve()
    for parent in (cur, *cur.parents):
        if (parent / "project.godot").is_file():
            return parent
    raise FileNotFoundError("agent_log: repo root not found (no project.godot)")


def grok_home() -> Path:
    raw = os.environ.get("GROK_HOME", "").strip()
    if raw:
        return Path(raw).expanduser().resolve()
    return (Path.home() / ".grok").resolve()


def encode_cwd(root: Path) -> str:
    return quote(str(root.resolve()), safe="")


def looks_like_session(path: Path) -> bool:
    if not path.is_dir():
        return False
    return any((path / name).is_file() for name in _SESSION_FILES)


def session_root(root: Path) -> Path:
    sessions = grok_home() / "sessions"
    direct = sessions / encode_cwd(root)
    if direct.is_dir():
        return direct
    if sessions.is_dir():
        want = root.resolve()
        for child in sessions.iterdir():
            marker = child / ".cwd"
            if not marker.is_file():
                continue
            try:
                body = marker.read_text(encoding="utf-8").strip()
            except OSError:
                continue
            if not body:
                continue
            try:
                got = Path(body).expanduser().resolve()
            except OSError:
                continue
            if got == want:
                return child
    return direct


def _mtime(path: Path) -> datetime:
    return datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)


def inferred_session_id(root: Path) -> str:
    base = session_root(root)
    if not base.is_dir():
        return ""
    best_id = ""
    best_time = datetime.min.replace(tzinfo=timezone.utc)
    for child in base.iterdir():
        if not looks_like_session(child):
            continue
        updates = child / "updates.jsonl"
        when = _mtime(updates) if updates.is_file() else _mtime(child)
        if when >= best_time:
            best_time = when
            best_id = child.name
    return best_id


def agent_session(root: Path | None = None) -> str:
    base = repo_root(root) if root is not None else repo_root()
    explicit = os.environ.get("WDB_AGENT_SESSION", "").strip()
    if explicit:
        if not _SESSION_KEY.fullmatch(explicit):
            raise ValueError("agent_log: WDB_AGENT_SESSION is not a usable folder key")
        return explicit
    inferred = inferred_session_id(base)
    if inferred and _SESSION_KEY.fullmatch(inferred):
        return inferred
    raise FileNotFoundError(
        "agent_log: no session key (set WDB_AGENT_SESSION or run inside a Grok session for this repo)"
    )


def agent_log_dir(job: str, root: Path | None = None) -> Path:
    if not _JOB_KEY.fullmatch(job):
        raise ValueError("agent_log: bad job name")
    base = repo_root(root) if root is not None else repo_root()
    session = agent_session(base)
    return (base / "_logs" / "sess" / session / job).resolve()


def agent_summary_path(job: str, root: Path | None = None) -> Path:
    return agent_log_dir(job, root) / "summary.txt"


def ensure_agent_log_dir(job: str, root: Path | None = None) -> Path:
    path = agent_log_dir(job, root)
    path.mkdir(parents=True, exist_ok=True)
    return path


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    job = ""
    hint = ""
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("-Job", "--job") and i + 1 < len(args):
            job = args[i + 1]
            i += 2
            continue
        if a in ("-Root", "--root") and i + 1 < len(args):
            hint = args[i + 1]
            i += 2
            continue
        if not a.startswith("-") and not job:
            job = a
        i += 1
    try:
        root = repo_root(hint or None)
        session = agent_session(root)
        print(f"session={session}")
        if job:
            directory = ensure_agent_log_dir(job, root)
            summary = directory / "summary.txt"
            print(f"job={job}")
            print(f"dir={directory}")
            print(f"summary={summary}")
        return 0
    except (OSError, ValueError) as exc:
        print(str(exc))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())