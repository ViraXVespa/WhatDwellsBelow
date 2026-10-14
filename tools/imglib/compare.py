"""Compare two images: pixel delta, changed regions, heatmap, score, labeled montage."""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw

from . import HAVE_CV2, cv2


def delta_map(a: Image.Image, b: Image.Image) -> np.ndarray:
    """Per-pixel max channel difference of two same-size images (RGBA). H x W int32."""
    xa = np.asarray(a.convert("RGBA")).astype(np.int32)
    xb = np.asarray(b.convert("RGBA")).astype(np.int32)
    return np.abs(xa - xb).max(axis=2)


def boxes(mask: np.ndarray, merge: int = 8, limit: int = 12, min_area: int = 1):
    """Bounding boxes (l, t, r, b) of the true regions of a bool mask, nearby regions merged (`merge` px),
    biggest first, at most `limit`."""
    if not mask.any():
        return []
    from .key import components, dilate
    grown = dilate(mask, merge) if merge > 0 else mask
    n, lab, areas, _t = components(grown)
    out = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero((lab == i) & mask)
        if len(xs) >= min_area:
            out.append((len(xs), (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)))
    out.sort(key=lambda t: -t[0])
    return [b for _n, b in out[:limit]]


def diff(a: Image.Image, b: Image.Image, tol: int = 0, ignore: list | None = None, merge: int = 8, limit: int = 12) -> dict:
    """Pixel diff. ignore: [(left, top, right, bottom)] rectangles in pixels of `a` that never count. Keys: status (same /
    changed / size), changed_px, ratio, max_delta, mean_delta, score (1.0 identical), bbox, regions."""
    if a.size != b.size:
        return {"status": "size", "before": list(a.size), "after": list(b.size), "changed_px": 0, "ratio": 1.0, "score": 0.0}
    delta = delta_map(a, b)
    for l, t, r, b in ignore or []:
        delta[int(t):int(b) + 1, int(l):int(r) + 1] = 0
    mask = delta > tol
    n = int(mask.sum())
    res = {"status": "changed" if n else "same", "changed_px": n, "ratio": round(n / mask.size, 6),
           "max_delta": int(delta.max()), "mean_delta": round(float(delta.mean()), 4),
           "score": round(1.0 - float(delta.mean()) / 255.0, 6), "bbox": None, "regions": []}
    if n:
        ys, xs = np.nonzero(mask)
        res["bbox"] = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        res["regions"] = [list(r) for r in boxes(mask, merge, limit)]
    return res


def heatmap(a: Image.Image, b: Image.Image, tol: int = 0, ignore: list | None = None, boxes_on: bool = False) -> Image.Image:
    """Dimmed `a` with changed pixels red (brighter red = bigger delta); optional yellow region boxes."""
    xa = np.asarray(a.convert("RGB"))
    delta = delta_map(a, b)
    for l, t, r, b in ignore or []:
        delta[int(t):int(b) + 1, int(l):int(r) + 1] = 0
    mask = delta > tol
    vis = (xa * 0.35).astype(np.uint8)
    vis[mask] = (255, 40, 40)
    out = Image.fromarray(vis, "RGB")
    if boxes_on:
        d = ImageDraw.Draw(out)
        for r in boxes(mask):
            d.rectangle((r[0] - 1, r[1] - 1, r[2], r[3]), outline=(255, 220, 0))
    return out


def montage(images: list, labels: list | None = None, cols: int | None = None, gap: int = 8, bg=(32, 32, 32), cell: tuple | None = None) -> Image.Image:
    """Grid of images with a caption above each (side-by-side / before-after). Cells share one size (the
    biggest image, or `cell`); smaller images sit top-left on a checker so transparency shows."""
    n = len(images)
    cols = cols or n
    rows = -(-n // cols)
    cw = cell[0] if cell else max(i.width for i in images)
    ch = cell[1] if cell else max(i.height for i in images)
    cap = 14 if labels else 0
    sheet = Image.new("RGB", (cols * cw + (cols + 1) * gap, rows * (ch + cap) + (rows + 1) * gap), bg)
    d = ImageDraw.Draw(sheet)
    for i, im in enumerate(images):
        x, y = gap + (i % cols) * (cw + gap), gap + (i // cols) * (ch + cap + gap)
        if labels:
            d.text((x, y), str(labels[i])[:max(1, cw // 6)], fill=(230, 230, 230))
        rgba = im.convert("RGBA")
        if rgba.size != (cw, ch):
            rgba.thumbnail((cw, ch), Image.Resampling.NEAREST)
        sheet.paste(checker(rgba.size), (x, y + cap))
        sheet.paste(rgba, (x, y + cap), rgba)
    return sheet


def checker(size: tuple[int, int], sq: int = 8) -> Image.Image:
    """Grey checkerboard RGB image (transparency backdrop)."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    v = np.where(((xx // sq) + (yy // sq)) % 2 == 0, 90, 130).astype(np.uint8)
    return Image.fromarray(np.dstack([v, v, v]), "RGB")

def grid_shape(n: int, cell_w: int, cell_h: int) -> tuple[int, int]:
    """Columns, rows. Two frames: side by side if taller than wide, else stacked.
    More than two: wide cells get fewer columns, tall cells get more."""
    import math

    if n <= 1:
        return 1, 1
    if n == 2:
        return (2, 1) if cell_h >= cell_w else (1, 2)
    aspect = cell_w / max(1, cell_h)
    cols = max(1, min(n, round(math.sqrt(n / aspect))))
    return cols, -(-n // cols)


def compose_group(images: list, labels: list | None = None, max_side: int = 1920):
    """One sheet for one area. Scales so the long side stays within max_side."""
    if not images:
        raise ValueError("compose_group needs at least one image")
    cols, _rows = grid_shape(len(images), max(im.width for im in images), max(im.height for im in images))
    sheet = montage([im.copy() for im in images], labels, cols=cols)
    long_side = max(sheet.size)
    if long_side > max_side:
        scale = max_side / long_side
        sheet = sheet.resize((max(1, round(sheet.width * scale)), max(1, round(sheet.height * scale))), Image.Resampling.NEAREST)
    return sheet
