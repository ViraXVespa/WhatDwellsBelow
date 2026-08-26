from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sprite_pipeline import fit_canvas, quantize_palette, range_key
from PIL import Image

IMG = Path(r"C:\Users\Vira\.grok\sessions\C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a03e55-f390-7750-ab00-b30f1e6ba566\images")
KEYS = ["up", "down", "left", "right", "up_left", "up_right", "down_left", "down_right"]


def save(src: Path, dest: Path) -> None:
    im = range_key(Image.open(src))
    im = quantize_palette(fit_canvas(im, 128))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    print("wrote", dest)


def main() -> None:
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
    Image.open("assets/sprites/player/male/equip_great_axe_right.png").transpose(
        Image.FLIP_LEFT_RIGHT
    ).save("assets/sprites/player/male/equip_great_axe_left.png")
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


if __name__ == "__main__":
    main()
