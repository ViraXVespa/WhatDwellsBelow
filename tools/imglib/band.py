"""Shrink that keeps pixel art: box average for alpha and the edge band, exact nearest source pixels inside.

The band follows each boundary: a plain anti-aliased rim (partial halo 1 px deep) gets BASE px. Where the halo is
deeper (a glow), the band walks inward along the distance gradient while each step keeps moving the colour the same
way by at least STEP (the glow's ramp) and stops at the first reversal or plateau (the glow's most solid point).
Bands are median-smoothed along the boundary (7 px window) and carried inward from the nearest boundary pixel.
Opaque output pixels further in than their band take the nearest-neighbour source pixel, so interiors stay exact.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

BASE, STEP, MAXW = 2, 6.0, 24

def band_info(A: np.ndarray, rgb: np.ndarray):
    """(interior mask, band width per opaque px) for output alpha A (uint8 HxW) and colour rgb (HxWx3)."""
    import cv2
    op = (A == 255).astype(np.uint8)
    H, W = A.shape
    halo = cv2.distanceTransform((A > 0).astype(np.uint8), cv2.DIST_L2, 5)
    halo_near = cv2.dilate(np.where(op == 0, halo, 0).astype(np.float32), np.ones((3, 3), np.uint8))
    d = cv2.distanceTransform(op, cv2.DIST_L2, 5)
    bnd = (op == 1) & (d <= 1.01)
    if not bnd.any():
        return np.zeros_like(bnd), np.zeros(A.shape, np.float32)
    dist = d.astype(np.float32)
    gy, gx = cv2.Sobel(dist, cv2.CV_32F, 0, 1, ksize=3), cv2.Sobel(dist, cv2.CV_32F, 1, 0, ksize=3)
    c = rgb.astype(np.float32)
    bandmap = np.zeros((H, W), np.float32)
    for y, x in zip(*np.nonzero(bnd)):
        n = np.array([gy[y, x], gx[y, x]])
        nn = float(np.linalg.norm(n))
        if halo_near[y, x] <= 1.5 or nn < 1e-3:
            bandmap[y, x] = BASE
            continue
        n /= nn
        prev, first, k = c[y, x], None, 0
        for s in range(1, MAXW):
            yy, xx = int(round(y + n[0] * s)), int(round(x + n[1] * s))
            if not (0 <= yy < H and 0 <= xx < W) or op[yy, xx] == 0:
                break
            dc = c[yy, xx] - prev
            if float(np.linalg.norm(dc)) < STEP or (first is not None and float(dc @ first) <= 0):
                break
            first = dc if first is None else first
            k, prev = s, c[yy, xx]
        bandmap[y, x] = max(BASE, k + 1)
    med = bandmap.copy()
    for y, x in zip(*np.nonzero(bnd)):
        w = bandmap[max(0, y - 3):y + 4, max(0, x - 3):x + 4]
        med[y, x] = np.median(w[w > 0])
    _, lab = cv2.distanceTransformWithLabels((~bnd).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    ys, xs = np.nonzero(bnd)
    lut = np.zeros(lab.max() + 1, np.float32)
    lut[lab[ys, xs]] = med[ys, xs]
    band = np.where(op == 1, lut[lab], 0).astype(np.float32)
    return (op == 1) & (d > band), band

def shrink_keep_interior(im: Image.Image, size: tuple[int, int], box_down) -> Image.Image:
    """box_down(im, size) for alpha and the band; the interior is the nearest source pixel (only when shrinking)."""
    box = np.array(box_down(im, size))
    nn = np.array(im.convert("RGBA").resize(size, Image.Resampling.NEAREST))
    interior, _ = band_info(box[..., 3], box[..., :3])
    interior &= nn[..., 3] == 255
    box[interior, :3] = nn[interior, :3]
    return Image.fromarray(box, "RGBA")
