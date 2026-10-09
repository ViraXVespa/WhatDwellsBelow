#!/usr/bin/env python3
"""Section 19 cleanup: Paint.NET-style outside wand + Color-to-Alpha lip + 128 fit."""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
import agent_log  # noqa: E402
from imglib import geom, imgio, key  # noqa: E402

MAGENTA = imgio.MAGENTA_RGBA
KEY_RGB = imgio.MAGENTA
CANVAS = 128
PAD = 8
WAND_DIST = key.WAND_DIST
TIGHT_DIST = key.TIGHT_DIST
MATTE_CUT = key.MATTE_CUT


def _dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def _as_rgba(im: Image.Image) -> np.ndarray:
    return imgio.to_np(im)


def key_to_alpha(im: Image.Image, spill_flood: bool = True) -> Image.Image:
    """Colour-to-alpha against the border plate (imglib.key.key_to_alpha).

    Glow and soft edges stay partial. `spill_flood` is accepted and does not switch paths.
    """
    return key.key_to_alpha(im, spill_flood=spill_flood)


def range_key(im: Image.Image) -> Image.Image:
    """Bible / seed path: wand the outside, flatten that region to exact #FF00FF."""
    keyed = key_to_alpha(im)
    arr = _as_rgba(keyed)
    arr[arr[:, :, 3] == 0] = np.array(MAGENTA, dtype=np.uint8)
    return Image.fromarray(arr, "RGBA")


def flatten_magenta_to_alpha(im: Image.Image, spill_flood: bool = True) -> Image.Image:
    return key_to_alpha(im, spill_flood=spill_flood)


def split_equal_3x3(im: Image.Image) -> list[Image.Image]:
    return geom.grid_split(im, 3, 3)


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
    return geom.fit_box(im, canvas, PAD, oy=lambda nh: max(0, min(canvas - nh, canvas - nh - 2 if baseline is None else baseline - nh)))


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
        im = imgio.load(p)
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
    key_d = key.rgb_dist(rgb, [KEY_RGB])
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


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Sprite pipeline: seeds | key (matte + 128 fit) | matte | flatten.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("seeds", help="Extract seeds: SRC DEST_DIR")
    s.add_argument("src", type=Path, help="Source image."); s.add_argument("dest", type=Path, help="Output folder for the seed cells.")
    for name, helptext in (("key", "matte + 128 fit"), ("alpha", "alias of key"), ("fit", "alias of key"),
                           ("matte", "matte only"), ("flatten", "range-key flatten")):
        s = sub.add_parser(name, help=f"SRC.png DEST.png ({helptext})")
        s.add_argument("src", type=Path, help="Source image."); s.add_argument("dest", type=Path, help="Output PNG path.")
    args = ap.parse_args(argv)
    if args.cmd == "seeds":
        print(json.dumps(extract_seeds(args.src, args.dest), indent=2))
    else:
        args.dest.parent.mkdir(parents=True, exist_ok=True)
        fn = {"key": fit_canvas, "alpha": fit_canvas, "fit": fit_canvas, "matte": key_to_alpha, "flatten": range_key}[args.cmd]
        fn(Image.open(args.src)).save(args.dest)
        print("wrote " + args.dest.as_posix())
    return agent_log.emit_result("PASS", cmd=args.cmd)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
