#!/usr/bin/env python3
"""Bake the hub light atlas (assets/baked/hub_light.png) through the --wdb-bake-camp hook.

    python tools/bake.py camp [--timeout-sec 180] [--headless]

Default is a real renderer: uses $DISPLAY / a live X socket, else xvfb-run (godot_lib.pick_display), software GL
is fine. --headless (or no display and no xvfb-run) forces the headless driver. The atlas is the runtime yard render
(day gradient, cast skirts, blur: all CPU), saved as is. shadow_px=0 is a FAIL in either mode (no box cast: the Layout
did not realize). After a bake, review the shots, then paste RESULT stamp= into HUB_BAKE_STAMP (hub_bake.gd): the game
loads only a png with that stamp and crashes at the hub otherwise (bake.py check is the no-Godot check).
Then bakes assets/baked/ground_wear.png (bake.py ground; same bytes each run). Never rewrites camp.tscn. Per-path Godot lock; never kills godot*.
Summary: _logs/bake-camp/<stamp>-bake-camp.txt; RESULT carries clean=, shadow_px=, stamp=, display=.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import godot_lib

GUI_HEAD = ["--audio-driver", "Dummy", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3"]

def draw_overlay(root: Path, err_log: Path, out: Path, org: float = -18.0, sub: float = 16.0) -> None:
    """Outlines what the bake was told about each caster, so a shadow that misses its geometry names which box is off."""
    from PIL import Image, ImageDraw
    im = Image.open(root / "assets/baked/hub_light.png").convert("RGB")
    d = ImageDraw.Draw(im)
    px = lambda x, z: ((x - org) * sub, (z - org) * sub)
    for line in err_log.read_text(encoding="utf-8", errors="replace").splitlines():
        f = line.split()
        if len(f) < 3 or f[0] != "bake_dbg:":
            continue
        n = [float(v) for v in f[3:]]
        if f[1] == "box":  # kind x z hx hz h
            d.rectangle([*px(n[0] - n[2], n[1] - n[3]), *px(n[0] + n[2], n[1] + n[3])], outline=(255, 220, 0))
        elif f[1] == "prot":  # name x z w d
            d.rectangle([*px(n[0], n[1]), *px(n[0] + n[2], n[1] + n[3])], outline=(255, 40, 40))
        elif f[1] == "cast":  # name x z w d top
            d.rectangle([*px(n[0], n[1]), *px(n[0] + n[2], n[1] + n[3])], outline=(0, 220, 255))
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bake hub_light.png through the --wdb-bake-camp hook (real renderer by default).", json_out=True)
    ap.add_argument("--timeout-sec", type=int, default=180, help="Godot timeout in seconds (default 180).")
    ap.add_argument("--headless", action="store_true", help="force the headless driver (same atlas, no display needed)")
    ap.add_argument("--overlay", nargs="?", const="_out/bake-camp/overlay.png", metavar="PNG", help="also write the bake with skirt boxes (yellow), protected footprints (red) and caster bounds (cyan) outlined, from the bake_dbg lines")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    out_log, err_log = agent_log.run_path("bake-camp", root, "bake-out.log"), agent_log.run_path("bake-camp", root, "bake-err.log")
    kind = "headless" if args.headless else godot_lib.pick_display()[0]
    gui = kind != "headless" and kind != "none"
    print(f"Baking hub light (display={kind})...")
    gargs = GUI_HEAD + ["--path", str(root), "--", "--wdb-bake-camp"] if gui else godot_lib.headless_args(root, "--wdb-bake-camp")
    r = godot_lib.run_godot(root, root, gargs, out_log, err_log, args.timeout_sec, gui=gui)
    hits = godot_lib.grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|bake_camp:")
    hard = any(godot_lib.HARD_RE.search(h) for h in hits)
    px = [int(m.group(1)) for h in hits for m in [re.search(r"shadow_px=(\d+)", h)] if m]
    shadow = px[-1] if px else 0
    stamps = [m.group(1) for h in hits for m in [re.search(r"stamp=([0-9a-f]+)", h)] if m]
    stamp = stamps[-1] if stamps else "none"

    if stamp != "none":
        hub = root / "scripts/graphics/light_rt/hub_bake.gd"
        if hub.is_file():
            ht = hub.read_text(encoding="utf-8")
            ht2 = re.sub(r'const HUB_BAKE_STAMP := "[0-9a-f]+"', f'const HUB_BAKE_STAMP := "{stamp}"', ht, count=1)
            if ht2 != ht:
                hub.write_text(ht2, encoding="utf-8")
                print(f"updated HUB_BAKE_STAMP={stamp}")
    clean = r["status"] == "EXIT=0" and not hard
    overlay = args.overlay or ""
    if overlay:
        draw_overlay(root, err_log, Path(overlay) if Path(overlay).is_absolute() else root / overlay)
    import bake_ground_wear
    if bake_ground_wear.main(["--root", str(root)]) != 0:
        clean = False
    status = "PASS" if clean else "FAIL"
    if clean and shadow == 0:
        status = "FAIL"
    body = ["bake camp root=.", f"status={r['status']} ms={r['ms']} display={kind} shadow_px={shadow} stamp={stamp} errBytes={r['err_bytes']} outBytes={r['out_bytes']}",
            "", "--- highlights ---"] + (hits[:120] or ["(no SCRIPT ERROR / WARNING highlights)"])
    return agent_log.finish("bake-camp", root, "\n".join(body), status, args=args,
                            clean=str(clean).lower(), shadow_px=shadow, stamp=stamp, display=kind, **({"overlay": overlay} if overlay else {}))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
