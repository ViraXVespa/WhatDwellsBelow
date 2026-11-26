"""Measure T-pose head, thigh, and calf size against the in-game woman.

Vision rubber-stamps scale, so this gate is pixels and mesh projections.
The clothed sprites are the reference, not inputs. Their arms are down, and
running the T-pose arm finder on them would call the coat the chest.

idle_down.png, border mask: head/coat about 0.71, one thigh/coat about 0.30,
one calf/coat about 0.19. idle_left.png: head/chest about 1.33 with hair,
thigh/chest about 0.83, calf/chest about 0.63.

A bald mannequin chest is the ribcage, which sits inside that coat. Front and
back therefore pass only when the head is a little wider than the ribcage and
each leg is slimmer than the current oversized mesh. The two side views share
a wider band because a round head is deeper than the chest. A pass is not a
look approval.
"""
from __future__ import annotations

import json
import struct
import tempfile
from pathlib import Path

from PIL import Image

from media.pipeline import mesh_check

# One limb over the ribcage. Front and back share FRONT. Left and right share SIDE.
FRONT = {"head_min": 0.75, "head_max": 1.20, "thigh_max": 0.50, "calf_max": 0.32}
SIDE = {"head_min": 0.90, "head_max": 1.60, "thigh_max": 0.95, "calf_max": 0.72}
HEAD_DELTA = 0.15
THIGH_DELTA = 0.12
CALF_DELTA = 0.10
BG_DISTANCE = 28
STILL_ROLES = frozenset({"mannequin-smooth", "mannequin-tpose-side", "mannequin-tpose-back"})
REF_NAME = "proportion-ref.json"
_FIELDS = ("ok", "view", "head_ratio", "thigh_ratio", "calf_ratio", "head_px", "chest_px", "thigh_px", "calf_px", "failed", "reason")


def _median(values: list[int]) -> int:
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


