"""Staged chroma-plate keyer. OpenCV is required.

Stages (each can dump a debug PNG through `debug=dir`):
  1 denoise   chroma-only median of the YCrCb planes, used to classify (output keeps the drawn RGB)
  2 plate     plate colour per image: median of border pixels near the plate hue (handles drift such as 242,5,181)
  3 trimap    background = border flood through plate-like chroma + enclosed exact-plate pockets;
              ring = solid pixels within `ring` px of background; glow = plate-tinted pixels connected to
              background that are not plate (translucent veil over the plate, incl. a red glow on a pink
              plate: near-plate bands touching the background are not plate pockets); solid = the rest
  4 unmix     ring: largest alpha whose colour C = P + (p-P)/a keeps the paint's magenta excess.
              glow: G = local mean colour of the art behind it; alpha = projection onto the P->G line,
              colour = unmixed brightness with G's chroma (pixels far off that line use the ring rule)
  5 despill   magenta excess min(R,B)-G limited to the paint's own (ring, glow, edge paint), then in
              YCrCb the chroma along the plate's direction beyond the art's is removed (glow, faint ring)
Solid pixels stay opaque with their drawn RGB. Nothing outside the measured mix gets alpha (no halo).
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

try:
    import cv2
except ImportError as exc:  # pragma: no cover
    raise SystemExit("OpenCV is required for keying: python -m pip install -r tools/requirements.txt") from exc

PLATE_HUE = (275.0, 350.0)


def _ycc(rgb: np.ndarray) -> np.ndarray:
    return cv2.cvtColor(rgb, cv2.COLOR_RGB2YCrCb).astype(np.float32)


def denoise(rgb: np.ndarray, k: int = 3) -> np.ndarray:
    """YCrCb with Cr/Cb median-filtered (k px); luma untouched."""
    ycc = cv2.cvtColor(rgb, cv2.COLOR_RGB2YCrCb)
    for c in (1, 2):
        ycc[..., c] = cv2.medianBlur(np.ascontiguousarray(ycc[..., c]), k)
    return ycc.astype(np.float32)


def plate_colour(rgb: np.ndarray, ring: int = 6):
    """(plate RGB tuple, chroma spread) from border pixels on the plate hue, or (None, 0) when no plate."""
    h, w = rgb.shape[:2]
    s = np.concatenate([rgb[:ring].reshape(-1, 3), rgb[-ring:].reshape(-1, 3),
                        rgb[:, :ring].reshape(-1, 3), rgb[:, -ring:].reshape(-1, 3)])
    hsv = cv2.cvtColor(s.reshape(-1, 1, 3), cv2.COLOR_RGB2HSV_FULL).reshape(-1, 3).astype(np.float32)
    hue = hsv[:, 0] * 360.0 / 256.0
    ok = (hue >= PLATE_HUE[0]) & (hue <= PLATE_HUE[1]) & (hsv[:, 1] >= 110) & (hsv[:, 2] >= 90)
    if ok.sum() < max(16, 0.05 * len(s)):
        return None, 0.0
    pick = s[ok]
    plate = np.median(pick, axis=0)
    ycc = _ycc(pick.reshape(-1, 1, 3)).reshape(-1, 3)
    c0 = np.median(ycc[:, 1:], axis=0)
    spread = float(np.percentile(np.linalg.norm(ycc[:, 1:] - c0, axis=1), 95))
    return tuple(int(round(v)) for v in plate), spread


def _flood(accept: np.ndarray) -> np.ndarray:
    n, lab = cv2.connectedComponents(accept.astype(np.uint8), connectivity=8)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    edge = edge[edge > 0]
    return np.isin(lab, edge)


def _nearest(p: np.ndarray, mask: np.ndarray):
    """(distance, colour) of the nearest `mask` pixel for every pixel."""
    dist, labels = cv2.distanceTransformWithLabels((~mask).astype(np.uint8), cv2.DIST_L2, 5,
                                                   labelType=cv2.DIST_LABEL_PIXEL)
    ys, xs = np.nonzero(mask)
    lut = np.zeros((int(labels.max()) + 1, 3), np.float32)
    lut[labels[ys, xs]] = p[ys, xs]
    return dist, lut[labels]


def _flood_from(accept: np.ndarray, seed: np.ndarray) -> np.ndarray:
    """Components of `accept` that touch `seed` (8-connected, one px dilation)."""
    n, lab = cv2.connectedComponents(accept.astype(np.uint8), connectivity=8)
    hit = np.unique(lab[cv2.dilate(seed.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & accept])
    return np.isin(lab, hit[hit > 0])


def trimap(rgb: np.ndarray, plate, spread: float, ring: int, t_core: float = 0.5, clear=None):
    """Returns (bg, ring_mask, glow, solid, core) as bool/float H x W arrays."""
    ycc = denoise(rgb)
    pc = _ycc(np.array(plate, np.uint8).reshape(1, 1, 3))[0, 0]
    # chroma distance, luma counts at half weight so dark maroon/purple paint is not plate
    d = np.sqrt(((ycc[..., 1:] - pc[1:]) ** 2).sum(-1) + 0.25 * (ycc[..., 0] - pc[0]) ** 2)
    raw = _ycc(rgb)
    d_raw = np.sqrt(((raw[..., 1:] - pc[1:]) ** 2).sum(-1) + 0.25 * (raw[..., 0] - pc[0]) ** 2)
    # the median only calms JPEG noise; a thin drawn line (bowstring, arm tip) keeps its own colour
    d = np.where(d_raw > 3.0 * max(10.0, 1.5 * spread), np.maximum(d, d_raw), d)
    pr = float(np.linalg.norm(pc[1:] - 128.0))  # plate chroma radius from neutral
    t_bg = max(10.0, 1.5 * spread)
    reach = max(8, min(rgb.shape[:2]) // 10)
    flat = d <= t_bg
    if clear is not None:
        flat |= clear  # already transparent pixels count as background
    bg = _flood(flat)
    n, lab, st, _ = cv2.connectedComponentsWithStats((flat & ~bg).astype(np.uint8), connectivity=8)
    min_pocket = max(24, int(rgb.shape[0] * rgb.shape[1] * 2e-5))
    keep = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] >= min_pocket]
    if keep:
        bg |= np.isin(lab, keep)
    # small enclosed pockets (gaps between hair strands) that are still clearly the plate
    # Only enclosed ones: a near-plate band touching the background is glow mixed with the plate
    # (a red glow on a pink plate), not plate.
    loose = (d <= 2.5 * t_bg) & ~bg
    n, lab, st, _ = cv2.connectedComponentsWithStats(loose.astype(np.uint8), connectivity=8)
    touch = np.unique(lab[cv2.dilate(bg.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & loose])
    keep = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] >= 6 and i not in set(touch.tolist())]
    if keep:
        bg |= np.isin(lab, keep)
    # glow: pixels connected to the background that carry more magenta excess (min(R,B)-G) than the
    # nearest strong colour allows. That is a translucent veil or soft edge mixed with the plate.
    p = rgb.astype(np.float32)
    P = np.array(plate, np.float32)
    # plate-ish: magenta excess and red and blue both still bright like the plate. Dark maroon paint has
    # excess too, but its red or blue is low, so it stays paint.
    plateish = (excess(p) > 12.0) & (np.minimum(p[..., 0], p[..., 2]) >= t_core * min(P[0], P[2]))
    # a darker shade on the plate's own hue (plate over dark hair or outline), not maroon or violet paint
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.float32)
    ph = cv2.cvtColor(np.array(plate, np.uint8).reshape(1, 1, 3), cv2.COLOR_RGB2HSV_FULL)[0, 0, 0] * 360.0 / 256.0
    gap = np.abs((hsv[..., 0] * 360.0 / 256.0 - ph + 180.0) % 360.0 - 180.0)
    plateish |= (gap <= 12.0) & (hsv[..., 1] >= 150) & (hsv[..., 2] >= 40) & (excess(p) > 12.0)
    core = ~bg & ~plateish
    glow = np.zeros_like(bg)
    if core.any():
        dist, F = _nearest(p, core)
        tinted = ~bg & plateish & (dist <= reach)
        # seeds: the background, and enclosed spots that are nearly plate (plate seen between hair strands)
        glow = _flood_from(tinted, bg | (tinted & (excess(p) >= 0.35 * float(excess(P)))))
    k = np.ones((2 * ring + 1, 2 * ring + 1), np.uint8)
    near = cv2.dilate(bg.astype(np.uint8), k).astype(bool) & ~bg
    ring_m = near & ~glow
    solid = ~(bg | ring_m | glow)
    # colour references sit inside the ring, so an edge pixel is judged against the paint behind it
    k2 = np.ones((2 * ring + 3, 2 * ring + 3), np.uint8)
    inner = core & ~cv2.dilate((bg | glow).astype(np.uint8), k2).astype(bool)
    # a strongly magenta pixel near the edge is fringe, not a reference; deep inside it is real paint
    deep = ~cv2.dilate((bg | glow).astype(np.uint8), np.ones((12 * ring + 1, 12 * ring + 1), np.uint8)).astype(bool)
    inner &= (excess(p) <= 0.15 * float(excess(P))) | deep
    core = inner if inner.any() else core
    return bg, ring_m, glow, solid, core


def excess(c: np.ndarray) -> np.ndarray:
    """Magenta excess min(R,B)-G of float RGB."""
    return np.minimum(c[..., 0], c[..., 2]) - c[..., 1]


def glow_colour(p: np.ndarray, core: np.ndarray, radius: int) -> np.ndarray:
    """Local mean colour of the art (core) within `radius` px: the colour a glow next to it carries.
    A single nearest pixel is too noisy (an outline, a highlight)."""
    k = (2 * radius + 1, 2 * radius + 1)
    w = cv2.blur(core.astype(np.float32), k)
    acc = cv2.blur(p * core[..., None], k)
    return acc / np.maximum(w[..., None], 1e-3), w > 1e-3


def unmix(rgb: np.ndarray, plate, solid: np.ndarray, soft: np.ndarray, core: np.ndarray, glow=None):
    """Alpha and colour for `soft` pixels: pixel = a*C + (1-a)*P.

    a is the smallest alpha whose colour C is a valid RGB with no more magenta excess than the nearest
    solid colour F (colour-to-alpha with a spill limit). Returns (alpha, rgb, F).
    """
    p = rgb.astype(np.float32)
    P = np.array(plate, np.float32)
    alpha = solid.astype(np.float32)
    out = p.copy()
    if not soft.any() or not solid.any():
        return alpha, out, p
    _dist, F = _nearest(p, core if core.any() else solid)
    dp = p - P
    # valid range per channel: C = P + dp/a must lie in [0, 255]
    need = np.zeros(p.shape[:2], np.float32)
    for c in range(3):
        lim = np.where(dp[..., c] > 0, 255.0 - P[c], P[c])
        need = np.maximum(need, np.abs(dp[..., c]) / np.maximum(lim, 1.0))
    # spill limit: excess(C) = min over i in (R, B) of (P_i - P_G) + (dp_i - dp_G)/a <= allow.
    # Largest alpha that meets it (a = 1 when the pixel itself is within the limit).
    allow = np.maximum(excess(F), 0.0)
    best = np.zeros(p.shape[:2], np.float32)
    for i in (0, 2):
        e = float(P[i] - P[1])
        k = dp[..., i] - dp[..., 1]
        ai = np.where(e <= allow, 1.0, np.where(k < 0, -k / np.maximum(e - allow, 1e-3), 0.0))
        best = np.maximum(best, ai)
    a = np.maximum(need, np.minimum(best, 1.0))
    a = np.clip(a, 0.0, 1.0)
    a = np.where(a < 0.04, 0.0, np.where(a > 0.97, 1.0, a))
    col = np.clip(P + dp / np.maximum(a[..., None], 1e-3), 0, 255)
    # A faint mix carries little colour of its own: lean it toward the nearest strong colour.
    col = a[..., None] * col + (1 - a[..., None]) * F
    if glow is not None and glow.any():
        # Glow: G = local mean colour of the art next to it (the glow's own colour). Alpha is the projection
        # of the pixel onto the plate -> G line. Colour keeps the unmixed brightness (p - (1-a)P)/a and takes
        # G's chroma, so a semi-transparent glow carries no plate hue.
        # near the art: the paint right behind (an outline); further out: the wider art colour (an orb's glow)
        G, ok = glow_colour(p, core, max(8, min(p.shape[:2]) // 30))
        G = np.where(ok[..., None], G, F)
        Gn, okn = glow_colour(p, core, 6)
        G = np.where(okn[..., None], Gn, G)
        F = np.where(glow[..., None], G, F)
        gp = G - P
        ag = np.clip(((p - P) * gp).sum(-1) / np.maximum((gp * gp).sum(-1), 1.0), 0.0, 1.0)
        ag = np.where(ag < 0.04, 0.0, np.where(ag > 0.97, 1.0, ag))
        cg = np.clip(P + dp / np.maximum(ag[..., None], 0.05), 0, 255)
        y = cv2.cvtColor(np.rint(cg).astype(np.uint8), cv2.COLOR_RGB2YCrCb)
        gy = cv2.cvtColor(np.rint(G).astype(np.uint8), cv2.COLOR_RGB2YCrCb)
        y[..., 1:] = gy[..., 1:]
        cg = cv2.cvtColor(y, cv2.COLOR_YCrCb2RGB).astype(np.float32)
        # A pixel far off the plate -> G line is its own colour mixed with the plate (a thin bowstring next to
        # a brown limb): keep the spill-limited alpha and colour from above for it.
        resid = np.linalg.norm(p - (ag[..., None] * G + (1 - ag[..., None]) * P), axis=-1)
        on = glow & (resid <= 40.0)
        a = np.where(on, ag, a)
        col = np.where(on[..., None], cg, col)
    alpha[soft] = a[soft]
    out[soft] = col[soft]
    return alpha, out, F


def despill(rgb: np.ndarray, F: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Limit magenta excess min(R,B)-G in `mask` to the foreground colour's own excess."""
    out = rgb.copy()
    ex = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    allow = np.maximum(np.minimum(F[..., 0], F[..., 2]) - F[..., 1], 0.0)
    cut = np.clip(ex - allow, 0.0, None) * mask
    out[..., 0] -= cut
    out[..., 2] -= cut
    return np.clip(out, 0, 255)


