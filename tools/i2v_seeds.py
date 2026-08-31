"""I2V plates: splice or single cell, exact integer nearest-neighbor scale, leave chroma."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import sprite_pipeline as sp  # noqa: E402

SCALE = 4
BODY_CELLS = (
    "up_left",
    "up",
    "up_right",
    "left",
    "right",
    "down_left",
    "down",
    "down_right",
)

PROMPT = """2D game sprite sheet. In-place {action}, facing {facing}. The engine moves and lights this later.

Same character as frame 1 on every frame: face, hair, green scarf, armor, palette, pixel size. Same body proportions, limb length, head size, and scale. No morph, stretch, squash, extra limbs, or redraw.

Locked ortho camera. No pan, zoom, tilt, or perspective change. Same footprint and foot baseline. Flat #FF00FF only. No ground or extra pixels.

Freeze frame-1 lighting. No new light, shade, bloom, grade, or filters.

Game-style cycle: readable, slightly exaggerated. Repeat it three times at a steady pace. Clean loop back to frame 1.

{motion}
Palette: {palette}
"""

MOTION = {
    "idle": "Small breath and weight shift only.",
    "walk": "Treadmill walk: contact, down, passing, up. Opposite arm and leg. Torso stays this facing.",
    "attack": "One swing, recover to frame 1.",
    "special": "One special strike, recover to frame 1.",
    "gather": "In-place gather swings, recover to frame 1.",
    "death": "Short collapse, then hold.",
    "dispel": "Short vanish to magenta.",
}


def scale_nn(im: Image.Image, factor: int) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    return im.resize((w * factor, h * factor), Image.Resampling.NEAREST)


def palette_hex(im: Image.Image, limit: int = 16) -> list[str]:
    rgba = im.convert("RGBA")
    counts: dict[tuple[int, int, int], int] = {}
    px = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16 or sp._dist((r, g, b), sp.KEY_RGB) <= 18.0:
                continue
            counts[(r, g, b)] = counts.get((r, g, b), 0) + 1
    ranked = sorted(counts.items(), key=lambda kv: -kv[1])[:limit]
    return [f"#{c[0]:02X}{c[1]:02X}{c[2]:02X}" for c, _n in ranked]


def facing_label(name: str) -> str:
    return name.replace("_", "-").title()


def build_prompt(facing: str, action: str, colors: list[str]) -> str:
    key = action.lower().strip()
    if key not in MOTION:
        key = "walk"
    return PROMPT.format(
        action=key,
        facing=facing_label(facing),
        palette=", ".join(colors) if colors else "frame 1",
        motion=MOTION[key],
    )


def write_palette(im: Image.Image, dest_dir: Path, extra: dict) -> list[str]:
    colors = palette_hex(im)
    payload = {"hex": colors}
    payload.update(extra)
    (dest_dir / "palette.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return colors


def export_cell(src: Path, dest_dir: Path, factor: int, facing: str, action: str) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    raw = Image.open(src).convert("RGBA")
    plate = scale_nn(raw, factor)
    path = dest_dir / f"seed_i2v_{facing}_x{factor}.png"
    plate.save(path)
    colors = write_palette(
        raw,
        dest_dir,
        {"source": str(src), "scale": factor, "src_size": list(raw.size), "out_size": list(plate.size)},
    )
    (dest_dir / f"prompt_{facing}.txt").write_text(
        build_prompt(facing, action, colors),
        encoding="utf-8",
    )
    return {
        "path": str(path),
        "src_size": list(raw.size),
        "out_size": list(plate.size),
        "scale": factor,
        "action": action,
    }


def export_bible(src: Path, dest_dir: Path, factor: int, action: str) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    raw = Image.open(src).convert("RGBA")
    named = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(raw)))
    colors = write_palette(
        raw,
        dest_dir,
        {"source": str(src), "scale": factor, "bible_size": list(raw.size)},
    )
    out: dict[str, object] = {"palette": str(dest_dir / "palette.json"), "scale": factor, "action": action}
    for name in list(BODY_CELLS) + ["face"]:
        plate = scale_nn(named[name], factor)
        path = dest_dir / f"seed_i2v_{name}_x{factor}.png"
        plate.save(path)
        out[name] = {"path": str(path), "src_size": list(named[name].size), "out_size": list(plate.size)}
    (dest_dir / "prompt_walk_down.txt").write_text(
        build_prompt("down", action, colors),
        encoding="utf-8",
    )
    return out


def main() -> None:
    p = argparse.ArgumentParser(
        description="Exact integer nearest-neighbor scale. No pad, no key, no 1024 fit."
    )
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--cell", type=Path, help="One splice still, same as Paint.NET 400%")
    src.add_argument("--bible", type=Path, help="Locked 3x3 Bible; split then scale each cell")
    p.add_argument("--dest", required=True, type=Path)
    p.add_argument("--scale", type=int, default=SCALE)
    p.add_argument("--facing", default="down")
    p.add_argument("--action", default="walk")
    args = p.parse_args()
    if args.scale < 1:
        p.error("--scale must be >= 1")
    if args.cell is not None:
        written = export_cell(args.cell, args.dest, args.scale, args.facing, args.action)
    else:
        written = export_bible(args.bible, args.dest, args.scale, args.action)
    print(json.dumps(written, indent=2))
    print()
    colors = json.loads((args.dest / "palette.json").read_text(encoding="utf-8"))["hex"]
    print(build_prompt(args.facing, args.action, colors))


if __name__ == "__main__":
    main()