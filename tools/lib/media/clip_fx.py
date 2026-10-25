#!/usr/bin/env python3
"""Framing, transitions and overlays for `media.py clip` (clip_edit.py owns the CLI). Thin ffmpeg filter builders:

  crop      static crop to a box (pixels, fractions, or a named region from tools/data/movies.json), scaled to a size
  zoom      animated zoom/pan (Ken Burns) from one box to another, eased, inside a time window
  fit       scale to an X size (x 1280x720, x-square 720x720, x-portrait 720x1280 or WxH): pad, crop or blurred fill
  join      (clip_edit.join) any xfade transition in TRANSITIONS
  wipe      before/after slider: an animated reveal line sweeps the after clip over the before clip (and back)
  pip       picture-in-picture inset in a corner, with a border, optionally timed
  mark      highlight boxes with arrows, optionally timed (drawn once with PIL, overlaid by ffmpeg)
  ba        before/after recipe: finds what changed; a small change gets zoom + wipe, a big one side by side
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

import clip_edit as ce

TRANSITIONS = ("fade", "dissolve", "fadeblack", "fadewhite", "wipeleft", "wiperight", "wipeup", "wipedown", "slideleft", "slideright",
               "slideup", "slidedown", "smoothleft", "smoothright", "circleopen", "circleclose", "radial", "pixelize")
SIZES = {"x": (1280, 720), "x-square": (720, 720), "x-portrait": (720, 1280)}
SMALL = 0.35  # ba: a change covering less than this share of the frame (padded box) is zoomed in on and wiped

def size_of(spec: str) -> tuple[int, int]:
    if spec in SIZES:
        return SIZES[spec]
    w, h = spec.lower().split("x")
    return int(w) // 2 * 2, int(h) // 2 * 2

def region(root: Path, name: str, movie: str = "") -> list[float]:
    """Named region [x, y, w, h] (fractions of the frame) from a movie in tools/data/movies.json."""
    movies = json.loads((root / "tools/data/movies.json").read_text(encoding="utf-8"))["movies"]
    for mn, mv in movies.items():
        if (not movie or mn == movie) and name in mv.get("regions", {}):
            return [float(v) for v in mv["regions"][name]]
    raise SystemExit("no region %r%s in tools/data/movies.json" % (name, " in movie " + movie if movie else ""))

def box_px(spec, w: int, h: int, root: Path | None = None, movie: str = "") -> tuple[float, float, float, float]:
    """X,Y,W,H in pixels, or fractions when every value is <= 1, or a region name."""
    if isinstance(spec, str) and not spec.replace(",", "").replace(".", "").replace("-", "").isdigit():
        spec = region(root or Path.cwd(), spec, movie)
    v = [float(x) for x in (spec.split(",") if isinstance(spec, str) else spec)]
    if len(v) != 4:
        raise SystemExit("box needs X,Y,W,H")
    if all(x <= 1.0 for x in v):
        v = [v[0] * w, v[1] * h, v[2] * w, v[3] * h]
    return v[0], v[1], v[2], v[3]

def aspect_box(b, aspect: float, w: int, h: int, pad: float = 0.0, min_w: float = 0.0):
    """Grow box b by `pad` (share of its size) to `aspect` (w/h) around its centre, at least min_w wide, inside the frame."""
    cx, cy = b[0] + b[2] / 2, b[1] + b[3] / 2
    bw, bh = b[2] * (1 + 2 * pad), b[3] * (1 + 2 * pad)
    bw = max(bw, bh * aspect, min_w)
    bw = min(bw, w, h * aspect)
    bh = bw / aspect
    x = min(max(0.0, cx - bw / 2), w - bw)
    y = min(max(0.0, cy - bh / 2), h - bh)
    return round(x, 1), round(y, 1), round(bw, 1), round(bh, 1)

def crop(src: Path, box, out: Path, size: tuple[int, int] = (0, 0)) -> Path:
    i = ce.info(src)
    ow, oh = size if size[0] else (i["w"], i["h"])
    x, y, bw, bh = aspect_box(box, ow / oh, i["w"], i["h"])
    ce._run(["-i", str(src), "-vf", "crop=%d:%d:%d:%d,scale=%d:%d:flags=lanczos,setsar=1" % (bw, bh, x, y, ow, oh), "-an", *ce.H264, str(out)])
    return out

def _ease(start: float, dur: float) -> str:
    p = "clip((t-%.3f)/%.3f,0,1)" % (start, max(dur, 0.001))
    return "(%s*%s*(3-2*%s))" % (p, p, p)

def zoom(src: Path, box_a, box_b, out: Path, size: tuple[int, int] = (0, 0), start: float = 0.0, dur: float = 0.0) -> Path:
    """Ken Burns: the view moves from box_a to box_b over [start, start+dur] (dur 0 = the whole clip), eased in and out.
    Works at twice the output size, then scales down, so the pan does not step a pixel at a time."""
    i = ce.info(src)
    ow, oh = size if size[0] else (i["w"], i["h"])
    a = aspect_box(box_a, ow / oh, i["w"], i["h"])
    b = aspect_box(box_b, ow / oh, i["w"], i["h"])
    e = _ease(start, dur or i["sec"])
    lerp = lambda k: "(%.2f+(%.2f)*%s)" % (a[k], b[k] - a[k], e)
    s = "(%d/%s)" % (2 * ow, lerp(2))
    vf = ("scale=w='trunc(%d*%s/2)*2':h='trunc(%d*%s/2)*2':eval=frame:flags=bicubic,crop=%d:%d:'%s*%s':'%s*%s',scale=%d:%d:flags=lanczos,setsar=1"
          % (i["w"], s, i["h"], s, 2 * ow, 2 * oh, lerp(0), s, lerp(1), s, ow, oh))
    ce._run(["-i", str(src), "-vf", vf, "-an", *ce.H264, str(out)])
    return out

def fit(src: Path, size: tuple[int, int], out: Path, fill: str = "pad") -> Path:
    """Scale into an exact size: pad (black bars), crop (fill and cut the edges) or blur (blurred copy behind)."""
    w, h = size
    if fill == "crop":
        fc = "[0:v]scale=%d:%d:force_original_aspect_ratio=increase:flags=lanczos,crop=%d:%d,setsar=1[o]" % (w, h, w, h)
    elif fill == "blur":
        fc = ("[0:v]split[a][b];[a]scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d,boxblur=20:2,eq=brightness=-0.08[bg];"
              "[b]scale=%d:%d:force_original_aspect_ratio=decrease:flags=lanczos[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[o]" % (w, h, w, h, w, h))
    else:
        fc = "[0:v]scale=%d:%d:force_original_aspect_ratio=decrease:flags=lanczos,pad=%d:%d:(ow-iw)/2:(oh-ih)/2,setsar=1[o]" % (w, h, w, h)
    ce._run(["-i", str(src), "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

def _legs(a: dict, b: dict, total: float) -> tuple[str, str]:
    """Both clips at the before clip's size and fps, held on their last frame to `total` seconds."""
    norm = "scale=%d:%d,setsar=1,fps=%s,format=gbrp,tpad=stop_mode=clone:stop_duration=%.3f"
    return norm % (a["w"], a["h"], a["fps"], total - a["sec"] + 0.1), norm % (a["w"], a["h"], a["fps"], total - b["sec"] + 0.1)

