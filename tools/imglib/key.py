"""Chroma-plate keying: plate mask, wand/pocket fill, despill, plate remap to #FF00FF, colour-to-alpha.

The plate is found by Lab distance to several references sampled from the image border (a plate drifts in
shade across one picture) plus a hue band, closed against JPEG speckle, then connected components: whatever
touches the border is plate, and enclosed islands are plate when small or tight. Exact-#FF00FF plates give
the same mask as the older single-colour wand (the new accept set is a superset of the old one).
"""
from __future__ import annotations

from collections import deque

import numpy as np
from PIL import Image

from . import HAVE_CV2, cv2
from .color import background_refs, delta_e, hsv, hue_gap
from .imgio import MAGENTA, hex_of

KEY_RGB = MAGENTA
WAND_DIST = 77.0
TIGHT_DIST = 18.0
POCKET_FRAC = 0.07
LAB_TOL = 20.0
SPILL_GREEN_EXCESS = 36
SPILL_HUE = 300.0
SPILL_HUE_WIDTH = 26.0
SPILL_SAT_MIN = 0.20
ALPHA_SNAP_LOW = 10
ALPHA_SNAP_HIGH = 242
MATTE_CUT = 128
PLATE_HUE = 310.0
RIM_HUE_WIDTH = 40.0
RIM_SPILL_MIN = 8


def components(mask: np.ndarray):
    """8-connected labels of a bool mask: (count, labels int32, areas list indexed by label, border-touch set)."""
    h, w = mask.shape
    if HAVE_CV2:
        n, lab, st, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), connectivity=8)
        areas = [0] + [int(v) for v in st[1:, cv2.CC_STAT_AREA]]
    else:
        lab = np.zeros((h, w), dtype=np.int32)
        areas = [0]
        n = 1
        for sy, sx in zip(*np.nonzero(mask)):
            if lab[sy, sx]:
                continue
            lab[sy, sx] = n
            q = deque([(sx, sy)])
            cnt = 0
            while q:
                x, y = q.popleft()
                cnt += 1
                for ny in range(max(0, y - 1), min(h, y + 2)):
                    for nx in range(max(0, x - 1), min(w, x + 2)):
                        if mask[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = n
                            q.append((nx, ny))
            areas.append(cnt)
            n += 1
    edge = np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])
    return n - 1, lab, areas, set(int(v) for v in np.unique(edge) if v)


def flood_border(accept: np.ndarray) -> np.ndarray:
    """8-connected flood from the border through `accept` (H x W bool). Returns a uint8 H x W mask."""
    n, lab, _areas, touch = components(accept.astype(bool))
    if n == 0 or not touch:
        return np.zeros(accept.shape, dtype=np.uint8)
    return np.isin(lab, np.fromiter(touch, dtype=np.int32)).astype(np.uint8)


def fill_pockets(mask: np.ndarray, dist: np.ndarray, pocket_dist: float, pocket_frac: float, tight_dist: float) -> int:
    """Grab enclosed chroma islands the border wand cannot reach (sets them in `mask`, a bool/uint8 H x W).

    Components of cells within pocket_dist are kept when small (pocket_frac of the image, at least 64 px) or
    when their mean distance is within tight_dist. Returns how many cells were added.
    """
    h, w = mask.shape
    cap = max(64, int(h * w * pocket_frac))
    cand = (dist <= pocket_dist) & (mask == 0)
    n, lab, areas, _t = components(cand)
    if n == 0:
        return 0
    sums = np.bincount(lab.ravel(), weights=np.where(cand, dist, 0.0).ravel(), minlength=n + 1)
    added = 0
    for i in range(1, n + 1):
        if areas[i] <= cap or sums[i] / max(1, areas[i]) <= tight_dist:
            sel = lab == i
            mask[sel] = 1
            added += areas[i]
    return added


def dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    """Chebyshev dilation of a bool mask by `radius` pixels."""
    if radius <= 0:
        return mask.copy()
    if HAVE_CV2:
        k = np.ones((2 * radius + 1, 2 * radius + 1), np.uint8)
        return cv2.dilate(mask.astype(np.uint8), k).astype(bool)
    h, w = mask.shape
    out = mask.copy()
    for _ in range(radius):
        pad = np.pad(out, 1)
        nxt = out.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nxt |= pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
        out = nxt
    return out


def _fill_speckle(accept: np.ndarray, loose: np.ndarray, max_area: int = 3) -> np.ndarray:
    """Close JPEG speckle: non-plate specks of at most `max_area` px inside the plate join it when most of
    their pixels are still plate-ish (`loose`). Thin features (outlines, antennae) are long and dark dots or
    sparks are not plate coloured, so they stay; a 3x3 closing would erase them."""
    n, lab, areas, touch = components(~accept)
    small = [i for i in range(1, n + 1) if areas[i] <= max_area and i not in touch]
    if not small:
        return accept
    share = np.bincount(lab.ravel(), weights=loose.ravel().astype(np.float32), minlength=n + 1)
    fill = [i for i in small if share[i] >= 0.5 * areas[i]]
    return accept | np.isin(lab, np.array(fill, dtype=np.int32)) if fill else accept


