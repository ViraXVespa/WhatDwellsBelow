"""Build the mannequin body with Hunyuan3D surface net, not the 32-grid structure.

The locked plates are already framed. This uploads them, runs the Comfy
blueprint settings, and checks the glb for a height gap. If that setting does
not fit on the card, one smaller octree is tried. A fail stays in the report.
"""
from __future__ import annotations

import json
from pathlib import Path

from media.pipeline import comfy_run, mesh_check

CKPT = "hunyuan_3d_v2.1.safetensors"
# Blueprint first (latent 4096, octree 256, 30 steps, cfg 5, surface net).
# The second row is the fit retry. It is not the 32-grid path.
STAGES = (
    {"latent": 4096, "octree": 256, "steps": 30, "cfg": 5.0, "threshold": 0.6},
    {"latent": 3072, "octree": 128, "steps": 30, "cfg": 5.0, "threshold": 0.6},
)
VIEWS = ("front", "left", "back", "right")


def _fits_failure(message: str) -> bool:
    text = message.lower()
    needles = ("out of memory", "outofmemory", "failed to allocate", "not enough memory", "cuda oom")
    return any(needle in text for needle in needles)


def build_workflow(
    names: dict[str, str],
    *,
    seed: int,
    latent: int,
    octree: int,
    steps: int,
    cfg: float,
    threshold: float,
    prefix: str,
) -> dict:
    """API graph. View order is front, left, back, right, matching the Hunyuan embeds."""
    missing = [slot for slot in VIEWS if slot not in names]
    if missing:
        raise ValueError("body views missing " + ",".join(missing))
    graph: dict[str, dict] = {
        "1": {
            "class_type": "ImageOnlyCheckpointLoader",
            "inputs": {"ckpt_name": CKPT},
        },
        "40": {
            "class_type": "EmptyLatentHunyuan3Dv2",
            "inputs": {"resolution": latent, "batch_size": 1},
        },
    }
    encode_ids = {"front": "20", "left": "21", "back": "22", "right": "23"}
    load_ids = {"front": "10", "left": "11", "back": "12", "right": "13"}
    for slot in VIEWS:
        graph[load_ids[slot]] = {
            "class_type": "LoadImage",
            "inputs": {"image": names[slot]},
        }
        graph[encode_ids[slot]] = {
            "class_type": "CLIPVisionEncode",
            "inputs": {"clip_vision": ["1", 1], "image": [load_ids[slot], 0], "crop": "center"},
        }
    graph["30"] = {
        "class_type": "Hunyuan3Dv2ConditioningMultiView",
        "inputs": {slot: [encode_ids[slot], 0] for slot in VIEWS},
    }
    graph["50"] = {
        "class_type": "KSampler",
        "inputs": {
            "model": ["1", 0],
            "seed": seed,
            "steps": steps,
            "cfg": cfg,
            "sampler_name": "euler",
            "scheduler": "normal",
            "positive": ["30", 0],
            "negative": ["30", 1],
            "latent_image": ["40", 0],
            "denoise": 1.0,
        },
    }
    graph["60"] = {
        "class_type": "VAEDecodeHunyuan3D",
        "inputs": {
            "samples": ["50", 0],
            "vae": ["1", 2],
            "num_chunks": 8000,
            "octree_resolution": octree,
        },
    }
    graph["70"] = {
        "class_type": "VoxelToMesh",
        "inputs": {"voxel": ["60", 0], "algorithm": "surface net", "threshold": threshold},
    }
    graph["80"] = {
        "class_type": "SaveGLB",
        "inputs": {"mesh": ["70", 0], "filename_prefix": prefix},
    }
    return graph


