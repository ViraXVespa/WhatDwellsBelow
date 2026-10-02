#!/usr/bin/env python3
"""Shared pixel helpers for the pack_*/process_*/plate_remap tools.

Import-only. Only helpers whose copies were byte-identical live here; variants
(fit, key, key_and_fit, sample_bg, extract) stay in their tools until a
before/after pixel diff proves one shared form. Change a helper here only with
that proof.
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
