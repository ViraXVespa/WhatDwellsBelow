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
# After 400% NN, pad #FF00FF so lifted feet / swinging arms stay on-plate.
# Fraction of the figure's bounding-box height, applied to every side that is short.
PAD_FRAC = 0.22
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

# Web-browser Imagine tests only. Grok Build I2V already knows it is video.
TEST_PREFIX = (
    "Generate a video. Image-to-video from this still. Do not output a still image. "
    "Make the clip as long as it needs to be to finish the motion below. No fixed duration.\n\n"
)

PROMPT = """2D game sprite on a treadmill. {action} in place. Engine slides this sprite later. The figure never travels.

{facing_lock}

The first frame already matches this still. Do not rotate into the pose. Do not find the facing later in the clip.

{identity_lock}

Joints should bend. Only cloth already on this still may shift. Do not spawn new cloth. Volume in the limbs. Not paper cutouts sliding on a hinge.

Locked camera. No pan, zoom, or perspective change. Flat #FF00FF only.

Keep the still's colors and the still's existing form shading. Do not add lights, grades, or filters. Do not flatten the figure to a short color list.

The hip belt buckle stays glued to the still's vertical center line. Feet stay on the same baseline. Small step bounce is fine. The whole figure stays in this still's slot, including lifted feet and swinging hands. Keep every limb inside the magenta plate.

Readable compact game cycle. The clip starts and ends on this idle still so it loops.

{motion}
"""

# Game facing is a locked view copied from the still, never a travel heading.
FACING_LOCK = {
    "down": (
        "Square front view the entire clip, copied from this still. Eyes, nose, chest, and belt buckle face the camera. "
        "Toes point at the viewer. Both shoulders the same width. Head on the center line. No tilt. "
        "This is marching in place toward the camera. Both ears visible. Three-quarter or a lean is the wrong shot."
    ),
    "up": (
        "Square back view the entire clip, copied from this still. Back of the head, rear of the armor, and heels face the camera. "
        "Both shoulders the same width. Head on the center line. No tilt. "
        "This is marching in place away from the camera. Face-on front view is the wrong shot."
    ),
    "left": (
        "Strict left profile the entire clip, copied from this still. Nose, chest, and toes point at the left edge. "
        "One ear, one shoulder silhouette. Head on the center line. No tilt toward the camera. "
        "This is marching in place toward the left edge. Front view or a three-quarter is the wrong shot."
    ),
    "right": (
        "Strict right profile the entire clip, copied from this still. Nose, chest, and toes point at the right edge. "
        "One ear, one shoulder silhouette. Head on the center line. No tilt toward the camera. "
        "This is marching in place toward the right edge. Front view or a three-quarter is the wrong shot."
    ),
    "down_left": (
        "Three-quarter front toward Down-Left the entire clip, copied from this still. More face than back. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "This is marching in place in that three-quarter. Full front, full profile, or back view is the wrong shot."
    ),
    "down_right": (
        "Three-quarter front toward Down-Right the entire clip, copied from this still. More face than back. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "This is marching in place in that three-quarter. Full front, full profile, or back view is the wrong shot."
    ),
    "up_left": (
        "Three-quarter back toward Up-Left the entire clip, copied from this still. More back than face. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "This is marching in place in that three-quarter. Full back, full front, or full profile is the wrong shot."
    ),
    "up_right": (
        "Three-quarter back toward Up-Right the entire clip, copied from this still. More back than face. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "This is marching in place in that three-quarter. Full back, full front, or full profile is the wrong shot."
    ),
}

# Player-character identity. Male and female have different styling; do not share outfit lines.
IDENTITY_LOCK = {
    "male": (
        "Male player character copied from this still. Short messy brown hair. Brown leather armor with metal shoulder plates. "
        "One short green scarf wrapped at the neck only, same small size as the still. "
        "Do not add extra scarf. Do not lengthen it down the chest or back. Do not drape more cloth on the shoulders. "
        "No cape. No cloak. No second scarf. "
        "Overall proportions stay in the same ballpark as the still. No extra limbs and no redesign. Hands stay empty. No weapon. No tool."
    ),
    "female": (
        "Female player character copied from this still. Long dark wavy hair with a braid across the crown. "
        "Burgundy fitted armor with metal trim. Dark trousers and brown boots. "
        "One green scarf wrapped at the neck, same bulk as the still. "
        "Do not add extra scarf. Do not lengthen it into a cape. Do not restyle her as the male delver. "
        "No short messy hair. No brown leather chest. No extra hanging cloth. "
        "Overall proportions stay in the same ballpark as the still. No extra limbs and no redesign. Hands stay empty. No weapon. No tool."
    ),
}

