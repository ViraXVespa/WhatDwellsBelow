"""Qwen still for the mannequin mesh. Smooth sculpt, not the pixel plate.

The pixel front has ears, a flat chest, and a blocky head. Feeding that plate
to a mesh extractor keeps those shapes and looks lumpy. This graph is text
only, so the pixel plate is not copied.
"""
from __future__ import annotations

PROMPT = (
    "Full-body female game mannequin, standing, facing the camera, feet together. "
    "Large rounded head, short legs, arms a little away from the sides. "
    "Smooth continuous skin, like a clean sculpt, not a pixel drawing and not a voxel. "
    "The head is a rounded oval with no ears. Ears are a later piece. "
    "Eyes may stay as simple marks. No eyebrows, no nose, no mouth, no lips. "
    "A female chest with breasts. The front of the torso is a continuous curve, not a flat plane. "
    "Bald. No hair, no circlet, no neckband, no armor, no pants, no boots. "
    "Even skin tone, flat magenta background, no text, no border."
)
NEGATIVE = (
    "ears, square head, box head, rectangular head, flat chest, missing breasts, "
    "flat plane, flat panel, voxel, voxels, pixel art, pixels, lumpy, blocky, stepped, "
    "eyebrows, nose, mouth, lips, hair, circlet, neckband, scarf, scarf tail, hanging cloth, "
    "armor, coat, pants, boots, clothes, weapon, extra limbs, realistic proportions, "
    "small head, long legs, fashion figure, blurry, portrait crop, text"
)


def front_workflow(*, seed: int = 21) -> dict:
    """Text-only Qwen Image 2.1 graph. Twelve steps, encoder on CPU."""
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
                "prompt": PROMPT,
                "negative_prompt": NEGATIVE,
                "resolution": 1024,
            },
        },
        "5": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["2", 0],
                "seed": seed,
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
            "inputs": {"images": ["6", 0], "filename_prefix": "wdb-gen/female-mannequin-smooth"},
        },
    }


def selftest() -> list[str]:
    """The mesh-source still does not copy the pixel plate."""
    bad: list[str] = []
    graph = front_workflow()
    blob = str(graph)
    if "LoadImage" in blob or "keep picture" in blob.lower():
        bad.append("smooth still still copies a plate")
    prompt = graph["4"]["inputs"]["prompt"]
    if "no ears" not in prompt or "breasts" not in prompt or "flat plane" not in prompt:
        bad.append("smooth still prompt dropped a required shape")
    if graph["1"]["inputs"]["device"] != "cpu":
        bad.append("smooth still encoder is not on CPU")
    return bad
