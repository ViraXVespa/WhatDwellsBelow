"""Chroma-plate keying: plate mask, plate remap to #FF00FF, colour-to-alpha.

The plate is sampled from the border. Strong black, white, and blue border pixels are subject samples,
not the key. Colour-to-alpha keeps glow and soft edges as partial alpha. Solid plate becomes transparent
black. RGB is never inverted.
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


def _foreground_medians(samples: np.ndarray) -> list:
    """Strong black, white, and blue colours in `samples` (N x 3). Plate-tinted pixels are left out.

    Those three are subject samples. They are never a plate reference. A pixel that still
    carries the plate (magenta excess in red and blue) is not a clean sample of them.
    """
    if samples.size == 0:
        return []
    h, sat, v = hsv(samples.reshape(-1, 1, 3))
    h = np.asarray(h).reshape(-1)
    sat = np.asarray(sat).reshape(-1)
    v = np.asarray(v).reshape(-1)
    peak = samples.max(axis=1).astype(np.int16)
    floor = samples.min(axis=1).astype(np.int16)
    spill = np.maximum(0, np.minimum(samples[:, 0], samples[:, 2]).astype(np.int16) - samples[:, 1].astype(np.int16))
    black = (peak <= 48) & (spill <= 12)
    white = (floor >= 210) & (sat <= 0.12) & (spill <= 12)
    blue = (hue_gap(h, 220.0) <= 45.0) & (sat >= 0.40) & (v >= 0.35) & (spill <= 24)
    found = []
    for mask in (black, white, blue):
        if int(np.asarray(mask).sum()) >= 4:
            found.append(tuple(int(x) for x in np.median(samples[mask], axis=0)))
    return found


def border_comparison(rgb: np.ndarray):
    """Plate colours from the border, plus strong black, white, and blue border colours.

    Plate colours are the colour-to-alpha base. Black, white, and blue are subject samples:
    they never become a plate reference. Returns (plate refs or None, foreground samples).
    """
    samples = border_samples(rgb)
    h, sat, v = hsv(samples.reshape(-1, 1, 3))
    h = np.asarray(h).reshape(-1)
    sat = np.asarray(sat).reshape(-1)
    v = np.asarray(v).reshape(-1)
    foreground = _foreground_medians(samples)
    spill = np.maximum(0, np.minimum(samples[:, 0], samples[:, 2]).astype(np.int16) - samples[:, 1].astype(np.int16))
    plate_px = (hue_gap(h, PLATE_HUE) <= 36.0) & (sat >= 0.40) & (v >= 0.28) & (spill > 12)
    hits = int(np.asarray(plate_px).sum())
    if hits < 16 or hits / float(max(1, samples.shape[0])) < 0.05:
        return None, foreground
    return background_refs(rgb, hue=PLATE_HUE, hue_tol=36.0, sat_min=0.40, val_min=0.28), foreground


def _edge_foreground(rgb: np.ndarray, plate: np.ndarray) -> list:
    """Black, white, and blue on the subject edge, where the figure meets the plate."""
    ring = dilate(plate, 2) & ~plate
    if not np.any(ring):
        return []
    return _foreground_medians(rgb[ring])


def _touching(cand: np.ndarray, seeds: np.ndarray) -> np.ndarray:
    """Components of `cand` that touch `seeds`."""
    if not np.any(cand) or not np.any(seeds):
        return np.zeros(cand.shape, dtype=bool)
    n, lab, _areas, _touch = components(cand)
    if n == 0:
        return np.zeros(cand.shape, dtype=bool)
    labels = np.unique(lab[dilate(seeds, 1) & cand])
    labels = labels[labels > 0]
    if labels.size == 0:
        return np.zeros(cand.shape, dtype=bool)
    return np.isin(lab, labels)


def _fringe_color(rgb: np.ndarray, pick: np.ndarray, amount: np.ndarray, foreground: list):
    """Remove the plate from a mix. Black, white, and blue samples stay those colours.

    The plate shows up as red and blue together above green. Subtract that excess from
    red and blue. Green is left as drawn, and RGB is never inverted. `amount` is the
    colour-to-alpha plate fraction. `pick` is the plate colour. `foreground` is the
    subject samples: when one of them explains the pixel, that colour is kept.
    """
    p = rgb.astype(np.float32)
    k = pick.astype(np.float32)
    red, green, blue = p[..., 0], p[..., 1], p[..., 2]
    spill = np.maximum(0.0, np.minimum(red, blue) - green)
    despill = np.empty_like(p)
    despill[..., 0] = np.clip(red - spill, 0.0, 255.0)
    despill[..., 1] = green
    despill[..., 2] = np.clip(blue - spill, 0.0, 255.0)
    removed = spill / np.maximum(np.minimum(red, blue), 1.0)
    alpha = np.clip(1.0 - amount.astype(np.float32), 0.0, 1.0)
    alpha = np.minimum(alpha, 1.0 - removed)
    err_best = np.full(p.shape[:2], 1e9, dtype=np.float32)
    chosen = despill
    chosen_a = alpha
    for sample in foreground:
        s = np.array(sample, dtype=np.float32)
        sk = s - k
        denom = np.maximum((sk * sk).sum(axis=-1), 1.0)
        a = np.clip(((p - k) * sk).sum(axis=-1) / denom, 0.0, 1.0)
        recon = a[..., None] * s + (1.0 - a[..., None]) * k
        err = np.sqrt(((p - recon) ** 2).sum(axis=-1) / 3.0)
        better = err < err_best
        err_best = np.where(better, err, err_best)
        chosen = np.where(better[..., None], s, chosen)
        chosen_a = np.where(better, a, chosen_a)
    use = err_best <= 18.0
    out_rgb = np.where(use[..., None], chosen, despill)
    out_a = np.where(use, chosen_a, alpha)
    rgb_u8 = np.clip(np.rint(out_rgb), 0, 255).astype(np.uint8)
    alpha_u8 = np.clip(np.rint(np.clip(out_a, 0.0, 1.0) * 255.0), 0, 255).astype(np.uint8)
    return rgb_u8, alpha_u8


def punch(im: Image.Image, spill_flood: bool = False) -> Image.Image:
    """Remap a chroma plate to exact #FF00FF, then colour-to-alpha it."""
    remapped, _vis, _info = remap_plate(im)
    return key_to_alpha(remapped, spill_flood=spill_flood)


