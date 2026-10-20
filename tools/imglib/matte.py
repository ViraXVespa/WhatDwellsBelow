"""Chroma-plate keyer: clean plate, trimap, one alpha solve, decontaminate. OpenCV is required.

Order (each stage can dump a debug PNG through `debug=dir`):
  1 plate    border pixels on the plate hue are clustered (YCrCb chroma, median + MAD); the sure plate is the border
             flood within noise of the LOCAL plate; B(x) = that plate inpainted under the subject and smoothed
             (a per-pixel clean plate, so drift and gradients such as B 153..243 are followed)
  2 trimap   background = sure plate (border flood plus enclosed plate pockets); unknown = the edge band (`band`
             px) plus plate-tinted regions (magenta excess >= TINT of the plate's) reaching the plate or holding a
             near-plate seed, except deep inside (DEEP x band); foreground = the rest
  3 alpha    one solve over the unknown band: projection of I - B onto F - B (F = the paint behind the edge,
             carried outward), raised to the least alpha that keeps F in gamut (colour-to-alpha). Only alpha within
             the plate's own noise goes to 0. No snapping, no thresholds near opaque.
  4 colour   decontaminate F = (I - (1 - a) B) / a; faint pixels lean to the carried paint colour; magenta excess
             on mixed pixels and the edge band limited to the paint's own (spill)
Full resolution only. Shrinking (premultiplied box) and the alpha policy are geom's job, after this.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

try:
    import cv2
except ImportError as exc:  # pragma: no cover
    raise SystemExit("OpenCV is required for keying: python -m pip install -r tools/requirements.txt") from exc

PLATE_HUE = (275.0, 350.0)  # degrees; Imagine's magenta drifts from violet to pink
NOISE_K = 3.0  # plate = within NOISE_K sigma of B(x)
MIN_T = 8.0  # floor of the plate distance threshold (YCrCb units)
TINT = 0.15  # plate-tinted: magenta excess at least this share of the local plate's
RING_K = 2.0  # noise floor multiplier within 3 px of solid paint, outside tinted (glow) regions
POCKET = 4e-3  # a shadowed-plate patch at most this share of the picture is plate (an armpit), larger is paint
DEEP = 6  # pixels farther than DEEP x band from the plate are paint (pink or violet robes stay)

def _ycc(rgb: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(np.ascontiguousarray(rgb.astype(np.uint8)), cv2.COLOR_RGB2YCrCb).astype(np.float32)

def excess(c: np.ndarray) -> np.ndarray:
    """Magenta excess min(R,B)-G of float RGB."""
    return np.minimum(c[..., 0], c[..., 2]) - c[..., 1]

def plate_colour(rgb: np.ndarray, ring: int = 6):
    """(plate RGB tuple, chroma spread) from the border cluster on the plate hue, or (None, 0) when there is none."""
    s = np.concatenate([rgb[:ring].reshape(-1, 3), rgb[-ring:].reshape(-1, 3),
                        rgb[:, :ring].reshape(-1, 3), rgb[:, -ring:].reshape(-1, 3)])
    hsv = cv2.cvtColor(s.reshape(-1, 1, 3), cv2.COLOR_RGB2HSV_FULL).reshape(-1, 3).astype(np.float32)
    hue = hsv[:, 0] * 360.0 / 256.0
    ok = (hue >= PLATE_HUE[0]) & (hue <= PLATE_HUE[1]) & (hsv[:, 1] >= 110) & (hsv[:, 2] >= 90)
    if ok.sum() < max(16, 0.05 * len(s)):
        return None, 0.0
    c = _ycc(s[ok].reshape(-1, 1, 3)).reshape(-1, 3)[:, 1:]
    c0 = np.median(c, axis=0)
    d = np.linalg.norm(c - c0, axis=1)
    keep = d <= max(6.0, 4.0 * float(np.median(d)))  # one cluster: drop border paint that only shares the hue
    pick = s[ok][keep]
    return tuple(int(round(v)) for v in np.median(pick, axis=0)), float(np.percentile(d[keep], 95))

def _border_flood(accept: np.ndarray) -> np.ndarray:
    n, lab = cv2.connectedComponents(accept.astype(np.uint8), connectivity=8)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    return np.isin(lab, edge[edge > 0])

def clean_plate(rgb: np.ndarray, known: np.ndarray) -> np.ndarray:
    """B(x): the plate colour everywhere, from the `known` plate pixels, inpainted under the subject (at quarter size,
    plates are smooth) and blurred. float32 H x W x 3."""
    h, w = known.shape
    f = max(1, min(h, w) // 256)
    small = cv2.resize(rgb, (max(1, w // f), max(1, h // f)), interpolation=cv2.INTER_AREA)
    ks = cv2.resize(known.astype(np.uint8), small.shape[1::-1], interpolation=cv2.INTER_NEAREST).astype(bool)
    ks = cv2.erode(ks.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) | (ks & ~cv2.erode(np.ones_like(ks, np.uint8), np.ones((3, 3), np.uint8)).astype(bool))
    if not ks.any():
        ks = known[::f, ::f][: small.shape[0], : small.shape[1]]
    filled = cv2.inpaint(np.ascontiguousarray(small), (~ks).astype(np.uint8), 5, cv2.INPAINT_TELEA)
    filled = cv2.GaussianBlur(filled.astype(np.float32), (0, 0), 3.0)
    return cv2.resize(filled, (w, h), interpolation=cv2.INTER_LINEAR)

def _plate_dist(rgb: np.ndarray, B: np.ndarray) -> np.ndarray:
    """Chroma distance to B(x) in YCrCb, luma at half weight (dark maroon paint is not plate)."""
    d = _ycc(rgb) - _ycc(np.clip(B, 0, 255))
    return np.sqrt((d[..., 1:] ** 2).sum(-1) + 0.25 * d[..., 0] ** 2)

def background(rgb: np.ndarray, plate, spread: float, clear=None):
    """(bg mask, B(x), noise sigma). Two rounds: a global plate seeds B(x), then the flood follows the local plate."""
    B = np.broadcast_to(np.array(plate, np.float32), rgb.shape).copy()
    t = max(MIN_T, 1.5 * spread)
    bg = None
    for _ in range(2):
        d = _plate_dist(rgb, B)
        flat = d <= t
        if clear is not None:
            flat |= clear
        bg = _border_flood(flat)
        # enclosed plate pockets (between hair strands, inside a ring)
        n, lab, st, _ = cv2.connectedComponentsWithStats((flat & ~bg).astype(np.uint8), connectivity=8)
        keep = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] >= 6]
        if keep:
            bg |= np.isin(lab, keep)
        B = clean_plate(rgb, bg)
        inner = bg & ~cv2.dilate((~bg).astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
        res = _plate_dist(rgb, B)[inner]
        sig = float(np.percentile(res, 68)) if res.size > 64 else t / NOISE_K
        t = max(MIN_T, NOISE_K * sig)
    return bg, B, t / NOISE_K

def _grow_from(accept: np.ndarray, seed: np.ndarray) -> np.ndarray:
    """Components of `accept` touching `seed` (8-connected, one px dilation)."""
    n, lab = cv2.connectedComponents(accept.astype(np.uint8), connectivity=8)
    hit = np.unique(lab[cv2.dilate(seed.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & accept])
    return np.isin(lab, hit[hit > 0])

def edge_frame(mask: np.ndarray, depth: int = 3) -> np.ndarray:
    """Crop seams: 1-2 px lines of paint along the picture's own border; art that really reaches the border is thick
    there and survives a 5 px opening."""
    h, w = mask.shape
    if h < 4 * depth or w < 4 * depth:
        return np.zeros_like(mask)
    k = np.ones((5, 5), np.uint8)
    # outside the picture counts as clear, or a strip along the border would survive the erosion
    thick = cv2.dilate(cv2.erode(mask.astype(np.uint8), k, borderType=cv2.BORDER_CONSTANT, borderValue=0), k).astype(bool)
    edge = np.zeros_like(mask)
    edge[:depth], edge[-depth:], edge[:, :depth], edge[:, -depth:] = True, True, True, True
    return mask & edge & ~thick

def colour_field(p: np.ndarray, ref: np.ndarray, scales=(1.5, 4, 12, 36)) -> np.ndarray:
    """Colour of `ref` pixels carried smoothly outward (normalised Gaussian blur summed over scales): near the rim the
    paint right behind dominates, further out the wider art colour."""
    w = np.zeros(p.shape[:2], np.float32)
    acc = np.zeros(p.shape, np.float32)
    m = ref.astype(np.float32)
    for sg in scales:
        k = int(sg * 3) | 1
        w += cv2.GaussianBlur(m, (k, k), sg)
        acc += cv2.GaussianBlur(p * m[..., None], (k, k), sg)
    return acc / np.maximum(w[..., None], 1e-6)

def solve_alpha(p: np.ndarray, B: np.ndarray, F: np.ndarray, sig, ) -> np.ndarray:
    """One alpha for I = a F + (1 - a) B: the projection onto B -> F, raised to the least alpha that keeps the unmixed
    colour in 0..255; alpha inside the plate's noise (NOISE_K sigma along B -> F) is 0."""
    dp = p - B
    fb = F - B
    gl = np.maximum((fb * fb).sum(-1), 1.0)
    a_line = (dp * fb).sum(-1) / gl
    lim = np.where(dp > 0, 255.0 - B, B)
    a_need = (np.abs(dp) / np.maximum(lim, 1.0)).max(-1)
    a = np.clip(np.maximum(a_line, a_need), 0.0, 1.0)
    floor = np.clip(NOISE_K * sig * 1.6 / np.sqrt(gl), 0.0, 0.3)  # YCrCb chroma units are ~0.6 of RGB
    return np.clip((a - floor) / np.maximum(1.0 - floor, 1e-3), 0.0, 1.0)

