"""Selftest for the wdb MCP (`python tools/wdb_mcp.py serve --selftest`). No CLI of its own.

Runs the tool functions against this checkout with state in a temp dir (read-only for the repo; tool runs write only
their gitignored _logs summaries), two stores on one state dir for the shared-handle case, then an in-process MCP client when `mcp` is
installed (skipped with a note otherwise).
"""
from __future__ import annotations

import asyncio
import json
import re
import tempfile
from pathlib import Path

import agent_log
import mcp_core as core
import mcp_tools

ROOT = Path(__file__).resolve().parents[3]

def _head(text: str) -> list[str]:
    return text.splitlines()

def _handle(text: str) -> str:
    m = re.search(r"(?:more: handle=|^handle: )([a-z][0-9a-f]{6})", text, re.M)
    return m.group(1) if m else ""

def _body(text: str) -> list[str]:
    return text.split("\n\n", 1)[1].splitlines() if "\n\n" in text else []

def cases(bad: list[str], state: Path) -> None:
    t = mcp_tools.Tools(ROOT, "D", True, state)
    first = t.lookup("func", path="tools/lib/slice/session_plan.py", name="seed")
    lines = _head(first)
    if lines[0] != "STATUS: PASS" or not re.match(r"page: 1-\d+ of \d+; more: handle=f", lines[1]):
        bad.append("func first call: STATUS / page+more header: " + " | ".join(lines[:2]))
    if len(lines) > 24:
        bad.append(f"first page must stay short (got {len(lines)} lines)")
    h = _handle(first)
    runs = t.store.runs
    second = t.lookup("more", handle=h)
    if t.store.runs != runs:
        bad.append("a follow-up re-ran the command")
    page1 = set(_body(first)) - {""}
    page2 = [ln for ln in _body(second) if ln.strip()]
    if not page2 or any(ln in page1 for ln in page2 if len(ln.strip()) > 12):
        bad.append("more must return only the next page, no overlap")
    again = t.lookup("func", path="tools/lib/slice/session_plan.py", name="seed")
    if _body(again) != _body(first) or _handle(again) == h:
        bad.append("a repeat call is a new handle with the same first page (no shown-line tracking)")
    for path in ("_logs/x.txt", "notes/a.md", "assets/x.png", "../../../../etc/passwd", "./../x.md", "/etc/passwd"):
        if not t.lookup("lines", path=path).startswith("STATUS: FAIL"):
            bad.append(f"{path} must be refused")
    if not t._allowed("check.py prove"):
        bad.append("Bot-only check.py prove must be refused on surface D")
    if "Bot-only" not in t.check("prove"):
        bad.append("check target prove must be refused")
    chk = t.check("load_graph")
    if not chk.startswith("STATUS: PASS") or len(_head(chk)) > 3 or "RESULT" in chk or "summary=" in chk:
        bad.append("check first call: STATUS, summary, handle only: " + chk[:120])
    ch = _handle(chk)
    runs = t.store.runs
    full = t.check(handle=ch, action="full")
    if t.store.runs != runs or not _body(full):
        bad.append("check follow-up must not re-run")
    t.check("load_graph"), t.check("load_graph")
    capped = t.check("load_graph")
    if not capped.startswith("STATUS: FAIL") or "rule 10" not in capped:
        bad.append("a fourth run of the same check (third rerun) must be refused: " + capped[:120])
    if not mcp_tools.Tools(ROOT, "D", True, state, rerun_limit=False).check("load_graph").startswith("STATUS: PASS"):
        bad.append("a non-Build server (explicit --surface) skips the rerun limit")
    if not t.lookup("task").startswith("STATUS:") or not t.lookup("stat", path="_logs/x").startswith("STATUS: FAIL"):
        bad.append("simple lookup actions with no query must answer (not raise); a _logs path argument is refused")
    if not t.lookup("more", handle="zz9").startswith("STATUS: FAIL"):
        bad.append("an unknown handle must FAIL")
    short = t.lookup("names", path="tools/lib/wdb_mcp/mcp_selftest.py")
    if "handle" in short or "\x1b[" in short or any(ln != ln.rstrip() for ln in short.splitlines()):
        bad.append("a reply that fits has no handle, ANSI codes or trailing spaces")
    data = json.loads((ROOT / "tools/data/mcp_protocol.json").read_text(encoding="utf-8"))
    for sit in data["situations"]:
        if not t.protocol("doc", situation=sit).startswith("STATUS: PASS"):
            bad.append(f"protocol situation {sit} does not resolve to a doc heading")
    if "phase:" not in t.protocol():
        bad.append("protocol now must name a phase")
    if "find.py" not in t.protocol("suggest", query="find a function code"):
        bad.append("protocol suggest must use the tools table")

def shared(bad: list[str]) -> None:
    """Two servers on one checkout: separate handle files, neither overwrites the other; expiry; rerun counts."""
    with tempfile.TemporaryDirectory() as td:
        one, two = core.Store(ROOT, True, Path(td)), core.Store(ROOT, True, Path(td))
        ha = one.new("l", [f"a{i}" for i in range(50)])
        hb = two.new("l", [f"b{i}" for i in range(50)])
        core.page(one, ha, first=True), core.page(two, hb, first=True)
        pa, pb = core.page(two, ha), core.page(one, hb)
        if "a20" not in pa or "b20" not in pb or "b" in pa.split("\n\n", 1)[1][:3]:
            bad.append("handles from two stores on one checkout must both page (each its own file)")
        rec = json.loads((Path(td) / f"{ha}.json").read_text(encoding="utf-8"))
        rec["t"] = 0
        (Path(td) / f"{ha}.json").write_text(json.dumps(rec), encoding="utf-8")
        if one.get(ha) is not None or one.get("../x") is not None:
            bad.append("an expired or malformed handle must not load")
        one.add_check_run("load_graph", "c000001")
        two.add_check_run("load_graph", "c000002")
        if one.check_runs().get("load_graph") != ["c000001", "c000002"]:
            bad.append("check rerun counts are shared per worktree")
        if list(Path(td).glob(".tmp-*")):
            bad.append("atomic writes must leave no temp files")

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
            h = _handle(text)
            if res.structured_content or any(t.output_schema for t in (await c.list_tools()).tools):
                bad.append("replies are text only (no structured duplicate or output schema)")
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
        shared(bad)
        client(bad, notes, Path(td))
    for n in notes:
        print(n)
    return agent_log.selftest_result(bad)
