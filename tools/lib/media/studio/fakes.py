"""Canned artifacts for simulate mode: placeholder stills, a small T-pose GLB, review and measure results.

Every artifact says SIMULATED (in the pixels, the GLB asset generator string, and the JSON).
"""
from __future__ import annotations

import json
import random
import struct
from pathlib import Path

from PIL import Image, ImageDraw

SIM_MARK = "SIMULATED"
VIEWS = ("front", "left", "back", "right")


def still_png(dest: Path, *, label: str, view: str = "front", seed: int = 0, size: int = 512) -> Path:
    """A flat mannequin silhouette on a transparent canvas, labelled SIMULATED."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    hue = rnd.randrange(60, 200)
    skin = (200, 150 + hue // 4, 120 + hue // 3, 255)
    dark = (60, 50, 70, 255)
    cx, s = size // 2, size / 512
    side = view in ("left", "right")
    head_r = int((44 if not side else 40) * s)
    d.ellipse([cx - head_r, int(70 * s), cx + head_r, int(70 * s) + 2 * head_r], fill=skin, outline=dark, width=3)
    tw = int((70 if not side else 46) * s)
    d.rounded_rectangle([cx - tw, int(165 * s), cx + tw, int(330 * s)], radius=int(24 * s), fill=skin, outline=dark, width=3)
    if not side:
        d.rectangle([cx - int(200 * s), int(180 * s), cx + int(200 * s), int(206 * s)], fill=skin, outline=dark, width=3)
    else:
        d.rectangle([cx - int(16 * s), int(180 * s), cx + int(16 * s), int(320 * s)], fill=skin, outline=dark, width=3)
    gap = int((22 if not side else 4) * s)
    for sign in (-1, 1):
        x0 = cx + sign * gap
        x1 = cx + sign * (gap + int(36 * s))
        d.rectangle([min(x0, x1), int(320 * s), max(x0, x1), int(470 * s)], fill=skin, outline=dark, width=3)
    if view == "front":
        for sign in (-1, 1):
            ex = cx + sign * int(16 * s)
            d.ellipse([ex - 5, int(112 * s), ex + 5, int(122 * s)], fill=dark)
    d.rectangle([0, 0, size, int(34 * s)], fill=(20, 20, 30, 220))
    d.text((8, 8), f"{SIM_MARK}  {label}  {view}", fill=(255, 210, 80, 255))
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)
    return dest


def _box(cx: float, cy: float, cz: float, sx: float, sy: float, sz: float) -> tuple[list, list, list]:
    """24 vertices with flat normals and 36 indices for one axis-aligned box."""
    pos, nrm, idx = [], [], []
    faces = (
        ((1, 0, 0), [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
        ((-1, 0, 0), [(-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1)]),
        ((0, 1, 0), [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
        ((0, -1, 0), [(-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)]),
        ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
        ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)]),
    )
    for n, corners in faces:
        base = len(pos)
        for x, y, z in corners:
            pos.append((cx + x * sx / 2, cy + y * sy / 2, cz + z * sz / 2))
            nrm.append(n)
        idx += [base, base + 1, base + 2, base, base + 2, base + 3]
    return pos, nrm, idx


def tpose_glb(dest: Path) -> Path:
    """A blocky T-pose figure (about 1.9 m tall) as one GLB mesh. Small on purpose."""
    parts = [
        (0, 1.62, 0, 0.26, 0.28, 0.26),   # head
        (0, 1.22, 0, 0.42, 0.52, 0.22),   # torso
        (0, 0.90, 0, 0.38, 0.16, 0.22),   # hips
        (-0.55, 1.40, 0, 0.70, 0.10, 0.10),  # left arm
        (0.55, 1.40, 0, 0.70, 0.10, 0.10),   # right arm
        (-0.12, 0.42, 0, 0.13, 0.80, 0.14),  # left leg
        (0.12, 0.42, 0, 0.13, 0.80, 0.14),   # right leg
        (-0.12, 0.02, 0.05, 0.14, 0.05, 0.26),  # left foot
        (0.12, 0.02, 0.05, 0.14, 0.05, 0.26),   # right foot
    ]
    pos, nrm, idx = [], [], []
    for p in parts:
        bp, bn, bi = _box(*p)
        off = len(pos)
        pos += bp
        nrm += bn
        idx += [i + off for i in bi]
    pbytes = b"".join(struct.pack("<3f", *v) for v in pos)
    nbytes = b"".join(struct.pack("<3f", *v) for v in nrm)
    ibytes = b"".join(struct.pack("<H", i) for i in idx)
    ibytes += b"\0" * (-len(ibytes) % 4)
    blob = pbytes + nbytes + ibytes
    mins = [min(v[i] for v in pos) for i in range(3)]
    maxs = [max(v[i] for v in pos) for i in range(3)]
    gltf = {
        "asset": {"version": "2.0", "generator": f"wdb studio {SIM_MARK} placeholder"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "sim-tpose"}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "material": 0}]}],
        "materials": [{"pbrMetallicRoughness": {"baseColorFactor": [0.78, 0.62, 0.52, 1.0], "metallicFactor": 0.0}}],
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(pbytes), "target": 34962},
            {"buffer": 0, "byteOffset": len(pbytes), "byteLength": len(nbytes), "target": 34962},
            {"buffer": 0, "byteOffset": len(pbytes) + len(nbytes), "byteLength": len(idx) * 2, "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3", "min": mins, "max": maxs},
            {"bufferView": 1, "componentType": 5126, "count": len(nrm), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5123, "count": len(idx), "type": "SCALAR"},
        ],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    out = struct.pack("<4sII", b"glTF", 2, total) + struct.pack("<I4s", len(js), b"JSON") + js
    out += struct.pack("<I4s", len(blob), b"BIN\0") + blob
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(out)
    return dest


def review(checks: list[dict], *, seed: int, fail_rate: float = 0.25, force_pass: bool = False) -> dict:
    """The real review shape: {verdict, checks:[{id, pass, reason}], failed}."""
    rnd = random.Random(seed)
    rows = []
    for row in checks:
        ok = force_pass or rnd.random() >= fail_rate
        reason = "" if ok else f"(simulated) {row.get('fail_if', 'check missed')}"
        rows.append({"id": row["id"], "pass": ok, "reason": reason})
    failed = [r["id"] for r in rows if not r["pass"]]
    return {"verdict": "fail" if failed else "pass", "checks": rows, "failed": failed, "simulated": True}


def proportion(seed: int) -> dict:
    rnd = random.Random(seed)
    head, thigh, calf = round(rnd.uniform(0.7, 1.1), 3), round(rnd.uniform(0.35, 0.52), 3), round(rnd.uniform(0.22, 0.34), 3)
    ok = 0.73 <= head <= 1.2 and thigh <= 0.5 and calf <= 0.32
    reason = "in band" if ok else "a measure is out of band"
    return {"head_ratio": head, "thigh_ratio": thigh, "calf_ratio": calf, "ok": ok, "reason": f"(simulated) {reason}", "simulated": True}


def mesh_report(seed: int) -> dict:
    rnd = random.Random(seed)
    return {"verts": rnd.randrange(30000, 60000), "span": round(rnd.uniform(1.85, 1.98), 4), "empty": [], "bands": 12,
            "ok": True, "reason": "", "simulated": True}


def silent_wav(dest: Path, seconds: float = 0.3) -> Path:
    """A short quiet tone so a simulated sound plays."""
    import math
    import struct
    import wave
    dest.parent.mkdir(parents=True, exist_ok=True)
    rate = 22050
    with wave.open(str(dest), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        n = int(rate * seconds)
        w.writeframes(b"".join(struct.pack("<h", int(1200 * math.sin(2 * math.pi * 440 * i / rate) * (1 - i / n))) for i in range(n)))
    return dest


# ---- Wang tilesets (placeholder) ----------------------------------------------------------------
# Tile count and sheet columns per variant. Corner and edge sets are 16 tiles (every on/off combination of
# 4 corners or 4 edges); blob-47 is the 47-tile corner-and-edge set Godot's "match corners and sides" terrain uses.
WANG_LAYOUT = {"seamless": (1, 1), "wang-corner-16": (16, 4), "wang-edge-16": (16, 4), "blob-47": (47, 8)}


def _blob_masks() -> list[int]:
    """The 47 corner-and-edge masks: bits N,E,S,W (1,2,4,8) and NE,SE,SW,NW (16,32,64,128); a corner counts only when both sides do."""
    out = set()
    for m in range(256):
        n, e, s, w = m & 1, m & 2, m & 4, m & 8
        keep = m & 15
        keep |= m & 16 if n and e else 0
        keep |= m & 32 if s and e else 0
        keep |= m & 64 if s and w else 0
        keep |= m & 128 if n and w else 0
        out.add(keep)
    return sorted(out)


def _wang_tile(size: int, kind: str, mask: int, a: tuple, b: tuple) -> Image.Image:
    img = Image.new("RGBA", (size, size), a)
    d = ImageDraw.Draw(img)
    h = size // 2
    q = size // 3
    if kind == "wang-corner-16":
        for bit, box in ((1, (0, 0, h, h)), (2, (h, 0, size, h)), (4, (h, h, size, size)), (8, (0, h, h, size))):
            if mask & bit:
                d.rectangle(box, fill=b)
    elif kind in ("wang-edge-16", "blob-47"):
        d.rectangle((q, q, size - q, size - q), fill=b if mask else a)
        for bit, box in ((1, (q, 0, size - q, q)), (2, (size - q, q, size, size - q)), (4, (q, size - q, size - q, size)), (8, (0, q, q, size - q))):
            if mask & bit:
                d.rectangle(box, fill=b)
        if kind == "blob-47":
            for bit, box in ((16, (size - q, 0, size, q)), (32, (size - q, size - q, size, size)), (64, (0, size - q, q, size)), (128, (0, 0, q, q))):
                if mask & bit:
                    d.rectangle(box, fill=b)
    d.rectangle((0, 0, size - 1, size - 1), outline=(0, 0, 0, 90))
    return img


def wang_sheet(dest: Path, *, kind: str, a: str, b: str, size: int = 128, seed: int = 0) -> tuple[Path, int, int]:
    """A placeholder sheet for one Wang variant: every tile in order, two flat colours for the two materials."""
    rnd = random.Random(seed)
    ca = (rnd.randrange(40, 110), rnd.randrange(40, 110), rnd.randrange(40, 110), 255)
    cb = (rnd.randrange(140, 230), rnd.randrange(120, 210), rnd.randrange(60, 160), 255)
    count, cols = WANG_LAYOUT[kind]
    masks = list(range(16)) if count == 16 else _blob_masks() if count == 47 else [0]
    rows = (count + cols - 1) // cols
    cell = max(16, min(size, 128))
    sheet = Image.new("RGBA", (cols * cell, rows * cell + 24), (0, 0, 0, 0))
    for i, m in enumerate(masks):
        sheet.paste(_wang_tile(cell, kind, m, ca, cb), ((i % cols) * cell, (i // cols) * cell + 24))
    d = ImageDraw.Draw(sheet)
    d.rectangle((0, 0, sheet.width, 23), fill=(20, 20, 30, 230))
    d.text((6, 6), f"{SIM_MARK}  {kind}  {a} / {b}  {size}px", fill=(255, 210, 80, 255))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)
    return dest, count, cols


def wang_preview(dest: Path, *, kind: str, seed: int = 0, cells: int = 8, cell: int = 48) -> Path:
    """A small random map drawn with the variant's matching rule, so seams can be eyeballed."""
    rnd = random.Random(seed + 7)
    ca, cb = (70, 80, 90, 255), (190, 170, 110, 255)
    grid = [[rnd.random() < 0.45 for _ in range(cells + 1)] for _ in range(cells + 1)]
    img = Image.new("RGBA", (cells * cell, cells * cell + 24), (0, 0, 0, 0))
    for y in range(cells):
        for x in range(cells):
            if kind == "wang-corner-16":
                m = grid[y][x] * 1 | grid[y][x + 1] * 2 | grid[y + 1][x + 1] * 4 | grid[y + 1][x] * 8
            elif kind == "seamless":
                m = 0
            else:
                c = grid[y][x]
                m = 0
                if c:
                    n, e, s, w = y > 0 and grid[y - 1][x], x < cells - 1 and grid[y][x + 1], y < cells - 1 and grid[y + 1][x], x > 0 and grid[y][x - 1]
                    m = (n and 1) | (e and 2) | (s and 4) | (w and 8)
                    m = m or 0
            img.paste(_wang_tile(cell, kind, m, ca, cb), (x * cell, y * cell + 24))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, img.width, 23), fill=(20, 20, 30, 230))
    d.text((6, 6), f"{SIM_MARK}  preview  {kind}", fill=(255, 210, 80, 255))
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.save(dest)
    return dest
