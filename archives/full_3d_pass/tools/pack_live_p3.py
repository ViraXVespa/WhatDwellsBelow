"""Overlay Phase 3 live billboard art onto assets/live."""
from pathlib import Path
from PIL import Image
import math
import shutil

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5CRepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
)
FRAMES = ROOT / "_src" / "anim_frames"
OUT = ROOT / "assets" / "live"
THRESH = 72
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
            if dist((r, g, b), bg) <= THRESH:
                px[x, y] = (0, 0, 0, 0)
            elif g > 140 and g > r + 36 and g > b + 36:
                px[x, y] = (0, 0, 0, 0)
            elif r > 220 and g > 220 and b > 220:
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
    out.paste(resized, ((canvas - nw) // 2, canvas - nh), resized)
    return out


def save_img(im: Image.Image, dest: Path, canvas: int) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    fit(key(im), canvas).save(dest)
    print("wrote", dest.relative_to(ROOT))


def from_jpg(name: str, dest: Path, canvas: int = 128) -> None:
    save_img(Image.open(SRC / name), dest, canvas)


def from_png(path: Path, dest: Path, canvas: int = 128) -> None:
    save_img(Image.open(path), dest, canvas)


def copy_png(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
    print("copy", dest.relative_to(ROOT))


def pack_cycle(folder: str, kind: str, picks: list[int], canvas: int = 128) -> None:
    dest_dir = OUT / "player"
    for i, fi in enumerate(picks):
        src = FRAMES / folder / f"f{fi:03d}.png"
        if not src.exists():
            print("missing", src)
            continue
        facing = folder.split("_")[-1]
        dest = dest_dir / f"{kind}_{facing}_{i}.png"
        from_png(src, dest, canvas)


def main() -> None:
    from_jpg("126.jpg", OUT / "player" / "down_left.png")
    from_jpg("129.jpg", OUT / "player" / "down_right.png")
    from_jpg("128.jpg", OUT / "player" / "up_left.png")
    from_jpg("127.jpg", OUT / "player" / "up_right.png")

    walk_picks = [8, 12, 16, 20]
    atk_picks = [8, 18, 28, 38]
    for facing in ["down", "left", "right", "up"]:
        pack_cycle(f"player_walk_{facing}", "walk", walk_picks)
        pack_cycle(f"player_attack_{facing}", "attack", atk_picks)

    player = OUT / "player"
    for i in range(4):
        copy_png(player / f"walk_down_{i}.png", player / f"walk_down_left_{i}.png")
        copy_png(player / f"walk_down_{i}.png", player / f"walk_down_right_{i}.png")
        copy_png(player / f"walk_up_{i}.png", player / f"walk_up_left_{i}.png")
        copy_png(player / f"walk_up_{i}.png", player / f"walk_up_right_{i}.png")
        copy_png(player / f"attack_down_{i}.png", player / f"attack_down_left_{i}.png")
        copy_png(player / f"attack_down_{i}.png", player / f"attack_down_right_{i}.png")
        copy_png(player / f"attack_up_{i}.png", player / f"attack_up_left_{i}.png")
        copy_png(player / f"attack_up_{i}.png", player / f"attack_up_right_{i}.png")

    npcs = OUT / "npcs"
    from_jpg("130.jpg", npcs / "shopkeep.png")
    from_jpg("132.jpg", npcs / "runner.png")
    from_jpg("133.jpg", npcs / "gopher.png")
    from_jpg("134.jpg", npcs / "stonemason.png")
    from_jpg("135.jpg", npcs / "lumberjack.png")
    from_jpg("136.jpg", npcs / "alchemist.png")
    from_jpg("137.jpg", npcs / "fishmonger.png")
    from_jpg("138.jpg", npcs / "patty.png")

    props = OUT / "props"
    from_jpg("139.jpg", props / "chest.png")
    from_jpg("140.jpg", props / "stairs.png")

    bruiser = OUT / "enemies" / "bruiser"
    ranged = OUT / "enemies" / "ranged"
    tank = OUT / "enemies" / "tank"
    from_jpg("141.jpg", bruiser / "windup_down.png")
    from_jpg("142.jpg", bruiser / "strike_down.png")
    from_jpg("147.jpg", ranged / "windup_down.png")
    from_jpg("146.jpg", ranged / "strike_down.png")
    from_jpg("144.jpg", tank / "windup_down.png")
    from_jpg("148.jpg", tank / "strike_down.png")
    for folder in [bruiser, ranged, tank]:
        for pose in ["windup", "strike"]:
            src = folder / f"{pose}_down.png"
            for f in FACINGS:
                dest = folder / f"{pose}_{f}.png"
                if dest == src:
                    continue
                copy_png(src, dest)
        idle = folder / "idle_down.png"
        for f in FACINGS:
            dest = folder / f"idle_{f}.png"
            if not dest.exists() and idle.exists():
                copy_png(idle, dest)
        for f in ["down", "up", "left", "right"]:
            src = folder / f"idle_{f}.png"
            if not src.exists():
                src = idle
            for i in range(4):
                dest = folder / f"walk_{f}_{i}.png"
                copy_png(src, dest)
            for i in range(4, 8):
                extra = folder / f"walk_{f}_{i}.png"
                if extra.exists():
                    extra.unlink()
                    print("removed", extra.relative_to(ROOT))

    tdir = OUT / "tiles"
    im = Image.open(SRC / "145.jpg").convert("RGB").resize((64, 64), Image.Resampling.NEAREST)
    im.save(tdir / "plaza_ground_b.png")
    print("tile", (tdir / "plaza_ground_b.png").relative_to(ROOT))
    im = Image.open(SRC / "143.jpg").convert("RGB").resize((64, 64), Image.Resampling.NEAREST)
    im.save(tdir / "dungeon_floor_b.png")
    print("tile", (tdir / "dungeon_floor_b.png").relative_to(ROOT))
    print("pack live p3 done")


if __name__ == "__main__":
    main()
