"""Staged chroma-plate keyer. OpenCV is required.

Stages (each can dump a debug PNG through `debug=dir`):
  1 denoise   chroma-only median of the YCrCb planes, used to classify (output keeps the drawn RGB)
  2 plate     plate colour per image: median of border pixels near the plate hue (handles drift such as 242,5,181)
  3 trimap    background = border flood through plate-like chroma + enclosed plate pockets, plus soft pixels
              within the plate's noise of the local plate (drift); solid = paint; everything else (edge ring,
              glow, plate-mix edge paint such as lavender next to a blue glow) is soft
  4 unmix     ONE alpha field over all soft pixels (and the plate around a glow): G = the rim paint's colour
              carried smoothly outward (multi-scale normalised blur); alpha blends, by fit confidence, the
              projection onto the plate->G line and own-colour C2A (thin lines like a bowstring); a noise
              floor from the plate's measured noise fades it to 0 (no radius seams, no regime switch)
  5 despill   plate-direction chroma above G's removed from mixes; magenta excess limited on edge paint
Solid pixels stay opaque with their drawn RGB. Nothing outside the measured mix gets alpha (no invented halo).
"""
from __future__ import annotations

from pathlib import Path

import os

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


def colour_field(p: np.ndarray, ref: np.ndarray, scales=(1.5, 4, 12, 36)) -> np.ndarray:
    """Art colour propagated smoothly outward from `ref` pixels: normalised Gaussian blur summed over
    scales, so near the rim the paint right behind dominates and further out the wider art colour does.
    Smooth everywhere (no radius seams)."""
    w = np.zeros(p.shape[:2], np.float32)
    acc = np.zeros(p.shape, np.float32)
    m = ref.astype(np.float32)
    for sg in scales:
        k = int(sg * 3) | 1
        w += cv2.GaussianBlur(m, (k, k), sg)
        acc += cv2.GaussianBlur(p * m[..., None], (k, k), sg)
    return acc / np.maximum(w[..., None], 1e-6)


_M = np.array([[0.5, -0.4187, -0.0813], [-0.1687, -0.3313, 0.5]], np.float32)  # RGB -> (Cr, Cb) - 128


def guided(I: np.ndarray, p: np.ndarray, r: int, eps: float) -> np.ndarray:
    """He et al. guided filter (grey guide), box radius r."""
    k = (2 * r + 1, 2 * r + 1)
    mI, mp = cv2.blur(I, k), cv2.blur(p, k)
    a = (cv2.blur(I * p, k) - mI * mp) / (cv2.blur(I * I, k) - mI * mI + eps)
    b = mp - a * mI
    return cv2.blur(a, k) * I + cv2.blur(b, k)


