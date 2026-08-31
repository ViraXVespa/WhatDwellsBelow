"""Section 19 cleanup: outside chroma wand, lattice crop, 128 canvas, foot baseline."""
from __future__ import annotations

import json
import math
from collections import deque
from pathlib import Path

from PIL import Image

MAGENTA = (255, 0, 255, 255)
KEY_RGB = (255, 0, 255)
CANVAS = 128
PAD = 8

# Alpha-tuning knobs. Wand grows from the frame edge only.
# Raise WAND_MIN / shrink HUE_WIDTH if a scarf or lip still gets eaten.
# Raise EDGE_DIST / FRINGE_GROW if magenta crumbs remain on the silhouette.
KEY_HUE = 300.0
HUE_WIDTH = 32.0
SAT_MIN = 0.28
VAL_MIN = 0.22
WAND_DIST = 78.0
TIGHT_DIST = 28.0
EDGE_DIST = 118.0
DESPILL = 0.80
WAND_MIN = 0.50
TIGHT_MIN = 0.82
FRINGE_GROW = 2


def _dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def _hsv(r: int, g: int, b: int) -> tuple[float, float, float]:
    rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
    mx = max(rf, gf, bf)
    mn = min(rf, gf, bf)
    d = mx - mn
    if d == 0.0:
        h = 0.0
    elif mx == rf:
        h = (60.0 * ((gf - bf) / d) + 360.0) % 360.0
    elif mx == gf:
        h = (60.0 * ((bf - rf) / d) + 120.0) % 360.0
    else:
        h = (60.0 * ((rf - gf) / d) + 240.0) % 360.0
    s = 0.0 if mx == 0.0 else d / mx
    return h, s, mx


