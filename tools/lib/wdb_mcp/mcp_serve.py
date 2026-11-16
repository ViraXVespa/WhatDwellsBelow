#!/usr/bin/env python3
"""stdio MCP server `wdb` for Grok Build: tools lookup, check, protocol (tools/lib/wdb_mcp/mcp_tools.py).

    python tools/wdb_mcp.py serve [--root DIR] [--surface D|B]     (Grok Build: no --surface, from .grok/config.toml)
    python tools/wdb_mcp.py serve --selftest
Needs the `mcp` package (pip install -r tools/requirements-mcp.txt). Every first response starts with
`STATUS: PASS` or `STATUS: FAIL (N)`; a cut one says `more: handle=H`. Catalog: design/tools-mcp.md.
--selftest runs the tool functions against a throwaway repo, then (when `mcp` is installed) an in-process MCP client.
Long-running server: no RESULT line, and nothing but the protocol may reach stdout.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import mcp_tools

LOOKUP_DOC = """Read repo code/docs. all=true returns the whole result in this one reply (use it whenever you will need
all of it); else a reply of about 60 lines (budget=N lines), and a cut one ends its header with `more: handle=H` (pass handle for the
next page, action=full for the rest at once). reads=[{action, path, ...}, ...] answers several independent reads in one
reply (each item takes this tool's arguments; all=true applies to all; identical reads run once). actions: func (path+name, or
pairs=[[path,name],...]), xref (pattern, path, regex=true when the pattern contains `|`, expand=FILE), names (path: every declared function), lines (path,
start, end; no start/end: the whole file), doc (path='design/x.md#Heading' that full section; no #Heading: always the
outline with line spans, all=true only stops it paging), route (door|job), scenes, facade, stat (path), changed (query=REV; path='DOC SCRIPT' for history), code_map
(path), task (query=ID), summary (query=JOB, pattern=MATCH), packet (session context; query='K1,K2' expands those)."""
CHECK_DOC = """Run a check once; replies STATUS + summary + handle, or with all=true STATUS + summary + the whole output.
Follow up with handle + action=failures|full|files. targets: tool_cli (stem), tool_docs, script_cap (files), load_graph,
gd_load (files)."""
PROTOCOL_DOC = """What to do now. action=now (default): slice, phase, next actions; doc situation=NAME: that doc section
(action=list names them); suggest query=TEXT: best tools-table rows; packet. all=true: no paging."""

def _trim_schemas(srv) -> None:
    """Published input schemas without pydantic titles or empty defaults (fewer tokens per list_tools)."""
    try:
        tools = srv._tool_manager.list_tools()  # private in mcp 2.x; skip trimming if it moves
    except AttributeError:
        return
    for t in tools:
        sch = t.parameters
        sch.pop("title", None)
        for prop in sch.get("properties", {}).values():
            prop.pop("title", None)
            if prop.get("default", 1) in ("", 0, False, None) and not isinstance(prop.get("default"), list):
                prop.pop("default", None)
            if "anyOf" in prop:  # list[...] | None -> the list schema
                kinds = [k for k in prop.pop("anyOf") if k.get("type") != "null"]
                prop.update(kinds[0] if kinds else {})

def build_server(root: Path, surface: str, rerun_limit: bool = True):
    from mcp.server.mcpserver import MCPServer  # mcp>=2: FastMCP was renamed MCPServer

    tools = mcp_tools.Tools(root, surface, rerun_limit=rerun_limit)
    srv = MCPServer("wdb")

    @srv.tool(description=LOOKUP_DOC, structured_output=False)
    def lookup(action: str = "more", handle: str = "", path: str = "", name: str = "", pattern: str = "",
               pairs: list[list[str]] | None = None, start: int = 0, end: int = 0, door: str = "", job: str = "",
               query: str = "", regex: bool = False, expand: str = "", budget: int = 0, all: bool = False,
               reads: list[dict] | None = None) -> str:
        return tools.lookup(action, handle, path, name, pattern, pairs, start, end, door, job, query, regex, expand, budget,
                            whole=all, reads=reads)

    @srv.tool(description=CHECK_DOC, structured_output=False)
    def check(target: str = "", handle: str = "", action: str = "", stem: str = "", files: list[str] | None = None,
              budget: int = 0, all: bool = False) -> str:
        return tools.check(target, handle, action, stem, files, budget, whole=all)

    @srv.tool(description=PROTOCOL_DOC, structured_output=False)
    def protocol(action: str = "now", situation: str = "", query: str = "", handle: str = "", budget: int = 0,
                 all: bool = False) -> str:
        return tools.protocol(action, situation, query, handle, budget, whole=all)

    _trim_schemas(srv)
    return srv, tools

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("stdio MCP server wdb (lookup, check, protocol) for Grok Build.")
    ap.add_argument("--surface", default="", help="Catalog surface letter (D, B) for a non-Build caller such as a Grok Bot agent; commands off it are refused, and the Build check rerun limit is off. Default: Build (D, limit on).")
    ap.add_argument("--selftest", action="store_true", help="Tool functions in a throwaway repo, then an in-process MCP client when mcp is installed.")
    args = ap.parse_args(argv)
    if args.selftest:
        import mcp_selftest

        return mcp_selftest.run()
    root = agent_log.resolve_root(args)
    try:
        srv, _ = build_server(root, args.surface or "D", rerun_limit=not args.surface)
    except ModuleNotFoundError as exc:
        print(f"error: {exc}. Install it: pip install -r tools/requirements-mcp.txt", file=sys.stderr)
        return 2
    srv.run("stdio")
    return 0

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
