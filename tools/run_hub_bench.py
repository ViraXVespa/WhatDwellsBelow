#!/usr/bin/env python3
"""One hub bench walk on a real display. Per-path Godot lock; never kills godot*.

    python tools/run_hub_bench.py [--timeout-sec 240]
Opens a window (project renderer, gl_compatibility). --headless is not an FPS reading.
Summary: _logs/hub-bench/<stamp>-hub-bench.txt.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib


def _hitches(path: str) -> list[dict]:
    p = Path(path)
    if path == "" or not p.is_file():
        return []
    rows: list[dict] = []
    for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(row, dict) and row.get("ev") == "hitch":
            rows.append(row)
    rows.sort(key=lambda r: float(r.get("dt_ms", 0)), reverse=True)
    return rows


# Same window the game uses: project.godot is gl_compatibility / opengl3. No --headless,
# so the present path is in the frame time.
GUI_HEAD = ["--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("One hub bench walk (~60s) on a real display, plus a hitch summary.", json_out=True)
    ap.add_argument("--timeout-sec", type=int, default=240, help="Godot timeout (default 240).")
    ap.add_argument("--headless", action="store_true", help="headless driver (not an FPS reading)")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    out_log = agent_log.run_path("hub-bench", root, "out.log")
    err_log = agent_log.run_path("hub-bench", root, "err.log")
    kind = "headless" if args.headless else godot_lib.pick_display()[0]
    gui = kind != "headless" and kind != "none"
    fresh = Path(root) / "_logs" / "hub-bench-fresh"
    if fresh.exists():
        shutil.rmtree(fresh)
    fresh.mkdir(parents=True)
    print("Running hub bench (display=%s, fresh=%s)..." % (kind, fresh))
    gargs = (
        godot_lib.headless_args(root, "--wdb-hub-bench", "--wdb-hitch-mult=1")
        if not gui
        else GUI_HEAD + ["--path", str(root), "--", "--wdb-hub-bench", "--wdb-hitch-mult=1"]
    )
    old_appdata = os.environ.get("APPDATA")
    os.environ["APPDATA"] = str(fresh)
    try:
        r = godot_lib.run_godot(root, root, gargs, out_log, err_log, args.timeout_sec, gui=gui)
    finally:
        if old_appdata is None:
            os.environ.pop("APPDATA", None)
        else:
            os.environ["APPDATA"] = old_appdata
    hb = godot_lib.grep_logs([err_log, out_log], r"^HB:")
    errs = godot_lib.grep_logs(
        [err_log, out_log],
        r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to|Lambda capture at index",
    )
    path = ""
    ok = False
    for line in hb:
        if "ok=1" in line:
            ok = True
        if "path=" in line:
            path = line.split("path=", 1)[1].strip()
    rows = _hitches(path)
    slow = []
    for row in rows[:8]:
        slow.append(
            "dt_ms=%s why=%s where=%s anim=%s ui=%s cell=%s"
            % (
                row.get("dt_ms", ""),
                row.get("why", ""),
                row.get("where", ""),
                row.get("anim", ""),
                row.get("ui", ""),
                row.get("cell", ""),
            )
        )
    fail = int(r["status"] == "TIMEOUT")
    fail += int(r["status"].startswith("EXIT=") and r["status"] != "EXIT=0")
    fail += int(bool(errs)) + int(not ok)
    body = [
        "hub bench root=.",
        "status=%s wall_ms=%s errBytes=%s outBytes=%s" % (r["status"], r["ms"], r["err_bytes"], r["out_bytes"]),
        "",
        "--- HB lines ---",
    ]
    body += hb or ["(no HB: lines)"]
    body += ["", "--- slowest hitches ---"] + (slow or ["(none)"])
    body += ["", "--- errors ---"] + (errs[:40] or ["(none)"])
    echo = [body[0], body[1], "hitches=%d" % len(rows)]
    echo += hb[-6:] if hb else ["(no HB: lines)"]
    echo += slow[:5]
    if errs:
        echo += ["errors:"] + errs[:5]
    return agent_log.finish(
        "hub-bench",
        root,
        "\n".join(body),
        "FAIL" if fail else "PASS",
        args=args,
        legacy=False,
        echo="\n".join(echo),
        retry=("hub-bench", body),
        fail_signals=fail,
    )


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
