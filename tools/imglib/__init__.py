"""Shared image library for the tools (Pillow + numpy, OpenCV when present).

Import-only package. `tools/` must be on sys.path (every tool already puts it there), then:

    from imglib import imgio, geom, color, key, compare, look

Modules: imgio (load/save, MAGENTA), geom (bbox, crop, fit, scale, flip, grid), color (distance, background
refs, palette, contrast), key (plate and wand keying, pockets, despill, plate remap), compare (pixel diff,
heatmap, score, montage), look (describe / layout / contrast / anchors / halo / motion for a model that
cannot see well; CLI: tools/img_inspect.py). Dependencies: tools/requirements.txt.

OpenCV is optional: without it the keying and components fall back to slower numpy/python paths, and only
template matching (look.find) refuses, with a clear message. Set IMGLIB_NO_CV2=1 to force the fallback.
"""
from __future__ import annotations

import os

try:
    if os.environ.get("IMGLIB_NO_CV2"):
        raise ImportError("IMGLIB_NO_CV2 set")
    import cv2  # noqa: F401
    HAVE_CV2 = True
except ImportError:
    cv2 = None  # type: ignore[assignment]
    HAVE_CV2 = False


def require_cv2(what: str) -> None:
    """Raise SystemExit with an install hint when OpenCV is missing."""
    if not HAVE_CV2:
        raise SystemExit(
            f"error: {what} needs OpenCV (cv2). Install: python3 -m pip install -r tools/requirements.txt "
            "(PEP 668 systems: python3 -m venv --system-site-packages VENV, then VENV/bin/python)"
        )
