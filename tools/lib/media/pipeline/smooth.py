"""T-pose stills for the mannequin mesh. Smooth sculpt, not the pixel plate.

The bind pose is a T-pose shared by characters and enemies. Idle is a later
animation. The standing pixel plates stay the pixel lock. This graph is text
only, so those plates are not copied into the mesh source.
"""
from __future__ import annotations

_SKIN = (
    "Large rounded head, short legs, chibi game proportions. "
    "Smooth continuous skin, like a clean sculpt, not a pixel drawing and not a voxel. "
    "The head is a rounded oval with no ears. Ears are a later piece. "
    "The sides of the head are a smooth unbroken oval, with no ear lobes and no ear bumps. "
    "A female chest with breasts. A narrow waist and an hourglass figure. "
    "The abdomen is slim. The hips are wider than the waist. "
    "The torso is a continuous curve, not a flat plane and not a thick tube. "
    "Bald. No hair, no circlet, no neckband, no armor, no pants, no boots. "
    "Even skin tone, flat magenta background, no text, no border."
)
_FACE = "Eyes may stay as simple marks. No eyebrows, no nose, no mouth, no lips. "
_POSE = (
    "T-pose. Both arms are straight out to the sides, horizontal, elbows locked, palms down. "
    "The thighs are apart with a clear gap. The knees are straight. "
    "The feet are apart, flat on the ground, toes forward, and do not touch. "
)
NEGATIVE = (
    "ears, ear lobes, ear bumps, ear cartilage, square head, box head, rectangular head, flat chest, missing breasts, "
    "flat plane, flat panel, thick abdomen, barrel torso, wide waist, no waist, rectangular torso, "
    "bent elbows, hanging arms, A-pose, arms down, idle stance, hands on hips, "
    "arm pointing forward, arm in front of the chest, pointing pose, "
    "thighs together, legs fused, legs touching, feet together, feet touching, planted together, "
    "voxel, voxels, pixel art, pixels, lumpy, blocky, stepped, "
    "eyebrows, nose, mouth, lips, hair, circlet, neckband, scarf, scarf tail, hanging cloth, "
    "armor, coat, pants, boots, clothes, weapon, extra limbs, realistic proportions, "
    "small head, long legs, fashion figure, blurry, portrait crop, text"
)

PROMPT = (
    "Full-body female game mannequin, facing the camera. "
    + _POSE
    + _FACE
    + _SKIN
)
_SIDE = (
    "T-pose seen from the side. The near hand is large because it reaches toward the camera. "
    "The far arm is a thin horizontal line going back. No arm follows the face. "
    "No arm in front of the chest. Both arms are horizontal and the elbows are locked. "
    "The legs are straight, not a walk step. "
)
SIDE_LEFT = (
    "Full-body female game mannequin, strict orthographic side view, face pointing to screen right. "
    + _SIDE
    + _FACE
    + _SKIN
)
SIDE_RIGHT = (
    "Full-body female game mannequin, strict orthographic side view, face pointing to screen left. "
    + _SIDE
    + _FACE
    + _SKIN
)
BACK = (
    "Full-body female game mannequin, strict back view. No face, no eyes, no eyebrows, no nose, and no mouth. "
    + _POSE
    + _SKIN
)

# Front, her left (face to screen right), her right (face to screen left), back.
# The standing pixel files are turn 0 only. They are not the mesh source.
VIEWS = (
    {"slot": "front", "role": "mannequin-smooth", "seed": 21, "prompt": PROMPT, "pixel": "female-mannequin-front.png"},
    {"slot": "left", "role": "mannequin-tpose-side", "seed": 31, "prompt": SIDE_LEFT, "pixel": "female-mannequin-left.png"},
    {"slot": "right", "role": "mannequin-tpose-side", "seed": 41, "prompt": SIDE_RIGHT, "pixel": "female-mannequin-right.png"},
    {"slot": "back", "role": "mannequin-tpose-back", "seed": 51, "prompt": BACK, "pixel": "female-mannequin-back.png"},
)


