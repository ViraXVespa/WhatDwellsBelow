#!/usr/bin/env python3
"""Shared pixel helpers for the pack_*/process_*/plate_remap tools.

Import-only. Helpers here were byte-identical copies, or parametric forms proven
equal on synthetic images before and after (fit_box covers the fit variants,
flood_border / fill_pockets / chroma_alpha the wand and colour-to-alpha loops).
key, key_and_fit, sample_bg, extract stay in their tools until a before/after
pixel diff proves one shared form. Change a helper here only with that proof.
"""
from __future__ import annotations

import math

KEYED_CAP = 512


def dist(a, b) -> float:
    """Euclidean distance between two equal-length colour tuples."""
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def neighbors8(x: int, y: int, w: int, h: int):
    """Yield the in-bounds 8-neighbours of (x, y)."""
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                yield nx, ny


def shrink_keyed(im, cap: int = KEYED_CAP):
    """Nearest-neighbour shrink so the longest side is at most cap."""
    from PIL import Image

    w, h = im.size
    m = max(w, h)
    if m <= cap:
        return im
    s = cap / m
    return im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.Resampling.NEAREST)


def chroma_alpha(p, k):
    """Colour-to-alpha amount: p is float RGB (0-1, H x W x 3), k the key (0-1, len 3). Returns H x W float."""
    import numpy as np

    alpha = np.zeros(p.shape[:2], dtype=np.float32)
    for i in range(3):
        pv = p[..., i]
        kv = float(k[i])
        ch = np.zeros_like(pv)
        if kv < 0.999:
            hi = pv > kv
            ch[hi] = (pv[hi] - kv) / (1.0 - kv)
        if kv > 0.001:
            lo = pv < kv
            ch[lo] = (kv - pv[lo]) / kv
        alpha = np.maximum(alpha, ch)
    return alpha


def flood_border(accept):
    """8-connected flood from the border through `accept` (H x W bool). Returns a uint8 H x W mask."""
    from collections import deque

    import numpy as np

    h, w = accept.shape
    mask = np.zeros((h, w), dtype=np.uint8)
    seen = np.zeros((h, w), dtype=np.uint8)
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if seen[y, x]:
            return
        seen[y, x] = 1
        if accept[y, x]:
            q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while q:
        x, y = q.popleft()
        mask[y, x] = 1
        x0 = 0 if x == 0 else x - 1
        x1 = w if x + 2 > w else x + 2
        y0 = 0 if y == 0 else y - 1
        y1 = h if y + 2 > h else y + 2
        for ny in range(y0, y1):
            for nx in range(x0, x1):
                if seen[ny, nx]:
                    continue
                seen[ny, nx] = 1
                if accept[ny, nx]:
                    q.append((nx, ny))
    return mask


def fill_pockets(mask, distances, w: int, h: int, pocket_dist: float, pocket_frac: float, tight_dist: float) -> int:
    """Grab enclosed chroma islands the border wand cannot reach (sets them to 1 in place).

    Components of cells within pocket_dist are kept when small (pocket_frac of the image, at least 64 px) or
    when their mean distance is within tight_dist. Returns how many cells were added.
    """
    from collections import deque

    n = w * h
    cap = max(64, int(n * pocket_frac))
    seen = bytearray(n)
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
            for nx, ny in neighbors8(j % w, j // w, w, h):
                nj = ny * w + nx
                if seen[nj] or mask[nj]:
                    continue
                if distances[nj] <= pocket_dist:
                    seen[nj] = 1
                    q.append(nj)
        mean = total / max(1, len(comp))
        if len(comp) <= cap or mean <= tight_dist:
            for j in comp:
                if not mask[j]:
                    mask[j] = 1
                    added += 1
    return added


def fit_box(im, canvas: int, pad: int, *, resample=None, to_int=round, oy=None, empty_exit: str = ""):
    """Crop to the opaque box, pad it, scale to fit `canvas` square, paste centred (oy(nh) sets the y offset).

    resample defaults to NEAREST; to_int turns the scaled size into pixels (round or int); empty_exit
    raises SystemExit(msg) on an empty image instead of returning a blank canvas.
    """
    from PIL import Image

    bbox = im.getbbox()
    if not bbox:
        if empty_exit:
            raise SystemExit(empty_exit)
        return Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    cropped = im.crop(bbox)
    box = Image.new("RGBA", (cropped.size[0] + pad * 2, cropped.size[1] + pad * 2), (0, 0, 0, 0))
    box.paste(cropped, (pad, pad), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, to_int(box.size[0] * scale))
    nh = max(1, to_int(box.size[1] * scale))
    resized = box.resize((nw, nh), resample if resample is not None else Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2 if oy is None else oy(nh)), resized)
    return out
