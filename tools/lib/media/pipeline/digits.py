"""Add a thumb, fingers, and a toe shape to a T-pose body mesh.

glTF Y is up. The wide horizontal axis is the arms. The chest side that
sticks out is the front. Counts come from the subject. Lengths come from
the hand and the foot that were found. A mesh that is not a T-pose fails.
This does not rebuild the body and does not assume a female body.
"""
from __future__ import annotations

import json
import math
import struct
from pathlib import Path

Vec = tuple[float, float, float]
Tri = tuple[int, int, int]


def require_spec(spec: object) -> dict:
    """Fingers, a thumb flag, and toe lobes. A missing field is an error."""
    if not isinstance(spec, dict):
        raise ValueError("digits spec must be an object")
    fingers = spec.get("fingers")
    thumb = spec.get("thumb")
    toes = spec.get("toes")
    if not isinstance(fingers, int) or not 1 <= fingers <= 4:
        raise ValueError("digits.fingers must be an integer from 1 to 4")
    if not isinstance(thumb, bool):
        raise ValueError("digits.thumb must be true or false")
    if not isinstance(toes, int) or not 1 <= toes <= 3:
        raise ValueError("digits.toes must be an integer from 1 to 3")
    return {"fingers": fingers, "thumb": thumb, "toes": toes}


def _add(a: Vec, b: Vec) -> Vec:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def _mul(a: Vec, scale: float) -> Vec:
    return (a[0] * scale, a[1] * scale, a[2] * scale)


def _sub(a: Vec, b: Vec) -> Vec:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a: Vec, b: Vec) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a: Vec, b: Vec) -> Vec:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def _norm(a: Vec) -> Vec:
    length = math.sqrt(_dot(a, a))
    if length < 1e-8:
        raise ValueError("digit axis is zero")
    return (a[0] / length, a[1] / length, a[2] / length)


def _axis(index: int) -> Vec:
    return tuple(1.0 if i == index else 0.0 for i in range(3))  # type: ignore[return-value]


def _span(points: list[Vec], axis: int) -> tuple[float, float]:
    vals = [point[axis] for point in points]
    return min(vals), max(vals)


