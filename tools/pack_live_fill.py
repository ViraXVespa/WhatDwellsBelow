"""Fill remaining live billboard art: unique diagonals, 4-dir enemies, leftover props."""
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
WALK_PICKS = [8, 12, 16, 20]
ATK_PICKS = [8, 18, 28, 38]


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


def pack_cycle(folder: str, dest_dir: Path, prefix: str, picks: list[int], canvas: int = 128) -> None:
    for i, fi in enumerate(picks):
        src = FRAMES / folder / f"f{fi:03d}.png"
        if not src.exists():
            print("missing", src)
            continue
        from_png(src, dest_dir / f"{prefix}_{i}.png", canvas)


def fill_enemy_diags(folder: Path, pose: str) -> None:
    mapping = {
        "down_right": "down",
        "down_left": "down",
        "up_right": "up",
        "up_left": "up",
    }
    for diag, src_f in mapping.items():
        src = folder / f"{pose}_{src_f}.png"
        dest = folder / f"{pose}_{diag}.png"
        if src.exists():
            copy_png(src, dest)


def main() -> None:
    player = OUT / "player"
    pack_cycle("player_walk_down_right", player, "walk_down_right", WALK_PICKS)
    pack_cycle("player_walk_down_left", player, "walk_down_left", WALK_PICKS)
    pack_cycle("player_walk_up_right", player, "walk_up_right", WALK_PICKS)
    pack_cycle("player_walk_up_left", player, "walk_up_left", WALK_PICKS)
    pack_cycle("player_attack_down_right", player, "attack_down_right", ATK_PICKS)
    pack_cycle("player_attack_down_left", player, "attack_down_left", ATK_PICKS)
    pack_cycle("player_attack_up_right", player, "attack_up_right", ATK_PICKS)
    pack_cycle("player_attack_up_left", player, "attack_up_left", ATK_PICKS)

    props = OUT / "props"
    from_jpg("149.jpg", props / "gate.png")
    from_jpg("150.jpg", props / "dumpster.png")
    from_jpg("151.jpg", props / "ore.png")
    from_jpg("152.jpg", props / "campfire.png")
    from_jpg("157.jpg", props / "sign.png")
    from_jpg("160.jpg", props / "notice_board.png")
    from_jpg("156.jpg", props / "pot.png")
    from_jpg("162.jpg", props / "barrel.png")
    from_jpg("164.jpg", props / "bush.png")
    from_jpg("167.jpg", props / "banner.png")
    from_jpg("166.jpg", props / "bolt.png")
    from_jpg("163.jpg", props / "hp_orb.png")

    bruiser = OUT / "enemies" / "bruiser"
    ranged = OUT / "enemies" / "ranged"
    tank = OUT / "enemies" / "tank"

    from_jpg("153.jpg", bruiser / "idle_left.png")
    from_jpg("155.jpg", bruiser / "idle_right.png")
    from_jpg("154.jpg", bruiser / "idle_up.png")
    from_jpg("174.jpg", bruiser / "windup_left.png")
    from_jpg("170.jpg", bruiser / "windup_right.png")
    from_jpg("175.jpg", bruiser / "windup_up.png")
    from_jpg("173.jpg", bruiser / "strike_left.png")
    from_jpg("172.jpg", bruiser / "strike_right.png")
    from_jpg("171.jpg", bruiser / "strike_up.png")

    from_jpg("161.jpg", ranged / "idle_left.png")
    from_jpg("159.jpg", ranged / "idle_right.png")
    from_jpg("158.jpg", ranged / "idle_up.png")
    from_jpg("177.jpg", ranged / "windup_left.png")
    from_jpg("176.jpg", ranged / "windup_right.png")
    from_jpg("180.jpg", ranged / "windup_up.png")
    from_jpg("181.jpg", ranged / "strike_left.png")
    from_jpg("178.jpg", ranged / "strike_right.png")
    from_jpg("179.jpg", ranged / "strike_up.png")

    from_jpg("165.jpg", tank / "idle_left.png")
    from_jpg("168.jpg", tank / "idle_right.png")
    from_jpg("169.jpg", tank / "idle_up.png")
    from_jpg("187.jpg", tank / "windup_left.png")
    from_jpg("184.jpg", tank / "windup_right.png")
    from_jpg("185.jpg", tank / "windup_up.png")
    from_jpg("183.jpg", tank / "strike_left.png")
    from_jpg("182.jpg", tank / "strike_right.png")
    from_jpg("186.jpg", tank / "strike_up.png")

    pack_cycle("bruiser_walk_down", bruiser, "walk_down", WALK_PICKS)
    pack_cycle("bruiser_walk_left", bruiser, "walk_left", WALK_PICKS)
    pack_cycle("bruiser_walk_right", bruiser, "walk_right", WALK_PICKS)
    pack_cycle("bruiser_walk_up", bruiser, "walk_up", WALK_PICKS)
    pack_cycle("ranged_walk_down", ranged, "walk_down", WALK_PICKS)
    pack_cycle("ranged_walk_left", ranged, "walk_left", WALK_PICKS)
    pack_cycle("ranged_walk_right", ranged, "walk_right", WALK_PICKS)
    pack_cycle("ranged_walk_up", ranged, "walk_up", WALK_PICKS)
    pack_cycle("tank_walk_down", tank, "walk_down", WALK_PICKS)
    pack_cycle("tank_walk_left", tank, "walk_left", WALK_PICKS)
    pack_cycle("tank_walk_right", tank, "walk_right", WALK_PICKS)
    pack_cycle("tank_walk_up", tank, "walk_up", WALK_PICKS)

    for folder in [bruiser, ranged, tank]:
        for pose in ["idle", "windup", "strike"]:
            fill_enemy_diags(folder, pose)

    print("pack live fill done")


if __name__ == "__main__":
    main()
