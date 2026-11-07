#!/usr/bin/env python3
"""Composed promo edits for `media.py clip` (clip_edit.py owns the CLI):

  punch     punch-in: ease into a box, hold, ease back out (clip_fx.zoom with back)
  callout   a box or ring (style) plus a promo chip label, optional leader line, staggered fade over [start, end]
  montage   clips joined with crossfades, each opening with its own chip title (top-left, centred on portrait), optional end card
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
        from imglib import geom
        if c.width > w or c.height > h:
            ratio = min(w / c.width, h / c.height)
            c = geom.resize_rgba(c, (max(1, int(c.width * ratio)), max(1, int(c.height * ratio))))
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

def focus_region(steps: list[dict], info: dict, root=None, base=Path("."), box=None, movie=""):
    """One segment's source region; never union regions from unrelated segments."""
    if box is not None:
        return clip_fx.box_px(box, info["w"], info["h"], root, movie)
    boxes = []
    for step in steps:
        if "track" in step:
            rows = clip_track.keys(step["track"], info["w"], info["h"], root, step.get("movie", ""), base)
            boxes.extend(row[1:] for row in rows)
        elif "box" in step:
            boxes.append(clip_fx.box_px(step["box"], info["w"], info["h"], root, step.get("movie", "")))
    return _union(boxes) if boxes else [info["w"] * 0.25, 0, info["w"] * 0.5, info["h"]]


def portrait_step(step: dict, info: dict, geometry, root=None, base=Path(".")) -> dict:
    """Resolve source-coordinate boxes/tracks once, then move them to the cropped canvas."""
    step = dict(step)
    if "box" in step:
        step["box"] = clip_track.portrait_box(clip_fx.box_px(step["box"], info["w"], info["h"], root, step.get("movie", "")), geometry)
    if "track" in step:
        step["track"] = [[row[0], *clip_track.portrait_box(row[1:], geometry)] for row in
                         clip_track.keys(step["track"], info["w"], info["h"], root, step.get("movie", ""), base)]
    return step