def chroma_despill(rgb: np.ndarray, F: np.ndarray, plate, mask: np.ndarray) -> np.ndarray:
    """In YCrCb, remove the part of each pixel's chroma that points toward the plate's chroma beyond what
    the paint behind it (F) has. Hue-correct: a blue glow loses its violet cast, a red glow stays red."""
    ycc = cv2.cvtColor(np.rint(np.clip(rgb, 0, 255)).astype(np.uint8), cv2.COLOR_RGB2YCrCb).astype(np.float32)
    fy = cv2.cvtColor(np.rint(F).astype(np.uint8), cv2.COLOR_RGB2YCrCb).astype(np.float32)
    pc = cv2.cvtColor(np.array(plate, np.uint8).reshape(1, 1, 3), cv2.COLOR_RGB2YCrCb).astype(np.float32)[0, 0, 1:] - 128.0
    u = pc / max(float(np.linalg.norm(pc)), 1e-3)
    c = ycc[..., 1:] - 128.0
    comp = (c * u).sum(-1)
    allow = np.maximum(((fy[..., 1:] - 128.0) * u).sum(-1), 0.0)
    cut = np.where(mask, np.clip(comp - allow, 0.0, None), 0.0)
    ycc[..., 1:] = c - cut[..., None] * u + 128.0
    back = cv2.cvtColor(np.clip(np.rint(ycc), 0, 255).astype(np.uint8), cv2.COLOR_YCrCb2RGB).astype(np.float32)
    return np.where(mask[..., None], back, rgb)