MOTION = {
    "idle": "Easy breath and weight shift only. Stay on the still pose and the still facing. Loop.",
    "walk": (
        "One loop that starts and ends on this idle still. "
        "March in place. The body stays in this still's facing and on this still's center line. "
        "A stride is a plant of one foot then the other, knees bent, both feet under the hips. "
        "Arms hang by the ribs and swing a short way, opposite the legs. Hands stay near the hips. Compact arm motion, not a windmill. "
        "1) Idle: this still. Weight even. Both feet planted. "
        "2) Idle into walk: weight shifts and one foot lifts first. Keep that same facing. "
        "3) Walk: at least three clear strides in place. Each stride shows a passing (swinging foot crosses under the torso) and a plant. Stay centered. "
        "4) Walk into idle: stride shortens and stops. The last plant is the other foot from the one that started. "
        "Weight evens out and the pose returns to this still. Keep the settle. Do not freeze mid-stride. "
        "5) Idle: this still again, both feet planted, so looping the clip is seamless."
    ),
    "attack": "One swing with follow-through, then recover to the still. Keep the still's facing. Do not travel.",
    "special": "One special strike, then recover to the still. Keep the still's facing. Do not travel.",
    "gather": "In-place gather swings, then recover to the still. Keep the still's facing. Do not travel.",
    "death": "Short collapse, then hold. Keep the still's facing until the fall.",
    "dispel": "Short vanish to magenta. Keep the still's facing.",
}


def scale_nn(im: Image.Image, factor: int) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    return im.resize((w * factor, h * factor), Image.Resampling.NEAREST)


def figure_bbox(im: Image.Image) -> tuple[int, int, int, int] | None:
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    x0, y0, x1, y1 = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 16:
                continue
            if sp._dist((r, g, b), sp.KEY_RGB) <= 18.0:
                continue
            if x < x0:
                x0 = x
            if y < y0:
                y0 = y
            if x > x1:
                x1 = x
            if y > y1:
                y1 = y
    if x1 < 0:
        return None
    return (x0, y0, x1, y1)


def pad_chroma(im: Image.Image, frac: float) -> Image.Image:
    """Pad #FF00FF after NN scale. Never shrink the figure."""
    rgba = im.convert("RGBA")
    box = figure_bbox(rgba)
    if box is None or frac <= 0:
        return rgba
    x0, y0, x1, y1 = box
    w, h = rgba.size
    fig_h = max(1, y1 - y0 + 1)
    need = max(1, int(round(fig_h * frac)))
    pad_l = max(0, need - x0)
    pad_t = max(0, need - y0)
    pad_r = max(0, need - (w - 1 - x1))
    pad_b = max(0, need - (h - 1 - y1))
    if pad_l == pad_t == pad_r == pad_b == 0:
        return rgba
    out = Image.new("RGBA", (w + pad_l + pad_r, h + pad_t + pad_b), (*sp.KEY_RGB, 255))
    out.paste(rgba, (pad_l, pad_t))
    return out


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


def facing_key(name: str) -> str:
    return name.strip().lower().replace("-", "_").replace(" ", "_")


def facing_label(name: str) -> str:
    return facing_key(name).replace("_", "-").title()


def facing_lock(name: str) -> str:
    key = facing_key(name)
    if key not in FACING_LOCK:
        key = "down"
    return FACING_LOCK[key]


def gender_key(name: str) -> str:
    g = name.strip().lower()
    if g in IDENTITY_LOCK:
        return g
    return "male"


