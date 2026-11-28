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


def _largest_mass(im: Image.Image) -> Image.Image:
    """Keep the largest 8-connected opaque mass. A speck must not shrink the figure."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    pix = rgba.load()
    seen = bytearray(w * h)
    best: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            start = y * w + x
            if seen[start] or pix[x, y][3] < 128:
                continue
            stack = [(x, y)]
            seen[start] = 1
            comp: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                comp.append((cx, cy))
                for dy in (-1, 0, 1):
                    ny = cy + dy
                    if ny < 0 or ny >= h:
                        continue
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        nx = cx + dx
                        if nx < 0 or nx >= w:
                            continue
                        j = ny * w + nx
                        if seen[j] or pix[nx, ny][3] < 128:
                            continue
                        seen[j] = 1
                        stack.append((nx, ny))
            if len(comp) > len(best):
                best = comp
    if not best:
        return rgba
    keep = bytearray(w * h)
    for x, y in best:
        keep[y * w + x] = 1
    for y in range(h):
        row = y * w
        for x in range(w):
            if pix[x, y][3] and not keep[row + x]:
                pix[x, y] = (0, 0, 0, 0)
    return rgba


def frame_rgba(im: Image.Image, *, canvas: int = CANVAS, span: float = SPAN) -> tuple[Image.Image, int]:
    """Fit a transparent figure on a black square. The long side is canvas/span."""
    if span <= 1:
        raise ValueError("span must be greater than 1")
    solid = im.convert("RGBA")
    alpha = solid.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    solid.putalpha(alpha)
    solid = _largest_mass(solid)
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
    stray = Image.new("RGB", (64, 64), (255, 0, 255))
    stray.paste(Image.new("RGB", (8, 40), (240, 230, 210)), (28, 20))
    stray.putpixel((32, 2), (240, 230, 210))
    keyed, _stats = key(stray)
    framed, height = frame_rgba(keyed, canvas=canvas)
    pix = framed.load()
    rows = [y for y in range(canvas) if any(max(pix[x, y]) > 16 for x in range(canvas))]
    span_h = 0 if not rows else rows[-1] - rows[0] + 1
    if abs(span_h - target) > 2:
        bad.append(f"a speck shrank the figure to {span_h}")
    return bad
