"""Extract, key, and pack walk-cycle frames from Imagine videos."""
from __future__ import annotations

import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import imageio_ffmpeg
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import plate_remap as pr  # noqa: E402
import sprite_pipeline as sp  # noqa: E402

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
SESSION_VID = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\videos"
)
RAW = ROOT / "_src" / "anim_frames"
OUT_PLAYER = ROOT / "assets" / "sprites" / "player"
CANVAS = 128
KEYED_CAP = 512
JOBS = {
    "down": SESSION_VID / "1.mp4",
    "left": SESSION_VID / "2.mp4",
    "right": SESSION_VID / "3.mp4",
    "up": SESSION_VID / "5.mp4",
}
ATTACK_JOBS = {
    "down": SESSION_VID / "4.mp4",
    "up": SESSION_VID / "6.mp4",
    "left": SESSION_VID / "7.mp4",
}


def extract(src: Path, dest_dir: Path, fps: int = 8) -> list[Path]:
    """Full-size RGB PNGs. Nearest chroma upsample; always re-extract."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    for old in dest_dir.glob("f*.png"):
        old.unlink()
    cmd = [
        FFMPEG,
        "-y",
        "-an",
        "-sws_flags",
        "neighbor+accurate_rnd+full_chroma_int",
        "-i",
        str(src),
        "-vf",
        f"fps={fps},format=rgb24",
        "-compression_level",
        "1",
        str(dest_dir / "f%03d.png"),
    ]
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return sorted(dest_dir.glob("f*.png"))


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


def fit(im: Image.Image, canvas: int = CANVAS) -> Image.Image:
    remapped, _vis, _info = pr.remap(im.convert("RGBA"))
    keyed = sp.key_to_alpha(remapped, spill_flood=False)
    return sp.fit_canvas(_shrink_keyed(keyed), canvas, key=False)


def pick_loop(paths: list[Path], count: int = 4) -> list[Path]:
    # skip first/last 15% (settle / drift), then even samples
    n = len(paths)
    a = max(1, int(n * 0.15))
    b = max(a + count, int(n * 0.85))
    span = paths[a:b]
    if len(span) <= count:
        return span
    step = len(span) / count
    return [span[int(i * step)] for i in range(count)]


def _pack_one(kind: str, facing: str, video: str) -> str:
    vid = Path(video)
    raw = extract(vid, RAW / f"player_{kind}_{facing}")
    chosen = pick_loop(raw, 4)
    wrote = []
    for i, src in enumerate(chosen):
        dest = OUT_PLAYER / f"{kind}_{facing}_{i}.png"
        fit(Image.open(src)).save(dest)
        wrote.append(dest.name)
    return f"{kind} {facing} " + " ".join(wrote)


def main() -> None:
    jobs: list[tuple[str, str, str]] = []
    for facing, vid in ATTACK_JOBS.items():
        if not vid.exists():
            print("missing attack", vid)
            continue
        jobs.append(("attack", facing, str(vid)))
    for facing, vid in JOBS.items():
        if not vid.exists():
            print("missing", vid)
            continue
        jobs.append(("walk", facing, str(vid)))
    if not jobs:
        return
    with ProcessPoolExecutor() as pool:
        futs = [pool.submit(_pack_one, kind, facing, video) for kind, facing, video in jobs]
        for fut in as_completed(futs):
            print(fut.result())


if __name__ == "__main__":
    main()