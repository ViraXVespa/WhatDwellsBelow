"""T-pose stills for a mannequin mesh. The pose is shared. The body is not.

The bind pose is a T-pose. Idle is a later animation. The standing pixel plates
stay the pixel lock and are not copied into this graph. Which body the prompt
describes comes from the subject: its label, its shape, and the negative that
belongs to that shape. A missing shape is an error.
"""
from __future__ import annotations

_FACE = "Eyes may stay as simple marks. No eyebrows, no nose, no mouth, no lips. "
_POSE = (
    "T-pose. Both arms are straight out to the sides, horizontal, elbows locked, palms down. "
    "The thighs are apart with a clear gap. The knees are straight. "
    "The feet are apart, flat on the ground, toes forward, and do not touch. "
)
_SURFACE = (
    "Smooth continuous skin, like a clean sculpt, not a pixel drawing and not a voxel. "
    "The torso is a continuous curve, not a flat plane and not a thick tube. "
    "Even skin tone, flat magenta background, no text, no border."
)
_NEGATIVE = (
    "bent elbows, hanging arms, A-pose, arms down, idle stance, hands on hips, "
    "arm pointing forward, arm in front of the chest, pointing pose, "
    "thighs together, legs fused, legs touching, feet together, feet touching, planted together, "
    "voxel, voxels, pixel art, pixels, lumpy, blocky, stepped, "
    "extra limbs, blurry, portrait crop, text"
)
_SIDE = (
    "T-pose seen from the side. The near hand is large because it reaches toward the camera. "
    "The far arm is a thin horizontal line going back. No arm follows the face. "
    "No arm in front of the chest. Both arms are horizontal and the elbows are locked. "
    "The legs are straight, not a walk step. "
)
# slot, vision role, the view clause that follows "Full-body {label} game mannequin, "
_SLOTS = (
    ("front", "mannequin-smooth", "facing the camera. "),
    ("left", "mannequin-tpose-side", "strict orthographic side view, face pointing to screen right. "),
    ("right", "mannequin-tpose-side", "strict orthographic side view, face pointing to screen left. "),
    ("back", "mannequin-tpose-back", "strict back view. No face, no eyes, no eyebrows, no nose, and no mouth. "),
)
_SEEDS = {"front": 21, "left": 31, "right": 41, "back": 51}


def _text(spec: dict, key: str) -> str:
    value = spec.get(key) if isinstance(spec, dict) else None
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"body data needs {key}")
    return value.strip()


def views_for(spec: dict) -> tuple[dict, ...]:
    """Four T-pose views. The pose is shared. The shape sentence is the asset's."""
    _text(spec, "id")
    label = _text(spec, "label")
    shape = _text(spec, "shape")
    seeds = spec.get("seeds") or {}
    if not isinstance(seeds, dict):
        raise ValueError("seeds must be an object")
    plates = spec.get("plates") or {}
    if not isinstance(plates, dict):
        raise ValueError("plates must be an object")
    pixels = spec.get("pixels") or {}
    if not isinstance(pixels, dict):
        raise ValueError("pixels must be an object")
    rows = []
    for slot, role, lead in _SLOTS:
        prompt = f"Full-body {label} game mannequin, {lead}"
        prompt += _SIDE if slot in ("left", "right") else _POSE
        if slot != "back":
            prompt += _FACE
        prompt += shape + " " + _SURFACE
        seed = seeds.get(slot, _SEEDS[slot])
        rows.append({
            "slot": slot,
            "role": role,
            "seed": int(seed),
            "prompt": prompt,
            "pixel": str(pixels.get(slot) or plates.get(slot) or ""),
        })
    return tuple(rows)


def workflow_for(slot: str, spec: dict, *, seed: int | None = None) -> dict:
    """Text-only Qwen Image 2.1 graph for one T-pose view. Encoder on CPU."""
    view = next((row for row in views_for(spec) if row["slot"] == slot), None)
    if view is None:
        raise ValueError(f"unknown T-pose slot {slot}")
    extra = spec.get("shape_negative") or ""
    if not isinstance(extra, str):
        raise ValueError("shape_negative must be a string")
    negative = _NEGATIVE
    if extra.strip():
        negative = extra.strip().rstrip(",") + ", " + _NEGATIVE
    subject_id = _text(spec, "id")
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
                "negative_prompt": negative,
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
            "inputs": {"images": ["6", 0], "filename_prefix": f"wdb-gen/{subject_id}-mannequin-tpose-{slot}"},
        },
    }


def front_workflow(spec: dict, *, seed: int = 21) -> dict:
    """Front T-pose graph for one subject."""
    return workflow_for("front", spec, seed=seed)