def despill(rgb: np.ndarray, F: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Limit magenta excess min(R,B)-G in `mask` to the paint colour's own excess."""
    out = rgb.copy()
    cut = np.clip(excess(rgb) - np.maximum(excess(F), 0.0), 0.0, None) * mask
    out[..., 0] -= cut
    out[..., 2] -= cut
    return np.clip(out, 0, 255)

def key(im: Image.Image, band: int | None = None, debug: str | Path | None = None, name: str = "key", plate=None):
    """Key one opaque plate picture at full resolution. Returns (RGBA image, stats). `plate` pins the plate RGB.
    A picture with no plate on its border (wood, an already cut sprite) returns unchanged."""
    src = im.convert("RGBA")
    arr = np.array(src)
    rgb = np.ascontiguousarray(arr[..., :3])
    if plate is None:
        plate, spread = plate_colour(rgb)
    else:
        plate, spread = tuple(int(v) for v in plate), 2.0
    if plate is None:
        return src, {"plate": None}
    if band is None:
        band = max(3, min(rgb.shape[:2]) // 120)
    bg, B, sig = background(rgb, plate, spread, clear=arr[..., 3] < 8)
    p = rgb.astype(np.float32)
    dist = cv2.distanceTransform((~bg).astype(np.uint8), cv2.DIST_L2, 5)
    # plate-tinted: magenta excess of the plate's order (a mix with the plate: glow, veil, shadowed pocket)
    tinted = ~bg & (excess(p) >= TINT * np.maximum(excess(B), 1.0))
    deep = dist > DEEP * band  # far inside: paint, even when it is pink or violet (a robe)
    # unknown = the edge band, plus tinted regions that reach the plate or hold a near-plate seed (armpit pocket)
    seed = bg | (tinted & (_plate_dist(rgb, B) <= 4.0 * NOISE_K * sig))
    cand = ~bg & ~deep & ((dist <= band) | tinted)
    unknown = _grow_from(cand, seed)
    # deep plate pockets (between an arm and the body): tinted patches holding a pixel close to the plate
    # (or, when the patch is small, holding shadowed plate: half the plate's magenta excess)
    unknown |= _grow_from(tinted, tinted & (_plate_dist(rgb, B) <= 2.0 * NOISE_K * sig))
    n, lab, st, _ = cv2.connectedComponentsWithStats(tinted.astype(np.uint8), connectivity=8)
    shade = tinted & (excess(p) >= 0.5 * excess(B))
    small = [i for i in np.unique(lab[shade]) if i and st[i, cv2.CC_STAT_AREA] <= max(64, int(POCKET * lab.size))]
    if small:
        unknown |= np.isin(lab, small)
    fg = ~bg & ~unknown
    # paint references: untinted pixels off the plate, or deep paint
    ref = ~bg & ~unknown & (~tinted | deep)
    ref |= ~bg & ~tinted & (_plate_dist(rgb, B) > 12.0 * max(sig, 1.0))  # a thin bright line has no inside
    F0 = colour_field(p, ref if ref.any() else ~bg)
    alpha = fg.astype(np.float32)
    if unknown.any():
        # JPEG ringing beside hard paint is well above the flat plate's noise: twice the floor there (not in glows)
        ring = (cv2.distanceTransform((~fg).astype(np.uint8), cv2.DIST_L2, 5) <= 3) & ~tinted
        alpha[unknown] = solve_alpha(p[unknown], B[unknown], F0[unknown], np.where(ring, RING_K * sig, sig)[unknown])
        # specks: alpha islands that reach neither paint nor half coverage
        keep = _grow_from(alpha > 0, fg | (alpha >= 0.5))
        alpha[~keep] = 0.0
    a3 = alpha[..., None]
    col = np.clip((p - (1.0 - a3) * B) / np.maximum(a3, 1e-3), 0, 255)
    w = np.clip(1.0 - alpha / 0.25, 0.0, 1.0)[..., None]  # a faint pixel's own colour is amplified noise
    col = w * F0 + (1 - w) * col
    # spill: every mixed pixel and the edge band keep no more magenta excess than the paint (a glow whose colour is
    # lighter than the carried paint unmixes violet otherwise: the plate's blue cannot be told from the glow's)
    col = despill(col, F0, unknown | (~bg & (dist <= band + 2)))
    col = np.where(fg[..., None], p, col)
    a8 = np.rint(alpha * arr[..., 3]).astype(np.uint8)
    out = np.zeros_like(arr)
    out[..., :3] = np.rint(col).astype(np.uint8)
    a8[edge_frame(a8 > 0)] = 0
    out[..., 3] = a8
    out[a8 == 0] = 0
    stats = {"plate": "#%02X%02X%02X" % plate, "spread": round(spread, 1), "sigma": round(sig, 2), "band": band,
             "bg": int(bg.sum()), "unknown": int(unknown.sum()), "fg": int(fg.sum())}
    if debug:
        dd = Path(debug)
        dd.mkdir(parents=True, exist_ok=True)
        Image.fromarray(np.clip(B, 0, 255).astype(np.uint8)).save(dd / f"{name}-1-plate.png")
        tri = np.zeros(rgb.shape, np.uint8)
        tri[fg] = 255
        tri[unknown] = 128
        Image.fromarray(tri).save(dd / f"{name}-2-trimap.png")
        Image.fromarray(a8).save(dd / f"{name}-3-alpha.png")
        Image.fromarray(out).save(dd / f"{name}-4-keyed.png")
    return Image.fromarray(out, "RGBA"), stats
