"""Hub bake roof-slope check (tools/bake.py check): each guild roof's own sun is in the bake.

hub_roof.gd slopes() scales a roof footprint per slope by Lambert against flat ground, so the front (south, sun-away)
half reads darker than the back half. Per footprint in FEET whose back half is a protected bright roof (median >
ROOF_MIN grey; the stall tarp footprint sits lower and is skipped): FAIL when front median / back median > MAX_RATIO.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bake_leak

ROOF_MIN = 200
MAX_RATIO = 0.9

def halves(img, data: dict) -> list[tuple[int, float, float]]:
    """(footprint index, back median, front median) grey, 4 texels in from the x ends, 2 from each half's z ends."""
    px = img.convert("L").load()
    o, s = data["org"], data["sub"]
    out = []
    for i, (x, z, w, d) in enumerate(data["feet"]):
        def med(z0: float, z1: float) -> float:
            v = sorted(px[a, b] for a in range(math.ceil((x - o[0]) * s) + 4, math.floor((x + w - o[0]) * s) - 4)
                       for b in range(math.ceil((z0 - o[1]) * s) + 2, math.floor((z1 - o[1]) * s) - 2))
            return float(v[len(v) // 2]) if v else 0.0
        out.append((i, med(z, z + d / 2), med(z + d / 2, z + d)))
    return out

def problems(root: Path, png: Path) -> list[str]:
    feet = root / bake_leak.FEET
    if not feet.is_file():
        return []  # bake_leak reports the missing file
    from PIL import Image
    data = json.loads(feet.read_text(encoding="utf-8"))
    with Image.open(png) as im:
        rows = halves(im, data)
    roofs = [r for r in rows if r[1] > ROOF_MIN]
    out = [f"FAIL roof slope: footprint {i} front {f:.0f} / back {b:.0f} = {f / b:.2f} grey (> {MAX_RATIO}); the roof's "
           f"own sun is missing from the bake (hub_roof.gd slopes)" for i, b, f in roofs if f / b > MAX_RATIO]
    return out + ([] if roofs else [f"FAIL roof slope: no bright roof footprint (back half > {ROOF_MIN}) in {bake_leak.FEET}"])

def selftest(td: Path) -> list[str]:
    """A flat-lit roof footprint FAILs (planted: slopes() skipped); a darker front half passes."""
    from PIL import Image, ImageDraw
    data = {"org": [0.0, 0.0], "sub": 16.0, "feet": [[2.0, 2.0, 2.0, 2.0]]}
    flat = Image.new("RGB", (96, 96), (100, 100, 100))
    ImageDraw.Draw(flat).rectangle([32, 32, 63, 63], fill=(230, 230, 230))
    lit = flat.copy()
    ImageDraw.Draw(lit).rectangle([32, 48, 63, 63], fill=(180, 180, 180))
    def ratio(im) -> float:
        _, b, f = halves(im, data)[0]
        return f / b
    bad = [] if ratio(flat) > MAX_RATIO else [f"roof: flat roof passed ({ratio(flat):.2f})"]
    return bad + ([] if ratio(lit) <= MAX_RATIO else [f"roof: shaded front flagged ({ratio(lit):.2f})"])
