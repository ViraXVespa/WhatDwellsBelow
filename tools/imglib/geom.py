"""Geometry helpers: bbox, crop, fit, scale, flip, grid split.

Nearest-neighbour is only for sizing up. Sizing down uses premultiplied Lanczos.
A heavy shrink also keeps a real near-white run (a string) that the kernel would average away.
"""
from __future__ import annotations

import numpy as np
from PIL import Image


def _lanczos_down(im: Image.Image, size: tuple[int, int]) -> Image.Image:
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
    return Image.fromarray(np.clip(np.rint(scaled), 0, 255).astype(np.uint8), "RGBA")


def _subject_cell(im: Image.Image, scale: int = 8) -> int:
    """Pixel size of the subject, or 1 when the subject is not a flat upscale of that cell."""
    arr = np.array(im.convert("RGBA"))
    h, w = arr.shape[:2]
    if h < scale * 8 or w < scale * 8:
        return 1
    hh, ww = h - (h % scale), w - (w % scale)
    block = arr[:hh, :ww].reshape(hh // scale, scale, ww // scale, scale, 4)
    subject = block[:, :, :, :, 3].max(axis=(1, 3)) > 128
    if int(subject.sum()) < 20:
        return 1
    rgb = block[:, :, :, :, :3].astype(np.int16)
    spread = (rgb.max(axis=(1, 3)) - rgb.min(axis=(1, 3))).max(axis=2)
    if float(np.median(spread[subject])) > 6:
        return 1
    return scale


def _box_reduce(im: Image.Image, scale: int) -> Image.Image:
    w, h = im.size
    ww, hh = w - (w % scale), h - (h % scale)
    arr = np.array(im.crop((0, 0, ww, hh)), dtype=np.float32)
    alpha = arr[:, :, 3:4] / 255.0
    prem = arr.copy()
    prem[:, :, :3] *= alpha
    cell = prem.reshape(hh // scale, scale, ww // scale, scale, 4).mean(axis=(1, 3))
    out_a = cell[:, :, 3:4]
    rgb = np.zeros_like(cell[:, :, :3])
    nz = out_a[..., 0] > 0.5
    rgb[nz] = np.clip(cell[nz, :3] * (255.0 / np.maximum(out_a[nz], 1.0)), 0, 255)
    cell[:, :, :3] = rgb
    return Image.fromarray(np.clip(np.rint(cell), 0, 255).astype(np.uint8), "RGBA")


def _keep_light_run(src: Image.Image, fitted: Image.Image) -> Image.Image:
    """Put back a near-white run when a heavy shrink averaged it away.

    A solid mass of bright pixels (a face, a highlight) is left to the Lanczos result.
    This is not an edge lift: only a bin that collected a real run is rewritten.
    """
    sw, sh = src.size
    dw, dh = fitted.size
    if sw <= dw or sh <= dh:
        return fitted
    bin_area = (sw / float(dw)) * (sh / float(dh))
    if bin_area < 150:
        return fitted
    arr = np.array(src)
    light = (arr[:, :, :3].min(axis=2) > 140) & (arr[:, :, 3] > 80)
    if int(light.sum()) < 4:
        return fitted
    ys, xs = np.nonzero(light)
    fx = np.clip((xs * (dw / float(sw))).astype(np.int32), 0, dw - 1)
    fy = np.clip((ys * (dh / float(sh))).astype(np.int32), 0, dh - 1)
    lin = fy * dw + fx
    count = np.bincount(lin, minlength=dw * dh)
    out = np.array(fitted)
    order = np.argsort(lin)
    lin_s = lin[order]
    cols = arr[ys, xs][order]
    cuts = np.flatnonzero(np.diff(lin_s)) + 1
    starts = np.r_[0, cuts]
    ids = lin_s[starts]
    for gid, start, end in zip(ids, starts, np.r_[cuts, len(lin_s)]):
        if count[gid] < 4:
            continue
        med = np.median(cols[start:end], axis=0)
        y, x = divmod(int(gid), dw)
        out[y, x, :3] = med[:3]
        out[y, x, 3] = max(int(out[y, x, 3]), 210)
    return Image.fromarray(out, "RGBA")


def resize_rgba(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale an RGBA image. Nearest when both sides grow. Premultiplied Lanczos when either side shrinks."""
    im = im.convert("RGBA")
    size = (max(1, int(size[0])), max(1, int(size[1])))
    if size == im.size:
        return im
    pure_up = size[0] >= im.size[0] and size[1] >= im.size[1]
    if pure_up:
        return im.resize(size, Image.Resampling.NEAREST)
    source = im
    cell = _subject_cell(im)
    if cell > 1:
        im = _box_reduce(im, cell)
        if im.size == size:
            return _keep_light_run(source, im)
        if im.size[0] <= size[0] and im.size[1] <= size[1]:
            return _keep_light_run(source, im.resize(size, Image.Resampling.NEAREST))
    return _keep_light_run(source, _lanczos_down(im, size))


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


def fit_box(im, canvas: int, pad: int, *, resample=None, to_int=round, oy=None, empty_exit: str = "", alpha_min: int = 24):
    """Crop to the opaque box, pad it, scale to fit `canvas` square, paste centred (oy(nh) sets the y offset).

    resample overrides the scale rule. Otherwise nearest when sizing up and premultiplied Lanczos
    when sizing down. to_int turns the scaled size into pixels (round or int). empty_exit raises
    SystemExit(msg) on an empty image instead of returning a blank canvas.
    alpha_min is the crop floor. Pixels under it do not grow the box, so a glow stored only as
    faint alpha is cut off. Pass a lower floor when that glow is the result.
    """
    # A faint halo must not expand the fit and shrink the subject.
    box = bbox(im, alpha_min) or im.getbbox()
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
