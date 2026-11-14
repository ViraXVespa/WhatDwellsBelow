#!/usr/bin/env python3
"""Run one wdb MCP tool call from a shell, with the same handle files as `serve` (_logs/gather/mcp/).

    python tools/wdb_mcp.py call lookup action=func path=scripts/app.gd name=_ready
    python tools/wdb_mcp.py call lookup handle=f3a9c1                      (next page of that handle)
    python tools/wdb_mcp.py call check target=load_graph
    python tools/wdb_mcp.py call protocol action=doc situation=finish
    python tools/wdb_mcp.py call lookup all=true reads='[{"action":"names","path":"scripts/app.gd"},{"action":"doc","path":"design/ui.md"}]'
Values: key=value; lists as comma lists (files=a.gd,b.gd; pairs=path:name,path:name); reads as JSON; true/false; integers.
Prints the tool's text answer, then the RESULT line. Does not need the `mcp` package.
"""
from __future__ import annotations

import inspect
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import mcp_tools

INTS = {"start", "end", "budget"}
BOOLS = {"regex", "all"}

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
        elif key == "reads":
            try:
                out[key] = json.loads(val)
            except ValueError:
                agent_log.fail(f"reads must be a JSON list of objects, got {val[:60]!r}")
        elif key == "pairs":
            out[key] = [v.split(":", 1) for v in val.split(",") if ":" in v]
        else:
            out[key] = val
    return out

def tool_help() -> str:
    """Each tool's arguments (from mcp_tools.Tools, `whole` shown as `all`) and its MCP description, for --help."""
    import mcp_serve

    docs = {"lookup": mcp_serve.LOOKUP_DOC, "check": mcp_serve.CHECK_DOC, "protocol": mcp_serve.PROTOCOL_DOC}
    out = ["tools (key=value; the same arguments and replies as the MCP; values: true/false, integers, files=a.gd,b.gd,",
           "  pairs=path:name,path:name, reads='[{...},...]' as JSON):"]
    for name, doc in docs.items():
        args = ["all" if a == "whole" else a for a in inspect.signature(getattr(mcp_tools.Tools, name)).parameters if a != "self"]
        out += [f"  {name}: {' '.join(args)}"] + [f"    {ln}" for ln in doc.splitlines()]
    return "\n".join(out)

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Run one wdb MCP tool call (lookup, check, protocol) from a shell.")
    ap.epilog = tool_help()
    ap.add_argument("tool", choices=("lookup", "check", "protocol"), help="Which MCP tool.")
    ap.add_argument("kv", nargs="*", help="key=value arguments, as the MCP tool takes them.")
    ap.add_argument("--surface", default="", help="Catalog surface letter for a non-Build caller (D, B); also turns the Build rerun limit off.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    tools = mcp_tools.Tools(root, args.surface or "D", rerun_limit=not args.surface)
    kw = parse(args.kv)
    if "all" in kw:
        kw["whole"] = kw.pop("all")
    text = getattr(tools, args.tool)(**kw)
    status = "PASS" if text.startswith("STATUS: PASS") else "FAIL"
    m = re.search(r"(?:more: handle=|^handle: )([a-z][0-9a-f]{6})", text, re.M)
    return agent_log.finish("mcp-call", root, text, status, args=args, tool=args.tool, handle=m.group(1) if m else None)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
