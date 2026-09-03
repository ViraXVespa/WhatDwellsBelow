"""Key whatever-magenta Imagine stills and fit them into engine sprites."""
from pathlib import Path

from PIL import Image

import plate_remap as pr
from sprite_pipeline import fit_canvas, key_to_alpha

ROOT = Path(__file__).resolve().parent.parent
SESSION = Path(
    r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
)
PLAYER = 128
PROP = 96
ORB = 48

JOBS = [
    ("6.jpg", ROOT / "assets/sprites/player/down_right.png", PLAYER),
    ("7.jpg", ROOT / "assets/sprites/player/down_left.png", PLAYER),
    ("8.jpg", ROOT / "assets/sprites/player/up_right.png", PLAYER),
    ("9.jpg", ROOT / "assets/sprites/player/up_left.png", PLAYER),
    ("2.jpg", ROOT / "assets/sprites/props/barrel.png", PROP),
    ("3.jpg", ROOT / "assets/sprites/props/pot.png", PROP),
    ("4.jpg", ROOT / "assets/sprites/props/hp_orb.png", ORB),
    ("1.jpg", ROOT / "assets/sprites/props/mana_orb.png", ORB),
]


def key_and_fit(src: Path, dest: Path, canvas: int) -> None:
    raw = Image.open(src).convert("RGBA")
    remapped, _vis, _info = pr.remap(raw)
    keyed = key_to_alpha(remapped, spill_flood=False)
    out = fit_canvas(keyed, canvas, key=False)
    dest.parent.mkdir(parents=True, exist_ok=True)
    out.save(dest)
    print(f"wrote {dest.name} {out.size}")


def main():
    for name, dest, canvas in JOBS:
        src = SESSION / name
        if not src.exists():
            raise SystemExit(f"missing {src}")
        key_and_fit(src, dest, canvas)


if __name__ == "__main__":
    main()