#!/usr/bin/env python3
"""Clean and normalize a squared 3x3 Character Bible into the live lock sheet (design/art-bible-character.md).

Order: plate remap (imglib.key.remap_plate) -> split thirds -> per cell: 2x Lanczos, SCUNet real_psnr,
G1 shrink, guided smooth, plate flatten -> 4x -> figure bbox -> full bodies to (cell - 2*margin) tall, bust keeps
its crop, centred on the 4 px grid -> trimmed-mean 4x4 rebuild to the cell. Prints a per-cell scale + bbox table
and flags (edge-touching source figure, width overflow). --no-denoise runs the rebuild only (no torch).

  python tools/media.py bible-normalize SRC DEST
  python tools/media.py bible-normalize SRC DEST --debug _out/bible_dbg --cache _cache/bible
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import cv2  # noqa: E402
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

from imglib import imgio, key  # noqa: E402

MAG = np.array([255, 0, 255], np.uint8)
BUST = 4
NAMES = ("up-left", "up", "up-right", "left", "bust", "right", "down-left", "down", "down-right")

def plate(a: np.ndarray) -> np.ndarray:
    """Near-#FF00FF after resampling (L1 < 90)."""
    return np.abs(a.astype(int) - MAG.astype(int)).sum(-1) < 90

def lz(a: np.ndarray, s: int) -> np.ndarray:
    return cv2.resize(a, (a.shape[1] * s, a.shape[0] * s), interpolation=cv2.INTER_LANCZOS4)

def _coh(a: np.ndarray, sig: float) -> np.ndarray:
    y = cv2.cvtColor(a, cv2.COLOR_RGB2GRAY).astype(np.float32)
    gx, gy = cv2.Sobel(y, cv2.CV_32F, 1, 0), cv2.Sobel(y, cv2.CV_32F, 0, 1)
    j = [cv2.GaussianBlur(v, (0, 0), sig) for v in (gx * gx, gy * gy, gx * gy)]
    tr = j[0] + j[1]
    return np.sqrt((j[0] - j[1]) ** 2 + 4 * j[2] ** 2) / (tr + 1e-3), tr

def g1(up: np.ndarray, base: np.ndarray, f: int, tc: float = 4, ti: float = 14) -> np.ndarray:
    """Base + soft-shrunk high band of (up - base); threshold tc on structured detail, ti on random texture."""
    d = up.astype(np.float32) - base.astype(np.float32)
    hi = d - cv2.GaussianBlur(d, (0, 0), 2 * f)
    c, tr = _coh(up, 1.5 * f)
    w = np.clip(np.maximum(c, np.clip(tr / (400 / f / f), 0, 1)), 0, 1)[..., None]
    t = tc + (ti - tc) * (1 - w)
    mag = np.sqrt((hi ** 2).sum(-1, keepdims=True))
    return (base + hi * np.maximum(mag - t, 0) / np.maximum(mag, 1e-6)).round().clip(0, 255).astype(np.uint8)

def _gf(i: np.ndarray, p: np.ndarray, r: int, eps: float) -> np.ndarray:
    f = lambda x: cv2.boxFilter(x, -1, (2 * r + 1, 2 * r + 1))  # noqa: E731
    mi, mp = f(i), f(p)
    a = (f(i * p) - mi * mp) / (f(i * i) - mi * mi + eps)
    return f(a) * i + f(mp - a * mi)