def montage(srcs: list, out: Path, titles: list[str] | None = None, fade: float = 0.4, end: tuple[str, str] | None = None, font: str = "",
            join: str = "fade", title_style: str = "chip", hold_end: float = 0.0, root: Path | None = None, base: Path = Path("."),
            size=(0, 0), fill: str = "pad", box=None, movie: str = "") -> Path:
    """Each clip at size (else first clip size), title over its first 1.6 s (portrait chip centred), joined by
    `join` (clip_track.JOINS: fade, cut, dip, whip); then the optional end card. A src may be a dict
    {"clip": PATH, "title", "sub", "sub_size" (x h, default 0.045), "trim": [IN, OUT] s (cut before a camera handback),
    "join" (how this segment joins the one before), "callouts": [callout steps]}; its callouts run on that segment only
    and share one `placed` list. fill track/focus/box crops EACH segment before chips and remaps callout geometry;
    comparison recipes rebuild clean A/B before native identity chips; segment box overrides the shared box; named boxes use the segment movie or shared movie. Native end cards are never cropped. hold_end freezes the last frame."""
    segs_in = [s if isinstance(s, dict) else {"clip": s} for s in srcs]
    srcs = [Path(s["clip"]) for s in segs_in]
    a = ce.info(srcs[0])
    if fill in ("track", "focus", "box") and not size[0]:
        size = clip_fx.SIZES["x-portrait"]
    w, h = size if size[0] else (a["w"] - a["w"] % 2, a["h"] - a["h"] % 2)
    font = ce._font(font)
    titles = (titles or []) + [""] * len(srcs)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        segs = []
        for k, s in enumerate(srcs):
            original = s
            if segs_in[k].get("trim"):
                a0, a1 = (float(v) for v in segs_in[k]["trim"])
                ce._run(["-ss", "%.3f" % a0, "-i", str(s), "-t", "%.3f" % (a1 - a0), "-an", *ce.H264, str(T / ("tr%d.mp4" % k))])
                s = T / ("tr%d.mp4" % k)
            source_info = ce.info(s)
            steps = segs_in[k].get("callouts", [])
            identity_pad = 0
            comparison = None
            if fill in ("track", "focus", "box"):
                explicit = segs_in[k].get("box", box)
                if fill == "box" and explicit is None:
                    raise ValueError("portrait fill box needs a segment box or --box")
                region = focus_region(steps, source_info, root, base, explicit, segs_in[k].get("movie", movie))
                geometry = clip_track.portrait_geometry(region, source_info["w"], source_info["h"], (w, h))
                comparison = segs_in[k].get("comparison")
                sidecar = original.with_suffix(".comparison.json")
                if comparison is None and sidecar.is_file():
                    comparison = json.loads(sidecar.read_text(encoding="utf-8"))
                    comparison = dict(comparison, **{key: str((sidecar.parent / comparison[key]).resolve())
                                                     for key in ("before", "after")})
                if comparison is not None:
                    identity_pad = clip_promo.identity_space(w, h)
                if comparison is not None and segs_in[k].get("trim"):
                    comparison = dict(comparison, trim=segs_in[k]["trim"])
                fit = clip_track.portrait(original if comparison is not None else s, region, T / ("f%d.mp4" % k),
                                          size=(w, h), comparison=comparison, base=base, defer_identity=comparison is not None)
                steps = [portrait_step(st, source_info, geometry, root, base) for st in steps]
            else:
                fit = clip_fx.fit(s, (w, h), T / ("f%d.mp4" % k), fill) if (source_info["w"], source_info["h"]) != (w, h) else s
            seg_placed: list = [((0, h - identity_pad, w, identity_pad), 0, ce.info(fit)["sec"], object())] if identity_pad else []
            for j, st in enumerate(steps):
                fit = _step(st, fit, T / ("c%d_%d.mp4" % (k, j)), T, root, font, base, seg_placed)
            title = segs_in[k].get("title", titles[k])
            if title and title_style == "lower":
                fit = clip_track.lower_third(fit, title, T / ("l%d.mp4" % k), segs_in[k].get("sub", ""), 0.1, 2.2, font,
                                             float(segs_in[k].get("sub_size", clip_track.SUB_K)), bottom_pad=identity_pad)
                titles[k] = ""
            elif title:
                titles[k] = title
                clip_promo.chip(titles[k], segs_in[k].get("sub", ""), clip_promo.COL[1], font, h, T / ("t%d.png" % k))
                from PIL import Image
                from imglib import geom
                with Image.open(T / ("t%d.png" % k)) as chip:
                    if chip.width > w * 0.92:
                        geom.resize_rgba(chip, (int(w * 0.92), max(1, int(chip.height * w * 0.92 / chip.width)))).save(T / ("t%d.png" % k))
                with Image.open(T / ("t%d.png" % k)) as chip:
                    lx = (w - chip.width) // 2 if h > w else int(30 * h / 720)
                ly = int(30 * h / 720)
                fc = ("[1:v]format=rgba,fade=t=in:st=0.1:d=0.3:alpha=1,fade=t=out:st=1.6:d=0.3:alpha=1[l];[0:v][l]overlay=%d:%d:shortest=1,format=yuv420p[o]" % (lx, ly))
                seg = T / ("s%d.mp4" % k)
                ce._run(["-i", str(fit), "-loop", "1", "-framerate", "30", "-t", "%.3f" % ce.info(fit)["sec"], "-i", str(T / ("t%d.png" % k)),
                         "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, str(seg)])
                fit = seg
            if comparison is not None:
                fit = clip_promo.identities(fit, T / ("identity%d.mp4" % k), comparison)
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
    """One spec step from cur into nxt. placed: owned (chip rect, start, end, owner) records; legacy 3-tuples accepted."""
    op = s["op"]
    i = ce.info(cur)
    rel = lambda p: p if Path(p).is_absolute() else base / p
    box = clip_fx.box_px(s["box"], i["w"], i["h"], root, s.get("movie", "")) if "box" in s else None
    st, en = float(s.get("start", 0.0)), float(s.get("end", 0.0)) or i["sec"]
    avoid = [r for r, a, b, _ in clip_track.chip_records(placed) if a < en and st < b]
    if op == "punch":
        punch(cur, box, nxt, s.get("start", 0.5), s.get("dur", 0.4), s.get("hold", 1.2))
    elif op == "callout" and "track" in s:
        rows = clip_track.keys(s["track"], i["w"], i["h"], root, s.get("movie", ""), base)
        clip_track.tracked(cur, rows, s["text"], nxt, st, en, s.get("color", "#ffd23f"), font, [], placed)
        REGIONS.append(_union([clip_track.at(rows, r[0]) for r in rows]))
    elif op == "callout":
        callout(cur, box, s["text"], nxt, st, en, s.get("color", "#ffd23f"), font, s.get("style", "box"), bool(s.get("leader", False)), avoid)
        REGIONS.append(list(box))
        placed.append((tuple(LAST_CHIP), st, en, object()))
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
        if s.get("for") == "portrait" and s.get("fill") in ("track", "focus", "box"):
            if s.get("fill") == "box" and "box" not in s:
                raise ValueError("portrait fill box needs box")
            reg = clip_fx.box_px(s["box"], i["w"], i["h"], root, s.get("movie", "")) if "box" in s else (
                _union(REGIONS) if REGIONS else [i["w"] * 0.25, 0, i["w"] * 0.5, i["h"]])
            src = clip_track.portrait(cur, reg, T / "portrait_focus.mp4", s.get("title", ""), s.get("sub", ""), font, clip_fx.size_of(s.get("size", "x-portrait")))
        elif s.get("for") == "portrait":
            target = clip_fx.size_of(s.get("size", "x-portrait"))
            src = clip_fx.fit(cur, target, T / "portrait_fit.mp4", s.get("fill", "blur"))
        ce.export(src, s.get("for", "x"), nxt, s.get("width", 0))
    else:
        raise ValueError("spec step: unknown op %r" % op)
    return nxt

def spec(path: Path, out: Path, root: Path | None = None) -> list[dict]:
    """Run a JSON edit list; returns one row per step (op, sec). Every path (clips, `after`, track .json files) is relative
    to the spec file's folder. Montage keys: join (fade|cut|dip|whip; a segment's own "join" overrides it at its seam),
    title_style (chip|lower), hold_end (s), and dict segments (title, sub, sub_size, trim, join, callouts, box). Final export
    {"for": "portrait", "fill": "track"|"focus"|"box", "size": "720x900"} crops per segment BEFORE callout/title chips,
    then draws a native end card. Comparison producers keep a .comparison.json clean-source
    recipe; legacy segments can supply comparison={before,after,labels,subs,hold,sweep,hold_b,zoom,zoom_in}.
    Paths are relative to the sidecar/spec. Both clean legs crop before identity chips; missing legs fail.
    Opaque legacy baked inputs need an explicit recipe, not guessed identity/timing.
    Non-montage annotation-only specs use the same crop-first path."""
    REGIONS.clear()
    d = json.loads(path.read_text(encoding="utf-8"))
    rel = lambda p: p if Path(p).is_absolute() else path.parent / p
    font = d.get("font", "")
    rows, placed = [], []
    steps = list(d.get("steps", []))
    native = steps[-1] if steps and steps[-1].get("op") == "export" and steps[-1].get("for") == "portrait" and steps[-1].get("fill") in ("track", "focus", "box") else None
    native_size = clip_fx.size_of(native.get("size", "x-portrait")) if native else (0, 0)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        if "montage" in d:
            segs = [dict(m, clip=str(rel(m["clip"]))) if isinstance(m, dict) else rel(m) for m in d["montage"]]
            cur = montage(segs, T / "m.mp4", d.get("titles"), d.get("fade", 0.4), tuple(d["end_card"]) if d.get("end_card") else None, font,
                          d.get("join", "fade"), d.get("title_style", "chip"), float(d.get("hold_end", 0.0)), root, path.parent,
                          native_size, native["fill"] if native else "pad", native.get("box") if native else None, native.get("movie", "") if native else "")
            rows.append({"op": "montage", "sec": ce.info(cur)["sec"]})
        else:
            cur = rel(d["in"])
        if native and "montage" not in d and all(s["op"] in ("callout", "caption", "lower_third") for s in steps[:-1]):
            cur = montage([{"clip": cur, "callouts": steps[:-1], "title": native.get("title", ""), "sub": native.get("sub", "")}], T / "native.mp4", font=font, root=root, base=path.parent,
                          size=native_size, fill=native["fill"], box=native.get("box"), movie=native.get("movie", ""))
            steps = [native]
        for k, s in enumerate(steps):
            if native is s and ("montage" in d or cur == T / "native.mp4"):
                s = dict(s, fill="pad")  # already composed at native size; never crop the chips or card again

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
    bad += portrait_selftest(t)
    bad += comparison_selftest(t)
    bad += clip_track.selftest(t)
    return bad


def portrait_selftest(t: Path) -> list[str]:
    """Synthetic two-subject segments exercise real crop-first composition and CLI."""
    import subprocess
    import sys
    from PIL import Image, ImageDraw
    bad = []
    image = Image.new("RGB", (640, 360), (220, 30, 30))
    ImageDraw.Draw(image).rectangle((320, 0, 640, 360), fill=(30, 30, 220))
    image.save(t / "subjects.png")
    ce._run(["-loop", "1", "-framerate", "10", "-i", str(t / "subjects.png"), "-t", "0.8", *ce.H264, str(t / "subjects.mp4")])
    segments = [{"clip": "subjects.mp4", "title": title, "box": box,
                 "callouts": [{"op": "callout", "box": box, "text": "SUBJECT", "color": "#00ff00"}]}
                for title, box in (("Left subject", [30, 120, 60, 60]), ("Right subject", [550, 120, 60, 60]))]
    data = {"montage": segments, "join": "cut", "fade": 0.1, "end_card": ["Native portrait card", "Full width"],
            "steps": [{"op": "export", "for": "portrait", "fill": "box", "size": "320x400"}]}
    (t / "native.json").write_text(json.dumps(data))
    spec(t / "native.json", t / "native.mp4")
    got = ce.info(t / "native.mp4")
    if (got["w"], got["h"]) != (320, 400):
        bad.append("native portrait dimensions: " + str(got))
    for when, channel in ((0.4, 0), (1.2, 2)):
        pixel = clip_fx._px(t / "native.mp4", when, (160, 200))
        if pixel[channel] < 170 or pixel[1] > 90:
            bad.append("per-segment focus at %s: %s" % (when, pixel))
    # Source boxes are mapped before their outline/chip is rendered, not cropped afterward.
    geometry = clip_track.portrait_geometry([550, 120, 60, 60], 640, 360, (320, 400))
    mapped = portrait_step({"box": [550, 120, 60, 60], "track": [[0, 550, 120, 60, 60]]}, {"w": 640, "h": 360}, geometry)
    if mapped["box"] != mapped["track"][0][1:] or not 0 <= mapped["box"][0] < 320:
        bad.append("portrait source geometry mapping: " + str(mapped))
    # Public box names must use the selected movie, not the first same-named region.
    (t / "project.godot").write_text('[application]\nconfig/name="clip-selftest"\n')
    (t / "tools/data").mkdir(parents=True, exist_ok=True)
    (t / "tools/data/movies.json").write_text(json.dumps({"movies": {
        "wrong": {"regions": {"subject": [0.5, 0, 0.5, 1]}},
        "selected": {"regions": {"subject": [0, 0, 0.5, 1]}}}}))
    entry = str(Path(__file__).resolve().parents[2] / "media.py")
    for fill in ("box", "focus", "track"):
        output = t / (fill + "-cli.mp4")
        cli = subprocess.run([sys.executable, entry, "clip", "export", str(t / "subjects.mp4"), "--root", str(t),
                              "--for", "portrait", "--size", "160x200", "--fill=" + fill,
                              "--box", "subject", "--movie", "selected", "--out", str(output)], capture_output=True, text=True)
        if cli.returncode or ce.info(output)["h"] != 200 or clip_fx._px(output, 0.4, (80, 100))[0] < 170:
            bad.append("portrait " + fill + " CLI: " + cli.stdout + cli.stderr)
    cli = subprocess.run([sys.executable, entry, "clip", "montage", str(t / "subjects.mp4"), str(t / "subjects.mp4"),
                          "--root", str(t), "--size", "160x200", "--fill", "box", "--box", "subject", "--movie", "selected",
                          "--labels", "", "--out", str(t / "movie-box.mp4")], capture_output=True, text=True)
    if cli.returncode or clip_fx._px(t / "movie-box.mp4", 0.4, (80, 100))[0] < 170:
        bad.append("montage selected movie box: " + cli.stdout + cli.stderr)
    # Measure the existing chip helper's asset, then check its centred accent in a real 4:5 frame.
    clip_promo.chip("Left subject", "", clip_promo.COL[1], ce._font(""), 400, t / "title-chip.png")
    with Image.open(t / "title-chip.png") as chip:
        lx = (320 - chip.width) // 2
    accent = clip_fx._px(t / "native.mp4", 0.4, (lx + 8, 16 + 26))
    if not (accent[0] > 180 and accent[1] > 150 and accent[2] < 150):
        bad.append("4:5 title chip not centred: " + str(accent))
    # Existing placement owner must not cover the subject when another in-frame spot exists.
    p = clip_track.place_chip(100, 40, (0, 300, 100, 60), 640, 360, clip_track.corners(640, 360))
    if clip_track._hit((*p, 100, 40), (0, 300, 100, 60)) or min(p) < 0:
        bad.append("edge chip covers subject: " + str(p))
    return bad


def comparison_selftest(t: Path) -> list[str]:
    """Baked comparison inputs must reconstruct clean legs, retaining identity after crop."""
    from PIL import Image
    import subprocess
    bad = []
    for name, color in (("clean-a", "#b02020"), ("clean-b", "#2020b0")):
        ce._run(["-f", "lavfi", "-i", "color=c=%s:s=640x360:r=10:d=2.1" % color, *ce.H264, str(t / (name + ".mp4"))])
    baked = t / "baked.mp4"
    clip_promo.wipe(t / "clean-a.mp4", t / "clean-b.mp4", baked, hold=0.5, sweep=0.8, hold_b=0.8)
    recipe = json.loads(baked.with_suffix(".comparison.json").read_text())
    shutil.copy2(baked, t / "legacy.mp4")  # no sidecar: exercise the explicit old-asset recipe too
    for size, fill in (((320, 400), "box"), ((320, 560), "track"), ((320, 400), "focus")):
        W, H = size
        data = {"montage": [
            {"clip": str(baked), "box": [480, 40, 80, 80], "title": "Roof", "sub": "Details", "trim": [0.1, 2.0], "callouts": [{"op": "callout", "box": [0, 0, 640, 360], "text": "Large competing callout", "color": "#00ff00"}]},
            {"clip": str(t / "legacy.mp4"), "comparison": recipe, "box": [480, 40, 80, 80], "title": "Market"}],
            "title_style": "lower", "join": "cut", "steps": [{"op": "export", "for": "portrait", "fill": fill, "size": "%dx%d" % size}]}
        path = t / ("identity-%s.json" % fill);path.write_text(json.dumps(data))
        output = path.with_suffix(".mp4");spec(path, output)
        if abs(ce.info(output)["sec"] - 4.0) > 0.15:
            bad.append("comparison trim/montage duration: %s got=%s" % (fill, ce.info(output)["sec"]))
        for when, after in ((0.5, False), (1.5, True), (2.5, False), (3.6, True)):
            raw = subprocess.check_output(["ffmpeg", "-v", "error", "-ss", str(when), "-i", str(output), "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
            image = Image.frombytes("RGB", size, raw)
            stamp_dir = t / "expected-chips"; stamp_dir.mkdir(exist_ok=True)
            clip_promo._chips(stamp_dir, W, H, ("BEFORE", "AFTER"), ("", ""), ce._font(""))
            stamp = Image.open(stamp_dir / ("b.png" if after else "a.png")).convert("RGBA")
            lx = int(30 * min(W, H) / 720)
            x0, y0 = lx // 2 * 2, (H - stamp.height - lx) // 2 * 2  # ffmpeg yuv420 overlay coordinates
            wanted = clip_promo.COL[int(after)][:3]
            points = [(x, y) for y in range(stamp.height) for x in range(stamp.width)
                      if stamp.getpixel((x, y)) == (*wanted, 255)]
            matched = sum(max(abs(a - b) for a, b in zip(image.getpixel((x0 + x, y0 + y)), wanted)) < 65
                          for x, y in points)
            if not points or matched / len(points) < 0.90:
                bad.append("comparison identity occluded %s t=%s after=%s matched=%s/%s" % (fill, when, after, matched, len(points)))

    stale = dict(recipe, source_sha256="stale")
    try:
        clip_promo.reframe(baked, [400, 0, 100, 100], t / "stale-result.mp4", (320, 400), stale)
        bad.append("stale comparison recipe was trusted")
    except ValueError:
        pass
    missing = dict(recipe, before=str(t / "missing.mp4"))
    try:
        clip_promo.reframe(baked, [400, 0, 100, 100], t / "missing-result.mp4", (320, 400), missing)
        bad.append("comparison missing clean leg silently fell back to baked input")
    except ValueError:
        pass
    return bad
