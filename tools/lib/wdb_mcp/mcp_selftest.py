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
    first = t.lookup("func", path="tools/lib/slice/session_plan.py", name="seed", budget=20)
    lines = _head(first)
    if lines[0] != "STATUS: PASS" or not re.match(r"page: 1-\d+ of \d+; more: handle=f", lines[1]):
        bad.append("func first call: STATUS / page+more header: " + " | ".join(lines[:2]))
    if len(lines) > 24:
        bad.append(f"first page must stay within budget (got {len(lines)} lines)")
    h = _handle(first)
    runs = t.store.runs
    second = t.lookup("more", handle=h)
    if t.store.runs != runs:
        bad.append("a follow-up re-ran the command")
    page1 = set(_body(first)) - {""}
    page2 = [ln for ln in _body(second) if ln.strip()]
    if not page2 or any(ln in page1 for ln in page2 if len(ln.strip()) > 12):
        bad.append("more must return only the next page, no overlap")
    again = t.lookup("func", path="tools/lib/slice/session_plan.py", name="seed", budget=20)
    if _body(again) != _body(first) or _handle(again) == h:
        bad.append("a repeat call is a new handle with the same first page (no shown-line tracking)")
    whole = t.lookup("func", path="tools/lib/slice/session_plan.py", name="seed", whole=True)
    if "handle" in whole or "page:" in whole or len(_body(whole)) <= len(_body(first)):
        bad.append("all=true (whole) returns the whole result in the first reply, with no handle")
    names_cases(bad, t)
    batch_cases(bad, t)
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
    chk_all = t.check("load_graph", whole=True)
    if "handle:" in chk_all or "summary:" not in chk_all or not _body(chk_all):
        bad.append("check all=true: STATUS, summary and the whole output in one reply: " + chk_all[:120])
    t.check("load_graph")
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
    if "handle=" in short or "handle:" in short or "\x1b[" in short or any(ln != ln.rstrip() for ln in short.splitlines()):
        bad.append("a reply that fits has no handle, ANSI codes or trailing spaces")
    data = json.loads((ROOT / "tools/data/mcp_protocol.json").read_text(encoding="utf-8"))
    for sit in data["situations"]:
        if not t.protocol("doc", situation=sit).startswith("STATUS: PASS"):
            bad.append(f"protocol situation {sit} does not resolve to a doc heading")
    if "phase:" not in t.protocol():
        bad.append("protocol now must name a phase")
    if "find.py" not in t.protocol("suggest", query="find a function code"):
        bad.append("protocol suggest must use the tools table")

def names_cases(bad: list[str], t: mcp_tools.Tools) -> None:
    """names lists every declared function (the CLI's --names keeps only the biggest few; it once hid `_toggle`)."""
    def funcs(f: Path) -> list[str]:
        return re.findall(r"^(?:static )?func (\w+)", f.read_text(encoding="utf-8-sig"), re.M)

    rel = "scripts/ui/pause_settings/report_page.gd"
    if not (ROOT / rel).is_file():
        rel = next(str(f.relative_to(ROOT)) for f in sorted((ROOT / "scripts").rglob("*.gd")) if len(funcs(f)) > 8)
    want = funcs(ROOT / rel)
    got = t.lookup("names", path=rel)
    missing = [n for n in want if not re.search(rf"\b{re.escape(n)}\b", got)]
    if missing:
        bad.append(f"names must list every declared function of {rel}; missing {missing}")
    outline = t.lookup("doc", path="design/tools-mcp.md")
    if not outline.startswith("STATUS: PASS") or "outline" not in outline or not re.search(r"^L\d+-\d+ ## Contract$", outline, re.M):
        bad.append("doc with no #Heading returns the outline with line spans: " + outline[:160])
    whole_outline = t.lookup("doc", path="design/tools-mcp.md", whole=True)
    if "outline" not in whole_outline or "Replies start" in whole_outline or "page:" in whole_outline:
        bad.append("doc with no #Heading and all=true still returns the outline, unpaged: " + whole_outline[:160])
    section = t.lookup("doc", path="design/tools-mcp.md#Contract", whole=True)
    if "Replies start" not in section or "## Catalog" in section:
        bad.append("doc path#Heading returns that full section only: " + section[:160])
    if "## Catalog" not in t.lookup("lines", path="design/tools-mcp.md", whole=True):
        bad.append("lines with no start/end returns the whole file")
    nope = t.lookup("doc", path="design/tools-mcp.md#Nope")
    if not nope.startswith("STATUS: FAIL") or nope.count("Contract") != 1:
        bad.append("an unknown heading fails and lists each heading once: " + nope[:160])

