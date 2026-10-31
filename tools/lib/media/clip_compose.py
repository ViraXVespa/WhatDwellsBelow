#!/usr/bin/env python3
"""Composed promo edits for `media.py clip` (clip_edit.py owns the CLI):

  punch     punch-in: ease into a box, hold, ease back out (clip_fx.zoom with back)
  callout   a box outline plus a promo chip label beside it, faded in and out over [start, end]
  montage   clips joined with crossfades, each opening with its own chip title (top-left), optional end card
  spec      a JSON edit list: {"in": CLIP | "montage": [CLIPS], "titles": [...], "steps": [{"op": punch|callout|caption|ba|export, ...}]}
            run in order, each step's output feeding the next (paths relative to the spec file)
"""
from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path

import clip_edit as ce
import clip_fx
import clip_promo

def punch(src: Path, box, out: Path, start: float = 0.5, dur: float = 0.4, hold: float = 1.2) -> Path:
    i = ce.info(src)
    return clip_fx.zoom(src, (0, 0, i["w"], i["h"]), box, out, (0, 0), start, dur, back=hold)

def callout(src: Path, box, text: str, out: Path, start: float = 0.0, end: float = 0.0, color: str = "#ffd23f", font: str = "") -> Path:
    """Outline + chip: the chip sits below the box (above it when the box is in the lower half), kept inside the frame."""
    from PIL import Image, ImageColor, ImageDraw
    i = ce.info(src)
    w, h = i["w"], i["h"]
    end = end or i["sec"]
    th = max(2, h // 180)
    font = ce._font(font)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        clip_promo.chip(text, "", ImageColor.getrgb(color) + (255,), font, int(h * 0.6), T / "c.png")
        c = Image.open(T / "c.png")
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        x, y, bw, bh = [int(v) for v in box]
        d.rectangle([x, y, x + bw, y + bh], outline=ImageColor.getrgb(color), width=th)
        cy = y + bh + th if y + bh / 2 < h / 2 else y - c.height - th
        cx = min(max(0, x), w - c.width)
        img.alpha_composite(c, (cx, min(max(0, cy), h - c.height)))
        img.save(T / "o.png")
        f = min(0.25, (end - start) / 4)
        fc = ("[1:v]format=rgba,fade=t=in:st=%.3f:d=%.3f:alpha=1,fade=t=out:st=%.3f:d=%.3f:alpha=1[l];[0:v][l]overlay=0:0:shortest=1,format=yuv420p[o]"
              % (start, f, end - f, f))
        ce._run(["-i", str(src), "-loop", "1", "-framerate", str(round(float(i["fps"])) or 30), "-t", "%.3f" % i["sec"], "-i", str(T / "o.png"),
                 "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

def montage(srcs: list[Path], out: Path, titles: list[str] | None = None, fade: float = 0.4, end: tuple[str, str] | None = None, font: str = "") -> Path:
    """Each clip at the first clip's size, its chip title over its first 1.6 s, crossfaded; then the optional end card."""
    a = ce.info(srcs[0])
    w, h = a["w"] - a["w"] % 2, a["h"] - a["h"] % 2
    font = ce._font(font)
    titles = (titles or []) + [""] * len(srcs)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        segs = []
        for k, s in enumerate(srcs):
            fit = clip_fx.fit(s, (w, h), T / ("f%d.mp4" % k)) if (ce.info(s)["w"], ce.info(s)["h"]) != (w, h) else s
            if titles[k]:
                clip_promo.chip(titles[k], "", clip_promo.COL[1], font, h, T / ("t%d.png" % k))
                lx = int(30 * h / 720)
                fc = ("[1:v]format=rgba,fade=t=in:st=0.1:d=0.3:alpha=1,fade=t=out:st=1.6:d=0.3:alpha=1[l];[0:v][l]overlay=%d:%d:shortest=1,format=yuv420p[o]" % (lx, lx))
                seg = T / ("s%d.mp4" % k)
                ce._run(["-i", str(fit), "-loop", "1", "-framerate", "30", "-t", "%.3f" % ce.info(fit)["sec"], "-i", str(T / ("t%d.png" % k)),
                         "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(seg)])
                fit = seg
            segs.append(fit)
        body = T / "body.mp4"
        ce.join(segs, fade, body) if len(segs) > 1 else shutil.copy2(segs[0], body)
        if end:
            clip_promo.card(end[0], end[1], font, w, h, T / "e.png")
            ce._run(["-sseof", "-0.2", "-i", str(body), "-frames:v", "1", str(T / "last.png")])
            fc = ("[0:v]gblur=sigma=%.1f,eq=brightness=-0.18:saturation=0.8[eb];"
                  "[1:v]format=rgba,fade=t=in:st=0.15:d=0.45:alpha=1[ec];[eb][ec]overlay=0:0,format=yuv420p[o]") % (14 * h / 720)
            ce._run(["-loop", "1", "-framerate", "30", "-t", "1.8", "-i", str(T / "last.png"), "-loop", "1", "-framerate", "30", "-t", "1.8", "-i", str(T / "e.png"),
                     "-filter_complex", fc, "-map", "[o]", "-an", "-t", "1.8", *ce.H264, str(T / "end.mp4")])
            ce.join([body, T / "end.mp4"], fade, out)
        else:
            shutil.copy2(body, out)
    return out

def spec(path: Path, out: Path, root: Path | None = None) -> list[dict]:
    """Run a JSON edit list; returns one row per step (op, out, sec)."""
    d = json.loads(path.read_text(encoding="utf-8"))
    rel = lambda p: p if Path(p).is_absolute() else path.parent / p
    font = d.get("font", "")
    rows = []
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        if "montage" in d:
            cur = montage([rel(p) for p in d["montage"]], T / "m.mp4", d.get("titles"), d.get("fade", 0.4),
                          tuple(d["end_card"]) if d.get("end_card") else None, font)
            rows.append({"op": "montage", "sec": ce.info(cur)["sec"]})
        else:
            cur = rel(d["in"])
        for k, s in enumerate(d.get("steps", [])):
            op, nxt = s["op"], T / ("s%d.mp4" % k)
            i = ce.info(cur)
            box = clip_fx.box_px(s["box"], i["w"], i["h"], root, s.get("movie", "")) if "box" in s else None
            if op == "punch":
                punch(cur, box, nxt, s.get("start", 0.5), s.get("dur", 0.4), s.get("hold", 1.2))
            elif op == "callout":
                callout(cur, box, s["text"], nxt, s.get("start", 0.0), s.get("end", 0.0), s.get("color", "#ffd23f"), font)
            elif op == "caption":
                ce.caption(cur, s.get("text", ""), nxt, s.get("start", 0.0), s.get("end", 0.0), s.get("pos", "bottom"), font)
            elif op == "ba":
                clip_fx.ba(cur, rel(s["after"]), nxt, box, s.get("layout", "auto"), tuple(s.get("labels", ("Before", "After"))), font=font,
                           style=s.get("style", "promo"), subs=tuple(s.get("subs", ("", ""))), end=tuple(s["end_card"]) if s.get("end_card") else None)
            elif op == "export":
                nxt = T / ("s%d%s" % (k, ".gif" if s.get("for") == "gif" else ".mp4"))
                ce.export(cur, s.get("for", "x"), nxt, s.get("width", 0))
            else:
                raise ValueError("spec step %d: unknown op %r" % (k, op))
            cur = nxt
            rows.append({"op": op, "sec": ce.info(cur)["sec"] if cur.suffix == ".mp4" else None})
        shutil.copy2(cur, out)
    return rows

def selftest(t: Path) -> list[str]:
    bad: list[str] = []
    ce._run(["-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30:duration=3", *ce.H264, str(t / "ca.mp4")])
    ce._run(["-f", "lavfi", "-i", "smptebars=size=640x360:rate=30:duration=2", *ce.H264, str(t / "cb.mp4")])
    a, b = t / "ca.mp4", t / "cb.mp4"
    near = lambda p, q, d=60: all(abs(x - y) < d for x, y in zip(p, q))
    punch(a, (0, 0, 320, 180), t / "punch.mp4", 0.2, 0.3, 1.0)
    p0, pm, p1 = (clip_fx._px(t / "punch.mp4", s, (600, 340)) for s in (0.05, 1.0, 2.6))
    if near(p0, pm, 20) or not near(p0, p1, 40):
        bad.append("punch: not zoomed mid-clip or not back out (%s %s %s)" % (p0, pm, p1))
    callout(a, (200, 100, 120, 80), "HERE", t / "call.mp4", 0.5, 2.5, "#ff0000")
    if not near(clip_fx._px(t / "call.mp4", 1.5, (200, 140)), (255, 0, 0), 90) or near(clip_fx._px(t / "call.mp4", 0.1, (200, 140)), (255, 0, 0), 60):
        bad.append("callout: outline not timed")
    i = ce.info(montage([a, b], t / "mont.mp4", ["One", "Two"], 0.4, ("T", "S")))
    if abs(i["sec"] - (3 + 2 - 0.4 + 1.8 - 0.4)) > 0.25:
        bad.append("montage: %s" % i)
    (t / "spec.json").write_text(json.dumps({"in": "ca.mp4", "steps": [{"op": "punch", "box": [0, 0, 320, 180]}, {"op": "callout", "box": [10, 10, 50, 50], "text": "X"}]}))
    rows = spec(t / "spec.json", t / "spec.mp4")
    if [r["op"] for r in rows] != ["punch", "callout"] or abs(ce.info(t / "spec.mp4")["sec"] - 3.0) > 0.15:
        bad.append("spec: %s" % rows)
    return bad