def key(im: Image.Image, ring: int | None = None, debug: str | Path | None = None, name: str = "key", plate=None):
    """Key one opaque plate picture. Returns (RGBA image, stats dict). `plate` pins the plate RGB.

    A picture with no plate on its border (wood, an already cut sprite) returns unchanged.
    """
    src = im.convert("RGBA")
    arr = np.array(src)
    rgb = np.ascontiguousarray(arr[..., :3])
    if plate is None:
        plate, spread = plate_colour(rgb)
    else:
        plate, spread = tuple(int(v) for v in plate), 2.0
    if plate is None:
        return src, {"plate": None}
    if ring is None:
        ring = max(2, min(rgb.shape[:2]) // 400)
    bg, ring_m, glow, solid, core = trimap(rgb, plate, spread, ring, clear=arr[..., 3] < 8)
    soft = ring_m | glow
    res = unmix(rgb, plate, solid, soft, core, glow)
    alpha, col = res[0], res[1]
    # despill band: the soft pixels plus solid paint a few px in from the edge (JPEG fringe on outlines).
    # Alpha there is untouched; only magenta excess above the paint behind it is removed.
    band = soft | (solid & cv2.dilate((bg | glow).astype(np.uint8), np.ones((4 * ring + 3, 4 * ring + 3), np.uint8)).astype(bool))
    col = despill(col, res[2], band)
    art, ok = glow_colour(rgb.astype(np.float32), core, max(6, min(rgb.shape[:2]) // 60))
    art = np.where(ok[..., None], art, res[2])
    art = np.where(glow[..., None], res[2], art)  # glow: its own colour G from unmix
    # glow, and ring pixels that are mostly plate; a near-opaque ring pixel is edge paint and keeps its hue
    col = chroma_despill(col, art, plate, glow | (ring_m & (alpha < 0.85)))
    a8 = np.rint(alpha * arr[..., 3]).astype(np.uint8)
    out = np.zeros_like(arr)
    out[..., :3] = np.rint(col).astype(np.uint8)
    out[..., 3] = a8
    out[a8 == 0] = 0
    stats = {"plate": "#%02X%02X%02X" % plate, "spread": round(spread, 1), "ring": ring,
             "bg": int(bg.sum()), "ring_px": int(ring_m.sum()), "glow": int(glow.sum()), "solid": int(solid.sum())}
    if debug:
        dd = Path(debug)
        dd.mkdir(parents=True, exist_ok=True)
        tri = np.zeros(rgb.shape, np.uint8)
        tri[solid] = (255, 255, 255)
        tri[ring_m] = (255, 160, 0)
        tri[glow] = (0, 160, 255)
        Image.fromarray(tri).save(dd / f"{name}-1-trimap.png")
        Image.fromarray((alpha * 255).astype(np.uint8)).save(dd / f"{name}-2-alpha.png")
        Image.fromarray(out).save(dd / f"{name}-3-keyed.png")
    return Image.fromarray(out, "RGBA"), stats
