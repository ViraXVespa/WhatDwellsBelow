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
KEYS = list(i2v_seeds.BODY_CELLS)
COMPARE_SIZE = (48, 72)
IDLE_FRAC = 0.18
KEYED_CAP = 512
RIM_HUE = 300.0
RIM_SAT_MIN = 0.12
RIM_KEY_DIST = 110.0
PINK_EXCESS = 10
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


def _best_period(stamps: list[Image.Image], lo: int = 6, hi: int = 20) -> int:
    n = len(stamps)
    if n < lo * 2:
        return max(lo, min(n, CYCLE_N))
    best_p = CYCLE_N
    best_c = 1e9
    cap = min(hi, n // 2)
    for per in range(lo, cap + 1):
        costs = [_mad(stamps[i], stamps[i + per]) for i in range(n - per)]
        cost = sum(costs) / max(1, len(costs))
        if cost < best_c:
            best_c = cost
            best_p = per
    return best_p


def _split_time(images: list[Image.Image]) -> tuple[list[Image.Image], list[Image.Image], list[Image.Image]]:
    n = len(images)
    if n < START_N + CYCLE_N + STOP_N:
        return _pad(images[:START_N], START_N), pick(images, CYCLE_N), _pad(images[-STOP_N:], STOP_N)
    a = START_N
    b = n - STOP_N
    return _pad(images[:a], START_N), pick(images[a:b], CYCLE_N), _pad(images[b:], STOP_N)


def split_phases(
    images: list[Image.Image], ref: Image.Image
) -> tuple[list[Image.Image], list[Image.Image], list[Image.Image]]:
    """Idle-compare for in/out, then one self-similar stride loop for walk."""
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
    walk0 = min(suffix - CYCLE_N, prefix + START_N)
    walk1 = max(walk0 + CYCLE_N, suffix)
    walk_stamps = stamps[walk0:walk1]
    period = _best_period(walk_stamps)
    off = 0
    best = 1e9
    room = max(1, len(walk_stamps) - period)
    span = max(1, int(room * 0.55))
    target = int(room * 0.28)
    for i in range(span):
        cost = _mad(walk_stamps[i], walk_stamps[min(len(walk_stamps) - 1, i + period)])
        cost += abs(i - target) * 0.08
        if cost < best:
            best = cost
            off = i
    loop0 = walk0 + off
    loop1 = min(suffix, loop0 + period)
    start = _pad(images[max(prefix, loop0 - START_N) : loop0], START_N)
    mid = pick(images[loop0:loop1], CYCLE_N)
    stop = _pad(images[max(loop1, suffix - STOP_N) : suffix], STOP_N)
    print(
        f"  loop n={n} prefix={prefix} suffix={suffix} period={period} "
        f"start={max(prefix, loop0 - START_N)}:{loop0} walk={loop0}:{loop1} "
        f"stop={max(loop1, suffix - STOP_N)}:{suffix} score {lo:.1f}-{hi:.1f}"
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


def write_seq(frames: list[Image.Image], dest: Path, prefix: str, rim: int, rim_hue: float) -> None:
    frames = [finish_matte(im, rim, rim_hue) for im in sp.lock_baselines(frames)]
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
    start_p, mid_p, stop_p = split_phases(images, bible_cell(gender, facing))
    dest = OUT / gender
    write_seq([clean(im, rim, rim_hue) for im in start_p], dest, f"idle_to_walk_{facing}", rim, rim_hue)
    write_seq([clean(im, rim, rim_hue) for im in mid_p], dest, f"walk_{facing}", rim, rim_hue)
    write_seq([clean(im, rim, rim_hue) for im in stop_p], dest, f"walk_to_idle_{facing}", rim, rim_hue)
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