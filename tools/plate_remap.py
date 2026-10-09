#!/usr/bin/env python3
"""Remap a generated chroma plate to exact #FF00FF.

Keeps the plate opaque. Does not punch alpha. Feed the result to I2V or to
sprite_pipeline key/matte after you accept the still.

The plate is found by imglib.key.plate_mask: Lab distance to several colours sampled from the border
(a generated plate drifts in shade and carries JPEG noise), a hue band, then connected components. Solid
plate near a border reference ends exactly (255, 0, 255). A farther mix keeps its drawn RGB.

  python tools/plate_remap.py SRC DEST
  python tools/plate_remap.py SRC DEST --wand 48 --edge 5 --mask DEST.mask.png
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from PIL import Image  # noqa: E402

from imglib import imgio, key  # noqa: E402

KEY = imgio.MAGENTA
KEY_HEX = imgio.MAGENTA_HEX
POCKET_FRAC = key.POCKET_FRAC


def remap(
    im: Image.Image,
    wand_dist: float = 48.0,
    min_amount: float = 0.72,
    edge: int = 4,
    edge_min: float = 0.04,
    pocket_frac: float = POCKET_FRAC,
    tol: float = key.LAB_TOL,
) -> tuple[Image.Image, Image.Image, dict]:
    """Returns (remapped RGBA, debug mask, info). See imglib.key.remap_plate."""
    return key.remap_plate(im, tol=tol, wand_dist=wand_dist, min_amount=min_amount, edge=edge, edge_min=edge_min, pocket_frac=pocket_frac)


def main() -> None:
    p = argparse.ArgumentParser(epilog="No --root: explicit-path tool, exempt by design (paths are arguments).",
        description="Hue-correct a sampled chroma plate to #FF00FF, including bleed and enclosed pockets."
    )
    p.add_argument("src", type=Path, help="Source still (JPG/PNG).")
    p.add_argument("dest", type=Path, help="Output PNG path.")
    p.add_argument("--wand", type=float, default=48.0, help="Extra RGB distance to the nearest plate colour that still counts as plate")
    p.add_argument("--tol", type=float, default=key.LAB_TOL, help="Lab distance to the nearest plate colour that counts as plate")
    p.add_argument("--min-amount", type=float, default=0.72, help="Kept for old command lines (no effect: plate pixels always become exact #FF00FF)")
    p.add_argument("--edge", type=int, default=4, help="Inward radius (px) to hunt bleed")
    p.add_argument("--edge-min", type=float, default=0.04, help="Min start-chroma mix on an edge pixel before remap")
    p.add_argument("--pocket-frac", type=float, default=POCKET_FRAC, help="Max island size as a fraction of the image (sprite_pipeline default 0.07)")
    p.add_argument("--mask", type=Path, default=None, help="Write a debug mask (magenta=plate, orange=bleed)")
    args = p.parse_args()
    if not args.src.is_file():
        print(f"missing {args.src}", file=sys.stderr)
        sys.exit(1)
    out, vis, info = remap(imgio.load(args.src), wand_dist=args.wand, min_amount=args.min_amount, edge=args.edge,
                           edge_min=args.edge_min, pocket_frac=args.pocket_frac, tol=args.tol)
    imgio.save(out, args.dest)
    if args.mask:
        imgio.save(vis, args.mask)
    print(json.dumps(info, indent=2))


if __name__ == "__main__":
    main()
