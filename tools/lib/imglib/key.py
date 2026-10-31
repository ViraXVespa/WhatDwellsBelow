"""Chroma-plate helpers: plate mask, plate remap to #FF00FF, rim strip, and the key entry points.

The keyer itself is imglib.matte (staged: denoise, plate, trimap, unmix, despill). key_to_alpha and punch
call it. remap_plate and plate_mask stay for media.py plate-remap and media.py keyed-region.
"""
from __future__ import annotations

from collections import deque

import numpy as np
from PIL import Image

from . import HAVE_CV2, cv2
from .color import background_refs, border_samples, delta_e, hsv, hue_gap
from .imgio import MAGENTA, hex_of

KEY_RGB = MAGENTA
WAND_DIST = 77.0
TIGHT_DIST = 18.0
POCKET_FRAC = 0.07
LAB_TOL = 20.0
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

def plate_border_refs(rgb: np.ndarray):
    """Magenta-plate colours from the border, or None when that border is not a plate.

    Wood, black, and an already-cut sprite stay as drawn. background_refs would
    otherwise take the border colour itself as the plate and eat the picture.
    """
    samples = border_samples(rgb)
    h, sat, v = hsv(samples.reshape(-1, 1, 3))
    ok = (hue_gap(h, PLATE_HUE) <= 36.0) & (sat >= 0.40) & (v >= 0.28)
    hit = int(np.asarray(ok).sum())
    # A real plate covers the margin. A handful of red roof pixels must not count.
    if hit < 16 or hit / float(max(1, samples.shape[0])) < 0.05:
        return None
    return background_refs(rgb, hue=PLATE_HUE, hue_tol=36.0, sat_min=0.40, val_min=0.28)

def remap_plate(im: Image.Image, tol: float = LAB_TOL, wand_dist: float = 48.0, min_amount: float = 0.72, edge: int = 4,
                edge_min: float = 0.04, pocket_frac: float = POCKET_FRAC):
    """Repaint solid plate as exact #FF00FF (opaque). A farther mix keeps its drawn RGB.

    Returns (image, debug image, info). Solid plate near a border reference ends exactly (255, 0, 255).
    Shifting a farther mix onto the key drew lines along hard pixel edges. Colour-to-alpha keeps that mix
    as partial alpha without a recolour. The debug image still marks the mix band.
    """
    src = im.convert("RGBA")
    arr = np.array(src, dtype=np.uint8, copy=True)
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3].copy()
    found = plate_border_refs(rgb)
    if found is None:
        vis = np.zeros((h, w, 4), dtype=np.uint8)
        vis[:, :, 3] = 255
        info = {
            "start_chroma": "#FF00FF",
            "refs": [],
            "target": "#FF00FF",
            "size": [w, h],
            "plate_pixels": 0,
            "bleed_pixels": 0,
            "lab_tol": tol,
            "wand_dist": wand_dist,
            "min_amount": min_amount,
            "edge": edge,
            "edge_min": edge_min,
            "pocket_frac": pocket_frac,
        }
        return src, Image.fromarray(vis, "RGBA"), info
    plate, refs, dist = plate_mask(rgb, refs=found, alpha=arr[:, :, 3], tol=tol, rgb_wand=wand_dist, pocket_frac=pocket_frac)
    amt, _pick = plate_amount(rgb, refs)
    # Flat plate (near a border ref) becomes exact #FF00FF. A farther plate-coloured mix
    # keeps its drawn RGB. Shifting that mix onto the key drew lines on the arrow.
    solid = plate & (dist <= float(tol) * 1.25)
    mix = plate & ~solid
    band = dilate(plate, edge) & ~plate
    hit = (band | mix) & (amt >= edge_min)
    arr[solid, :3] = KEY_RGB
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
        lip = rim & near & (v >= 0.45) & (spill >= RIM_SPILL_MIN) & ((s >= 0.08) | (spill >= 18))
        bright = rim & (hue_gap(h, PLATE_HUE) <= 30.0) & (s >= 0.55) & (v >= 0.55)
        hit = lip | bright
        if not hit.any():
            break
        arr[hit] = 0
    return arr

def key_to_alpha(im: Image.Image, plate=None) -> Image.Image:
    """Key an opaque magenta-plate picture with the staged keyer (imglib.matte). `plate` pins the plate RGB."""
    from . import matte
    return matte.key(im, plate=plate)[0]

def punch(im: Image.Image) -> Image.Image:
    """Same as key_to_alpha (kept for the pack tools)."""
    return key_to_alpha(im)

def pixelate(im: Image.Image, cell: float, palette: int = 0, crisp: bool = True) -> Image.Image:
    """Keyed art at a coarser pixel grid, from the shared steps: geom.shrink_art (crisp: interior = nearest source px,
    edge band and alpha box-averaged) or geom.resize_rgba (premultiplied box) down by `cell` source px per pixel, optional color.quantize_palette, geom.alpha_policy "hard" (binary edges), then
    geom.scale_nearest back to the source size. cell <= 1 returns a copy."""
    from . import color, geom
    im = im.convert("RGBA")
    if cell <= 1.0:
        return im.copy()
    size = (max(1, round(im.width / cell)), max(1, round(im.height / cell)))
    small = geom.shrink_art(im, size) if crisp else geom.resize_rgba(im, size)
    if palette > 0:
        small = color.quantize_palette(small, palette)
    return geom.scale_nearest(geom.alpha_policy(small, "hard"), size=im.size)
