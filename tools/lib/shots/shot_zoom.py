#!/usr/bin/env python3
"""Zoom into the full-size original of a downsized shot (view the downsized PNG first; zoom only for a small detail).

    python tools/shots.py zoom SRC --box X,Y,W,H [--box ...] [--scale N] [--grid] [--space down|full] [--out PATH]
    python tools/shots.py zoom SRC --center X,Y --size W,H [--scale N]
    python tools/shots.py zoom SRC --rect-norm X0,Y0,X1,Y1          # fractions of the frame, 0..1 (same in both spaces)
SRC may be the downsized PNG: its original is SRC's dir /full/<same name> (shots.py capture/flow keep it for scales
below 100, only in ignored or out-of-repo dirs). Coordinates are in --space: `down` (default; pixels of SRC as you
viewed it, mapped by the width ratio) or `full` (pixels of the original). --scale enlarges nearest-neighbour (exact
N x N blocks); --grid draws a 1-px line every original pixel at --scale >= 4. Several regions make one labeled montage.
Default --out: _logs/shot-zoom/<name>-zoom.png. No original found: crops SRC itself and says so.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))  # tools/ (imglib)
import boot  # noqa: E402,F401
import agent_log
from imglib import compare, geom, imgio

def original(src: Path) -> Path | None:
    """The kept original, if it is newer than SRC's run and the same aspect (else a stale one from an older shot)."""
    from PIL import Image
    for p in (src.parent / "full" / src.name, src.with_name(src.stem + "_full.png")):
        if p.is_file() and abs(p.stat().st_mtime - src.stat().st_mtime) < 120:
            (a, b), (c, d) = Image.open(p).size, Image.open(src).size
            if abs(a / b - c / d) < 0.01 and a >= c:
                return p
    return None

def _ints(text: str, n: int, what: str) -> list[float]:
    v = [float(x) for x in text.replace("x", ",").split(",")]
    if len(v) != n:
        raise ValueError(f"{what} needs {n} comma numbers")
    return v

def regions(args, down_size: tuple[int, int], full_size: tuple[int, int]) -> list[tuple[str, tuple[int, int, int, int]]]:
    """Each region as (label, full-pixel box l,t,r,b)."""
    fx, fy = full_size[0] / down_size[0], full_size[1] / down_size[1]
    k = (1.0, 1.0) if args.space == "full" else (fx, fy)
    out = []
    for b in args.box or []:
        x, y, w, h = _ints(b, 4, "--box")
        out.append((f"box {b}", (x * k[0], y * k[1], (x + w) * k[0], (y + h) * k[1])))
    for c in args.center or []:
        x, y = _ints(c, 2, "--center")
        w, h = _ints(args.size, 2, "--size")
        out.append((f"at {c}", ((x - w / 2) * k[0], (y - h / 2) * k[1], (x + w / 2) * k[0], (y + h / 2) * k[1])))
    for r in args.rect_norm or []:
        x0, y0, x1, y1 = _ints(r, 4, "--rect-norm")
        out.append((f"norm {r}", (x0 * full_size[0], y0 * full_size[1], x1 * full_size[0], y1 * full_size[1])))
    res = []
    for lab, (l, t, r_, b_) in out:
        box = (max(0, round(l)), max(0, round(t)), min(full_size[0], round(r_)), min(full_size[1], round(b_)))
        if box[2] <= box[0] or box[3] <= box[1]:
            raise ValueError(f"{lab} is outside the image")
        res.append((lab, box))
    return res

def zoom(im, box, scale: int, grid: bool):
    c = geom.scale_nearest(im.crop(box), scale) if scale > 1 else im.crop(box)
    if grid and scale >= 4:
        px = c.load()
        for x in range(0, c.width, scale):
            for y in range(c.height):
                px[x, y] = (0, 0, 0, 255)
        for y in range(0, c.height, scale):
            for x in range(c.width):
                px[x, y] = (0, 0, 0, 255)
    return c