def _frame(points: list[Vec]) -> dict:
    if len(points) < 40:
        raise ValueError("too few vertices")
    spans = []
    for axis in range(3):
        lo, hi = _span(points, axis)
        spans.append((hi - lo, axis, lo, hi))
    height = spans[1][0]
    if height < 0.5:
        raise ValueError("height span is short")
    lateral, depth = sorted((spans[0], spans[2]), reverse=True)
    if lateral[0] < depth[0] * 1.4:
        raise ValueError("not a T-pose")
    y0, y1 = spans[1][2], spans[1][3]
    center = (lateral[2] + lateral[3]) / 2
    torso = [
        point for point in points
        if y0 + 0.45 * height < point[1] < y0 + 0.72 * height
        and abs(point[lateral[1]] - center) < lateral[0] * 0.18
    ]
    if len(torso) < 8:
        raise ValueError("no torso to find the front")
    depths = sorted(point[depth[1]] for point in torso)
    median = depths[len(depths) // 2]
    front = 1 if (depths[-1] - median) >= (median - depths[0]) else -1
    return {
        "lat": lateral[1],
        "dep": depth[1],
        "lat_lo": lateral[2],
        "lat_hi": lateral[3],
        "y0": y0,
        "y1": y1,
        "height": height,
        "center": center,
        "front": front,
    }


def _hand_frame(points: list[Vec], info: dict, sign: int) -> dict:
    lat = info["lat"]
    dep = info["dep"]
    half = max(info["lat_hi"] - info["center"], info["center"] - info["lat_lo"])
    pool = [
        point for point in points
        if (point[lat] - info["center"]) * sign > 0.48 * half
        and point[1] > info["y0"] + 0.55 * info["height"]
    ]
    if len(pool) < 8:
        raise ValueError("no hand on the " + ("right" if sign > 0 else "left"))
    outward = [(point[lat] - info["center"]) * sign for point in pool]
    inner, outer = min(outward), max(outward)
    bins = 14
    width = (outer - inner) / bins or 1.0
    depth_span = []
    for index in range(bins):
        sel = [
            point for point, dist in zip(pool, outward)
            if index * width <= dist - inner < (index + 1) * width or (index == bins - 1 and dist == outer)
        ]
        if len(sel) < 4:
            depth_span.append(0.0)
            continue
        lo, hi = _span(sel, dep)
        depth_span.append(hi - lo)
    forearm = sorted(depth_span[:5])[2] if any(depth_span[:5]) else 0.0
    start = next((i for i, span in enumerate(depth_span) if span > max(forearm * 1.45, 1e-4)), bins // 2)
    cut_dist = inner + (start + (bins - start) * 0.35) * width
    tip_dist = outer
    palm = [point for point, dist in zip(pool, outward) if dist >= inner + start * width]
    if len(palm) < 4:
        palm = pool
    up_lo, up_hi = _span(palm, 1)
    dep_lo, dep_hi = _span(palm, dep)
    return {
        "sign": sign,
        "cut": info["center"] + sign * cut_dist,
        "tip": info["center"] + sign * tip_dist,
        "up_lo": up_lo,
        "up_hi": up_hi,
        "dep_lo": dep_lo,
        "dep_hi": dep_hi,
        "side": "right" if sign > 0 else "left",
    }


def _inside(coord: float, limit: float, sign: int) -> bool:
    return (coord - limit) * sign <= 1e-7


def _hit(a: Vec, b: Vec, axis: int, limit: float) -> Vec:
    span = b[axis] - a[axis]
    t = 0.0 if abs(span) < 1e-9 else (limit - a[axis]) / span
    t = max(0.0, min(1.0, t))
    return (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )


def _clip_poly(poly: list[Vec], axis: int, limit: float, sign: int) -> list[Vec]:
    if not poly:
        return []
    output: list[Vec] = []
    for index, current in enumerate(poly):
        nxt = poly[(index + 1) % len(poly)]
        cin = _inside(current[axis], limit, sign)
        nin = _inside(nxt[axis], limit, sign)
        if cin:
            output.append(current)
        if cin != nin:
            output.append(_hit(current, nxt, axis, limit))
    return output


def _clip(points: list[Vec], faces: list[Tri], axis: int, sign: int, limit: float) -> tuple[list[Vec], list[Tri], list[Vec]]:
    kept: list[Vec] = []
    tris: list[Tri] = []
    boundary: list[Vec] = []
    index_of: dict[tuple[int, int, int], int] = {}

    def vid(point: Vec) -> int:
        key = (round(point[0], 6), round(point[1], 6), round(point[2], 6))
        found = index_of.get(key)
        if found is None:
            found = len(kept)
            kept.append(point)
            index_of[key] = found
        return found

    for tri in faces:
        poly = _clip_poly([points[tri[0]], points[tri[1]], points[tri[2]]], axis, limit, sign)
        if len(poly) < 3:
            continue
        ids = [vid(point) for point in poly]
        for offset in range(1, len(poly) - 1):
            tris.append((ids[0], ids[offset], ids[offset + 1]))
        if len(poly) >= 2 and any(abs(point[axis] - limit) < 1e-4 for point in poly):
            boundary.extend(point for point in poly if abs(point[axis] - limit) < 1e-4)
    return kept, tris, boundary


def _cap(points: list[Vec], faces: list[Tri], boundary: list[Vec], dep: int) -> tuple[list[Vec], list[Tri]]:
    unique: list[Vec] = []
    seen: set[tuple[int, int, int]] = set()
    for point in boundary:
        key = (round(point[0], 5), round(point[1], 5), round(point[2], 5))
        if key not in seen:
            seen.add(key)
            unique.append(point)
    if len(unique) < 3:
        return points, faces
    centroid = (
        sum(point[0] for point in unique) / len(unique),
        sum(point[1] for point in unique) / len(unique),
        sum(point[2] for point in unique) / len(unique),
    )
    ordered = sorted(unique, key=lambda point: math.atan2(point[1] - centroid[1], point[dep] - centroid[dep]))
    start = len(points)
    points = points + ordered
    for index in range(1, len(ordered) - 1):
        faces.append((start, start + index, start + index + 1))
    return points, faces


def _prism(
    base: Vec, axis: Vec, up: Vec, side: Vec, length: float, rad_up: float, rad_side: float, *, tip: float = 0.62,
) -> tuple[list[Vec], list[Tri]]:
    sides = 6
    ring: list[Vec] = []
    for end, scale in ((0.0, 1.0), (length, tip)):
        center = _add(base, _mul(axis, end))
        for index in range(sides):
            angle = math.tau * index / sides
            offset = _add(_mul(up, math.sin(angle) * rad_up * scale), _mul(side, math.cos(angle) * rad_side * scale))
            ring.append(_add(center, offset))
    tris: list[Tri] = []
    for index in range(sides):
        nxt = (index + 1) % sides
        tris.append((index, nxt, sides + nxt))
        tris.append((index, sides + nxt, sides + index))
    for index in range(1, sides - 1):
        tris.append((0, index + 1, index))
        tris.append((sides, sides + index, sides + index + 1))
    return ring, tris


def _append(points: list[Vec], faces: list[Tri], extra: list[Vec], tris: list[Tri]) -> tuple[list[Vec], list[Tri]]:
    start = len(points)
    points = points + extra
    faces = faces + [(start + tri[0], start + tri[1], start + tri[2]) for tri in tris]
    return points, faces


def _basis(axis: Vec) -> tuple[Vec, Vec]:
    helper = (0.0, 1.0, 0.0) if abs(axis[1]) < 0.85 else (1.0, 0.0, 0.0)
    side = _norm(_cross(axis, helper))
    up = _norm(_cross(side, axis))
    return up, side


def _fingers(points: list[Vec], faces: list[Tri], info: dict, hand: dict, spec: dict) -> tuple[list[Vec], list[Tri], dict]:
    lat = _axis(info["lat"])
    outward = _mul(lat, float(hand["sign"]))
    depth_span = max(hand["dep_hi"] - hand["dep_lo"], 1e-4)
    up_span = max(hand["up_hi"] - hand["up_lo"], 1e-4)
    reach = abs(hand["tip"] - hand["cut"])
    length = max(reach * 1.15, depth_span * 0.62)
    count = spec["fingers"]
    gap_ratio = 0.28
    slot = depth_span * 0.88 / (count + (count - 1) * gap_ratio)
    gap = slot * gap_ratio
    rad_side = slot * 0.46
    rad_up = min(max(up_span * 0.38, depth_span * 0.08), rad_side * 1.2)
    origin_dep = hand["dep_lo"] + depth_span * 0.06 + rad_side
    placed = []
    for index in range(count):
        center_dep = origin_dep + index * (slot + gap)
        base = [0.0, 0.0, 0.0]
        base[info["lat"]] = hand["cut"] - hand["sign"] * length * 0.34
        base[1] = (hand["up_lo"] + hand["up_hi"]) / 2
        base[info["dep"]] = center_dep
        extra, tris = _prism(tuple(base), outward, (0.0, 1.0, 0.0), _axis(info["dep"]), length, rad_up, rad_side)
        points, faces = _append(points, faces, extra, tris)
        placed.append(round(center_dep, 4))
    thumb = None
    if spec["thumb"]:
        thumb_len = length * 0.72
        direction = _norm(_add(_add(_mul(outward, 0.72), _mul(_axis(info["dep"]), 0.62 * info["front"])), (0.0, -0.38, 0.0)))
        up, side = _basis(direction)
        base = [0.0, 0.0, 0.0]
        base[info["lat"]] = hand["cut"]
        base[1] = (hand["up_lo"] + hand["up_hi"]) / 2 - rad_up * 0.2
        base[info["dep"]] = (hand["dep_lo"] + hand["dep_hi"]) / 2 + info["front"] * (depth_span * 0.46)
        extra, tris = _prism(tuple(base), direction, up, side, thumb_len, rad_up * 1.15, rad_side * 1.05)
        points, faces = _append(points, faces, extra, tris)
        thumb = True
    return points, faces, {
        "side": hand["side"],
        "fingers": placed,
        "thumb": thumb is not None,
        "length": round(length, 4),
    }


def _foot_frame(points: list[Vec], info: dict, sign: int) -> dict:
    lat = info["lat"]
    dep = info["dep"]
    half = max(info["lat_hi"] - info["center"], info["center"] - info["lat_lo"])
    pool = [
        point for point in points
        if point[1] < info["y0"] + 0.16 * info["height"]
        and (point[lat] - info["center"]) * sign > 0.04 * half
    ]
    if len(pool) < 8:
        raise ValueError("no foot on the " + ("right" if sign > 0 else "left"))
    sole_cut = info["y0"] + 0.055 * info["height"]
    pool = [point for point in pool if point[1] <= sole_cut]
    if len(pool) < 8:
        raise ValueError("no sole on the " + ("right" if sign > 0 else "left"))
    sole = min(point[1] for point in pool)
    dep_lo, dep_hi = _span(pool, dep)
    front_limit = dep_hi if info["front"] > 0 else dep_lo
    band = (dep_hi - dep_lo) * 0.18
    toe_end = [
        point for point in pool
        if (point[dep] - front_limit) * info["front"] > -band
    ]
    if len(toe_end) < 8:
        toe_end = pool
    lat_lo, lat_hi = _span(toe_end, lat)
    top = max(point[1] for point in pool)
    return {
        "sign": sign,
        "side": "right" if sign > 0 else "left",
        "sole": sole,
        "top": top,
        "front_at": front_limit,
        "lat_lo": lat_lo,
        "lat_hi": lat_hi,
        "dep_span": dep_hi - dep_lo,
    }


def _toes(points: list[Vec], faces: list[Tri], info: dict, foot: dict, spec: dict) -> tuple[list[Vec], list[Tri], dict]:
    count = spec["toes"]
    width = max(foot["lat_hi"] - foot["lat_lo"], 1e-4)
    length = max(width * 0.72, foot["dep_span"] * 0.16)
    rad_up = max(min((foot["top"] - foot["sole"]) * 0.45, length * 0.42), width * 0.12)
    gap_ratio = 0.35
    slot = width * 0.78 / (count + (count - 1) * gap_ratio)
    gap = slot * gap_ratio
    rad_side = slot * 0.42
    # Medial lobe first: toward the body center.
    medial = foot["lat_lo"] if foot["sign"] > 0 else foot["lat_hi"]
    step = (slot + gap) * (-1 if foot["sign"] < 0 else 1)
    start = medial + (rad_side if foot["sign"] > 0 else -rad_side)
    forward = _mul(_axis(info["dep"]), float(info["front"]))
    placed = []
    for index in range(count):
        lobe = length * (1.15 if index == 0 else 0.82)
        center_lat = start + step * index
        base = [0.0, foot["sole"] + rad_up, 0.0]
        base[info["lat"]] = center_lat
        base[info["dep"]] = foot["front_at"] - info["front"] * lobe * 0.48
        extra, tris = _prism(tuple(base), forward, (0.0, 1.0, 0.0), _axis(info["lat"]), lobe, rad_up, rad_side)
        points, faces = _append(points, faces, extra, tris)
        placed.append(round(center_lat, 4))
    return points, faces, {"side": foot["side"], "toes": placed, "length": round(length, 4)}


def apply(points: list[Vec], faces: list[Tri], spec: dict) -> tuple[list[Vec], list[Tri], dict]:
    """Clip each paddle and add the digits this subject asked for."""
    spec = require_spec(spec)
    if not faces:
        raise ValueError("mesh has no triangles")
    info = _frame(list(points))
    current_points = list(points)
    current_faces = list(faces)
    hands = []
    for sign in (1, -1):
        hand = _hand_frame(current_points, info, sign)
        current_points, current_faces, boundary = _clip(
            current_points, current_faces, info["lat"], sign, hand["cut"],
        )
        current_points, current_faces = _cap(current_points, current_faces, boundary, info["dep"])
        current_points, current_faces, row = _fingers(current_points, current_faces, info, hand, spec)
        hands.append(row)
    feet = []
    for sign in (1, -1):
        foot = _foot_frame(current_points, info, sign)
        current_points, current_faces, row = _toes(current_points, current_faces, info, foot, spec)
        feet.append(row)
    report = {
        "front": info["front"],
        "lateral": info["lat"],
        "hands": hands,
        "feet": feet,
        "verts": len(current_points),
        "faces": len(current_faces),
    }
    return current_points, current_faces, report


def write_glb(path: Path, points: list[Vec], faces: list[Tri]) -> None:
    """Write positions and triangles. The view material is replaced in Blender."""
    blob = b"".join(struct.pack("<fff", *point) for point in points)
    index_blob = b"".join(struct.pack("<III", *tri) for tri in faces)
    pad = (4 - (len(blob) % 4)) % 4
    doc = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(blob) + pad + len(index_blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(blob)},
            {"buffer": 0, "byteOffset": len(blob) + pad, "byteLength": len(index_blob)},
        ],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": len(points),
                "type": "VEC3",
            },
            {
                "bufferView": 1,
                "componentType": 5125,
                "count": len(faces) * 3,
                "type": "SCALAR",
            },
        ],
        "materials": [{
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.86, 0.62, 0.48, 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 0.6,
            },
        }],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1, "material": 0, "mode": 4}]}],
        "nodes": [{"mesh": 0}],
        "scenes": [{"nodes": [0]}],
        "scene": 0,
    }
    raw = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    raw += b" " * ((4 - len(raw) % 4) % 4)
    chunks = b"".join((
        struct.pack("<I4s", len(raw), b"JSON"),
        raw,
        struct.pack("<I4s", len(blob) + pad + len(index_blob), b"BIN\x00"),
        blob + (b"\x00" * pad) + index_blob,
    ))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(chunks)) + chunks)


