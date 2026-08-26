"""Key Imagine stills into assets/3d for the Gloam 3D view."""
from pathlib import Path
from PIL import Image, ImageOps, ImageFilter
import math
import shutil

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
)
OUT = ROOT / "assets" / "3d"
THRESH = 64
FACINGS = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def sample_bg(im: Image.Image) -> tuple:
    rgb = im.convert("RGB")
    w, h = rgb.size
    pts = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]
    cols = [rgb.getpixel(p) for p in pts]
    return tuple(int(sum(c[i] for c in cols) / len(cols)) for i in range(3))


def is_green(rgb, bg) -> bool:
    r, g, b = rgb
    if dist((r, g, b), bg) <= THRESH:
        return True
    return g > 140 and g > r + 36 and g > b + 36


def key(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    bg = sample_bg(im)
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_green((r, g, b), bg):
                px[x, y] = (0, 0, 0, 0)
    return im


def fit(im: Image.Image, canvas: int, pad: int = 8) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        raise SystemExit("empty after key")
    cropped = im.crop(bbox)
    box = Image.new("RGBA", (cropped.size[0] + pad * 2, cropped.size[1] + pad * 2), (0, 0, 0, 0))
    box.paste(cropped, (pad, pad), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(box.size[0] * scale))
    nh = max(1, int(box.size[1] * scale))
    resized = box.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2), resized)
    return out


def sprite(name: str, dest: Path, canvas: int = 256) -> Image.Image:
    im = fit(key(Image.open(SRC / name)), canvas)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    print("sprite", dest.relative_to(ROOT))
    return im


def copy_img(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dest)
    print("copy", dest.relative_to(ROOT))


