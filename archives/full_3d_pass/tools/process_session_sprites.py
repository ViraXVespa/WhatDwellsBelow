"""Key whatever-magenta Imagine stills and fit them into engine sprites."""
from pathlib import Path
from PIL import Image
import collections

ROOT = Path(__file__).resolve().parent.parent
SESSION = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
)
PLAYER = 128
PROP = 96
ORB = 48

JOBS = [
    ("6.jpg", ROOT / "assets/sprites/player/down_right.png", PLAYER, 58),
    ("7.jpg", ROOT / "assets/sprites/player/down_left.png", PLAYER, 58),
    ("8.jpg", ROOT / "assets/sprites/player/up_right.png", PLAYER, 52),
    ("9.jpg", ROOT / "assets/sprites/player/up_left.png", PLAYER, 52),
    ("2.jpg", ROOT / "assets/sprites/props/barrel.png", PROP, 48),
    ("3.jpg", ROOT / "assets/sprites/props/pot.png", PROP, 48),
    ("4.jpg", ROOT / "assets/sprites/props/hp_orb.png", ORB, 36),
    ("1.jpg", ROOT / "assets/sprites/props/mana_orb.png", ORB, 36),
]


def close(a, b, thresh):
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5 <= thresh


def sample_bg(im: Image.Image):
    w, h = im.size
    pts = [
        im.getpixel((2, 2)),
        im.getpixel((w // 2, 2)),
        im.getpixel((w - 3, 2)),
        im.getpixel((2, h - 3)),
        im.getpixel((w - 3, h - 3)),
    ]
    r = sum(p[0] for p in pts) // len(pts)
    g = sum(p[1] for p in pts) // len(pts)
    b = sum(p[2] for p in pts) // len(pts)
    return (r, g, b)


def flood_key(im: Image.Image, thresh: int) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    bg = sample_bg(im)
    q = collections.deque()
    seen = set()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if (x, y) in seen or x < 0 or y < 0 or x >= w or y >= h:
            continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if a == 0 or not close((r, g, b), bg, thresh):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def key_and_fit(src: Path, dest: Path, canvas: int, thresh: int) -> None:
    raw = Image.open(src).convert("RGBA")
    # Key at 256px so flood-fill is cheap; output is 48-128 anyway.
    raw = raw.resize((256, 256), Image.Resampling.NEAREST)
    keyed = flood_key(raw, thresh)
    bbox = keyed.getbbox()
    if not bbox:
        raise SystemExit(f"empty after key: {src}")
    cropped = keyed.crop(bbox)
    pad = 6
    cw, ch = cropped.size
    box = Image.new("RGBA", (cw + pad * 2, ch + pad * 2), (0, 0, 0, 0))
    box.paste(cropped, (pad, pad), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(box.size[0] * scale))
    nh = max(1, int(box.size[1] * scale))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2), resized)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    print(f"wrote {dest.name} bbox={bbox} -> {nw}x{nh} bg_sample_ok")


def main():
    for name, dest, canvas, thresh in JOBS:
        src = SESSION / name
        if not src.exists():
            raise SystemExit(f"missing {src}")
        key_and_fit(src, dest, canvas, thresh)


if __name__ == "__main__":
    main()
