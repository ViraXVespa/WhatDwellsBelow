#!/usr/bin/env python3
"""Pack corrected left-facing player sheets with magenta key + despill."""
from pathlib import Path
from PIL import Image
import math
import numpy as np
from imglib import imgio, key as plate_key  # noqa: E402
from imglib.geom import fit_box  # noqa: E402
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

ROOT = Path(__file__).resolve().parent.parent
SRC = agent_log.grok_sessions(r"C%3A%5CUsers%5CVira%5Csource%5CRepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images")
FRAMES = ROOT / "_src" / "anim_frames"
OUT = ROOT / "assets" / "live" / "player"
LAWN = (124, 252, 0)
WALK_PICKS = [8, 12, 16, 20]
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


def fit(im: Image.Image, canvas: int = 128, pad: int = 6) -> Image.Image:
    return fit_box(im, canvas, pad, to_int=int, oy=lambda nh: canvas - nh)


def save_img(im: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    fit(key(im)).save(dest)
    print("wrote", dest.relative_to(ROOT))


def pack_cycle(folder: str, prefix: str, picks: list[int]) -> None:
    for i, fi in enumerate(picks):
        src = FRAMES / folder / f"f{fi:03d}.png"
        if not src.exists():
            print("missing", src)
            continue
        save_img(imgio.load(src), OUT / f"{prefix}_{i}.png")


def _run() -> None:
    save_img(imgio.load(SRC / "190.jpg"), OUT / "left.png")
    save_img(imgio.load(SRC / "188.jpg"), OUT / "up_left.png")
    save_img(imgio.load(SRC / "189.jpg"), OUT / "down_left.png")
    pack_cycle("player_walk_left", "walk_left", WALK_PICKS)
    pack_cycle("player_walk_up_left", "walk_up_left", WALK_PICKS)
    pack_cycle("player_walk_down_left", "walk_down_left", WALK_PICKS)
    pack_cycle("player_attack_left", "attack_left", ATK_PICKS)
    pack_cycle("player_attack_up_left", "attack_up_left", ATK_PICKS)
    pack_cycle("player_attack_down_left", "attack_down_left", ATK_PICKS)
    print("facing fix packed")


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("pack_facing_fix", "Pack corrected left-facing player sheets with magenta key + despill.", _run, argv, globals())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
