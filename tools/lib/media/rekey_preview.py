#!/usr/bin/env python3
"""Preview the open-set rekey. Does not write live assets.

    python tools/media.py rekey-preview
    python tools/media.py rekey-preview --only shopkeep,wisp
Keys each source plate with plate_remap then key_to_alpha, fits it, and writes a
blue composite under _logs/rekey-look/. The counts are the check. This file stays
in tools/ so the next session runs it again. session.py py would delete a copy
under _logs/agent-py/.

Does not nearest-upscale the plate first (that distorted the female face).

    python tools/media.py rekey-preview --pixelate 32 [--palette 24] [--only dumpster,stall]
--pixelate N (cells per metre; 32 = the hub ground pixel) adds key.pixelate after keying and writes
before|after pairs as px_<name>.png. With it the hub set (HUB_SET, live keyed art, world width per sheet
width) is previewed too.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

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
# Hub props and faces: name, live path, world metres across the sheet (negative = sheet height: interact_fx spr_h
# 0.85 for the yard props; positive = width: layout_spec box x * face_w for the faces).
HUB_SET = (
    ("dumpster", "assets/sprites/props/dumpster.png", -0.85),
    ("anvil", "assets/sprites/props/anvil.png", -0.85),
    ("notice_board", "assets/sprites/props/notice_board.png", -0.85),
    ("sign", "assets/sprites/props/sign.png", -0.85),
    ("stall", "assets/sprites/buildings/stall.png", 4.6 * 0.96),
    ("guild", "assets/sprites/buildings/guild.png", 5.6),
    ("guild_reception", "assets/sprites/buildings/guild_reception.png", 3.8),
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
    keyed = key.key_to_alpha(raw)
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

def _pair(a: Image.Image, b: Image.Image, scale: int = 3) -> Image.Image:
    w, h = a.size
    out = Image.new("RGBA", (w * 2 + 4, h), BLUE)
    out.paste(a, (0, 0), a)
    out.paste(b, (w + 4, 0), b)
    return out.resize((out.width * scale, out.height * scale), Image.NEAREST)

def _pixel_one(root: Path, name: str, im: Image.Image, metres: float, cells: float, palette: int, out_dir: Path, dry: bool) -> str:
    side = im.size[1] if metres < 0 else im.size[0]
    cell = side / max(abs(metres), 1e-6) / cells
    px = key.pixelate(im, cell, palette)
    a = np.array(px)
    line = (f"px {name} cell={cell:.2f}src_px colours={len(np.unique(a[a[..., 3] > 0][:, :3], axis=0))} "
            f"partial={int(((a[..., 3] > 0) & (a[..., 3] < 255)).sum())}")
    if not dry:
        _pair(im, px).save(out_dir / f"px_{name}.png")
        line += f" preview=_logs/rekey-look/px_{name}.png"
    return line

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Preview the open-set rekey on blue. Does not write live assets.", writes=True)
    ap.add_argument("--only", default="", help="Comma-separated names from the open set (default: all nine).")
    ap.add_argument("--pixelate", type=float, default=0.0, help="Cells per metre for key.pixelate after keying (32 = hub ground pixel); adds the hub set.")
    ap.add_argument("--palette", type=int, default=0, help="With --pixelate: quantize to this many colours (0 = off).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    wanted = {p.strip() for p in args.only.split(",") if p.strip()}
    names = {row[0] for row in OPEN_SET} | ({row[0] for row in HUB_SET} if args.pixelate > 0 else set())
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
        if args.pixelate > 0 and not wanted:
            break
        if wanted and name not in wanted:
            continue
        shown += 1
        line = _one(root, name, live, canvas, pad, out_dir, args.dry_run)
        if line.endswith("MISSING source for " + live) or " MISSING source " in line:
            missing += 1
        lines.append(line)
    if args.pixelate > 0:
        for name, live, metres in HUB_SET:
            if wanted and name not in wanted:
                continue
            path = root / live
            if not path.is_file():
                missing += 1
                lines.append(f"px {name} MISSING {live}")
                continue
            shown += 1
            lines.append(_pixel_one(root, name, imgio.load(path).convert("RGBA"), metres, args.pixelate, args.palette, out_dir, args.dry_run))
    status = "FAIL" if missing else "PASS"
    if missing:
        lines.append(f"{missing} source(s) missing")
    return agent_log.finish("rekey-preview", root, "\n".join(lines), status, args=args, shown=shown, missing=missing)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
