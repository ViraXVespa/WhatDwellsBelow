"""I2V plates: splice or single cell, exact integer nearest-neighbor scale, leave chroma.

Attack body stills (parked keyframe pipeline): tools/attack_keyframes.py
when the User resumes that job. This file stays I2V + overlay prompts.
"""
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

# Shared camera / plate / identity. Keep this short so later lines still land.
_PROMPT_HEAD = """2D pixel-art sprite. {action} in place, as if on an invisible treadmill. No machine. Stay in this still's slot.

{facing_lock}

First frame is this still. Keep this still's costume, hair, and colors.

{identity_lock}

Smooth even motion. Locked camera. Flat #FF00FF. No new shadows.
"""

_PROMPT_HEAD_FEMALE_UP = """2D pixel-art sprite. {action} in place, as if on an invisible treadmill. No machine. Stay in this still's slot.

{facing_lock}

First frame is this still. Keep this still's costume, hair, and colors. Do not add garments.

{identity_lock}

Smooth even motion. Locked camera. Flat #FF00FF. No new shadows.
"""

# One-shots are planted. Treadmill / marching language makes the figure walk or run.
_PROMPT_HEAD_ONESHOT = """2D pixel-art sprite. {action} in place. Feet planted. Do not walk. Do not run. Stay in this still's slot.

{facing_lock}

First frame is this still. Keep this still's costume, hair, and colors.

{identity_lock}

Smooth even motion. Locked camera. Flat #FF00FF. No new shadows.
"""

_PROMPT_HEAD_ONESHOT_FEMALE_UP = """2D pixel-art sprite. {action} in place. Feet planted. Do not walk. Do not run. Stay in this still's slot.

{facing_lock}

First frame is this still. Keep this still's costume, hair, and colors. Do not add garments.

{identity_lock}

Smooth even motion. Locked camera. Flat #FF00FF. No new shadows.
"""

LOOP_PROMPT = (
    _PROMPT_HEAD
    + """
Loop. Start and end on this still.

{motion}
"""
)

LOOP_PROMPT_FEMALE_UP = (
    _PROMPT_HEAD_FEMALE_UP
    + """
Loop. Start and end on this still.

{motion}
"""
)

# Walk is not a looping gait for the whole clip. Pack cuts idle_to_walk / walk /
# walk_to_idle from a held idle start, the middle strides, and a held idle end.
WALK_PROMPT = (
    _PROMPT_HEAD
    + """
Hold this still first. Do not take a step on the first frames. Then walk in place, then stop. Settle back onto this still and hold it. The first frames and the last frames are idle.

{motion}
"""
)

WALK_PROMPT_FEMALE_UP = (
    _PROMPT_HEAD_FEMALE_UP
    + """
Hold this still first. Do not take a step on the first frames. Then walk in place, then stop. Settle back onto this still and hold it. The first frames and the last frames are idle.

{motion}
"""
)

ONESHOT_PROMPT = (
    _PROMPT_HEAD_ONESHOT
    + """
One action. Start on this still. Finish, then hold. Do not loop.

{motion}
"""
)

ONESHOT_PROMPT_FEMALE_UP = (
    _PROMPT_HEAD_ONESHOT_FEMALE_UP
    + """
One action. Start on this still. Finish, then hold. Do not loop.

{motion}
"""
)

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
        "Rear silhouette matches this still. "
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
        "Rear silhouette matches this still. "
        "This is marching in place in that three-quarter. Full back, full front, or full profile is the wrong shot."
    ),
    "up_right": (
        "Three-quarter back toward Up-Right the entire clip, copied from this still. More back than face. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "Rear silhouette matches this still. "
        "This is marching in place in that three-quarter. Full back, full front, or full profile is the wrong shot."
    ),
}