def _hue_dist(a: float, b: float) -> float:
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def _smoothstep(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def _neighbors8(x: int, y: int, w: int, h: int):
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                yield nx, ny


def sample_chroma(im: Image.Image) -> tuple[int, int, int]:
    """Border-sampled key colour. Prefers samples near #FF00FF."""
    px = im.load()
    w, h = im.size
    pts: list[tuple[int, int, int]] = []
    step_x = max(1, w // 16)
    step_y = max(1, h // 16)
    for x in range(0, w, step_x):
        pts.append(px[x, 0][:3])
        pts.append(px[x, h - 1][:3])
    for y in range(0, h, step_y):
        pts.append(px[0, y][:3])
        pts.append(px[w - 1, y][:3])
    if not pts:
        return KEY_RGB
    scored = sorted((_dist(p, KEY_RGB), p) for p in pts)
    take = scored[: max(4, len(scored) // 3)]
    n = len(take)
    return tuple(int(sum(s[1][i] for s in take) / n) for i in range(3))


def key_amount(r: int, g: int, b: int, bg: tuple[int, int, int]) -> float:
    """1 = chroma key, 0 = foreground. Hue-gated so on-model pinks stay put."""
    if g >= r - 8 and g >= b - 8 and g > 70:
        return 0.0
    d = min(_dist((r, g, b), KEY_RGB), _dist((r, g, b), bg))
    h, s, v = _hsv(r, g, b)
    hd = _hue_dist(h, KEY_HUE)
    bh, bs, _bv = _hsv(*bg)
    if bs > 0.2:
        hd = min(hd, _hue_dist(h, bh))
    # Skin / leather: red-brown with real green, not a magenta void.
    if r > 90 and g > 28 and b < 110 and r > b + 25 and g < r + 10 and g > int(r * 0.22):
        if d > TIGHT_DIST:
            return 0.0
    if s < SAT_MIN or v < VAL_MIN:
        if d >= TIGHT_DIST * 1.6:
            return 0.0
    hue_score = max(0.0, 1.0 - hd / HUE_WIDTH)
    dist_score = max(0.0, 1.0 - d / EDGE_DIST)
    sat_term = max(0.0, (s - SAT_MIN) / max(1e-6, 1.0 - SAT_MIN))
    score = max(dist_score, hue_score * (0.45 + 0.55 * sat_term) * min(1.0, v / 0.55))
    if d >= EDGE_DIST and hue_score < 0.25:
        return 0.0
    return min(1.0, score)


def is_key(r: int, g: int, b: int, bg: tuple[int, int, int] | None = None) -> bool:
    return key_amount(r, g, b, bg or KEY_RGB) >= WAND_MIN


def _amounts(im: Image.Image, bg: tuple[int, int, int]) -> list[float]:
    px = im.load()
    w, h = im.size
    out = [0.0] * (w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b, a = px[x, y]
            out[row + x] = 1.0 if a == 0 else key_amount(r, g, b, bg)
    return out


def wand_mask(im: Image.Image, amounts: list[float]) -> bytearray:
    """8-connected magic wand from the border, plus leftover pure-key pockets."""
    w, h = im.size
    mask = bytearray(w * h)
    seen = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        i = y * w + x
        if seen[i]:
            return
        seen[i] = 1
        if amounts[i] >= WAND_MIN:
            q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)
    while q:
        x, y = q.popleft()
        i = y * w + x
        mask[i] = 1
        for nx, ny in _neighbors8(x, y, w, h):
            ni = ny * w + nx
            if seen[ni]:
                continue
            seen[ni] = 1
            if amounts[ni] >= WAND_MIN:
                q.append((nx, ny))
    for i, amt in enumerate(amounts):
        if not mask[i] and amt >= TIGHT_MIN:
            mask[i] = 1
    return mask


def _grow_mask(mask: bytearray, w: int, h: int, steps: int) -> bytearray:
    cur = bytearray(mask)
    for _ in range(max(0, steps)):
        nxt = bytearray(cur)
        for y in range(h):
            row = y * w
            for x in range(w):
                if cur[row + x]:
                    continue
                for nx, ny in _neighbors8(x, y, w, h):
                    if cur[ny * w + nx]:
                        nxt[row + x] = 1
                        break
        cur = nxt
    return cur


def despill_rgb(r: int, g: int, b: int, amt: float) -> tuple[int, int, int]:
    spill = max(0.0, min(1.0, amt)) * DESPILL
    if spill <= 0.0:
        return r, g, b
    avg = (r + b) * 0.5
    nr = int(round(r - (r - g) * spill * 0.55))
    nb = int(round(b - (b - g) * spill * 0.55))
    ng = int(round(g + (avg - g) * spill * 0.22))
    return max(0, min(255, nr)), max(0, min(255, ng)), max(0, min(255, nb))


def key_to_alpha(im: Image.Image) -> Image.Image:
    """Outside wand. Convert chroma to alpha; phase near-key fringe instead of clipping it."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    bg = sample_chroma(im)
    amounts = _amounts(im, bg)
    mask = wand_mask(im, amounts)
    fringe = _grow_mask(mask, w, h, FRINGE_GROW)
    for y in range(h):
        row = y * w
        for x in range(w):
            i = row + x
            if not fringe[i]:
                continue
            r, g, b, a = px[x, y]
            amt = amounts[i]
            t = _smoothstep((amt - 0.18) / 0.74)
            na = int(round(a * (1.0 - t)))
            if mask[i] and amt >= TIGHT_MIN:
                na = 0
            nr, ng, nb = despill_rgb(r, g, b, amt if na < 250 else amt * 0.35)
            if na <= 2:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (nr, ng, nb, max(0, min(255, na)))
    return im


def range_key(im: Image.Image) -> Image.Image:
    """Bible / seed path: wand the outside, flatten that region to exact #FF00FF, despill the lip."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    bg = sample_chroma(im)
    amounts = _amounts(im, bg)
    mask = wand_mask(im, amounts)
    fringe = _grow_mask(mask, w, h, FRINGE_GROW)
    for y in range(h):
        row = y * w
        for x in range(w):
            i = row + x
            if not fringe[i]:
                continue
            r, g, b, a = px[x, y]
            if a == 0:
                px[x, y] = MAGENTA
                continue
            amt = amounts[i]
            if mask[i] and amt >= WAND_MIN:
                px[x, y] = MAGENTA
                continue
            nr, ng, nb = despill_rgb(r, g, b, amt)
            px[x, y] = (nr, ng, nb, a)
    return im


def flatten_magenta_to_alpha(im: Image.Image) -> Image.Image:
    return key_to_alpha(im)


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
            a = ap[x, y]
            if a < 16:
                px[x, y] = (0, 0, 0, 0)
            else:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, a)
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
        bg = Image.new("RGBA", (cell, cell), MAGENTA)
        bg.paste(im, (0, 0), im)
        col, row = i % 3, i // 3
        sheet.paste(bg, (col * cell, row * cell))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)


def write_palette(im: Image.Image, dest: Path) -> None:
    rgba = im.convert("RGBA")
    colors: dict[tuple[int, int, int], int] = {}
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
    elif cmd in ("key", "alpha"):
        src, dest = Path(sys.argv[2]), Path(sys.argv[3])
        key_to_alpha(Image.open(src)).save(dest)
        print(f"wrote {dest}")
    elif cmd == "flatten":
        src, dest = Path(sys.argv[2]), Path(sys.argv[3])
        range_key(Image.open(src)).save(dest)
        print(f"wrote {dest}")
    else:
        print("usage: sprite_pipeline.py seeds SRC DEST_DIR")
        print("       sprite_pipeline.py key SRC.png DEST.png")
        print("       sprite_pipeline.py flatten SRC.png DEST.png")