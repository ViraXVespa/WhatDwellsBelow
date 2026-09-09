"""Key and install the Placeholdia / dungeon art pass stills."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from sprite_pipeline import fit_canvas  # noqa: E402

SESSION = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a08788-1bb6-76c0-8fa8-40b73dda2810\images"
)
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
    return Image.open(SESSION / name).convert("RGBA")


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
    arr = np.array(im)
    rgb = arr[:, :, :3].astype(np.float32)
    corners = np.stack(
        [rgb[2, 2], rgb[2, -3], rgb[-3, 2], rgb[-3, -3]],
        axis=0,
    )
    bg = corners.mean(axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    mag = np.array([255.0, 0.0, 255.0], dtype=np.float32)
    dmag = np.sqrt(((rgb - mag) ** 2).sum(axis=2))
    keyed = (dist <= 62.0) | (dmag <= 72.0)
    arr[:, :, 3] = np.where(keyed, 0, arr[:, :, 3])
    return Image.fromarray(arr, "RGBA")


def sprite_out(src: str, dest: Path, canvas: int = 128, quad: str | None = None) -> None:
    im = load(src)
    if quad:
        im = crop_frac(im, QUADS[quad])
    keyed = key_sprite(im)
    out = fit_canvas(keyed, canvas, key=False, spill_flood=False)
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
    bbox = keyed.getbbox()
    if bbox is None:
        raise SystemExit(f"empty {src}")
    cropped = keyed.crop(bbox)
    scale = max_w / cropped.size[0]
    nw = max_w
    nh = max(1, int(cropped.size[1] * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.NEAREST)
    dest.parent.mkdir(parents=True, exist_ok=True)
    resized.save(dest)
    print("wide", dest.name, resized.size)


_FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11100", "10010", "10001", "10001", "10001", "10010", "11100"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "W": ["10001", "10001", "10101", "10101", "10101", "01010", "01010"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


def blit_line(
    im: Image.Image,
    text: str,
    x0: int,
    y0: int,
    scale: int,
    fill: tuple[int, int, int, int],
) -> None:
    px = im.load()
    shadow = (48, 28, 16, 255)
    gw, gap = 5, 2
    for i, ch in enumerate(text):
        rows = _FONT.get(ch, _FONT[" "])
        bx = x0 + i * (gw + gap) * scale
        for gy, row in enumerate(rows):
            for gx, bit in enumerate(row):
                if bit != "1":
                    continue
                for oy in range(scale):
                    for ox in range(scale):
                        x = bx + gx * scale + ox
                        y = y0 + gy * scale + oy
                        if 0 <= x + 1 < im.size[0] and 0 <= y + 1 < im.size[1]:
                            px[x + 1, y + 1] = shadow
                        if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
                            px[x, y] = fill


def cloth_box(im: Image.Image) -> tuple[int, int, int, int]:
    arr = np.array(im)
    a = arr[:, :, 3] > 16
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)
    cloth = a & (r > g + 15) & (r > b + 15) & (r > 70)
    ys, xs = np.where(cloth)
    if xs.size < 80:
        bbox = im.getbbox()
        if bbox is None:
            return (0, 0, im.size[0], im.size[1])
        return bbox
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def banner_out() -> None:
    dest = PROPS / "welcome_banner.png"
    keyed = key_sprite(load("14.jpg"))
    bbox = keyed.getbbox()
    cropped = keyed.crop(bbox)
    scale = 512 / cropped.size[0]
    nw = 512
    nh = max(1, int(cropped.size[1] * scale))
    out = cropped.resize((nw, nh), Image.Resampling.NEAREST)
    w, h = out.size
    cx0 = int(w * 0.20)
    cy0 = int(h * 0.40)
    cx1 = int(w * 0.80)
    cy1 = int(h * 0.68)
    pad_x = max(8, int((cx1 - cx0) * 0.08))
    pad_y = max(6, int((cy1 - cy0) * 0.12))
    inner_w = max(8, cx1 - cx0 - pad_x * 2)
    inner_h = max(8, cy1 - cy0 - pad_y * 2)
    lines = ["WELCOME TO", "PLACEHOLDIA!"]
    gw, gh, gap, lh = 5, 7, 1, 2
    longest = max(len(line) for line in lines)
    line_w = longest * (gw + gap) - gap
    block_h = len(lines) * gh + (len(lines) - 1) * lh
    px = max(2, min(inner_w // line_w, inner_h // block_h))
    total_w = line_w * px
    total_h = block_h * px
    bx = cx0 + pad_x + (inner_w - total_w) // 2
    by = cy0 + pad_y + (inner_h - total_h) // 2
    fill = (236, 214, 164, 255)
    for i, line in enumerate(lines):
        lw = (len(line) * (gw + gap) - gap) * px
        lx = bx + (total_w - lw) // 2
        ly = by + i * (gh + lh) * px
        blit_line(out, line, lx, ly, px, fill)
    out.save(dest)
    print("banner", dest.name, out.size, "cloth", (cx0, cy0, cx1, cy1), "px", px)


def recut_sprites() -> None:
    sprite_out("18.jpg", PROPS / "anvil.png")
    sprite_out("19.jpg", PROPS / "crystal.png")
    sprite_out("20.jpg", PROPS / "dumpster.png")
    sprite_out("21.jpg", PROPS / "notice_board.png")
    sprite_out("22.jpg", FX / "dummy.png", canvas=160)
    sprite_out("23.jpg", PROPS / "chest.png")
    sprite_out("24.jpg", PROPS / "shrine.png")
    sprite_out("25.jpg", PROPS / "campfire.png")
    sprite_out("26.jpg", PROPS / "tree.png", canvas=160)
    sprite_out("27.jpg", PROPS / "ore.png")
    sprite_out("28.jpg", PROPS / "pot.png")
    sprite_out("29.jpg", PROPS / "barrel.png")
    sprite_out("30.jpg", PROPS / "stairs.png", canvas=160)
    sprite_out("32.jpg", PROPS / "plate.png")
    sprite_out("33.jpg", PROPS / "lever.png")
    sprite_out("34.jpg", PROPS / "hp_orb.png", canvas=64)
    sprite_out("35.jpg", PROPS / "gate.png", canvas=160)
    sprite_out("38.jpg", PROPS / "sign.png", canvas=160)
    sprite_out("40.jpg", PROPS / "crack_wall.png", canvas=160)
    sprite_out("41.jpg", PROPS / "boss_door.png", canvas=160)
    sprite_out("36.jpg", NPCS / "receptionist.png", canvas=160)
    sprite_out("37.jpg", NPCS / "vendor.png", canvas=160)
    sprite_out("39.jpg", NPCS / "shopkeep.png", canvas=160)


def mix_path() -> None:
    dirt = Image.open(TILES / "plaza_ground.png").convert("RGB")
    cobble = Image.open(TILES / "plaza_path.png").convert("RGB")
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


def main() -> None:
    tile_out("3.jpg", TILES / "plaza_grass.png")
    tile_out("7.jpg", TILES / "plaza_ground.png")
    tile_out("11.jpg", TILES / "plaza_ground_b.png")
    tile_out("10.jpg", TILES / "plaza_path.png")
    tile_out("9.jpg", TILES / "plaza_wall.png", quad="tr")
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


if __name__ == "__main__":
    main()