# One-shots keep the same view as the still, with planted feet. No marching.
FACING_LOCK_PLANTED = {
    "down": (
        "Square front view the entire clip, copied from this still. Eyes, nose, chest, and belt buckle face the camera. "
        "Toes point at the viewer. Both shoulders the same width. Head on the center line. No tilt. "
        "Feet stay planted. Do not walk or run. Both ears visible. Three-quarter or a lean is the wrong shot."
    ),
    "up": (
        "Square back view the entire clip, copied from this still. Back of the head, rear of the armor, and heels face the camera. "
        "Both shoulders the same width. Head on the center line. No tilt. "
        "Rear silhouette matches this still. "
        "Feet stay planted. Do not walk or run. Face-on front view is the wrong shot."
    ),
    "left": (
        "Strict left profile the entire clip, copied from this still. Nose, chest, and toes point at the left edge. "
        "One ear, one shoulder silhouette. Head on the center line. No tilt toward the camera. "
        "Feet stay planted. Do not walk or run. Front view or a three-quarter is the wrong shot."
    ),
    "right": (
        "Strict right profile the entire clip, copied from this still. Nose, chest, and toes point at the right edge. "
        "One ear, one shoulder silhouette. Head on the center line. No tilt toward the camera. "
        "Feet stay planted. Do not walk or run. Front view or a three-quarter is the wrong shot."
    ),
    "down_left": (
        "Three-quarter front toward Down-Left the entire clip, copied from this still. More face than back. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "Feet stay planted. Do not walk or run. Full front, full profile, or back view is the wrong shot."
    ),
    "down_right": (
        "Three-quarter front toward Down-Right the entire clip, copied from this still. More face than back. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "Feet stay planted. Do not walk or run. Full front, full profile, or back view is the wrong shot."
    ),
    "up_left": (
        "Three-quarter back toward Up-Left the entire clip, copied from this still. More back than face. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "Rear silhouette matches this still. "
        "Feet stay planted. Do not walk or run. Full back, full front, or full profile is the wrong shot."
    ),
    "up_right": (
        "Three-quarter back toward Up-Right the entire clip, copied from this still. More back than face. "
        "Keep this same three-quarter. Head on the center line. No tilt off the still. "
        "Rear silhouette matches this still. "
        "Feet stay planted. Do not walk or run. Full back, full front, or full profile is the wrong shot."
    ),
}

# Player-character identity. Male and female have different styling; do not share outfit lines.
# female_up omits neckband language: the locked Up still has no visible neckband.
IDENTITY_LOCK = {
    "male": (
        "Male player character copied from this still. Short messy brown hair. Brown leather armor with metal shoulder plates. "
        "A short green neckband worn only around the neck, same bulk as this still. Hands empty. No weapon. No tool."
    ),
    "female": (
        "Female player character copied from this still. "
        "Long dark wavy hair hangs loose from the scalp down the back in one sheet, same hang as this still. "
        "A little bounce with the step. Hair stays together. "
        "A small braid lies along the crown of the scalp only. That is hair on the top of the head, not a worn circlet. "
        "Hair is not tied. Ends hang free. "
        "Burgundy fitted armor, dark trousers, brown boots. "
        "A short green neckband worn only around the neck, same bulk as this still. Hands empty. No weapon. No tool."
    ),
    "female_up": (
        "Female player character copied from this still. "
        "Loose dark hair, same shape as this still. Light bounce only. "
        "Burgundy armor, dark trousers, brown boots. Hands empty."
    ),
}

DISPEL_IDENTITY_TAIL = (
    "Hands start empty. The only prop this clip may grow is one small ritual knife. "
    "No axe, staff, bow, pick, or hatchet."
)

# idle_to_walk / walk_to_idle are pack cuts from the walk I2V, not their own clips.
ACTION_ALIAS = {
    "idle_to_walk": "walk",
    "walk_to_idle": "walk",
    "atk_great_axe": "attack_great_axe",
    "atk_staff": "attack_staff",
    "atk_longbow": "attack_longbow",
    "spc_great_axe": "special_great_axe",
    "spc_staff": "special_staff",
    "spc_longbow": "special_longbow",
}

