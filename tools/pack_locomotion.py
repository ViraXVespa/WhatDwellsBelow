"""Pack idle stills + idle_to_walk / walk / walk_to_idle from I2V clips."""
from __future__ import annotations

import argparse
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import i2v_seeds  # noqa: E402
import plate_remap as pr  # noqa: E402
import sprite_pipeline as sp  # noqa: E402

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
FINAL = ROOT / "_src" / "walk_final"
OUT = ROOT / "assets" / "sprites" / "player"
RAW = ROOT / "_src" / "walk_harvest"
BIBLES = {
    "male": ROOT / "assets" / "sprites" / "player" / "bible_locked_male.png",
    "female": ROOT / "assets" / "sprites" / "player" / "bible_locked_female.png",
}
START_N = 3
CYCLE_N = 8
STOP_N = 3
P_LO = 8
P_HI = 16
LOOP_MAD_OK = 8.0
KEYS = list(i2v_seeds.BODY_CELLS)
COMPARE_SIZE = (48, 72)
IDLE_FRAC = 0.18
KEYED_CAP = 512
RIM_HUE = 300.0
RIM_SAT_MIN = 0.12
RIM_KEY_DIST = 110.0
PINK_EXCESS = 10
LEG_TOP = 0.45
EXTENT_SIZE = (64, 96)
_BIBLE_CELLS: dict[str, dict[str, Image.Image]] = {}


def extract(video: Path, dest: Path, fps: int = 8, reuse: bool = False) -> list[Path]:
    """Full-size RGB PNGs. Nearest chroma upsample; no pre-key shrink."""
    dest.mkdir(parents=True, exist_ok=True)
    if reuse:
        existing = sorted(dest.glob("f*.png"))
        if existing:
            return existing
    for old in dest.glob("f*.png"):
        old.unlink()
    cmd = [
        FFMPEG,
        "-y",
        "-an",
        "-sws_flags",
        "neighbor+accurate_rnd+full_chroma_int",
        "-i",
        str(video),
        "-vf",
        f"fps={fps},format=rgb24",
        "-compression_level",
        "1",
        str(dest / "f%03d.png"),
    ]
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return sorted(dest.glob("f*.png"))


def _shrink_keyed(im: Image.Image, cap: int = KEYED_CAP) -> Image.Image:
    w, h = im.size
    m = max(w, h)
    if m <= cap:
        return im
    s = cap / m
    return im.resize(
        (max(1, int(w * s)), max(1, int(h * s))),
        Image.Resampling.NEAREST,
    )


def bible_cell(gender: str, facing: str) -> Image.Image:
    if gender not in _BIBLE_CELLS:
        bible = Image.open(BIBLES[gender]).convert("RGBA")
        _BIBLE_CELLS[gender] = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(bible)))
    return _BIBLE_CELLS[gender][facing]


