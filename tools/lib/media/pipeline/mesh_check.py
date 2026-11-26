"""Decide whether a mesh is one body.

Height in the glTF file is Y. Blender shows that axis as Z after import.
An internal empty band is a hole, the failure that left the head floating.
A mesh whose largest piece holds under 60 percent of the vertices is fragmented.
A pass means the mesh can go on. It is not a look approval.
"""
from __future__ import annotations

import json
import struct
from pathlib import Path

BANDS = 10
MIN_SPAN = 0.5
MIN_VERTS = 1000
MIN_SHARE = 0.6
FLOAT_VEC3 = 5126
UNSIGNED_BYTE = 5121
UNSIGNED_SHORT = 5123
UNSIGNED_INT = 5125


def height_report(points: list[tuple[float, float, float]], *, bands: int = BANDS) -> dict:
    """Band the Y axis. An empty band, a short span, or a shred fails."""
    if bands < 2:
        raise ValueError("bands must be at least 2")
    ys = [point[1] for point in points]
    if not ys:
        return {"verts": 0, "span": 0.0, "bands": [], "empty": [], "ok": False, "reason": "no vertices"}
    y0 = min(ys)
    y1 = max(ys)
    span = y1 - y0
    counts = [0] * bands
    if span > 0:
        for y in ys:
            index = min(bands - 1, int((y - y0) / span * bands))
            counts[index] += 1
    empty = [index for index, count in enumerate(counts) if count == 0]
    reason = ""
    if empty:
        reason = "empty height band"
    elif span < MIN_SPAN:
        reason = "height span is short"
    elif len(ys) < MIN_VERTS:
        reason = "too few vertices"
    return {
        "verts": len(ys),
        "span": round(span, 4),
        "y": [round(y0, 4), round(y1, 4)],
        "bands": counts,
        "empty": empty,
        "ok": reason == "",
        "reason": reason,
    }


def _chunks(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise ValueError(f"{path.name} is not a glb")
    chunk_len, chunk_type = struct.unpack_from("<I4s", data, 12)
    if chunk_type != b"JSON":
        raise ValueError(f"{path.name} has no JSON chunk")
    doc = json.loads(data[20:20 + chunk_len])
    blob_at = 20 + chunk_len
    if blob_at % 4:
        blob_at += 4 - (blob_at % 4)
    bin_len, bin_type = struct.unpack_from("<I4s", data, blob_at)
    if bin_type != b"BIN\x00":
        raise ValueError(f"{path.name} has no binary chunk")
    return doc, data[blob_at + 8:blob_at + 8 + bin_len]


def _accessor_bytes(doc: dict, blob: bytes, accessor_index: int) -> tuple[dict, int, int]:
    accessor = doc["accessors"][accessor_index]
    view = doc["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return accessor, start, view.get("byteStride", 0)


def load_positions(path: Path) -> list[tuple[float, float, float]]:
    """Read POSITION from the first mesh in a binary glTF file."""
    points, _faces = load_primitive(path)
    return points


def load_primitive(path: Path) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int]]]:
    """Read positions and triangles. A point cloud has an empty triangle list."""
    doc, blob = _chunks(path)
    try:
        primitive = doc["meshes"][0]["primitives"][0]
        accessor, start, stride = _accessor_bytes(doc, blob, primitive["attributes"]["POSITION"])
    except (KeyError, IndexError) as exc:
        raise ValueError(f"{path.name} has no position accessor") from exc
    if accessor.get("componentType") != FLOAT_VEC3 or accessor.get("type") != "VEC3":
        raise ValueError(f"{path.name} positions are not float vectors")
    stride = stride or 12
    points = [struct.unpack_from("<fff", blob, start + index * stride) for index in range(accessor["count"])]
    faces: list[tuple[int, int, int]] = []
    if "indices" in primitive:
        index_acc, index_at, _stride = _accessor_bytes(doc, blob, primitive["indices"])
        kind = index_acc.get("componentType")
        fmt = {UNSIGNED_BYTE: "<B", UNSIGNED_SHORT: "<H", UNSIGNED_INT: "<I"}.get(kind)
        if fmt is None or index_acc.get("type") != "SCALAR":
            raise ValueError(f"{path.name} indices are not scalar")
        width = struct.calcsize(fmt)
        values = [struct.unpack_from(fmt, blob, index_at + index * width)[0] for index in range(index_acc["count"])]
        faces = [tuple(values[index:index + 3]) for index in range(0, len(values) - 2, 3)]
    return points, faces


