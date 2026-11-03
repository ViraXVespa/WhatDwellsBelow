"""Hub bake light-leak check (tools/bake.py check): no lit rim around a building's footprint.

A building footprint stays unshaded in hub_light.png (its roof samples the atlas there). If the bake blur mixes
that bright footprint into the yard texels around it, the ground right at the walls glows (a light outline round
the guild hall). Per footprint side, per texel column along it (corners and texels inside another footprint
skipped): rim = mean light of the 1st-2nd texels outside, base = mean of the 3rd-5th. A side FAILs when its
median rim - base exceeds LEAK_TOL (0-255 grey). Footprints and image origin come from FEET, which
tools/bake.py camp records from its bake_dbg prot / org lines (record()).
"""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

FEET = "tools/data/hub_bake_feet.json"
LEAK_TOL = 4.0
CORNER = 4

def record(root: Path, log: Path) -> Path | None:
    """Write FEET from a bake log; None when the log has no org line."""
    text = log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""
    org = re.search(r"bake_dbg: org (\S+) (\S+) (\S+)", text)
    if not org:
        return None
    feet = [[float(v) for v in m.groups()] for m in re.finditer(r"bake_dbg: prot \S+ (\S+) (\S+) (\S+) (\S+)", text)]
    out = root / FEET
    rows = ",\n  ".join(json.dumps(f) for f in feet)
    out.write_text(f'{{"org": [{float(org.group(1))}, {float(org.group(2))}], "sub": {float(org.group(3))},\n "feet": [\n  {rows}\n ]}}\n',
                   encoding="utf-8")
    return out

def _box(r: list[float], org: list[float], sub: float) -> tuple[int, int, int, int]:
    x, z, w, d = r
    return (math.ceil((x - org[0]) * sub - 0.5), math.floor((x + w - org[0]) * sub - 0.5),
            math.ceil((z - org[1]) * sub - 0.5), math.floor((z + d - org[1]) * sub - 0.5))

def sides(img, data: dict) -> list[tuple[int, str, float]]:
    """(footprint index, side N/S/E/W, median rim - base) for every footprint side with columns to read."""
    px = img.convert("RGB").load()
    w, h = img.size
    boxes = [_box(r, data["org"], data["sub"]) for r in data["feet"]]
    def inside(x: int, y: int) -> bool:
        return any(b[0] <= x <= b[1] and b[2] <= y <= b[3] for b in boxes)
    def lum(x: int, y: int) -> float:
        return sum(px[x, y]) / 3.0
    out = []
    for i, (x0, x1, y0, y1) in enumerate(boxes):
        for side, (dx, dy) in {"N": (0, -1), "S": (0, 1), "W": (-1, 0), "E": (1, 0)}.items():
            if dy:
                cols = [(c, y1 if dy > 0 else y0) for c in range(x0 + CORNER, x1 - CORNER + 1)]
            else:
                cols = [(x1 if dx > 0 else x0, c) for c in range(y0 + CORNER, y1 - CORNER + 1)]
            diffs = []
            for ex, ey in cols:
                pts = [(ex + dx * k, ey + dy * k) for k in range(1, 6)]
                if any(not (0 <= x < w and 0 <= y < h) or inside(x, y) for x, y in pts):
                    continue
                v = [lum(x, y) for x, y in pts]
                diffs.append((v[0] + v[1]) / 2.0 - (v[2] + v[3] + v[4]) / 3.0)
            if diffs:
                diffs.sort()
                out.append((i, side, diffs[len(diffs) // 2]))
    return out

def problems(root: Path, png: Path) -> list[str]:
    """FAIL lines for leaking footprint sides (empty when clean)."""
    feet = root / FEET
    if not feet.is_file():
        return [f"FAIL {FEET} missing: run tools/bake.py camp (records the bake footprints)"]
    from PIL import Image
    data = json.loads(feet.read_text(encoding="utf-8"))
    with Image.open(png) as im:
        rows = sides(im, data)
    return [f"FAIL light leak: footprint {i} {data['feet'][i]} side {s} rim +{d:.1f} grey over the yard 3-5 texels out "
            f"(> {LEAK_TOL}); the blur bleeds the lit footprint past the walls (hub_blur.gd zones)"
            for i, s, d in rows if d > LEAK_TOL]

def selftest(td: Path) -> list[str]:
    """A dark yard round one bright footprint: a blurred rim FAILs, a sharp edge passes."""
    from PIL import Image, ImageDraw, ImageFilter
    data = {"org": [0.0, 0.0], "sub": 16.0, "feet": [[2.0, 2.0, 2.0, 2.0]]}
    im = Image.new("RGB", (96, 96), (100, 100, 100))
    ImageDraw.Draw(im).rectangle([32, 32, 63, 63], fill=(230, 230, 230))
    sharp = [d for _, _, d in sides(im, data)]
    soft = [d for _, _, d in sides(im.filter(ImageFilter.BoxBlur(1)), data)]
    bad = [] if len(sharp) == 4 and max(sharp) <= LEAK_TOL else [f"leak: sharp footprint edge flagged {sharp}"]
    return bad + ([] if len(soft) == 4 and min(soft) > LEAK_TOL else [f"leak: blurred rim not flagged {soft}"])
