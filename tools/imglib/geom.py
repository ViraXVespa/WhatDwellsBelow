"""Geometry helpers: bbox, crop, fit, scale, flip, grid split.

Nearest-neighbour is only for sizing up. Sizing down uses premultiplied Lanczos.
"""
from __future__ import annotations

import numpy as np
from PIL import Image


def resize_rgba(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale an RGBA image. Nearest when both sides grow. Premultiplied Lanczos when either side shrinks."""
    im = im.convert("RGBA")
    size = (max(1, int(size[0])), max(1, int(size[1])))
    if size == im.size:
        return im
    pure_up = size[0] >= im.size[0] and size[1] >= im.size[1]
    if pure_up:
        return im.resize(size, Image.Resampling.NEAREST)
    arr = np.array(im, dtype=np.float32)
    alpha = arr[:, :, 3:4] / 255.0
    prem = arr.copy()
    prem[:, :, :3] *= alpha
    prem_u8 = np.clip(np.rint(prem), 0, 255).astype(np.uint8)
    scaled = np.array(Image.fromarray(prem_u8, "RGBA").resize(size, Image.Resampling.LANCZOS), dtype=np.float32)
    out_a = scaled[:, :, 3:4]
    rgb = np.zeros_like(scaled[:, :, :3])
    nz = out_a[..., 0] > 0.5
    rgb[nz] = np.clip(scaled[nz, :3] * (255.0 / np.maximum(out_a[nz], 1.0)), 0, 255)
    scaled[:, :, :3] = rgb
    # A one-pixel line averages away under Lanczos. Keep a hairline of solid source
    # pixels visible, using that solid colour, without hardening a wide soft glow.
    solid = arr[:, :, 3] >= 220.0
    if np.any(solid):
        cover = np.array(Image.fromarray((solid.astype(np.uint8) * 255), "L").resize(size, Image.Resampling.BOX))
        pack = np.zeros_like(arr)
        pack[:, :, :3] = np.where(solid[..., None], arr[:, :, :3], 0.0)
        pack[:, :, 3] = np.where(solid, 255.0, 0.0)
        pooled = np.array(Image.fromarray(np.clip(np.rint(pack), 0, 255).astype(np.uint8), "RGBA").resize(size, Image.Resampling.BOX), dtype=np.float32)
        hair = (cover >= 1) & (cover <= 48) & (scaled[:, :, 3] < 170.0)
        if np.any(hair):
            tone = np.clip(pooled[:, :, :3] * (255.0 / np.maximum(pooled[:, :, 3:4], 1.0)), 0, 255)
            scaled[hair, :3] = tone[hair]
            scaled[hair, 3] = np.maximum(scaled[hair, 3], 210.0)
    return Image.fromarray(np.clip(np.rint(scaled), 0, 255).astype(np.uint8), "RGBA")


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


def shrink(im: Image.Image, cap: int) -> Image.Image:
    """High-quality shrink so the longest side is at most `cap` (returned as is when it already is)."""
    w, h = im.size
    m = max(w, h)
    if m <= cap:
        return im
    s = cap / m
    return resize_rgba(im, (max(1, int(w * s)), max(1, int(h * s))))


def fit_axis(im: Image.Image, *, width: int | None = None, height: int | None = None, to_int=int, empty: str = "none"):
    """Crop to `im.getbbox()` and scale so the width (or the height) equals the given size.

    Nearest when sizing up, premultiplied Lanczos when sizing down. The other side follows the aspect
    (at least 1 px, `to_int` turns it into pixels). Empty image: None, or the whole image as the box
    when `empty="whole"`.
    """
    box = im.getbbox()
    if box is None and empty != "whole":
        return None
    cropped = im.crop(box) if box is not None else im.copy()
    if width is not None:
        scale = width / max(1, cropped.size[0])
        size = (width, max(1, to_int(cropped.size[1] * scale)))
    else:
        scale = height / max(1, cropped.size[1])
        size = (max(1, to_int(cropped.size[0] * scale)), height)
    return resize_rgba(cropped, size)


def flip(im: Image.Image, horizontal: bool = True) -> Image.Image:
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT if horizontal else Image.Transpose.FLIP_TOP_BOTTOM)


def grid_split(im: Image.Image, cols: int, rows: int) -> list[Image.Image]:
    """Equal cells, row-major."""
    cw, ch = im.width // cols, im.height // rows
    return [im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r in range(rows) for c in range(cols)]


def fit_box(im, canvas: int, pad: int, *, resample=None, to_int=round, oy=None, empty_exit: str = ""):
    """Crop to the opaque box, pad it, scale to fit `canvas` square, paste centred (oy(nh) sets the y offset).

    resample overrides the scale rule. Otherwise nearest when sizing up and premultiplied Lanczos
    when sizing down. to_int turns the scaled size into pixels (round or int). empty_exit raises
    SystemExit(msg) on an empty image instead of returning a blank canvas.
    """
    # A faint halo must not expand the fit and shrink the subject.
    box = bbox(im, 24) or im.getbbox()
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
    if resample is None:
        resized = resize_rgba(padded, (nw, nh))
    else:
        resized = padded.resize((nw, nh), resample)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2 if oy is None else oy(nh)), resized)
    return out
