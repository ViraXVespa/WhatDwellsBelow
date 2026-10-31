"""Per-image pixel grid: generated pixel art is not on a fixed lattice (cells drift a pixel too big or small, the grid
starts at any phase), so detect each axis's own cell boundaries and sample one colour per detected cell.

detect(im) -> {"x": Axis, "y": Axis}; Axis = (period, phase, bounds) with bounds the cell edges 0..size, found from
gradient-projection peaks (|colour step| summed across the other axis) fitted locally around period steps (+-JIT).
Seed pitch: geom.detect_grid (uniform pitch/phase, luma combs per tile) when it is confident; this module refines that
into the art's own per-cell edges. sample(im, g) -> one RGBA per detected cell (the cell's most common colour); fill(small, g, size) paints it back."""
from __future__ import annotations

import numpy as np
from PIL import Image

JIT = 1


def _profile(a: np.ndarray, axis: int) -> np.ndarray:
    """Boundary strength before each index along axis (index 0 and size: 0)."""
    d = np.abs(np.diff(a.astype(np.float32), axis=axis)).sum(axis=2)  # per-pixel colour step
    p = d.sum(axis=1 - axis) if axis == 1 else d.sum(axis=1)
    return np.concatenate([[0.0], p, [0.0]])


def _axis(p: np.ndarray, size: int, seed: float = 0.0) -> tuple[int, int, list[int]]:
    inner = p[1:size]
    thr = 0.25 * float(np.percentile(inner, 95))
    peaks = [i for i in range(1, size) if p[i] > thr and p[i] >= p[i - 1] and p[i] > p[i + 1]]
    per = int(round(seed)) if seed >= 2.0 else (int(round(float(np.median(np.diff(peaks))))) if len(peaks) >= 3 else 1)
    if per <= 1:
        return 1, 0, list(range(size + 1))
    keep: list[int] = []
    for i in sorted(peaks, key=lambda i: -p[i]):  # strongest first; neighbours closer than a jittered cell lose
        if all(abs(i - k) >= max(2, per - 1 - JIT) for k in keep):
            keep.append(i)
    keep = sorted(keep)
    step = float(per)
    if len(keep) >= 3:  # mean step over the kept edges: the +-1 jitter averages out (a median of ints does not)
        step = (keep[-1] - keep[0]) / (len(keep) - 1)
        per = max(2, int(round(step)))
    edges = [0] + keep + [size]
    bounds = [0]
    for a, b in zip(edges, edges[1:]):  # flat runs (same colour cells) split evenly at the local period
        k = max(1, int(round((b - a) / step))) if b - a > step + JIT else 1  # up to one jittered cell is one cell
        bounds += [a + round((b - a) * t / k) for t in range(1, k + 1)]
    bounds = sorted(set(bounds))
    return per, (keep[0] % per) if keep else 0, bounds


def detect(im: Image.Image, seed: float | None = None) -> dict:
    if seed is None:
        from . import geom
        pitch, _gx, _gy, conf = geom.detect_grid(im.convert("RGB"), alpha=im.convert("RGBA").getchannel("A"))
        seed = float(pitch) if conf >= 0.5 else 0.0
    a = np.asarray(im.convert("RGBA"))
    a = a * np.concatenate([a[..., 3:] / 255.0] * 3 + [np.ones_like(a[..., 3:])], axis=2)  # transparent = one colour
    h, w = a.shape[:2]
    return {"x": _axis(_profile(a, 1), w, seed), "y": _axis(_profile(a, 0), h, seed)}


def sample(im: Image.Image, g: dict) -> Image.Image:
    a = np.asarray(im.convert("RGBA"))
    bx, by = g["x"][2], g["y"][2]
    out = np.zeros((len(by) - 1, len(bx) - 1, 4), np.uint8)
    for j in range(len(by) - 1):
        for i in range(len(bx) - 1):
            c = a[by[j]:by[j + 1], bx[i]:bx[i + 1]].reshape(-1, 4)
            vals, n = np.unique(c, axis=0, return_counts=True)
            out[j, i] = vals[int(np.argmax(n))]
    return Image.fromarray(out, "RGBA")


def fill(small: Image.Image, g: dict, size: tuple[int, int]) -> Image.Image:
    s = np.asarray(small.convert("RGBA"))
    xi = np.searchsorted(g["x"][2], np.arange(size[0]), side="right") - 1
    yi = np.searchsorted(g["y"][2], np.arange(size[1]), side="right") - 1
    return Image.fromarray(s[np.clip(yi, 0, s.shape[0] - 1)][:, np.clip(xi, 0, s.shape[1] - 1)], "RGBA")


def jittered(seed: int = 7, n: int = 14, base: int = 5, phase: int = 3) -> tuple[Image.Image, list[int], list[int]]:
    """Selftest art: random-colour cells of base +-1 px, first edge at `phase`."""
    rng = np.random.default_rng(seed)
    def edges() -> list[int]:
        e, x = sorted({0, phase}), phase
        for _ in range(n):
            x += base + int(rng.integers(-1, 2))
            e.append(x)
        return e
    ex, ey = edges(), edges()
    w, h = ex[-1] + 2, ey[-1] + 2
    ex.append(w)
    ey.append(h)
    cells = rng.integers(0, 256, (len(ey), len(ex), 3), dtype=np.uint8)
    a = np.zeros((h, w, 4), np.uint8)
    a[..., 3] = 255
    for j in range(len(ey) - 1):
        for i in range(len(ex) - 1):
            a[ey[j]:ey[j + 1], ex[i]:ex[i + 1], :3] = cells[j, i]
    return Image.fromarray(a, "RGBA"), ex, ey
