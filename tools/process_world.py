#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import math
import shutil
from imglib import geom, imgio, key as plate_key  # noqa: E402
from imglib.color import dist  # noqa: E402
from imglib.geom import fit_box  # noqa: E402
import numpy as np
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

ROOT = Path(__file__).resolve().parent.parent
SRC = agent_log.grok_sessions(r"C%3A%5CUsers%5CVira%5Csource%5Crepos%5CGrokSandbox%5Cwhat-dwells-below\01a01725-c75b-79f2-967f-30d19272bef6\images")
THRESH = 58
CANVAS = 128


def sample_bg(im: Image.Image) -> tuple:
    rgb = im.convert("RGB")
    w, h = rgb.size
    pts = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3), (w // 2, 2), (2, h // 2)]
    cols = [rgb.getpixel(p) for p in pts]
    return tuple(int(sum(c[i] for c in cols) / len(cols)) for i in range(3))


def key(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    bg = sample_bg(im)
    if plate_key.looks_like_plate(bg):
        return plate_key.punch(im)
    arr = np.array(im)
    rgb = arr[:, :, :3].astype(np.float32)
    d = np.sqrt(((rgb - np.array(bg, np.float32)) ** 2).sum(axis=-1))
    arr[d <= THRESH] = 0
    return Image.fromarray(plate_key.strip_rim(arr), "RGBA")


def fit(im: Image.Image, canvas: int, pad: int = 6) -> Image.Image:
    return fit_box(im, canvas, pad, to_int=int, empty_exit="empty after key")


def sprite(src_name: str, dest: Path, canvas: int = CANVAS) -> None:
    im = key(imgio.load(SRC / src_name))
    dest.parent.mkdir(parents=True, exist_ok=True)
    fit(im, canvas).save(dest)
    print("sprite", dest)


def crop_tile(src_name: str, dest: Path, box_frac, size: int = 64) -> None:
    im = imgio.load(SRC / src_name, "RGB")
    w, h = im.size
    x0, y0, x1, y1 = box_frac
    crop = im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))
    tile = crop.resize((size, size), Image.Resampling.BOX)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tile.save(dest)
    print("tile", dest)


def wall_tile(src_name: str, dest: Path, size: int = 64) -> None:
    im = imgio.load(SRC / src_name)
    px = im.load()
    w, h = im.size
    fill = (48, 54, 68, 255)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 225 and g > 225 and b > 225:
                px[x, y] = fill
    bbox = geom.bbox(im)
    cropped = im.crop(bbox)
    tile = cropped.resize((size, size), Image.Resampling.BOX)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tile.convert("RGB").save(dest)
    print("wall", dest)


def building(src_name: str, dest: Path, max_w: int) -> None:
    im = key(imgio.load(SRC / src_name))
    resized = geom.fit_axis(im, width=max_w, empty="whole")
    dest.parent.mkdir(parents=True, exist_ok=True)
    resized.save(dest)
    print("building", dest, resized.size)


def _run() -> None:
    tiles = ROOT / "assets" / "tiles"
    props = ROOT / "assets" / "sprites" / "props"
    npcs = ROOT / "assets" / "sprites" / "npcs"
    bld = ROOT / "assets" / "sprites" / "buildings"

    crop_tile("46.jpg", tiles / "dungeon_floor.png", (0.28, 0.28, 0.72, 0.72))
    crop_tile("46.jpg", tiles / "dungeon_floor_b.png", (0.08, 0.42, 0.52, 0.86))
    crop_tile("37.jpg", tiles / "plaza_ground.png", (0.22, 0.22, 0.78, 0.78))
    crop_tile("37.jpg", tiles / "plaza_ground_b.png", (0.05, 0.40, 0.55, 0.90))
    wall_tile("42.jpg", tiles / "dungeon_wall.png")

    wall = imgio.load(tiles / "dungeon_wall.png", "RGB")
    px = wall.load()
    w, h = wall.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            px[x, y] = (min(255, int(r * 1.15 + 18)), min(255, int(g * 0.95 + 8)), max(0, int(b * 0.72)))
    wall.save(tiles / "plaza_wall.png")
    print("wall", tiles / "plaza_wall.png")

    sprite("33.jpg", props / "crystal.png")
    sprite("44.jpg", props / "stairs.png")
    sprite("49.jpg", props / "ore.png")
    sprite("35.jpg", props / "chest.png")
    sprite("39.jpg", props / "anvil.png")
    sprite("47.jpg", props / "dumpster.png")
    sprite("54.jpg", props / "sign.png")
    sprite("48.jpg", props / "bolt.png", canvas=48)

    sprite("43.jpg", npcs / "miner.png")
    sprite("51.jpg", npcs / "lumberjack.png")
    sprite("52.jpg", npcs / "alchemist.png")
    sprite("57.jpg", npcs / "stonemason.png")
    sprite("56.jpg", npcs / "fishmonger.png")
    sprite("50.jpg", npcs / "gopher.png")
    sprite("58.jpg", npcs / "runner.png")
    sprite("55.jpg", npcs / "vendor.png")
    shutil.copyfile(npcs / "gopher.png", npcs / "patty.png")

    building("40.jpg", bld / "guild.png", 320)
    building("41.jpg", bld / "stall.png", 320)

    check = ROOT / "tools" / "_tilecheck"
    check.mkdir(parents=True, exist_ok=True)
    for name in ["dungeon_floor", "dungeon_floor_b", "plaza_ground", "plaza_ground_b"]:
        t = Image.open(tiles / f"{name}.png")
        canvas = Image.new("RGB", (t.size[0] * 2, t.size[1] * 2))
        for y in range(2):
            for x in range(2):
                canvas.paste(t, (x * t.size[0], y * t.size[1]))
        geom.scale_nearest(canvas, size=(256, 256)).save(check / f"{name}_2x2.png")


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("process_world", 'Key and fit the _src world stills (tiles, props) into assets/.', _run, argv, globals())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
