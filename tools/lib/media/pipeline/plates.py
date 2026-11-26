"""Frame one keyed mannequin view for Pixal3D.

The figure's long side fills 1/1.1 of a square black plate, same rule for every
view. Keying stays in imglib.matte. This does not run Comfy.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from imglib.geom import bbox, fit_box
from imglib.matte import key

CANVAS = 1024
SPAN = 1.1


def frame_rgba(im: Image.Image, *, canvas: int = CANVAS, span: float = SPAN) -> tuple[Image.Image, int]:
    """Fit a transparent figure on a black square. The long side is canvas/span."""
    if span <= 1:
        raise ValueError("span must be greater than 1")
    solid = im.convert("RGBA")
    alpha = solid.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    solid.putalpha(alpha)
    box = bbox(solid, 24) or solid.getbbox()
    if not box:
        raise ValueError("frame has no figure")
    long_side = max(box[2] - box[0], box[3] - box[1])
    pad = max(0, round(long_side * (span - 1) / 2))
    fitted = fit_box(solid, canvas, pad, alpha_min=24)
    found = bbox(fitted, 24)
    height = 0 if not found else found[3] - found[1]
    base = Image.new("RGB", fitted.size, (0, 0, 0))
    rgba = fitted.convert("RGBA")
    base.paste(rgba, mask=rgba.getchannel("A"))
    return base, height


def frame_file(src: Path, dest: Path, *, canvas: int = CANVAS) -> dict:
    im = Image.open(src)
    keyed, stats = key(im)
    framed, height = frame_rgba(keyed, canvas=canvas)
    dest.parent.mkdir(parents=True, exist_ok=True)
    framed.save(dest)
    return {"plate": None if not stats else stats.get("plate"), "height": height, "canvas": canvas}


def selftest() -> list[str]:
    """A white figure on magenta lands near canvas/1.1 tall on black."""
    bad: list[str] = []
    canvas = 110
    plate = Image.new("RGB", (64, 64), (255, 0, 255))
    mark = Image.new("RGB", (8, 40), (240, 230, 210))
    plate.paste(mark, (28, 12))
    keyed, stats = key(plate)
    if not stats.get("plate"):
        bad.append("a magenta plate did not key")
    framed, height = frame_rgba(keyed, canvas=canvas)
    if framed.size != (canvas, canvas):
        bad.append("framed plate is not square")
    if framed.getpixel((0, 0)) != (0, 0, 0):
        bad.append("framed corner is not black")
    target = canvas / SPAN
    if abs(height - target) > 2:
        bad.append(f"figure height {height} is not near {target:.0f}")
    return bad
