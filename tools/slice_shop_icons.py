#!/usr/bin/env python3
"""Slice the ghost-shop icon sheet into gear sources and keyed 64px icons.

The sheet is the Imagine plate at _src/sources/assets/ui/shop-icons/shop_icons.png
(magenta cells, black grid). This writes one unkeyed cell per icon under
_src/sources/assets/ui/gear/ and the keyed icon under assets/ui/gear/.
Order is left to right, top to bottom: snack, then the 24 artifacts.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import agent_log  # noqa: E402
from imglib.geom import fit_box  # noqa: E402
import sprite_pipeline as sp  # noqa: E402

SHEET = ROOT / "_src" / "sources" / "assets" / "ui" / "shop-icons" / "shop_icons.png"
LOG_SHEET = ROOT / "_logs" / "icon-gen" / "shop_icons.png"
PLATES = ROOT / "_src" / "sources" / "assets" / "ui" / "gear"
LIVE = ROOT / "assets" / "ui" / "gear"
MANIFEST = ROOT / "_src" / "manifest.json"

NAMES = (
    "snack",
    "cinder_ember",
    "cinder_coil",
    "tide_pearl",
    "tide_scale",
    "root_knot",
    "root_charm",
    "root_seed",
    "ash_mask",
    "ash_bell",
    "ash_cloak",
    "spark_lens",
    "spark_wire",
    "bone_ring",
    "bone_splint",
    "bone_tooth",
    "veil_shard",
    "veil_thread",
    "veil_coin",
    "veil_hush",
    "iron_seal",
    "iron_nail",
    "iron_link",
    "iron_plate",
    "iron_heart",
)

def _bands(mask: np.ndarray) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    start = None
    for i, on in enumerate(mask.tolist()):
        if on and start is None:
            start = i
        elif not on and start is not None:
            spans.append((start, i))
            start = None
    if start is not None:
        spans.append((start, len(mask)))
    return spans

def _cells(im: Image.Image) -> list[Image.Image]:
    rgb = np.asarray(im.convert("RGBA"))[:, :, :3]
    dark = rgb.max(axis=2) < 40
    rows = [s for s in _bands(~(dark.mean(axis=1) > 0.55)) if s[1] - s[0] > 20]
    cols = [s for s in _bands(~(dark.mean(axis=0) > 0.55)) if s[1] - s[0] > 20]
    if len(rows) != 5 or len(cols) != 5:
        raise SystemExit(f"grid {len(cols)}x{len(rows)} from {im.size}, want 5x5")
    out: list[Image.Image] = []
    for y0, y1 in rows:
        for x0, x1 in cols:
            out.append(im.crop((x0, y0, x1, y1)))
    if len(out) != len(NAMES):
        raise SystemExit(f"cells {len(out)} names {len(NAMES)}")
    return out

def _save(path: Path, im: Image.Image) -> None:
    if agent_log.DRY_RUN:
        print(f"would write {path.relative_to(ROOT).as_posix()}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"wrote {path.relative_to(ROOT).as_posix()}")

def _ensure_sheet() -> None:
    if SHEET.is_file():
        return
    if not LOG_SHEET.is_file():
        raise SystemExit(f"missing source sheet {SHEET.relative_to(ROOT).as_posix()}")
    if agent_log.DRY_RUN:
        print(f"would write {SHEET.relative_to(ROOT).as_posix()}")
        return
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(LOG_SHEET, SHEET)
    print(f"wrote {SHEET.relative_to(ROOT).as_posix()}")

def _manifest(names: tuple[str, ...]) -> None:
    if not MANIFEST.is_file():
        print("missing manifest")
        return
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    have = {str(e.get("live", "")) for e in data.get("entries", [])}
    added = 0
    for name in names:
        live = f"assets/ui/gear/{name}.png"
        if live in have:
            continue
        data["entries"].append({
            "live": live,
            "source": f"sources/assets/ui/gear/{name}.png",
            "origin": f"_src/sources/assets/ui/gear/{name}.png",
            "flip": False,
            "window": "full",
            "kind": "figure",
            "loose": False,
            "cell": "",
        })
        added += 1
    if added == 0:
        print("manifest already has the shop icons")
        return
    if agent_log.DRY_RUN:
        print(f"would write _src/manifest.json added={added}")
        return
    MANIFEST.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"wrote _src/manifest.json added={added}")

def _run() -> None:
    _ensure_sheet()
    if agent_log.DRY_RUN and not SHEET.is_file():
        for name in NAMES:
            print(f"would write _src/sources/assets/ui/gear/{name}.png")
            print(f"would write assets/ui/gear/{name}.png")
        _manifest(NAMES)
        return
    im = Image.open(SHEET).convert("RGBA")
    for name, cell in zip(NAMES, _cells(im)):
        _save(PLATES / f"{name}.png", cell)
        _save(LIVE / f"{name}.png", fit_box(sp.key_to_alpha(cell), 64, 2))
    _manifest(NAMES)

def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer(
        "slice_shop_icons",
        "Slice _src/sources/assets/ui/shop-icons/shop_icons.png into gear plates and keyed 64px icons.",
        _run,
        argv,
        globals(),
    )

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