# Prompt-head label. Do not put a weapon or tool name in the I2V first line.
ACTION_LABEL = {
    "idle": "idle",
    "walk": "walk",
    "attack_great_axe": "two-hand arc",
    "attack_staff": "short poke",
    "attack_longbow": "aim and loose",
    "special_great_axe": "two-hand plant",
    "special_staff": "hand snap",
    "special_longbow": "aim and pulse",
    "gather_pickaxe": "two-hand arc",
    "gather_hatchet": "side chop",
    "death": "death",
    "dispel": "ritual end",
}

# Browser name `gather` has no tool suffix. Regen writes both tool sheets.
GATHER_KEYS = ("gather_pickaxe", "gather_hatchet")

LOOP_ACTIONS = frozenset({"idle", "walk"})

# Body I2V is kinematics only. Overlay stills add the gear later.
# Do not name axe, staff, bow, pick, hatchet, haft, shaft, string, or arrow here.
# Two-hand classes keep the palms apart so the model does not fill the gap with a blob.
_HANDS_APART = (
    "Palms stay open and empty. The two hands stay apart. "
    "Flat #FF00FF plate must stay visible between the palms the whole clip. "
    "The palms do not touch. The palms do not cup, clap, or close on a shape. "
    "Do not grow a disc, swirl, orb, bar, or any other object between the hands."
)

_MOTION_TWO_HAND_ARC = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    f"{_HANDS_APART} "
    "Feet stay under the hips. Do not step toward the camera or slide off the still's center line. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty and apart at the rest pose. "
    "2) Coil: both arms rise as a pair. The hands stay separated with plate between them. Torso coils. Keep this facing. "
    "3) Swing: a single heavy two-arm swing through the front of the silhouette. Knees bend. "
    "Shoulders rotate. The hands travel as a pair and keep the gap. One swing only. "
    "4) Follow-through: the swing finishes past the front. Torso unwinds. Do not spin or travel. The gap stays open. "
    "5) Recover: hands and weight return to this still. Hold the still so a cut on the last frame is clean."
)

_MOTION_TWO_HAND_ARC_DOUBLE = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    f"{_HANDS_APART} "
    "In-place gather. Feet stay under the hips. Do not travel. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty and apart at the rest pose. "
    "2) Coil: both arms rise as a pair over the shoulder. The hands stay separated with plate between them. "
    "Torso coils. Keep this facing. "
    "3) Beat: a downward two-arm beat onto a point just in front of the toes. Knees bend on impact. "
    "One clear hit. Then a second hit with the same motion so the gather cycle reads. The gap stays open on both hits. "
    "4) After the second hit, do not start a third. "
    "5) Recover: hands and weight return to this still. Hold the still so a cut on the last frame is clean."
)

_MOTION_TWO_HAND_PLANT = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    f"{_HANDS_APART} "
    "Plant in place. Feet stay under the hips. Do not travel. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty and apart at the rest pose. "
    "2) Wind-up: both arms rise high as a pair. The hands stay separated with plate between them. "
    "Knees bend. Torso coils. A readable pause. Keep this facing. Do not hop. "
    "3) Plant: both empty hands drive straight down onto the baseline in front of the toes and stay apart. "
    "Weight drops into the plant. One beat only. "
    "4) Shock: a short hold on the planted pose so the hit reads. No second plant. The gap stays open. "
    "5) Recover: hands and weight return to this still. Hold the still so a cut on the last frame is clean."
)

