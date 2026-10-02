#!/usr/bin/env python3
"""Pack Phase 4 enemy stills: magenta key, 128 canvas, 8-dir copies."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
from sprite_lib import fit_box

CANVAS = 128
PAD = 8

KEYS = [
    "right",
    "down_right",
    "down",
    "down_left",
    "left",
    "up_left",
    "up",
    "up_right",
]


def is_bg(r: int, g: int, b: int) -> bool:
    if r > 180 and b > 140 and g < 100:
        return True
    if r > 200 and b > 80 and g < 70:
        return True
    if r > 150 and b > 150 and g < 120 and abs(r - b) < 90:
        return True
    return False


def key_bg(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if is_bg(r, g, b):
                px[x, y] = (0, 0, 0, 0)
    return im


def fit_local(im: Image.Image) -> Image.Image:
    return fit_box(im, CANVAS, PAD, oy=lambda nh: max(0, min(CANVAS - nh, CANVAS - nh - 2)))



def pack_one(src: Path, dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    im = key_bg(Image.open(src))
    out = fit_local(im)
    down = dest_dir / "idle_down.png"
    out.save(down)
    flipped = out.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    for k in KEYS:
        p = dest_dir / f"idle_{k}.png"
        if k in ("left", "up_left", "down_left"):
            flipped.save(p)
        else:
            out.save(p)
    return down


def _run(img: Path, dest_root: Path) -> int:
    mapping = {
        "21.jpg": "orc",
        "22.jpg": "spider",
        "23.jpg": "goblin",
        "24.jpg": "slime",
        "25.jpg": "archer",
        "26.jpg": "skeleton",
        "27.jpg": "shaman",
        "28.jpg": "bat",
        "29.jpg": "gate_master",
        "30.jpg": "imp",
        "31.jpg": "wolf",
        "32.jpg": "wisp",
        "33.jpg": "beetle",
        "34.jpg": "guardian",
    }
    packed = 0
    for name, typ in mapping.items():
        src = img / name
        if not src.exists():
            print("missing", src)
            continue
        out = pack_one(src, dest_root / typ)
        print("packed", typ, "->", out)
        packed += 1
    return packed


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Pack the Phase 4 enemy stills (21.jpg..34.jpg) into per-type sprite folders.")
    ap.add_argument("image_dir", type=Path, help="Folder holding 21.jpg .. 34.jpg")
    ap.add_argument("dest_root", type=Path, help="Destination root; one folder per enemy type")
    args = ap.parse_args(argv)
    packed = _run(args.image_dir, args.dest_root)
    return agent_log.emit_result("PASS" if packed else "FAIL", packed=packed)


if __name__ == "__main__":
    raise SystemExit(main())
