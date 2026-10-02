#!/usr/bin/env python3
"""Bake the hub light atlas (assets/baked/hub_light.png) through the --wdb-bake-camp hook.

    python3 tools/run_bake_camp.py [--timeout-sec 180] [--headless]

Default is a real renderer: uses $DISPLAY / a live X socket, else xvfb-run (godot_lib.pick_display), software GL
is fine. Headless (--headless, or no display and no xvfb-run) draws no shadow pixels (shadow_px=0), so that run
is INFO, not a bake. Never rewrites camp.tscn. Per-path Godot lock; never kills godot*.
Summary: _logs/bake-camp/summary.txt; RESULT carries clean=, shadow_px=, display=.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib

GUI_HEAD = ["--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bake hub_light.png through the --wdb-bake-camp hook (real renderer by default).", json_out=True)
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=180)
    ap.add_argument("--headless", action="store_true", help="force the headless driver (no shadow pixels; INFO only)")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    d = agent_log.ensure_agent_log_dir("bake-camp", root)
    out_log, err_log = d / "bake-out.log", d / "bake-err.log"
    kind = "headless" if args.headless else godot_lib.pick_display()[0]
    gui = kind != "headless" and kind != "none"
    print(f"Baking hub light (display={kind})...")
    gargs = GUI_HEAD + ["--path", str(root), "--", "--wdb-bake-camp"] if gui else godot_lib.headless_args(root, "--wdb-bake-camp")
    r = godot_lib.run_godot(root, root, gargs, out_log, err_log, args.timeout_sec, gui=gui)
    hits = godot_lib.grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|bake_camp:")
    hard = any(godot_lib.HARD_RE.search(h) for h in hits)
    px = [int(m.group(1)) for h in hits for m in [re.search(r"shadow_px=(\d+)", h)] if m]
    shadow = px[-1] if px else 0
    clean = r["status"] == "EXIT=0" and not hard
    status = "PASS" if clean else "FAIL"
    if clean and shadow == 0:
        status = "FAIL" if gui else "INFO"
    body = ["bake camp root=.", f"status={r['status']} ms={r['ms']} display={kind} shadow_px={shadow} errBytes={r['err_bytes']} outBytes={r['out_bytes']}",
            "", "--- highlights ---"] + (hits[:120] or ["(no SCRIPT ERROR / WARNING highlights)"])
    return agent_log.finish("bake-camp", root, "\n".join(body), status, args=args,
                            clean=str(clean).lower(), shadow_px=shadow, display=kind)


if __name__ == "__main__":
    raise SystemExit(main())
