#!/usr/bin/env python3
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sprite_pipeline import fit_canvas, quantize_palette, range_key
from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import match_keyed_region as matcher
from imglib import geom

ROOT = Path(__file__).resolve().parent.parent

IMG = agent_log.grok_sessions(r"C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a03e55-f390-7750-ab00-b30f1e6ba566\images")
KEYS = ["up", "down", "left", "right", "up_left", "up_right", "down_left", "down_right"]


def save(src: Path, dest: Path) -> None:
    use = matcher.resolve_source(ROOT / dest, src)
    if use is None:
        raise SystemExit(f"missing source for {dest}")
    im = range_key(Image.open(use))
    im = quantize_palette(fit_canvas(im, 128))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    print("wrote", dest)


def _run() -> None:
    jobs = {
        "assets/sprites/player/male/equip_great_axe_down.png": "15.jpg",
        "assets/sprites/player/male/equip_staff_down.png": "9.jpg",
        "assets/sprites/player/male/equip_longbow_down.png": "16.jpg",
        "assets/sprites/player/male/equip_great_axe_right.png": "17.jpg",
        "assets/sprites/player/male/equip_great_axe_up.png": "20.jpg",
        "assets/sprites/player/female/equip_great_axe_down.png": "14.jpg",
        "assets/sprites/player/female/equip_staff_down.png": "18.jpg",
        "assets/sprites/player/female/equip_longbow_down.png": "19.jpg",
        "assets/fx/dummy.png": "12.jpg",
        "assets/fx/arrow.png": "11.jpg",
        "assets/fx/lightning.png": "10.jpg",
        "assets/fx/crack.png": "13.jpg",
    }
    for dest, src in jobs.items():
        save(IMG / src, Path(dest))
    geom.flip(Image.open("assets/sprites/player/male/equip_great_axe_right.png")).save(
        "assets/sprites/player/male/equip_great_axe_left.png"
    )
    for gender in ["male", "female"]:
        for wpn in ["great_axe", "staff", "longbow"]:
            down = Path(f"assets/sprites/player/{gender}/equip_{wpn}_down.png")
            if not down.exists():
                continue
            src = Image.open(down)
            for k in KEYS:
                p = Path(f"assets/sprites/player/{gender}/equip_{wpn}_{k}.png")
                if not p.exists():
                    src.save(p)
                    print("fill", p)


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("pack_p2_art", 'Key and fit Phase 2 equipment and fx stills from a Grok session into assets/sprites and assets/fx.', _run, argv, globals())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