def sparkles(rgb, alpha, col, solid0, wide, plate, pale=None):
    """Small paint pieces inside a glow (sparkles) are paint over glow over plate. Their pixels are unmixed
    against what lies behind them (the source just around the sparkle) with the least alpha that keeps the
    colour in range, then composited over the keyed glow carried in from around them: clean dots in their
    own colour, the glow continuous underneath."""
    n, lab, st, _ = cv2.connectedComponentsWithStats(solid0.astype(np.uint8), connectivity=8)
    near_glow = cv2.dilate(wide.astype(np.uint8), np.ones((41, 41), np.uint8)).astype(bool)
    keep = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] < int(2e-3 * solid0.size)]
    sp = np.isin(lab, keep) & near_glow
    if not sp.any():
        return alpha, col, sp, sp
    # the sparkle with its own halo: grow while the source keeps differing from the glow behind it
    S = cv2.dilate(sp.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))).astype(bool)
    ring_m = cv2.dilate(S.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) & ~S
    p = rgb.astype(np.float32)
    B = colour_field(p, ring_m, (1.5, 4, 10))                     # what is behind: glow over plate
    ag = colour_field(np.repeat(alpha[..., None], 3, -1), ring_m, (1.5, 4, 10))[..., 0]
    fg = colour_field(col * alpha[..., None], ring_m, (1.5, 4, 10))  # keyed glow, premultiplied
    # least alpha with K = (C - (1-a) B) / a inside 0..255
    up = (p - B) / np.maximum(255.0 - B, 1.0)
    dn = (B - p) / np.maximum(B, 1.0)
    a_s = np.clip(np.maximum(up, dn).max(-1), 0.0, 1.0)
    # mostly the sparkle's own colour over what is behind: alpha by position on that line where it fits
    own0 = colour_field(p, sp & ~pale if pale is not None else sp, (1.5, 4))
    ob = own0 - B
    a_p = np.clip(((p - B) * ob).sum(-1) / np.maximum((ob * ob).sum(-1), 1.0), 0.0, 1.0)
    a_s = np.maximum(a_s, a_p)
    # JPEG noise in the glow reads as a little alpha: a soft floor, then a light blur (the source is soft too)
    t = np.clip((a_s - 0.1) / 0.25, 0.0, 1.0)
    a_s = a_s * t * t * (3 - 2 * t)
    a_s = cv2.GaussianBlur(a_s.astype(np.float32), (0, 0), 0.8)
    a_s = np.where(sp, 1.0, a_s)
    K = np.clip((p - (1 - a_s[..., None]) * B) / np.maximum(a_s[..., None], 1e-3), 0, 255)
    # no plate chroma beyond the sparkle's own (its halo is the sparkle's colour, not violet/pink)
    pc = _M @ np.array(plate, np.float32)
    u = pc / max(float(np.linalg.norm(pc)), 1e-3)
    own = colour_field(p, sp & ~pale if pale is not None else sp, (1.5, 4))
    allow = np.maximum((own @ _M.T) @ u, 0.0)
    over = np.maximum((K @ _M.T) @ u - allow, 0.0)
    K = np.clip(K - over[..., None] * _chroma_rgb(u), 0, 255)
    # a faint halo pixel's own colour is too noisy to trust: lean on the sparkle's colour there
    w_k = np.clip(a_s * 2.0, 0.0, 1.0)[..., None]
    K = own + (K - own) * w_k
    a_o = a_s + (1 - a_s) * ag
    c_o = (a_s[..., None] * K + (1 - a_s[..., None]) * fg) / np.maximum(a_o[..., None], 1e-3)
    alpha = np.where(S, a_o, alpha)
    col = np.where(S[..., None], c_o, col)
    return alpha, col, S, sp


def _chroma_rgb(u: np.ndarray) -> np.ndarray:
    """RGB change for a unit (Cr, Cb) chroma step with luma kept."""
    return np.array([1.402 * u[0], -0.344136 * u[1] - 0.714136 * u[0], 1.772 * u[1]], np.float32)