def workflow_for(slot: str, *, seed: int | None = None) -> dict:
    """Text-only Qwen Image 2.1 graph for one T-pose view. Encoder on CPU."""
    view = next((row for row in VIEWS if row["slot"] == slot), None)
    if view is None:
        raise ValueError(f"unknown T-pose slot {slot}")
    return {
        "1": {
            "class_type": "CLIPLoader",
            "inputs": {"clip_name": "qwen3vl_8b_int8_convrot.safetensors", "type": "qwen_image", "device": "cpu"},
        },
        "2": {
            "class_type": "UNETLoader",
            "inputs": {"unet_name": "qwen_image_2.1_int8_convrot.safetensors", "weight_dtype": "default"},
        },
        "3": {
            "class_type": "VAELoader",
            "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"},
        },
        "4": {
            "class_type": "TextEncodeQwenImage21",
            "inputs": {
                "clip": ["1", 0],
                "vae": ["3", 0],
                "prompt": view["prompt"],
                "negative_prompt": NEGATIVE,
                "resolution": 1024,
            },
        },
        "5": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["2", 0],
                "seed": view["seed"] if seed is None else seed,
                "steps": 12,
                "cfg": 1.5,
                "sampler_name": "euler",
                "scheduler": "simple",
                "positive": ["4", 0],
                "negative": ["4", 1],
                "latent_image": ["4", 2],
                "denoise": 1.0,
            },
        },
        "6": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["5", 0], "vae": ["3", 0]},
        },
        "7": {
            "class_type": "SaveImage",
            "inputs": {"images": ["6", 0], "filename_prefix": f"wdb-gen/female-mannequin-tpose-{slot}"},
        },
    }


def front_workflow(*, seed: int = 21) -> dict:
    """Front T-pose graph. Kept so older callers still build the mesh source."""
    return workflow_for("front", seed=seed)


def selftest() -> list[str]:
    """The mesh source is a text-only T-pose, not a copy of the standing plate."""
    bad: list[str] = []
    slots = [row["slot"] for row in VIEWS]
    if slots != ["front", "left", "right", "back"]:
        bad.append("T-pose views are not front, left, right, back")
    seen: set[str] = set()
    for row in VIEWS:
        graph = workflow_for(row["slot"])
        blob = str(graph)
        if "LoadImage" in blob or "keep picture" in blob.lower():
            bad.append(f"{row['slot']} still copies a plate")
        prompt = graph["4"]["inputs"]["prompt"]
        if "T-pose" not in prompt or "no ears" not in prompt or "hourglass" not in prompt:
            bad.append(f"{row['slot']} prompt dropped a required shape")
        if "feet together" in prompt or "a little away" in prompt:
            bad.append(f"{row['slot']} prompt still asks for the standing pose")
        if graph["1"]["inputs"]["device"] != "cpu":
            bad.append(f"{row['slot']} encoder is not on CPU")
        prefix = graph["7"]["inputs"]["filename_prefix"]
        if prefix in seen:
            bad.append(f"duplicate prefix {prefix}")
        seen.add(prefix)
    front = workflow_for("front")["4"]["inputs"]["prompt"]
    if "facing the camera" not in front or "clear gap" not in front:
        bad.append("front prompt is not a gapped T-pose")
    if "screen right" not in workflow_for("left")["4"]["inputs"]["prompt"]:
        bad.append("left prompt does not face screen right")
    if "toward the camera" not in workflow_for("left")["4"]["inputs"]["prompt"]:
        bad.append("left prompt does not aim an arm at the camera")
    if "screen left" not in workflow_for("right")["4"]["inputs"]["prompt"]:
        bad.append("right prompt does not face screen left")
    if "No face" not in workflow_for("back")["4"]["inputs"]["prompt"]:
        bad.append("back prompt still allows a face")
    return bad