def infer_gender(src: Path | None, explicit: str) -> str:
    g = explicit.strip().lower()
    if g in IDENTITY_LOCK:
        return g
    if src is not None:
        n = src.name.lower()
        if "female" in n:
            return "female"
        if "male" in n:
            return "male"
    return "male"


def identity_lock(gender: str) -> str:
    return IDENTITY_LOCK[gender_key(gender)]


def build_prompt(
    facing: str,
    action: str,
    colors: list[str],
    test: bool = False,
    gender: str = "male",
) -> str:
    key = action.lower().strip()
    if key not in MOTION:
        key = "walk"
    body = PROMPT.format(
        action=key,
        facing_lock=facing_lock(facing),
        identity_lock=identity_lock(gender),
        motion=MOTION[key],
    )
    if test:
        return TEST_PREFIX + body
    return body


def write_palette(im: Image.Image, dest_dir: Path, extra: dict) -> list[str]:
    colors = palette_hex(im)
    payload = {"hex": colors}
    payload.update(extra)
    (dest_dir / "palette.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return colors


def export_cell(
    src: Path,
    dest_dir: Path,
    factor: int,
    facing: str,
    action: str,
    test: bool = False,
    gender: str = "male",
) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    raw = Image.open(src).convert("RGBA")
    plate = pad_chroma(scale_nn(raw, factor), PAD_FRAC)
    path = dest_dir / f"seed_i2v_{facing}_x{factor}.png"
    plate.save(path)
    write_palette(
        raw,
        dest_dir,
        {
            "source": str(src),
            "scale": factor,
            "pad_frac": PAD_FRAC,
            "src_size": list(raw.size),
            "out_size": list(plate.size),
        },
    )
    (dest_dir / f"prompt_{facing}.txt").write_text(
        build_prompt(facing, action, [], test=test, gender=gender),
        encoding="utf-8",
    )
    return {
        "path": str(path),
        "src_size": list(raw.size),
        "out_size": list(plate.size),
        "scale": factor,
        "action": action,
    }


def export_bible(
    src: Path,
    dest_dir: Path,
    factor: int,
    action: str,
    test: bool = False,
    gender: str = "male",
) -> dict:
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
        if name != "face":
            plate = pad_chroma(plate, PAD_FRAC)
        path = dest_dir / f"seed_i2v_{name}_x{factor}.png"
        plate.save(path)
        out[name] = {"path": str(path), "src_size": list(named[name].size), "out_size": list(plate.size)}
    for name in BODY_CELLS:
        (dest_dir / f"prompt_{action}_{name}.txt").write_text(
            build_prompt(name, action, [], test=test, gender=gender),
            encoding="utf-8",
        )
    return out


def main() -> None:
    p = argparse.ArgumentParser(
        description="Exact integer nearest-neighbor scale, then #FF00FF pad. No key, no 1024 fit."
    )
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--cell", type=Path, help="One splice still, same as Paint.NET 400%")
    src.add_argument("--bible", type=Path, help="Locked 3x3 Bible; split then scale each cell")
    p.add_argument("--dest", required=True, type=Path)
    p.add_argument("--scale", type=int, default=SCALE)
    p.add_argument("--facing", default="down")
    p.add_argument("--action", default="walk")
    p.add_argument(
        "--gender",
        default="",
        help="Player identity lock: male or female. Inferred from the source filename when omitted.",
    )
    p.add_argument(
        "--test",
        action="store_true",
        help="Prefix the web-browser Imagine preamble (image-to-video / no still / no fixed duration).",
    )
    args = p.parse_args()
    if args.scale < 1:
        p.error("--scale must be >= 1")
    src_path = args.cell if args.cell is not None else args.bible
    gender = infer_gender(src_path, args.gender)
    if args.cell is not None:
        written = export_cell(
            args.cell, args.dest, args.scale, args.facing, args.action, test=args.test, gender=gender
        )
    else:
        written = export_bible(args.bible, args.dest, args.scale, args.action, test=args.test, gender=gender)
    print(json.dumps(written, indent=2))
    print()
    print(build_prompt(args.facing, args.action, [], test=args.test, gender=gender))


if __name__ == "__main__":
    main()