_MOTION_SHORT_POKE = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    "Palms stay empty. Hands stay close but not touching. Plate must stay visible between the palms. "
    "Do not grow a disc, swirl, orb, bar, or any other object between the hands. "
    "Compact. Short reach. Feet stay planted under the hips. Do not walk. Do not run. Do not punch. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty at the rest pose. "
    "2) Ready: both hands rise near the ribs and stay slightly apart. A small coil. Keep this facing. "
    "3) Strike: one short two-arm poke along this still's facing. Elbows stay close. Not a fist punch. One beat only. "
    "4) Recoil: the empty hands spring back a little after the poke. The gap stays open. "
    "5) Recover: hands and weight return to this still. Hold the still so a cut on the last frame is clean."
)

_MOTION_HAND_SNAP = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    "The flash is later VFX. This clip is only the body. Feet stay under the hips. Do not travel. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty at the rest pose. "
    "2) Wind-up: both hands rise. The lead hand lifts toward the facing. A short charge pose. Keep this facing. "
    "3) Release: the lead hand snaps forward along the facing. One beat only. "
    "4) Follow-through: arms settle a little after the snap. No second snap. "
    "5) Recover: hands and weight return to this still. Hold the still so a cut on the last frame is clean."
)

_MOTION_AIM_LOOSE = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    "Feet stay planted under the hips. Do not walk. Do not run. The motion is in place. "
    "The lead arm aims along this still's facing. If this still is square front, that arm points at the camera; "
    "a side-on stance toward the left or right edge is the wrong shot. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty at the rest pose. "
    "2) Raise: the rear hand rises to the chest or cheek. The lead arm extends along the facing. "
    "Torso turns only as far as this still's view already allows. Keep this facing. "
    "3) Hold: a short hold at the cheek or chest. Shoulders stay level. No lean off the center line. "
    "4) Pulse: the rear hand eases forward a little. The lead arm stays extended. One pulse only. "
    "5) Recover: both arms drop back to this still. Hold the still so a cut on the last frame is clean."
)

_MOTION_AIM_PULSE = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    "Feet stay planted under the hips. Do not travel. Several pulses, one stance. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty at the rest pose. "
    "2) First raise: rear hand to the cheek or chest, lead arm along the facing. Keep this facing. "
    "3) Fan: two or three quick raise-and-pulse beats from that same stance. Each pulse is a small "
    "rear-hand release. The body does not step or spin between pulses. "
    "4) Last pulse: one final release, then the arms stop. "
    "5) Recover: both arms drop back to this still. Hold the still so a cut on the last frame is clean."
)

_MOTION_SIDE_CHOP = (
    "Unarmed body. Hands empty the whole clip. No new props at any point. "
    "Palms stay empty. If both hands rise, they stay apart with plate visible between them. "
    "Do not grow a disc, swirl, orb, bar, or any other object in the hands. "
    "In-place gather. Feet stay under the hips. Do not travel. "
    "1) Idle: this still. Weight even. Both feet planted. Hands empty at the rest pose. "
    "2) Lift: the striking hands rise to the side. Torso coils. Keep this facing. "
    "3) Chop: a side or diagonal chop onto a point just in front of the toes. Knees bend on impact. "
    "One clear hit. Then a second hit with the same motion so the gather cycle reads. "
    "4) After the second hit, do not start a third. "
    "5) Recover: hands and weight return to this still. Hold the still so a cut on the last frame is clean."
)

