"""Read the running Grok session's own files (library for the first-message facts and the slice state of start_build_slice.py).

Layout seen in real sessions: <sessions>/<url-encoded cwd>/<session id>/{chat_history.jsonl, prompt_context.json, terminal/}. <sessions> is
$WDB_GROK_SESSIONS, else C:\\Users\\Vira\\.grok\\sessions, else ~/.grok/sessions. The session id is $GROK_SESSION_ID. Everything here is best effort:
a file that is missing or unreadable gives None / [] and the caller says "not verified" instead of guessing.
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

import agent_log


def session_dir(sid: str = "", base: Path | None = None) -> Path | None:
    """The folder of session `sid` (default $GROK_SESSION_ID) under any cwd-named folder of the session store, or None."""
    sid = (sid or os.environ.get("GROK_SESSION_ID", "")).strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", sid):
        return None
    for b in ([base] if base else [agent_log.grok_sessions(), Path.home() / ".grok" / "sessions"]):
        try:
            for cand in sorted(b.glob(f"*/{sid}")):
                if cand.is_dir():
                    return cand
        except OSError:
            continue
    return None


def _rows(path: Path) -> list[dict]:
    out: list[dict] = []
    try:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if isinstance(row, dict):
                out.append(row)
    except OSError:
        return []
    return out


def _text(content: object) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(str(p.get("text", "")) for p in content if isinstance(p, dict))
    return ""


def context_facts(sdir: Path | None) -> dict:
    """{'agents': [file names] | None, 'skill_at_start': bool | None}. None = could not be read (not verified)."""
    out: dict = {"agents": None, "skill_at_start": None}
    if sdir is None:
        return out
    try:
        ctx = json.loads((sdir / "prompt_context.json").read_text(encoding="utf-8"))
        files = ctx.get("agents_md_files")
        if isinstance(files, list):
            out["agents"] = [str(f.get("file_name", "?")) for f in files if isinstance(f, dict)]
    except (OSError, ValueError):
        pass
    rows = _rows(sdir / "chat_history.jsonl")
    if rows:
        seen = False
        for r in rows:
            if r.get("type") in ("assistant", "tool_result"):
                break
            if r.get("type") == "user" and "skills are available" in _text(r.get("content")):
                seen = True
                if "pc-offload" in _text(r.get("content")):
                    out["skill_at_start"] = True
                    return out
        out["skill_at_start"] = False if seen else None
    return out


def prompt_facts(sdir: Path | None) -> dict:
    """{'time': ISO str, 'chars': int} of this session's first prompt from <sessions>/<cwd>/prompt_history.jsonl, or {} (not verified)."""
    if sdir is None:
        return {}
    sid = sdir.name
    for r in _rows(sdir.parent / "prompt_history.jsonl"):
        if r.get("session_id") == sid:
            return {"time": str(r.get("timestamp", "")), "chars": len(str(r.get("prompt", "")))}
    return {}


def statement(sdir: Path | None) -> str:
    """The first-message facts, only what was read from the session's files; Build then says which of AGENTS.md and the skill it opened."""
    f = context_facts(sdir)
    ask = "In your first message say which of AGENTS.md and the pc-offload skill you actually opened, or that you opened neither; write 'loaded' or 'read' only for what you opened."
    if f["agents"] is None and f["skill_at_start"] is None:
        return "Session facts: not verified (this session's files could not be read; `/session-info` shows the agents file and skill list). " + ask
    a = f"prompt_context.json: agents_md_files=[{', '.join(f['agents'])}]" if f["agents"] is not None else "agents_md_files: not verified"
    s = {True: "pc-offload is in the skills list at start", False: "pc-offload is not in the skills list at start", None: "skills list at start: not verified"}[f["skill_at_start"]]
    return f"Session facts: {a}; {s}. " + ask
