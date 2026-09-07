# Key _src/gear/*.jpg through the live still pipeline into assets/ui/gear/*.png
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import plate_remap as pr  # noqa: E402
import sprite_pipeline as sp  # noqa: E402

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
    bbox = keyed.getbbox()
    if bbox is None:
        return Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    cropped = keyed.crop(bbox)
    cw, ch = cropped.size
    box = Image.new("RGBA", (cw + PAD * 2, ch + PAD * 2), (0, 0, 0, 0))
    box.paste(cropped, (PAD, PAD), cropped)
    scale = min(canvas / box.size[0], canvas / box.size[1])
    nw = max(1, int(round(box.size[0] * scale)))
    nh = max(1, int(round(box.size[1] * scale)))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.paste(resized, ((canvas - nw) // 2, (canvas - nh) // 2), resized)
    return out


def sources() -> list[Path]:
    found: list[Path] = []
    for path in sorted(SRC.iterdir()) if SRC.is_dir() else []:
        if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
            found.append(path)
    return found


def main() -> None:
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


if __name__ == "__main__":
    main()