def _box(lo: Vec, hi: Vec) -> tuple[list[Vec], list[Tri]]:
    corners = []
    for z in (lo[2], hi[2]):
        for y in (lo[1], hi[1]):
            for x in (lo[0], hi[0]):
                corners.append((x, y, z))
    quads = (
        (0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4),
        (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6),
    )
    tris: list[Tri] = []
    for a, b, c, d in quads:
        tris.append((a, b, c))
        tris.append((a, c, d))
    return corners, tris


def _join(parts: list[tuple[list[Vec], list[Tri]]]) -> tuple[list[Vec], list[Tri]]:
    points: list[Vec] = []
    faces: list[Tri] = []
    for extra, tris in parts:
        points, faces = _append(points, faces, extra, tris)
    return points, faces


def _figure() -> tuple[list[Vec], list[Tri]]:
    """A box T-pose with paddle hands and block feet. Not a character."""
    parts = [
        _box((-0.2, 0.45, -0.1), (0.2, 1.35, 0.16)),
        _box((-0.15, 0.9, -0.08), (0.15, 1.2, 0.22)),
        _box((-0.12, 1.4, -0.08), (0.12, 1.85, 0.08)),
        _box((0.2, 1.05, -0.04), (0.85, 1.16, 0.04)),
        _box((0.85, 1.0, -0.09), (1.12, 1.18, 0.09)),
        _box((-0.85, 1.05, -0.04), (-0.2, 1.16, 0.04)),
        _box((-1.12, 1.0, -0.09), (-0.85, 1.18, 0.09)),
        _box((0.06, 0.08, -0.04), (0.16, 0.45, 0.05)),
        _box((-0.16, 0.08, -0.04), (-0.06, 0.45, 0.05)),
        _box((0.04, 0.0, -0.05), (0.2, 0.09, 0.16)),
        _box((-0.2, 0.0, -0.05), (-0.04, 0.09, 0.16)),
    ]
    return _join(parts)


