#!/usr/bin/env python3
"""Run one wdb MCP tool call from a shell, with the same handle files as `serve` (_logs/gather/mcp/).

    python tools/wdb_mcp.py call lookup action=func path=scripts/app.gd name=_ready
    python tools/wdb_mcp.py call lookup handle=f3a9c1                      (next page of that handle)
    python tools/wdb_mcp.py call check target=load_graph
    python tools/wdb_mcp.py call protocol action=doc situation=finish
Values: key=value; lists as comma lists (files=a.gd,b.gd; pairs=path:name,path:name); true/false; integers.
Prints the tool's text answer, then the RESULT line. Does not need the `mcp` package.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import mcp_tools

INTS = {"start", "end", "budget"}
BOOLS = {"regex"}

def parse(pairs: list[str]) -> dict:
    out: dict = {}
    for item in pairs:
        key, sep, val = item.partition("=")
        if not sep:
            agent_log.fail(f"expected key=value, got {item!r}")
        if key in INTS:
            out[key] = int(val or 0)
        elif key in BOOLS:
            out[key] = val.lower() in ("1", "true", "yes")
        elif key == "files":
            out[key] = [v for v in val.split(",") if v]
        elif key == "pairs":
            out[key] = [v.split(":", 1) for v in val.split(",") if ":" in v]
        else:
            out[key] = val
    return out

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Run one wdb MCP tool call (lookup, check, protocol) from a shell.")
    ap.add_argument("tool", choices=("lookup", "check", "protocol"), help="Which MCP tool.")
    ap.add_argument("kv", nargs="*", help="key=value arguments, as the MCP tool takes them.")
    ap.add_argument("--surface", default="D", help="Catalog surface letter (D Build, B Bot).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    tools = mcp_tools.Tools(root, args.surface)
    text = getattr(tools, args.tool)(**parse(args.kv))
    status = "PASS" if text.startswith("STATUS: PASS") else "FAIL"
    first = text.splitlines()[1].split(": ", 1)[-1] if len(text.splitlines()) > 1 else "-"
    return agent_log.finish("mcp-call", root, text, status, args=args, tool=args.tool, handle=first)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
