"""Section 19 cleanup: Paint.NET-style outside wand + Color-to-Alpha lip + 128 fit."""
from __future__ import annotations

import json
import math
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

MAGENTA = (255, 0, 255, 255)
KEY_RGB = (255, 0, 255)
CANVAS = 128
PAD = 8

# Paint.NET Magic Wand ~30% in Euclidean RGB is about 76-80.
# (60% on this scale was ~155.)
WAND_DIST = 77.0
TIGHT_DIST = 18.0
POCKET_DIST = 77.0
POCKET_FRAC = 0.07
# Inverted plate becomes green. ig - max(ir, ib) >= this is spill.
# Dark magenta rims score ~50; maroon tabard ~20; olive/gold/ice go negative.
SPILL_GREEN_EXCESS = 36
SPILL_HUE = 300.0
SPILL_HUE_WIDTH = 26.0
SPILL_SAT_MIN = 0.20
ALPHA_SNAP_LOW = 10
ALPHA_SNAP_HIGH = 242
MATTE_CUT = 128
_KEY_V = np.array(KEY_RGB, dtype=np.int16)


def _dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def _hsv(r: int, g: int, b: int) -> tuple[float, float, float]:
    rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
    mx = max(rf, gf, bf)
    mn = min(rf, gf, bf)
    d = mx - mn
    if d == 0.0:
        h = 0.0
    elif mx == rf:
        h = (60.0 * ((gf - bf) / d) + 360.0) % 360.0
    elif mx == gf:
        h = (60.0 * ((bf - rf) / d) + 120.0) % 360.0
    else:
        h = (60.0 * ((rf - gf) / d) + 240.0) % 360.0
    s = 0.0 if mx == 0.0 else d / mx
    return h, s, mx


def _hue_dist(a: float, b: float) -> float:
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def _neighbors8(x: int, y: int, w: int, h: int):
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                yield nx, ny


def _as_rgba(im: Image.Image) -> np.ndarray:
    return np.array(im.convert("RGBA"), dtype=np.uint8, copy=True)


def _rgb_dist(rgb: np.ndarray, key: np.ndarray) -> np.ndarray:
    d = rgb.astype(np.int16, copy=False) - key
    return np.sqrt((d.astype(np.float32) ** 2).sum(axis=-1))


def pixel_key_dist(rgb: tuple[int, int, int], bg: tuple[int, int, int]) -> float:
    return min(_dist(rgb, KEY_RGB), _dist(rgb, bg))


def key_amount(r: int, g: int, b: int, bg: tuple[int, int, int]) -> float:
    d = pixel_key_dist((r, g, b), bg)
    if d >= WAND_DIST:
        return 0.0
    return 1.0 - d / WAND_DIST


def is_key(r: int, g: int, b: int, bg: tuple[int, int, int] | None = None) -> bool:
    return pixel_key_dist((r, g, b), bg or KEY_RGB) <= WAND_DIST


def _inverted_green_excess(r: int, g: int, b: int) -> int:
    """Invert RGB, then how hard G beats R and B. Magenta plate scores high."""
    return (255 - g) - max(255 - r, 255 - b)


def _is_spill(r: int, g: int, b: int, bg: tuple[int, int, int]) -> bool:
    """Bright plate (Euclidean) or dark magenta rim (invert-to-green / hue)."""
    if pixel_key_dist((r, g, b), bg) <= WAND_DIST:
        return True
    if _inverted_green_excess(r, g, b) >= SPILL_GREEN_EXCESS:
        return True
    h, s, v = _hsv(r, g, b)
    if s >= SPILL_SAT_MIN and v >= 0.06 and _hue_dist(h, SPILL_HUE) <= SPILL_HUE_WIDTH:
        return True
    return False


