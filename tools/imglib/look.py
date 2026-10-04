"""Programmatic eyes: compact text facts about an image (plus optional annotated PNGs).

Every function returns plain data; `fmt_*` turn it into short text. CLI: tools/img_inspect.py.
  describe  size, alpha coverage, content box, margins, palette
  regions   element boxes (components) with layout checks: off-screen, clipped, overlap, alignment, spacing
  contrast  WCAG ratio of a box (text vs its background) and the safe-area check
  grid / zoom   labeled coordinate overlay, crop + zoom
  find      locate a template or sprite (OpenCV matchTemplate)
  halo      colour bleed on the rim of a keyed image; edge density
  motion    changed-pixel % per frame across a sequence
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw

from . import compare, geom, require_cv2, cv2
from .color import contrast_ratio, delta_e, hsv, hue_gap, palette
from .key import components, dilate

# ---------------------------------------------------------------- describe

def describe(im: Image.Image, n_colors: int = 6) -> dict:
    rgba = im.convert("RGBA")
    a = np.asarray(rgba)[..., 3]
    box = geom.bbox(rgba)
    w, h = rgba.size
    out = {"size": [w, h], "mode": im.mode, "alpha_pct": round(100.0 * float((a > 0).mean()), 1),
           "partial_alpha_pct": round(100.0 * float(((a > 0) & (a < 255)).mean()), 2), "box": list(box) if box else None,
           "palette": palette(rgba, n_colors)}
    out["margins"] = {"left": box[0], "top": box[1], "right": w - box[2], "bottom": h - box[3]} if box else None
    return out


def fmt_describe(d: dict) -> str:
    pal = " ".join("#%02X%02X%02X:%s%%" % (c[0], c[1], c[2], p) for c, p in d["palette"])
    m = d["margins"]
    mt = f"margins L{m['left']} T{m['top']} R{m['right']} B{m['bottom']}" if m else "empty"
    return f"size {d['size'][0]}x{d['size'][1]} {d['mode']} | opaque {d['alpha_pct']}% (partial {d['partial_alpha_pct']}%) | content box {d['box']} | {mt}\npalette {pal}"

# ---------------------------------------------------------------- regions / layout

def content_mask(im: Image.Image, thresh: float = 18.0) -> np.ndarray:
    """True where something is drawn: alpha > 0 on a transparent image, else Lab distance from the border colour."""
    rgba = np.asarray(im.convert("RGBA"))
    if (rgba[..., 3] < 255).any():
        return rgba[..., 3] > 0
    from .color import background_refs
    rgb = np.ascontiguousarray(rgba[..., :3])
    return delta_e(rgb, background_refs(rgb, k=1)) > thresh


def regions(im: Image.Image, merge: int = 6, min_area: int = 12, mask: np.ndarray | None = None) -> list:
    """Element boxes (l, t, r, b), merged within `merge` px, reading order (top then left)."""
    m = content_mask(im) if mask is None else mask
    bx = compare.boxes(m, merge=merge, limit=400, min_area=min_area)
    return sorted(bx, key=lambda b: (b[1] // max(4, merge * 2), b[0]))


def _nested(a, b) -> bool:
    """One box fully inside the other (a panel and its contents): not an overlap."""
    return (a[0] <= b[0] and a[1] <= b[1] and a[2] >= b[2] and a[3] >= b[3]) or (b[0] <= a[0] and b[1] <= a[1] and b[2] >= a[2] and b[3] >= a[3])


def _inter(a, b) -> int:
    w = min(a[2], b[2]) - max(a[0], b[0])
    h = min(a[3], b[3]) - max(a[1], b[1])
    return w * h if w > 0 and h > 0 else 0


def layout(boxes: list, size: tuple[int, int], safe: float = 0.05, tol: int = 3) -> dict:
    """Layout facts for element boxes on a (w, h) screen."""
    w, h = size
    sx, sy = int(w * safe), int(h * safe)
    res = {"count": len(boxes), "offscreen": [], "clipped": [], "outside_safe": [], "overlaps": [], "near_aligned": [], "gaps": {}}
    for i, b in enumerate(boxes):
        if b[0] < 0 or b[1] < 0 or b[2] > w or b[3] > h:
            res["offscreen"].append(i)
        elif b[0] == 0 or b[1] == 0 or b[2] == w or b[3] == h:
            res["clipped"].append(i)
        if b[0] < sx or b[1] < sy or b[2] > w - sx or b[3] > h - sy:
            res["outside_safe"].append(i)
    for i in range(len(boxes)):
        for j in range(i + 1, len(boxes)):
            ov = _inter(boxes[i], boxes[j])
            if ov and not _nested(boxes[i], boxes[j]):
                res["overlaps"].append((i, j, ov))
    for name, idx in (("left", 0), ("top", 1), ("right", 2), ("bottom", 3)):
        vals = sorted((boxes[i][idx], i) for i in range(len(boxes)))
        for (v1, i1), (v2, i2) in zip(vals, vals[1:]):
            if 0 < v2 - v1 <= tol:
                res["near_aligned"].append((name, i1, i2, v2 - v1))
    for axis, name in ((0, "horizontal"), (1, "vertical")):
        gaps = []
        order = sorted(range(len(boxes)), key=lambda i: boxes[i][axis])
        for a_i, b_i in zip(order, order[1:]):
            a, b = boxes[a_i], boxes[b_i]
            cross = min(a[3 - axis], b[3 - axis]) - max(a[1 - axis], b[1 - axis])
            g = b[axis] - a[axis + 2]
            if cross > 0 and g >= 0:
                gaps.append(g)
        if gaps:
            res["gaps"][name] = {"values": gaps[:20], "min": min(gaps), "max": max(gaps), "spread": max(gaps) - min(gaps)}
    return res


def fmt_layout(boxes: list, res: dict, limit: int = 30) -> str:
    lines = [f"{res['count']} elements"]
    for i, b in enumerate(boxes[:limit]):
        lines.append(f"  #{i} x{b[0]} y{b[1]} {b[2] - b[0]}x{b[3] - b[1]}")
    if len(boxes) > limit:
        lines.append(f"  ... {len(boxes) - limit} more")
    for key in ("offscreen", "clipped", "outside_safe"):
        if res[key]:
            lines.append(f"{key}: {res[key][:20]}")
    if res["overlaps"]:
        lines.append("overlaps: " + ", ".join(f"#{i}/#{j} {a}px" for i, j, a in res["overlaps"][:12]))
    if res["near_aligned"]:
        lines.append("near-aligned (off by 1-3 px): " + ", ".join(f"{n} #{i}/#{j} by {d}" for n, i, j, d in res["near_aligned"][:12]))
    for k, g in res["gaps"].items():
        lines.append(f"gaps {k}: min {g['min']} max {g['max']} spread {g['spread']} {g['values']}")
    return "\n".join(lines)


def annotate(im: Image.Image, boxes: list, res: dict | None = None) -> Image.Image:
    """Boxes numbered on a copy: green ok, red off-screen/clipped, orange overlap."""
    out = im.convert("RGB").copy()
    d = ImageDraw.Draw(out)
    bad = set(res["offscreen"] + res["clipped"]) if res else set()
    ov = {k for t in res["overlaps"] for k in t[:2]} if res else set()
    for i, b in enumerate(boxes):
        col = (255, 60, 60) if i in bad else (255, 160, 0) if i in ov else (0, 220, 90)
        d.rectangle((b[0], b[1], b[2] - 1, b[3] - 1), outline=col)
        d.text((b[0] + 2, b[1] + 1), str(i), fill=col)
    return out

# ---------------------------------------------------------------- contrast / safe area

def contrast(im: Image.Image, box: tuple, large: bool = False) -> dict:
    """WCAG contrast of the two dominant colours in a box (text vs background): the most common colour is the
    background, the colour farthest from it (Lab) with a real share is the text."""
    crop = np.asarray(im.convert("RGB").crop(box))
    px = crop.reshape(-1, 3)
    q = (px >> 3).astype(np.int32)
    key = q[:, 0] * 1024 + q[:, 1] * 32 + q[:, 2]
    vals, cnt = np.unique(key, return_counts=True)
    bg_key = vals[cnt.argmax()]
    bg = tuple(int(v) for v in px[key == bg_key].mean(axis=0).round())
    d = delta_e(px.reshape(1, -1, 3), [bg])[0]
    far = d >= 25
    if far.sum() < max(3, 0.01 * len(px)):
        return {"box": list(box), "bg": bg, "fg": None, "ratio": 1.0, "pass": False, "need": 3.0 if large else 4.5, "note": "no distinct foreground"}
    fg = tuple(int(v) for v in px[far][d[far] >= np.percentile(d[far], 70)].mean(axis=0).round())
    r = contrast_ratio(fg, bg)
    need = 3.0 if large else 4.5
    return {"box": list(box), "bg": bg, "fg": fg, "ratio": round(r, 2), "need": need, "pass": r >= need}


def fmt_contrast(c: dict) -> str:
    hx = lambda v: "none" if v is None else "#%02X%02X%02X" % v
    return f"box {c['box']} text {hx(c['fg'])} on {hx(c['bg'])} ratio {c['ratio']}:1 need {c['need']} -> {'PASS' if c['pass'] else 'FAIL'}" + (f" ({c['note']})" if c.get("note") else "")

# ---------------------------------------------------------------- grid / zoom

def grid_overlay(im: Image.Image, step: int = 100, color=(255, 255, 0)) -> Image.Image:
    out = im.convert("RGB").copy()
    d = ImageDraw.Draw(out, "RGBA")
    for x in range(0, out.width, step):
        d.line((x, 0, x, out.height), fill=color + (110,))
        d.text((x + 2, 2), str(x), fill=color + (255,))
    for y in range(0, out.height, step):
        d.line((0, y, out.width, y), fill=color + (110,))
        d.text((2, y + 2), str(y), fill=color + (255,))
    return out


def zoom(im: Image.Image, box: tuple, factor: int = 4, label: bool = True) -> Image.Image:
    crop = im.convert("RGBA").crop(box)
    big = geom.scale_nearest(crop, factor)
    out = Image.new("RGB", big.size, (0, 0, 0))
    out.paste(compare.checker(big.size), (0, 0))
    out.paste(big, (0, 0), big)
    if label:
        d = ImageDraw.Draw(out)
        d.text((2, 2), f"{box[0]},{box[1]} x{factor}", fill=(255, 255, 0))
    return out

# ---------------------------------------------------------------- anchors

def find(shot: Image.Image, template: Image.Image, threshold: float = 0.9, limit: int = 8) -> list:
    """Where `template` appears in `shot`: [(x, y, w, h, score)], best first (OpenCV normalised correlation;
    a transparent template is matched through its alpha)."""
    require_cv2("find (template matching)")
    s = np.asarray(shot.convert("RGB"))
    t_rgba = np.asarray(template.convert("RGBA"))
    t = np.ascontiguousarray(t_rgba[..., :3])
    mask = None
    if (t_rgba[..., 3] < 255).any():
        mask = np.ascontiguousarray(np.repeat((t_rgba[..., 3:4] > 0).astype(np.uint8) * 255, 3, axis=2))
    if t.shape[0] > s.shape[0] or t.shape[1] > s.shape[1]:
        return []
    res = cv2.matchTemplate(s, t, cv2.TM_CCORR_NORMED if mask is not None else cv2.TM_CCOEFF_NORMED, mask=mask) if mask is not None else cv2.matchTemplate(s, t, cv2.TM_CCOEFF_NORMED)
    res = np.nan_to_num(res, nan=0.0, posinf=0.0, neginf=0.0)
    out = []
    th, tw = t.shape[:2]
    work = res.copy()
    while len(out) < limit:
        _mn, mx, _a, loc = cv2.minMaxLoc(work)
        if mx < threshold:
            break
        x, y = loc
        out.append((int(x), int(y), tw, th, round(float(mx), 4)))
        work[max(0, y - th // 2):y + th // 2 + 1, max(0, x - tw // 2):x + tw // 2 + 1] = -1.0
    return out

# ---------------------------------------------------------------- edges / halo

def rim(im: Image.Image) -> np.ndarray:
    """Opaque pixels that touch a transparent pixel (8-neighbourhood)."""
    a = np.asarray(im.convert("RGBA"))[..., 3]
    clear = a < 8
    return (a >= 8) & dilate(clear, 1)


def halo(im: Image.Image, hue: float = 310.0, hue_tol: float = 40.0) -> dict:
    """Colour bleed on a keyed picture's rim: share of rim pixels tinted with the plate hue, compared with the
    interior (pixels 3+ px inside), plus a count of leftover bright, saturated plate-coloured opaque pixels anywhere
    (maroon and crimson art do not count)."""
    arr = np.asarray(im.convert("RGBA"))
    rgb = np.ascontiguousarray(arr[..., :3])
    h, s, v = hsv(rgb)
    tint = (hue_gap(h, hue) <= hue_tol) & (s >= 0.25) & (v >= 0.2)
    opaque = arr[..., 3] >= 8
    r = rim(im)
    inner = opaque & ~dilate(~opaque, 3)
    plate_like = (hue_gap(h, hue) <= 30.0) & (s >= 0.55) & (v >= 0.6) & opaque
    n_rim = int(r.sum())
    return {"rim_px": n_rim, "halo_px": int((tint & r).sum()),
            "halo_pct": round(100.0 * float((tint & r).sum()) / max(1, n_rim), 2),
            "interior_tint_pct": round(100.0 * float((tint & inner).sum()) / max(1, int(inner.sum())), 2),
            "plate_like_px": int(plate_like.sum()), "plate_like_blobs": components(plate_like)[0],
            "mask": tint & r}


def fmt_halo(d: dict) -> str:
    verdict = "CLEAN" if d["plate_like_px"] == 0 and d["halo_pct"] <= d["interior_tint_pct"] + 2.0 else "CHECK"
    return (f"rim {d['rim_px']} px | halo (plate-hue rim) {d['halo_px']} px = {d['halo_pct']}% vs interior {d['interior_tint_pct']}% | "
            f"leftover plate-coloured opaque {d['plate_like_px']} px in {d['plate_like_blobs']} blobs -> {verdict}")


def edges(im: Image.Image) -> dict:
    """Edge density (share of pixels on a Canny edge); needs OpenCV."""
    require_cv2("edges")
    g = cv2.cvtColor(np.asarray(im.convert("RGB")), cv2.COLOR_RGB2GRAY)
    e = cv2.Canny(g, 80, 160)
    return {"edge_pct": round(100.0 * float((e > 0).mean()), 2)}

# ---------------------------------------------------------------- motion

def motion(frames: list, tol: int = 8) -> dict:
    """Changed-pixel % between consecutive frames (PIL images, same size)."""
    rows = []
    for i in range(1, len(frames)):
        d = compare.delta_map(frames[i - 1], frames[i])
        m = d > tol
        ys, xs = np.nonzero(m)
        rows.append({"frame": i, "changed_pct": round(100.0 * float(m.mean()), 3),
                     "bbox": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1] if len(xs) else None})
    pcts = [r["changed_pct"] for r in rows]
    return {"frames": len(frames), "rows": rows, "static": sum(p == 0 for p in pcts), "max_pct": max(pcts, default=0.0),
            "mean_pct": round(sum(pcts) / max(1, len(pcts)), 3)}


def fmt_motion(d: dict) -> str:
    lines = [f"{d['frames']} frames | static steps {d['static']}/{len(d['rows'])} | mean {d['mean_pct']}% max {d['max_pct']}%"]
    lines += [f"  {r['frame'] - 1}->{r['frame']}: {r['changed_pct']}%  {r['bbox']}" for r in d["rows"][:40]]
    return "\n".join(lines)
