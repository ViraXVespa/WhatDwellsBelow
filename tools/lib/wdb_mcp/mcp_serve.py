#!/usr/bin/env python3
"""stdio MCP server `wdb` for Grok Build: tools lookup, check, protocol (tools/lib/wdb_mcp/mcp_tools.py).

    python tools/wdb_mcp.py serve [--root DIR] [--surface D]       (Grok Build runs this from .grok/config.toml)
    python tools/wdb_mcp.py serve --selftest
Needs the `mcp` package (pip install -r tools/requirements-mcp.txt). Every first response starts with
`STATUS: PASS` or `STATUS: FAIL (N)`, then `handle:` and `next:`; follow-ups pass the handle. Catalog: design/tools-mcp.md.
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

LOOKUP_DOC = """Read repo code/docs progressively (thin wrapper over find.py / docs.py / session.py / slice.py plan expand).
First call runs the command once and returns STATUS, handle, next and the first page; pass handle (action=more) for the
next page only, action=full for all. Lines already shown this session are elided unless fresh=true.
actions: func (path+name, or pairs=[[path,name],...]), xref (pattern, path, regex, expand=FILE), names / all_names (path),
lines (path, start, end), doc (path='design/x.md#Heading'), route (door|job), scenes, facade, stat (path), changed
(query=REV, path='DOC SCRIPT' for history), code_map (path), task (query=ID), summary (query=JOB, pattern=MATCH),
packet (the session-plan context packet; query='K1,K2' expands only those candidates)."""
CHECK_DOC = """Run one check once and cache it (check.py tool-cli|tool-docs|script-cap|load-graph, gate.py gd-load).
First call: STATUS: PASS or STATUS: FAIL (N) + handle + summary only. Follow-up: handle + action=failures|full|files.
targets: tool_cli (stem), tool_docs, script_cap (files), load_graph, gd_load (files)."""
PROTOCOL_DOC = """What should I do or use right now? action=now (default): slice identity, current phase and next actions;
action=doc situation=NAME: the canonical doc section (boot, understand, implement, compact-stop, questions, verify,
finish, references, pick-a-tool); action=suggest query=TEXT: best rows of the tools table; action=packet; action=list."""

def build_server(root: Path, surface: str):
    from mcp.server.mcpserver import MCPServer  # mcp>=2: FastMCP was renamed MCPServer

    tools = mcp_tools.Tools(root, surface)
    srv = MCPServer("wdb")

    @srv.tool(description=LOOKUP_DOC)
    def lookup(action: str = "more", handle: str = "", path: str = "", name: str = "", pattern: str = "",
               pairs: list[list[str]] | None = None, start: int = 0, end: int = 0, door: str = "", job: str = "",
               query: str = "", regex: bool = False, expand: str = "", budget: int = 0, fresh: bool = False) -> str:
        return tools.lookup(action, handle, path, name, pattern, pairs, start, end, door, job, query, regex, expand, budget, fresh)

    @srv.tool(description=CHECK_DOC)
    def check(target: str = "", handle: str = "", action: str = "", stem: str = "", files: list[str] | None = None, budget: int = 0) -> str:
        return tools.check(target, handle, action, stem, files, budget)

    @srv.tool(description=PROTOCOL_DOC)
    def protocol(action: str = "now", situation: str = "", query: str = "", handle: str = "", budget: int = 0) -> str:
        return tools.protocol(action, situation, query, handle, budget)

    return srv, tools

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("stdio MCP server wdb (lookup, check, protocol) for Grok Build.")
    ap.add_argument("--surface", default="D", help="Catalog surface letter the caller has (D Build, B Bot); commands off it are refused.")
    ap.add_argument("--selftest", action="store_true", help="Tool functions in a throwaway repo, then an in-process MCP client when mcp is installed.")
    args = ap.parse_args(argv)
    if args.selftest:
        import mcp_selftest

        return mcp_selftest.run()
    root = agent_log.resolve_root(args)
    try:
        srv, _ = build_server(root, args.surface)
    except ModuleNotFoundError as exc:
        print(f"error: {exc}. Install it: pip install -r tools/requirements-mcp.txt", file=sys.stderr)
        return 2
    srv.run("stdio")
    return 0

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