MOTION = {
    "idle": "Easy breath and weight shift only. Stay on the still pose and the still facing. Loop.",
    "walk": (
        "Walk in place. Small steps. Knees bend. "
        "Arms stay close to the ribs and move only a little, opposite the feet. "
        "1) Idle hold: this still. Both feet planted. Weight even. A brief pause. Do not lift a foot yet. "
        "2) Idle into walk: after that pause, one foot lifts first. Keep this facing. "
        "3) Walk: a few clear in-place strides. Passing step then plant. Stay in this slot. "
        "4) Walk into idle: strides shorten and stop. The last plant is the other foot from the one that started. "
        "Weight evens. The pose returns to this still. Do not freeze mid-stride. "
        "5) Hold this still until the clip ends. Last frame is this idle still, both feet planted."
    ),
    "attack_great_axe": _MOTION_TWO_HAND_ARC,
    "attack_staff": _MOTION_SHORT_POKE,
    "attack_longbow": _MOTION_AIM_LOOSE,
    "special_great_axe": _MOTION_TWO_HAND_PLANT,
    "special_staff": _MOTION_HAND_SNAP,
    "special_longbow": _MOTION_AIM_PULSE,
    "gather_pickaxe": _MOTION_TWO_HAND_ARC_DOUBLE,
    "gather_hatchet": _MOTION_SIDE_CHOP,
    "death": (
        "Unarmed body dying in place. Hands stay empty. Do not spawn a prop, a grave, or blood. "
        "No red spray. No puddle. No gore. The engine draws a blood pool later. This clip is only the body. "
        "Keep this still's facing until the figure is down. Do not travel off the slot. "
        "1) Idle: this still. Weight even. Both feet planted. "
        "2) Break: knees buckle. Torso folds. Arms go slack. The facing of the head and chest stays the still's facing "
        "as long as the figure is upright. "
        "3) Fall: a short collapse onto the baseline inside this still's slot. No spin off camera. "
        "4) Down: the figure is on the plate, collapsed. Hold that down pose. Do not get up. Do not loop. "
        "5) Hold the final down frame so a cut there is clean."
    ),
    "dispel": (
        "Ritual seppuku in place. This is a chosen end, not a hit reaction and not a vanish. "
        "The only prop is one small knife. Do not spawn any other prop, cape, or altar. "
        "No blood. No spray. No puddle. No gore. The engine draws a blood pool later. This clip is only the body and the knife. "
        "Keep this still's facing the whole time. Feet stay in this still's slot. Do not travel. Take the time the ritual needs. "
        "1) Idle: this still. Weight even. Both feet planted. Hands empty. "
        "2) Draw: one hand brings out a small knife. A short pause so the knife reads. Keep this facing. "
        "3) Kneel: the figure drops to a kneel or seated fold on the baseline, still centered. The knife stays in hand. "
        "4) Cut: a single abdominal cut with that knife. One beat. No second stab. No decapitation. "
        "5) Collapse: the figure folds forward onto the plate and goes still. Hold the down pose. "
        "Do not get up. Do not fade the figure into magenta. Do not loop. Hold the final down frame so a cut there is clean."
    ),
}

# Overlay stills: Grok image-edit ONTO an accepted unarmed body frame.
# Mask the grip corridor. Do not ask the editor to delete a baked prop.
OVERLAY_ALIAS = {
    "axe": "great_axe",
    "great-axe": "great_axe",
    "atk_great_axe": "great_axe",
    "attack_great_axe": "great_axe",
    "spc_great_axe": "great_axe",
    "special_great_axe": "great_axe",
    "lightning_staff": "staff",
    "atk_staff": "staff",
    "attack_staff": "staff",
    "spc_staff": "staff",
    "special_staff": "staff",
    "bow": "longbow",
    "atk_longbow": "longbow",
    "attack_longbow": "longbow",
    "spc_longbow": "longbow",
    "special_longbow": "longbow",
    "pick": "pickaxe",
    "gather_pickaxe": "pickaxe",
    "axe_tool": "hatchet",
    "gather_hatchet": "hatchet",
    "carry": "rest",
    "idle": "rest",
}

OVERLAY_TOOL = {
    "great_axe": (
        "one two-handed great axe, long wood haft, single wide metal head, "
        "same chunky pixel style and palette as this still"
    ),
    "staff": (
        "one short two-handed lightning staff, wood shaft, small metal cap, "
        "same chunky pixel style and palette as this still"
    ),
    "longbow": (
        "one longbow, simple wood curve, string drawn to the grip, "
        "same chunky pixel style and palette as this still"
    ),
    "pickaxe": (
        "one two-handed pickaxe, wood haft, pointed metal head, "
        "same chunky pixel style and palette as this still"
    ),
    "hatchet": (
        "one short hatchet, wood haft, flat chopping head, "
        "same chunky pixel style and palette as this still"
    ),
    "rest": (
        "one carried tool in a rest / shoulder or hip carry that matches this still's idle grip, "
        "same chunky pixel style and palette as this still"
    ),
}


