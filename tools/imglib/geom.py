"""Geometry helpers: bbox, crop, fit, scale, flip, grid split.

Nearest-neighbour is only for sizing up. Sizing down uses premultiplied Lanczos.
A flat nearest upscale is reduced to its pixel grid first. Transparent pixels do not
count as a second colour in that test. A heavy shrink also keeps a real near-white run
(a string) that the kernel would average away.
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


def _cell_spread(arr: np.ndarray, scale: int) -> float:
    """Median colour spread of opaque pixels in subject cells. Transparent black is not a colour."""
    h, w = arr.shape[:2]
    if h < scale * 4 or w < scale * 4:
        return 999.0
    hh, ww = h - (h % scale), w - (w % scale)
    block = arr[:hh, :ww].reshape(hh // scale, scale, ww // scale, scale, 4)
    opaque = block[:, :, :, :, 3] > 128
    rgb = block[:, :, :, :, :3].astype(np.int16)
    present = np.where(opaque[..., None], rgb, 999)
    absent = np.where(opaque[..., None], rgb, -999)
    spread = (absent.max(axis=(1, 3)) - present.min(axis=(1, 3))).max(axis=2)
    count = opaque.sum(axis=(1, 3))
    subject = count >= max(1, (scale * scale) // 4)
    if int(subject.sum()) < 12:
        return 999.0
    return float(np.median(spread[subject]))


def _subject_cell(im: Image.Image) -> int:
    """Largest power-of-two cell that is still a flat nearest upscale, or 1.

    A keyed edge cell is subject paint plus transparent black. The black is not a
    second colour, so it does not reject the grid.
    """
    arr = np.array(im.convert("RGBA"))
    best = 1
    scale = 2
    while scale <= 32:
        if _cell_spread(arr, scale) > 8:
            break
        best = scale
        scale *= 2
    return best


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


ALPHA_JUMP = 96.0  # alpha range inside one footprint centre above this: a hard edge, snapped to its side
CELL_FLAT = 7.0  # median luma spread inside a footprint's centre at or under this: the source is drawn in flat cells


def _centre_windows(arr: np.ndarray, size: tuple[int, int], whole: bool = False):
    """Per output pixel, the source pixels in the centre half of its footprint (whole: the whole footprint):
    (oh, ow, n, 4) float32."""
    sh, sw = arr.shape[:2]
    ow, oh = size
    fx, fy = sw / float(ow), sh / float(oh)
    if whole:
        kx, ky = max(1, int(round(fx))), max(1, int(round(fy)))
    else:
        kx, ky = max(2 if fx >= 3 else 1, int(fx / 2)), max(2 if fy >= 3 else 1, int(fy / 2))
    cx = ((np.arange(ow) + 0.5) * fx - kx / 2.0).astype(np.int32)
    cy = ((np.arange(oh) + 0.5) * fy - ky / 2.0).astype(np.int32)
    xs = np.clip(cx[:, None] + np.arange(kx)[None, :], 0, sw - 1)  # (ow, kx)
    ys = np.clip(cy[:, None] + np.arange(ky)[None, :], 0, sh - 1)  # (oh, ky)
    win = arr[ys[:, None, :, None], xs[None, :, None, :]]  # (oh, ow, ky, kx, 4)
    return win.reshape(oh, ow, ky * kx, 4).astype(np.float32)


def cell_reduce(im: Image.Image, size: tuple[int, int]):
    """Shrink art drawn in flat cells (pixel art, AI pixel art on a loose grid, JPEG noise on top) by taking the
    median of the centre of each output pixel's footprint. Edges between cells are never averaged, so outlines and
    hard alpha edges stay hard; a soft glow keeps its partial alpha (the median of partial alpha). Returns None when
    the source is not drawn in cells at this scale (smooth painting): the caller uses the premultiplied Lanczos."""
    arr = np.array(im.convert("RGBA"))
    sh, sw = arr.shape[:2]
    if sw / float(size[0]) < 2.5 or sh / float(size[1]) < 2.5:
        return None
    win = _centre_windows(arr, size)
    a = win[..., 3]
    luma = win[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    solid = a.min(axis=2) >= 250
    if int(solid.sum()) < 24:
        return None
    spread = np.percentile(luma, 90, axis=2) - np.percentile(luma, 10, axis=2)
    if float(np.median(spread[solid])) > CELL_FLAT:
        return None
    med_a = np.median(a, axis=2)
    # a window across a hard edge (paint and clear, little in between) takes the side it is mostly on: hard edges
    # stay hard. A window of partial alpha (glow, translucent shading) keeps its median.
    # (a glow changes slowly across one footprint centre; an edge jumps by more than ALPHA_JUMP inside it)
    edge = (a.max(axis=2) - a.min(axis=2)) > ALPHA_JUMP
    med_a = np.where(edge, np.where(a.mean(axis=2) >= 128.0, 255.0, 0.0), med_a)
    keep = a >= np.maximum(1.0, med_a[..., None] * 0.5)
    rgb = np.where(keep[..., None], win[..., :3], np.nan)
    import warnings
    with np.errstate(all="ignore"), warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)
        col = np.nanmedian(rgb, axis=2)
    col = np.nan_to_num(col)
    out = np.dstack([col, med_a])
    out[med_a < 1.0] = 0
    return Image.fromarray(np.clip(np.rint(out), 0, 255).astype(np.uint8), "RGBA")


def _line_through(win: np.ndarray, ky: int, kx: int) -> np.ndarray:
    """Footprints holding a thin line (paint centred, clear on both sides), not the side of a solid edge."""
    oh, ow = win.shape[:2]
    paint = (win >= 128).reshape(oh, ow, ky, kx).astype(np.float32)
    n = paint.sum(axis=(2, 3))
    yy = (np.arange(ky, dtype=np.float32) + 0.5) / ky - 0.5
    xx = (np.arange(kx, dtype=np.float32) + 0.5) / kx - 0.5
    with np.errstate(all="ignore"):
        cy = (paint * yy[None, None, :, None]).sum(axis=(2, 3)) / n
        cx = (paint * xx[None, None, None, :]).sum(axis=(2, 3)) / n
    return (n > 0) & (np.abs(np.nan_to_num(cy, nan=1.0)) <= 0.2) & (np.abs(np.nan_to_num(cx, nan=1.0)) <= 0.2)


def snap_edges(src: Image.Image, out: Image.Image) -> Image.Image:
    """Hard edges stay hard after a shrink: an output pixel whose footprint jumps from clear to paint (alpha range
    over ALPHA_JUMP) takes the side it is mostly on, and a thin line through the footprint (a bowstring, an
    outline thinner than one output pixel) is kept as paint. A glow or translucent shading changes slowly across one
    footprint and keeps its partial alpha."""
    arr = np.array(src.convert("RGBA"))
    if arr.shape[0] < out.size[1] * 2 or arr.shape[1] < out.size[0] * 2:
        return out
    full = _centre_windows(arr, out.size, whole=True)
    win = full[..., 3]
    ky = max(1, int(round(arr.shape[0] / float(out.size[1]))))
    kx = max(1, int(round(arr.shape[1] / float(out.size[0]))))
    edge = (win.max(axis=2) - win.min(axis=2)) > ALPHA_JUMP
    line = edge & _line_through(win, ky, kx)
    o = np.array(out)
    side = np.where((win.mean(axis=2) >= 128.0) | line, 255, 0).astype(np.uint8)
    o[..., 3] = np.where(edge, side, o[..., 3])
    # a snapped edge or line pixel takes the colour of the paint in its footprint (an outline on the rim, the line
    # itself), not an average with the clear around it or the fill behind it
    fix = edge & (side == 255)
    if fix.any():
        paint = full[..., 3:4] >= 128
        import warnings
        with np.errstate(all="ignore"), warnings.catch_warnings():
            warnings.simplefilter("ignore", RuntimeWarning)
            col = np.nanmedian(np.where(paint, full[..., :3], np.nan), axis=2)
        o[fix, :3] = np.clip(np.nan_to_num(col[fix]), 0, 255).astype(np.uint8)
    o[o[..., 3] == 0] = 0
    return Image.fromarray(o, "RGBA")


def resize_rgba(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale an RGBA image. Nearest when both sides grow. Shrinking: art drawn in flat cells takes the centre
    median of each footprint (cell_reduce, keeps pixel edges hard); anything else is premultiplied Lanczos."""
    im = im.convert("RGBA")
    size = (max(1, int(size[0])), max(1, int(size[1])))
    if size == im.size:
        return im
    pure_up = size[0] >= im.size[0] and size[1] >= im.size[1]
    if pure_up:
        return im.resize(size, Image.Resampling.NEAREST)
    source = im
    # art drawn in flat cells: centre medians straight from the source (a box average over a grid that is not
    # exactly the source's would blur every cell edge)
    cells = cell_reduce(im, size)
    if cells is not None:
        return _keep_light_run(source, snap_edges(im, cells))
    cell = _subject_cell(im)
    if cell > 1:
        im = _box_reduce(im, cell)
        if im.size == size:
            return _keep_light_run(source, im)
        if im.size[0] <= size[0] and im.size[1] <= size[1]:
            return _keep_light_run(source, im.resize(size, Image.Resampling.NEAREST))
    return _keep_light_run(source, snap_edges(im, _lanczos_down(im, size)))


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