def _write_report(dest: Path, report: dict) -> None:
    lines = [
        "# mannequin body",
        "",
        f"status: {report['status']}",
        f"turns: {report['turns']}/{report['limit']}",
        "",
        "This is a progress record. A failed mesh is not for approval.",
        "",
    ]
    for step in report["steps"]:
        lines.append(f"## turn {step['turn']}")
        lines.append("")
        lines.append(
            f"latent {step['latent']} octree {step['octree']} steps {step['steps']} "
            f"threshold {step['threshold']}"
        )
        if step.get("prompt_id"):
            lines.append(f"prompt: {step['prompt_id']}")
        if step.get("error"):
            lines.append(f"error: {step['error']}")
        if step.get("mesh"):
            lines.append(
                f"mesh: {step['mesh']} verts={step.get('verts')} span={step.get('span')} "
                f"empty={step.get('empty') or 'none'}"
            )
        lines.append(f"action: {step['action']}")
        lines.append("")
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "report.md").write_text("\n".join(lines), encoding="utf-8")
    (dest / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")


def run_body(
    root: Path,
    views: dict[str, Path],
    dest: Path,
    *,
    server: str,
    turns: int,
    seed: int = 3,
    timeout: float = 2400,
) -> dict:
    """Upload the four plates and try the stages. Stop when the mesh connects or the limit hits."""
    limit = max(1, min(turns, len(STAGES)))
    comfy_run.free(server)
    uploaded = {slot: comfy_run.upload_image(server, views[slot]) for slot in VIEWS}
    steps: list[dict] = []
    status = "fail"
    kept: Path | None = None
    for index, stage in enumerate(STAGES[:limit]):
        step = {"turn": index, "action": "stop", **stage}
        workflow = build_workflow(
            uploaded,
            seed=seed + index,
            prefix=f"wdb-gen/female-hunyuan-body-t{index}",
            **stage,
        )
        print(f"turn {index} latent={stage['latent']} octree={stage['octree']}", flush=True)
        try:
            prompt_id = comfy_run.queue(server, workflow)
            step["prompt_id"] = prompt_id
            print(f"turn {index} prompt {prompt_id}", flush=True)
            item = comfy_run.wait(server, prompt_id, timeout)
            glb = dest / f"turn-{index}.glb"
            comfy_run.save_3d(server, item, glb)
            measured = mesh_check.check_glb(glb)
            step["mesh"] = str(glb)
            step["verts"] = measured["verts"]
            step["span"] = measured["span"]
            step["empty"] = measured["empty"]
            if measured["ok"]:
                final = dest / "body.glb"
                final.write_bytes(glb.read_bytes())
                gen = root / "data" / "pipeline" / "wip" / "gen" / "female-hunyuan-body.glb"
                gen.parent.mkdir(parents=True, exist_ok=True)
                gen.write_bytes(glb.read_bytes())
                step["action"] = "kept"
                status = "pass"
                kept = gen
                steps.append(step)
                break
            step["action"] = "stop"
            step["error"] = measured["reason"]
        except ValueError as exc:
            step["error"] = str(exc)
            if _fits_failure(step["error"]) and index + 1 < limit:
                step["action"] = "smaller"
            else:
                step["action"] = "stop"
        steps.append(step)
        if step["action"] == "stop":
            break
    report = {"status": status, "turns": len(steps), "limit": limit, "steps": steps, "glb": str(kept) if kept else ""}
    _write_report(dest, report)
    try:
        comfy_run.free(server)
    except ValueError:
        pass
    return report


def selftest() -> list[str]:
    """The graph is the surface-net blueprint, and the retry is a smaller octree."""
    bad: list[str] = []
    names = {slot: f"{slot}.png" for slot in VIEWS}
    graph = build_workflow(names, seed=3, prefix="wdb-gen/body", **STAGES[0])
    blob = json.dumps(graph)
    if "VaeDecodeStructureTrellis2" in blob or "resolution\": 32" in blob:
        bad.append("body graph still uses the 32-grid structure path")
    if graph["70"]["inputs"]["algorithm"] != "surface net":
        bad.append("body graph is not surface net")
    if graph["60"]["inputs"]["octree_resolution"] != STAGES[0]["octree"]:
        bad.append("body graph dropped the blueprint octree")
    loads = [node for node in graph.values() if node["class_type"] == "LoadImage"]
    if len(loads) != 4:
        bad.append(f"body graph has {len(loads)} views")
    if STAGES[1]["octree"] >= STAGES[0]["octree"] or STAGES[1]["latent"] >= STAGES[0]["latent"]:
        bad.append("the fit retry is not smaller")
    if not _fits_failure("CUDA out of memory. failed to allocate"):
        bad.append("an out-of-memory error was missed")
    if _fits_failure("node Hunyuan missing"):
        bad.append("a missing node was treated as a fit failure")
    try:
        build_workflow({"front": "f.png"}, seed=1, prefix="x", **STAGES[0])
        bad.append("a three-view graph was accepted")
    except ValueError:
        pass
    return bad