def _mask(im: Image.Image) -> tuple[bytearray, int, int]:
    """Foreground is distance from the border color. A clear border also drops alpha under 128."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    pix = rgba.load()
    border_clear = False
    for x in range(0, w, max(1, w // 32)):
        if pix[x, 0][3] < 128 or pix[x, h - 1][3] < 128:
            border_clear = True
            break
    if not border_clear:
        for y in range(0, h, max(1, h // 32)):
            if pix[0, y][3] < 128 or pix[w - 1, y][3] < 128:
                border_clear = True
                break
    samples = [pix[x, 0][:3] for x in range(w)]
    samples.extend(pix[x, h - 1][:3] for x in range(w))
    samples.extend(pix[0, y][:3] for y in range(h))
    samples.extend(pix[w - 1, y][:3] for y in range(h))
    bg = tuple(_median([sample[channel] for sample in samples]) for channel in range(3))
    limit = BG_DISTANCE * BG_DISTANCE
    mask = bytearray(w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            if border_clear and pix[x, y][3] < 128:
                continue
            red, green, blue = pix[x, y][:3]
            dist = (red - bg[0]) ** 2 + (green - bg[1]) ** 2 + (blue - bg[2]) ** 2
            if dist > limit:
                mask[row + x] = 1
    return _largest(mask, w, h), w, h


def _largest(mask: bytearray, w: int, h: int) -> bytearray:
    """Keep the largest 8-connected mass so a speck cannot set the bbox."""
    seen = bytearray(w * h)
    best: list[int] = []
    for start in range(w * h):
        if seen[start] or not mask[start]:
            continue
        stack = [start]
        seen[start] = 1
        comp: list[int] = []
        while stack:
            cur = stack.pop()
            comp.append(cur)
            cy, cx = divmod(cur, w)
            for ny in range(cy - 1, cy + 2):
                if ny < 0 or ny >= h:
                    continue
                for nx in range(cx - 1, cx + 2):
                    if nx < 0 or nx >= w:
                        continue
                    nxt = ny * w + nx
                    if not seen[nxt] and mask[nxt]:
                        seen[nxt] = 1
                        stack.append(nxt)
        if len(comp) > len(best):
            best = comp
    out = bytearray(w * h)
    for index in best:
        out[index] = 1
    return out


def _row_stats(mask: bytearray, w: int, h: int) -> tuple[list[int], list[list[int]]]:
    """Span and solid runs per row. A one or two pixel hole is closed."""
    spans = [0] * h
    runs: list[list[int]] = [[] for _ in range(h)]
    for y in range(h):
        row = bytearray(mask[y * w:(y + 1) * w])
        index = 0
        while index < w:
            if row[index]:
                index += 1
                continue
            end = index
            while end < w and not row[end]:
                end += 1
            if index > 0 and end < w and end - index <= 2:
                for fill in range(index, end):
                    row[fill] = 1
            index = end
        first = -1
        last = -1
        run = 0
        widths: list[int] = []
        for x in range(w):
            if row[x]:
                if first < 0:
                    first = x
                last = x
                run += 1
            elif run:
                widths.append(run)
                run = 0
        if run:
            widths.append(run)
        if first >= 0:
            spans[y] = last - first + 1
        runs[y] = widths
    return spans, runs


def _head_width(spans: list[int], top: int, height: int) -> tuple[int, int, bool]:
    """Widest row above the neck. A shoulder that widens in steps must not count as the head."""
    seen = 0
    neck_y = None
    neck_w = 10**9
    shrinking = False
    limit = min(len(spans), top + int(height * 0.45))
    ready = top + max(3, int(height * 0.05))
    for y in range(top, limit):
        width = spans[y]
        if not shrinking:
            if width >= seen:
                seen = width
                continue
            if seen >= 8 and y >= ready and width <= seen * 0.85:
                shrinking = True
                neck_y = y
                neck_w = width
            continue
        if 0 < width < neck_w:
            neck_w = width
            neck_y = y
        if width > seen and width > neck_w * 1.5:
            break
    if neck_y is None:
        band = [spans[y] for y in range(top, min(limit, top + int(height * 0.28)))]
        return (max(band) if band else 0), top + int(height * 0.28), False
    band = [spans[y] for y in range(top, neck_y)]
    return (max(band) if band else 0), neck_y, True


def _widest(row: list[int]) -> int:
    return max(row) if row else 0


def _chest_width(spans: list[int], runs: list[list[int]], top: int, bottom: int, head_end: int) -> int:
    """Torso width just under the outstretched arms. The arm span is not the chest."""
    height = bottom - top + 1
    arm_lo = head_end
    arm_hi = min(bottom, top + int(height * 0.75))
    if arm_hi <= arm_lo:
        arm_lo = top
    arm_y = max(range(arm_lo, arm_hi), key=lambda y: _widest(runs[y]))
    arm = _widest(runs[arm_y])
    under = arm_y
    floor = min(bottom, top + int(height * 0.62))
    while under < floor and arm and _widest(runs[under]) > arm * 0.42:
        under += 1
    if arm and _widest(runs[min(under, bottom)]) > arm * 0.42:
        under = min(bottom, top + int(height * 0.40))
    end = min(bottom + 1, under + max(3, int(height * 0.08)))
    widths = [max(runs[y]) for y in range(under, end) if runs[y]]
    return _median(widths) if widths else 0


def _ear_lobes(spans: list[int], top: int, neck_y: int) -> bool:
    """True when the lower head widens again. A smooth oval has one width peak."""
    span = neck_y - top
    if span < 16:
        return False
    cut = top + int(span * 0.55)
    upper = [spans[y] for y in range(top, cut) if spans[y] > 0]
    lower = [spans[y] for y in range(cut, neck_y) if spans[y] > 0]
    if not upper or not lower:
        return False
    skull = max(upper)
    if skull < 8:
        return False
    bulge = max(3, int(skull * 0.025))
    if max(lower) >= skull + bulge:
        return True
    valley = skull
    rebound = 0
    for width in lower:
        if width < valley:
            valley = width
        rebound = max(rebound, width - valley)
    tuck = skull - valley
    return tuck >= max(2, int(skull * 0.012)) and rebound >= bulge


def clip_ear_lobes(im: Image.Image) -> tuple[Image.Image, int]:
    """Cut lower-head lobes back to the skull curve. A smooth head is unchanged."""
    rgba = im.convert("RGBA")
    mask, w, h = _mask(rgba)
    spans, _runs = _row_stats(mask, w, h)
    occupied = [y for y in range(h) if spans[y]]
    if len(occupied) < 16:
        return rgba, 0
    top = occupied[0]
    _head, neck_y, _flared = _head_width(spans, top, occupied[-1] - top + 1)
    if not _ear_lobes(spans, top, neck_y):
        return rgba, 0
    cut = top + int((neck_y - top) * 0.55)
    upper = [y for y in range(top, cut) if spans[y] > 0]
    if not upper:
        return rgba, 0
    skull = max(spans[y] for y in upper)
    skull_y = max(y for y in upper if spans[y] == skull)

    def edges(y: int) -> tuple[int, int]:
        row = y * w
        xs = [x for x in range(w) if mask[row + x]]
        return xs[0], xs[-1]

    allow_left, allow_right = edges(skull_y)
    pix = rgba.load()
    background = pix[0, 0]
    changed = 0
    for y in range(skull_y + 1, neck_y):
        row = y * w
        xs = [x for x in range(w) if mask[row + x]]
        if not xs:
            continue
        left, right = xs[0], xs[-1]
        if left > allow_left:
            allow_left = left
        if right < allow_right:
            allow_right = right
        for x in xs:
            if x < allow_left or x > allow_right:
                pix[x, y] = background
                mask[row + x] = 0
                changed += 1
    return rgba, changed


def _torso_band(runs: list[list[int]], neck_y: int, top: int, height: int) -> int:
    """Chest depth when the arms are not outstretched in this view."""
    y1 = top + int(height * 0.48)
    if y1 <= neck_y:
        y1 = neck_y + max(3, int(height * 0.08))
    widths = [_widest(runs[y]) for y in range(neck_y, min(y1, len(runs))) if runs[y]]
    if not widths:
        return 0
    peak = max(widths)
    solid = [width for width in widths if width >= peak * 0.6]
    return _median(solid or widths)


def _limb(runs: list[list[int]], top: int, height: int, start: float, stop: float) -> tuple[int, bool]:
    """Median width of the thicker leg in a height band, and whether the legs are two masses."""
    widths: list[int] = []
    split = 0
    y0 = top + int(height * start)
    y1 = max(y0 + 1, top + int(height * stop))
    for y in range(y0, min(y1, len(runs))):
        row = sorted(runs[y], reverse=True)
        if not row:
            continue
        if len(row) >= 2 and row[1] >= row[0] * 0.45:
            split += 1
        widths.append(row[0])
    if not widths:
        return 0, False
    return _median(widths), split * 2 >= len(widths)


def _empty(reason: str) -> dict:
    return {
        "ok": False,
        "view": "front",
        "head_ratio": 0.0,
        "thigh_ratio": 0.0,
        "calf_ratio": 0.0,
        "head_px": 0,
        "chest_px": 0,
        "thigh_px": 0,
        "calf_px": 0,
        "failed": ["head_wide", "thigh_thick", "calf_thick"],
        "reason": reason,
    }


def _judge(view: str, head: float, thigh: float, calf: float) -> list[str]:
    band = FRONT if view == "front" else SIDE
    failed: list[str] = []
    if head > band["head_max"]:
        failed.append("head_wide")
    elif head < band["head_min"]:
        failed.append("head_narrow")
    if thigh > band["thigh_max"]:
        failed.append("thigh_thick")
    if calf > band["calf_max"]:
        failed.append("calf_thick")
    return failed


def _pack(view: str, head_px: int, chest_px: int, thigh_px: int, calf_px: int) -> dict:
    if chest_px < 4 or head_px < 4:
        return _empty("no ribcage to measure")
    head = round(head_px / chest_px, 3)
    thigh = round(thigh_px / chest_px, 3)
    calf = round(calf_px / chest_px, 3)
    failed = _judge(view, head, thigh, calf)
    reason = f"{view} head {head:.2f} thigh {thigh:.2f} calf {calf:.2f}"
    if failed:
        reason += " fail " + ",".join(failed)
    return {
        "ok": not failed,
        "view": view,
        "head_ratio": head,
        "thigh_ratio": thigh,
        "calf_ratio": calf,
        "head_px": head_px,
        "chest_px": chest_px,
        "thigh_px": thigh_px,
        "calf_px": calf_px,
        "failed": failed,
        "reason": reason,
    }


def measure_mask(mask: bytearray, w: int, h: int, *, view: str | None = None) -> dict:
    """Ratios for one silhouette. view forces the band. None detects front from two leg masses."""
    spans, runs = _row_stats(mask, w, h)
    occupied = [y for y in range(h) if spans[y]]
    if len(occupied) < 16:
        return _empty("no silhouette")
    top, bottom = occupied[0], occupied[-1]
    height = bottom - top + 1
    head_px, head_end, flared = _head_width(spans, top, height)
    arm_hi = min(bottom, top + int(height * 0.55))
    arm = 0
    if arm_hi > head_end:
        arm = max(_widest(runs[y]) for y in range(head_end, arm_hi))
    if flared and arm > head_px * 1.4:
        chest_px = _chest_width(spans, runs, top, bottom, head_end)
    else:
        chest_px = _torso_band(runs, head_end, top, height)
    thigh_px, split = _limb(runs, top, height, 0.62, 0.70)
    calf_px, _calf_split = _limb(runs, top, height, 0.80, 0.88)
    kind = view if view in ("front", "side") else ("front" if split else "side")
    packed = _pack(kind, head_px, chest_px, thigh_px, calf_px)
    if kind == "front" and _ear_lobes(spans, top, head_end):
        failed = list(packed["failed"])
        if "no_ears" not in failed:
            failed.append("no_ears")
        packed["failed"] = failed
        packed["ok"] = False
        reason = str(packed["reason"])
        packed["reason"] = reason + (",no_ears" if " fail " in reason else " fail no_ears")
    return packed


def measure_image(path: Path, *, view: str | None = None) -> dict:
    """Measure a T-pose still. A missing file is an error. A blank plate fails closed."""
    if not path.is_file():
        raise ValueError(f"no image {path}")
    with Image.open(path) as im:
        mask, w, h = _mask(im)
    return measure_mask(mask, w, h, view=view)


def mismatches(left: dict, right: dict) -> bool:
    """True when two views of the same class drifted. Front is not compared to a side."""
    if left.get("view") != right.get("view"):
        return False
    if abs(float(left.get("head_ratio", 0)) - float(right.get("head_ratio", 0))) > HEAD_DELTA:
        return True
    if abs(float(left.get("thigh_ratio", 0)) - float(right.get("thigh_ratio", 0))) > THIGH_DELTA:
        return True
    return abs(float(left.get("calf_ratio", 0)) - float(right.get("calf_ratio", 0))) > CALF_DELTA


def with_reference(root: Path, measure: dict) -> dict:
    """Fail a passing still that drifts from the first passing still of that class."""
    path = root / "data" / "pipeline" / "wip" / "gen" / REF_NAME
    blob: dict = {}
    if path.is_file():
        blob = json.loads(path.read_text(encoding="utf-8"))
    kind = str(measure.get("view") or "front")
    ref = blob.get(kind)
    failed = list(measure.get("failed") or [])
    if measure.get("ok") and isinstance(ref, dict) and ref.get("ok") and mismatches(measure, ref):
        failed.append("proportion_mismatch")
    elif measure.get("ok") and not (isinstance(ref, dict) and ref.get("ok")):
        blob[kind] = {key: measure[key] for key in ("ok", "view", "head_ratio", "thigh_ratio", "calf_ratio")}
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(blob, indent=2) + "\n", encoding="utf-8")
    out = dict(measure)
    out["failed"] = failed
    out["ok"] = not failed
    if failed and "proportion_mismatch" in failed:
        out["reason"] = str(measure.get("reason") or kind) + " fail " + ",".join(failed)
    return out


def merge_review(doc: dict, measure: dict) -> dict:
    """Add measurement fails to a vision review. An empty fail list leaves the vision verdict."""
    failed = [str(item) for item in doc.get("failed") or []]
    checks = list(doc.get("checks") or [])
    for cid in measure.get("failed") or []:
        if cid not in failed:
            failed.append(cid)
        checks.append({"id": cid, "pass": False, "reason": measure.get("reason", "")})
    out = dict(doc)
    out["failed"] = failed
    out["checks"] = checks
    out["verdict"] = "fail" if failed else out.get("verdict", "pass")
    out["proportion"] = {key: measure[key] for key in _FIELDS if key in measure}
    return out


def _raster(points: list[tuple[float, float, float]], faces: list[tuple[int, int, int]], horizontal: int, size: int = 180) -> bytearray:
    """Fill the mesh silhouette. horizontal 0 is X (front). horizontal 2 is Z (side)."""
    if not points:
        return bytearray(size * size)
    xs = [point[horizontal] for point in points]
    ys = [point[1] for point in points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    span = max(max_x - min_x, max_y - min_y, 1e-6)
    pad = 8
    scale = (size - 2 * pad) / span

    def project(index: int) -> tuple[float, float]:
        point = points[index]
        px = pad + (point[horizontal] - min_x) * scale
        py = pad + (max_y - point[1]) * scale
        return px, py

    mask = bytearray(size * size)

    def edge(a: tuple[float, float], b: tuple[float, float], y: float, hits: list[float]) -> None:
        y0, y1 = a[1], b[1]
        if y0 == y1 or y < min(y0, y1) or y > max(y0, y1):
            return
        hits.append(a[0] + (y - y0) / (y1 - y0) * (b[0] - a[0]))

    for tri in faces:
        proj = [project(tri[0]), project(tri[1]), project(tri[2])]
        y0 = max(0, int(min(p[1] for p in proj)))
        y1 = min(size - 1, int(max(p[1] for p in proj)))
        for y in range(y0, y1 + 1):
            hits: list[float] = []
            edge(proj[0], proj[1], y + 0.5, hits)
            edge(proj[1], proj[2], y + 0.5, hits)
            edge(proj[2], proj[0], y + 0.5, hits)
            if len(hits) < 2:
                continue
            x0 = max(0, int(min(hits)))
            x1 = min(size - 1, int(max(hits)))
            row = y * size
            for x in range(x0, x1 + 1):
                mask[row + x] = 1
    return mask


def check_glb(path: Path) -> dict:
    """Front and side projections of a GLB. Both must pass. A fragment is the mesh check's job."""
    points, faces = mesh_check.load_primitive(path)
    if not faces:
        empty = _empty("mesh has no triangles")
        return {"ok": False, "reason": empty["reason"], "failed": empty["failed"], "front": empty, "side": empty}
    front = measure_mask(_raster(points, faces, 0), 180, 180, view="front")
    side = measure_mask(_raster(points, faces, 2), 180, 180, view="side")
    failed = [f"front {cid}" for cid in front["failed"]] + [f"side {cid}" for cid in side["failed"]]
    reason = f"front {front['reason']}; side {side['reason']}"
    return {"ok": not failed, "reason": reason, "failed": failed, "front": front, "side": side}


