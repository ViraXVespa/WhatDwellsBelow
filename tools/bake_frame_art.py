#!/usr/bin/env python3
"""Bake the object-frame art (scripts/ui/progress_ui/*_art.gd) to PNGs under assets/ui/frames/<art>/<key>.png.

  python tools/bake_frame_art.py            draw every skin in code, write the PNGs, import, then --check
  python tools/bake_frame_art.py --check    draw in code and compare with the committed PNGs (FAIL = stale or missing)
  python tools/bake_frame_art.py --time     how long building every skin takes from the PNGs

Re-run after editing any *_art.gd or a frame's dress(); the game loads only the PNGs (art_bake.gd) and a missing
one is an error. New PNG imports get fix_alpha_border off so the pixels match the drawn image exactly.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(_TOOLS))
import agent_log
import godot_lib

ROOT = _TOOLS.parent
FRAMES = ROOT / "assets" / "ui" / "frames"
JOB = "frame-art"


def godot(*args: str, timeout: int = 600) -> str:
    exe = str(godot_lib.godot_exe())
    r = subprocess.run([exe, "--headless", "--path", str(ROOT), *args], capture_output=True, text=True, errors="replace", timeout=timeout)
    return r.stdout + r.stderr


def fix_imports() -> int:
    n = 0
    for imp in FRAMES.rglob("*.png.import"):
        s = imp.read_text(encoding="utf-8")
        t = s.replace("process/fix_alpha_border=true", "process/fix_alpha_border=false")
        if t != s:
            imp.write_text(t, encoding="utf-8", newline="\n")
            n += 1
    return n


def show(out: str) -> bool:
    for line in out.splitlines():
        if line.startswith("FRAME_ART") or godot_lib.HARD_RE.search(line):
            print(line)
    return not godot_lib.HARD_RE.search(out)


def main(argv: list[str] | None = None) -> int:
    global ROOT, FRAMES
    ap = agent_log.std_parser(__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="Compare the code drawing with the committed PNGs; write nothing.")
    ap.add_argument("--time", action="store_true", help="Time building every skin from the PNGs.")
    a = ap.parse_args(sys.argv[1:] if argv is None else argv)
    ROOT = agent_log.resolve_root(a)
    FRAMES = ROOT / "assets" / "ui" / "frames"
    if a.time:
        ok = show(godot("--", "--wdb-frame-art-time"))
    elif a.check:
        out = godot("--", "--wdb-frame-art-check")
        ok = show(out) and re.search(r"stale=0\b", out) is not None
    else:
        ok = show(godot("--", "--wdb-bake-frame-art"))
        godot("--import")
        if fix_imports():
            godot("--import")
        out = godot("--", "--wdb-frame-art-check")
        ok = ok and show(out) and re.search(r"stale=0\b", out) is not None
    return agent_log.finish(JOB, ROOT, "frame art %s" % ("time" if a.time else "check" if a.check else "bake"), "PASS" if ok else "FAIL",
                            args=a, pngs=len(list(FRAMES.rglob("*.png"))))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
