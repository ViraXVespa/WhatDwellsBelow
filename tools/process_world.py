from pathlib import Path
from PIL import Image
import math
import shutil

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CGrokSandbox%5Cwhat-dwells-below\01a01725-c75b-79f2-967f-30d19272bef6\images"
)
THRESH = 58
CANVAS = 128


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def sample_bg(im: Image.Image) -> tuple:
    rgb = im.convert("RGB")
    w, h = rgb.size
    pts = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3), (w // 2, 2), (2, h // 2)]
    cols = [rgb.getpixel(p) for p in pts]
    return tuple(int(sum(c[i] for c in cols) / len(cols)) for i in range(3))


def key(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    bg = sample_bg(im)
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if dist((r, g, b), bg) <= THRESH:
                px[x, y] = (0, 0, 0, 0)
    return im


def fit(im: Image.Image, canvas: int, pad: int = 6) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        raise SystemExit("empty after key")
    cropped = im.crop(bbox)
    box = Image.new("RGBA", (cropped.size[0] + pad * 2, cropped.size[1] + pad * 2), (0, 0, 0, 0))
    box.paste(cropped, (pad, pad), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(box.size[0] * scale))
    nh = max(1, int(box.size[1] * scale))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2), resized)
    return out


def sprite(src_name: str, dest: Path, canvas: int = CANVAS) -> None:
    im = key(Image.open(SRC / src_name))
    dest.parent.mkdir(parents=True, exist_ok=True)
    fit(im, canvas).save(dest)
    print("sprite", dest)


def crop_tile(src_name: str, dest: Path, box_frac, size: int = 64) -> None:
    im = Image.open(SRC / src_name).convert("RGB")
    w, h = im.size
    x0, y0, x1, y1 = box_frac
    crop = im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1)))
    tile = crop.resize((size, size), Image.Resampling.BOX)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tile.save(dest)
    print("tile", dest)


def wall_tile(src_name: str, dest: Path, size: int = 64) -> None:
    im = Image.open(SRC / src_name).convert("RGBA")
    px = im.load()
    w, h = im.size
    fill = (48, 54, 68, 255)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 225 and g > 225 and b > 225:
                px[x, y] = fill
    bbox = im.getbbox()
    cropped = im.crop(bbox)
    tile = cropped.resize((size, size), Image.Resampling.BOX)
    dest.parent.mkdir(parents=True, exist_ok=True)
    tile.convert("RGB").save(dest)
    print("wall", dest)


def building(src_name: str, dest: Path, max_w: int) -> None:
    im = key(Image.open(SRC / src_name))
    bbox = im.getbbox()
    cropped = im.crop(bbox)
    scale = max_w / cropped.size[0]
    nw = max_w
    nh = max(1, int(cropped.size[1] * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.NEAREST)
    dest.parent.mkdir(parents=True, exist_ok=True)
    resized.save(dest)
    print("building", dest, resized.size)


def main() -> None:
    tiles = ROOT / "assets" / "tiles"
    props = ROOT / "assets" / "sprites" / "props"
    npcs = ROOT / "assets" / "sprites" / "npcs"
    bld = ROOT / "assets" / "sprites" / "buildings"

    crop_tile("46.jpg", tiles / "dungeon_floor.png", (0.28, 0.28, 0.72, 0.72))
    crop_tile("46.jpg", tiles / "dungeon_floor_b.png", (0.08, 0.42, 0.52, 0.86))
    crop_tile("37.jpg", tiles / "plaza_ground.png", (0.22, 0.22, 0.78, 0.78))
    crop_tile("37.jpg", tiles / "plaza_ground_b.png", (0.05, 0.40, 0.55, 0.90))
    wall_tile("42.jpg", tiles / "dungeon_wall.png")

    wall = Image.open(tiles / "dungeon_wall.png").convert("RGB")
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
        canvas.resize((256, 256), Image.Resampling.NEAREST).save(check / f"{name}_2x2.png")


if __name__ == "__main__":
    main()
