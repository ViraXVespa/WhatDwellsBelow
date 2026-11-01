#!/usr/bin/env python3
"""Zoom into the full-size original of a downsized shot (view the downsized PNG first; zoom only for a small detail).

    python tools/shots.py zoom SRC --box X,Y,W,H [--box ...] [--scale N] [--grid] [--space down|full] [--out PATH]
    python tools/shots.py zoom SRC --center X,Y --size W,H [--scale N]
    python tools/shots.py zoom SRC --rect-norm X0,Y0,X1,Y1          # fractions of the frame, 0..1 (same in both spaces)
SRC may be the downsized PNG: its original is SRC's dir /full/<same name> (shots.py capture/flow keep it at every scale,
only in ignored or out-of-repo dirs). Coordinates are in --space: `down` (default; pixels of SRC as you
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

def resolve(src: Path) -> tuple[Path | None, str]:
    """(kept original, note). None with the reason when it is missing, stale (written > 120 s apart from SRC) or a
    different aspect / smaller than SRC; the caller then zooms SRC itself and must say NO original."""
    from PIL import Image
    cands = [p for p in (src.parent / "full" / src.name, src.with_name(src.stem + "_full.png")) if p.is_file()]
    if not cands:
        return None, "NO original: none in full/"
    p = cands[0]
    if abs(p.stat().st_mtime - src.stat().st_mtime) > 120:
        return None, f"NO original: {p.name} is stale (written {abs(p.stat().st_mtime - src.stat().st_mtime):.0f}s apart)"
    (a, b), (c, d) = Image.open(p).size, Image.open(src).size
    if abs(a / b - c / d) > 0.01 or a < c:
        return None, f"NO original: {a}x{b} does not match {c}x{d} (aspect/size)"
    return p, f"original {a}x{b} for {c}x{d}, scale {a / c:.4g}x{b / d:.4g}"

def original(src: Path) -> Path | None:
    return resolve(src)[0]

def to_full(box, down_size, full_size) -> tuple[tuple[int, int, int, int], bool]:
    """(l,t,r,b) in downsized px -> full px with the per-axis ratio of the real sizes, floored left/top and ceiled
    right/bottom (never cut short), then clamped to the full frame. Returns (box, clamped)."""
    import math
    sx, sy = full_size[0] / down_size[0], full_size[1] / down_size[1]
    l, t, r, b = box
    raw = (math.floor(l * sx + 1e-9), math.floor(t * sy + 1e-9), math.ceil(r * sx - 1e-9), math.ceil(b * sy - 1e-9))
    out = (max(0, raw[0]), max(0, raw[1]), min(full_size[0], raw[2]), min(full_size[1], raw[3]))
    return out, out != raw

def _ints(text: str, n: int, what: str) -> list[float]:
    v = [float(x) for x in text.replace("x", ",").split(",")]
    if len(v) != n:
        raise ValueError(f"{what} needs {n} comma numbers")
    return v

def regions(args, down_size: tuple[int, int], full_size: tuple[int, int]) -> list[tuple[str, tuple[int, int, int, int]]]:
    """Each region as (label naming the requested box and the resolved full box, full-pixel box l,t,r,b)."""
    ref = full_size if args.space == "full" else down_size
    out = []
    for b in args.box or []:
        x, y, w, h = _ints(b, 4, "--box")
        out.append((f"box {b}", (x, y, x + w, y + h)))
    for c in args.center or []:
        x, y = _ints(c, 2, "--center")
        w, h = _ints(args.size, 2, "--size")
        out.append((f"at {c}", (x - w / 2, y - h / 2, x + w / 2, y + h / 2)))
    for r in args.rect_norm or []:
        x0, y0, x1, y1 = _ints(r, 4, "--rect-norm")
        out.append((f"norm {r}", (x0 * ref[0], y0 * ref[1], x1 * ref[0], y1 * ref[1])))
    res = []
    for lab, bx in out:
        box, clamped = to_full(bx, ref, full_size)
        if box[2] <= box[0] or box[3] <= box[1]:
            raise ValueError(f"{lab} is outside the image")
        res.append((f"{lab} ({args.space}) -> full {box[0]},{box[1]},{box[2] - box[0]}x{box[3] - box[1]}"
                    + (" clamped" if clamped else ""), box))
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
        if to_full((10, 10, 20, 20), (640, 360), (1920, 1080)) != ((30, 30, 60, 60), False):
            bad.append("1920->640 (3x) ratio wrong")
        if to_full((1, 1, 2, 2), (333, 187), (1000, 563)) != ((3, 3, 7, 7), False):
            bad.append("odd sizes must round outward")
        import random
        for _ in range(200):  # outward: the full box always covers the exact scaled box
            l, u = random.uniform(0, 300), random.uniform(0, 170)
            (L, T, R, B), _c = to_full((l, u, l + 5.3, u + 4.1), (333, 187), (1000, 563))
            if L > l * 1000 / 333 or T > u * 563 / 187 or (R < min(1000, (l + 5.3) * 1000 / 333) - 1e-6) or (B < min(563, (u + 4.1) * 563 / 187) - 1e-6):
                bad.append("outward rounding cut a box short"); break
        if to_full((630, 350, 650, 370), (640, 360), (1920, 1080)) != ((1890, 1050, 1920, 1080), True):
            bad.append("edge clamp not reported")
        Image.new("RGBA", (200, 120)).save(t / "m.png")
        full.save(t / "full" / "m.png")
        if original(t / "m.png") or "aspect" not in resolve(t / "m.png")[1]:
            bad.append("mismatched aspect must be NO original")
        Image.new("RGBA", (50, 25)).save(t / "lone.png")
        if "none in full/" not in resolve(t / "lone.png")[1]:
            bad.append("missing original must say NO original")
        import os
        os.utime(t / "full" / "s.png", (1, 1))
        if "stale" not in resolve(t / "s.png")[1]:
            bad.append("stale original must be NO original")
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
    orig, note = resolve(src)
    down = imgio.load(src)
    im = imgio.load(orig) if orig else down
    try:
        regs = regions(args, down.size, im.size)
    except ValueError as e:
        agent_log.fail(str(e))
    if not regs:
        agent_log.fail("give --box, --center/--size or --rect-norm")
    tiles = [zoom(im, b, max(1, args.scale), args.grid) for _, b in regs]
    labels = [lab for lab, _ in regs]
    out_im = tiles[0] if len(tiles) == 1 else compare.montage(tiles, labels)
    out = Path(args.out) if args.out else root / "_logs" / "shot-zoom" / f"{src.stem}-zoom.png"
    imgio.save(out_im, out)
    lines = [f"source={orig or src} ({note}{'' if orig else '; zoomed the downsized PNG'}) {im.width}x{im.height}, viewed {down.width}x{down.height}, space={args.space}"]
    lines += [f"  {l}" for l in labels] + [f"out={out} {out_im.width}x{out_im.height}"]
    return agent_log.finish("shot-zoom", root, "\n".join(lines), "PASS", args=args, echo="\n".join(lines), regions=len(regs), original=int(bool(orig)))

if __name__ == "__main__":
    raise SystemExit(main())