def wipe(before: Path, after: Path, out: Path, labels: tuple[str, str] = ("Before", "After"), hold: float = 0.6, sweep: float = 1.6,
         back: bool = True, line: int = 3, font: str = "") -> Path:
    """Slider wipe: a white line sweeps left to right; left of it is the after clip, right of it the before clip.
    Holds `hold` s on before, sweeps, holds, and (back) sweeps back. Labels sit top-left (after) and top-right (before)."""
    a, b = ce.info(before), ce.info(after)
    t1 = hold + sweep + max(hold, 1.0)
    total = max(a["sec"], b["sec"], t1 + (sweep + hold if back else hold))
    la, lb = _legs(a, b, total)
    e1, e2 = _ease(hold, sweep).replace("t", "T"), _ease(t1, sweep).replace("t", "T")
    f = "(%s-%s)" % (e1, e2) if back else e1
    expr = "if(lt(abs(X-W*%s),%d),255,if(lt(X,W*%s),B,A))" % (f, max(1, line), f)
    with tempfile.TemporaryDirectory() as td:
        caps = ",".join([ce._text(labels[1], a["h"], "top", font, x="w*0.03", tmp=Path(td)),
                         ce._text(labels[0], a["h"], "top", font, x="w*0.97-text_w", tmp=Path(td))])
        fc = "[0:v]%s[a];[1:v]%s[b];[a][b]blend=all_expr='%s',trim=duration=%.3f,format=yuv420p,%s[o]" % (la, lb, expr, total, caps)
        ce._run(["-i", str(before), "-i", str(after), "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

def pip(main: Path, inset: Path, out: Path, corner: str = "tr", scale: float = 0.33, start: float = 0.0, end: float = 0.0, border: int = 4) -> Path:
    m = ce.info(main)
    w = int(m["w"] * scale) // 2 * 2
    mg = max(8, m["h"] // 40)
    x = "%d" % mg if "l" in corner else "W-w-%d" % mg
    y = "%d" % mg if "t" in corner else "H-h-%d" % mg
    en = ":enable='between(t,%.3f,%.3f)'" % (start, end) if end > 0 else ""
    fc = "[1:v]scale=%d:-2,pad=iw+%d:ih+%d:%d:%d:white[p];[0:v][p]overlay=%s:%s:eof_action=pass%s,format=yuv420p[o]" % (w, 2 * border, 2 * border, border, border, x, y, en)
    ce._run(["-i", str(main), "-i", str(inset), "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

def _arrow(d, box, w: int, h: int, color, th: int) -> None:
    """Arrow from the open side of the frame to the box edge."""
    cx, cy = box[0] + box[2] / 2, box[1] + box[3] / 2
    dx, dy = (w / 2 - cx) or 1.0, (h / 2 - cy) + h * 0.25
    n = (dx * dx + dy * dy) ** 0.5
    dx, dy = dx / n, dy / n
    tip = (cx + dx * (box[2] / 2 + th * 2) * min(1.0, abs(dx) * 3) , cy + dy * (box[3] / 2 + th * 2))
    tail = (tip[0] + dx * h * 0.18, tip[1] + dy * h * 0.18)
    d.line([tail, tip], fill=color, width=th)
    hx, hy = -dx * h * 0.035, -dy * h * 0.035
    d.polygon([tip, (tip[0] - hx + hy * 0.6, tip[1] - hy - hx * 0.6), (tip[0] - hx - hy * 0.6, tip[1] - hy + hx * 0.6)], fill=color)

def mark(src: Path, boxes: list, out: Path, arrows: bool = True, start: float = 0.0, end: float = 0.0, color: str = "#ffd23f") -> Path:
    from PIL import Image, ImageColor, ImageDraw
    i = ce.info(src)
    th = max(2, i["h"] // 180)
    img = Image.new("RGBA", (i["w"], i["h"]), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rgb = ImageColor.getrgb(color)
    for bx in boxes:
        d.rectangle([bx[0], bx[1], bx[0] + bx[2], bx[1] + bx[3]], outline=rgb, width=th)
        if arrows:
            _arrow(d, bx, i["w"], i["h"], rgb, th)
    en = ":enable='between(t,%.3f,%.3f)'" % (start, end) if end > 0 else ""
    with tempfile.TemporaryDirectory() as td:
        png = Path(td) / "mark.png"
        img.save(png)
        ce._run(["-i", str(src), "-i", str(png), "-filter_complex", "[0:v][1:v]overlay=0:0%s,format=yuv420p[o]" % en, "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

def _frame(src: Path, t: float, dst: Path):
    from PIL import Image
    ce._run(["-ss", "%.3f" % t, "-i", str(src), "-frames:v", "1", str(dst)])
    return Image.open(dst).convert("L")

def change_box(before: Path, after: Path, samples: int = 6, floor: float = 3.0) -> tuple[tuple[float, float, float, float] | None, float]:
    """Where after differs from before: the 32x18 grid cells whose mean difference beats the noise (3x the median
    cell, between `floor` and 2.5x that) in at least half the sampled frames, so a subtle shade change counts; the box
    spans the biggest connected patch and any patch at least a quarter its size (stray noise cells drop out). Returns (box in before-clip pixels or None, share of the frame changed)."""
    from PIL import Image, ImageChops
    a, b = ce.info(before), ce.info(after)
    dur = min(a["sec"], b["sec"])
    gw, gh = 32, 18
    hits = [0] * (gw * gh)
    with tempfile.TemporaryDirectory() as td:
        for k in range(samples):
            t = dur * (k + 0.5) / samples
            x = _frame(before, t, Path(td) / ("a%d.png" % k))
            y = _frame(after, t, Path(td) / ("b%d.png" % k)).resize(x.size)
            g = list(ImageChops.difference(x, y).convert("L").resize((gw, gh), Image.BOX).getdata())
            cut = max(floor, 3.0 * min(sorted(g)[len(g) // 2], 2.5 * floor / 3.0))
            for n, v in enumerate(g):
                hits[n] += 1 if v > cut else 0
    on = {(n % gw, n // gw) for n, c in enumerate(hits) if c * 2 >= samples}
    if not on:
        return None, 0.0
    share = len(on) / float(gw * gh)
    patches: list[list] = []
    while on:
        todo, patch = [on.pop()], []
        while todo:
            c = todo.pop()
            patch.append(c)
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                q = (c[0] + d[0], c[1] + d[1])
                if q in on:
                    on.discard(q)
                    todo.append(q)
        patches.append(patch)
    big = max(len(p) for p in patches)
    cells = [c for p in patches if len(p) * 4 >= big for c in p]
    cw, ch = a["w"] / gw, a["h"] / gh
    x0, y0 = min(c[0] for c in cells), min(c[1] for c in cells)
    x1, y1 = max(c[0] for c in cells) + 1, max(c[1] for c in cells) + 1
    return (x0 * cw, y0 * ch, (x1 - x0) * cw, (y1 - y0) * ch), share

def ba(before: Path, after: Path, out: Path, box=None, layout: str = "auto", labels=("Before", "After"), zoom_in: float = 0.8,
       max_zoom: float = 2.5, font: str = "") -> dict:
    """Before/after recipe. auto: find the change; if its padded box is under SMALL of the frame, zoom both clips onto it
    (Ken Burns from the full frame over zoom_in s, at most max_zoom) and slider-wipe; otherwise side by side."""
    a = ce.info(before)
    found, share = (box, -1.0) if box else change_box(before, after)
    pick = {"layout": layout, "share": round(share, 3), "box": None}
    zb = None
    if found:
        zb = aspect_box(found, a["w"] / a["h"], a["w"], a["h"], pad=0.35, min_w=a["w"] / max_zoom)
        pick["box"] = [round(v) for v in zb]
    if layout == "auto":
        small = zb is not None and zb[2] * zb[3] <= SMALL * a["w"] * a["h"]
        pick["layout"] = "wipe" if small or not found else "sbs"
    if pick["layout"] != "wipe":
        zb = None
    with tempfile.TemporaryDirectory() as td:
        legs = [before, after]
        if zb and pick["layout"] == "wipe":
            full = (0, 0, a["w"], a["h"])
            legs = [zoom(p, full, zb, Path(td) / ("z%d.mp4" % k), (a["w"], a["h"]), 0.0, zoom_in) for k, p in enumerate(legs)]
            pick["zoom"] = round(a["w"] / zb[2], 2)
        if pick["layout"] == "wipe":
            wipe(legs[0], legs[1], out, labels, hold=max(0.6, zoom_in + 0.3), font=font)
        else:
            ce.sbs(legs[0], legs[1], out, labels, font, stack="v" if pick["layout"] == "stack" else "h")
    return pick

def _px(src: Path, t: float, xy: tuple[int, int]) -> tuple:
    with tempfile.TemporaryDirectory() as td:
        ce._run(["-ss", "%.3f" % t, "-i", str(src), "-frames:v", "1", str(Path(td) / "p.png")])
        from PIL import Image
        return Image.open(Path(td) / "p.png").convert("RGB").getpixel(xy)

def selftest(t: Path) -> list[str]:
    """Synthetic clips: a = testsrc2, b = a with a small white square (the 'change'), c = smptebars."""
    bad: list[str] = []
    ce._run(["-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30:duration=3", *ce.H264, str(t / "a.mp4")])
    ce._run(["-i", str(t / "a.mp4"), "-vf", "drawbox=x=420:y=60:w=60:h=50:color=white:t=fill", *ce.H264, str(t / "b.mp4")])
    ce._run(["-f", "lavfi", "-i", "smptebars=size=640x360:rate=30:duration=2", *ce.H264, str(t / "c.mp4")])
    a, b, c = t / "a.mp4", t / "b.mp4", t / "c.mp4"
    near = lambda p, q, d=60: all(abs(x - y) < d for x, y in zip(p, q))
    i = ce.info(crop(b, (400, 40, 100, 90), t / "crop.mp4", (320, 180)))
    if (i["w"], i["h"]) != (320, 180) or not near(_px(t / "crop.mp4", 1.0, (160, 90)), (255, 255, 255)):
        bad.append("crop: %s" % i)
    zoom(b, (0, 0, 640, 360), (420, 60, 60, 50), t / "zoom.mp4", (320, 180), 0.5, 1.5)
    if not near(_px(t / "zoom.mp4", 2.8, (160, 90)), (255, 255, 255)) or near(_px(t / "zoom.mp4", 0.1, (160, 90)), (255, 255, 255)):
        bad.append("zoom: end not on the box or start already there")
    for name, sz, fill in (("fit-pad", (720, 1280), "pad"), ("fit-crop", (720, 720), "crop"), ("fit-blur", (720, 1280), "blur")):
        i = ce.info(fit(a, sz, t / (name + ".mp4"), fill))
        if (i["w"], i["h"]) != sz:
            bad.append("%s: %s" % (name, i))
    for tr in ("wipeleft", "slideup", "dissolve"):
        i = ce.info(ce.join([a, c], 0.5, t / ("j-%s.mp4" % tr), tr))
        if abs(i["sec"] - 4.5) > 0.15:
            bad.append("join %s: %s" % (tr, i))
    i = ce.info(ce.sbs(a, c, t / "stack.mp4", stack="v"))
    if (i["w"], i["h"]) != (640, 720):
        bad.append("stack: %s" % i)
    wipe(a, b, t / "wipe.mp4", hold=0.3, sweep=1.0, back=False)
    if not near(_px(t / "wipe.mp4", 2.0, (450, 85)), (255, 255, 255)) or near(_px(t / "wipe.mp4", 0.1, (450, 85)), (255, 255, 255)):
        bad.append("wipe: after not revealed at the end or shown before the sweep")
    pip(a, c, t / "pip.mp4", "tr", 0.3, 0.5, 2.5)
    if near(_px(t / "pip.mp4", 0.2, (560, 40)), _px(t / "pip.mp4", 1.5, (560, 40)), 8):
        bad.append("pip: inset not shown in its window")
    mark(a, [(200, 100, 120, 80)], t / "mark.mp4", True, 0.0, 0.0, "#ff0000")
    if not near(_px(t / "mark.mp4", 1.0, (200, 140)), (255, 0, 0), 90):
        bad.append("mark: box edge not red")
    ce.caption(a, "", t / "cues.mp4", cues=[(0.0, 1.0, "One"), (1.5, 2.5, "Two: 'x'")])
    if abs(ce.info(t / "cues.mp4")["sec"] - 3.0) > 0.15:
        bad.append("cues")
    pick = ba(a, b, t / "ba.mp4", zoom_in=0.5)
    if pick["layout"] != "wipe" or not pick["box"] or not (pick["box"][0] <= 420 <= pick["box"][0] + pick["box"][2]):
        bad.append("ba small change: %s" % pick)
    pick = ba(a, c, t / "ba2.mp4")
    if pick["layout"] != "sbs":
        bad.append("ba big change: %s" % pick)
    return bad