def mirror_file(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGBA")
    ImageOps.mirror(im).save(dest)
    print("mirror", dest.relative_to(ROOT))


def tile(name: str, dest: Path, size: int = 128) -> None:
    im = Image.open(SRC / name).convert("RGB")
    im = im.resize((size, size), Image.Resampling.LANCZOS)
    arr = im
    rolled = Image.new("RGB", (size, size))
    rolled.paste(arr.crop((size - 8, 0, size, size)), (0, 0))
    rolled.paste(arr.crop((0, 0, 8, size)), (size - 8, 0))
    blended = Image.blend(arr, rolled, 0.18)
    dest.parent.mkdir(parents=True, exist_ok=True)
    blended.save(dest)
    print("tile", dest.relative_to(ROOT))


def preview_2x2(path: Path, dest: Path) -> None:
    t = Image.open(path).convert("RGB")
    s = t.size[0]
    out = Image.new("RGB", (s * 2, s * 2))
    for y in range(2):
        for x in range(2):
            out.paste(t, (x * s, y * s))
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    print("preview", dest.relative_to(ROOT))


def fill_facings(folder: Path, prefix: str, have: dict, canvas_src: Path | None = None) -> None:
    """have: facing -> existing png path. Fill the rest from nearest cardinal."""
    nearest = {
        "down_right": "down",
        "down_left": "down",
        "up_right": "up",
        "up_left": "up",
        "right": "down",
        "left": "down",
        "up": "down",
        "down": "down",
    }
    for f in FACINGS:
        dest = folder / f"{prefix}_{f}.png"
        if dest.exists():
            continue
        src_key = f if f in have else nearest.get(f, "down")
        src = have.get(src_key) or have.get("down")
        if src and Path(src).exists():
            copy_img(Path(src), dest)


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    tiles = OUT / "tiles"
    tile("43.jpg", tiles / "plaza_grass.png")
    tile("39.jpg", tiles / "plaza_ground.png")
    tile("51.jpg", tiles / "plaza_ground_b.png")
    tile("38.jpg", tiles / "dungeon_floor.png")
    tile("48.jpg", tiles / "dungeon_floor_b.png")
    tile("42.jpg", tiles / "dungeon_wall.png")
    for n in ["plaza_grass", "plaza_ground", "dungeon_floor", "dungeon_wall"]:
        preview_2x2(tiles / f"{n}.png", tiles / f"_preview_{n}.png")

    bld = OUT / "buildings"
    sprite("46.jpg", bld / "guild.png", 384)
    sprite("44.jpg", bld / "guild_reception.png", 384)
    sprite("45.jpg", bld / "stall.png", 384)

    props = OUT / "props"
    for src, name in {
        "68.jpg": "fence.png",
        "71.jpg": "gate.png",
        "69.jpg": "tree.png",
        "75.jpg": "bush.png",
        "79.jpg": "banner.png",
        "64.jpg": "crystal.png",
        "82.jpg": "anvil.png",
        "81.jpg": "dumpster.png",
        "83.jpg": "notice_board.png",
        "76.jpg": "sign.png",
        "77.jpg": "stairs.png",
        "78.jpg": "ore.png",
        "80.jpg": "chest.png",
        "87.jpg": "campfire.png",
        "85.jpg": "pot.png",
        "88.jpg": "barrel.png",
        "84.jpg": "bolt.png",
        "86.jpg": "hp_orb.png",
    }.items():
        sprite(src, props / name, 256 if name not in ("bolt.png", "hp_orb.png") else 128)

    npcs = OUT / "npcs"
    for src, name in {
        "66.jpg": "receptionist.png",
        "60.jpg": "vendor.png",
        "63.jpg": "shopkeep.png",
        "65.jpg": "miner.png",
        "67.jpg": "gopher.png",
        "62.jpg": "patty.png",
        "61.jpg": "runner.png",
        "73.jpg": "lumberjack.png",
        "74.jpg": "alchemist.png",
        "72.jpg": "stonemason.png",
        "70.jpg": "fishmonger.png",
    }.items():
        sprite(src, npcs / name, 256)

    player = OUT / "player"
    idle = {
        "down": sprite("41.jpg", player / "down.png"),
        "down_right": sprite("59.jpg", player / "down_right.png"),
        "right": sprite("47.jpg", player / "right.png"),
        "up_right": sprite("58.jpg", player / "up_right.png"),
        "up": sprite("57.jpg", player / "up.png"),
        "up_left": sprite("53.jpg", player / "up_left.png"),
        "left": sprite("49.jpg", player / "left.png"),
        "down_left": sprite("56.jpg", player / "down_left.png"),
    }
    walk_a = sprite("96.jpg", player / "walk_down_0.png")
    walk_b = sprite("93.jpg", player / "walk_down_1.png")
    idle_down = player / "down.png"
    for i in range(8):
        src = player / "walk_down_0.png" if i % 2 == 0 else player / "walk_down_1.png"
        if i >= 2:
            copy_img(src, player / f"walk_down_{i}.png")
    atk = {
        "down": sprite("91.jpg", player / "attack_down_0.png"),
        "right": sprite("97.jpg", player / "attack_right_0.png"),
        "left": sprite("100.jpg", player / "attack_left_0.png"),
        "up": sprite("102.jpg", player / "attack_up_0.png"),
    }
    for d, srcn in [("down_right", "attack_down_0.png"), ("down_left", "attack_down_0.png"),
                    ("up_right", "attack_up_0.png"), ("up_left", "attack_up_0.png")]:
        copy_img(player / srcn, player / f"attack_{d}_0.png")
    for f in FACINGS:
        base = player / f"attack_{f}_0.png"
        if not base.exists():
            copy_img(player / "attack_down_0.png", base)
        for i in range(1, 8):
            copy_img(base, player / f"attack_{f}_{i}.png")

    def pack_enemy(role: str, idle_map: dict, windup: str | None, strike: str | None) -> None:
        folder = OUT / "enemies" / role
        have = {}
        for facing, src in idle_map.items():
            sprite(src, folder / f"idle_{facing}.png", 256)
            have[facing] = folder / f"idle_{facing}.png"
        if "right" in have and "left" not in have:
            mirror_file(have["right"], folder / "idle_left.png")
            have["left"] = folder / "idle_left.png"
        fill_facings(folder, "idle", {k: str(v) for k, v in have.items()})
        wsrc = windup or idle_map.get("down")
        ssrc = strike or wsrc
        sprite(wsrc, folder / "windup_down.png", 256)
        sprite(ssrc, folder / "strike_down.png", 256)
        for f in FACINGS:
            if f != "down":
                copy_img(folder / "windup_down.png", folder / f"windup_{f}.png")
                copy_img(folder / "strike_down.png", folder / f"strike_{f}.png")
            idle_f = folder / f"idle_{f}.png"
            if idle_f.exists():
                for i in range(8):
                    copy_img(idle_f, folder / f"walk_{f}_{i}.png") if f in ("down", "up", "left", "right") else None
        for f in ["down", "up", "left", "right"]:
            idle_f = folder / f"idle_{f}.png"
            if idle_f.exists():
                for i in range(8):
                    dest = folder / f"walk_{f}_{i}.png"
                    if not dest.exists():
                        copy_img(idle_f, dest)

    pack_enemy(
        "bruiser",
        {"down": "52.jpg", "right": "89.jpg", "up": "90.jpg"},
        "92.jpg",
        "103.jpg",
    )
    pack_enemy(
        "ranged",
        {"down": "54.jpg", "right": "95.jpg", "up": "99.jpg"},
        "104.jpg",
        "104.jpg",
    )
    pack_enemy(
        "tank",
        {"down": "55.jpg", "right": "94.jpg", "up": "98.jpg"},
        "101.jpg",
        "101.jpg",
    )
    print("done")


if __name__ == "__main__":
    main()
