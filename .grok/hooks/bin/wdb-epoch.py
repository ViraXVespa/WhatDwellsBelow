#!/usr/bin/env python3
"""PostCompact / SessionStart(resume) hook: start a new wdb MCP epoch.

After a compact the model no longer holds what the MCP sent, so the MCP must stop eliding those lines.
Passive event: always exits 0; prints nothing the model sees.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/lib"))
sys.path.insert(0, str(ROOT / "tools/lib/wdb_mcp"))

def main() -> int:
    if "--selftest" in sys.argv[1:]:
        import tempfile

        import mcp_core

        with tempfile.TemporaryDirectory() as td:
            a = mcp_core.read_epoch(ROOT, Path(td))
            b = mcp_core.bump_epoch(ROOT, Path(td))
            ok = a == "0" and b == "1" and mcp_core.read_epoch(ROOT, Path(td)) == "1"
        print("RESULT " + ("PASS" if ok else "FAIL") + " cmd=selftest")
        return 0 if ok else 1
    try:
        import mcp_core

        mcp_core.bump_epoch(ROOT)
    except Exception:  # a passive hook never blocks the session
        pass
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
