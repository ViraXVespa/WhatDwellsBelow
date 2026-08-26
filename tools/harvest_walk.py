"""Extract evenly spaced walk frames from I2V clips (Section 19)."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import imageio_ffmpeg
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sprite_pipeline import fit_canvas, flatten_magenta_to_alpha, lock_baselines, quantize_palette, range_key

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
FRAME_COUNT = 6


def extract(video: Path, tmp: Path, fps: int = 12) -> list[Path]:
    tmp.mkdir(parents=True, exist_ok=True)
    for p in tmp.glob("f*.png"):
        p.unlink()
    cmd = [FFMPEG, "-y", "-i", str(video), "-vf", f"fps={fps}", str(tmp / "f%03d.png")]
    subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return sorted(tmp.glob("f*.png"))


def pick(paths: list[Path], count: int) -> list[Path]:
    if not paths:
        return []
    # skip first and last settling frames
    usable = paths[2:-2] if len(paths) > 10 else paths
    if len(usable) < count:
        usable = paths
    n = len(usable)
    idxs = [int(round(i * (n - 1) / (count - 1))) for i in range(count)]
    return [usable[i] for i in idxs]


def clean_frame(src: Path) -> Image.Image:
    im = range_key(Image.open(src))
    return quantize_palette(fit_canvas(im))


def harvest(video: Path, dest_dir: Path, prefix: str) -> list[Path]:
    tmp = Path("_src/walk_raw") / prefix
    frames = pick(extract(video, tmp), FRAME_COUNT)
    cleaned = [clean_frame(p) for p in frames]
    cleaned = lock_baselines(cleaned)
    dest_dir.mkdir(parents=True, exist_ok=True)
    out = []
    for i, im in enumerate(cleaned):
        p = dest_dir / f"{prefix}_{i}.png"
        im.save(p)
        out.append(p)
        print("wrote", p)
    return out


def flip_set(src_prefix: str, dest_prefix: str, folder: Path) -> None:
    for i in range(FRAME_COUNT):
        src = folder / f"{src_prefix}_{i}.png"
        dest = folder / f"{dest_prefix}_{i}.png"
        Image.open(src).transpose(Image.FLIP_LEFT_RIGHT).save(dest)
        print("flip", dest)


if __name__ == "__main__":
    # args: video dest_dir prefix
    harvest(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