def largest_share(faces: list[tuple[int, int, int]]) -> float:
    """Share of triangle vertices that sit in the largest connected piece."""
    parent: dict[int, int] = {}

    def find(node: int) -> int:
        root = node
        while parent[root] != root:
            root = parent[root]
        while parent[node] != root:
            parent[node], node = root, parent[node]
        return root

    for tri in faces:
        for vert in tri:
            parent.setdefault(vert, vert)
        root = find(tri[0])
        for vert in tri[1:]:
            parent[find(vert)] = root
    if not parent:
        return 1.0
    counts: dict[int, int] = {}
    for vert in parent:
        root = find(vert)
        counts[root] = counts.get(root, 0) + 1
    return max(counts.values()) / len(parent)


def check_glb(path: Path) -> dict:
    points, faces = load_primitive(path)
    report = height_report(points)
    report["glb"] = str(path)
    report["share"] = 1.0
    if faces and report["ok"]:
        share = largest_share(faces)
        report["share"] = round(share, 4)
        if share < MIN_SHARE:
            report["ok"] = False
            report["reason"] = "fragmented"
    return report


def _minimal_glb(points: list[tuple[float, float, float]]) -> bytes:
    """One triangle-free point cloud is enough. A mesh still needs a primitive."""
    blob = b"".join(struct.pack("<fff", *point) for point in points)
    doc = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(blob)}],
        "accessors": [{
            "bufferView": 0,
            "componentType": FLOAT_VEC3,
            "count": len(points),
            "type": "VEC3",
        }],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
    }
    raw = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    raw += b" " * ((4 - len(raw) % 4) % 4)
    chunks = b"".join((
        struct.pack("<I4s", len(raw), b"JSON"),
        raw,
        struct.pack("<I4s", len(blob), b"BIN\x00"),
        blob,
    ))
    return b"glTF" + struct.pack("<II", 2, 12 + len(chunks)) + chunks


def selftest() -> list[str]:
    """A full column passes. A missing middle band fails. The glb reader round-trips."""
    bad: list[str] = []
    column = [(0.0, -1.0 + index * 2 / 1199, 0.0) for index in range(1200)]
    whole = height_report(column)
    if not whole["ok"]:
        bad.append(f"a full column failed ({whole['reason']})")
    gap = [point for point in column if not -0.2 < point[1] < 0.4]
    hole = height_report(gap)
    if hole["ok"] or not hole["empty"]:
        bad.append("a missing middle band passed")
    short = height_report([(0.0, index / 4000, 0.0) for index in range(1200)])
    if short["ok"] or short["reason"] != "height span is short":
        bad.append(f"a short span passed ({short['reason']})")
    path_points = [(0.0, -1.0 + i * 0.02, 0.0) for i in range(1200)]
    raw = _minimal_glb(path_points)
    from tempfile import TemporaryDirectory
    with TemporaryDirectory() as tmp:
        path = Path(tmp) / "column.glb"
        path.write_bytes(raw)
        loaded = check_glb(path)
        if loaded["verts"] != 1200 or not loaded["ok"]:
            bad.append(f"glb reader verts={loaded['verts']} ok={loaded['ok']}")
        path.write_bytes(_faced_glb(column, _strip(0, 1200)))
        one = check_glb(path)
        if not one["ok"] or one["share"] < 0.99:
            bad.append(f"one strip failed ({one['reason']} share={one['share']})")
        path.write_bytes(_faced_glb(column, _strip(0, 600) + _strip(600, 1200)))
        split = check_glb(path)
        if split["ok"] or split["reason"] != "fragmented":
            bad.append(f"two pieces passed ({split['reason']})")
    return bad


def _strip(start: int, stop: int) -> list[int]:
    faces: list[int] = []
    for index in range(start, stop - 2):
        faces.extend((index, index + 1, index + 2))
    return faces


def _faced_glb(points: list[tuple[float, float, float]], indices: list[int]) -> bytes:
    """Positions plus triangles, packed back to back in one buffer."""
    pos = b"".join(struct.pack("<fff", *point) for point in points)
    idx = b"".join(struct.pack("<I", value) for value in indices)
    blob = pos + idx
    doc = {
        "asset": {"version": "2.0"},
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pos)},
            {"buffer": 0, "byteOffset": len(pos), "byteLength": len(idx)},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": FLOAT_VEC3, "count": len(points), "type": "VEC3"},
            {"bufferView": 1, "componentType": UNSIGNED_INT, "count": len(indices), "type": "SCALAR"},
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
    return b"glTF" + struct.pack("<II", 2, 12 + len(chunks)) + chunks