def _runs(values: list[float], gap: float) -> int:
    if not values:
        return 0
    ordered = sorted(values)
    runs = 1
    for left, right in zip(ordered, ordered[1:]):
        if right - left > gap:
            runs += 1
    return runs


def selftest() -> list[str]:
    """A paddle figure grows separated fingers. A cube is not a T-pose."""
    bad: list[str] = []
    try:
        require_spec({"fingers": 4})
        bad.append("a digits spec with no thumb was accepted")
    except ValueError:
        pass
    try:
        require_spec({"fingers": 4, "thumb": True, "toes": 0})
        bad.append("zero toes was accepted")
    except ValueError:
        pass
    points, faces = _figure()
    try:
        _frame([(0.0, 0.0, 0.0), (1.0, 0.2, 0.2), (0.2, 0.1, 1.0)] * 40)
        bad.append("a cube was treated as a T-pose")
    except ValueError:
        pass
    spec = {"fingers": 4, "thumb": True, "toes": 2}
    new_points, _new_faces, report = apply(points, faces, spec)
    if report["front"] != 1:
        bad.append("the chest bulge was not the front")
    if any(len(row["fingers"]) != 4 or not row["thumb"] for row in report["hands"]):
        bad.append("a hand did not grow four fingers and a thumb")
    if any(len(row["toes"]) != 2 for row in report["feet"]):
        bad.append("a foot did not grow two toe lobes")
    old_toe = max(point[2] for point in points if point[1] < 0.1 and point[0] > 0)
    new_toe = max(point[2] for point in new_points if point[1] < 0.2 and point[0] > 0)
    if new_toe <= old_toe:
        bad.append("the toe did not pass the old foot")
    tip = [point[2] for point in new_points if point[0] > 1.0 and 0.9 < point[1] < 1.3]
    if _runs(tip, 0.008) < 3:
        bad.append("the finger tips are still one paddle")
    return bad