def normalize_overlay(tool: str) -> str:
    key = tool.lower().strip().replace("-", "_").replace(" ", "_")
    key = OVERLAY_ALIAS.get(key, key)
    if key not in OVERLAY_TOOL:
        known = ", ".join(sorted(OVERLAY_TOOL))
        raise ValueError(f"unknown overlay tool {tool!r}; expected one of: {known}")
    return key


def build_overlay_prompt(facing: str, tool: str) -> str:
    key = normalize_overlay(tool)
    face = facing_label(facing)
    return (
        "2D pixel-art image edit of this still. Keep this still's body, face, hair, armor, "
        "pose, facing, and colors exactly. Do not redraw the figure. Do not change the pose.\n\n"
        f"Facing stays {face}, copied from this still.\n\n"
        "Paint only inside the empty hands and the open corridor those hands could hold. "
        "Do not edit pixels outside that grip corridor. Do not add garments, limbs, or shadows.\n\n"
        f"Add {OVERLAY_TOOL[key]}, registered to this still's empty-hand grip.\n\n"
        "Leave the flat #FF00FF plate opaque. No anti-aliasing. No new background."
    )


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


def facing_lock(name: str, planted: bool = False) -> str:
    key = facing_key(name)
    table = FACING_LOCK_PLANTED if planted else FACING_LOCK
    if key not in table:
        key = "down"
    return table[key]


def gender_key(name: str) -> str:
    g = name.strip().lower()
    if g in ("male", "female"):
        return g
    return "male"


def infer_gender(src: Path | None, explicit: str) -> str:
    g = explicit.strip().lower()
    if g in ("male", "female"):
        return g
    if src is not None:
        n = src.name.lower()
        if "female" in n:
            return "female"
        if "male" in n:
            return "male"
    return "male"


def is_female_up(gender: str, facing: str) -> bool:
    return gender_key(gender) == "female" and facing_key(facing) == "up"


def identity_lock(gender: str, facing: str = "down") -> str:
    if is_female_up(gender, facing):
        return IDENTITY_LOCK["female_up"]
    return IDENTITY_LOCK[gender_key(gender)]


def normalize_action(action: str) -> str:
    key = action.lower().strip().replace("-", "_").replace(" ", "_")
    return ACTION_ALIAS.get(key, key)


def motion_keys(action: str) -> list[str]:
    key = normalize_action(action)
    if key == "gather":
        return list(GATHER_KEYS)
    if key in MOTION:
        return [key]
    known = ", ".join(sorted(MOTION) + ["gather"])
    raise ValueError(f"unknown I2V action {action!r}; expected one of: {known}")


def _identity_for(key: str, gender: str, facing: str) -> str:
    text = identity_lock(gender, facing)
    if key != "dispel":
        return text
    return text.replace(
        "Hands empty. No weapon. No tool.",
        DISPEL_IDENTITY_TAIL,
    ).replace(
        "Hands empty.",
        DISPEL_IDENTITY_TAIL,
    )


def _strip_wrap_language(text: str) -> str:
    cuts = (
        "One short green cloth wrapped all the way around the neck as a close collar. ",
        "A short green neckband worn only around the neck, same bulk as this still. ",
        "It stays on the neck. It does not hang down onto the armor. Same bulk as this still. ",
        "From behind the hair covers that collar. ",
        "From behind, that same collar only. ",
        "The green collar stays on the neck and does not hang onto the armor. "
        "Only cloth already on this still may shift. Do not spawn new cloth. ",
        "The hip belt buckle stays glued to the still's vertical center line. ",
    )
    out = text
    for cut in cuts:
        out = out.replace(cut, "")
    return out


