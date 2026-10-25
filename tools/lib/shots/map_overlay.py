#!/usr/bin/env python3
"""Overlays on a stitched full-map PNG (`shots.py capture --full-map --overlays ...`): the sweep's marks (sweep_marks.gd,
saved as <png>.marks.json) drawn in grid cells. Layers: rooms (bounds coloured by kind), spawns (enemy spawn jobs sized
by pack, ambush red, named purple; the arrival spawn, stairs, boss door and boss), torches, loot (placed props and
interactables), lift (brighten the dark floor first), legend.

  python tools/lib/shots/map_overlay.py --selftest
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

LAYERS = ("lift", "rooms", "spawns", "torches", "loot", "legend")
ROOM = {"spawn": "#3ddc84", "boss": "#ff4d4d", "shop": "#4dc3ff", "extract_gate": "#4dc3ff", "puzzle": "#c77dff",
        "stash": "#ffd23f", "vein": "#ffa94d", "base": "#ff8c42"}
KEY = {"spawn": "#3ddc84", "stairs": "#ffffff", "boss_door": "#ff4d4d", "boss": "#ff4d4d", "boss_enemy": "#ff4d4d",
       "ambush": "#ff3b3b", "named": "#c77dff", "enemy": "#ff9f1c", "torch": "#ffe066", "loot": "#4df0ff"}
MAP_SPAWN = {"enemy_job", "ambush", "named"}
MAP_KEY = {"spawn", "stairs", "boss_door", "boss", "boss_enemy"}

def save_marks(sweep: dict, png: Path) -> Path | None:
    """Keep the sweep's geometry and marks next to the PNG (the tiles may be deleted)."""
    if "marks" not in sweep:
        return None
    out = png.with_suffix(".marks.json")
    out.write_text(json.dumps({k: v for k, v in sweep.items() if k != "tiles"}), encoding="utf-8")
    return out

def _xy(d: dict, f: float, cell) -> tuple[float, float]:
    return (cell[0] + 0.5 - d["x0"]) * d["ppu"] / f, (cell[1] + 0.5 - d["z0"]) * d["sinp"] * d["ppu"] / f