def selftest() -> int:
    import tempfile
    from PIL import Image
    bad = []
    with tempfile.TemporaryDirectory() as td:
        t = Path(td)
        full = Image.new("RGBA", (400, 200), (0, 0, 0, 255))
        for x in range(400):
            for y in range(200):
                full.putpixel((x, y), (x % 256, y, (x // 256) * 100, 255))
        (t / "full").mkdir()
        full.save(t / "full" / "s.png")
        full.resize((200, 100)).save(t / "s.png")
        src = original(t / "s.png")
        if src != t / "full" / "s.png":
            bad.append(f"original() did not resolve full/: {src}")
        ns = build_parser().parse_args([str(t / "s.png"), "--box", "10,20,5,4", "--center", "50,50", "--size", "10,10", "--rect-norm", "0.5,0.5,0.6,0.6"])
        regs = regions(ns, (200, 100), (400, 200))
        if [b for _, b in regs] != [(20, 40, 30, 48), (90, 90, 110, 110), (200, 100, 240, 120)]:
            bad.append(f"down->full mapping wrong: {regs}")
        ns.space = "full"
        if regions(ns, (200, 100), (400, 200))[0][1] != (10, 20, 15, 24):
            bad.append("--space full must keep the box")
        z = zoom(full, (20, 40, 30, 48), 3, False)
        if z.size != (30, 24) or any(z.getpixel((i * 3 + d, 0)) != full.getpixel((20 + i, 40)) for i in range(10) for d in range(3)):
            bad.append("nearest scale is not exact 3x3 blocks of the original")
    for b in bad:
        print("FAIL " + b)
    print(f"RESULT {'FAIL' if bad else 'PASS'} selftest shot-zoom")
    return 1 if bad else 0

def build_parser():
    ap = agent_log.std_parser(__doc__.split("\n")[0])
    ap.add_argument("src", nargs="?", default="", help="Shot PNG (the downsized one is fine: its full/ original is used).")
    ap.add_argument("--box", action="append", help="X,Y,W,H in --space pixels (repeat for a montage).")
    ap.add_argument("--center", action="append", help="X,Y centre in --space pixels, with --size.")
    ap.add_argument("--size", default="64,64", help="W,H for --center (default 64,64).")
    ap.add_argument("--rect-norm", dest="rect_norm", action="append", help="X0,Y0,X1,Y1 as 0..1 fractions of the frame.")
    ap.add_argument("--space", choices=("down", "full"), default="down", help="down = pixels of SRC as viewed (default); full = pixels of the original.")
    ap.add_argument("--scale", type=int, default=4, help="Nearest-neighbour enlarge factor (default 4; 1 = none).")
    ap.add_argument("--grid", action="store_true", help="Pixel grid lines at --scale >= 4.")
    ap.add_argument("--out", default="", help="Output PNG (default _logs/shot-zoom/<name>-zoom.png).")
    ap.add_argument("--selftest", action="store_true", help="Synthetic image: downsized coords map to the original; nearest scale is exact.")
    return ap

def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(sys.argv[1:] if argv is None else argv)
    if args.selftest:
        return selftest()
    root = agent_log.resolve_root(args)
    src = Path(args.src)
    if not src.is_file():
        agent_log.fail(f"no such PNG: {src}")
    orig = original(src)
    down = imgio.load(src)
    im = imgio.load(orig) if orig else down
    try:
        regs = regions(args, down.size, im.size)
    except ValueError as e:
        agent_log.fail(str(e))
    if not regs:
        agent_log.fail("give --box, --center/--size or --rect-norm")
    tiles = [zoom(im, b, max(1, args.scale), args.grid) for _, b in regs]
    labels = [f"{lab} -> full {b[0]},{b[1]},{b[2] - b[0]}x{b[3] - b[1]}" for lab, b in regs]
    out_im = tiles[0] if len(tiles) == 1 else compare.montage(tiles, labels)
    out = Path(args.out) if args.out else root / "_logs" / "shot-zoom" / f"{src.stem}-zoom.png"
    imgio.save(out_im, out)
    lines = [f"source={orig or src} ({'original' if orig else 'NO original: zoomed the downsized PNG'}) {im.width}x{im.height}, viewed {down.width}x{down.height}, space={args.space}"]
    lines += [f"  {l}" for l in labels] + [f"out={out} {out_im.width}x{out_im.height}"]
    return agent_log.finish("shot-zoom", root, "\n".join(lines), "PASS", args=args, echo="\n".join(lines), regions=len(regs), original=int(bool(orig)))

if __name__ == "__main__":
    raise SystemExit(main())
