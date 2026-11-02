#!/usr/bin/env python3
"""Scene-tracking and montage helpers for `media.py clip` (clip_edit.py owns the CLI, clip_compose.py the spec):

  keys / track   a callout box over time: inline [[t, x, y, w, h], ...], a named track in movies.json
                 (movie["tracks"][name], same rows, px or fractions), or a per-frame JSON file ([{"t": s, "box": [...]}, ...])
  tracked        callout whose box and chip follow the keys (piecewise-linear ffmpeg expressions in t)
  hold           freeze one frame for a while, then play on
  lower_third    a full-width title strip low in the frame (distinct from the top-left chip titles)
  place_chip     chip spot beside a box that keeps out of the label/title corners and of chips already placed
"""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

import clip_edit as ce
import clip_promo

# Label and title corners: ba/wipe labels and montage chip titles sit top-left and top-right.
CORNERS = ((0.0, 0.0, 0.36, 0.2), (0.64, 0.0, 0.36, 0.2))

def corners(w: int, h: int) -> list[tuple[float, float, float, float]]:
    return [(x * w, y * h, cw * w, ch * h) for x, y, cw, ch in CORNERS]

def _hit(a, b) -> bool:
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]

def place_chip(cw: int, ch: int, box, w: int, h: int, avoid=(), gap: int = 4) -> tuple[int, int]:
    """Below the box, above it, right, left; then stepped down the frame: the first spot inside the frame that hits no
    avoid rect (corners plus chips already placed). Falls back to below, clamped."""
    x, y, bw, bh = box
    clamp = lambda cx, cy: (int(min(max(0, cx), w - cw)), int(min(max(0, cy), h - ch)))
    cands = [(x, y + bh + gap), (x, y - ch - gap), (x + bw + gap, y), (x - cw - gap, y)]
    cands += [(x, y + bh + gap + k * (ch + gap)) for k in range(1, 6)] + [(x, y - (k + 1) * (ch + gap)) for k in range(1, 6)]
    for cx, cy in cands:
        p = clamp(cx, cy)
        if (p[0], p[1]) == (int(cx), int(cy)) and not any(_hit((p[0], p[1], cw, ch), r) for r in avoid):
            return p
    return clamp(x, y + bh + gap)

def keys(spec, w: int, h: int, root: Path | None = None, movie: str = "", base: Path | None = None) -> list[list[float]]:
    """Track rows [t, x, y, w, h] in px, sorted by t."""
    if isinstance(spec, str):
        p = Path(spec) if Path(spec).is_absolute() else (base or Path.cwd()) / spec
        if spec.endswith(".json") and p.is_file():
            spec = [[r["t"], *r["box"]] for r in json.loads(p.read_text(encoding="utf-8"))]
        else:
            m = json.loads(((root or Path.cwd()) / "tools" / "data" / "movies.json").read_text(encoding="utf-8"))["movies"].get(movie, {})
            if spec not in m.get("tracks", {}):
                raise SystemExit("no track %r in movie %r" % (spec, movie))
            spec = m["tracks"][spec]
    rows = []
    for r in spec:
        v = [float(a) for a in r[1:5]]
        if all(a <= 1.0 for a in v):
            v = [v[0] * w, v[1] * h, v[2] * w, v[3] * h]
        rows.append([float(r[0]), *v])
    if not rows:
        raise SystemExit("empty track")
    return sorted(rows)

def at(rows: list[list[float]], t: float) -> list[float]:
    """The box at time t (same interpolation as expr)."""
    if t <= rows[0][0]:
        return rows[0][1:]
    for a, b in zip(rows, rows[1:]):
        if t < b[0]:
            f = (t - a[0]) / max(1e-3, b[0] - a[0])
            return [a[k] + (b[k] - a[k]) * f for k in range(1, 5)]
    return rows[-1][1:]

