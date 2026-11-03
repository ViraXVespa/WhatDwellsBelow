#!/usr/bin/env python3
"""Composed promo edits for `media.py clip` (clip_edit.py owns the CLI):

  punch     punch-in: ease into a box, hold, ease back out (clip_fx.zoom with back)
  callout   a box or ring (style) plus a promo chip label, optional leader line, staggered fade over [start, end]
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
import clip_track

LAST_CHIP: list[float] = []  # the last static callout's chip rect (x, y, w, h): spec nudges later chips off it

def punch(src: Path, box, out: Path, start: float = 0.5, dur: float = 0.4, hold: float = 1.2) -> Path:
    i = ce.info(src)
    return clip_fx.zoom(src, (0, 0, i["w"], i["h"]), box, out, (0, 0), start, dur, back=hold)

def callout(src: Path, box, text: str, out: Path, start: float = 0.0, end: float = 0.0, color: str = "#ffd23f", font: str = "",
            shape: str = "box", leader: bool = False, avoid=()) -> Path:
    """Box or ring outline + chip: the chip sits below the shape (above it when it is in the lower half), kept inside the frame,
    offset by a leader line when `leader`; the shape fades in first and the chip 0.2 s later (out in reverse)."""
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
        img, lab = Image.new("RGBA", (w, h), (0, 0, 0, 0)), Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        x, y, bw, bh = [int(v) for v in box]
        rgb = ImageColor.getrgb(color)
        (d.ellipse if shape == "ring" else d.rectangle)([x, y, x + bw, y + bh], outline=rgb, width=th)
        gap = h // 12 if leader else th
        below = y + bh / 2 < h / 2
        # keep out of the label/title corners and of chips already placed (clip_track.place_chip)
        cx, cy = clip_track.place_chip(c.width, c.height, (x + (bw // 2 if leader else 0), y, bw, bh), w, h,
                                       clip_track.corners(w, h) + list(avoid), gap)
        below = cy > y
        LAST_CHIP[:] = [cx, cy, c.width, c.height]
        if leader:
            d.line([(x + bw // 2, y + bh if below else y), (cx + th, cy if below else cy + c.height)], fill=rgb, width=th)
        lab.alpha_composite(c, (cx, cy))
        img.save(T / "o.png")
        lab.save(T / "l.png")
        f = min(0.25, (end - start) / 5)
        g = min(0.2, (end - start) / 5)
        fade = "format=rgba,fade=t=in:st=%.3f:d=%.3f:alpha=1,fade=t=out:st=%.3f:d=%.3f:alpha=1"
        fc = ("[1:v]%s[s];[2:v]%s[c];[0:v][s]overlay=0:0:shortest=1[a];[a][c]overlay=0:0:shortest=1,format=yuv420p[o]"
              % (fade % (start, f, end - f, f), fade % (start + g, f, end - f - g, f)))
        loop = ["-loop", "1", "-framerate", str(round(float(i["fps"])) or 30), "-t", "%.3f" % i["sec"]]
        ce._run(["-i", str(src), *loop, "-i", str(T / "o.png"), *loop, "-i", str(T / "l.png"),
                 "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(out)])
    return out

def montage(srcs: list, out: Path, titles: list[str] | None = None, fade: float = 0.4, end: tuple[str, str] | None = None, font: str = "",
            join: str = "fade", title_style: str = "chip", hold_end: float = 0.0, root: Path | None = None, base: Path = Path(".")) -> Path:
    """Each clip at the first clip's size, its title over its first 1.6 s (chip top-left, or a lower-third strip), joined by
    `join` (clip_track.JOINS: fade, cut, dip, whip); then the optional end card. A src may be a dict
    {"clip": PATH, "title", "sub", "sub_size" (x h, default 0.045), "trim": [IN, OUT] s (cut before a camera handback),
    "join" (how this segment joins the one before), "callouts": [callout steps]}; its callouts run on that segment only
    and share one `placed` list (chips keep off each other). hold_end: freeze the last frame (before the end card)."""
    segs_in = [s if isinstance(s, dict) else {"clip": s} for s in srcs]
    srcs = [Path(s["clip"]) for s in segs_in]
    a = ce.info(srcs[0])
    w, h = a["w"] - a["w"] % 2, a["h"] - a["h"] % 2
    font = ce._font(font)
    titles = (titles or []) + [""] * len(srcs)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        segs = []
        for k, s in enumerate(srcs):
            if segs_in[k].get("trim"):
                a0, a1 = (float(v) for v in segs_in[k]["trim"])
                ce._run(["-ss", "%.3f" % a0, "-i", str(s), "-t", "%.3f" % (a1 - a0), "-an", *ce.H264, str(T / ("tr%d.mp4" % k))])
                s = T / ("tr%d.mp4" % k)
            fit = clip_fx.fit(s, (w, h), T / ("f%d.mp4" % k)) if (ce.info(s)["w"], ce.info(s)["h"]) != (w, h) else s
            seg_placed: list = []
            for j, st in enumerate(segs_in[k].get("callouts", [])):
                fit = _step(st, fit, T / ("c%d_%d.mp4" % (k, j)), T, root, font, base, seg_placed)
            title = segs_in[k].get("title", titles[k])
            if title and title_style == "lower":
                fit = clip_track.lower_third(fit, title, T / ("l%d.mp4" % k), segs_in[k].get("sub", ""), 0.1, 2.2, font,
                                             float(segs_in[k].get("sub_size", clip_track.SUB_K)))
                titles[k] = ""
            elif title:
                titles[k] = title
                clip_promo.chip(titles[k], "", clip_promo.COL[1], font, h, T / ("t%d.png" % k))
                lx = int(30 * h / 720)
                fc = ("[1:v]format=rgba,fade=t=in:st=0.1:d=0.3:alpha=1,fade=t=out:st=1.6:d=0.3:alpha=1[l];[0:v][l]overlay=%d:%d:shortest=1,format=yuv420p[o]" % (lx, lx))
                seg = T / ("s%d.mp4" % k)
                ce._run(["-i", str(fit), "-loop", "1", "-framerate", "30", "-t", "%.3f" % ce.info(fit)["sec"], "-i", str(T / ("t%d.png" % k)),
                         "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(seg)])
                fit = seg
            segs.append(fit)
        body = T / "body.mp4"
        clip_track.join_each(segs, [segs_in[k].get("join", join) for k in range(1, len(segs))], fade, body) if len(segs) > 1 else shutil.copy2(segs[0], body)
        if hold_end > 0:
            clip_track.hold_end(body, hold_end, T / "held.mp4")
            body = T / "held.mp4"
        if end:
            clip_promo.card(end[0], end[1], font, w, h, T / "e.png")
            ce._run(["-sseof", "-0.2", "-i", str(body), "-frames:v", "1", str(T / "last.png")])
            fc = ("[0:v]gblur=sigma=%.1f,eq=brightness=-0.18:saturation=0.8[eb];"
                  "[1:v]format=rgba,fade=t=in:st=0.15:d=0.45:alpha=1[ec];[eb][ec]overlay=0:0,format=yuv420p[o]") % (14 * h / 720)
            ce._run(["-loop", "1", "-framerate", "30", "-t", "1.8", "-i", str(T / "last.png"), "-loop", "1", "-framerate", "30", "-t", "1.8", "-i", str(T / "e.png"),
                     "-filter_complex", fc, "-map", "[o]", "-an", "-t", "1.8", *ce.H264, str(T / "end.mp4")])
            clip_track.join([body, T / "end.mp4"], join if join != "cut" else "fade", fade, out)
        else:
            shutil.copy2(body, out)
    return out

REGIONS: list[list[float]] = []  # callout / track regions of the current spec run (portrait --fill track|focus crops to them)

def _union(boxes) -> list[float]:
    x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    return [x0, y0, max(b[0] + b[2] for b in boxes) - x0, max(b[1] + b[3] for b in boxes) - y0]

def _step(s: dict, cur: Path, nxt: Path, T: Path, root, font: str, base: Path, placed: list) -> Path:
    """One spec step from cur into nxt. placed: [(chip rect, start, end)] of earlier callouts, nudged around."""
    op = s["op"]
    i = ce.info(cur)
    rel = lambda p: p if Path(p).is_absolute() else base / p
    box = clip_fx.box_px(s["box"], i["w"], i["h"], root, s.get("movie", "")) if "box" in s else None
    st, en = float(s.get("start", 0.0)), float(s.get("end", 0.0)) or i["sec"]
    avoid = [r for r, a, b in placed if a < en and st < b]
    if op == "punch":
        punch(cur, box, nxt, s.get("start", 0.5), s.get("dur", 0.4), s.get("hold", 1.2))
    elif op == "callout" and "track" in s:
        rows = clip_track.keys(s["track"], i["w"], i["h"], root, s.get("movie", ""), base)
        clip_track.tracked(cur, rows, s["text"], nxt, st, en, s.get("color", "#ffd23f"), font, [], placed)
        REGIONS.append(_union([clip_track.at(rows, r[0]) for r in rows]))
    elif op == "callout":
        callout(cur, box, s["text"], nxt, st, en, s.get("color", "#ffd23f"), font, s.get("style", "box"), bool(s.get("leader", False)), avoid)
        REGIONS.append(list(box))
        placed.append((tuple(LAST_CHIP), st, en))
    elif op == "hold":
        clip_track.hold(cur, float(s["at"]), float(s.get("dur", 1.0)), nxt)
    elif op == "lower_third":
        clip_track.lower_third(cur, s["title"], nxt, s.get("sub", ""), s.get("start", 0.1), s.get("dur", 2.2), font,
                               float(s.get("sub_size", clip_track.SUB_K)))
    elif op == "caption":
        ce.caption(cur, s.get("text", ""), nxt, s.get("start", 0.0), s.get("end", 0.0), s.get("pos", "bottom"), font)
    elif op == "ba":
        clip_fx.ba(cur, rel(s["after"]), nxt, box, s.get("layout", "auto"), tuple(s.get("labels", ("Before", "After"))), font=font,
                   style=s.get("style", "promo"), subs=tuple(s.get("subs", ("", ""))), end=tuple(s["end_card"]) if s.get("end_card") else None)
    elif op == "export":
        nxt = nxt.with_suffix(".gif" if s.get("for") == "gif" else ".mp4")
        src = cur
        if s.get("for") == "portrait" and s.get("fill") in ("track", "focus"):
            reg = clip_fx.box_px(s["box"], i["w"], i["h"], root, s.get("movie", "")) if "box" in s else (
                _union(REGIONS) if REGIONS else [i["w"] * 0.25, 0, i["w"] * 0.5, i["h"]])
            src = clip_track.portrait(cur, reg, T / "portrait_focus.mp4", s.get("title", ""), s.get("sub", ""), font, clip_fx.SIZES["x-portrait"])
        elif s.get("for") == "portrait":
            src = clip_fx.fit(cur, clip_fx.SIZES["x-portrait"], T / "portrait_fit.mp4", s.get("fill", "blur"))
        ce.export(src, s.get("for", "x"), nxt, s.get("width", 0))
    else:
        raise ValueError("spec step: unknown op %r" % op)
    return nxt

def spec(path: Path, out: Path, root: Path | None = None) -> list[dict]:
    """Run a JSON edit list; returns one row per step (op, sec). Every path (clips, `after`, track .json files) is relative
    to the spec file's folder. Montage keys: join (fade|cut|dip|whip; a segment's own "join" overrides it at its seam),
    title_style (chip|lower), hold_end (s), and dict segments (title, sub, sub_size, trim, join, callouts). Export
    {"for": "portrait", "fill": "track"|"focus"} crops to the callout/track regions (or "box"), big title/sub in the bands."""
    REGIONS.clear()
    d = json.loads(path.read_text(encoding="utf-8"))
    rel = lambda p: p if Path(p).is_absolute() else path.parent / p
    font = d.get("font", "")
    rows, placed = [], []
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        if "montage" in d:
            segs = [dict(m, clip=str(rel(m["clip"]))) if isinstance(m, dict) else rel(m) for m in d["montage"]]
            cur = montage(segs, T / "m.mp4", d.get("titles"), d.get("fade", 0.4), tuple(d["end_card"]) if d.get("end_card") else None, font,
                          d.get("join", "fade"), d.get("title_style", "chip"), float(d.get("hold_end", 0.0)), root, path.parent)
            rows.append({"op": "montage", "sec": ce.info(cur)["sec"]})
        else:
            cur = rel(d["in"])
        for k, s in enumerate(d.get("steps", [])):
            try:
                cur = _step(s, cur, T / ("s%d.mp4" % k), T, root, font, path.parent, placed)
            except ValueError as e:
                raise ValueError("spec step %d: %s" % (k, e))
            rows.append({"op": s["op"], "sec": ce.info(cur)["sec"] if cur.suffix == ".mp4" else None})
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
    # montage options: per-segment callouts, lower-third titles, dip join, hold_end
    (t / "m.json").write_text(json.dumps({"montage": [{"clip": "ca.mp4", "title": "One", "callouts": [{"op": "callout", "box": [200, 100, 120, 80], "text": "A"}]}, "cb.mp4"],
                                          "join": "dip", "title_style": "lower", "hold_end": 1.0}))
    spec(t / "m.json", t / "m2.mp4")
    if abs(ce.info(t / "m2.mp4")["sec"] - (3 + 2 - 0.5 + 1.0)) > 0.2:
        bad.append("montage options: %s" % ce.info(t / "m2.mp4"))
    if not near(clip_fx._px(t / "m2.mp4", 1.5, (200, 140)), (255, 210, 63), 90):
        bad.append("montage per-segment callout missing")
    # two callouts on the same spot: the second chip is nudged off the first; neither lands in a title corner
    two = [{"op": "callout", "box": [260, 150, 100, 50], "text": "One"}, {"op": "callout", "box": [260, 150, 100, 50], "text": "Two"}]
    placed: list = []
    c1 = _step(two[0], a, t / "n1.mp4", t, None, "", t, placed)
    _step(two[1], c1, t / "n2.mp4", t, None, "", t, placed)
    r1, r2 = placed[0][0], placed[1][0]
    if clip_track._hit(r1, r2) or any(clip_track._hit(r, c) for r in (r1, r2) for c in clip_track.corners(640, 360)):
        bad.append("callout nudge/corners: %s %s" % (r1, r2))
    # tracked callout and hold through a spec
    (t / "trk.json").write_text(json.dumps({"in": "ca.mp4", "steps": [{"op": "callout", "track": [[0, 40, 40, 80, 60], [2, 440, 200, 80, 60]], "text": "T"},
                                                                       {"op": "hold", "at": 1.0, "dur": 0.5}]}))
    spec(t / "trk.json", t / "trk.mp4")
    if abs(ce.info(t / "trk.mp4")["sec"] - 3.5) > 0.15:
        bad.append("spec track+hold: %s" % ce.info(t / "trk.mp4"))
    bad += clip_track.selftest(t)
    return bad
