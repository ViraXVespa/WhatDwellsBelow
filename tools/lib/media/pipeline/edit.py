"""Text edit of a kept mesh: one whole-body still, then a Hi3D refine of a copy.

`pipeline edit ID --text` draws that change on a Qwen still of the whole subject
in the subject's T-pose, then Hi3D v1.0 refines a copy of the kept mesh from
that still. The source glb is not overwritten. Hi3D reads the mesh and the
image. It does not read the prompt. A failed mesh stays in the review report.
"""
from __future__ import annotations

import json
from pathlib import Path

from media.pipeline import comfy_run, mesh_check, proportion, smooth

CKPT = "hi3d_v1_int8.safetensors"
DINO = "dinov2-large.safetensors"
CLIP = "clip-vit-large-patch14.safetensors"
BG = "birefnet.safetensors"
CHAIN = ("512", "1024", "1536")
STEPS = 25


def _fits_failure(message: str) -> bool:
    text = message.lower()
    needles = ("out of memory", "outofmemory", "failed to allocate", "not enough memory", "cuda oom")
    return any(needle in text for needle in needles)


def _guard_prefix(prefix: str) -> None:
    leaf = prefix.replace("\\", "/").rstrip("/").split("/")[-1]
    if leaf.endswith("-hunyuan-body") or "hunyuan-body-digits" in leaf:
        raise ValueError("edit would overwrite a kept mesh")


def kept_source(root: Path, subject_id: str) -> Path:
    if not subject_id:
        raise ValueError("subject id is required")
    return root / "data" / "pipeline" / "wip" / "gen" / f"{subject_id}-hunyuan-body.glb"


def edit_dest(root: Path, subject_id: str) -> Path:
    """New glb. This is never the kept body and never the rejected digits mesh."""
    if not subject_id:
        raise ValueError("subject id is required")
    gen = root / "data" / "pipeline" / "wip" / "gen"
    dest = gen / f"{subject_id}-hunyuan-body-edit.glb"
    blocked = {
        gen / f"{subject_id}-hunyuan-body.glb",
        gen / f"{subject_id}-hunyuan-body-digits.glb",
    }
    if dest in blocked:
        raise ValueError("edit output collides with a kept mesh")
    return dest


def parse_passes(raw: str | None) -> tuple[str, ...]:
    """Default chain is 512, then 1024, then 1536. One resolution is allowed."""
    if raw is None or not str(raw).strip():
        return CHAIN
    parts = tuple(piece.strip() for piece in str(raw).split(",") if piece.strip())
    if not parts:
        raise ValueError("edit passes are empty")
    unknown = [part for part in parts if part not in CHAIN]
    if unknown:
        raise ValueError("unknown edit pass " + ", ".join(unknown))
    order = [CHAIN.index(part) for part in parts]
    if order != sorted(order) or len(set(parts)) != len(parts):
        raise ValueError("edit passes must run 512, then 1024, then 1536")
    return parts


def prompt_for(spec: dict, text: str, *, slot: str = "front") -> dict:
    """The subject's whole-body still, plus the change. The change is not a crop."""
    change = " ".join(text.split())
    if not change:
        raise ValueError("edit text is required")
    graph = smooth.workflow_for(slot, spec)
    view = next((row for row in smooth.views_for(spec) if row["slot"] == slot), None)
    if view is None:
        raise ValueError(f"unknown edit slot {slot}")
    return {
        "prompt": graph["4"]["inputs"]["prompt"].rstrip() + " " + change,
        "negative": graph["4"]["inputs"]["negative_prompt"],
        "role": view["role"],
        "seed": view["seed"],
        "slot": slot,
    }


def build_still(
    prompt: str,
    negative: str,
    *,
    seed: int,
    prefix: str,
    reference: str | None = None,
) -> dict:
    """Qwen Image 2.1 graph. A reference image is optional and is the whole subject."""
    if not prompt.strip():
        raise ValueError("edit text is required")
    _guard_prefix(prefix)
    encoded = {
        "clip": ["1", 0],
        "vae": ["3", 0],
        "prompt": prompt,
        "negative_prompt": negative,
        "resolution": 1024,
    }
    graph: dict[str, dict] = {
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
        "4": {"class_type": "TextEncodeQwenImage21", "inputs": encoded},
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
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["3", 0]}},
        "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": prefix}},
    }
    if reference:
        # Resolution 0 keeps the latent on the reference size. Any other size shifts the edit.
        encoded["resolution"] = 0
        encoded["image_1"] = ["8", 0]
        graph["8"] = {"class_type": "LoadImage", "inputs": {"image": reference}}
    return graph


