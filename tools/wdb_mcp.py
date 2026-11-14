#!/usr/bin/env python3
"""wdb MCP for Grok Build: three read-only, progressive tools (lookup, check, protocol) over the real repository commands.

`python tools/wdb_mcp.py` lists the subcommands; `python tools/wdb_mcp.py SUB --help` prints that one's flags.
Grok Build starts `serve` itself from `.grok/config.toml`; `call` runs one tool from a shell (tests, the Bot, debugging).
The work lives in tools/lib/wdb_mcp/; this file only maps names to modules. Not named mcp.py: that would shadow the `mcp` package.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("serve", "wdb_mcp/mcp_serve", "stdio MCP server (Grok Build starts it from .grok/config.toml); --selftest"),
    ("call",  "wdb_mcp/mcp_call",  "Run one MCP tool call from a shell: TOOL key=value ... (same handles and state as serve)"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