def _format_one(facing: str, key: str, gender: str) -> str:
    female_up = is_female_up(gender, facing)
    if key == "walk":
        template = WALK_PROMPT_FEMALE_UP if female_up else WALK_PROMPT
    elif key in LOOP_ACTIONS:
        template = LOOP_PROMPT_FEMALE_UP if female_up else LOOP_PROMPT
    else:
        template = ONESHOT_PROMPT_FEMALE_UP if female_up else ONESHOT_PROMPT
    planted = key not in LOOP_ACTIONS and key != "walk"
    text = template.format(
        action=ACTION_LABEL.get(key, key.replace("_", " ")),
        facing_lock=facing_lock(facing, planted=planted),
        identity_lock=_identity_for(key, gender, facing),
        motion=MOTION[key],
    )
    if female_up:
        return _strip_wrap_language(text)
    return text


def build_prompt(
    facing: str,
    action: str,
    colors: list[str],
    test: bool = False,
    gender: str = "male",
) -> str:
    keys = motion_keys(action)
    chunks: list[str] = []
    for key in keys:
        chunk = _format_one(facing, key, gender)
        if len(keys) > 1:
            chunk = f"# {key}\n\n{chunk}"
        chunks.append(chunk)
    body = "\n\n---\n\n".join(chunks)
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
    overlay: str = "",
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
    out: dict = {
        "path": str(path),
        "src_size": list(raw.size),
        "out_size": list(plate.size),
        "scale": factor,
        "action": action,
    }
    if overlay:
        overlay_key = normalize_overlay(overlay)
        overlay_path = dest_dir / f"overlay_{overlay_key}_{facing}.txt"
        overlay_path.write_text(build_overlay_prompt(facing, overlay_key), encoding="utf-8")
        out["overlay"] = overlay_key
        out["overlay_prompt"] = str(overlay_path)
    return out


def export_bible(
    src: Path,
    dest_dir: Path,
    factor: int,
    action: str,
    test: bool = False,
    gender: str = "male",
    overlay: str = "",
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
    if overlay:
        overlay_key = normalize_overlay(overlay)
        out["overlay"] = overlay_key
        for name in BODY_CELLS:
            overlay_path = dest_dir / f"overlay_{overlay_key}_{name}.txt"
            overlay_path.write_text(build_overlay_prompt(name, overlay_key), encoding="utf-8")
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
    p.add_argument(
        "--action",
        default="walk",
        help=(
            "I2V motion key: walk, idle, attack_great_axe, attack_staff, attack_longbow, "
            "special_great_axe, special_staff, special_longbow, gather (writes pickaxe and hatchet), "
            "gather_pickaxe, gather_hatchet, death, dispel. Attack / special / gather prompts "
            "are unarmed body classes; they do not name the gear."
        ),
    )
    p.add_argument(
        "--overlay",
        default="",
        help=(
            "Also write an image-edit overlay prompt for this tool: great_axe, staff, longbow, "
            "pickaxe, hatchet, rest. Paint-on only. Do not use this as an I2V action."
        ),
    )
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
            args.cell,
            args.dest,
            args.scale,
            args.facing,
            args.action,
            test=args.test,
            gender=gender,
            overlay=args.overlay,
        )
    else:
        written = export_bible(
            args.bible,
            args.dest,
            args.scale,
            args.action,
            test=args.test,
            gender=gender,
            overlay=args.overlay,
        )
    print(json.dumps(written, indent=2))
    print()
    print(build_prompt(args.facing, args.action, [], test=args.test, gender=gender))
    if args.overlay:
        print()
        print("# overlay")
        print()
        print(build_overlay_prompt(args.facing, args.overlay))


if __name__ == "__main__":
    main()