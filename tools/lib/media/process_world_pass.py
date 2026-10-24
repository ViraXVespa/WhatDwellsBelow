#!/usr/bin/env python3
"""Key and install the Placeholdia / dungeon art pass stills."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
from sprite_pipeline import fit_canvas  # noqa: E402

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
from imglib import geom, imgio, key as plate_key, overlay  # noqa: E402

SESSION = agent_log.grok_sessions(r"C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a08788-1bb6-76c0-8fa8-40b73dda2810\images")
TILES = ROOT / "assets" / "tiles"
PROPS = ROOT / "assets" / "sprites" / "props"
NPCS = ROOT / "assets" / "sprites" / "npcs"
BLD = ROOT / "assets" / "sprites" / "buildings"
FX = ROOT / "assets" / "fx"
CHECK = ROOT / "tools" / "_tilecheck"

QUADS = {
    "tl": (0.0, 0.0, 0.5, 0.5),
    "tr": (0.5, 0.0, 1.0, 0.5),
    "bl": (0.0, 0.5, 0.5, 1.0),
    "br": (0.5, 0.5, 1.0, 1.0),
}

def load(name: str) -> Image.Image:
    return imgio.load(SESSION / name)

def crop_frac(im: Image.Image, frac: tuple[float, float, float, float]) -> Image.Image:
    w, h = im.size
    x0, y0, x1, y1 = frac
    return im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))

def make_seamless(im: Image.Image, blend: int = 10) -> Image.Image:
    rgb = im.convert("RGB")
    arr = np.array(rgb, dtype=np.float32)
    h, w = arr.shape[:2]
    arr = np.roll(arr, w // 2, axis=1)
    arr = np.roll(arr, h // 2, axis=0)
    r = min(blend, w // 8, h // 8)
    for i in range(r):
        t = (i + 1) / (r + 1)
        cx = w // 2
        cy = h // 2
        a = t
        arr[:, cx - r + i] = arr[:, cx - r + i] * (1.0 - a) + arr[:, cx + r - 1 - i] * a
        arr[:, cx + r - 1 - i] = arr[:, cx - r + i]
        arr[cy - r + i, :] = arr[cy - r + i, :] * (1.0 - a) + arr[cy + r - 1 - i, :] * a
        arr[cy + r - 1 - i, :] = arr[cy - r + i, :]
    arr = np.roll(arr, -(w // 2), axis=1)
    arr = np.roll(arr, -(h // 2), axis=0)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")

def tile_out(src: str, dest: Path, size: int = 128, quad: str | None = None) -> None:
    im = load(src)
    if quad:
        im = crop_frac(im, QUADS[quad])
    w, h = im.size
    side = min(w, h)
    im = im.crop(((w - side) // 2, (h - side) // 2, (w - side) // 2 + side, (h - side) // 2 + side))
    im = im.convert("RGB").resize((size, size), Image.Resampling.BOX)
    im = make_seamless(im)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    canvas = Image.new("RGB", (size * 2, size * 2))
    for y in range(2):
        for x in range(2):
            canvas.paste(im, (x * size, y * size))
    CHECK.mkdir(parents=True, exist_ok=True)
    canvas.save(CHECK / f"{dest.stem}_2x2.png")
    print("tile", dest.name, im.size)

def key_sprite(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    rgb = np.array(im)[:, :, :3]
    corners = np.stack([rgb[2, 2], rgb[2, -3], rgb[-3, 2], rgb[-3, -3]], axis=0)
    if plate_key.looks_like_plate(corners.mean(axis=0)):
        return plate_key.punch(im)
    arr = np.array(im)
    bg = corners.mean(axis=0)
    dist = np.sqrt(((rgb.astype(np.float32) - bg) ** 2).sum(axis=2))
    mag = np.array([255.0, 0.0, 255.0], dtype=np.float32)
    dmag = np.sqrt(((rgb.astype(np.float32) - mag) ** 2).sum(axis=2))
    keyed = (dist <= 62.0) | (dmag <= 72.0)
    arr[keyed] = 0
    return Image.fromarray(plate_key.strip_rim(arr), "RGBA")

def sprite_out(src: str, dest: Path, canvas: int = 128, quad: str | None = None) -> None:
    im = load(src)
    if quad:
        im = crop_frac(im, QUADS[quad])
    keyed = key_sprite(im)
    out = fit_canvas(keyed, canvas, key=False)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    print("sprite", dest.name, out.size)

def wide_out(src: str, dest: Path, max_w: int, quad: str | None = None, key_black: bool = False) -> None:
    im = load(src)
    if quad:
        im = crop_frac(im, QUADS[quad])
    keyed = key_sprite(im)
    if key_black:
        keyed = keyed.copy()
        px = keyed.load()
        w, h = keyed.size
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a > 0 and r < 18 and g < 18 and b < 18:
                    px[x, y] = (0, 0, 0, 0)
    resized = geom.fit_axis(keyed, width=max_w)
    if resized is None:
        raise SystemExit(f"empty {src}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    resized.save(dest)
    print("wide", dest.name, resized.size)

def cloth_box(im: Image.Image) -> tuple[int, int, int, int]:
    arr = np.array(im)
    a = arr[:, :, 3] > 16
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    cloth = a & (r > g + 15) & (r > b + 15) & (r > 70)
    ys, xs = np.where(cloth)
    if xs.size < 80:
        bbox = geom.bbox(im)
        if bbox is None:
            return (0, 0, im.size[0], im.size[1])
        return bbox
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)

# the banner text; the same spec is the manifest row's "overlay", which rekey_all_stills applies
BANNER_OVERLAY = {"lines": ["WELCOME TO", "PLACEHOLDIA!"], "box": [0.2, 0.4, 0.8, 0.68], "fill": [236, 214, 164], "centre": "cloth"}

def banner_out() -> None:
    dest = PROPS / "welcome_banner.png"
    keyed = key_sprite(load("14.jpg"))
    out = geom.fit_axis(keyed, width=512, empty="whole")
    out = overlay.apply(out, BANNER_OVERLAY)
    out.save(dest)
    print("banner", dest.name, out.size)

# Recut props/NPCs: (source still, folder, sprite name, canvas px).
RECUTS = (
    (18, PROPS, "anvil", 128), (19, PROPS, "crystal", 128), (20, PROPS, "dumpster", 128), (21, PROPS, "notice_board", 128),
    (22, FX, "dummy", 160), (23, PROPS, "chest", 128), (24, PROPS, "shrine", 128), (25, PROPS, "campfire", 128),
    (26, PROPS, "tree", 160), (27, PROPS, "ore", 128), (28, PROPS, "pot", 128), (29, PROPS, "barrel", 128),
    (30, PROPS, "stairs", 160), (32, PROPS, "plate", 128), (33, PROPS, "lever", 128), (34, PROPS, "hp_orb", 64),
    (35, PROPS, "gate", 160), (38, PROPS, "sign", 160), (40, PROPS, "crack_wall", 160), (41, PROPS, "boss_door", 160),
    (36, NPCS, "receptionist", 160), (37, NPCS, "vendor", 160), (39, NPCS, "shopkeep", 160),
)

def recut_sprites() -> None:
    for n, folder, name, canvas in RECUTS:
        sprite_out(f"{n}.jpg", folder / f"{name}.png", canvas=canvas)

def mix_path() -> None:
    dirt = imgio.load(TILES / "plaza_ground.png", "RGB")
    cobble = imgio.load(TILES / "plaza_path.png", "RGB")
    cobble = cobble.resize(dirt.size, Image.Resampling.BOX)
    mixed = Image.blend(dirt, cobble, 0.28)
    mixed.save(TILES / "plaza_path.png")
    canvas = Image.new("RGB", (256, 256))
    for y in range(2):
        for x in range(2):
            canvas.paste(mixed, (x * 128, y * 128))
    CHECK.mkdir(parents=True, exist_ok=True)
    canvas.save(CHECK / "plaza_path_2x2.png")
    print("path mix", mixed.size)

def _run() -> None:
    tile_out("7.jpg", TILES / "plaza_ground.png")
    tile_out("10.jpg", TILES / "plaza_path.png")
    tile_out("8.jpg", TILES / "plaza_roof.png")
    tile_out("4.jpg", TILES / "foundation_floor.png", quad="tl")
    tile_out("6.jpg", TILES / "foundation_wall.png")

    recut_sprites()
    mix_path()

    wide_out("31.jpg", PROPS / "extract_gate_on.png", 384, quad="tl")
    wide_out("42.jpg", PROPS / "extract_gate_off.png", 384)
    wide_out("17.jpg", BLD / "guild.png", 512)
    wide_out("16.jpg", BLD / "guild_reception.png", 384, key_black=True)
    wide_out("15.jpg", BLD / "stall.png", 512, key_black=True)
    banner_out()

def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("process_world_pass", "Key and install the Placeholdia / dungeon art pass stills.", _run, argv, globals())

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