def rgb_dist(rgb: np.ndarray, refs) -> np.ndarray:
    """Euclidean RGB distance of every pixel to the nearest of `refs`. H x W float32."""
    out = None
    for r in refs:
        d = rgb.astype(np.int32) - np.array(r, dtype=np.int32)
        v = np.sqrt((d * d).sum(axis=-1).astype(np.float32))
        out = v if out is None else np.minimum(out, v)
    return out


def hue_band(rgb: np.ndarray, refs, hue_tol: float = 14.0, sat_min: float = 0.50, val_min: float = 0.40) -> np.ndarray:
    """Pixels whose hue is near a reference hue and that are saturated and bright enough: plate shades that
    sit far from every reference in Lab but are still plainly the plate colour."""
    h, s, v = hsv(rgb)
    hit = np.zeros(h.shape, dtype=bool)
    for r in refs:
        rh, rs, rv = hsv(np.array(r, dtype=np.uint8).reshape(1, 1, 3))
        if rs[0, 0] < 0.2:
            continue
        hit |= hue_gap(h, float(rh[0, 0])) <= hue_tol
    return hit & (s >= sat_min) & (v >= val_min)


def plate_mask(rgb: np.ndarray, refs=None, alpha: np.ndarray | None = None, tol: float = LAB_TOL, rgb_wand: float = 0.0,
               pocket_frac: float = POCKET_FRAC, tight: float = 12.0, extra: np.ndarray | None = None):
    """Boolean plate mask for an opaque chroma-plate picture. Returns (mask, refs, lab_distance).

    accept = Lab distance <= tol | hue band | RGB distance <= rgb_wand | alpha < 8 | extra; specks <= 3 px filled; border
    flood; enclosed islands that are small or tight (Lab) join; pixels within `tight` of a reference always join.
    """
    if refs is None:
        refs = background_refs(rgb, hue=PLATE_HUE, hue_tol=45.0)
    d = delta_e(rgb, refs)
    accept = (d <= tol) | hue_band(rgb, refs)
    if rgb_wand > 0:
        accept |= rgb_dist(rgb, refs) <= rgb_wand
    if alpha is not None:
        accept |= alpha < 8
    if extra is not None:
        accept |= extra
    mask = flood_border(_fill_speckle(accept, (d <= tol * 2.0) | hue_band(rgb, refs, sat_min=0.25, val_min=0.25))).astype(bool)
    mask[d <= tight] = True
    m8 = mask.astype(np.uint8)
    fill_pockets(m8, d, tol * 1.25, pocket_frac, tight)
    return m8.astype(bool), refs, d


def plate_amount(rgb: np.ndarray, refs) -> tuple[np.ndarray, np.ndarray]:
    """GIMP colour-to-alpha plate mix against the nearest reference. Returns (amount 0-1, reference per pixel)."""
    dists = np.stack([delta_e(rgb, [r]) for r in refs])
    pick = np.array(refs, dtype=np.float32)[dists.argmin(axis=0)]
    p = rgb.astype(np.float32) / 255.0
    k = pick / 255.0
    alpha = np.zeros(rgb.shape[:2], dtype=np.float32)
    for i in range(3):
        pv, kv = p[..., i], k[..., i]
        hi, lo = pv > kv, pv < kv
        ch = np.zeros_like(pv)
        ch[hi] = (pv[hi] - kv[hi]) / np.maximum(1.0 - kv[hi], 1e-3)
        ch[lo] = (kv[lo] - pv[lo]) / np.maximum(kv[lo], 1e-3)
        alpha = np.maximum(alpha, ch)
    return np.clip(1.0 - alpha, 0.0, 1.0), pick