def selftest() -> list[str]:
    """The pose is shared. Breasts and an hourglass are whatever shape the asset passed in."""
    bad: list[str] = []
    female = {
        "id": "female",
        "label": "female",
        "shape": (
            "The head is a rounded oval only a little wider than the ribcage. "
            "Slim thighs and slim calves. "
            "The head has no ears. Ears are a later piece. "
            "The sides of the head are a smooth unbroken oval, with no ear lobes and no ear bumps. "
            "The widest part of the head is the upper skull, never a lobe beside the jaw. "
            "A female chest with breasts. A narrow waist and an hourglass figure. "
            "The abdomen is slim. The hips are wider than the waist. "
            "Bald. No hair, no circlet, no neckband, no armor, no pants, no boots."
        ),
        "shape_negative": (
            "ears, ear lobes, ear bumps, ear cartilage, visible ear, ear attached to the jaw, lobed skull, "
            "square head, box head, rectangular head, flat chest, missing breasts, "
            "flat plane, flat panel, thick abdomen, barrel torso, wide waist, no waist, rectangular torso, "
            "eyebrows, nose, mouth, lips, hair, circlet, neckband, scarf, scarf tail, hanging cloth, "
            "armor, coat, pants, boots, clothes, weapon, "
            "huge head, giant head, thick thighs, thick calves, long legs, fashion figure"
        ),
    }
    brute = {"id": "brute", "label": "brute", "shape": "A heavy chest and thick arms. Bald."}
    try:
        workflow_for("front", {"id": "brute", "label": "brute"})
        bad.append("a missing shape was accepted")
    except ValueError:
        pass
    slots = [row["slot"] for row in views_for(female)]
    if slots != ["front", "left", "right", "back"]:
        bad.append("T-pose views are not front, left, right, back")
    seen: set[str] = set()
    for row in views_for(female):
        graph = workflow_for(row["slot"], female)
        blob = str(graph)
        if "LoadImage" in blob or "keep picture" in blob.lower():
            bad.append(f"{row['slot']} still copies a plate")
        prompt = graph["4"]["inputs"]["prompt"]
        if "T-pose" not in prompt or "no ears" not in prompt or "hourglass" not in prompt:
            bad.append(f"{row['slot']} prompt dropped a required shape")
        if "feet together" in prompt or "a little away" in prompt:
            bad.append(f"{row['slot']} prompt still asks for the standing pose")
        if "Large rounded head" in prompt or "little wider than the ribcage" not in prompt:
            bad.append(f"{row['slot']} prompt still asks for a giant head")
        if "chibi" in prompt.lower() or "short legs" in prompt.lower():
            bad.append(f"{row['slot']} prompt still asks for a chibi head")
        if "Slim thighs" not in prompt or "slim calves" not in prompt:
            bad.append(f"{row['slot']} prompt dropped the slim legs")
        negative = graph["4"]["inputs"]["negative_prompt"]
        if "small head" in negative or "huge head" not in negative:
            bad.append(f"{row['slot']} negative still wants a large head")
        if "realistic proportions" in negative or "chibi" in negative.lower():
            bad.append(f"{row['slot']} negative still pushes a chibi head")
        if "Shrink the head" in prompt or "Narrow each thigh" in prompt:
            bad.append(f"{row['slot']} prompt already contains a retry sentence")
        if graph["1"]["inputs"]["device"] != "cpu":
            bad.append(f"{row['slot']} encoder is not on CPU")
        prefix = graph["7"]["inputs"]["filename_prefix"]
        if not prefix.startswith("wdb-gen/female-mannequin-tpose-"):
            bad.append(f"{row['slot']} prefix is not the subject id")
        if prefix in seen:
            bad.append(f"duplicate prefix {prefix}")
        seen.add(prefix)
    front = workflow_for("front", female)["4"]["inputs"]["prompt"]
    if "facing the camera" not in front or "clear gap" not in front:
        bad.append("front prompt is not a gapped T-pose")
    if "screen right" not in workflow_for("left", female)["4"]["inputs"]["prompt"]:
        bad.append("left prompt does not face screen right")
    if "toward the camera" not in workflow_for("left", female)["4"]["inputs"]["prompt"]:
        bad.append("left prompt does not aim an arm at the camera")
    if "screen left" not in workflow_for("right", female)["4"]["inputs"]["prompt"]:
        bad.append("right prompt does not face screen left")
    if "No face" not in workflow_for("back", female)["4"]["inputs"]["prompt"]:
        bad.append("back prompt still allows a face")
    brute_prompt = workflow_for("front", brute)["4"]["inputs"]["prompt"].lower()
    brute_negative = workflow_for("front", brute)["4"]["inputs"]["negative_prompt"].lower()
    for word in ("breast", "hourglass", "female"):
        if word in brute_prompt or word in brute_negative:
            bad.append(f"a brute prompt inherited {word}")
    if "t-pose" not in brute_prompt:
        bad.append("a brute prompt dropped the shared pose")
    if not workflow_for("front", brute)["7"]["inputs"]["filename_prefix"].startswith("wdb-gen/brute-"):
        bad.append("a brute graph used another subject's prefix")
    return bad
