"""Section 19 cleanup: magenta range-key, lattice crop, 128 canvas, foot baseline."""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

MAGENTA = (255, 0, 255, 255)
CANVAS = 128
PAD = 8

# Saturated magenta / hot-pink / violet, not on-model greens or skin.
def is_key(r: int, g: int, b: int) -> bool:
    # Green scarf: G is the strongest channel.
    if g >= r - 8 and g >= b - 8 and g > 70:
        return False
    # Skin / leather: red-brown with real green in it, not a magenta void.
    if r > 90 and g > 28 and b < 110 and r > b + 25 and g < r + 10 and g > int(r * 0.22):
        return False
    if r > 100 and b > 50 and g < 40:
        return True
    if r > 120 and b > 90 and g < min(r, b) * 0.88:
        return True
    if r > 180 and b > 70 and g < 170 and (r - g) >= 30:
        return True
    return False


def range_key(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if is_key(r, g, b):
                px[x, y] = MAGENTA
    return im


def flatten_magenta_to_alpha(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_key(r, g, b):
                px[x, y] = (0, 0, 0, 0)
    return im


def split_equal_3x3(im: Image.Image) -> list[Image.Image]:
    w, h = im.size
    cw, ch = w // 3, h // 3
    cells = []
    for row in range(3):
        for col in range(3):
            box = (col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)
            cells.append(im.crop(box))
    return cells


CELL_NAMES = [
    "up_left", "up", "up_right",
    "left", "face", "right",
    "down_left", "down", "down_right",
]


def fit_canvas(im: Image.Image, canvas: int = CANVAS, baseline: int | None = None) -> Image.Image:
    im = flatten_magenta_to_alpha(im)
    bbox = im.getbbox()
    if bbox is None:
        return Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    cropped = im.crop(bbox)
    cw, ch = cropped.size
    box = Image.new("RGBA", (cw + PAD * 2, ch + PAD * 2), (0, 0, 0, 0))
    box.paste(cropped, (PAD, PAD), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(round(box.size[0] * scale)))
    nh = max(1, int(round(box.size[1] * scale)))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    ox = (canvas - nw) // 2
    if baseline is None:
        oy = canvas - nh - 2
    else:
        oy = baseline - nh
    oy = max(0, min(canvas - nh, oy))
    out.paste(resized, (ox, oy), resized)
    return out


def foot_baseline(im: Image.Image) -> int:
    px = im.load()
    w, h = im.size
    for y in range(h - 1, -1, -1):
        for x in range(w):
            if px[x, y][3] > 8:
                return y + 1
    return h


def lock_baselines(frames: list[Image.Image]) -> list[Image.Image]:
    bases = [foot_baseline(f) for f in frames]
    target = max(bases) if bases else CANVAS - 2
    locked = []
    for f, b in zip(frames, bases):
        dy = target - b
        if dy == 0:
            locked.append(f)
            continue
        out = Image.new("RGBA", f.size, (0, 0, 0, 0))
        out.paste(f, (0, dy), f)
        locked.append(out)
    return locked


def quantize_palette(im: Image.Image, colors: int = 24) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    pal = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    pal = pal.convert("RGB")
    out = pal.convert("RGBA")
    out.putalpha(alpha)
    px = out.load()
    ap = alpha.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            if ap[x, y] < 16:
                px[x, y] = (0, 0, 0, 0)
            elif ap[x, y] < 250:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 255)
    return out


def extract_seeds(src: Path, dest_dir: Path) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    im = range_key(Image.open(src))
    cells = split_equal_3x3(im)
    out = {}
    for name, cell in zip(CELL_NAMES, cells):
        p = dest_dir / f"seed_{name}.png"
        cell.save(p)
        out[name] = str(p)
    return out


def composite_bible(cell_paths: dict[str, Path], dest: Path, cell: int = 256) -> None:
    sheet = Image.new("RGBA", (cell * 3, cell * 3), MAGENTA)
    order = CELL_NAMES
    for i, name in enumerate(order):
        p = cell_paths[name]
        im = Image.open(p).convert("RGBA")
        im = fit_canvas(im, cell)
        # restore magenta behind alpha
        bg = Image.new("RGBA", (cell, cell), MAGENTA)
        bg.paste(im, (0, 0), im)
        col, row = i % 3, i // 3
        sheet.paste(bg, (col * cell, row * cell))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)


def write_palette(im: Image.Image, dest: Path) -> None:
    rgba = im.convert("RGBA")
    colors = {}
    px = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16 or is_key(r, g, b):
                continue
            colors[(r, g, b)] = colors.get((r, g, b), 0) + 1
    ranked = sorted(colors.items(), key=lambda kv: -kv[1])[:32]
    dest.write_text(json.dumps({"colors": [list(c) for c, _n in ranked]}, indent=2))


if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "seeds":
        print(json.dumps(extract_seeds(Path(sys.argv[2]), Path(sys.argv[3])), indent=2))
