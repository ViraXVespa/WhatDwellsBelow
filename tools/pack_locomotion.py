"""Pack idle stills + idle_to_walk / walk / walk_to_idle from I2V clips."""
from __future__ import annotations

import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import imageio_ffmpeg
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


def extract(video: Path, dest: Path, fps: int = 8) -> list[Path]:
    """Full-size RGB PNGs. Nearest chroma upsample; no pre-key shrink."""
    dest.mkdir(parents=True, exist_ok=True)
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
    bible = Image.open(BIBLES[gender]).convert("RGBA")
    cells = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(bible)))
    return cells[facing]


def _stamp(im: Image.Image, size: tuple[int, int] = COMPARE_SIZE) -> Image.Image:
    """Plate-ignored figure stamp for idle compare. Not a shipping matte."""
    im = im.convert("RGBA").resize(size, Image.Resampling.NEAREST)
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            if sp._dist((r, g, b), sp.KEY_RGB) <= 40:
                continue
            op[x, y] = (r, g, b, 255)
    bbox = out.getbbox()
    if bbox is None:
        return Image.new("RGB", size, (0, 0, 0))
    crop = out.crop(bbox).convert("RGB")
    cw, ch = crop.size
    scale = min(size[0] / cw, size[1] / ch)
    nw = max(1, int(cw * scale))
    nh = max(1, int(ch * scale))
    rsz = crop.resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGB", size, (0, 0, 0))
    canvas.paste(rsz, ((size[0] - nw) // 2, size[1] - nh))
    return canvas


def _mad(a: Image.Image, b: Image.Image) -> float:
    pa, pb = a.tobytes(), b.tobytes()
    n = len(pa)
    return sum(abs(pa[i] - pb[i]) for i in range(n)) / max(1, n)


def _smooth(vals: list[float], radius: int = 2) -> list[float]:
    out: list[float] = []
    for y in range(len(vals)):
        w = vals[max(0, y - radius) : y + radius + 1]
        out.append(sum(w) / len(w))
    return out


def idle_scores(paths: list[Path], ref: Image.Image) -> list[float]:
    stamp = _stamp(ref)
    return [_mad(_stamp(Image.open(p)), stamp) for p in paths]


def _pad(paths: list[Path], n: int) -> list[Path]:
    if not paths:
        return []
    out = list(paths)
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


def _split_time(paths: list[Path]) -> tuple[list[Path], list[Path], list[Path]]:
    n = len(paths)
    if n < START_N + CYCLE_N + STOP_N:
        return _pad(paths[:START_N], START_N), pick(paths, CYCLE_N), _pad(paths[-STOP_N:], STOP_N)
    a = START_N
    b = n - STOP_N
    return _pad(paths[:a], START_N), pick(paths[a:b], CYCLE_N), _pad(paths[b:], STOP_N)


def split_phases(paths: list[Path], ref: Image.Image) -> tuple[list[Path], list[Path], list[Path]]:
    """Idle-compare for in/out, then one self-similar stride loop for walk."""
    n = len(paths)
    if n < START_N + CYCLE_N + STOP_N:
        return _split_time(paths)
    stamps = [_stamp(Image.open(p)) for p in paths]
    ref_s = _stamp(ref)
    scores = [_mad(s, ref_s) for s in stamps]
    sm = _smooth(scores)
    lo, hi = min(sm), max(sm)
    if hi - lo < 1.0:
        return _split_time(paths)
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
        return _split_time(paths)
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
    start = _pad(paths[max(prefix, loop0 - START_N) : loop0], START_N)
    mid = pick(paths[loop0:loop1], CYCLE_N)
    stop = _pad(paths[max(loop1, suffix - STOP_N) : suffix], STOP_N)
    print(
        f"  loop n={n} prefix={prefix} suffix={suffix} period={period} "
        f"start={max(prefix, loop0 - START_N)}:{loop0} walk={loop0}:{loop1} "
        f"stop={max(loop1, suffix - STOP_N)}:{suffix} score {lo:.1f}-{hi:.1f}"
    )
    return start, mid, stop


def pick(paths: list[Path], n: int) -> list[Path]:
    if not paths:
        return []
    if len(paths) <= n:
        return list(paths)
    return [paths[int(round(i * (len(paths) - 1) / (n - 1)))] for i in range(n)]


def key_fit(im: Image.Image) -> Image.Image:
    remapped, _vis, _info = pr.remap(im.convert("RGBA"))
    keyed = sp.key_to_alpha(remapped, spill_flood=False)
    return sp.fit_canvas(_shrink_keyed(keyed), key=False)


def clean(src: Path) -> Image.Image:
    # I2V chroma pad (PAD_FRAC) is plate; keyed bbox is the figure, then 128-fit.
    return key_fit(Image.open(src))


def write_seq(frames: list[Image.Image], dest: Path, prefix: str) -> None:
    frames = sp.lock_baselines(frames)
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob(f"{prefix}_*.png"):
        old.unlink()
    for i, im in enumerate(frames):
        im.save(dest / f"{prefix}_{i}.png")


def pack_idle(gender: str) -> None:
    bible = Image.open(BIBLES[gender]).convert("RGBA")
    cells = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(bible)))
    out = OUT / gender
    out.mkdir(parents=True, exist_ok=True)
    for k in KEYS:
        im = key_fit(cells[k])
        im.save(out / f"idle_{k}.png")
        print("idle", gender, k)


def pack_clip(gender: str, facing: str, video: str) -> str:
    vid = Path(video)
    raw_dir = RAW / f"{gender}_{facing}"
    paths = extract(vid, raw_dir)
    start_p, mid_p, stop_p = split_phases(paths, bible_cell(gender, facing))
    dest = OUT / gender
    write_seq([clean(p) for p in start_p], dest, f"idle_to_walk_{facing}")
    write_seq([clean(p) for p in mid_p], dest, f"walk_{facing}")
    write_seq([clean(p) for p in stop_p], dest, f"walk_to_idle_{facing}")
    return f"packed {gender} {facing} frames {len(paths)}"


def main() -> None:
    jobs: list[tuple[str, str, str]] = []
    for gender in ("male", "female"):
        pack_idle(gender)
        for facing in KEYS:
            vid = FINAL / f"{gender}_{facing}.mp4"
            if not vid.exists():
                print("missing", vid)
                continue
            jobs.append((gender, facing, str(vid)))
    if not jobs:
        return
    with ProcessPoolExecutor() as pool:
        futs = [pool.submit(pack_clip, g, f, v) for g, f, v in jobs]
        for fut in as_completed(futs):
            print(fut.result())


if __name__ == "__main__":
    main()