def batch_cases(bad: list[str], t: mcp_tools.Tools) -> None:
    """reads=[...]: mixed reads in one reply, in order; a bad read fails only itself."""
    runs = t.store.runs
    reads = [{"action": "names", "path": "scripts/app.gd"},
             {"action": "lines", "path": "design/tools-mcp.md", "start": 1, "end": 2},
             {"action": "doc", "path": "design/tools-mcp.md#Contract"},
             {"action": "func", "path": "tools/lib/wdb_mcp/mcp_core.py", "name": "fail"},
             {"action": "lines", "path": "_logs/x.txt"}]
    got = t.lookup("batch", reads=reads, whole=True)
    order = [got.find(x) for x in ("## [1] names", "## design/tools-mcp.md L1-2", "## design/tools-mcp.md L", "mcp_core.py:fail", "## [5] lines")]
    if not got.startswith("STATUS: FAIL (1)") or "1 of 5 reads failed" not in got or -1 in order or order != sorted(order):
        bad.append("batch: every read answered in order, one failed read counted: " + got[:200])
    if any(ln.startswith("page:") for ln in _head(got)[:3]) or t.store.runs - runs != 2:
        bad.append(f"batch all=true: one reply, and only command-backed reads run a command ({t.store.runs - runs} runs)")
    runs = t.store.runs
    dup = t.lookup(reads=[{"action": "func", "path": "tools/lib/wdb_mcp/mcp_core.py", "name": "fail"},
                          {"name": "fail", "action": "func", "path": "tools/lib/wdb_mcp/mcp_core.py"}], whole=True)
    if dup.count("mcp_core.py:fail") != 1 or "1 duplicate read(s) skipped" not in dup or t.store.runs - runs != 1:
        bad.append("identical batch reads are answered once and the skip is noted: " + dup[:200])
    if not t.lookup(reads=[{"path": "x"}]).startswith("STATUS: FAIL"):
        bad.append("a batch read without an action is refused")

def shared(bad: list[str]) -> None:
    """Two servers on one checkout: separate handle files, neither overwrites the other; expiry; rerun counts."""
    with tempfile.TemporaryDirectory() as td:
        one, two = core.Store(ROOT, True, Path(td)), core.Store(ROOT, True, Path(td))
        ha = one.new("l", [f"a{i}" for i in range(50)])
        hb = two.new("l", [f"b{i}" for i in range(50)])
        one.put(ha, {**one.get(ha), "budget": 20}), two.put(hb, {**two.get(hb), "budget": 20})
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
            res3 = await c.call_tool("lookup", {"all": True, "reads": [{"action": "names", "path": "scripts/app.gd"},
                                                                     {"action": "doc", "path": "design/tools-mcp.md#Contract"}]})
            text3 = res3.content[0].text if res3.content else ""
            if not text3.startswith("STATUS: PASS") or "## [1] names" not in text3 or "Replies start" not in text3:
                bad.append("MCP lookup all=true reads=[...] over the client: " + text3[:120])

    asyncio.run(go())
    notes.append("in-process MCP client: 3 tools, call + handle follow-up + all=true batch")

def call_help(bad: list[str]) -> None:
    """`wdb_mcp.py call --help` lists every tool's arguments, so a shell caller needs no extra round to learn them."""
    import subprocess

    import boot

    out = subprocess.run([*boot.cmd("mcp_call"), "--help"], capture_output=True, text=True).stdout
    for want in ("lookup: action handle path", " reads", "check: target handle action stem files budget all",
                 "protocol: action situation query handle budget all", "reads='[{...},...]' as JSON"):
        if want not in out:
            bad.append(f"call --help lists each tool's arguments; missing {want!r}")

def run() -> int:
    bad: list[str] = []
    notes: list[str] = []
    call_help(bad)
    with tempfile.TemporaryDirectory() as td:
        cases(bad, Path(td))
        shared(bad)
        client(bad, notes, Path(td))
    for n in notes:
        print(n)
    return agent_log.selftest_result(bad)
