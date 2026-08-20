"""Pack corrected left-facing player sheets with magenta key + despill."""
from pathlib import Path
from PIL import Image
import math

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5CRepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
)
FRAMES = ROOT / "_src" / "anim_frames"
OUT = ROOT / "assets" / "live" / "player"
MAGENTA = (239, 19, 106)
LAWN = (124, 252, 0)
WALK_PICKS = [8, 12, 16, 20]
ATK_PICKS = [8, 18, 28, 38]


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def key(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if dist((r, g, b), MAGENTA) <= 90:
                px[x, y] = (0, 0, 0, 0)
                continue
            if r > 160 and g < 90 and b > 50 and r > g + 40:
                px[x, y] = (0, 0, 0, 0)
                continue
            if dist((r, g, b), LAWN) <= 72:
                px[x, y] = (0, 0, 0, 0)
                continue
            if g > 150 and g > r + 40 and g > b + 40:
                px[x, y] = (0, 0, 0, 0)
                continue
            # despill: leftover green fringe on otherwise-character pixels
            if g > r + 24 and g > b + 12 and g > 90:
                ng = int((r + b) * 0.5)
                px[x, y] = (r, ng, b, a)
    return im


def fit(im: Image.Image, canvas: int = 128, pad: int = 6) -> Image.Image:
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
        save_img(Image.open(src), OUT / f"{prefix}_{i}.png")


def main() -> None:
    save_img(Image.open(SRC / "190.jpg"), OUT / "left.png")
    save_img(Image.open(SRC / "188.jpg"), OUT / "up_left.png")
    save_img(Image.open(SRC / "189.jpg"), OUT / "down_left.png")
    pack_cycle("player_walk_left", "walk_left", WALK_PICKS)
    pack_cycle("player_walk_up_left", "walk_up_left", WALK_PICKS)
    pack_cycle("player_walk_down_left", "walk_down_left", WALK_PICKS)
    pack_cycle("player_attack_left", "attack_left", ATK_PICKS)
    pack_cycle("player_attack_up_left", "attack_up_left", ATK_PICKS)
    pack_cycle("player_attack_down_left", "attack_down_left", ATK_PICKS)
    print("facing fix packed")


if __name__ == "__main__":
    main()