def remap_plate(im: Image.Image, tol: float = LAB_TOL, wand_dist: float = 48.0, min_amount: float = 0.72, edge: int = 4,
                edge_min: float = 0.04, pocket_frac: float = POCKET_FRAC):
    """Repaint the plate as exact #FF00FF (opaque), shifting edge bleed by its plate mix. Returns (image, debug image, info).

    Every plate pixel ends exactly (255, 0, 255); the edge band (within `edge` px of the plate) is shifted
    by amount x (key - nearest reference) when the pixel holds at least edge_min of the plate colour.
    """
    src = im.convert("RGBA")
    arr = np.array(src, dtype=np.uint8, copy=True)
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].copy()
    plate, refs, _d = plate_mask(rgb, alpha=arr[:, :, 3], tol=tol, rgb_wand=wand_dist, pocket_frac=pocket_frac)
    amt, pick = plate_amount(rgb, refs)
    band = dilate(plate, edge) & ~plate
    hit = band & (amt >= edge_min)
    shifted = np.clip(np.rint(rgb.astype(np.float32) + amt[..., None] * (np.array(KEY_RGB, np.float32) - pick)), 0, 255).astype(np.uint8)
    arr[hit, :3] = shifted[hit]
    arr[plate, :3] = KEY_RGB
    arr[:, :, 3] = 255
    vis = np.zeros((h, w, 4), dtype=np.uint8)
    vis[:, :, 3] = 255
    vis[plate] = (255, 0, 255, 255)
    t = np.clip(np.rint(40.0 + amt * 215.0), 0, 255).astype(np.uint8)
    vis[hit, 0], vis[hit, 1], vis[hit, 2] = 255, t[hit], 0
    info = {
        "start_chroma": hex_of(refs[0]),
        "refs": [hex_of(r) for r in refs],
        "target": "#FF00FF",
        "size": [w, h],
        "plate_pixels": int(plate.sum()),
        "bleed_pixels": int(hit.sum()),
        "lab_tol": tol,
        "wand_dist": wand_dist,
        "min_amount": min_amount,
        "edge": edge,
        "edge_min": edge_min,
        "pocket_frac": pocket_frac,
    }
    return Image.fromarray(arr, "RGBA"), Image.fromarray(vis, "RGBA"), info


def chroma_alpha(p: np.ndarray, k) -> np.ndarray:
    """Colour-to-alpha amount: p is float RGB (0-1, H x W x 3), k the key (0-1, len 3). Returns H x W float."""
    alpha = np.zeros(p.shape[:2], dtype=np.float32)
    for i in range(3):
        pv = p[..., i]
        kv = float(k[i])
        ch = np.zeros_like(pv)
        if kv < 0.999:
            hi = pv > kv
            ch[hi] = (pv[hi] - kv) / (1.0 - kv)
        if kv > 0.001:
            lo = pv < kv
            ch[lo] = (kv - pv[lo]) / kv
        alpha = np.maximum(alpha, ch)
    return alpha


def c2a(rgb: np.ndarray, a: np.ndarray, key) -> tuple[np.ndarray, np.ndarray]:
    """GIMP colour-to-alpha of every pixel against one key colour. Returns (rgb uint8, alpha uint8)."""
    p = rgb.astype(np.float32) / 255.0
    k = np.array(key, dtype=np.float32) / 255.0
    alpha = chroma_alpha(p, k)
    empty = alpha < 0.01
    safe = np.maximum(alpha, 1e-6)[..., None]
    recon = np.clip(np.rint(((p - k) / safe + k) * 255.0), 0, 255).astype(np.uint8)
    new_a = np.rint(a.astype(np.float32) * alpha).astype(np.int32)
    kill = empty | (new_a < ALPHA_SNAP_LOW)
    new_a = np.where(new_a > ALPHA_SNAP_HIGH, 255, new_a).astype(np.uint8)
    recon[kill] = 0
    new_a[kill] = 0
    return recon, new_a


def ref_hue(rgb) -> float:
    """Hue in degrees of one RGB colour."""
    h, _s, _v = hsv(np.array(rgb, dtype=np.uint8).reshape(1, 1, 3))
    return float(h[0, 0])


def spill_map(arr: np.ndarray, refs) -> np.ndarray:
    """Bright plate (Euclidean to key or a reference) or dark plate-hued rim (invert-to-green excess / hue of the
    key and of every reference: a plate drifts toward red or violet, so one fixed hue misses it)."""
    rgb = arr[:, :, :3]
    d = rgb_dist(rgb, [KEY_RGB, *refs])
    inv = 255 - rgb.astype(np.int16)
    excess = inv[:, :, 1] - np.maximum(inv[:, :, 0], inv[:, :, 2])
    h, s, v = hsv(rgb)
    near_hue = np.zeros(h.shape, dtype=bool)
    for r in [KEY_RGB, *refs]:
        near_hue |= hue_gap(h, ref_hue(r)) <= SPILL_HUE_WIDTH
    hue_hit = (s >= SPILL_SAT_MIN) & (v >= 0.06) & near_hue
    return (d <= WAND_DIST) | (excess >= SPILL_GREEN_EXCESS) | hue_hit