def _preview(image_name: str) -> dict:
    """Load3D reads these preview files even when only the mesh output is wired."""
    return {
        "image": image_name,
        "mask": image_name,
        "normal": image_name,
        "recording": "",
        "camera_info": {
            "position": {"x": 0, "y": 1, "z": 3},
            "target": {"x": 0, "y": 1, "z": 0},
            "zoom": 1,
            "cameraType": "perspective",
            "fov": 35,
        },
    }


def build_refine(
    image_name: str,
    mesh_name: str,
    passes: tuple[str, ...],
    *,
    seed: int,
    prefix: str,
) -> dict:
    """Hi3D chain. Remesh once, then each decoded mesh feeds the next pass."""
    if not image_name or not mesh_name:
        raise ValueError("edit refine needs a still and a mesh")
    if not passes:
        raise ValueError("edit passes are empty")
    _guard_prefix(prefix)
    graph: dict[str, dict] = {
        "1": {"class_type": "Hi3DCheckpointLoader", "inputs": {"ckpt_name": CKPT}},
        "2": {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": DINO}},
        "3": {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": CLIP}},
        "4": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "5": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": BG}},
        "6": {
            "class_type": "RemoveBackground",
            "inputs": {"bg_removal_model": ["5", 0], "image": ["4", 0]},
        },
        "7": {
            "class_type": "ImageCropToMask",
            "inputs": {
                "images": ["4", 0],
                "masks": ["6", 0],
                "width": 1024,
                "height": 1024,
                "pad_factor": 1.2,
                "grow_mask": 0,
                "background": "#ffffff",
            },
        },
        "9": {
            "class_type": "Hi3DConditioning",
            "inputs": {"dino_vision": ["2", 0], "clip_vision": ["3", 0], "image": ["7", 0]},
        },
        "10": {
            "class_type": "Load3D",
            "inputs": {
                "model_file": mesh_name,
                "image": _preview(image_name),
                "width": 1024,
                "height": 1024,
            },
        },
        "11": {"class_type": "Get3DComponents", "inputs": {"model_3d": ["10", 6]}},
        "24": {
            "class_type": "RemeshMesh",
            "inputs": {
                "mesh": ["11", 0],
                "resolution": 1024,
                "sign_mode": "solid",
                "sign_mode.fill": 20,
                "sign_mode.qef": False,
                "band": 1,
                "project_back": 0,
                "fix_poles": False,
                "smooth_iters": 0,
                "drop_small_components": 0.01,
                "precluster_max_verts": 20000000,
            },
        },
    }
    mesh_from = ["24", 0]
    for index, resolution in enumerate(passes):
        if resolution not in CHAIN:
            raise ValueError(f"unknown edit pass {resolution}")
        stage = str(30 + index * 3)
        sampler = str(31 + index * 3)
        decode = str(32 + index * 3)
        graph[stage] = {
            "class_type": "Hi3DRefineStage",
            "inputs": {
                "positive": ["9", 0],
                "negative": ["9", 1],
                "mesh": mesh_from,
                "resolution": resolution,
            },
        }
        graph[sampler] = {
            "class_type": "Hi3DSampler",
            "inputs": {
                "model": ["1", 0],
                "positive": [stage, 0],
                "negative": [stage, 1],
                "latent": [stage, 2],
                "seed": seed,
                "steps": STEPS,
            },
        }
        graph[decode] = {
            "class_type": "VAEDecodeHi3D",
            "inputs": {"samples": [sampler, 0], "vae": ["1", 1]},
        }
        mesh_from = [decode, 0]
    graph["80"] = {"class_type": "SaveGLB", "inputs": {"mesh": mesh_from, "filename_prefix": prefix}}
    return graph


def _write_report(dest: Path, report: dict) -> None:
    lines = [
        "# mesh edit",
        "",
        f"status: {report['status']}",
        f"source: {report['source']}",
        "",
        "This is a progress record. A failed mesh is not for approval.",
        "",
    ]
    for step in report["steps"]:
        lines.append("## " + ",".join(step["passes"]))
        lines.append("")
        if step.get("prompt_id"):
            lines.append(f"prompt: {step['prompt_id']}")
        if step.get("error"):
            lines.append(f"error: {step['error']}")
        if step.get("mesh"):
            lines.append(
                f"mesh: {step['mesh']} verts={step.get('verts')} span={step.get('span')} "
                f"share={step.get('share')} empty={step.get('empty') or 'none'}"
            )
        if step.get("proportion"):
            lines.append(f"proportion: {step['proportion']}")
        lines.append(f"action: {step['action']}")
        lines.append("")
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "report.md").write_text("\n".join(lines), encoding="utf-8")
    (dest / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


def run_refine(
    source: Path,
    image: Path,
    dest: Path,
    review: Path,
    *,
    subject_id: str,
    gates: dict,
    server: str,
    passes: tuple[str, ...],
    seed: int = 42,
    timeout: float = 3600,
) -> dict:
    """Upload a copy of the source mesh and refine it. The source file stays put."""
    if not subject_id:
        raise ValueError("subject id is required")
    if not source.is_file():
        raise ValueError(f"missing mesh {source}")
    if not image.is_file():
        raise ValueError(f"missing still {image}")
    if source.resolve() == dest.resolve():
        raise ValueError("edit would overwrite the source mesh")
    if dest.name.endswith("-hunyuan-body.glb") or "hunyuan-body-digits" in dest.name:
        raise ValueError("edit would overwrite a kept mesh")
    before = source.stat().st_size
    comfy_run.free(server)
    image_name = comfy_run.upload_image(server, image)
    mesh_name = comfy_run.upload_file(server, source, subfolder="3d")
    attempt = passes
    retried = False
    steps: list[dict] = []
    status = "fail"
    kept: Path | None = None
    while True:
        step: dict = {"passes": list(attempt), "action": "stop", "seed": seed}
        workflow = build_refine(
            image_name,
            mesh_name,
            attempt,
            seed=seed,
            prefix=f"wdb-gen/{subject_id}-edit",
        )
        print("refine " + ",".join(attempt), flush=True)
        try:
            prompt_id = comfy_run.queue(server, workflow)
            step["prompt_id"] = prompt_id
            print(f"refine prompt {prompt_id}", flush=True)
            item = comfy_run.wait(server, prompt_id, timeout)
            glb = review / ("refine-" + "-".join(attempt) + ".glb")
            comfy_run.save_3d(server, item, glb)
            measured = mesh_check.check_glb(glb)
            step["mesh"] = str(glb)
            step["verts"] = measured["verts"]
            step["span"] = measured["span"]
            step["empty"] = measured["empty"]
            step["share"] = measured.get("share")
            if measured["ok"]:
                sized = proportion.check_glb(glb, gates)
                step["proportion"] = sized["reason"]
                if sized["ok"]:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(glb.read_bytes())
                    step["action"] = "kept"
                    status = "pass"
                    kept = dest
                else:
                    step["error"] = sized["reason"]
            else:
                step["error"] = measured["reason"]
        except ValueError as exc:
            step["error"] = str(exc)
            if _fits_failure(step["error"]) and not retried and attempt != ("512",):
                step["action"] = "smaller"
                retried = True
                steps.append(step)
                attempt = ("512",)
                continue
        steps.append(step)
        break
    if source.stat().st_size != before:
        raise ValueError("edit changed the source mesh")
    report = {
        "status": status,
        "source": str(source),
        "glb": str(kept) if kept else "",
        "steps": steps,
    }
    _write_report(review, report)
    try:
        comfy_run.free(server)
    except ValueError:
        pass
    return report


def selftest() -> list[str]:
    """The still keeps the subject's pose, and the refine writes a new glb."""
    bad: list[str] = []
    spec = {"id": "crate", "label": "crate", "shape": "A square crate."}
    try:
        prompt_for(spec, "   ")
        bad.append("blank edit text was accepted")
    except ValueError:
        pass
    try:
        parse_passes("1536,512")
        bad.append("a reversed pass list was accepted")
    except ValueError:
        pass
    try:
        parse_passes("256")
        bad.append("an unknown pass was accepted")
    except ValueError:
        pass
    if parse_passes(None) != CHAIN:
        bad.append("the default chain is not 512, 1024, 1536")
    spoken = prompt_for(spec, "A round window.")
    if "round window" not in spoken["prompt"] or "Full-body" not in spoken["prompt"]:
        bad.append("the edit still dropped the whole subject")
    if "T-pose" not in spoken["prompt"]:
        bad.append("the edit still dropped the mesh pose")
    if "thumb" in spoken["prompt"].lower() or "finger" in spoken["prompt"].lower():
        bad.append("a crate edit grew a hand")
    if "chibi" in spoken["prompt"].lower() or "short legs" in spoken["prompt"].lower():
        bad.append("the edit still asks for a chibi head")
    if "realistic proportions" in spoken["negative"]:
        bad.append("the edit negative bans realistic proportions")
    still = build_still(spoken["prompt"], spoken["negative"], seed=spoken["seed"], prefix="wdb-gen/crate-edit-still")
    blob = json.dumps(still)
    if "LoadImage" in blob or "image_1" in blob:
        bad.append("a text still copied a plate")
    if still["4"]["inputs"]["resolution"] != 1024:
        bad.append("a text still dropped the square latent")
    if still["1"]["inputs"]["device"] != "cpu":
        bad.append("the edit encoder is not on CPU")
    referenced = build_still(
        spoken["prompt"], spoken["negative"], seed=1, prefix="wdb-gen/crate-edit-still", reference="plate.png",
    )
    if referenced["4"]["inputs"].get("image_1") != ["8", 0] or referenced["4"]["inputs"]["resolution"] != 0:
        bad.append("a reference still did not keep the reference size")
    if referenced["8"]["inputs"]["image"] != "plate.png":
        bad.append("a reference still dropped its image")
    try:
        build_still("x", "y", seed=1, prefix="wdb-gen/crate-hunyuan-body")
        bad.append("a kept-body still prefix was accepted")
    except ValueError:
        pass
    root = Path("C:/wdb-edit-selftest")
    dest = edit_dest(root, "female")
    source = kept_source(root, "female")
    if dest.name != "female-hunyuan-body-edit.glb" or dest == source:
        bad.append("edit dest is the kept body")
    if "digits" in dest.name:
        bad.append("edit dest is the digits mesh")
    refine = build_refine("still.png", "3d/female-hunyuan-body.glb", CHAIN, seed=42, prefix="wdb-gen/female-edit")
    stages = [node for node in refine.values() if node["class_type"] == "Hi3DRefineStage"]
    decodes = [key for key, node in refine.items() if node["class_type"] == "VAEDecodeHi3D"]
    if [node["inputs"]["resolution"] for node in stages] != ["512", "1024", "1536"]:
        bad.append("the refine chain is not 512, then 1024, then 1536")
    if stages[0]["inputs"]["mesh"] != ["24", 0]:
        bad.append("the first pass skipped the remesh")
    if stages[1]["inputs"]["mesh"] != [decodes[0], 0]:
        bad.append("1024 did not take the decoded 512 mesh")
    if refine["80"]["inputs"]["mesh"] != [decodes[-1], 0]:
        bad.append("save is not the last decode")
    if refine["24"]["inputs"]["sign_mode"] != "solid" or refine["24"]["inputs"]["sign_mode.fill"] != 20:
        bad.append("the remesh is not the solid watertight pass")
    if refine["7"]["inputs"]["pad_factor"] != 1.2 or refine["7"]["inputs"]["background"] != "#ffffff":
        bad.append("the crop is not the whole subject on white")
    if refine["10"]["inputs"]["model_file"] != "3d/female-hunyuan-body.glb":
        bad.append("the refine graph dropped the source mesh")
    names = {node["class_type"] for node in refine.values()}
    if "Hunyuan3Dv2Conditioning" in names or "ImageOnlyCheckpointLoader" in names:
        bad.append("the refine graph rebuilt the body")
    one = build_refine("still.png", "3d/crate.glb", ("512",), seed=1, prefix="wdb-gen/crate-edit")
    if sum(node["class_type"] == "Hi3DRefineStage" for node in one.values()) != 1:
        bad.append("a single pass ran the whole chain")
    if not _fits_failure("CUDA out of memory"):
        bad.append("an out-of-memory error was missed")
    if _fits_failure("node Hi3D missing"):
        bad.append("a missing node was treated as a fit failure")
    try:
        build_refine("still.png", "3d/crate.glb", ("512",), seed=1, prefix="wdb-gen/crate-hunyuan-body-digits")
        bad.append("a digits prefix was accepted")
    except ValueError:
        pass
    return bad
