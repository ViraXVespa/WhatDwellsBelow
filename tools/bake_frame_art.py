#!/usr/bin/env python3
"""Bake the object-frame art (scripts/ui/progress_ui/*_art.gd) to PNGs under assets/ui/frames/<art>/<key>.png.

  python tools/bake_frame_art.py            draw every skin in code, write the PNGs, import, then --check
  python tools/bake_frame_art.py --check    draw in code and compare with the committed PNGs (FAIL = stale or missing)
  python tools/bake_frame_art.py --time     how long building every skin takes from the PNGs

Re-run after editing any *_art.gd or a frame's dress(); the game loads only the PNGs (art_bake.gd) and a missing
one is an error. New PNG imports get fix_alpha_border off so the pixels match the drawn image exactly.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(_TOOLS))
import godot_lib

ROOT = _TOOLS.parent
FRAMES = ROOT / "assets" / "ui" / "frames"


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
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--time", action="store_true")
    a = ap.parse_args(argv)
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
    print(f"RESULT {'PASS' if ok else 'FAIL'} pngs={len(list(FRAMES.rglob('*.png')))}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
