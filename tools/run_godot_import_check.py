#!/usr/bin/env python3
"""Editor import / script-reload check. Per-path Godot lock; never kills godot*.

    python3 tools/run_godot_import_check.py [--timeout-sec 180]
Summary: _logs/godot-import-check/summary.txt; RESULT carries clean=true|false.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Headless editor import check.", json_out=True)
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=180, help="Godot timeout in seconds (default 180).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    d = agent_log.ensure_agent_log_dir("godot-import-check", root)
    out_log, err_log = d / "import-out.log", d / "import-err.log"
    print("Running editor import check...")
    r = godot_lib.run_godot(root, root, ["--headless", "--editor", "--import", "--path", str(root), "--quit"],
                            out_log, err_log, args.timeout_sec)
    hits = godot_lib.grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|WARNING:")
    hard = any(godot_lib.HARD_RE.search(h) for h in hits)
    clean = r["status"] == "EXIT=0" and r["err_bytes"] == 0 and not hard
    body = ["godot import check root=.", f"status={r['status']} ms={r['ms']} errBytes={r['err_bytes']} outBytes={r['out_bytes']}",
            "", "--- highlights ---"] + (hits[:120] or ["(no SCRIPT ERROR / WARNING highlights)"])
    return agent_log.finish("godot-import-check", root, "\n".join(body), "PASS" if clean else "FAIL", args=args,
                            clean=str(clean).lower(), status_godot=r["status"])


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
