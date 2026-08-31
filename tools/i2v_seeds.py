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

PROMPT = """Animate this exact pixel-art character in place as a {action} cycle, facing {facing}.

Keep the same overall character design, face, hair, armor, green scarf, proportions, palette, and sprite style from the first frame. Do not redesign, repaint, recolor, simplify, smooth, or invent new details.

Locked camera, no pan, no tilt, no zoom, no rotation. Character stays the same scale and stays inset from every edge. Feet stay on the same baseline.

Solid flat pure magenta #FF00FF background only. No ground plane, no floor, no detached shadow, no particles, no debris, no outline glow, no extra pixels outside the character.

Face stays fully visible on every frame: both eyes, brows, nose, mouth, and hairline. No blacked-out face, no dark smears over the head, no missing facial features, no face blur, no censorship bars, no face restoration, no photoreal skin.

LOOK LOCK (do not break):
- Keep the exact lighting of the first frame. Flat even sprite lighting only.
- Do not add lights, rim light, backlight, point lights, bounce light, or a new key/fill.
- Do not add shading, ambient occlusion, bloom, glow, specular pop, or photographic rendering.
- Do not add filters or post: no color grade, no saturation/contrast/exposure change, no LUT, no vignette, no sharpen, no blur, no depth of field, no chromatic aberration, no film grain, no compression noise, no anti-aliasing.
- Do not smooth or upsample-redraw the pixels. Keep large visible square pixels and the first-frame colors.

Limited palette including: {palette}

Motion only: {motion}
"""

MOTION = {
    "idle": "tiny breathing idle; weight shifts slightly; no locomotion; loop cleanly",
    "walk": "in-place walk cycle with a clear passing / leg-crossover pose; both legs and arms cross front and back; loop cleanly",
    "attack": "one melee swing and recover to the start pose; keep the facing; loop is not required",
    "special": "one special-weapon strike and recover; keep the facing",
    "gather": "in-place gathering swings at a node in front of the feet; keep the facing",
    "death": "short collapse, then hold the final pose",
    "dispel": "short dissolve / vanish, then hold empty magenta",
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
        palette=", ".join(colors) if colors else "the first-frame palette",
        motion=MOTION[key],
    )


def write_palette(im: Image.Image, dest_dir: Path, extra: dict) -> list[str]:
    colors = palette_hex(im)
    payload = {"hex": colors}
    payload.update(extra)
    (dest_dir / "palette.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return colors


def export_cell(src: Path, dest_dir: Path, factor: int, facing: str) -> dict:
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
        build_prompt(facing, "walk", colors),
        encoding="utf-8",
    )
    return {
        "path": str(path),
        "src_size": list(raw.size),
        "out_size": list(plate.size),
        "scale": factor,
    }


def export_bible(src: Path, dest_dir: Path, factor: int) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    raw = Image.open(src).convert("RGBA")
    named = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(raw)))
    colors = write_palette(
        raw,
        dest_dir,
        {"source": str(src), "scale": factor, "bible_size": list(raw.size)},
    )
    out: dict[str, object] = {"palette": str(dest_dir / "palette.json"), "scale": factor}
    for name in list(BODY_CELLS) + ["face"]:
        plate = scale_nn(named[name], factor)
        path = dest_dir / f"seed_i2v_{name}_x{factor}.png"
        plate.save(path)
        out[name] = {"path": str(path), "src_size": list(named[name].size), "out_size": list(plate.size)}
    (dest_dir / "prompt_walk_down.txt").write_text(
        build_prompt("down", "walk", colors),
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
        written = export_cell(args.cell, args.dest, args.scale, args.facing)
    else:
        written = export_bible(args.bible, args.dest, args.scale)
    print(json.dumps(written, indent=2))
    print()
    colors = json.loads((args.dest / "palette.json").read_text(encoding="utf-8"))["hex"]
    print(build_prompt(args.facing, args.action, colors))


if __name__ == "__main__":
    main()