def draw(png: Path, marks: dict, layers: list[str], out: Path) -> dict:
    """Draw the layers on png -> out; returns counts per layer."""
    from PIL import Image, ImageDraw, ImageEnhance
    Image.MAX_IMAGE_PIXELS = None
    bad = sorted(set(layers) - set(LAYERS))
    if bad:
        raise SystemExit("unknown overlay layers %s (have: %s)" % (bad, ", ".join(LAYERS)))
    im = Image.open(png).convert("RGB")
    if "lift" in layers:
        im = ImageEnhance.Brightness(im).enhance(2.2)
    f = marks["w"] * marks["ppu"] / im.width  # the stitch's 2x reduce factor
    m = marks.get("marks", {})
    dr = ImageDraw.Draw(im)
    r = max(marks["ppu"] / f * 0.45, im.width / 700.0)  # about one cell, readable when reduced
    lw = max(1, int(r / 2))
    got: dict[str, int] = {}
    if "rooms" in layers:
        for rm in m.get("rooms", []):
            x0, y0 = _xy(marks, f, (rm["x"] - 0.5, rm["y"] - 0.5))
            x1, y1 = _xy(marks, f, (rm["x"] + rm["w"] - 0.5, rm["y"] + rm["h"] - 0.5))
            dr.rectangle((x0, y0, x1, y1), outline=ROOM.get(rm["kind"], "#8899aa"), width=lw)
        got["rooms"] = len(m.get("rooms", []))
    if "torches" in layers:
        for c in m.get("torches", []):
            x, y = _xy(marks, f, c)
            dr.ellipse((x - r * 0.6, y - r * 0.6, x + r * 0.6, y + r * 0.6), fill=KEY["torch"])
        got["torches"] = len(m.get("torches", []))
    if "loot" in layers:
        cells = [p["cell"] for p in m.get("props", [])] + [c["cell"] for c in m.get("cells", []) if c["kind"] not in MAP_SPAWN | MAP_KEY]
        for c in cells:
            x, y = _xy(marks, f, c)
            dr.polygon([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], fill=KEY["loot"], outline="#000000")
        got["loot"] = len(cells)
    if "spawns" in layers:
        for e in m.get("enemies", []):
            x, y = _xy(marks, f, e["cell"])
            k = r * (1.0 + 0.35 * max(1, e.get("n", 1)))
            col = KEY["ambush"] if e["kind"] == "ambush" else KEY["named"] if e["kind"] == "named" else KEY["enemy"]
            dr.ellipse((x - k, y - k, x + k, y + k), outline=col, width=lw + 1)
        for c in m.get("cells", []):
            if c["kind"] in MAP_KEY:
                x, y = _xy(marks, f, c["cell"])
                k = r * 2.2
                dr.rectangle((x - k, y - k, x + k, y + k), fill=KEY[c["kind"]], outline="#000000", width=lw)
        got["spawns"] = len(m.get("enemies", []))
    if "legend" in layers:  # a strip under the map, so nothing on the floor is covered
        rows = [("arrival", KEY["spawn"]), ("stairs", KEY["stairs"]), ("boss / door", KEY["boss"]), ("enemy pack (size = count)", KEY["enemy"]),
                ("ambush", KEY["ambush"]), ("named", KEY["named"]), ("torch", KEY["torch"]), ("loot / prop", KEY["loot"])]
        s = max(16, im.width // 90)
        bar = Image.new("RGB", (im.width, im.height + s * 2), (0, 0, 0))
        bar.paste(im, (0, 0))
        im, dr, x = bar, ImageDraw.Draw(bar), s // 2
        for t, col in rows:
            dr.rectangle((x, im.height - s * 1.5, x + s // 2, im.height - s), fill=col)
            dr.text((x + s * 0.8, im.height - s * 1.6), t, fill="#ffffff", font_size=int(s * 0.8))
            x += int(s * (2 + 0.45 * len(t)))
    im.save(out)
    return got

def selftest() -> list[str]:
    import tempfile
    from PIL import Image
    bad: list[str] = []
    marks = {"x0": 10, "z0": 20, "w": 40, "h": 30, "ppu": 64.0, "sinp": 0.5, "marks": {
        "rooms": [{"x": 12, "y": 22, "w": 5, "h": 4, "kind": "boss"}], "torches": [[11, 21]], "props": [{"cell": [30, 30], "kind": "chest"}],
        "enemies": [{"cell": [20, 25], "kind": "ambush", "n": 2}], "cells": [{"cell": [14, 24], "kind": "spawn"}]}}
    with tempfile.TemporaryDirectory() as td:
        png = Path(td) / "m.png"
        Image.new("RGB", (40 * 16, int(30 * 0.5 * 16)), (5, 5, 5)).save(png)  # reduce 4
        if _xy(marks, 4.0, (10, 20)) != (8.0, 4.0):
            bad.append("cell -> px %s" % (_xy(marks, 4.0, (10, 20)),))
        got = draw(png, marks, list(LAYERS), Path(td) / "o.png")
        if got != {"rooms": 1, "torches": 1, "loot": 1, "spawns": 1}:
            bad.append("counts %s" % got)
        o = Image.open(Path(td) / "o.png")
        x, y = _xy(marks, 4.0, (30, 30))
        if o.getpixel((int(x), int(y))) != (77, 240, 255):
            bad.append("loot pixel %s" % (o.getpixel((int(x), int(y))),))
        if save_marks({"tiles": [1], "w": 1}, png) is not None or save_marks({**marks, "tiles": [1]}, png) is None:
            bad.append("save_marks")
        elif "tiles" in json.loads(png.with_suffix(".marks.json").read_text()):
            bad.append("save_marks keeps tiles")
    return bad

if __name__ == "__main__":
    if "--selftest" in sys.argv:
        b = selftest()
        print("\n".join(b) or "map_overlay selftest ok")
        raise SystemExit(1 if b else 0)
    print(__doc__)
