#!/usr/bin/env python3
"""Crop, zoom and probe a shot PNG, so a detail or a pixel question needs no ad hoc script.

    python tools/shots.py crop PNG --box X,Y,W,H [--zoom N] [--out PATH]    # crop (and enlarge N times, nearest) to a PNG; open it with shots.py show or read it
    python tools/shots.py crop PNG --probe X,Y [X,Y ...]                    # RGBA and hex at each point
    python tools/shots.py crop PNG [--box X,Y,W,H] --near HEX [--tol N]     # count and bounding box of pixels within N of a colour (default tol 8)
    python tools/shots.py crop PNG [--box X,Y,W,H] --dark N                 # count and bounding box of pixels whose R, G and B are all <= N
    python tools/shots.py crop PNG --spans [--step N] [--bg HEX] [--fg HEX] # connected foreground runs per row, each with its centre colour, plus the figure box
    python tools/shots.py crop MODEL --overlay REF --scale S --anchor-ref X,Y --anchor-model X,Y [--opacity A] [--flip-x] [--out PATH]
        # nearest-scale REF, land anchor-ref on anchor-model, blend REF at opacity over the whole frame, print outer-edge deltas
Coordinates are image pixels, origin top-left. A box outside the image fails. Default --out: _logs/shot-crop/<name>-X-Y-WxH[-zN].png.
A pixel is foreground when its alpha is at least 128. --bg drops pixels within --tol of that colour. --fg keeps only pixels within --tol of that colour.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
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

def foreground(arr, tol: int, bg, fg):
    """Opaque pixels, minus --bg, and only --fg when that colour is set."""
    import numpy as np

    rgb = arr[:, :, :3].astype(int)
    alpha = arr[:, :, 3] if arr.shape[2] > 3 else np.full(rgb.shape[:2], 255, dtype=int)
    mask = alpha >= 128
    if bg is not None:
        mask &= np.abs(rgb - np.array(bg)).max(axis=2) > tol
    if fg is not None:
        mask &= np.abs(rgb - np.array(fg)).max(axis=2) <= tol
    return mask

def runs_of(row) -> list[tuple[int, int]]:
    """Inclusive [start, end] columns where row is True."""
    found: list[tuple[int, int]] = []
    start = -1
    for index, on in enumerate(row):
        if on and start < 0:
            start = index
        elif not on and start >= 0:
            found.append((start, index - 1))
            start = -1
    if start >= 0:
        found.append((start, len(row) - 1))
    return found

def span_report(arr, ox: int, oy: int, step: int, tol: int, bg, fg) -> list[str]:
    import numpy as np

    mask = foreground(arr, tol, bg, fg)
    if not mask.any():
        return ["figure none"]
    ys, xs = np.where(mask)
    y0, y1 = int(ys.min()), int(ys.max())
    x0, x1 = int(xs.min()), int(xs.max())
    lines = [
        "figure y=%d-%d h=%d x=%d-%d w=%d" % (
            y0 + oy, y1 + oy, y1 - y0 + 1, x0 + ox, x1 + ox, x1 - x0 + 1,
        )
    ]
    rows = list(range(y0, y1 + 1, step))
    if rows[-1] != y1:
        rows.append(y1)
    for row in rows:
        parts = []
        for start, end in runs_of(mask[row]):
            mid = (start + end) // 2
            pix = arr[row, mid, :3]
            parts.append(
                "x=%d-%d w=%d #%02x%02x%02x"
                % (start + ox, end + ox, end - start + 1, int(pix[0]), int(pix[1]), int(pix[2]))
            )
        lines.append("y=%d %s" % (row + oy, " | ".join(parts)))
    return lines

def parse_point(text: str) -> tuple[float, float]:
    p = [float(v) for v in text.split(",")]
    if len(p) != 2:
        raise ValueError("anchor is X,Y")
    return p[0], p[1]

def run_text(runs, ox: int) -> str:
    if not runs:
        return "none"
    return " | ".join("x=%d-%d w=%d" % (s + ox, e + ox, e - s + 1) for s, e in runs)

def blend_overlay(model, ref, opacity: float, scale: float, anchor_ref, anchor_model, flip_x: bool):
    """Nearest-scale ref so anchor_ref lands on anchor_model. Returns image, left, top, scaled rgba."""
    from imglib import imgio
    from PIL import Image

    if flip_x:
        ref = ref.transpose(Image.FLIP_LEFT_RIGHT)
    sw = max(1, int(round(ref.width * scale)))
    sh = max(1, int(round(ref.height * scale)))
    scaled = ref.resize((sw, sh), 0)
    sx = sw / ref.width
    sy = sh / ref.height
    left = int(round(anchor_model[0] - (anchor_ref[0] + 0.5) * sx))
    top = int(round(anchor_model[1] - (anchor_ref[1] + 0.5) * sy))
    base = imgio.to_np(model)
    over = imgio.to_np(scaled)
    height, width = base.shape[:2]
    x0, y0 = max(0, left), max(0, top)
    x1, y1 = min(width, left + sw), min(height, top + sh)
    if x1 <= x0 or y1 <= y0:
        raise ValueError("overlay misses the model image")
    src = over[y0 - top:y1 - top, x0 - left:x1 - left]
    alpha = (src[:, :, 3].astype("float32") * float(opacity)) / 255.0
    alpha = alpha[:, :, None]
    dest = base[y0:y1, x0:x1, :3].astype("float32")
    rgb = src[:, :, :3].astype("float32")
    base[y0:y1, x0:x1, :3] = (dest * (1.0 - alpha) + rgb * alpha).clip(0, 255).astype("uint8")
    return imgio.from_np(base), left, top, over

def overlay_report(model_arr, scaled, left: int, top: int, step: int, tol: int, bg, fg) -> list[str]:
    """Outer edges of the placed reference against the model, every step rows."""
    import numpy as np

    height, width = model_arr.shape[:2]
    ref_mask = np.zeros((height, width), dtype=bool)
    over_a = scaled[:, :, 3] >= 128
    h, w = over_a.shape
    x0, y0 = max(0, left), max(0, top)
    x1, y1 = min(width, left + w), min(height, top + h)
    ref_mask[y0:y1, x0:x1] = over_a[y0 - top:y1 - top, x0 - left:x1 - left]
    model_mask = foreground(model_arr, tol, bg, fg)
    both = ref_mask | model_mask
    if not both.any():
        return ["overlay figure none"]
    ys = np.where(both.any(axis=1))[0]
    y0r, y1r = int(ys.min()), int(ys.max())
    rows = list(range(y0r, y1r + 1, step))
    if rows[-1] != y1r:
        rows.append(y1r)
    lines = []
    for row in rows:
        ref_runs = runs_of(ref_mask[row])
        model_runs = runs_of(model_mask[row])
        lines.append("y=%d ref %s || model %s" % (row, run_text(ref_runs, 0), run_text(model_runs, 0)))
    return lines

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
    if args.spans:
        if args.step < 1:
            raise ValueError("--step is a positive row interval")
        bg = parse_hex(args.bg) if args.bg else None
        fg = parse_hex(args.fg) if args.fg else None
        out.extend(span_report(arr, x, y, args.step, args.tol, bg, fg))
    if args.overlay:
        if args.scale <= 0:
            raise ValueError("--scale must be above 0")
        if args.step < 1:
            raise ValueError("--step is a positive row interval")
        if not 0 < args.opacity <= 1:
            raise ValueError("--opacity is between 0 and 1")
        if not args.anchor_ref or not args.anchor_model:
            raise ValueError("--overlay needs --anchor-ref and --anchor-model")
        ref_path = Path(args.overlay)
        if not ref_path.is_file():
            raise ValueError(f"not a file: {ref_path}")
        placed, left, top, scaled = blend_overlay(
            im, imgio.load(ref_path), args.opacity, args.scale,
            parse_point(args.anchor_ref), parse_point(args.anchor_model), args.flip_x,
        )
        dest = Path(args.out) if args.out else Path("_logs/shot-crop") / f"{png.stem}-overlay.png"
        out.append(
            "overlay scale=%.4f opacity=%.2f place=%d,%d size=%dx%d"
            % (args.scale, args.opacity, left, top, scaled.shape[1], scaled.shape[0])
        )
        out.extend(overlay_report(
            imgio.to_np(im), scaled, left, top, args.step, args.tol,
            parse_hex(args.bg) if args.bg else None,
            parse_hex(args.fg) if args.fg else None,
        ))
        out.append("crop " + str(imgio.save(placed, dest)))
        return out
    asked = bool(args.probe or args.near or args.dark is not None or args.spans)
    if args.box or args.out or not asked:
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
            return subprocess.run([*boot.cmd("shot_crop"), str(f), *a], capture_output=True, text=True)

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
        im.putpixel((4, 2), (255, 255, 255, 255))
        im.putpixel((8, 2), (255, 255, 255, 255))
        im.putpixel((6, 6), (255, 255, 255, 255))
        imgio.save(im, f)
        p = run_me("--spans", "--bg", "#000000", "--step", "4")
        text = p.stdout
        if "figure y=2-6 h=5 x=4-8 w=5" not in text or "y=2 x=4-4 w=1 #ffffff | x=8-8 w=1 #ffffff" not in text or "y=6 x=6-6 w=1 #ffffff" not in text:
            bad.append("spans reports the figure and both rows: " + text)
        if "crop " in text:
            bad.append("spans alone must not write a crop: " + text)
        ref = Path(td) / "ref.png"
        rim = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
        rim.putpixel((1, 1), (255, 0, 0, 255))
        imgio.save(rim, ref)
        over = Path(td) / "over.png"
        p = run_me(
            "--overlay", str(ref), "--scale", "2", "--opacity", "0.5",
            "--anchor-ref", "1,1", "--anchor-model", "5,5", "--out", str(over),
            "--bg", "#000000", "--step", "1",
        )
        if p.returncode != 0 or not over.is_file():
            bad.append("overlay writes a png: " + p.stdout + p.stderr)
        else:
            pix = imgio.load(over).getpixel((5, 5))
            if pix[0] < 120 or pix[0] > 136 or pix[1] != 0 or pix[2] != 0:
                bad.append("overlay lands half red on the anchor: %s" % (pix,))
            if "y=5 ref x=4-5 w=2" not in p.stdout:
                bad.append("overlay report names the placed run: " + p.stdout)
    return agent_log.selftest_result(bad)

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
    ap.add_argument("--spans", action="store_true", help="Print connected foreground runs every --step rows, plus the figure box.")
    ap.add_argument("--step", type=int, default=8, help="Row interval for --spans (default 8). The last foreground row is always included.")
    ap.add_argument("--bg", default="", metavar="HEX", help="With --spans, ignore pixels within --tol of this colour.")
    ap.add_argument("--fg", default="", metavar="HEX", help="With --spans, keep only pixels within --tol of this colour.")
    ap.add_argument("--overlay", default="", metavar="PNG", help="Reference PNG blended over this shot. Needs --anchor-ref and --anchor-model.")
    ap.add_argument("--opacity", type=float, default=0.5, help="Reference strength for --overlay (default 0.5).")
    ap.add_argument("--scale", type=float, default=1.0, help="Nearest scale applied to --overlay before placement.")
    ap.add_argument("--anchor-ref", default="", metavar="X,Y", help="Pixel on the reference that lands on --anchor-model.")
    ap.add_argument("--anchor-model", default="", metavar="X,Y", help="Pixel on this shot that receives --anchor-ref.")
    ap.add_argument("--flip-x", action="store_true", help="Mirror the reference before placing it.")
    ap.add_argument("--selftest", action="store_true", help="Run the built-in cases.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    if not args.png:
        agent_log.fail("pass the PNG (example: python tools/shots.py crop _logs/shot-flow/camp-npc-panels/01-vendor.png --box 100,80,300,200 --zoom 3)")
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