def _stamp(im: Image.Image, size: tuple[int, int] = COMPARE_SIZE) -> Image.Image:
    """Plate-ignored figure stamp for idle compare. Not a shipping matte."""
    im = im.convert("RGBA").resize(size, Image.Resampling.NEAREST)
    arr = np.asarray(im)
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3]
    key = np.array(sp.KEY_RGB, dtype=np.int16)
    dist = np.sqrt(((rgb - key).astype(np.float32) ** 2).sum(axis=-1))
    keep = (alpha >= 16) & (dist > 40.0)
    if not keep.any():
        return Image.new("RGB", size, (0, 0, 0))
    masked = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    masked[keep, :3] = arr[keep, :3]
    masked[keep, 3] = 255
    ys, xs = np.where(keep)
    crop = masked[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1, :3]
    ch, cw = crop.shape[:2]
    scale = min(size[0] / cw, size[1] / ch)
    nw = max(1, int(cw * scale))
    nh = max(1, int(ch * scale))
    rsz = Image.fromarray(crop, "RGB").resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGB", size, (0, 0, 0))
    canvas.paste(rsz, ((size[0] - nw) // 2, size[1] - nh))
    return canvas


def _mad(a: Image.Image, b: Image.Image) -> float:
    pa = np.asarray(a, dtype=np.int16)
    pb = np.asarray(b, dtype=np.int16)
    return float(np.mean(np.abs(pa - pb)))


def _smooth(vals: list[float], radius: int = 2) -> list[float]:
    out: list[float] = []
    for y in range(len(vals)):
        w = vals[max(0, y - radius) : y + radius + 1]
        out.append(sum(w) / len(w))
    return out


def idle_scores(images: list[Image.Image], ref: Image.Image) -> list[float]:
    stamp = _stamp(ref)
    return [_mad(_stamp(im), stamp) for im in images]


def _pad(items: list, n: int) -> list:
    if not items:
        return []
    out = list(items)
    while len(out) < n:
        out.append(out[-1])
    return out[:n]


def _figure_keep(im: Image.Image, size: tuple[int, int] = EXTENT_SIZE) -> np.ndarray:
    im = im.convert("RGBA").resize(size, Image.Resampling.NEAREST)
    arr = np.asarray(im)
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3]
    key = np.array(sp.KEY_RGB, dtype=np.int16)
    dist = np.sqrt(((rgb - key).astype(np.float32) ** 2).sum(axis=-1))
    return (alpha >= 16) & (dist > 40.0)


def _leg_wh(im: Image.Image) -> tuple[float, float]:
    """Lower-body bbox. Arms above the cut do not drive stride width."""
    keep = _figure_keep(im)
    if not keep.any():
        return 0.0, 0.0
    ys, xs = np.where(keep)
    y0, y1 = int(ys.min()), int(ys.max())
    cut = y0 + int((y1 - y0 + 1) * LEG_TOP)
    band = keep[cut : y1 + 1]
    if not band.any():
        band = keep
    ys, xs = np.where(band)
    return float(xs.max() - xs.min() + 1), float(ys.max() - ys.min() + 1)


def _amp(vals: list[float]) -> float:
    if not vals:
        return 0.0
    mid = sum(vals) / len(vals)
    return (max(vals) - min(vals)) / max(1.0, mid)


def _extent_series(images: list[Image.Image], facing: str) -> tuple[list[float], str]:
    """Width on side/diagonal. Height on front/back so up/down still have a stride."""
    pairs = [_leg_wh(im) for im in images]
    widths = [p[0] for p in pairs]
    heights = [p[1] for p in pairs]
    if facing in ("up", "down"):
        return _smooth(heights), "h"
    return _smooth(widths), "w"


def _motion_onset(exts: list[float]) -> int:
    n = len(exts)
    if n < 3:
        return 0
    cap = max(CYCLE_N, n // 3)
    sl = exts[: cap + 1]
    lo, hi = min(exts), max(exts)
    if hi - lo < 1e-3:
        return 0
    thr = lo + 0.35 * (hi - lo)
    i = 0
    if sl[0] >= thr:
        while i < len(sl) - 1 and sl[i] >= thr:
            i += 1
        while i < len(sl) and sl[i] < thr:
            i += 1
        return min(i, cap)
    while i < len(sl) and sl[i] < thr:
        i += 1
    return min(i, cap)


def _one_cycle(
    stamps: list[Image.Image],
    exts: list[float],
    onset: int,
    close: int,
) -> tuple[int, int, float]:
    """Best single wrap of period 8–16 on the first two cycles after onset."""
    n = min(len(stamps), len(exts))
    close = min(close, n - 1, n - 12)
    onset = max(0, min(onset, max(0, close - P_LO)))
    sl_all = exts[onset : close + 1] or [0.0]
    span = max(sl_all) - min(sl_all)
    min_amp = 0.12 * max(1.0, span)
    search_hi = min(close, onset + P_HI * 2)
    best_i = onset
    best_p = CYCLE_N
    best = 1e9
    found = False
    for p in range(P_LO, P_HI + 1):
        last = search_hi - p
        if last < onset:
            continue
        for i in range(onset, last + 1):
            sl = exts[i : i + p]
            if max(sl) - min(sl) < min_amp:
                continue
            cost = _mad(stamps[i], stamps[i + p])
            cost += (i - onset) * 0.04
            cost += abs(p - CYCLE_N) * 0.8
            if cost < best:
                best = cost
                best_i = i
                best_p = p
                found = True
    if not found:
        for p in range(P_LO, P_HI + 1):
            if onset + p <= close:
                return onset, p, -1.0
        return onset, CYCLE_N, -1.0
    return best_i, best_p, best


def _to_eight(
    frames: list[Image.Image],
    sl: list[float],
    src_off: int,
) -> tuple[list[Image.Image], list[int], int]:
    """Rotate plant to slot 0. Sequential if period is 8, else even sample."""
    if not frames:
        return frames, [], 0
    k = int(sl.index(max(sl))) if sl else 0
    p = len(frames)
    if p == CYCLE_N:
        order = [(k + i) % p for i in range(CYCLE_N)]
    else:
        order = [(k + int(round(i * p / CYCLE_N))) % p for i in range(CYCLE_N)]
    mid = [frames[j] for j in order]
    src = [src_off + j for j in order]
    return mid, src, k


def _mass_x(im: Image.Image) -> float:
    arr = np.asarray(im.convert("RGBA"))
    alpha = arr[:, :, 3] > 8
    if not alpha.any():
        return arr.shape[1] * 0.5
    top = alpha[: max(1, arr.shape[0] // 2)]
    ys, xs = np.where(top if top.any() else alpha)
    return float(xs.mean())


def lock_x(frames: list[Image.Image], ref: Image.Image) -> list[Image.Image]:
    """Keep the torso on the idle still's X so clip switches do not slide."""
    target = _mass_x(ref)
    out: list[Image.Image] = []
    for im in frames:
        dx = int(round(target - _mass_x(im)))
        if dx == 0:
            out.append(im)
            continue
        canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
        canvas.paste(im, (dx, 0), im)
        out.append(canvas)
    return out


def _split_time(images: list[Image.Image]) -> tuple[list[Image.Image], list[Image.Image], list[Image.Image]]:
    n = len(images)
    if n < START_N + CYCLE_N + STOP_N:
        return _pad(images[:START_N], START_N), images[:CYCLE_N] if n >= CYCLE_N else pick(images, CYCLE_N), _pad(images[-STOP_N:], STOP_N)
    a = START_N
    b = n - STOP_N
    return _pad(images[:a], START_N), pick(images[a:b], CYCLE_N), _pad(images[b:], STOP_N)


def split_phases(
    images: list[Image.Image],
    ref: Image.Image,
    facing: str = "down",
) -> tuple[list[Image.Image], list[Image.Image], list[Image.Image]]:
    """One early cycle, plant at walk[0], start/stop glued to that plant."""
    n = len(images)
    if n < START_N + CYCLE_N + STOP_N:
        return _split_time(images)
    stamps = [_stamp(im) for im in images]
    ref_s = _stamp(ref)
    scores = [_mad(s, ref_s) for s in stamps]
    sm = _smooth(scores)
    lo, hi = min(sm), max(sm)
    if hi - lo < 1.0:
        return _split_time(images)
    thr = lo + IDLE_FRAC * (hi - lo)
    prefix = 0
    for i, s in enumerate(sm):
        if s <= thr:
            prefix = i
        else:
            break
    suffix = n - 1
    for i in range(n - 1, -1, -1):
        if sm[i] <= thr:
            suffix = i
        else:
            break
    if prefix >= suffix:
        return _split_time(images)
    exts, kind = _extent_series(images, facing)
    onset = max(prefix + 1, _motion_onset(exts))
    close = min(suffix, n - 1)
    off, period, loop_mad = _one_cycle(stamps, exts, onset, close)
    raw = images[off : off + period]
    sl = exts[off : off + period]
    if len(raw) < CYCLE_N:
        return _split_time(images)
    mid, src, rot = _to_eight(raw, sl, off)
    plant = src[0] if src else off
    leave_from = max(src) + 1 if src else off + period
    approach = images[max(prefix, plant - (START_N - 1)) : plant]
    leave = images[leave_from : min(suffix + 1, leave_from + (STOP_N - 1))]
    start = _pad(approach, START_N - 1)
    stop = _pad(leave, STOP_N - 1)
    peak = 0
    trough = sl.index(min(sl)) if sl else 0
    warn = "" if 0.0 <= loop_mad <= LOOP_MAD_OK else " WEAK_LOOP"
    print(
        f"  {facing} n={n} prefix={prefix} suffix={suffix} onset={onset} "
        f"cycle={off}:{off + period} period={period} rot={rot} plant={plant} "
        f"start={max(prefix, plant - (START_N - 1))}:{plant} "
        f"stop={leave_from}:{min(suffix + 1, leave_from + (STOP_N - 1))} "
        f"score {lo:.1f}-{hi:.1f} extent={kind} "
        f"loop_mad={loop_mad:.2f}{warn}"
    )
    return start, mid, stop


def pick(items: list, n: int) -> list:
    if not items:
        return []
    if len(items) <= n:
        return list(items)
    return [items[int(round(i * (len(items) - 1) / (n - 1)))] for i in range(n)]


def _hsv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    r = rgb[:, :, 0].astype(np.float32) / 255.0
    g = rgb[:, :, 1].astype(np.float32) / 255.0
    b = rgb[:, :, 2].astype(np.float32) / 255.0
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    diff = mx - mn
    s = np.divide(diff, mx, out=np.zeros_like(mx), where=mx > 1e-6)
    v = mx
    h = np.zeros_like(mx)
    mask = diff > 1e-6
    rc = np.divide((g - b), diff, out=np.zeros_like(mx), where=mask)
    gc = np.divide((b - r), diff, out=np.zeros_like(mx), where=mask)
    bc = np.divide((r - g), diff, out=np.zeros_like(mx), where=mask)
    h = np.where(mask & (mx == r), (60.0 * rc) % 360.0, h)
    h = np.where(mask & (mx == g), (60.0 * gc) + 120.0, h)
    h = np.where(mask & (mx == b), (60.0 * bc) + 240.0, h)
    h %= 360.0
    return h, s, v


def _near_clear(clear: np.ndarray, radius: int) -> np.ndarray:
    near = clear.copy()
    for _ in range(max(0, radius)):
        nxt = near.copy()
        nxt[1:, :] |= near[:-1, :]
        nxt[:-1, :] |= near[1:, :]
        nxt[:, 1:] |= near[:, :-1]
        nxt[:, :-1] |= near[:, 1:]
        nxt[1:, 1:] |= near[:-1, :-1]
        nxt[1:, :-1] |= near[:-1, 1:]
        nxt[:-1, 1:] |= near[1:, :-1]
        nxt[:-1, :-1] |= near[1:, 1:]
        near = nxt
    return near & ~clear


def _magenta_lip(arr: np.ndarray, hue_width: float) -> np.ndarray:
    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3]
    key = np.array(sp.KEY_RGB, dtype=np.int16)
    dist = np.sqrt(((rgb - key).astype(np.float32) ** 2).sum(axis=-1))
    h, s, _v = _hsv(arr[:, :, :3])
    hd = np.abs(h - RIM_HUE)
    hd = np.minimum(hd, 360.0 - hd)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    pink = (r >= g + PINK_EXCESS) & (b >= g + PINK_EXCESS)
    hue_hit = (s >= RIM_SAT_MIN) & (hd <= hue_width)
    return (alpha >= 16) & (pink | hue_hit | (dist <= RIM_KEY_DIST))


def finish_matte(im: Image.Image, rim: int, hue_width: float) -> Image.Image:
    """Despill then punch a magenta lip at canvas resolution (after 128-fit)."""
    if rim <= 0:
        return im
    arr = np.array(im.convert("RGBA"))
    clear = arr[:, :, 3] < 16
    band = _near_clear(clear, rim + 1)
    rgb = arr[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    spill = np.maximum(0, np.minimum(r, b) - g)
    hit = band & (spill > 0)
    if hit.any():
        rgb = rgb.copy()
        rgb[hit, 0] = np.clip(r[hit] - spill[hit], 0, 255)
        rgb[hit, 2] = np.clip(b[hit] - spill[hit], 0, 255)
        arr[hit, :3] = rgb[hit].astype(np.uint8)
    for _ in range(rim):
        clear = arr[:, :, 3] < 16
        lip = _near_clear(clear, 1) & _magenta_lip(arr, hue_width)
        if not lip.any():
            break
        arr[lip] = 0
    return Image.fromarray(arr, "RGBA")


def key_fit(im: Image.Image, rim: int = 2, rim_hue: float = 26.0) -> Image.Image:
    remapped, _vis, _info = pr.remap(im.convert("RGBA"))
    keyed = sp.key_to_alpha(remapped, spill_flood=False)
    fitted = sp.fit_canvas(_shrink_keyed(keyed), key=False)
    return finish_matte(fitted, rim, rim_hue)


def clean(im: Image.Image, rim: int, rim_hue: float) -> Image.Image:
    # I2V chroma pad (PAD_FRAC) is plate; keyed bbox is the figure, then 128-fit.
    return key_fit(im, rim, rim_hue)


def _seq_frame(name: str, prefix: str) -> bool:
    if not name.endswith(".png"):
        return False
    stem = name[:-4]
    head = prefix + "_"
    if not stem.startswith(head):
        return False
    return stem[len(head) :].isdigit()


def write_seq(frames: list[Image.Image], dest: Path, prefix: str) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob(f"{prefix}_*.png"):
        if _seq_frame(old.name, prefix):
            old.unlink()
    for i, im in enumerate(frames):
        im.save(dest / f"{prefix}_{i}.png")


def pack_idle(gender: str) -> None:
    bible = Image.open(BIBLES[gender]).convert("RGBA")
    cells = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(bible)))
    out = OUT / gender
    out.mkdir(parents=True, exist_ok=True)
    for k in KEYS:
        im = key_fit(cells[k], rim=0, rim_hue=26.0)
        im.save(out / f"idle_{k}.png")
        print("idle", gender, k)


def pack_clip(
    gender: str,
    facing: str,
    video: str,
    reuse: bool = False,
    rim: int = 2,
    rim_hue: float = 26.0,
) -> str:
    vid = Path(video)
    raw_dir = RAW / f"{gender}_{facing}"
    paths = extract(vid, raw_dir, reuse=reuse)
    images = [Image.open(p).convert("RGBA") for p in paths]
    start_p, mid_p, stop_p = split_phases(images, bible_cell(gender, facing), facing)
    idle = key_fit(bible_cell(gender, facing), rim=0, rim_hue=26.0)
    start_c = [clean(im, rim, rim_hue) for im in start_p]
    mid_c = [clean(im, rim, rim_hue) for im in mid_p]
    stop_c = [clean(im, rim, rim_hue) for im in stop_p]
    start_c = start_c[: START_N - 1] + [mid_c[0]] if start_c or mid_c else start_c
    if len(start_c) < START_N:
        start_c = _pad(([idle] if idle else []) + start_c, START_N)
    stop_c = (stop_c[: STOP_N - 1] + [idle]) if stop_c else [idle]
    if len(stop_c) < STOP_N:
        stop_c = _pad(stop_c, STOP_N)
    chained = start_c[:START_N] + mid_c + stop_c[:STOP_N]
    chained = lock_x(sp.lock_baselines(chained), idle)
    start_c = chained[:START_N]
    mid_c = chained[START_N : START_N + CYCLE_N]
    stop_c = chained[START_N + CYCLE_N :]
    dest = OUT / gender
    write_seq(start_c, dest, f"idle_to_walk_{facing}")
    write_seq(mid_c, dest, f"walk_{facing}")
    write_seq(stop_c, dest, f"walk_to_idle_{facing}")
    return f"packed {gender} {facing} frames {len(images)}"


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Pack walk I2V clips into engine frames.")
    parser.add_argument("--gender", action="append", choices=("male", "female"))
    parser.add_argument("--facing", action="append", choices=KEYS)
    parser.add_argument("--skip-idle", action="store_true")
    parser.add_argument("--reuse-harvest", action="store_true")
    parser.add_argument("--rim", type=int, default=2)
    parser.add_argument("--rim-hue", type=float, default=26.0)
    args = parser.parse_args(argv)
    genders = args.gender or ["male", "female"]
    facings = args.facing or list(KEYS)
    jobs: list[tuple[str, str, str, bool, int, float]] = []
    for gender in genders:
        if not args.skip_idle:
            pack_idle(gender)
        for facing in facings:
            vid = FINAL / f"{gender}_{facing}.mp4"
            if not vid.exists():
                print("missing", vid)
                continue
            jobs.append((gender, facing, str(vid), args.reuse_harvest, args.rim, args.rim_hue))
    if not jobs:
        return
    if len(jobs) == 1:
        print(pack_clip(*jobs[0]))
        return
    with ProcessPoolExecutor() as pool:
        futs = [
            pool.submit(pack_clip, gender, facing, video, reuse, rim, rim_hue)
            for gender, facing, video, reuse, rim, rim_hue in jobs
        ]
        for fut in as_completed(futs):
            print(fut.result())


if __name__ == "__main__":
    main()