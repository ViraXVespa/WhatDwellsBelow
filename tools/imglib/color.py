"""Colour helpers: distance, background references, palette, WCAG contrast."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

from . import HAVE_CV2, cv2


def dist(a, b) -> float:
    """Euclidean distance between two equal-length colour tuples."""
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def rgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    """uint8 H x W x 3 (or N x 3) RGB -> float32 Lab (L 0-100). cv2 when present, else the D65 formula."""
    p = rgb.astype(np.float32) / 255.0
    if HAVE_CV2 and p.ndim == 3:
        return cv2.cvtColor(p, cv2.COLOR_RGB2LAB)
    lin = np.where(p > 0.04045, ((p + 0.055) / 1.055) ** 2.4, p / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]], dtype=np.float32)
    xyz = (lin @ m.T) / np.array([0.95047, 1.0, 1.08883], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0, 500.0 * (f[..., 0] - f[..., 1]), 200.0 * (f[..., 1] - f[..., 2])], axis=-1).astype(np.float32)


def hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """uint8 H x W x 3 -> (hue degrees 0-360, sat 0-1, val 0-1)."""
    p = rgb.astype(np.float32) / 255.0
    mx, mn = p.max(axis=-1), p.min(axis=-1)
    d = mx - mn
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    h = np.zeros_like(mx)
    nz = d > 0
    with np.errstate(divide="ignore", invalid="ignore"):
        h = np.where(nz & (mx == r), (60.0 * ((g - b) / d) + 360.0) % 360.0, h)
        h = np.where(nz & (mx == g), 60.0 * ((b - r) / d) + 120.0, h)
        h = np.where(nz & (mx == b) & (mx != r) & (mx != g), 60.0 * ((r - g) / d) + 240.0, h)
    s = np.where(mx > 0, d / np.where(mx > 0, mx, 1), 0.0)
    return h % 360.0, s.astype(np.float32), mx


def hue_gap(h: np.ndarray, ref: float) -> np.ndarray:
    d = np.abs(h - ref) % 360.0
    return np.minimum(d, 360.0 - d)


def delta_e(rgb: np.ndarray, refs) -> np.ndarray:
    """Lab distance of every pixel to the nearest of `refs` (list of RGB tuples). H x W float32."""
    lab = rgb_to_lab(rgb)
    out = None
    for ref in refs:
        rl = rgb_to_lab(np.array(ref, dtype=np.uint8).reshape(1, 1, 3))[0, 0]
        d = np.sqrt(((lab - rl) ** 2).sum(axis=-1))
        out = d if out is None else np.minimum(out, d)
    return out


def border_samples(rgb: np.ndarray, ring: int = 4) -> np.ndarray:
    """N x 3 uint8 pixels from a ring of `ring` px around the image edge."""
    h, w = rgb.shape[:2]
    ring = max(1, min(ring, h // 2, w // 2))
    return np.concatenate([rgb[:ring].reshape(-1, 3), rgb[-ring:].reshape(-1, 3), rgb[ring:-ring, :ring].reshape(-1, 3), rgb[ring:-ring, -ring:].reshape(-1, 3)])


def background_refs(rgb: np.ndarray, k: int = 3, hue: float | None = None, hue_tol: float = 40.0, sat_min: float = 0.35, val_min: float = 0.35, min_share: float = 0.05):
    """Background colours sampled from the image border: up to k RGB tuples, biggest cluster first.

    With `hue` (degrees, e.g. 300 for magenta) only border pixels in that hue band count, so a figure touching
    the edge does not pollute the references. A plate that drifts in shade gets one reference per shade.
    """
    s = border_samples(rgb)
    if hue is not None:
        h, sat, v = hsv(s.reshape(-1, 1, 3))
        ok = (hue_gap(h, hue) <= hue_tol) & (sat >= sat_min) & (v >= val_min)
        picked = s[ok.reshape(-1)]
        if len(picked) >= 8:
            s = picked
    if len(s) == 0:
        return [(255, 0, 255)]
    lab = rgb_to_lab(s.reshape(-1, 1, 3)).reshape(-1, 3) if HAVE_CV2 else rgb_to_lab(s)
    kk = max(1, min(k, len(s) // 8))
    if kk == 1 or not HAVE_CV2:
        return [tuple(int(v) for v in np.median(s, axis=0))]
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 20, 0.5)
    cv2.setRNGSeed(7)
    _c, labels, _ = cv2.kmeans(lab.astype(np.float32), kk, None, crit, 3, cv2.KMEANS_PP_CENTERS)
    labels = labels.reshape(-1)
    refs = []
    for i in np.argsort(-np.bincount(labels, minlength=kk)):
        sel = s[labels == i]
        if len(sel) >= max(2, min_share * len(s)):
            refs.append(tuple(int(v) for v in np.median(sel, axis=0)))
    return refs or [tuple(int(v) for v in np.median(s, axis=0))]


def palette(im: Image.Image, n: int = 6, alpha_min: int = 16):
    """Dominant colours as [(rgb, percent of opaque pixels)]. Quantised to 4 bits per channel, then merged."""
    a = np.asarray(im.convert("RGBA"))
    px = a[a[..., 3] >= alpha_min][:, :3]
    if len(px) == 0:
        return []
    q = (px >> 4).astype(np.int32)
    key = q[:, 0] * 256 + q[:, 1] * 16 + q[:, 2]
    vals, cnt = np.unique(key, return_counts=True)
    order = np.argsort(-cnt)[:n]
    out = []
    for i in order:
        sel = px[key == vals[i]]
        out.append((tuple(int(v) for v in sel.mean(axis=0).round()), round(100.0 * cnt[i] / len(px), 1)))
    return out


def luminance(rgb) -> float:
    """WCAG relative luminance of an RGB tuple (0-255)."""
    def ch(v: float) -> float:
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(rgb[0]) + 0.7152 * ch(rgb[1]) + 0.0722 * ch(rgb[2])


def contrast_ratio(a, b) -> float:
    """WCAG contrast ratio between two RGB tuples, 1.0 to 21.0."""
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