def unmix(rgb: np.ndarray, plate, solid: np.ndarray, soft: np.ndarray, core: np.ndarray, noise=None, t_bg: float = 10.0,
          fine=None, bg=None, mix=None):
    """One alpha field over every non-solid pixel: pixel = a*C + (1-a)*P.

    G = the art's colour carried smoothly outward from the rim (colour_field). Two estimates:
      a_line  projection onto the plate -> G line (a glow of the art's colour fading into the plate)
      a_own   colour-to-alpha: the largest alpha whose C has no more plate chroma than G (a thin line of
              its own colour, e.g. a bowstring next to a brown limb)
    blended by how well the pixel fits the line (confidence, no regime switch). A noise floor fades the
    alpha to 0 where the pixel is plate within its own noise. Colour: unmixed, plate-direction chroma above
    G's removed, faint pixels lean to G. Returns (alpha, rgb, G).
    """
    p = rgb.astype(np.float32)
    P = np.array(plate, np.float32)
    alpha = solid.astype(np.float32)
    out = p.copy()
    if not soft.any() or not core.any():
        return alpha, out, p
    # the glow / edge colour is the solid paint right at the rim facing the soft region (a red glow band, a
    # dark outline), carried outward; not the art's average (that mixes highlights and outlines)
    rim = solid & cv2.dilate(soft.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    G = colour_field(p, rim if rim.any() else core)
    # the rim itself can carry plate spill; G keeps no more plate-direction chroma than the deeper art
    pc0 = _M @ P
    u0 = pc0 / max(float(np.linalg.norm(pc0)), 1e-3)
    # the plate drifts across an AI picture: P is the local plate, carried in from the background around
    if bg is not None and bg.any():
        P = colour_field(p, bg, (120,))
    deep = colour_field(p, core, (4, 12, 36))
    over = np.clip((G @ _M.T) @ u0 - np.maximum((deep @ _M.T) @ u0, 0.0), 0.0, None)
    # only as far as G is itself a plate + deep-art mix (lavender between magenta and pale blue); a glow
    # colour of its own (red next to a pink plate and a white orb) is off that line and kept
    dg = deep - P
    t = np.clip(((G - P) * dg).sum(-1) / np.maximum((dg * dg).sum(-1), 1.0), 0.0, 1.0)
    off = np.linalg.norm(G - P - t[..., None] * dg, axis=-1) / np.maximum(np.linalg.norm(dg, axis=-1), 1.0)
    w = np.clip(1.0 - off / 0.25, 0.0, 1.0)
    G = np.clip(G - (w * over)[..., None] * _chroma_rgb(u0), 0, 255)
    dp = p - P
    gp = G - P
    gl = np.maximum((gp * gp).sum(-1), 1.0)
    a_line = np.clip((dp * gp).sum(-1) / gl, 0.0, 1.0)
    resid = np.linalg.norm(dp - a_line[..., None] * gp, axis=-1)
    # colour-to-alpha against the plate's chroma direction
    u = u0
    L = np.maximum((P @ _M.T) @ u if P.ndim > 1 else float(pc0 @ u), 1e-3)
    allow = np.clip((G @ _M.T) @ u, 0.0, 0.9 * L)
    # a glow whose colour sits on the violet side of the plate (between the plate and blue) is most likely
    # still carrying plate: its allowance is the deeper art's (a blue wisp's tail is blue, not lavender)
    gh = cv2.cvtColor(np.clip(G, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL)[..., 0].astype(np.int32)
    ph0 = int(cv2.cvtColor(np.array(plate, np.uint8).reshape(1, 1, 3), cv2.COLOR_RGB2HSV_FULL)[0, 0, 0])
    gside = (gh - ph0 + 128) % 256 - 128
    vio = (gside < -8) & (gside >= -64)
    if mix is not None:
        vio = vio | mix  # plate-mixed paint: the deeper art's allowance too (rim colour may itself be mixed)
    allow = np.where(vio, np.minimum(allow, np.maximum((deep @ _M.T) @ u, 0.0)), allow)
    # own-colour alpha: the largest a whose C = P + dp/a has no more magenta excess min(R,B)-G than G
    # (excess, not the chroma axis: warm paint such as brown wood shares the plate's Cr but has no excess)
    ex_allow = np.maximum(excess(G), 0.0)
    a_own = np.zeros(p.shape[:2], np.float32)
    for i in (0, 2):
        e = P[..., i] - P[..., 1] if P.ndim > 1 else P[i] - P[1]
        k = dp[..., i] - dp[..., 1]
        ai = np.where(e <= ex_allow, 1.0, np.where(k < 0, -k / np.maximum(e - ex_allow, 1e-3), 0.0))
        a_own = np.maximum(a_own, ai)
    a_own = np.clip(a_own, 0.0, 1.0)
    need = np.zeros(p.shape[:2], np.float32)
    for c in range(3):
        Pc = P[..., c]
        lim = np.where(dp[..., c] > 0, 255.0 - Pc, Pc)
        need = np.maximum(need, np.abs(dp[..., c]) / np.maximum(lim, 1.0))
    a_own = np.maximum(a_own, need)
    conf = np.clip(1.0 - resid / (0.35 * np.sqrt(gl)), 0.0, 1.0)
    conf = conf * conf * (3 - 2 * conf)
    # the line model is for plate mixes: a pixel with no more magenta excess than G is paint, not a mix
    conf = conf * np.clip((excess(p) - ex_allow) / 20.0, 0.0, 1.0)
    a_mix = np.maximum(a_line, a_own)
    a = conf * a_line + (1 - conf) * a_mix
    # colour from each estimate's own alpha (unmixing with a rescaled alpha would overshoot past G)
    # on the line the unmixed colour is G itself; the off-line residual is JPEG noise, not colour
    # on the line the unmixed colour is G plus residual/a; at low alpha that residual is amplified JPEG noise,
    # so lean to G as alpha falls (an opaque-ish edge keeps its own colour)
    wl = ((1 - a_line) ** 2)[..., None]
    col_line = wl * G + (1 - wl) * np.clip(P + dp / np.maximum(a_line[..., None], 0.02), 0, 255)
    col_own = np.clip(P + dp / np.maximum(a_mix[..., None], 0.02), 0, 255)
    col = conf[..., None] * col_line + (1 - conf[..., None]) * col_own
    # noise floor: 3 sigma of the plate's own pixel noise measured along the plate -> G direction
    cov = np.eye(3, dtype=np.float32) * 9.0 if noise is None else noise
    sig = np.sqrt(np.maximum(np.einsum("...i,ij,...j->...", gp, cov, gp), 1e-6)) / np.sqrt(gl)
    floor = np.clip(3.0 * sig / np.sqrt(gl), 0.01, 0.25)
    # outside a glow (cut edges), JPEG ringing next to the paint is well above the flat plate's noise: use
    # the background threshold there so the plate around an outline stays clear
    if fine is not None:
        floor = np.where(fine, floor, np.maximum(floor, np.clip(2.5 * t_bg / np.sqrt(gl), 0.0, 0.25)))
    # the same noise band at both ends: within it of the plate is plate, within it of opaque is opaque
    # within JPEG ringing (10%) of opaque is opaque: a hard pixel edge stays hard
    top = np.maximum(floor, 0.1)
    a_hard = np.clip((a - floor) / (1 - floor - top), 0.0, 1.0)
    a_hard = np.where(a_hard < 0.04, 0.0, a_hard)  # below 4%: JPEG specks in the plate
    # in a glow the raw estimate is kept (no snap, no cut); key() smooths it and ramps it out softly
    a = np.where(fine, a, a_hard) if fine is not None else a_hard
    # remove chroma toward the plate beyond G's own (YCrCb, luma kept)
    c = col @ _M.T
    comp = c @ u
    # and no further from the plate than G either (JPEG green ringing, amplified by unmixing)
    gcomp = (G @ _M.T) @ u
    cut = np.clip(comp - allow, 0.0, None) + np.clip(comp - np.minimum(gcomp, 0.0), None, 0.0)
    # near-opaque paint with no magenta excess of its own (brown wood) keeps its hue; a plate mix does not
    keep = np.maximum(np.clip((1.0 - a) * 10.0, 0.0, 1.0), np.clip((excess(p) - ex_allow) / 20.0, 0.0, 1.0))
    cut = cut * (np.maximum(keep, mix.astype(np.float32)) if mix is not None else keep)
    c2 = c - cut[..., None] * u
    y = col @ np.array([0.299, 0.587, 0.114], np.float32)
    col = np.stack([y + 1.402 * c2[..., 0], y - 0.344136 * c2[..., 1] - 0.714136 * c2[..., 0], y + 1.772 * c2[..., 1]], -1)
    # a faint pixel carries little colour of its own: lean it to the art colour (keeps a red glow red)
    w = (conf * (1 - a))[..., None]
    col = np.clip(w * G + (1 - w) * col, 0, 255)
    alpha[soft] = a[soft]
    out[soft] = col[soft]
    hard = np.zeros_like(alpha)
    hard[soft] = a_hard[soft]
    return alpha, out, G, floor, hard


def despill(rgb: np.ndarray, F: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Limit magenta excess min(R,B)-G in `mask` to the foreground colour's own excess."""
    out = rgb.copy()
    ex = np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]
    allow = np.maximum(np.minimum(F[..., 0], F[..., 2]) - F[..., 1], 0.0)
    cut = np.clip(ex - allow, 0.0, None) * mask
    out[..., 0] -= cut
    out[..., 2] -= cut
    return np.clip(out, 0, 255)


def _edge_frame(mask: np.ndarray, depth: int = 3) -> np.ndarray:
    """Crop seams: thin lines of paint along the picture's own border (a dark 1-2 px frame left by a crop or a
    JPEG edge). They vanish under a 5 px opening; art that really reaches the border is thick there and stays."""
    h, w = mask.shape
    if h < 4 * depth or w < 4 * depth:
        return np.zeros_like(mask)
    k = np.ones((5, 5), np.uint8)
    thick = cv2.dilate(cv2.erode(mask.astype(np.uint8), k), k).astype(bool)
    edge = np.zeros_like(mask)
    edge[:depth], edge[-depth:], edge[:, :depth], edge[:, -depth:] = True, True, True, True
    return mask & edge & ~thick


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
    p32 = rgb.astype(np.float32)
    # plate drift: soft pixels within the plate's own noise of the LOCAL plate colour (carried in from the
    # background around) and connected to it are background, not a faint glow
    flat_px = rgb[bg & ~cv2.dilate((~bg).astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)].astype(np.float32)
    noise = np.cov(flat_px.T).astype(np.float32) if len(flat_px) > 64 else None
    if bg.any():
        sig = float(np.sqrt(np.trace(noise))) if noise is not None else 6.0
        Pf = colour_field(p32, bg, (6, 18, 54, 160))
        drift = (glow | ring_m) & (np.linalg.norm(p32 - Pf, axis=-1) <= max(10.0, 3.0 * sig))
        drift = _flood_from(drift, bg)
        bg |= drift
        glow &= ~drift
        ring_m &= ~drift
    # one alpha field over everything that is not solid paint: the edge ring, the glow, and the plate
    # around the art (a glow fades into the plate; the noise floor zeroes plain plate)
    reach = max(8, min(rgb.shape[:2]) // 10)
    near_art = cv2.dilate((~bg).astype(np.uint8), np.ones((2 * reach + 1, 2 * reach + 1), np.uint8)).astype(bool)
    soft = ring_m | glow | (bg & near_art & (arr[..., 3] >= 8))
    # solid-looking edge pixels carrying more plate-direction chroma than the deeper art next to them are
    # plate mix too (pale lavender between a blue glow and the plate): they join the soft region
    pcv = _M @ np.array(plate, np.float32)
    u = pcv / max(float(np.linalg.norm(pcv)), 1e-3)
    deep_col = colour_field(p32, core, (4, 12, 36))
    edge = cv2.dilate((soft & ~bg | bg).astype(np.uint8), np.ones((6 * ring + 9, 6 * ring + 9), np.uint8)).astype(bool)
    # ... and that sit on the plate -> art line (a mix of the two, not a colour of its own such as skin)
    gp = deep_col - np.array(plate, np.float32)
    dp = p32 - np.array(plate, np.float32)
    t = np.clip((dp * gp).sum(-1) / np.maximum((gp * gp).sum(-1), 1.0), 0.0, 1.0)
    on_line = np.linalg.norm(dp - t[..., None] * gp, axis=-1) < 0.2 * np.linalg.norm(gp, axis=-1)
    # or bright and on the violet side of the plate hue (plate over a pale blue glow: lavender), which dark
    # purple paint and warm skin are not
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.int32)
    ph = int(cv2.cvtColor(np.array(plate, np.uint8).reshape(1, 1, 3), cv2.COLOR_RGB2HSV_FULL)[0, 0, 0])
    side = (hsv[..., 0] - ph + 128) % 256 - 128
    violet = (side < 0) & (side >= -64) & (np.minimum(p32[..., 0], p32[..., 2]) >= 0.5 * min(plate[0], plate[2]))
    comp_px = (p32 @ _M.T) @ u
    dirty = solid & edge & (on_line | violet) & (comp_px - np.maximum((deep_col @ _M.T) @ u, 0.0) > 4.0)
    # lavender within 60 deg of the plate on the violet side that carries plate chroma of its own is plate
    # mix even when the art around it is lavender too (armpit pockets, a wisp's tail)
    # small specks of plate hue inside or at the edge of the art (plate seen through a tear in cloth, a tip
    # pixel mixed with the plate): saturated, plate-hued, magenta-heavy and small. Large ones are paint (a robe).
    hsv_s = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.int32)
    speck = np.zeros_like(solid)
    hueish = np.abs(side) <= 21
    hueish &= (hsv_s[..., 1] >= 100) & (excess(p32) > 25)
    specky = solid & hueish
    n3, lab3, st3, _ = cv2.connectedComponentsWithStats(specky.astype(np.uint8), connectivity=8)
    small = [i for i in range(1, n3) if st3[i, cv2.CC_STAT_AREA] <= max(128, int(2e-4 * specky.size))]
    if small:
        dirty |= np.isin(lab3, small) & solid
        speck = cv2.dilate(np.isin(lab3, small).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & hueish & (solid | ring_m)
    near_any = cv2.distanceTransform((~(bg | soft)).astype(np.uint8), cv2.DIST_L2, 5) <= 48
    dirty |= solid & near_any & violet & (side >= -43) & (comp_px > 8.0)
    # pale lavender near background or glow is plate seen through a see-through rim (a ghost's armpits, a
    # wisp's tail): keyed after unmixing (largest alpha that leaves no plate-ward chroma)
    # (hue nearer the plate's than the subject's own plate-free colour around it, by 20 deg or more)
    own_c = colour_field(p32, solid & (comp_px <= 2.0), (4, 12, 36))
    oh = cv2.cvtColor(np.clip(own_c, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL)[..., 0].astype(np.int32)
    ph_k = int(cv2.cvtColor(np.array(plate, np.uint8).reshape(1, 1, 3), cv2.COLOR_RGB2HSV_FULL)[0, 0, 0])
    o_side = np.abs((oh - ph_k + 128) % 256 - 128)
    cand = solid & (comp_px > 4.0) & (side >= -64) & (side <= 0) & (np.max(p32, -1) >= 150) & (hsv_s[..., 1] >= 35) & (np.abs(side) + 10 < o_side)
    # ... as whole patches reaching background or glow (a pocket can run far inside the figure)
    n4, lab4, _, _ = cv2.connectedComponentsWithStats(cand.astype(np.uint8), connectivity=8)
    touch = np.unique(lab4[cv2.dilate((bg | soft).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & cand])
    see = np.isin(lab4, touch[touch > 0])
    solid0 = solid.copy()
    soft |= dirty
    solid &= ~dirty
    # a glow is soft paint reaching past the cut edge: glow pixels more than 2 rings out from the solid art.
    # Its surroundings get the fine (plate-noise) floor; a plain anti-aliased edge keeps the coarse one.
    d_solid = cv2.distanceTransform((~solid).astype(np.uint8), cv2.DIST_L2, 5)
    wide = glow & (d_solid > 2 * ring + 1)
    # ... and only a real glow (a sizeable connected veil), not plate specks along a cut edge
    n, lab, st, _ = cv2.connectedComponentsWithStats(wide.astype(np.uint8), connectivity=8)
    big = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] >= max(200, int(2e-3 * wide.size))]
    wide = np.isin(lab, big) if big else np.zeros_like(wide)
    onramp = np.zeros_like(solid)
    ramp_ok = np.zeros_like(solid)
    if wide.any():
        # a glow runs on into "solid" paint until it reaches its full colour: paint next to a glow that lies
        # on the glow's own ramp (offset from the plate along the local glow direction) short of the ramp's
        # far end nearby is still glow (an orb's red band thinning into the pink)
        Pv = np.array(plate, np.float32)
        off = p32 - Pv
        dirn = colour_field(off, wide, (8, 24))
        dirn /= np.maximum(np.linalg.norm(dirn, axis=-1, keepdims=True), 1e-3)
        proj = (off * dirn).sum(-1)
        res = np.linalg.norm(off - proj[..., None] * dirn, axis=-1)
        # only the main art: small separate pieces (sparkles in the glow) keep their own crisp shape
        n2, lab2, st2, _ = cv2.connectedComponentsWithStats(solid.astype(np.uint8), connectivity=8)
        main = np.isin(lab2, [i for i in range(1, n2) if st2[i, cv2.CC_STAT_AREA] >= int(2e-3 * solid.size)])
        zone = main & (cv2.distanceTransform((~wide).astype(np.uint8), cv2.DIST_L2, 5) <= 16)
        ok = zone & (res < 0.25 * np.maximum(proj, 1.0))
        top_p = cv2.dilate(np.where(ok, proj, 0.0).astype(np.float32), np.ones((17, 17), np.uint8))
        ramp = ok & (proj < 0.985 * top_p) & (excess(p32) > 12.0)  # still plate-tinted
        onramp = ramp
        ramp_ok = ok
        soft |= ramp
        solid &= ~ramp
        glow |= ramp
        d_solid = cv2.distanceTransform((~solid).astype(np.uint8), cv2.DIST_L2, 5)
    fine = cv2.dilate(wide.astype(np.uint8), np.ones((2 * reach + 1, 2 * reach + 1), np.uint8)).astype(bool) & (d_solid > ring)
    soft &= ~bg | fine  # the plate fades into alpha only around a glow
    alpha, col, G, floor, a_hard = unmix(rgb, plate, solid, soft, core, noise, max(10.0, 1.5 * spread), fine, bg, dirty | speck)
    if speck.any():
        # a plate speck is the plate mixed with the paint around it: alpha along plate -> that paint, colour
        # the paint's (no plate hue left in the art)
        D = colour_field(p32, solid & ~speck & ~hueish, (2, 6, 18))
        pd = np.array(plate, np.float32) - D
        t = ((p32 - D) * pd).sum(-1) / np.maximum((pd * pd).sum(-1), 1.0)
        alpha = np.where(speck, np.minimum(alpha, np.clip(1.0 - t, 0.0, 1.0)), alpha)
        col = np.where(speck[..., None], D, col)
    calm = fine & soft
    if calm.any():
        # glow: edge-aware smoothing (guided by the source's luma) kills JPEG blocks, then a smoothstep
        # across the plate's noise band (0.5 .. 2 x floor) fades the tail to 0 with no cut
        guide = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
        sm = guided(guide, alpha, 6, 1e-3)
        # plus a normalised blur over glow + paint so the glow meets the paint edge without a torn seam
        w = (calm | solid).astype(np.float32)
        sm = cv2.GaussianBlur(sm * w, (0, 0), 2.0) / np.maximum(cv2.GaussianBlur(w, (0, 0), 2.0), 1e-3)
        f = np.where(calm, floor, 0.0)
        t = np.clip((sm - 0.5 * f) / np.maximum(1.5 * f, 1e-4), 0.0, 1.0)
        sm = np.clip(sm, 0.0, 1.0) * t * t * (3 - 2 * t)
        # the hard-edge ring next to the paint keeps its snap (opaque edge paint stays opaque)
        edge_px = (a_hard >= 1.0) & (d_solid <= 2 * ring + 1) & ~onramp
        alpha = np.where(calm, np.where(edge_px, 1.0, sm), alpha)
        # soften where the glow meets its full-colour band (both on the glow ramp; outlines are not)
        z = (calm | onramp) & ~edge_px
        zw = z.astype(np.float32)
        zb = cv2.GaussianBlur(alpha * zw, (0, 0), 1.5) / np.maximum(cv2.GaussianBlur(zw, (0, 0), 1.5), 1e-3)
        alpha = np.where(z & (cv2.distanceTransform((~calm).astype(np.uint8), cv2.DIST_L2, 5) <= 6), zb, alpha)
    if wide.any():
        alpha, col, S_sp, sp_core = sparkles(rgb, alpha, col, solid0, wide, plate, see)
        see = see & ~(S_sp & ~sp_core)  # a sparkle's halo is already unmixed against the glow
    if wide.any():
        # the paint's own edge against a wide glow is the glow ramp's business, and sparkles are paint
        at_glow = cv2.dilate((fine & soft).astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
    if see.any():
        cp = float(pcv @ u)
        a_see = np.clip(1.0 - comp_px / max(cp, 1.0), 0.0, 1.0)
        k_see = np.clip((p32 - (1 - a_see[..., None]) * np.array(plate, np.float32)) / np.maximum(a_see[..., None], 1e-3), 0, 255)
        a_new = np.minimum(alpha, a_see)
        if wide.any():
            # at a glow the alpha stays the glow ramp's; only the plate-ward chroma goes
            a_new = np.where(at_glow, alpha, a_new)
            k_glow = np.clip(p32 - np.maximum(comp_px, 0.0)[..., None] * _chroma_rgb(u), 0, 255)
            k_see = np.where(at_glow[..., None], k_glow, k_see)
        col = np.where(see[..., None], k_see, col)
        alpha = np.where(see, a_new, alpha)
    # partly transparent pixels left pale lavender (light, between blue and the plate's hue): their
    # plate-ward chroma is plate, remove it (alpha kept)
    ch = cv2.cvtColor(np.clip(col, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL)[..., 0].astype(np.int32)
    c_side = (ch - ph_k + 128) % 256 - 128
    c_comp = (col.astype(np.float32) @ _M.T) @ u
    lav = (alpha > 0) & (alpha < 1) & (c_side >= -54) & (c_side <= 0) & (col.max(-1) >= 150) & (c_comp > 0)
    col = np.where(lav[..., None], np.clip(col - np.maximum(c_comp, 0.0)[..., None] * _chroma_rgb(u), 0, 255), col)
    # JPEG fringe on solid outline paint: magenta excess above the art colour removed, alpha untouched
    band = solid & cv2.dilate((bg | glow).astype(np.uint8), np.ones((4 * ring + 3, 4 * ring + 3), np.uint8)).astype(bool)
    col = despill(col, G, band)
    a8 = np.rint(alpha * arr[..., 3]).astype(np.uint8)
    out = np.zeros_like(arr)
    out[..., :3] = np.rint(col).astype(np.uint8)
    out[..., 3] = a8
    out[a8 == 0] = 0
    frame = _edge_frame(a8 > 0)
    out[frame] = 0
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