def sample_chroma(im: Image.Image) -> tuple[int, int, int]:
    """Border-sampled key colour. Prefers samples near #FF00FF."""
    px = im.load()
    w, h = im.size
    pts: list[tuple[int, int, int]] = []
    step_x = max(1, w // 16)
    step_y = max(1, h // 16)
    for x in range(0, w, step_x):
        pts.append(px[x, 0][:3])
        pts.append(px[x, h - 1][:3])
    for y in range(0, h, step_y):
        pts.append(px[0, y][:3])
        pts.append(px[w - 1, y][:3])
    if not pts:
        return KEY_RGB
    scored = sorted((_dist(p, KEY_RGB), p) for p in pts)
    take = scored[: max(4, len(scored) // 3)]
    n = len(take)
    return tuple(int(sum(s[1][i] for s in take) / n) for i in range(3))


def _distance_map(arr: np.ndarray, bg: tuple[int, int, int]) -> np.ndarray:
    rgb = arr[:, :, :3]
    d = np.minimum(_rgb_dist(rgb, _KEY_V), _rgb_dist(rgb, np.array(bg, dtype=np.int16)))
    d[arr[:, :, 3] == 0] = 0.0
    return d


def _distances(im: Image.Image, bg: tuple[int, int, int]) -> list[float]:
    return _distance_map(_as_rgba(im), bg).ravel().tolist()


def _hsv_np(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    p = rgb.astype(np.float32) / 255.0
    mx = p.max(axis=-1)
    mn = p.min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    r, g, b = p[..., 0], p[..., 1], p[..., 2]
    mask = d > 0
    rmax = mask & (mx == r)
    gmax = mask & (mx == g)
    bmax = mask & (mx == b)
    h[rmax] = (60.0 * ((g[rmax] - b[rmax]) / d[rmax]) + 360.0) % 360.0
    h[gmax] = (60.0 * ((b[gmax] - r[gmax]) / d[gmax]) + 120.0) % 360.0
    h[bmax] = (60.0 * ((r[bmax] - g[bmax]) / d[bmax]) + 240.0) % 360.0
    s = np.zeros_like(mx)
    nz = mx > 0
    s[nz] = d[nz] / mx[nz]
    return h, s, mx


def _spill_map(arr: np.ndarray, bg: tuple[int, int, int]) -> np.ndarray:
    rgb = arr[:, :, :3]
    d = np.minimum(_rgb_dist(rgb, _KEY_V), _rgb_dist(rgb, np.array(bg, dtype=np.int16)))
    inv = 255 - rgb.astype(np.int16)
    excess = inv[:, :, 1] - np.maximum(inv[:, :, 0], inv[:, :, 2])
    h, s, v = _hsv_np(rgb)
    hd = np.abs(h - SPILL_HUE) % 360.0
    hd = np.minimum(hd, 360.0 - hd)
    hue_hit = (s >= SPILL_SAT_MIN) & (v >= 0.06) & (hd <= SPILL_HUE_WIDTH)
    return (d <= WAND_DIST) | (excess >= SPILL_GREEN_EXCESS) | hue_hit


def _fill_pockets(mask: bytearray, distances: list[float], w: int, h: int) -> bytearray:
    """Grab enclosed chroma islands the border wand cannot reach."""
    n = w * h
    cap = max(64, int(n * POCKET_FRAC))
    seen = bytearray(n)
    for i in range(n):
        if mask[i] or seen[i] or distances[i] > POCKET_DIST:
            continue
        comp: list[int] = []
        q: deque[int] = deque([i])
        seen[i] = 1
        total = 0.0
        while q:
            j = q.popleft()
            comp.append(j)
            total += distances[j]
            x = j % w
            y = j // w
            for nx, ny in _neighbors8(x, y, w, h):
                nj = ny * w + nx
                if seen[nj] or mask[nj]:
                    continue
                if distances[nj] <= POCKET_DIST:
                    seen[nj] = 1
                    q.append(nj)
        mean = total / max(1, len(comp))
        if len(comp) <= cap or mean <= TIGHT_DIST:
            for j in comp:
                mask[j] = 1
    return mask


def wand_mask(
    im: Image.Image,
    distances: list[float],
    bg: tuple[int, int, int],
    spill_flood: bool = True,
) -> bytearray:
    """8-connected wand from the border, including dark magenta spill."""
    arr = _as_rgba(im)
    h, w = arr.shape[:2]
    dist2d = np.asarray(distances, dtype=np.float32).reshape(h, w)
    accept = dist2d <= WAND_DIST
    accept |= arr[:, :, 3] == 0
    if spill_flood:
        accept |= _spill_map(arr, bg)
    mask2d = np.zeros((h, w), dtype=np.uint8)
    seen = np.zeros((h, w), dtype=np.uint8)
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if seen[y, x]:
            return
        seen[y, x] = 1
        if accept[y, x]:
            q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while q:
        x, y = q.popleft()
        mask2d[y, x] = 1
        x0 = 0 if x == 0 else x - 1
        x1 = w if x + 2 > w else x + 2
        y0 = 0 if y == 0 else y - 1
        y1 = h if y + 2 > h else y + 2
        for ny in range(y0, y1):
            for nx in range(x0, x1):
                if seen[ny, nx]:
                    continue
                seen[ny, nx] = 1
                if accept[ny, nx]:
                    q.append((nx, ny))

    mask2d[dist2d <= TIGHT_DIST] = 1
    mask = bytearray(mask2d.ravel().tolist())
    return _fill_pockets(mask, distances, w, h)


def color_to_alpha_pixel(
    r: int, g: int, b: int, a: int, key: tuple[int, int, int] = KEY_RGB
) -> tuple[int, int, int, int]:
    """GIMP Color-to-Alpha against one key colour."""
    pr, pg, pb = r / 255.0, g / 255.0, b / 255.0
    kr, kg, kb = key[0] / 255.0, key[1] / 255.0, key[2] / 255.0

    def chan_alpha(p: float, k: float) -> float:
        if p > k:
            return (p - k) / (1.0 - k) if k < 0.999 else 0.0
        if p < k:
            return (k - p) / k if k > 0.001 else 0.0
        return 0.0

    alpha = max(chan_alpha(pr, kr), chan_alpha(pg, kg), chan_alpha(pb, kb))
    if alpha < 0.01:
        return (0, 0, 0, 0)

    nr = (pr - kr) / alpha + kr
    ng = (pg - kg) / alpha + kg
    nb = (pb - kb) / alpha + kb
    new_a = int(round(a * alpha))
    if new_a < ALPHA_SNAP_LOW:
        return (0, 0, 0, 0)
    if new_a > ALPHA_SNAP_HIGH:
        new_a = 255
    return (
        max(0, min(255, int(round(nr * 255.0)))),
        max(0, min(255, int(round(ng * 255.0)))),
        max(0, min(255, int(round(nb * 255.0)))),
        new_a,
    )


def color_to_alpha_via_green(r: int, g: int, b: int, a: int) -> tuple[int, int, int, int]:
    """Invert so plate is green, C2A against green, invert the kept colour back."""
    ir, ig, ib = 255 - r, 255 - g, 255 - b
    out = color_to_alpha_pixel(ir, ig, ib, a, (0, 255, 0))
    if out[3] == 0:
        return (0, 0, 0, 0)
    return (255 - out[0], 255 - out[1], 255 - out[2], out[3])


def _c2a_np(rgb: np.ndarray, a: np.ndarray, key: tuple[int, int, int]) -> tuple[np.ndarray, np.ndarray]:
    p = rgb.astype(np.float32) / 255.0
    k = np.array(key, dtype=np.float32) / 255.0
    alpha = np.zeros(a.shape, dtype=np.float32)
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
    empty = alpha < 0.01
    safe = np.maximum(alpha, 1e-6)[..., None]
    recon = (p - k) / safe + k
    recon = np.clip(np.rint(recon * 255.0), 0, 255).astype(np.uint8)
    new_a = np.rint(a.astype(np.float32) * alpha).astype(np.int32)
    kill = empty | (new_a < ALPHA_SNAP_LOW)
    new_a = np.where(new_a > ALPHA_SNAP_HIGH, 255, new_a).astype(np.uint8)
    recon[kill] = 0
    new_a[kill] = 0
    return recon, new_a


def _spill_steps(w: int, h: int) -> int:
    return max(3, min(10, min(w, h) // 80))


def _neighbor8_true(flag: np.ndarray) -> np.ndarray:
    h, w = flag.shape
    pad = np.pad(flag, 1, mode="constant", constant_values=False)
    out = np.zeros_like(flag, dtype=bool)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            out |= pad[1 + dy : 1 + dy + h, 1 + dx : 1 + dx + w]
    return out


def _eat_magenta_spill(im: Image.Image, bg: tuple[int, int, int]) -> Image.Image:
    return Image.fromarray(_eat_magenta_spill_arr(_as_rgba(im), bg), "RGBA")


def _eat_magenta_spill_arr(arr: np.ndarray, bg: tuple[int, int, int]) -> np.ndarray:
    """Walk inward from clear pixels through dark magenta / inverted-green spill."""
    h, w = arr.shape[:2]
    bg_v = np.array(bg, dtype=np.int16)
    for _ in range(_spill_steps(w, h)):
        rgb = arr[:, :, :3]
        a = arr[:, :, 3]
        clear = a == 0
        spill = _spill_map(arr, bg) & ~clear
        hits = spill & _neighbor8_true(clear)
        if not hits.any():
            break
        d = np.minimum(_rgb_dist(rgb, _KEY_V), _rgb_dist(rgb, bg_v))
        inv = 255 - rgb.astype(np.int16)
        excess = inv[:, :, 1] - np.maximum(inv[:, :, 0], inv[:, :, 2])
        hard = hits & ((d <= TIGHT_DIST) | (excess >= SPILL_GREEN_EXCESS + 12))
        soft = hits & ~hard
        arr[hard] = 0
        if soft.any():
            irgb = 255 - rgb
            recon, na = _c2a_np(irgb, a, (0, 255, 0))
            recon = 255 - recon
            still = _spill_map(np.dstack((recon, na)), bg)
            drop = soft & ((na == 0) | still)
            keep = soft & ~drop
            arr[drop] = 0
            arr[keep, :3] = recon[keep]
            arr[keep, 3] = na[keep]
    return arr


def snap_matte(im: Image.Image, cut: int = MATTE_CUT) -> Image.Image:
    """Binary alpha so C2A cannot leave a magenta lip on dark backdrops."""
    arr = _as_rgba(im)
    keep = arr[:, :, 3] >= cut
    arr[~keep] = 0
    arr[keep, 3] = 255
    return Image.fromarray(arr, "RGBA")


def key_to_alpha(im: Image.Image, spill_flood: bool = True) -> Image.Image:
    """Outside wand deletes the plate; spill walk + invert-C2A eat the pink lip.

    Stills with an exact #FF00FF plate keep spill_flood on. Video extracts should
    plate-remap first, then pass spill_flood=False so compressed maroon / hair is
    not treated as plate.
    """
    im = im.convert("RGBA")
    arr = _as_rgba(im)
    bg = sample_chroma(im)
    dist2d = _distance_map(arr, bg)
    mask = wand_mask(im, dist2d.ravel().tolist(), bg, spill_flood=spill_flood)
    arr.reshape(-1, 4)[np.frombuffer(mask, dtype=np.uint8) == 1] = 0
    arr = _eat_magenta_spill_arr(arr, bg)
    keep = arr[:, :, 3] >= MATTE_CUT
    arr[~keep] = 0
    arr[keep, 3] = 255
    return Image.fromarray(arr, "RGBA")


def range_key(im: Image.Image) -> Image.Image:
    """Bible / seed path: wand the outside, flatten that region to exact #FF00FF."""
    keyed = key_to_alpha(im)
    arr = _as_rgba(keyed)
    arr[arr[:, :, 3] == 0] = np.array(MAGENTA, dtype=np.uint8)
    return Image.fromarray(arr, "RGBA")


def flatten_magenta_to_alpha(im: Image.Image, spill_flood: bool = True) -> Image.Image:
    return key_to_alpha(im, spill_flood=spill_flood)


def split_equal_3x3(im: Image.Image) -> list[Image.Image]:
    w, h = im.size
    cw, ch = w // 3, h // 3
    cells = []
    for row in range(3):
        for col in range(3):
            box = (col * cw, row * ch, (col + 1) * cw, (row + 1) * ch)
            cells.append(im.crop(box))
    return cells


CELL_NAMES = [
    "up_left",
    "up",
    "up_right",
    "left",
    "face",
    "right",
    "down_left",
    "down",
    "down_right",
]


def fit_canvas(
    im: Image.Image,
    canvas: int = CANVAS,
    baseline: int | None = None,
    key: bool = True,
    spill_flood: bool = True,
) -> Image.Image:
    if key:
        im = flatten_magenta_to_alpha(im, spill_flood=spill_flood)
    bbox = im.getbbox()
    if bbox is None:
        return Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    cropped = im.crop(bbox)
    cw, ch = cropped.size
    box = Image.new("RGBA", (cw + PAD * 2, ch + PAD * 2), (0, 0, 0, 0))
    box.paste(cropped, (PAD, PAD), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(round(box.size[0] * scale)))
    nh = max(1, int(round(box.size[1] * scale)))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    ox = (canvas - nw) // 2
    if baseline is None:
        oy = canvas - nh - 2
    else:
        oy = baseline - nh
    oy = max(0, min(canvas - nh, oy))
    out.paste(resized, (ox, oy), resized)
    return out


def foot_baseline(im: Image.Image) -> int:
    arr = np.asarray(im.convert("RGBA"))
    rows = np.any(arr[:, :, 3] > 8, axis=1)
    idx = np.flatnonzero(rows)
    if idx.size == 0:
        return arr.shape[0]
    return int(idx[-1] + 1)


def lock_baselines(frames: list[Image.Image]) -> list[Image.Image]:
    bases = [foot_baseline(f) for f in frames]
    target = max(bases) if bases else CANVAS - 2
    locked = []
    for f, b in zip(frames, bases):
        dy = target - b
        if dy == 0:
            locked.append(f)
            continue
        out = Image.new("RGBA", f.size, (0, 0, 0, 0))
        out.paste(f, (0, dy), f)
        locked.append(out)
    return locked


def quantize_palette(im: Image.Image, colors: int = 24) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    pal = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    pal = pal.convert("RGB")
    out = pal.convert("RGBA")
    out.putalpha(alpha)
    arr = np.array(out, dtype=np.uint8, copy=True)
    a = np.array(alpha)
    arr[a < 16] = 0
    return Image.fromarray(arr, "RGBA")


def extract_seeds(src: Path, dest_dir: Path) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    im = range_key(Image.open(src))
    cells = split_equal_3x3(im)
    out = {}
    for name, cell in zip(CELL_NAMES, cells):
        p = dest_dir / f"seed_{name}.png"
        cell.save(p)
        out[name] = str(p)
    return out


def composite_bible(cell_paths: dict[str, Path], dest: Path, cell: int = 256) -> None:
    sheet = Image.new("RGBA", (cell * 3, cell * 3), MAGENTA)
    order = CELL_NAMES
    for i, name in enumerate(order):
        p = cell_paths[name]
        im = Image.open(p).convert("RGBA")
        im = fit_canvas(im, cell)
        bg = Image.new("RGBA", (cell, cell), MAGENTA)
        bg.paste(im, (0, 0), im)
        col, row = i % 3, i // 3
        sheet.paste(bg, (col * cell, row * cell))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)


def write_palette(im: Image.Image, dest: Path) -> None:
    arr = np.asarray(im.convert("RGBA"))
    rgb = arr[:, :, :3]
    a = arr[:, :, 3]
    key_d = _rgb_dist(rgb, _KEY_V)
    keep = (a >= 16) & (key_d > WAND_DIST)
    if not keep.any():
        dest.write_text(json.dumps({"colors": []}, indent=2))
        return
    pix = rgb[keep]
    # packed RGB as int for a cheap unique count
    pack = pix[:, 0].astype(np.int32) << 16 | pix[:, 1].astype(np.int32) << 8 | pix[:, 2]
    vals, counts = np.unique(pack, return_counts=True)
    order = np.argsort(-counts)[:32]
    colors = []
    for v in vals[order]:
        colors.append([int((v >> 16) & 255), int((v >> 8) & 255), int(v & 255)])
    dest.write_text(json.dumps({"colors": colors}, indent=2))


if __name__ == "__main__":
    import sys

    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "seeds":
        print(json.dumps(extract_seeds(Path(sys.argv[2]), Path(sys.argv[3])), indent=2))
    elif cmd in ("key", "alpha", "fit"):
        src, dest = Path(sys.argv[2]), Path(sys.argv[3])
        dest.parent.mkdir(parents=True, exist_ok=True)
        fit_canvas(Image.open(src)).save(dest)
        print("wrote " + str(dest))
    elif cmd == "matte":
        src, dest = Path(sys.argv[2]), Path(sys.argv[3])
        dest.parent.mkdir(parents=True, exist_ok=True)
        key_to_alpha(Image.open(src)).save(dest)
        print("wrote " + str(dest))
    elif cmd == "flatten":
        src, dest = Path(sys.argv[2]), Path(sys.argv[3])
        dest.parent.mkdir(parents=True, exist_ok=True)
        range_key(Image.open(src)).save(dest)
        print("wrote " + str(dest))
    else:
        print("usage: sprite_pipeline.py seeds SRC DEST_DIR")
        print("       sprite_pipeline.py key SRC.png DEST.png   (matte + 128 fit)")
        print("       sprite_pipeline.py matte SRC.png DEST.png (matte only)")
        print("       sprite_pipeline.py flatten SRC.png DEST.png")