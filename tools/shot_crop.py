#!/usr/bin/env python3
"""Crop, zoom and probe a shot PNG, so a detail or a pixel question needs no ad hoc script.

    python tools/shot_crop.py PNG --box X,Y,W,H [--zoom N] [--out PATH]    # crop (and enlarge N times, nearest) to a PNG; open it with show_png.py or read it
    python tools/shot_crop.py PNG --probe X,Y [X,Y ...]                    # RGBA and hex at each point
    python tools/shot_crop.py PNG [--box X,Y,W,H] --near HEX [--tol N]     # count and bounding box of pixels within N of a colour (default tol 8)
    python tools/shot_crop.py PNG [--box X,Y,W,H] --dark N                 # count and bounding box of pixels whose R, G and B are all <= N
Coordinates are image pixels, origin top-left. A box outside the image fails. Default --out: _logs/shot-crop/<name>-X-Y-WxH[-zN].png.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def parse_box(text: str) -> tuple[int, int, int, int]:
    p = [int(v) for v in text.replace("x", ",").split(",")]
    if len(p) != 4 or p[2] <= 0 or p[3] <= 0:
        raise ValueError("--box is X,Y,W,H with W and H above 0")
    return p[0], p[1], p[2], p[3]


def parse_hex(text: str) -> tuple[int, int, int]:
    h = text.lstrip("#")
    if len(h) != 6:
        raise ValueError("--near is a #rrggbb colour")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def stats(arr, mask, ox: int, oy: int) -> str:
    """'count=N bbox=x,y,w,h' (image coordinates) of the True cells of mask."""
    import numpy as np

    n = int(mask.sum())
    if not n:
        return "count=0 bbox=none"
    ys, xs = np.where(mask)
    return "count=%d bbox=%d,%d,%d,%d" % (n, xs.min() + ox, ys.min() + oy, xs.max() - xs.min() + 1, ys.max() - ys.min() + 1)


def run(png: Path, args) -> list[str]:
    import numpy as np
    from imglib import imgio

    im = imgio.load(png)
    w, h = im.size
    out: list[str] = [f"{png.name} {w}x{h}"]
    box = parse_box(args.box) if args.box else (0, 0, w, h)
    x, y, bw, bh = box
    if x < 0 or y < 0 or x + bw > w or y + bh > h:
        raise ValueError(f"box {x},{y},{bw},{bh} is outside the {w}x{h} image")
    for pt in args.probe:
        px, py = [int(v) for v in pt.split(",")]
        if not (0 <= px < w and 0 <= py < h):
            raise ValueError(f"point {pt} is outside the {w}x{h} image")
        r, g, b, a = im.getpixel((px, py))
        out.append(f"probe {px},{py} rgba=({r},{g},{b},{a}) #{r:02x}{g:02x}{b:02x}")
    arr = imgio.to_np(im)[y:y + bh, x:x + bw]
    if args.near:
        r, g, b = parse_hex(args.near)
        d = np.abs(arr[:, :, :3].astype(int) - np.array([r, g, b])).max(axis=2)
        out.append("near #%02x%02x%02x tol=%d %s" % (r, g, b, args.tol, stats(arr, d <= args.tol, x, y)))
    if args.dark is not None:
        out.append("dark <=%d %s" % (args.dark, stats(arr, (arr[:, :, :3] <= args.dark).all(axis=2), x, y)))
    if args.box or args.out or not (args.probe or args.near or args.dark is not None):
        crop = im.crop((x, y, x + bw, y + bh))
        if args.zoom > 1:
            crop = crop.resize((bw * args.zoom, bh * args.zoom), 0)
        dest = Path(args.out) if args.out else Path("_logs/shot-crop") / f"{png.stem}-{x}-{y}-{bw}x{bh}{'-z%d' % args.zoom if args.zoom > 1 else ''}.png"
        out.append("crop " + str(imgio.save(crop, dest)))
    return out


def selftest() -> int:
    import subprocess
    import tempfile

    from imglib import imgio
    from PIL import Image

    bad: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        f = Path(td) / "a.png"
        im = Image.new("RGBA", (20, 10), (0, 0, 0, 255))
        im.putpixel((5, 4), (200, 100, 50, 255))
        imgio.save(im, f)

        def run_me(*a: str) -> subprocess.CompletedProcess:
            return subprocess.run([sys.executable, str(Path(__file__).resolve()), str(f), *a], capture_output=True, text=True)

        p = run_me("--probe", "5,4")
        if "rgba=(200,100,50,255) #c86432" not in p.stdout:
            bad.append("probe prints the pixel: " + p.stdout)
        p = run_me("--near", "#c86432", "--tol", "2")
        if "count=1 bbox=5,4,1,1" not in p.stdout:
            bad.append("near finds the one pixel: " + p.stdout)
        p = run_me("--dark", "0")
        if "count=199" not in p.stdout:
            bad.append("dark counts the 199 black pixels: " + p.stdout)
        o = Path(td) / "c.png"
        p = run_me("--box", "4,3,4,3", "--zoom", "3", "--out", str(o))
        if p.returncode != 0 or not o.is_file() or imgio.load(o).size != (12, 9):
            bad.append("box + zoom writes a 12x9 crop: " + p.stdout + p.stderr)
        if run_me("--box", "18,8,5,5").returncode == 0:
            bad.append("a box outside the image must fail")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Crop, zoom and probe a shot PNG.")
    ap.add_argument("png", nargs="?", help="The PNG to look at.")
    ap.add_argument("--box", default="", metavar="X,Y,W,H", help="Region (crop, and the area --near / --dark count in).")
    ap.add_argument("--zoom", type=int, default=1, help="Enlarge the crop N times (nearest).")
    ap.add_argument("--out", default="", help="Crop PNG path (default under _logs/shot-crop/).")
    ap.add_argument("--probe", nargs="+", default=[], metavar="X,Y", help="Print RGBA and hex at these points.")
    ap.add_argument("--near", default="", metavar="HEX", help="Count and bounding box of pixels within --tol of #rrggbb.")
    ap.add_argument("--tol", type=int, default=8, help="Per-channel tolerance for --near (default 8).")
    ap.add_argument("--dark", type=int, default=None, metavar="N", help="Count and bounding box of pixels with R, G, B all <= N.")
    ap.add_argument("--selftest", action="store_true", help="Run the built-in cases.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    if not args.png:
        agent_log.fail("pass the PNG (example: python tools/shot_crop.py _logs/shot-flow/camp-npc-panels/01-vendor.png --box 100,80,300,200 --zoom 3)")
    png = Path(args.png)
    if not png.is_file():
        agent_log.fail(f"not a file: {png}")
    try:
        lines = run(png, args)
    except ValueError as e:
        agent_log.fail(str(e))
    print("\n".join(lines))
    return agent_log.emit_result("PASS", png=png.name)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