def eat_spill(arr: np.ndarray, refs) -> np.ndarray:
    """Walk inward from clear pixels through dark magenta / inverted-green spill (in place)."""
    h, w = arr.shape[:2]
    steps = max(3, min(10, min(w, h) // 80))
    for _ in range(steps):
        rgb = arr[:, :, :3]
        a = arr[:, :, 3]
        clear = a == 0
        hits = spill_map(arr, refs) & ~clear & dilate(clear, 1)
        if not hits.any():
            break
        d = rgb_dist(rgb, [KEY_RGB, *refs])
        inv = 255 - rgb.astype(np.int16)
        excess = inv[:, :, 1] - np.maximum(inv[:, :, 0], inv[:, :, 2])
        hard = hits & ((d <= TIGHT_DIST) | (excess >= SPILL_GREEN_EXCESS + 12))
        soft = hits & ~hard
        arr[hard] = 0
        if soft.any():
            recon, na = c2a(255 - rgb, a, (0, 255, 0))
            recon = 255 - recon
            still = spill_map(np.dstack((recon, na)), refs)
            drop = soft & ((na == 0) | still)
            keep = soft & ~drop
            arr[drop] = 0
            arr[keep, :3] = recon[keep]
            arr[keep, 3] = na[keep]
    return arr


def looks_like_plate(rgb) -> bool:
    """True when one RGB colour is the magenta plate (near #FF00FF or the same hue)."""
    pix = np.array(rgb, dtype=np.uint8).reshape(1, 1, 3)
    if float(rgb_dist(pix, [KEY_RGB])[0, 0]) < 90.0:
        return True
    h, s, v = hsv(pix)
    return bool(float(hue_gap(h, 300.0)[0, 0]) <= 28.0 and float(s[0, 0]) >= 0.35 and float(v[0, 0]) >= 0.35)


def strip_rim(arr: np.ndarray, hue_width: float = RIM_HUE_WIDTH, passes: int = 12) -> np.ndarray:
    """Delete a chroma lip on the matte edge. Interior cloth (maroon, skin, green) stays.

    A light pink fringe such as (240, 200, 220) is still the plate: hue near 300 and both red and blue
    above green. Maroon sits nearer red, so a hue width of 40 leaves it. Each pass peels one pixel.
    Removed pixels are (0, 0, 0, 0) so a later resize cannot bleed pink RGB back in.
    """
    width = float(hue_width)
    for _ in range(max(0, passes)):
        arr[arr[:, :, 3] < 16] = 0
        clear = arr[:, :, 3] == 0
        if not clear.any():
            break
        rim = dilate(clear, 1) & ~clear
        rgb = arr[:, :, :3]
        r = rgb[:, :, 0].astype(np.int16)
        g = rgb[:, :, 1].astype(np.int16)
        b = rgb[:, :, 2].astype(np.int16)
        spill = np.maximum(0, np.minimum(r, b) - g)
        h, s, v = hsv(rgb)
        near = hue_gap(h, 300.0) <= width
        lip = rim & near & (v >= 0.12) & (spill >= RIM_SPILL_MIN) & ((s >= 0.08) | (spill >= 18))
        bright = rim & (hue_gap(h, PLATE_HUE) <= 30.0) & (s >= 0.55) & (v >= 0.55)
        hit = lip | bright
        if not hit.any():
            break
        arr[hit] = 0
    return arr


def punch(im: Image.Image, spill_flood: bool = False) -> Image.Image:
    """Remap a chroma plate to exact #FF00FF, then key it and strip the pink lip."""
    remapped, _vis, _info = remap_plate(im)
    return key_to_alpha(remapped, spill_flood=spill_flood)


def key_to_alpha(im: Image.Image, spill_flood: bool = True, tol: float = LAB_TOL, refs=None) -> Image.Image:
    """Outside wand deletes the plate; spill walk + invert-C2A eat the pink lip; binary matte.

    `refs` pins the plate colours (e.g. to clean the rim of an already keyed picture: transparent pixels count as
    plate). Stills with a chroma plate keep spill_flood on. Video extracts should plate-remap first, then pass
    spill_flood=False so compressed maroon / hair is not treated as plate.
    """
    arr = np.array(im.convert("RGBA"), dtype=np.uint8, copy=True)
    rgb = arr[:, :, :3].copy()
    refs = list(refs) if refs else background_refs(rgb, hue=PLATE_HUE, hue_tol=45.0)
    near = rgb_dist(rgb, [KEY_RGB, *refs])
    extra = (near <= WAND_DIST) | (arr[:, :, 3] == 0)
    if spill_flood:
        extra |= spill_map(arr, refs)
    mask, refs, d = plate_mask(rgb, refs=refs, alpha=arr[:, :, 3], tol=tol, extra=extra)
    mask |= near <= TIGHT_DIST
    arr[mask] = 0
    arr = eat_spill(arr, refs)
    keep = arr[:, :, 3] >= MATTE_CUT
    arr[~keep] = 0
    arr[keep, 3] = 255
    arr = strip_rim(arr)
    return Image.fromarray(arr, "RGBA")
