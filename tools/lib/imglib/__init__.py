"""Shared image library for the tools (Pillow, numpy and OpenCV).

Import-only package. `tools/` must be on sys.path (every tool already puts it there), then:

    from imglib import imgio, geom, color, key, compare, look

Modules: imgio (load/save, MAGENTA), geom (bbox, crop, fit, scale, flip, grid), color (distance, background
refs, palette, contrast), key (plate mask, plate remap, key entry points), matte (the staged keyer), compare (pixel diff,
heatmap, score, montage), look (describe / layout / contrast / anchors / halo / motion for a model that
cannot see well; CLI: tools/shots.py inspect). Dependencies: tools/requirements.txt.

OpenCV is required (tools/requirements.txt). Importing imglib without it stops with the install command,
so no tool silently takes a slower or different path.
"""
from __future__ import annotations

try:
    import cv2  # noqa: F401
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "error: tools/lib/imglib needs OpenCV (cv2). Install: python -m pip install -r tools/requirements.txt"
    ) from exc
HAVE_CV2 = True

def require_cv2(what: str) -> None:
    """Raise SystemExit with an install hint when OpenCV is missing."""
    if not HAVE_CV2:
        raise SystemExit(
            f"error: {what} needs OpenCV (cv2). Install: python -m pip install -r tools/requirements.txt "
            "(PEP 668 systems: python -m venv --system-site-packages VENV, then VENV/bin/python)"
        )
