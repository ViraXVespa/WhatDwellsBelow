"""Read the running Grok session's own files (library for did_not_work.py and the first-message facts of start_build_slice.py).

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


def statement(sdir: Path | None) -> str:
    """The exact first-message line for the User: what is true about AGENTS.md and the skills, or how to check."""
    f = context_facts(sdir)
    how = "Could not read this session's files, so say \"not verified\" and check `/session-info` (or the context shown at the top of the session) for the agents file and the skill list."
    if f["agents"] is None and f["skill_at_start"] is None:
        return "First-message statement: " + how
    a = ("AGENTS.md: auto-loaded (" + ", ".join(f["agents"]) + ")") if f["agents"] else "AGENTS.md: read by hand (the session's agents_md_files is empty)" if f["agents"] is not None else "AGENTS.md: not verified"
    s = {True: "skills: pc-offload listed at start", False: "skills: found by path (pc-offload was not in the list at start)", None: "skills: not verified"}[f["skill_at_start"]]
    return f"First-message statement, copy it exactly: \"{a}; {s}\". Never write 'loaded' for what you did not verify."


def failed_steps(rows: list[dict]) -> list[dict]:
    """Failed tool steps in order: {'i', 'tool', 'what', 'why', 'reported'}; reported = a later assistant text says 'Did not work'."""
    calls: dict[str, tuple[str, str]] = {}
    out: list[dict] = []
    last_dnw = -1
    for i, r in enumerate(rows):
        t = r.get("type")
        if t == "assistant":
            if "did not work" in _text(r.get("content")).lower():
                last_dnw = i
            for c in r.get("tool_calls") or []:
                try:
                    a = json.loads(c.get("arguments") or "{}")
                except ValueError:
                    a = {}
                what = a.get("command") or a.get("target_file") or a.get("file_path") or a.get("path") or a.get("description") or ""
                calls[str(c.get("id"))] = (str(c.get("name", "?")), " ".join(str(what).split())[:120])
        elif t == "tool_result":
            body = _text(r.get("content"))
            m = re.match(r"exit: (-?\d+)", body)
            bad = (m is not None and (m.group(1) != "0" or re.search(r"^RESULT FAIL", body, re.M) is not None)) or (m is None and body.startswith("Error"))
            if not bad:
                continue
            lines = body.splitlines()
            why = next((ln.strip() for ln in lines if re.search(r"^RESULT FAIL|error|Error|FAIL|not found|does not exist", ln)), "") or (lines[0] if lines else "")
            tool, what = calls.get(str(r.get("tool_call_id")), ("?", ""))
            out.append({"i": i, "tool": tool, "what": what, "why": why[:160], "reported": False})
    for s in out:
        s["reported"] = last_dnw > s["i"]
    return out
