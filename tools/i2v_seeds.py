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

PROMPT = """Generate a video. Image-to-video from this still. Do not output a still image. Length at least ten seconds.

2D game sprite. In-place {action}, facing {facing}. Engine moves and lights this later.

Keep this character: face, hair, green scarf, armor, pixel look. Overall proportions stay in the same ballpark as the still. No extra limbs and no redesign.

Joints should bend. Cloth and scarf can move. Volume in the limbs. Not paper cutouts sliding on a hinge.

Locked camera. No pan, zoom, or perspective change. Flat #FF00FF only.

Keep the still's colors and the still's existing form shading. Do not add lights, grades, or filters. Do not flatten the figure to a short color list.

Do not freeze on the still. After a short idle, move. Play the full sequence below more than once. Seamless loop. Do not aim at a frame count.

Stay in the same vertical slot and on the same foot baseline so the game can slide this sprite. Small step bounce is fine. Do not drift up, down, or off-center.

Readable game cycle, a little exaggeration.

{motion}
"""

MOTION = {
    "idle": "Easy breath and weight shift only. Stay on the still pose. Loop.",
    "walk": (
        "Full in-place walk sequence, then repeat it seamlessly for the whole clip. "
        "Three passings per run. A passing is both feet crossing in the center of the body. "
        "1) Idle: standing pose from the still, weight even, both feet planted. "
        "2) Idle into walk: weight shifts, first foot lifts. Do not skip this. "
        "First run leads with the left foot. Next run leads with the right foot. Alternate every run. "
        "3) Passing 1: swinging foot goes through the center; feet cross; opposite arm comes forward. "
        "4) Plant: that swinging foot goes down. Weight on the planted foot. Rear foot leaves. "
        "5) Passing 2: feet cross in the center again, opposite direction from passing 1. Opposite arm and opposite leg. "
        "6) Plant: the other foot goes down. "
        "7) Passing 3: feet cross in the center a third time, opposite direction from passing 2. "
        "8) Walk into idle: stride shortens, last foot plants, weight evens out. "
        "This settle uses the opposite leading leg from the idle-into-walk that started this run. "
        "If the run led with the left foot, stop from a right-foot lead. If it led with the right foot, stop from a left-foot lead. "
        "Both stop-leads must appear in the clip so a game stop can use either foot. "
        "9) Idle: back to the still pose, both feet planted. "
        "Then repeat from idle with no pause, no freeze, and the other lead foot. "
        "If the clip does not show all three center-crossings, both plants, and walk-to-idle on both leads, it is incomplete."
    ),
    "attack": "One swing with follow-through, then recover to the still.",
    "special": "One special strike, then recover to the still.",
    "gather": "In-place gather swings, then recover to the still.",
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
    write_palette(
        raw,
        dest_dir,
        {"source": str(src), "scale": factor, "src_size": list(raw.size), "out_size": list(plate.size)},
    )
    (dest_dir / f"prompt_{facing}.txt").write_text(
        build_prompt(facing, action, []),
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
    write_palette(
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
        build_prompt("down", action, []),
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
    print(build_prompt(args.facing, args.action, []))


if __name__ == "__main__":
    main()