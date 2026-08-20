"""Extract, key, and pack walk-cycle frames from Imagine videos."""
from __future__ import annotations

import cv2
from pathlib import Path
from PIL import Image
import collections
import math

ROOT = Path(__file__).resolve().parent.parent
SESSION_VID = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\videos"
)
RAW = ROOT / "_src" / "anim_frames"
OUT_PLAYER = ROOT / "assets" / "sprites" / "player"
BG = (239, 19, 106)
CANVAS = 128
JOBS = {
    "down": SESSION_VID / "1.mp4",
    "left": SESSION_VID / "2.mp4",
    "right": SESSION_VID / "3.mp4",
    "up": SESSION_VID / "5.mp4",
}


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def extract(src: Path, dest_dir: Path, fps: int = 8) -> list[Path]:
    dest_dir.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(src))
    src_fps = cap.get(cv2.CAP_PROP_FPS) or 24
    step = max(1, int(round(src_fps / fps)))
    i = saved = 0
    paths = []
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if i % step == 0:
            p = dest_dir / f"f{saved:03d}.png"
            cv2.imwrite(str(p), frame)
            paths.append(p)
            saved += 1
        i += 1
    cap.release()
    return paths


def flood_key(im: Image.Image, thresh: int = 55) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    corners = [im.getpixel((2, 2)), im.getpixel((w - 3, 2)), im.getpixel((2, h - 3))]
    bg = tuple(sum(c[i] for c in corners) // len(corners) for i in range(3))
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
        if a == 0 or dist((r, g, b), bg) > thresh:
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def fit(im: Image.Image, canvas: int = CANVAS) -> Image.Image:
    keyed = flood_key(im.resize((256, 256), Image.Resampling.NEAREST))
    bbox = keyed.getbbox()
    if not bbox:
        raise SystemExit("empty frame")
    cropped = keyed.crop(bbox)
    pad = 6
    box = Image.new("RGBA", (cropped.size[0] + pad * 2, cropped.size[1] + pad * 2), (0, 0, 0, 0))
    box.paste(cropped, (pad, pad), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(box.size[0] * scale))
    nh = max(1, int(box.size[1] * scale))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2), resized)
    return out


def pick_loop(paths: list[Path], count: int = 4) -> list[Path]:
    # skip first/last 15% (settle / drift), then even samples
    n = len(paths)
    a = max(1, int(n * 0.15))
    b = max(a + count, int(n * 0.85))
    span = paths[a:b]
    if len(span) <= count:
        return span
    step = len(span) / count
    return [span[int(i * step)] for i in range(count)]


def pack_attack() -> None:
    vid = SESSION_VID / "4.mp4"
    if not vid.exists():
        return
    raw = extract(vid, RAW / "player_attack_down")
    chosen = pick_loop(raw, 4)
    out = ROOT / "assets" / "sprites" / "player"
    for i, src in enumerate(chosen):
        dest = out / f"attack_down_{i}.png"
        fit(Image.open(src)).save(dest)
        print("wrote", dest.name)


def main() -> None:
    pack_attack()
    for facing, vid in JOBS.items():
        if not vid.exists():
            print("missing", vid)
            continue
        raw = extract(vid, RAW / f"player_walk_{facing}")
        chosen = pick_loop(raw, 4)
        for i, src in enumerate(chosen):
            dest = OUT_PLAYER / f"walk_{facing}_{i}.png"
            fit(Image.open(src)).save(dest)
            print("wrote", dest.name)


if __name__ == "__main__":
    main()