def _stamp(mask: bytearray, w: int, x0: int, x1: int, y0: int, y1: int) -> None:
    for y in range(y0, y1):
        row = y * w
        for x in range(x0, x1):
            mask[row + x] = 1


def _figure(w: int, h: int, *, head: int, chest: int, thigh: int, calf: int, side: bool) -> bytearray:
    """A flat T-pose silhouette. side keeps one leg mass and still reaches both ways with the arms."""
    mask = bytearray(w * h)
    cx = w // 2
    gap = 10
    _stamp(mask, w, cx - head // 2, cx + head // 2, 16, 74)
    _stamp(mask, w, cx - 8, cx + 8, 66, 96)
    _stamp(mask, w, 8, w - 8, 84, 100)
    _stamp(mask, w, cx - chest // 2, cx + chest // 2, 92, 158)
    if side:
        _stamp(mask, w, cx - max(chest, thigh) // 2, cx + max(chest, thigh) // 2, 150, 176)
        _stamp(mask, w, cx - thigh // 2, cx + thigh // 2, 168, 236)
        _stamp(mask, w, cx - calf // 2, cx + calf // 2, 228, 286)
        _stamp(mask, w, cx - 12, cx + 12, 278, 300)
    else:
        _stamp(mask, w, cx - gap - thigh, cx + gap + thigh, 150, 176)
        _stamp(mask, w, cx - gap - thigh, cx - gap, 168, 236)
        _stamp(mask, w, cx + gap, cx + gap + thigh, 168, 236)
        _stamp(mask, w, cx - gap - calf, cx - gap, 228, 286)
        _stamp(mask, w, cx + gap, cx + gap + calf, 228, 286)
        _stamp(mask, w, cx - gap - 12, cx - gap, 278, 300)
        _stamp(mask, w, cx + gap, cx + gap + 12, 278, 300)
    return mask


def _box(origin: int, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float):
    verts = [
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
    ]
    quads = ((0, 1, 2, 3), (4, 6, 5, 7), (0, 4, 5, 1), (3, 2, 6, 7), (0, 3, 7, 4), (1, 5, 6, 2))
    faces = []
    for a, b, c, d in quads:
        faces.append((origin + a, origin + b, origin + c))
        faces.append((origin + a, origin + c, origin + d))
    return [(x, y, z) for x, y, z in verts], faces


def _write_glb(path: Path, points: list[tuple[float, float, float]], faces: list[tuple[int, int, int]]) -> None:
    pos = b"".join(struct.pack("<fff", *point) for point in points)
    indices = [index for tri in faces for index in tri]
    idx = b"".join(struct.pack("<I", index) for index in indices)
    blob = pos + idx
    doc = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pos)},
            {"buffer": 0, "byteOffset": len(pos), "byteLength": len(idx)},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(points), "type": "VEC3"},
            {"bufferView": 1, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
        ],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
    }
    raw = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    raw += b" " * ((4 - len(raw) % 4) % 4)
    chunks = b"".join((
        struct.pack("<I4s", len(raw), b"JSON"),
        raw,
        struct.pack("<I4s", len(blob), b"BIN\x00"),
        blob,
    ))
    path.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(chunks)) + chunks)