def tracked(src: Path, rows: list[list[float]], text: str, out: Path, start: float = 0.0, end: float = 0.0,
            color: str = "#ffd23f", font: str = "", avoid=()) -> Path:
    """Box outline and chip that follow the track (one overlay frame per video frame, drawn with PIL); the chip takes
    place_chip's spot each frame, so it keeps out of the corners and of `avoid`."""
    from PIL import Image, ImageColor, ImageDraw
    i = ce.info(src)
    w, h, fps = i["w"], i["h"], float(i["fps"]) or 30.0
    end = end or i["sec"]
    th = max(2, h // 180)
    rgb = ImageColor.getrgb(color)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        clip_promo.chip(text, "", rgb + (255,), ce._font(font), int(h * 0.6), T / "c.png")
        c = Image.open(T / "c.png")
        av = corners(w, h) + list(avoid)
        blank = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        for n in range(int(round(i["sec"] * fps))):
            t = n / fps
            img = blank.copy()
            if start <= t <= end:
                x, y, bw, bh = at(rows, t)
                ImageDraw.Draw(img).rectangle([x, y, x + bw, y + bh], outline=rgb, width=th)
                img.alpha_composite(c, place_chip(c.width, c.height, (x, y, bw, bh), w, h, av, th))
            img.save(T / ("o%05d.png" % n))
        ce._run(["-i", str(src), "-framerate", "%g" % fps, "-i", str(T / "o%05d.png"),
                 "-filter_complex", "[0:v][1:v]overlay=0:0:shortest=1,format=yuv420p[o]", "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

def hold(src: Path, t: float, dur: float, out: Path) -> Path:
    """Play to t, freeze that frame for dur seconds, play on (total = clip + dur)."""
    i = ce.info(src)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        ce._run(["-ss", "%.3f" % t, "-i", str(src), "-frames:v", "1", str(T / "f.png")])
        ce._run(["-loop", "1", "-framerate", "%g" % i["fps"], "-t", "%.3f" % dur, "-i", str(T / "f.png"), "-vf", "format=yuv420p", *ce.H264, str(T / "h.mp4")])
        parts = [T / "h.mp4", T / "b.mp4"]
        ce._run(["-i", str(src), "-ss", "%.3f" % t, "-an", *ce.H264, str(T / "b.mp4")])
        if t > 0.02:
            ce._run(["-i", str(src), "-t", "%.3f" % t, "-an", *ce.H264, str(T / "a.mp4")])
            parts.insert(0, T / "a.mp4")
        join(parts, "cut", 0.0, out)
    return out

def hold_end(src: Path, dur: float, out: Path) -> Path:
    ce._run(["-i", str(src), "-vf", "tpad=stop_mode=clone:stop_duration=%.3f,format=yuv420p" % dur, "-an", *ce.H264, str(out)])
    return out

def strip_png(title: str, sub: str, w: int, h: int, font: str, path: Path, accent=(255, 206, 92, 255)) -> tuple[int, int]:
    """Lower-third strip: full-width dark band, accent bar at its left, title and optional subline. Returns its (y, height)."""
    from PIL import Image, ImageDraw
    k = h / 720
    f1, f2 = clip_promo._f(font, int(46 * k)), clip_promo._f(font, int(26 * k), "Medium")
    bh = int((112 if sub else 76) * k)
    y = int(h * 0.74)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, y, w, y + bh], fill=(12, 12, 16, 190))
    d.rectangle([int(40 * k), y + int(14 * k), int(48 * k), y + bh - int(14 * k)], fill=accent)
    d.text((int(64 * k), y + int(12 * k)), title, font=f1, fill=(245, 245, 245, 255))
    if sub:
        d.text((int(64 * k), y + int(66 * k)), sub, font=f2, fill=(200, 200, 205, 255))
    img.save(path)
    return y, bh

def lower_third(src: Path, title: str, out: Path, sub: str = "", start: float = 0.1, dur: float = 2.2, font: str = "") -> Path:
    i = ce.info(src)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        strip_png(title, sub, i["w"], i["h"], ce._font(font), T / "s.png")
        fc = ("[1:v]format=rgba,fade=t=in:st=%.3f:d=0.3:alpha=1,fade=t=out:st=%.3f:d=0.3:alpha=1[l];"
              "[0:v][l]overlay=0:0:shortest=1,format=yuv420p[o]") % (start, start + max(0.4, dur - 0.3))
        ce._run(["-i", str(src), "-loop", "1", "-framerate", "30", "-t", "%.3f" % i["sec"], "-i", str(T / "s.png"),
                 "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

JOINS = {"fade": ("fade", None), "cut": ("cut", 0.0), "dip": ("fadeblack", 0.5), "whip": ("slideleft", 0.25)}

def join(segs: list[Path], how: str, fade: float, out: Path) -> Path:
    """Montage join: fade (crossfade by `fade`), cut (straight concat), dip (through black) or whip (fast slide)."""
    tr, d = JOINS[how]
    if tr == "cut":
        first = ce.info(segs[0])
        norm = "scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2,fps=%s,format=yuv420p,setsar=1" % (
            first["w"], first["h"], first["w"], first["h"], first["fps"])
        n = len(segs)
        fc = ";".join("[%d:v]%s[v%d]" % (k, norm, k) for k in range(n)) + ";" + "".join("[v%d]" % k for k in range(n)) + "concat=n=%d:v=1:a=0[o]" % n
        ce._run([a for s in segs for a in ("-i", str(s))] + ["-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(out)])
        return out
    return ce.join(segs, d if d is not None else fade, out, tr)

def selftest(t: Path) -> list[str]:
    import clip_fx
    bad: list[str] = []
    ce._run(["-f", "lavfi", "-i", "color=c=gray:size=640x360:rate=30:duration=3", *ce.H264, str(t / "g.mp4")])
    g = t / "g.mp4"
    rows = [[0.0, 40, 40, 80, 60], [2.0, 440, 200, 80, 60]]
    if [round(v) for v in at(rows, 1.0)] != [240, 120, 80, 60]:
        bad.append("track at: %s" % at(rows, 1.0))
    tracked(g, rows, "HERE", t / "tr.mp4", 0.0, 3.0, "#ff0000")
    for s, (bx, by) in ((0.0, (40, 70)), (1.0, (240, 150)), (2.5, (440, 230))):
        px = clip_fx._px(t / "tr.mp4", s, (bx, by))
        if not (px[0] > 180 and px[1] < 110):
            bad.append("tracked box edge at %.1fs %s: %s" % (s, (bx, by), px))
    hold(g, 1.0, 1.5, t / "hold.mp4")
    if abs(ce.info(t / "hold.mp4")["sec"] - 4.5) > 0.15:
        bad.append("hold: %s" % ce.info(t / "hold.mp4"))
    hold_end(g, 1.0, t / "he.mp4")
    if abs(ce.info(t / "he.mp4")["sec"] - 4.0) > 0.15:
        bad.append("hold_end: %s" % ce.info(t / "he.mp4"))
    lower_third(g, "Title", t / "lt.mp4", "sub", 0.1, 2.0)
    band, top = clip_fx._px(t / "lt.mp4", 1.0, (320, int(360 * 0.74) + 4)), clip_fx._px(t / "lt.mp4", 1.0, (320, 40))
    if not (sum(band) < sum(top) - 120):
        bad.append("lower_third: band %s top %s" % (band, top))
    for how, want in (("cut", 6.0), ("dip", 5.5), ("whip", 5.75), ("fade", 5.6)):
        if abs(ce.info(join([g, g], how, 0.4, t / ("j_%s.mp4" % how)))["sec"] - want) > 0.15:
            bad.append("join %s: %s" % (how, ce.info(t / ("j_%s.mp4" % how))))
    w, h = 640, 360
    av = corners(w, h)
    p = place_chip(120, 40, (20, 10, 60, 30), w, h, av)
    if any(_hit((p[0], p[1], 120, 40), r) for r in av):
        bad.append("place_chip in a corner: %s" % (p,))
    q = place_chip(120, 40, (200, 150, 60, 30), w, h, av + [(p[0], p[1], 120, 40), (200, 184, 120, 40)])
    if _hit((q[0], q[1], 120, 40), (200, 184, 120, 40)):
        bad.append("place_chip overlap not nudged: %s" % (q,))
    return bad
