#!/usr/bin/env python3
"""Shim: shared pixel helpers now live in tools/imglib (kept one release for the pack_*/process_* imports).

Import-only. Same names and signatures as before: `dist`, `neighbors8`, `shrink_keyed`, `KEYED_CAP`,
`chroma_alpha`, `flood_border`, `fill_pockets` (flat-list form), `fit_box`. New code imports imglib directly
(`imglib.color`, `imglib.geom`, `imglib.key`).
"""
from __future__ import annotations

import numpy as np
from PIL import Image

from imglib import key as _key
from imglib.color import dist  # noqa: F401
from imglib.geom import fit_box  # noqa: F401
from imglib.key import chroma_alpha, flood_border  # noqa: F401

KEYED_CAP = 512


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
    w, h = im.size
    m = max(w, h)
    if m <= cap:
        return im
    s = cap / m
    return im.resize((max(1, int(w * s)), max(1, int(h * s))), Image.Resampling.NEAREST)


def fill_pockets(mask, distances, w: int, h: int, pocket_dist: float, pocket_frac: float, tight_dist: float) -> int:
    """Flat-list form of imglib.key.fill_pockets (sets cells in `mask` in place, returns how many were added)."""
    m = np.asarray(mask, dtype=np.uint8).reshape(h, w)
    d = np.asarray(distances, dtype=np.float32).reshape(h, w)
    added = _key.fill_pockets(m, d, pocket_dist, pocket_frac, tight_dist)
    flat = m.ravel()
    for i in np.flatnonzero(flat):
        mask[int(i)] = 1
    return added
