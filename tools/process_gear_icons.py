#!/usr/bin/env python3
# Key _src/gear/*.jpg through the live still pipeline into assets/ui/gear/*.png
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image
from sprite_lib import fit_box  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import plate_remap as pr  # noqa: E402
import sprite_pipeline as sp  # noqa: E402

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

SRC = ROOT / "_src" / "gear"
DEST = ROOT / "assets" / "ui" / "gear"
CANVAS = 64
PAD = 2

EXPECTED = (
    "slot_head",
    "slot_body",
    "slot_legs",
    "slot_potion",
    "slot_food",
    "great_axe",
    "staff",
    "longbow",
    "pickaxe",
    "hatchet",
    "head",
    "body",
    "legs",
    "ration",
    "trail_bread",
    "potion",
)


def key_still(src: Path) -> Image.Image:
    raw = Image.open(src).convert("RGBA")
    remapped, _vis, _info = pr.remap(raw)
    return sp.key_to_alpha(remapped, spill_flood=False)


def fit_icon(keyed: Image.Image, canvas: int = CANVAS) -> Image.Image:
    return fit_box(keyed, canvas, PAD)


def sources() -> list[Path]:
    found: list[Path] = []
    for path in sorted(SRC.iterdir()) if SRC.is_dir() else []:
        if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
            found.append(path)
    return found


def _run() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"missing source dir {SRC}")
    DEST.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    for src in sources():
        dest = DEST / (src.stem + ".png")
        out = fit_icon(key_still(src))
        out.save(dest)
        seen.add(src.stem)
        print(f"wrote {dest.relative_to(ROOT)} {out.size}", flush=True)
    missing = [name for name in EXPECTED if name not in seen]
    if missing:
        print("missing sources: " + ", ".join(missing), flush=True)
    extra = sorted(seen.difference(EXPECTED))
    if extra:
        print("extra sources: " + ", ".join(extra), flush=True)


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("process_gear_icons", 'Key _src/gear/*.jpg through the live still pipeline into assets/ui/gear/*.png.', _run, argv, globals())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
