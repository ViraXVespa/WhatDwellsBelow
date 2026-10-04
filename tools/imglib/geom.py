"""Geometry helpers: bbox, crop, fit, nearest scale, flip, grid split."""
from __future__ import annotations

from PIL import Image


def bbox(im: Image.Image, alpha_min: int = 1):
    """(left, top, right, bottom) of pixels with alpha >= alpha_min, or None when empty."""
    a = im.convert("RGBA").getchannel("A")
    if alpha_min > 1:
        a = a.point(lambda v: 255 if v >= alpha_min else 0)
    return a.getbbox()


def crop(im: Image.Image, box, pad: int = 0) -> Image.Image:
    l, t, r, b = box
    return im.crop((max(0, l - pad), max(0, t - pad), min(im.width, r + pad), min(im.height, b + pad)))


def scale_nearest(im: Image.Image, factor: float | None = None, size: tuple[int, int] | None = None) -> Image.Image:
    """Nearest-neighbour scale by factor or to size."""
    if size is None:
        size = (max(1, round(im.width * float(factor))), max(1, round(im.height * float(factor))))
    return im.resize(size, Image.Resampling.NEAREST)


def flip(im: Image.Image, horizontal: bool = True) -> Image.Image:
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT if horizontal else Image.Transpose.FLIP_TOP_BOTTOM)


def grid_split(im: Image.Image, cols: int, rows: int) -> list[Image.Image]:
    """Equal cells, row-major."""
    cw, ch = im.width // cols, im.height // rows
    return [im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r in range(rows) for c in range(cols)]


def fit_box(im, canvas: int, pad: int, *, resample=None, to_int=round, oy=None, empty_exit: str = ""):
    """Crop to the opaque box, pad it, scale to fit `canvas` square, paste centred (oy(nh) sets the y offset).

    resample defaults to NEAREST; to_int turns the scaled size into pixels (round or int); empty_exit
    raises SystemExit(msg) on an empty image instead of returning a blank canvas.
    """
    box = im.getbbox()
    if not box:
        if empty_exit:
            raise SystemExit(empty_exit)
        return Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    cropped = im.crop(box)
    padded = Image.new("RGBA", (cropped.size[0] + pad * 2, cropped.size[1] + pad * 2), (0, 0, 0, 0))
    padded.paste(cropped, (pad, pad), cropped)
    scale = min(canvas / padded.size[0], canvas / padded.size[1])
    nw = max(1, to_int(padded.size[0] * scale))
    nh = max(1, to_int(padded.size[1] * scale))
    resized = padded.resize((nw, nh), resample if resample is not None else Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2 if oy is None else oy(nh)), resized)
    return out
