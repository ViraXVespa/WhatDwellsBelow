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
    ask = ("Your first text to her, before your next tool call, says which of AGENTS.md and the pc-offload skill you actually opened, or that you opened neither; "
           "write 'loaded' or 'read' only for what you opened. It is not kept for the first ask.")
    if f["agents"] is None and f["skill_at_start"] is None:
        return "Session facts: not verified (this session's files could not be read; `/session-info` shows the agents file and skill list). " + ask
    a = f"prompt_context.json: agents_md_files=[{', '.join(f['agents'])}]" if f["agents"] is not None else "agents_md_files: not verified"
    s = {True: "pc-offload is in the skills list at start", False: "pc-offload is not in the skills list at start", None: "skills list at start: not verified"}[f["skill_at_start"]]
    return f"Session facts: {a}; {s}. " + ask


FAIL_TEXT = re.compile(r"^(Error|The string to replace was not found|File not found|.{0,80}(does not exist|No such file))", re.S)


def failed_since_ask(rows: list[dict]) -> list[dict]:
    """Failed tool steps after the last ask_user_question call (all of them when there was no ask yet), in order: {'tool', 'what', 'why'}.
    Failed = a terminal result with a non-zero exit or a `RESULT FAIL` line, or another tool whose result starts with an error."""
    calls: dict[str, tuple[str, str]] = {}
    start = 0
    for i, r in enumerate(rows):
        if r.get("type") == "assistant":
            for c in r.get("tool_calls") or []:
                if c.get("name") == "ask_user_question":
                    start = i
    out: list[dict] = []
    for i, r in enumerate(rows):
        t = r.get("type")
        if t == "assistant":
            for c in r.get("tool_calls") or []:
                try:
                    a = json.loads(c.get("arguments") or "{}")
                except ValueError:
                    a = {}
                what = a.get("command") or a.get("target_file") or a.get("file_path") or a.get("path") or a.get("description") or ""
                calls[str(c.get("id"))] = (str(c.get("name", "?")), " ".join(str(what).split())[:120])
        elif t == "tool_result" and i > start:
            body = _text(r.get("content"))
            m = re.match(r"exit: (-?\d+)", body)
            bad = (m is not None and (m.group(1) != "0" or re.search(r"^RESULT FAIL", body, re.M) is not None)) or (m is None and FAIL_TEXT.match(body) is not None)
            if not bad:
                continue
            lines = [ln.strip() for ln in body.splitlines() if ln.strip()]
            why = next((ln for ln in lines if re.search(r"^RESULT FAIL|error|Error|FAIL|not found|does not exist|not exist", ln)), "") or (lines[0] if lines else "")
            tool, what = calls.get(str(r.get("tool_call_id")), ("?", ""))
            out.append({"tool": tool, "what": what, "why": why[:160]})
    return out


def failed_block(sdir: Path | None = None) -> str:
    """The `Did not work:` lines for the next message, built from this session's own tool results (see failed_since_ask); '' text says none or not verified."""
    sdir = sdir or session_dir()
    rows = _rows(sdir / "chat_history.jsonl") if sdir else []
    if not rows:
        return "Did not work: not verified here (this session's record could not be read); write it from your own tool results."
    steps = failed_since_ask(rows)
    if not steps:
        return "Did not work: none in this session's tool results since your last ask."
    return "Did not work (from this session's tool results since your last ask; paste as the first lines of the message):\n" + "\n".join(
        f"Did not work: {x['what'] or x['tool']} - {x['why']}" for x in steps)
