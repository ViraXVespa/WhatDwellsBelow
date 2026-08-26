"""Pack on-spec live 3D art into assets/live (billboard-ready, same Placeholdia cast)."""
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter
import math
import shutil

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5CRepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
)
OUT = ROOT / "assets" / "live"
SPR = ROOT / "assets" / "sprites"
TILES = ROOT / "assets" / "tiles"
THRESH = 64
FACINGS = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def sample_bg(im: Image.Image):
    rgb = im.convert("RGB")
    w, h = rgb.size
    pts = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]
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
            if dist((r, g, b), bg) <= THRESH or (g > 140 and g > r + 36 and g > b + 36):
                px[x, y] = (0, 0, 0, 0)
    return im


def fit(im: Image.Image, canvas: int, pad: int = 6) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    cropped = im.crop(bbox)
    box = Image.new("RGBA", (cropped.size[0] + pad * 2, cropped.size[1] + pad * 2), (0, 0, 0, 0))
    box.paste(cropped, (pad, pad), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(box.size[0] * scale))
    nh = max(1, int(box.size[1] * scale))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    # feet toward bottom
    out.paste(resized, ((canvas - nw) // 2, canvas - nh), resized)
    return out


def sprite_jpg(name: str, dest: Path, canvas: int = 128) -> None:
    im = fit(key(Image.open(SRC / name)), canvas)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    print("sprite", dest.relative_to(ROOT))


def copy_png(src: Path, dest: Path, canvas: int | None = None) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert("RGBA")
    if canvas:
        im = fit(im, canvas, pad=2)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    print("copy", dest.relative_to(ROOT))


def seamless_tile(name: str, dest: Path, size: int = 64) -> None:
    im = Image.open(SRC / name).convert("RGB").resize((size, size), Image.Resampling.NEAREST)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    print("tile", dest.relative_to(ROOT))


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    tdir = OUT / "tiles"
    seamless_tile("106.jpg", tdir / "plaza_grass.png")
    seamless_tile("110.jpg", tdir / "plaza_ground.png")
    copy_png(TILES / "plaza_ground_b.png", tdir / "plaza_ground_b.png")
    seamless_tile("108.jpg", tdir / "dungeon_floor.png")
    copy_png(TILES / "dungeon_floor_b.png", tdir / "dungeon_floor_b.png")
    seamless_tile("109.jpg", tdir / "dungeon_wall.png")

    bld = OUT / "buildings"
    sprite_jpg("111.jpg", bld / "guild.png", 256)
    sprite_jpg("119.jpg", bld / "stall.png", 256)
    sprite_jpg("112.jpg", bld / "guild_reception.png", 256)

    npcs = OUT / "npcs"
    sprite_jpg("105.jpg", npcs / "vendor.png")
    sprite_jpg("113.jpg", npcs / "receptionist.png")
    sprite_jpg("124.jpg", npcs / "miner.png")
    for name in ["gopher", "patty", "runner", "lumberjack", "alchemist", "stonemason", "fishmonger", "shopkeep"]:
        src = SPR / "npcs" / f"{name}.png"
        if src.exists():
            copy_png(src, npcs / f"{name}.png", 128)

    props = OUT / "props"
    sprite_jpg("117.jpg", props / "crystal.png")
    sprite_jpg("121.jpg", props / "anvil.png")
    sprite_jpg("120.jpg", props / "tree.png", 192)
    sprite_jpg("125.jpg", props / "fence.png")
    for name in [
        "gate", "bush", "banner", "dumpster", "notice_board", "sign", "stairs",
        "ore", "chest", "campfire", "pot", "barrel", "bolt", "hp_orb",
    ]:
        src = SPR / "props" / f"{name}.png"
        if src.exists():
            copy_png(src, props / f"{name}.png", 128)

    player = OUT / "player"
    sprite_jpg("107.jpg", player / "down.png")
    sprite_jpg("118.jpg", player / "right.png")
    sprite_jpg("114.jpg", player / "left.png")
    sprite_jpg("116.jpg", player / "up.png")
    copy_png(player / "down.png", player / "down_right.png")
    copy_png(player / "down.png", player / "down_left.png")
    copy_png(player / "up.png", player / "up_right.png")
    copy_png(player / "up.png", player / "up_left.png")
    for src in (SPR / "player").glob("walk_*.png"):
        copy_png(src, player / src.name)
    for src in (SPR / "player").glob("attack_*.png"):
        copy_png(src, player / src.name)

    for role, jpg in [("bruiser", "115.jpg"), ("ranged", "122.jpg"), ("tank", "123.jpg")]:
        folder = OUT / "enemies" / role
        sprite_jpg(jpg, folder / "idle_down.png")
        src_dir = SPR / "enemies" / role
        if src_dir.exists():
            for src in src_dir.glob("*.png"):
                dest = folder / src.name
                if not dest.exists():
                    copy_png(src, dest, 128)
        for f in FACINGS:
            idle = folder / f"idle_{f}.png"
            if not idle.exists():
                copy_png(folder / "idle_down.png", idle)
            for pose in ["windup", "strike"]:
                p = folder / f"{pose}_{f}.png"
                if not p.exists():
                    alt = folder / f"{pose}_down.png"
                    copy_png(alt if alt.exists() else folder / "idle_down.png", p)
        for f in ["down", "up", "left", "right"]:
            idle = folder / f"idle_{f}.png"
            for i in range(8):
                dest = folder / f"walk_{f}_{i}.png"
                if not dest.exists() and idle.exists():
                    copy_png(idle, dest)
    print("live pack done")


if __name__ == "__main__":
    main()
