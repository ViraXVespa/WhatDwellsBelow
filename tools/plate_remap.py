#!/usr/bin/env python3
"""Remap a generated chroma plate to exact #FF00FF, including edge bleed.

Keeps the plate opaque. Does not punch alpha. Feed the result to I2V or to
sprite_pipeline key/matte after you accept the still.

Armpit / crotch / between-arm islands use the same enclosed-pocket fill as
tools/sprite_pipeline.py (_fill_pockets).

  python tools/plate_remap.py SRC DEST
  python tools/plate_remap.py SRC DEST --wand 48 --edge 5 --mask DEST.mask.png
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from math import sqrt
from pathlib import Path

from PIL import Image

KEY = (255, 0, 255)
KEY_HEX = "#FF00FF"
TIGHT_DIST = 18.0
POCKET_FRAC = 0.07


def _dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return sqrt(
        (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2
    )


def _hex(rgb: tuple[int, int, int]) -> str:
    return f"#{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"


def _clamp(v: float) -> int:
    return 0 if v < 0 else 255 if v > 255 else int(round(v))


def _neighbors8(x: int, y: int, w: int, h: int):
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                yield nx, ny


def _fg_alpha(p: tuple[int, int, int], key: tuple[int, int, int]) -> float:
    """0 = pixel is the key, 1 = pixel contains no key. GIMP Color-to-Alpha."""

    def chan(pv: float, kv: float) -> float:
        pv /= 255.0
        kv /= 255.0
        if pv > kv:
            return (pv - kv) / (1.0 - kv) if kv < 0.999 else 0.0
        if pv < kv:
            return (kv - pv) / kv if kv > 0.001 else 0.0
        return 0.0

    return max(
        chan(p[0], key[0]),
        chan(p[1], key[1]),
        chan(p[2], key[2]),
    )


def plate_amount(p: tuple[int, int, int], chroma: tuple[int, int, int]) -> float:
    a = 1.0 - _fg_alpha(p, chroma)
    if a < 0.0:
        return 0.0
    if a > 1.0:
        return 1.0
    return a


def sample_start_chroma(im: Image.Image) -> tuple[int, int, int]:
    """Border-sampled plate color. Ignores low-sat / dark pixels."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    samples: list[tuple[int, int, int]] = []
    step_x = max(1, w // 32)
    step_y = max(1, h // 32)
    coords: list[tuple[int, int]] = []
    for x in range(0, w, step_x):
        coords.append((x, 0))
        coords.append((x, h - 1))
    for y in range(0, h, step_y):
        coords.append((0, y))
        coords.append((w - 1, y))
    for x, y in coords:
        r, g, b, a = px[x, y]
        if a < 16:
            continue
        mx = max(r, g, b)
        mn = min(r, g, b)
        if mx < 40:
            continue
        sat = 0.0 if mx == 0 else (mx - mn) / mx
        if sat < 0.35:
            continue
        samples.append((r, g, b))
    if not samples:
        for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
            r, g, b, _a = px[x, y]
            samples.append((r, g, b))
    samples.sort(key=lambda c: (c[0], c[1], c[2]))
    mid = samples[len(samples) // 2]
    ranked = sorted(samples, key=lambda c: _dist(c, mid))
    take = ranked[: max(1, len(ranked) // 2)]
    n = len(take)
    return (
        int(round(sum(c[0] for c in take) / n)),
        int(round(sum(c[1] for c in take) / n)),
        int(round(sum(c[2] for c in take) / n)),
    )


def chroma_distances(im: Image.Image, chroma: tuple[int, int, int]) -> list[float]:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    out = [0.0] * (w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                out[row + x] = 0.0
            else:
                out[row + x] = _dist((r, g, b), chroma)
    return out


def wand_plate(
    im: Image.Image,
    chroma: tuple[int, int, int],
    wand_dist: float,
    min_amount: float,
) -> list[int]:
    """8-connected wand from the border. 1 = plate, 0 = figure."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    n = w * h
    seen = [False] * n
    mask = [0] * n
    q: deque[int] = deque()

    def accept(i: int) -> bool:
        x = i % w
        y = i // w
        r, g, b, a = px[x, y]
        if a < 8:
            return True
        rgb = (r, g, b)
        if _dist(rgb, chroma) <= wand_dist:
            return True
        return plate_amount(rgb, chroma) >= min_amount

    for x in range(w):
        for y in (0, h - 1):
            q.append(y * w + x)
    for y in range(h):
        for x in (0, w - 1):
            q.append(y * w + x)

    while q:
        i = q.popleft()
        if seen[i]:
            continue
        seen[i] = True
        if not accept(i):
            continue
        mask[i] = 1
        x = i % w
        y = i // w
        for nx, ny in _neighbors8(x, y, w, h):
            q.append(ny * w + nx)
    return mask


def fill_pockets(
    mask: list[int],
    distances: list[float],
    w: int,
    h: int,
    pocket_dist: float,
    pocket_frac: float,
) -> int:
    """Grab enclosed chroma islands the border wand cannot reach.

    Same rule as tools/sprite_pipeline.py _fill_pockets: flood leftover
    near-chroma components; keep them if they are small or very tight to
    the sampled plate colour (armpits, crotch, between arm and torso).
    """
    n = w * h
    cap = max(64, int(n * pocket_frac))
    seen = [0] * n
    added = 0
    for i in range(n):
        if mask[i] or seen[i] or distances[i] > pocket_dist:
            continue
        comp: list[int] = []
        q: deque[int] = deque([i])
        seen[i] = 1
        total = 0.0
        while q:
            j = q.popleft()
            comp.append(j)
            total += distances[j]
            x = j % w
            y = j // w
            for nx, ny in _neighbors8(x, y, w, h):
                nj = ny * w + nx
                if seen[nj] or mask[nj]:
                    continue
                if distances[nj] <= pocket_dist:
                    seen[nj] = 1
                    q.append(nj)
        mean = total / max(1, len(comp))
        if len(comp) <= cap or mean <= TIGHT_DIST:
            for j in comp:
                if not mask[j]:
                    mask[j] = 1
                    added += 1
    return added


def edge_band(mask: list[int], w: int, h: int, radius: int) -> list[int]:
    """Pixels within radius of the plate that are not themselves plate."""
    band = [0] * (w * h)
    if radius <= 0:
        return band
    plate = [i for i, v in enumerate(mask) if v]
    r2 = radius * radius
    for i in plate:
        x = i % w
        y = i // w
        x0 = 0 if x < radius else x - radius
        x1 = w if x + radius + 1 > w else x + radius + 1
        y0 = 0 if y < radius else y - radius
        y1 = h if y + radius + 1 > h else y + radius + 1
        for yy in range(y0, y1):
            dy = yy - y
            row = yy * w
            for xx in range(x0, x1):
                dx = xx - x
                j = row + xx
                if mask[j]:
                    continue
                if dx * dx + dy * dy <= r2:
                    band[j] = 1
    return band


def remap_pixel(
    rgb: tuple[int, int, int],
    chroma: tuple[int, int, int],
    amount: float,
) -> tuple[int, int, int]:
    """Move start-chroma influence onto #FF00FF. amount 1 = full plate."""
    if amount <= 0.001:
        return rgb
    if amount >= 0.999:
        return KEY
    dr = KEY[0] - chroma[0]
    dg = KEY[1] - chroma[1]
    db = KEY[2] - chroma[2]
    return (
        _clamp(rgb[0] + amount * dr),
        _clamp(rgb[1] + amount * dg),
        _clamp(rgb[2] + amount * db),
    )


def remap(
    im: Image.Image,
    wand_dist: float = 48.0,
    min_amount: float = 0.72,
    edge: int = 4,
    edge_min: float = 0.04,
    pocket_frac: float = POCKET_FRAC,
) -> tuple[Image.Image, Image.Image, dict]:
    src = im.convert("RGBA")
    w, h = src.size
    px = src.load()
    chroma = sample_start_chroma(src)
    mask = wand_plate(src, chroma, wand_dist, min_amount)
    distances = chroma_distances(src, chroma)
    for i, d in enumerate(distances):
        if not mask[i] and d <= TIGHT_DIST:
            mask[i] = 1
    pockets = fill_pockets(mask, distances, w, h, wand_dist, pocket_frac)
    band = edge_band(mask, w, h, edge)

    out = src.copy()
    opx = out.load()
    vis = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    vpx = vis.load()

    plate_n = 0
    band_n = 0
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b, a = px[x, y]
            i = row + x
            rgb = (r, g, b)
            if mask[i]:
                amt = plate_amount(rgb, chroma)
                if amt < 0.35:
                    amt = 1.0
                opx[x, y] = (*remap_pixel(rgb, chroma, max(amt, 0.85)), a)
                vpx[x, y] = (255, 0, 255, 255)
                plate_n += 1
                continue
            if band[i]:
                amt = plate_amount(rgb, chroma)
                if amt >= edge_min:
                    opx[x, y] = (*remap_pixel(rgb, chroma, amt), a)
                    t = _clamp(40 + amt * 215)
                    vpx[x, y] = (255, t, 0, 255)
                    band_n += 1
                else:
                    vpx[x, y] = (0, 0, 0, 255)
                continue
            vpx[x, y] = (0, 0, 0, 255)

    info = {
        "start_chroma": _hex(chroma),
        "start_rgb": list(chroma),
        "target": KEY_HEX,
        "size": [w, h],
        "plate_pixels": plate_n,
        "bleed_pixels": band_n,
        "pocket_pixels": pockets,
        "wand_dist": wand_dist,
        "min_amount": min_amount,
        "edge": edge,
        "edge_min": edge_min,
        "pocket_frac": pocket_frac,
        "tight_dist": TIGHT_DIST,
    }
    return out, vis, info


def main() -> None:
    p = argparse.ArgumentParser(
        description="Hue-correct a sampled chroma plate to #FF00FF, including bleed and enclosed pockets."
    )
    p.add_argument("src", type=Path)
    p.add_argument("dest", type=Path)
    p.add_argument("--wand", type=float, default=48.0, help="Max RGB distance to start chroma for the plate wand and pockets")
    p.add_argument("--min-amount", type=float, default=0.72, help="Min plate mix to treat a pixel as background")
    p.add_argument("--edge", type=int, default=4, help="Inward radius (px) to hunt bleed")
    p.add_argument("--edge-min", type=float, default=0.04, help="Min start-chroma mix on an edge pixel before remap")
    p.add_argument("--pocket-frac", type=float, default=POCKET_FRAC, help="Max island size as a fraction of the image (sprite_pipeline default 0.07)")
    p.add_argument("--mask", type=Path, default=None, help="Write a debug mask (magenta=plate, orange=bleed)")
    args = p.parse_args()
    if not args.src.is_file():
        print(f"missing {args.src}", file=sys.stderr)
        sys.exit(1)
    im = Image.open(args.src)
    out, vis, info = remap(
        im,
        wand_dist=args.wand,
        min_amount=args.min_amount,
        edge=args.edge,
        edge_min=args.edge_min,
        pocket_frac=args.pocket_frac,
    )
    args.dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.dest)
    if args.mask:
        args.mask.parent.mkdir(parents=True, exist_ok=True)
        vis.save(args.mask)
    print(json.dumps(info, indent=2))


if __name__ == "__main__":
    main()