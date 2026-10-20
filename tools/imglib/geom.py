"""Geometry helpers: bbox, crop, fit, scale, flip, grid split.

Nearest-neighbour is only for sizing up. Sizing down is one premultiplied box (area) average.
The hard-edge rule is alpha_policy, applied once at output scale.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

def _box_down(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Premultiplied area average (float): each output pixel is the exact mean of its fractional footprint, so alpha
    is true coverage and invisible colour never bleeds into the edge."""
    a = np.asarray(im.convert("RGBA"), np.float32) / 255.0
    prem = a.copy()
    prem[..., :3] *= prem[..., 3:]
    ch = [np.asarray(Image.fromarray(np.ascontiguousarray(prem[..., c])).resize(size, Image.Resampling.BOX), np.float32)
          for c in range(4)]
    out = np.dstack(ch)
    al = out[..., 3:]
    out[..., :3] = np.where(al > 1e-4, out[..., :3] / np.maximum(al, 1e-4), 0.0)
    out = np.clip(np.rint(out * 255.0), 0, 255).astype(np.uint8)
    out[out[..., 3] == 0] = 0
    return Image.fromarray(out, "RGBA")

def resize_rgba(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale an RGBA image: nearest when both sides grow, otherwise ONE premultiplied box (area) average. Any hard
    edge rule is applied afterwards, once, by alpha_policy."""
    im = im.convert("RGBA")
    size = (max(1, int(size[0])), max(1, int(size[1])))
    if size == im.size:
        return im
    if size[0] >= im.size[0] and size[1] >= im.size[1]:
        return im.resize(size, Image.Resampling.NEAREST)
    return _box_down(im, size)

POLICIES = ("soft", "crisp", "hard")
CRISP_LO, CRISP_HI = 0.12, 0.88  # crisp: coverage under/over these goes clear/opaque; the anti-aliased middle stays

def alpha_policy(im: Image.Image, policy: str = "crisp") -> Image.Image:
    """The one final alpha rule, at output scale. soft: coverage as is (glows, fx). crisp: near-clear and near-opaque
    coverage snaps, the middle (edge anti-aliasing) stays. hard: one threshold at half coverage (1-bit sprites)."""
    if policy not in POLICIES:
        raise ValueError(f"alpha policy {policy!r} not in {POLICIES}")
    o = np.array(im.convert("RGBA"))
    if policy != "soft":
        a = o[..., 3].astype(np.float32) / 255.0
        if policy == "hard":
            a = (a >= 0.5).astype(np.float32)
        else:
            a = np.where(a < CRISP_LO, 0.0, np.where(a > CRISP_HI, 1.0, (a - CRISP_LO) / (CRISP_HI - CRISP_LO)))
        o[..., 3] = np.rint(a * 255.0).astype(np.uint8)
    o[o[..., 3] == 0] = 0
    return Image.fromarray(o, "RGBA")

def detect_grid(im: Image.Image, lo: float = 2.0, hi: float = 16.0):
    """(pitch, phase x, phase y, confidence) of a pixel-art grid from luma-gradient profiles (a fractional comb, as
    pixfix does); confidence is the comb's share of the gradient energy in both axes (about 0.5+ is a real grid)."""
    g = np.asarray(im.convert("L"), np.float32)
    best = (0.0, 0.0, 0.0, 0.0)
    prof = [np.abs(np.diff(g, axis=1)).sum(0), np.abs(np.diff(g, axis=0)).sum(1)]
    prof = [p - p.mean() for p in prof]
    for pitch in np.arange(lo, hi, 0.02):
        r = []
        for p in prof:
            z = (p * np.exp(2j * np.pi * np.arange(len(p)) / pitch)).sum()
            r.append((abs(z) / max(np.abs(p).sum(), 1e-6), (np.angle(z) * pitch / (2 * np.pi)) % pitch))
        c = min(r[0][0], r[1][0])
        if c > best[3]:
            best = (float(pitch), float(r[0][1]), float(r[1][1]), float(c))
    return best

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

    Nearest when sizing up, premultiplied box average when sizing down. The other side follows the aspect
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

GRID_TOL = 0.015  # a detected grid sets the scale only when its pitch is this close to the fit (body size kept)

def fit_like(im: Image.Image, ref, alpha_min: int = 128, resize=None, grid=None) -> Image.Image:
    """Place a keyed still on a canvas exactly like `ref` (the live still it replaces): same canvas size, the solid
    body scaled to the size of ref's body and lined up on ref's bottom edge and centre x. No recentring and no
    padding of its own. ref may also be a recorded geometry ((W, H), body box), so a re-run does not fit against its
    own output. grid=(pitch, phase x, phase y) from detect_grid: when the pitch is within GRID_TOL of the fit's source px
    per output px, that pitch is the scale and the crop starts on a grid line, so each output pixel is one cell."""
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
    if grid and abs(grid[0] * scale - 1.0) <= GRID_TOL:
        pitch, gx, gy = grid
        scale = 1.0 / pitch
        x0 = gx + np.floor((full[0] - gx) / pitch) * pitch
        y0 = gy + np.floor((full[1] - gy) / pitch) * pitch
        nw = int(np.ceil((full[2] - x0) / pitch))
        nh = int(np.ceil((full[3] - y0) / pitch))
        crop = im.transform((max(1, round(nw * pitch)), max(1, round(nh * pitch))), Image.Transform.AFFINE,
                            (1, 0, x0, 0, 1, y0), Image.Resampling.NEAREST)
        full = (x0, y0, x0 + nw * pitch, y0 + nh * pitch)
    else:
        crop = im.crop(full)
        nw, nh = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    small = (resize or resize_rgba)(crop, (nw, nh))
    # line up the body: bottom edge and centre x of the scaled body on ref's
    bx0 = (sb[0] - full[0]) * scale
    bx1 = (sb[2] - full[0]) * scale
    by1 = (sb[3] - full[1]) * scale
    ox = round((rb[0] + rb[2]) / 2.0 - (bx0 + bx1) / 2.0)
    oy = round(rb[3] - by1)
    out.paste(small, (ox, oy))  # no mask: pasting with alpha as its own mask squares partial alpha
    return out

def flip(im: Image.Image, horizontal: bool = True) -> Image.Image:
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT if horizontal else Image.Transpose.FLIP_TOP_BOTTOM)

def grid_split(im: Image.Image, cols: int, rows: int) -> list[Image.Image]:
    """Equal cells, row-major."""
    cw, ch = im.width // cols, im.height // rows
    return [im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r in range(rows) for c in range(cols)]

def fit_box(im, canvas: int, pad: int, *, resample=None, to_int=round, oy=None, empty_exit: str = "", alpha_min: int = 24):
    """Crop to the opaque box, pad it, scale to fit `canvas` square, paste centred (oy(nh) sets the y offset).

    resample overrides the scale rule. Otherwise resize_rgba (nearest up, premultiplied box down). to_int turns the scaled size into pixels (round or int). empty_exit raises
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
    padded.paste(cropped, (pad, pad))
    scale = min(canvas / padded.size[0], canvas / padded.size[1])
    nw = max(1, to_int(padded.size[0] * scale))
    nh = max(1, to_int(padded.size[1] * scale))
    if resample is None:
        resized = resize_rgba(padded, (nw, nh))
    else:
        resized = padded.resize((nw, nh), resample)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2 if oy is None else oy(nh)))
    return out
