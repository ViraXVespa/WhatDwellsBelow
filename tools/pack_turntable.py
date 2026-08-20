"""Pack 8-dir player sheets from turntable + facing clips, shared scale and torso pin."""
from pathlib import Path
from PIL import Image
import math

ROOT = Path(__file__).resolve().parent.parent
FRAMES = ROOT / "_src" / "anim_frames"
IMG = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5CRepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
)
OUT = ROOT / "assets" / "live" / "player"
CANVAS = 128
CHAR_H = 110
MAGENTA = (239, 19, 106)
LAWN = (124, 252, 0)
PICKS = [8, 12, 16, 20]
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
            if dist((r, g, b), MAGENTA) <= 92:
                px[x, y] = (0, 0, 0, 0)
            elif r > 160 and g < 95 and b > 45 and r > g + 30:
                px[x, y] = (0, 0, 0, 0)
            elif dist((r, g, b), LAWN) <= 72:
                px[x, y] = (0, 0, 0, 0)
            elif g > 150 and g > r + 40 and g > b + 40:
                px[x, y] = (0, 0, 0, 0)
            elif g > r + 28 and g > b + 16 and g > 100:
                px[x, y] = (r, int((r + b) * 0.5), b, a)
    return im


def torso_x(im: Image.Image) -> int:
    px = im.load()
    w, h = im.size
    xs = []
    y0 = int(h * 0.72)
    for y in range(y0, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 30:
                continue
            cyan = b > r + 15 and b > g + 10 and b > 80
            if cyan:
                continue
            xs.append(x)
    if not xs:
        return w // 2
    xs.sort()
    return xs[len(xs) // 2]


def place(im: Image.Image) -> Image.Image:
    im = key(im)
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ch = im.crop(bbox)
    scale = CHAR_H / max(1, ch.size[1])
    nw = max(1, int(ch.size[0] * scale))
    nh = CHAR_H
    ch = ch.resize((nw, nh), Image.Resampling.NEAREST)
    tx = torso_x(ch)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x0 = CANVAS // 2 - tx
    y0 = CANVAS - nh
    out.paste(ch, (x0, y0), ch)
    return out


def save(im: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    place(im).save(dest)
    print("wrote", dest.relative_to(ROOT))


def frame(folder: str, i: int) -> Path:
    return FRAMES / folder / f"f{i:03d}.png"


def pack_list(folder: str, idxs: list, dest_prefix: str) -> None:
    n = 0
    for i in idxs:
        p = frame(folder, i)
        if not p.exists():
            print("missing", p)
            continue
        save(Image.open(p), OUT / f"{dest_prefix}_{n}.png")
        n += 1


def main() -> None:
    # Idles from stills + turntable
    save(Image.open(ROOT / "assets" / "live" / "player" / "down.png"), OUT / "down.png")
    save(Image.open(IMG / "191.jpg"), OUT / "right.png")
    save(Image.open(IMG / "192.jpg"), OUT / "down_right.png")
    save(Image.open(IMG / "193.jpg"), OUT / "up_right.png")
    save(Image.open(IMG / "194.jpg"), OUT / "down_left.png")
    save(Image.open(frame("turn_walk", 30)), OUT / "left.png")
    save(Image.open(frame("turn_walk", 45)), OUT / "up.png")
    save(Image.open(frame("turn_walk", 60)), OUT / "up_left.png")

    pack_list("turn_walk", [0, 8, 12, 16], "walk_down")
    pack_list("turn_walk", [28, 30, 32, 36], "walk_left")
    pack_list("turn_walk", [44, 46, 48, 52], "walk_up")
    pack_list("turn_walk", [56, 60, 64, 68], "walk_up_left")
    pack_list("walk_right_new", PICKS, "walk_right")
    pack_list("walk_down_right_new", PICKS, "walk_down_right")
    pack_list("walk_up_right_new", PICKS, "walk_up_right")
    pack_list("walk_down_left_new", PICKS, "walk_down_left")

    pack_list("turn_atk", [0, 8, 12, 18], "attack_down")
    pack_list("turn_atk", [70, 74, 78, 82], "attack_left")
    pack_list("turn_atk", [50, 54, 58, 62], "attack_up")
    pack_list("turn_atk", [26, 30, 34, 38], "attack_up_left")
    pack_list("atk_right_new", ATK_PICKS, "attack_right")
    pack_list("atk_down_right_new", ATK_PICKS, "attack_down_right")
    pack_list("atk_up_right_new", ATK_PICKS, "attack_up_right")
    pack_list("atk_down_left_new", ATK_PICKS, "attack_down_left")
    print("turntable pack done")


if __name__ == "__main__":
    main()
