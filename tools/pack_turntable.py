#!/usr/bin/env python3
"""Pack 8-dir player sheets from turntable + facing clips, shared scale and torso pin."""
from pathlib import Path
from PIL import Image
import math
from imglib import geom, imgio, key as plate_key  # noqa: E402
import numpy as np
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "_src" / "anim_frames"
IMG = agent_log.grok_sessions(r"C%3A%5CUsers%5CVira%5Csource%5CRepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images")
OUT = ROOT / "assets" / "live" / "player"
CANVAS = 128
CHAR_H = 110
LAWN = (124, 252, 0)
PICKS = [8, 12, 16, 20]
ATK_PICKS = [8, 18, 28, 38]


def key(im: Image.Image) -> Image.Image:
    keyed = plate_key.punch(im)
    arr = np.array(keyed)
    rgb = arr[:, :, :3].astype(np.float32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    lawn_d = np.sqrt(((rgb - np.array(LAWN, np.float32)) ** 2).sum(axis=-1))
    lawn = (lawn_d <= 72.0) | ((g > 150) & (g > r + 40) & (g > b + 40))
    arr[lawn] = 0
    return Image.fromarray(arr, "RGBA")


def torso_x(im: Image.Image) -> int:
    px = im.load()
    w, h = im.size
    xs = []
    y0 = int(h * 0.72)
    for y in range(y0, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 30:
                continue
            cyan = b > r + 15 and b > g + 10 and b > 80
            if cyan:
                continue
            xs.append(x)
    if not xs:
        return w // 2
    xs.sort()
    return xs[len(xs) // 2]


def place(im: Image.Image) -> Image.Image:
    im = key(im)
    ch = geom.fit_axis(im, height=CHAR_H)
    if ch is None:
        return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    nh = CHAR_H
    tx = torso_x(ch)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x0 = CANVAS // 2 - tx
    y0 = CANVAS - nh
    out.paste(ch, (x0, y0), ch)
    return out


def save(im: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    place(im).save(dest)
    print("wrote", dest.relative_to(ROOT))


def frame(folder: str, i: int) -> Path:
    return FRAMES / folder / f"f{i:03d}.png"


def pack_list(folder: str, idxs: list, dest_prefix: str) -> None:
    n = 0
    for i in idxs:
        p = frame(folder, i)
        if not p.exists():
            print("missing", p)
            continue
        save(imgio.load(p), OUT / f"{dest_prefix}_{n}.png")
        n += 1


def _run() -> None:
    # Idles from stills + turntable
    save(imgio.load(ROOT / "assets" / "live" / "player" / "down.png"), OUT / "down.png")
    save(imgio.load(IMG / "191.jpg"), OUT / "right.png")
    save(imgio.load(IMG / "192.jpg"), OUT / "down_right.png")
    save(imgio.load(IMG / "193.jpg"), OUT / "up_right.png")
    save(imgio.load(IMG / "194.jpg"), OUT / "down_left.png")
    save(imgio.load(frame("turn_walk", 30)), OUT / "left.png")
    save(imgio.load(frame("turn_walk", 45)), OUT / "up.png")
    save(imgio.load(frame("turn_walk", 60)), OUT / "up_left.png")

    pack_list("turn_walk", [0, 8, 12, 16], "walk_down")
    pack_list("turn_walk", [28, 30, 32, 36], "walk_left")
    pack_list("turn_walk", [44, 46, 48, 52], "walk_up")
    pack_list("turn_walk", [56, 60, 64, 68], "walk_up_left")
    pack_list("walk_right_new", PICKS, "walk_right")
    pack_list("walk_down_right_new", PICKS, "walk_down_right")
    pack_list("walk_up_right_new", PICKS, "walk_up_right")
    pack_list("walk_down_left_new", PICKS, "walk_down_left")

    pack_list("turn_atk", [0, 8, 12, 18], "attack_down")
    pack_list("turn_atk", [70, 74, 78, 82], "attack_left")
    pack_list("turn_atk", [50, 54, 58, 62], "attack_up")
    pack_list("turn_atk", [26, 30, 34, 38], "attack_up_left")
    pack_list("atk_right_new", ATK_PICKS, "attack_right")
    pack_list("atk_down_right_new", ATK_PICKS, "attack_down_right")
    pack_list("atk_up_right_new", ATK_PICKS, "attack_up_right")
    pack_list("atk_down_left_new", ATK_PICKS, "attack_down_left")
    print("turntable pack done")


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("pack_turntable", "Pack 8-dir player sheets from turntable + facing clips, shared scale and torso pin.", _run, argv, globals())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
