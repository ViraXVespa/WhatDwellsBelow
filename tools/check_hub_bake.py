#!/usr/bin/env python3
"""Hub bake check: the committed assets/baked/hub_light.png must match HUB_BAKE_STAMP in hub_bake.gd.

    python tools/check_hub_bake.py [--root R] [--json]

The game loads only a baked hub image whose size matches the Layout and whose RGBA8 pixels hash to HUB_BAKE_STAMP
(first 16 hex of SHA-256), and crashes with a FATAL message otherwise. This is the same hash without Godot, so a stale
bake fails here (run_build_gate.py --batch) before it breaks the hub. Fix: tools/run_bake_camp.py, review, paste stamp=.
RESULT PASS = png present, size >= 16, stamp equal; FAIL otherwise. Summary: _logs/hub-bake/.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log

PNG = "assets/baked/hub_light.png"
SRC = "scripts/graphics/light_rt/hub_bake.gd"


def png_stamp(path: Path) -> tuple[str, int, int]:
    from PIL import Image
    with Image.open(path) as im:
        rgba = im.convert("RGBA")
        return hashlib.sha256(rgba.tobytes()).hexdigest()[:16], rgba.width, rgba.height


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check that the committed hub_light.png matches HUB_BAKE_STAMP.", json_out=True)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    png, src = root / PNG, root / SRC
    lines: list[str] = []
    m = re.search(r'const HUB_BAKE_STAMP := "([0-9a-f]*)"', src.read_text(encoding="utf-8"))
    want = m.group(1) if m else ""
    got, w, h = ("", 0, 0)
    if not m:
        lines.append(f"FAIL {SRC}: no `const HUB_BAKE_STAMP := \"<hex>\"` line")
    elif not png.is_file():
        lines.append(f"FAIL {PNG} is missing: the game crashes at the hub")
    else:
        got, w, h = png_stamp(png)
        if min(w, h) < 16:
            lines.append(f"FAIL {PNG} is {w}x{h}")
        elif got != want:
            lines.append(f"FAIL {PNG} stamp {got} != HUB_BAKE_STAMP {want or '(empty)'}: rebake with tools/run_bake_camp.py, "
                         "review, paste its stamp= into hub_bake.gd")
    ok = not lines
    if ok:
        lines.append(f"hub bake ok: {PNG} {w}x{h} stamp={got}")
    status = "PASS" if ok else "FAIL"
    out_dir = agent_log.ensure_agent_log_dir("hub-bake", root)
    res = agent_log.write_run_file(root, out_dir, "hub-bake", "\n".join(lines), status, stamp=got or "none", want=want or "none")
    if args.json:
        agent_log.print_json({"status": status, "stamp": got, "want": want, "size": [w, h], "lines": lines})
    else:
        print("\n".join(lines + [res]))
    return agent_log.exit_code(status)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
