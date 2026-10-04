"""Load and save images; the key colour."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

MAGENTA = (255, 0, 255)
MAGENTA_RGBA = (255, 0, 255, 255)
MAGENTA_HEX = "#FF00FF"


def load(path, mode: str = "RGBA") -> Image.Image:
    """Open an image fully decoded and converted (closes the file)."""
    with Image.open(path) as im:
        return im.convert(mode)


def save(im: Image.Image, path) -> Path:
    """Save, creating parent folders. Returns the path."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    im.save(p)
    return p


def to_np(im: Image.Image, mode: str = "RGBA") -> np.ndarray:
    """Writable uint8 H x W x C copy."""
    return np.array(im.convert(mode), dtype=np.uint8, copy=True)


def from_np(arr: np.ndarray) -> Image.Image:
    mode = {2: "L", 3: "RGB", 4: "RGBA"}[arr.ndim if arr.ndim == 2 else arr.shape[2]]
    return Image.fromarray(arr.astype(np.uint8, copy=False), mode)


def hex_of(rgb) -> str:
    return "#%02X%02X%02X" % (int(rgb[0]), int(rgb[1]), int(rgb[2]))
