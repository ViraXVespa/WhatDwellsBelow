"""Selftest for the wdb MCP (`python tools/wdb_mcp.py serve --selftest`). No CLI of its own.

Runs the tool functions against this checkout with state in a temp dir (read-only for the repo; tool runs write only
their gitignored _logs summaries), a temp repo for edited-file cases, then an in-process MCP client when `mcp` is
installed (skipped with a note otherwise).
"""
from __future__ import annotations

import asyncio
import json
import tempfile
from pathlib import Path

import agent_log
import mcp_core as core
import mcp_tools

ROOT = Path(__file__).resolve().parents[3]

def _head(text: str) -> list[str]:
    return text.splitlines()

def cases(bad: list[str], state: Path) -> None:
    t = mcp_tools.Tools(ROOT, "D", True, state)
    first = t.lookup("func", path="tools/lib/slice/session_plan.py", name="render")
    lines = _head(first)
    if lines[0] != "STATUS: PASS" or not lines[1].startswith("handle: f") or not lines[2].startswith("next: more"):
        bad.append("func first call: STATUS / handle / next header: " + " | ".join(lines[:3]))
    if len(lines) > 27:
        bad.append(f"first page must stay short (got {len(lines)} lines)")
    h = lines[1].split(": ")[1]
    runs = t.store.runs
    second = t.lookup("more", handle=h)
    if t.store.runs != runs:
        bad.append("a follow-up re-ran the command")
    page1 = set(lines[6:]) - {""}
    page2 = [ln for ln in _head(second)[5:] if ln.strip() and not ln.startswith("...")]
    if not page2 or any(ln in page1 for ln in page2 if len(ln.strip()) > 12):
        bad.append("more must return only the next page, no overlap")
    again = t.lookup("func", path="tools/lib/slice/session_plan.py", name="render")
    if "unchanged, already shown" not in again:
        bad.append("a repeat read in the same epoch must elide shown lines")
    core.bump_epoch(ROOT, state)
    fresh = t.lookup("func", path="tools/lib/slice/session_plan.py", name="render")
    if "already shown" in fresh:
        bad.append("a new epoch (after compact) must resend")
    for path in ("_logs/x.txt", "notes/a.md", "assets/x.png"):
        if not t.lookup("lines", path=path).startswith("STATUS: FAIL"):
            bad.append(f"{path} must be refused")
    if not t._allowed("check.py prove"):
        bad.append("Bot-only check.py prove must be refused on surface D")
    if "Bot-only" not in t.check("prove"):
        bad.append("check target prove must be refused")
    chk = t.check("load_graph")
    if not chk.startswith("STATUS: PASS") or len(_head(chk)) > 5:
        bad.append("check first call: status header only: " + chk[:120])
    ch = _head(chk)[1].split(": ")[1]
    runs = t.store.runs
    full = t.check(handle=ch, action="full")
    if t.store.runs != runs or "RESULT" in full.split("\n", 5)[-1][:0]:
        bad.append("check follow-up must not re-run")
    if not t.lookup("more", handle="zz9").startswith("STATUS: FAIL"):
        bad.append("an unknown handle must FAIL")
    data = json.loads((ROOT / "tools/data/mcp_protocol.json").read_text(encoding="utf-8"))
    for sit in data["situations"]:
        if not t.protocol("doc", situation=sit).startswith("STATUS: PASS"):
            bad.append(f"protocol situation {sit} does not resolve to a doc heading")
    if "phase:" not in t.protocol():
        bad.append("protocol now must name a phase")
    if "find.py" not in t.protocol("suggest", query="find a function code"):
        bad.append("protocol suggest must use the tools table")

def edited(bad: list[str]) -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        (root / "design").mkdir()
        src = root / "a.gd"
        src.write_text("\n".join(f"var v{i} = {i}" for i in range(30)) + "\n", encoding="utf-8")
        t = mcp_tools.Tools(root, "D", False)
        t.lookup("lines", path="a.gd", start=1, end=30, budget=40)
        src.write_text("\n".join(f"var v{i} = {i * (2 if i == 15 else 1)}" for i in range(30)) + "\n", encoding="utf-8")
        out = t.lookup("lines", path="a.gd", start=1, end=30, budget=40)
        body = [ln for ln in _head(out)[4:] if ln.startswith("var ")]
        if body != ["var v15 = 30"] and "var v15 = 30" not in body:
            bad.append("after an edit only the changed lines are re-sent: " + " | ".join(body))
        if len(body) > 3:
            bad.append(f"after an edit, unchanged lines must stay elided (sent {len(body)})")

def client(bad: list[str], notes: list[str], state: Path) -> None:
    try:
        from mcp import Client
        import mcp_serve
    except ModuleNotFoundError as exc:
        notes.append(f"in-process MCP client skipped ({exc}); pip install -r tools/requirements-mcp.txt")
        return
    srv, tools = mcp_serve.build_server(ROOT, "D")
    tools.store = core.Store(ROOT, False, state)

    async def go() -> None:
        async with Client(srv) as c:
            names = sorted(t.name for t in (await c.list_tools()).tools)
            if names != ["check", "lookup", "protocol"]:
                bad.append(f"server must register exactly lookup, check, protocol: {names}")
            res = await c.call_tool("lookup", {"action": "func", "path": "scripts/app.gd", "name": "_ready"})
            text = res.content[0].text if res.content else ""
            if not text.startswith("STATUS: PASS"):
                bad.append("MCP lookup over the client: " + text[:120])
            h = text.splitlines()[1].split(": ")[1]
            res2 = await c.call_tool("lookup", {"handle": h, "action": "full"})
            if "STATUS:" not in (res2.content[0].text if res2.content else ""):
                bad.append("MCP follow-up by handle failed")

    asyncio.run(go())
    notes.append("in-process MCP client: 3 tools, call + handle follow-up")

def run() -> int:
    bad: list[str] = []
    notes: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        cases(bad, Path(td))
        edited(bad)
        client(bad, notes, Path(td))
    for n in notes:
        print(n)
    return agent_log.selftest_result(bad)