def key_to_alpha(im: Image.Image, spill_flood: bool = True, tol: float = LAB_TOL, refs=None) -> Image.Image:
    """One colour-to-alpha against the nearest border-sampled plate key.

    Opacity is `chroma_alpha`. The drawn RGB stays, so soft shading and a pale glow stay
    in the art instead of being rebuilt into a green unmix. Solid plate, including a
    one-level quantize of the key, becomes transparent black. A halo around the paint keeps
    the nearest paint colour, with alpha falling off across about a 16th of the short side.
    Paint inside that halo becomes opaque, so interior holes fill. No fringe walk, no
    red-and-blue-above-green subtract, and no snap of
    alpha under 10 or over 242.
    `spill_flood` and `tol` stay on the signature and do not switch paths. `refs` pins
    the plate colours.
    """
    _ = (spill_flood, tol)
    src = im.convert("RGBA")
    arr = np.array(src, dtype=np.uint8, copy=True)
    rgb = arr[:, :, :3]
    src_a = arr[:, :, 3]
    if refs is None:
        found, _foreground = border_comparison(rgb)
        if found is None:
            exact = (rgb[:, :, 0] >= 250) & (rgb[:, :, 1] <= 8) & (rgb[:, :, 2] >= 250)
            if not np.any(exact):
                return src
            found = [tuple(int(v) for v in KEY_RGB)]
        refs = list(found)
    else:
        refs = [tuple(int(v) for v in r) for r in refs]
    p = rgb.astype(np.float32) / 255.0
    opacities = []
    dists = []
    for ref in refs:
        k = np.asarray(ref, dtype=np.float32) / 255.0
        opacities.append(chroma_alpha(p, k))
        dists.append(delta_e(rgb, [ref]))
    dist = np.stack(dists)
    pick = dist.argmin(axis=0)
    opacity = np.take_along_axis(np.stack(opacities), pick[None], axis=0)[0]
    picked_dist = np.take_along_axis(dist, pick[None], axis=0)[0]
    keys = np.asarray(refs, dtype=np.int16)[pick]
    near_key = np.max(np.abs(rgb.astype(np.int16) - keys), axis=2) <= 1
    # `tol` is the Lab distance of solid plate. A mix sits farther out and keeps partial alpha.
    opacity = np.where(near_key | (picked_dist <= float(tol)), 0.0, opacity)
    # The shopkeep bloom is several art pixels of plate around the body, including the
    # armpits and the gap between the hands and the legs. Chroma leaves that bloom nearly
    # clear and magenta. Paint the halo in the nearest real paint colour and fade it outward.
    # Paint itself stays opaque so the interior sections stay filled.
    spill = np.minimum(rgb[:, :, 0].astype(np.int16), rgb[:, :, 2].astype(np.int16)) - rgb[:, :, 1].astype(np.int16)
    if HAVE_CV2:
        inside = cv2.distanceTransform((opacity > 0.02).astype(np.uint8), cv2.DIST_L2, 5)
        radius = float(max(4, min(rgb.shape[0], rgb.shape[1]) // 16))
        deep = inside > float(max(4, min(rgb.shape[0], rgb.shape[1]) // 48))
        # Real paint, including a soft edge that is already mostly the drawing. The bloom
        # outside it is plate-tinted and is not paint.
        paint = ((opacity > 0.55) & (spill < 40) & (inside > 1.0)) | (deep & (opacity > 0.35) & (spill < 48))
        had_mix = opacity > 0.02
        opacity = np.where(paint, 1.0, opacity)
        if np.any(paint):
            # Colour comes from paint that is not itself plate-tinted, so the halo is the
            # edge colour rather than the magenta mix.
            seeds = paint & (spill < 12)
            if not np.any(seeds):
                seeds = paint
            mask = np.where(seeds, 0, 255).astype(np.uint8)
            dist_to, labels = cv2.distanceTransformWithLabels(mask, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
            seeds_y, seeds_x = np.nonzero(seeds)
            lut = np.zeros((int(labels.max()) + 1, 3), np.uint8)
            lut[labels[seeds_y, seeds_x]] = rgb[seeds_y, seeds_x]
            # Only where the plate already held a mix. Empty plate stays clear.
            glow = (~paint) & had_mix & (spill >= 24) & (dist_to > 0.0) & (dist_to <= radius)
            rgb[glow] = lut[labels][glow]
            fade = np.clip(1.0 - dist_to / radius, 0.0, 1.0) ** 0.55
            opacity = np.where(glow, fade * 0.95, opacity)
    new_a = np.clip(np.rint(src_a.astype(np.float32) * opacity), 0, 255).astype(np.uint8)
    out = np.zeros_like(arr)
    visible = new_a > 0
    out[visible, :3] = rgb[visible]
    out[visible, 3] = new_a[visible]
    return Image.fromarray(out, "RGBA")
