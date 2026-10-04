#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import math
from imglib import geom, imgio  # noqa: E402
from imglib.color import dist  # noqa: E402
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

ROOT = Path(__file__).resolve().parent.parent
CANVAS = 128
THRESH = 62


def sample_bg(im: Image.Image) -> tuple:
    px = im.convert("RGB")
    w, h = px.size
    samples = [px.getpixel((2, 2)), px.getpixel((w - 3, 2)), px.getpixel((2, h - 3)), px.getpixel((w - 3, h - 3))]
    return tuple(int(sum(c[i] for c in samples) / 4) for i in range(3))


def key_and_fit(src: Path, dest: Path, flip: bool = False) -> None:
    im = imgio.load(src)
    if flip:
        im = geom.flip(im)
    bg = sample_bg(im)
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if dist((r, g, b), bg) <= THRESH:
                px[x, y] = (0, 0, 0, 0)
    canvas = geom.fit_box(im, CANVAS, 8, to_int=int, empty_exit=f"empty {src}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest)
    print("wrote", dest)


def _run() -> None:
    jobs = [
        ("bruiser", "idle", "down", ROOT / "_src/bruiser_idle_down.jpg", False),
        ("bruiser", "idle", "right", ROOT / "_src/bruiser_idle_right.jpg", False),
        ("bruiser", "idle", "left", ROOT / "_src/bruiser_idle_left.jpg", False),
        ("bruiser", "idle", "up", ROOT / "_src/bruiser_idle_up.jpg", False),
        ("bruiser", "windup", "down", ROOT / "_atk_15.jpg", False),
        ("bruiser", "strike", "down", ROOT / "_atk_16.jpg", False),
        ("bruiser", "windup", "right", ROOT / "_atk_17.jpg", False),
        ("bruiser", "strike", "right", ROOT / "_atk_13.jpg", False),
        ("bruiser", "windup", "left", ROOT / "_atk_17.jpg", True),
        ("bruiser", "strike", "left", ROOT / "_atk_19.jpg", False),
        ("bruiser", "windup", "up", ROOT / "_atk_14.jpg", False),
        ("bruiser", "strike", "up", ROOT / "_atk_18.jpg", False),
        ("tank", "idle", "down", ROOT / "_src/tank_idle_down.jpg", False),
        ("tank", "idle", "right", ROOT / "_src/tank_idle_right.jpg", False),
        ("tank", "idle", "left", ROOT / "_src/tank_idle_left.jpg", False),
        ("tank", "idle", "up", ROOT / "_src/tank_idle_up.jpg", False),
    ]
    for role, pose, facing, src, flip in jobs:
        dest = ROOT / "assets" / "sprites" / "enemies" / role / f"{pose}_{facing}.png"
        key_and_fit(src, dest, flip=flip)


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("process_enemies", 'Key the _src enemy stills into the live enemy sprites.', _run, argv, globals())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