def _mannequin_glb(path: Path, *, head_half: float) -> None:
    """Boxes in a T-pose. head_half is half the head width on X."""
    parts = [
        _box(0, -head_half, head_half, 1.55, 1.95, -0.18, 0.18),
        _box(8, -0.18, 0.18, 1.05, 1.48, -0.14, 0.14),
        _box(16, -1.0, 1.0, 1.40, 1.52, -0.04, 0.04),
        _box(24, -0.24, -0.12, 0.45, 1.02, -0.08, 0.08),
        _box(32, 0.12, 0.24, 0.45, 1.02, -0.08, 0.08),
        _box(40, -0.20, -0.12, 0.05, 0.42, -0.06, 0.06),
        _box(48, 0.12, 0.20, 0.05, 0.42, -0.06, 0.06),
    ]
    points: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int]] = []
    for verts, tris in parts:
        points.extend(verts)
        faces.extend(tris)
    _write_glb(path, points, faces)


def selftest() -> list[str]:
    """A slim T-pose passes. A giant head, a thick thigh, and a thick calf fail. The glb gate uses the same bands."""
    bad: list[str] = []
    slim = measure_mask(_figure(220, 320, head=40, chest=36, thigh=14, calf=10, side=False), 220, 320)
    if not slim["ok"] or slim["view"] != "front":
        bad.append(f"a slim front failed ({slim['reason']})")
    if "no_ears" in slim["failed"]:
        bad.append(f"a smooth head was called ears ({slim['reason']})")
    eared = bytearray(_figure(220, 320, head=40, chest=36, thigh=14, calf=10, side=False))
    cx = 110
    for y in range(50, 64):
        row = y * 220
        for x in range(cx - 26, cx - 16):
            eared[row + x] = 1
        for x in range(cx + 16, cx + 26):
            eared[row + x] = 1
    heard = measure_mask(eared, 220, 320)
    if "no_ears" not in heard["failed"]:
        bad.append(f"ear lobes passed ({heard['reason']})")
    plate = Image.new("RGB", (220, 320), (199, 30, 191))
    paint = plate.load()
    for index, on in enumerate(eared):
        if on:
            paint[index % 220, index // 220] = (235, 200, 180)
    clipped, removed = clip_ear_lobes(plate)
    if removed < 8:
        bad.append("ear lobes were not clipped")
    with tempfile.TemporaryDirectory() as tmp:
        clipped_path = Path(tmp) / "clipped.png"
        clipped.convert("RGB").save(clipped_path)
        fixed = measure_image(clipped_path, view="front")
        if "no_ears" in fixed["failed"] or not fixed["ok"]:
            bad.append(f"a clipped head still failed ({fixed['reason']})")
    smooth_plate = Image.new("RGB", (220, 320), (199, 30, 191))
    smooth_paint = smooth_plate.load()
    smooth_mask = _figure(220, 320, head=40, chest=36, thigh=14, calf=10, side=False)
    for index, on in enumerate(smooth_mask):
        if on:
            smooth_paint[index % 220, index // 220] = (235, 200, 180)
    _unchanged, smooth_removed = clip_ear_lobes(smooth_plate)
    if smooth_removed:
        bad.append("a smooth head was clipped")
    giant = measure_mask(_figure(220, 320, head=90, chest=36, thigh=14, calf=10, side=False), 220, 320)
    if giant["ok"] or "head_wide" not in giant["failed"]:
        bad.append(f"a giant head passed ({giant['reason']})")
    meaty = measure_mask(_figure(220, 320, head=40, chest=36, thigh=22, calf=10, side=False), 220, 320)
    if "thigh_thick" not in meaty["failed"]:
        bad.append(f"a thick thigh passed ({meaty['reason']})")
    thick_calf = measure_mask(_figure(220, 320, head=40, chest=36, thigh=14, calf=16, side=False), 220, 320)
    if "calf_thick" not in thick_calf["failed"]:
        bad.append(f"a thick calf passed ({thick_calf['reason']})")
    side = measure_mask(_figure(220, 320, head=40, chest=32, thigh=24, calf=18, side=True), 220, 320, view="side")
    if not side["ok"] or side["view"] != "side":
        bad.append(f"a slim side failed ({side['reason']})")
    if "no_ears" in side["failed"]:
        bad.append("a side view was failed for front ears")
    wide_side = measure_mask(_figure(220, 320, head=70, chest=32, thigh=24, calf=18, side=True), 220, 320, view="side")
    if "head_wide" not in wide_side["failed"]:
        bad.append(f"a wide side head passed ({wide_side['reason']})")
    drifted = dict(slim)
    drifted["head_ratio"] = round(slim["head_ratio"] + HEAD_DELTA + 0.02, 3)
    if not mismatches(slim, drifted):
        bad.append("a drifted head matched its pair")
    if mismatches(slim, side):
        bad.append("a front was compared to a side")
    merged = merge_review({"verdict": "pass", "failed": [], "checks": []}, giant)
    if merged["verdict"] != "fail" or "head_wide" not in merged["failed"]:
        bad.append("a vision pass hid a giant head")
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        first = with_reference(root, slim)
        if not first["ok"]:
            bad.append("the first passing still was rejected")
        second = with_reference(root, drifted)
        if "proportion_mismatch" not in second["failed"]:
            bad.append("a later still was allowed to drift")
        plate = root / "plate.png"
        paint = Image.new("RGB", (220, 320), (199, 30, 191))
        pix = paint.load()
        mask = _figure(220, 320, head=40, chest=36, thigh=14, calf=10, side=False)
        for y in range(320):
            for x in range(220):
                if mask[y * 220 + x]:
                    pix[x, y] = (235, 200, 180)
        paint.save(plate)
        loaded = measure_image(plate, view="front")
        if not loaded["ok"]:
            bad.append(f"a magenta plate failed ({loaded['reason']})")
        soft = Image.new("RGBA", (220, 320), (255, 0, 255, 160))
        soft_pix = soft.load()
        for y in range(320):
            for x in range(220):
                if mask[y * 220 + x]:
                    soft_pix[x, y] = (235, 200, 180, 255)
        soft_path = root / "soft.png"
        soft.save(soft_path)
        soft_measured = measure_image(soft_path, view="front")
        if not soft_measured["ok"]:
            bad.append(f"a soft magenta margin failed ({soft_measured['reason']})")
        glb = root / "body.glb"
        _mannequin_glb(glb, head_half=0.20)
        sized = check_glb(glb)
        if not sized["ok"]:
            bad.append(f"a slim glb failed ({sized['reason']})")
        _mannequin_glb(glb, head_half=0.42)
        huge = check_glb(glb)
        if huge["ok"] or not any("head_wide" in item for item in huge["failed"]):
            bad.append(f"a giant-head glb passed ({huge['reason']})")
    return bad