def core_box(im: Image.Image, alpha_min: int = 128):
    """Box of the solid body (alpha >= alpha_min), falling back to any alpha."""
    return bbox(im, alpha_min) or im.convert("RGBA").getbbox()


def fit_like(im: Image.Image, ref, alpha_min: int = 128) -> Image.Image:
    """Place a keyed still on a canvas exactly like `ref` (the live still it replaces): same canvas size, the solid
    body scaled to the size of ref's body and lined up on ref's bottom edge and centre x. No recentring and no
    padding of its own, so a sprite anchored low, a building face cropped tight, or an off-centre prop keeps that
    framing. The glow around the body comes along at the same scale.
    ref may also be a recorded geometry ((W, H), body box), so a re-run does not fit against its own output."""
    im = im.convert("RGBA")
    if isinstance(ref, Image.Image):
        (W, H), rb = ref.size, core_box(ref, alpha_min)
    else:
        (W, H), rb = ref
    sb = core_box(im, alpha_min)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if not rb or not sb:
        return out
    rw, rh = rb[2] - rb[0], rb[3] - rb[1]
    sw, sh = sb[2] - sb[0], sb[3] - sb[1]
    scale = float(np.sqrt((rw / max(1, sw)) * (rh / max(1, sh))))
    full = im.getbbox()
    crop = im.crop(full)
    nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    small = resize_rgba(crop, (nw, nh))
    # line up the body: bottom edge and centre x of the scaled body on ref's
    bx0 = (sb[0] - full[0]) * scale
    bx1 = (sb[2] - full[0]) * scale
    by1 = (sb[3] - full[1]) * scale
    ox = round((rb[0] + rb[2]) / 2.0 - (bx0 + bx1) / 2.0)
    oy = round(rb[3] - by1)
    out.paste(small, (ox, oy), small)
    return out


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
