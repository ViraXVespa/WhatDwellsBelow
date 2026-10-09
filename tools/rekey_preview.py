#!/usr/bin/env python3
"""Preview the open-set rekey. Does not write live assets.

    python tools/rekey_preview.py
    python tools/rekey_preview.py --only shopkeep,wisp
Keys each source plate with plate_remap then key_to_alpha, fits it, and writes a
blue composite under _logs/rekey-look/. The counts are the check. This file stays
in tools/ so the next session runs it again. run_agent_py.py would delete a copy
under _logs/agent-py/.

Does not nearest-upscale the plate first (that distorted the female face).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import match_keyed_region as matcher
import plate_remap as pr
from imglib import geom, imgio, key

# name, live path, canvas, pad. Gear is 64 with pad 2. The orb is 48. Other stills are 128 with pad 8.
OPEN_SET = (
    ("shopkeep", "assets/sprites/npcs/shopkeep.png", 128, 8),
    ("wisp", "assets/sprites/enemies/wisp/idle_up.png", 128, 8),
    ("arrow", "assets/fx/arrow.png", 128, 8),
    ("hp_orb", "assets/sprites/props/hp_orb.png", 48, 8),
    ("female", "assets/sprites/player/female/idle_down.png", 128, 8),
    ("head", "assets/ui/gear/head.png", 64, 2),
    ("hatchet", "assets/ui/gear/hatchet.png", 64, 2),
    ("longbow", "assets/ui/gear/longbow.png", 64, 2),
    ("slot_legs", "assets/ui/gear/slot_legs.png", 64, 2),
)
BLUE = (30, 60, 140, 255)
FIT_FLOOR = 24


def _counts(arr: np.ndarray) -> dict[str, int]:
    alpha = arr[:, :, 3]
    rgb = arr[:, :, :3].astype(np.int16)
    spill = np.maximum(0, np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1])
    return {
        "clear": int((alpha == 0).sum()),
        "opaque": int((alpha == 255).sum()),
        "partial": int(((alpha > 0) & (alpha < 255)).sum()),
        "plate_opaque": int(((alpha > 200) & (spill >= 24)).sum()),
    }


def _halo_cropped(im: Image.Image, floor: int = FIT_FLOOR) -> int:
    """Faint pixels outside the fit_box crop. Those are dropped when alpha_min stays at the default."""
    arr = np.array(im.convert("RGBA"))
    alpha = arr[:, :, 3]
    faint = (alpha > 0) & (alpha < floor)
    if not np.any(faint):
        return 0
    box = geom.bbox(im, floor)
    if box is None:
        return int(faint.sum())
    left, top, right, bottom = box
    keep = np.zeros(faint.shape, dtype=bool)
    keep[top:bottom, left:right] = True
    return int((faint & ~keep).sum())


def _light_rows(arr: np.ndarray) -> tuple[int, int]:
    """Rows with a light pixel, and the longest gap between those rows. A string is a run, not sparkles."""
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]
    light = (rgb.min(axis=2) > 170) & (alpha > 80)
    rows = np.flatnonzero(light.any(axis=1))
    if rows.size == 0:
        return 0, 0
    gaps = np.diff(rows) - 1
    gap = int(gaps.max()) if gaps.size else 0
    return int(rows.size), gap


def _one(root: Path, name: str, live: str, canvas: int, pad: int, out_dir: Path, dry: bool) -> str:
    dest = root / live
    src = matcher.resolve_source(dest)
    if src is None or not src.is_file():
        return f"{name} MISSING source for {live}"
    raw = imgio.load(src).convert("RGBA")
    remapped, _vis, info = pr.remap(raw)
    keyed = key.key_to_alpha(remapped, spill_flood=False)
    raw_n = _counts(np.array(keyed))
    cropped = _halo_cropped(keyed)
    fitted = geom.fit_box(keyed, canvas, pad)
    fit_n = _counts(np.array(fitted))
    rel_src = src.relative_to(root).as_posix() if src.is_relative_to(root) else src.as_posix()
    line = (f"{name} source={rel_src} plate_px={info.get('plate_pixels', 0)} "
            f"keyed partial={raw_n['partial']} opaque={raw_n['opaque']} plate_opaque={raw_n['plate_opaque']} "
            f"halo_cropped={cropped} fit={fitted.size[0]}x{fitted.size[1]} "
            f"fit_partial={fit_n['partial']} fit_opaque={fit_n['opaque']} fit_plate_opaque={fit_n['plate_opaque']}")
    if name == "longbow":
        rows, gap = _light_rows(np.array(fitted))
        line += f" near_white_rows={rows} longest_gap={gap}"
    if not dry:
        bg = Image.new("RGBA", fitted.size, BLUE)
        bg.paste(fitted, (0, 0), fitted)
        path = out_dir / f"{name}.png"
        bg.save(path)
        line += f" preview=_logs/rekey-look/{name}.png"
    return line


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Preview the open-set rekey on blue. Does not write live assets.", writes=True)
    ap.add_argument("--only", default="", help="Comma-separated names from the open set (default: all nine).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    wanted = {p.strip() for p in args.only.split(",") if p.strip()}
    names = {row[0] for row in OPEN_SET}
    bad = wanted - names
    if bad:
        agent_log.fail(f"unknown name(s): {', '.join(sorted(bad))}. Known: {', '.join(n for n, *_ in OPEN_SET)}")
    out_dir = root / "_logs" / "rekey-look"
    if not args.dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)
    lines = ["Open-set preview. Live assets are not written. Counts are the check. A picture description is not a pixel count.",
             "partial is plate-mixed glow kept as alpha. plate_opaque is solid plate left in the art. halo_cropped is faint alpha fit_box drops at its default floor of 24."]
    missing = 0
    shown = 0
    for name, live, canvas, pad in OPEN_SET:
        if wanted and name not in wanted:
            continue
        shown += 1
        line = _one(root, name, live, canvas, pad, out_dir, args.dry_run)
        if line.endswith("MISSING source for " + live) or " MISSING source " in line:
            missing += 1
        lines.append(line)
    status = "FAIL" if missing else "PASS"
    if missing:
        lines.append(f"{missing} source(s) missing")
    return agent_log.finish("rekey-preview", root, "\n".join(lines), status, args=args, shown=shown, missing=missing)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