def guided_smooth(img: np.ndarray, ref: np.ndarray, r: int = 4, eps: float = 0.01, gain: float = 0.7) -> np.ndarray:
    """Guided filter weighted gain*clip((0.8-coh)/0.2)*(1-DoG feature mask 6..16); plate filled from nearest figure."""
    pm = plate(ref)
    c, _ = _coh(ref, 1.5)
    y = cv2.cvtColor(ref, cv2.COLOR_RGB2YCrCb)[..., 0].astype(np.float32)
    dog = np.abs(cv2.GaussianBlur(y, (0, 0), 0.7) - cv2.GaussianBlur(y, (0, 0), 2.0))
    feat = cv2.GaussianBlur(np.clip((dog - 6) / 10, 0, 1), (0, 0), 0.8)
    f = img.copy()
    _, lab = cv2.distanceTransformWithLabels(pm.astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    m = np.zeros((lab.max() + 1, 3), np.uint8)
    m[lab[~pm]] = img[~pm]
    f[pm] = m[lab[pm]]
    x = f.astype(np.float32) / 255
    g = cv2.cvtColor(f, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255
    s = np.stack([_gf(g, x[..., k], r, eps) for k in range(3)], -1) * 255
    w = (gain * np.clip((0.8 - c) / 0.2, 0, 1) * (1 - feat))[..., None]
    o = (img * (1 - w) + s * w).round().clip(0, 255).astype(np.uint8)
    o[pm] = MAG
    return o

def denoise_cell(net, cell: np.ndarray, dbg=None) -> np.ndarray:
    """Cell -> 4x denoised (D2: denoise at 2x)."""
    from imglib import scunet
    s2 = lz(cell, 2)
    s2[plate(s2)] = MAG
    b2 = scunet.denoise(net, s2)
    g2 = g1(s2, b2, 2)
    g2[plate(s2)] = MAG
    d2 = guided_smooth(g2, s2)
    if dbg:
        for n, a in (("1_lanczos2x", s2), ("2_scunet", b2), ("3_g1", g2), ("4_smooth", d2)):
            dbg(n, a)
    return lz(d2, 2)

def figure_box(a4: np.ndarray, tol: int = 16):
    """Main connected component plus small parts inside its box (+tol). Returns x0, y0, x1, y1, mask."""
    fg = (~plate(a4)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg, 8)
    if n < 2:
        return None
    j = 1 + st[1:, 4].argmax()
    x, y, w, h = st[j, :4]
    keep = lab == j
    for q in range(1, n):
        qx, qy, qw, qh = st[q, :4]
        if q != j and qx >= x - tol and qy >= y - tol and qx + qw <= x + w + tol and qy + qh <= y + h + tol:
            keep |= lab == q
    ys, xs = np.where(keep)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, keep

def place(a4: np.ndarray, box, size: int, height: int | None):
    """Figure on a size x size plate. height=None keeps position (bust). Returns canvas, scale, width, overflow."""
    x0, y0, x1, y1, keep = box
    out = np.full((size, size, 3), MAG, np.uint8)
    if height is None:
        sub = keep[y0:y1, x0:x1]
        out[y0:y1, x0:x1][sub] = a4[y0:y1, x0:x1][sub]
        return out, 1.0, x1 - x0, False
    fig = a4[y0:y1, x0:x1].astype(np.float32)
    m = keep[y0:y1, x0:x1].astype(np.float32)
    sc = height / fig.shape[0]
    w = round(fig.shape[1] * sc)
    over = w > size
    if over:  # flag, never crop: fit the width instead
        sc, w = size / fig.shape[1], size
        height = round(fig.shape[0] * sc)
    up = sc >= 1
    num = cv2.resize(fig * m[..., None], (w, height), interpolation=cv2.INTER_LANCZOS4 if up else cv2.INTER_AREA)
    den = cv2.resize(m, (w, height), interpolation=cv2.INTER_LINEAR if up else cv2.INTER_AREA)
    f = (num / np.maximum(den, 1e-6)[..., None]).round().clip(0, 255).astype(np.uint8)
    oy = (size - height) // 2
    oy -= oy % 4
    ox = (size - w) // 2
    ox -= ox % 4
    t = np.full(f.shape, MAG, np.uint8)
    t[den >= 0.5] = f[den >= 0.5]
    out[oy:oy + height, ox:ox + w] = t
    return out, sc, w // 4, over

def rebuild(a4: np.ndarray, p: int = 4, trim: float = 0.25) -> np.ndarray:
    """p x p blocks -> one pixel: trimmed mean by luma. A block with any figure pixel is figure (mean of its figure pixels)."""
    h, w = a4.shape[:2]
    b = a4.reshape(h // p, p, w // p, p, 3).transpose(0, 2, 1, 3, 4).reshape(h // p, w // p, p * p, 3).astype(np.float32)
    isp = np.all(b == MAG, -1)
    luma = b @ np.array([0.299, 0.587, 0.114], np.float32)
    k = int(p * p * trim)
    order = np.argsort(luma, axis=2)
    lo = np.take_along_axis(b, order[..., k:p * p - k, None], 2).mean(2)
    mixed = isp.any(2) & ~isp.all(2)
    for yy, xx in zip(*np.where(mixed)):
        px = b[yy, xx][~isp[yy, xx]]
        kk = int(len(px) * trim)
        px = px[np.argsort(px @ np.array([0.299, 0.587, 0.114], np.float32))][kk:len(px) - kk]
        lo[yy, xx] = px.mean(0)
    lo = lo.round().astype(np.uint8)
    lo[isp.all(2)] = MAG
    return lo

def run(src: Path, dest: Path, cell: int, margin: int, denoise: bool, debug: Path | None, cache: Path | None) -> int:
    im = imgio.load(src)
    w, h = im.size
    if w != h or w % 3:
        print(f"error: {src.name} is {w}x{h}; square the Bible on its lattice first (art-bible-character.md)", file=sys.stderr)
        return 2
    rgb = np.asarray(key.remap_plate(im)[0].convert("RGB"))
    net = None
    if denoise:
        from imglib import scunet
        net = scunet.load()
    c3 = w // 3
    C = cell * 4
    sheet = np.zeros((3 * cell, 3 * cell, 3), np.uint8)
    print(f"{'cell':10} {'scale':>6}  bbox(x0,y0,x1,y1)     top bot  width  flags")
    flags = 0
    for i in range(9):
        r, k = divmod(i, 3)
        s = rgb[r * c3:(r + 1) * c3, k * c3:(k + 1) * c3]
        if c3 != cell:
            s = cv2.resize(s, (cell, cell), interpolation=cv2.INTER_AREA if c3 > cell else cv2.INTER_LANCZOS4)
            s[plate(s)] = MAG
        dbg = None
        if debug:
            debug.mkdir(parents=True, exist_ok=True)
            dbg = lambda n, a, i=i: Image.fromarray(a).save(debug / f"c{i}_{n}.png")  # noqa: E731
            dbg("0_cell", s)
        ref = lz(s, 4)
        ref[plate(ref)] = MAG
        if net is None:
            a4 = ref
        else:
            cp = cache / (hashlib.sha256(s.tobytes()).hexdigest()[:16] + ".png") if cache else None
            if cp and cp.is_file():
                a4 = np.asarray(Image.open(cp).convert("RGB")).copy()
            else:
                a4 = denoise_cell(net, s, dbg)
                if cp:
                    cp.parent.mkdir(parents=True, exist_ok=True)
                    Image.fromarray(a4).save(cp)
            a4[plate(ref)] = MAG
        box = figure_box(ref)
        if box is None:
            print(f"error: cell {NAMES[i]} has no figure", file=sys.stderr)
            return 1
        sm = (~plate(s))
        ys, xs = np.where(sm)
        fl = []
        if ys.min() == 0 or xs.min() == 0 or ys.max() == cell - 1 or xs.max() == cell - 1:
            fl.append("edge-touch")
        canvas, sc, fw, over = place(a4, box, C, None if i == BUST else (cell - 2 * margin) * 4)
        if over:
            fl.append("width-overflow(fit-to-width)")
        if dbg:
            dbg("5_placed4x", canvas)
        out = rebuild(canvas)
        sheet[r * cell:(r + 1) * cell, k * cell:(k + 1) * cell] = out
        ys, xs = np.where(~np.all(out == MAG, -1))
        flags += bool(fl)
        print(f"{NAMES[i]:10} {sc:6.3f}  ({xs.min()},{ys.min()},{xs.max()},{ys.max()}){'':6} {ys.min():>3} {cell - 1 - ys.max():>3}  "
              f"{xs.max() - xs.min() + 1:>5}  {' '.join(fl)}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(dest)
    print(f"wrote {dest} ({3 * cell}x{3 * cell}) flagged_cells={flags}")
    return 0

def main() -> None:
    p = argparse.ArgumentParser(description="Clean JPEG damage and normalize a squared 3x3 Bible into the live lock sheet.",
                                epilog="No --root: explicit-path tool, exempt by design (paths are arguments).")
    p.add_argument("src", type=Path, help="Squared 3x3 Bible (raw archive copy, any square size divisible by 3)")
    p.add_argument("dest", type=Path, help="Output PNG (3 x --cell square)")
    p.add_argument("--cell", type=int, default=256, help="Output cell size in px (default 256)")
    p.add_argument("--margin", type=int, default=4, help="Plate px above and below every full-body figure (default 4)")
    p.add_argument("--no-denoise", action="store_true", help="Skip SCUNet/G1/smooth: remap, normalize, rebuild only (no torch)")
    p.add_argument("--debug", type=Path, default=None, help="Dump per-cell stage PNGs into this dir")
    p.add_argument("--cache", type=Path, default=None, help="Reuse denoised 4x cells from this dir (keyed by cell hash)")
    a = p.parse_args()
    if not a.src.is_file():
        p.error(f"missing {a.src}")
    if a.cell % 1 or a.cell < 32 or not 0 <= a.margin < a.cell // 4:
        p.error("bad --cell/--margin")
    sys.exit(run(a.src, a.dest, a.cell, a.margin, not a.no_denoise, a.debug, a.cache))

if __name__ == "__main__":
    main()
