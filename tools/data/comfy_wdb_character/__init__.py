"""Comfy nodes for the What Dwells Below character pages.

The pose page and the style-lock page share these nodes. Approve and Deny
write the book and do not run the model again. Queue the walk folder sends
one pose picture per depth PNG.
"""
from __future__ import annotations

import json
import time
import uuid
from datetime import datetime
from pathlib import Path

try:
    from aiohttp import web
    from server import PromptServer
except ImportError:
    web = None
    PromptServer = None


HERE = Path(__file__).resolve().parent
LEDGER_DEFAULT = r"C:\Users\Vira\source\repos\WhatDwellsBelow\_src\comfy-character\ledger.json"
CATEGORY = "wdb"
CELLS = ["up_left", "up", "up_right", "left", "face", "right", "down_left", "down", "down_right"]
_CELL_LABEL = {
    "up_left": "Up left",
    "up": "Up",
    "up_right": "Up right",
    "left": "Left",
    "face": "Face",
    "right": "Right",
    "down_left": "Down left",
    "down": "Down",
    "down_right": "Down right",
}
STYLE_CHOICES = ["all nine cells, averaged", "full sheet, one picture"] + CELLS
WORKFLOW_NAMES = {"WDB Character.json": "character", "WDB Style lock.json": "style"}
UNET = "flux-2-klein-base-4b-fp8.safetensors"
LORA = "flux2_klein_4b_refcontrol_depth.safetensors"
CLIP = "qwen_3_4b_fp4_flux2.safetensors"
VAE = "flux2-vae.safetensors"


def _prompts() -> dict:
    return json.loads((HERE / "prompts.json").read_text(encoding="utf-8"))


def words(facing: str, job: str, model: str) -> str:
    data = _prompts()
    if facing == "face":
        view = "The face cell from the bible. Keep this face and this hair."
        identity_key = "female"
    elif facing == "up":
        view = data["facing"]["up"]
        identity_key = "female_up"
    elif facing in data["facing"]:
        view = data["facing"][facing]
        identity_key = "female"
    else:
        raise ValueError("unknown facing " + facing)
    if model == "sdxl":
        template = data["sdxl_style"]
    elif job == "walk frame":
        template = data["klein_walk"]
    else:
        template = data["klein_still"]
    return template.format(facing=view, identity=data["identity"][identity_key])


def _bible_dir() -> Path:
    import folder_paths

    return Path(folder_paths.get_input_directory()) / "wdb-bible"


def _load_png(path: Path):
    import numpy as np
    import torch
    from PIL import Image

    if not path.is_file():
        raise FileNotFoundError(
            "missing " + path.name + ". Stop the Comfy server, then on the game repo run: python tools/media.py comfy-character setup"
        )
    image = Image.open(path).convert("RGB")
    array = np.asarray(image).astype("float32") / 255.0
    return torch.from_numpy(array).unsqueeze(0)


def _bible_image(which: str):
    import torch

    folder = _bible_dir()
    if which == "all nine cells, averaged":
        frames = [_load_png(folder / f"female-{name}.png") for name in CELLS]
        return torch.cat(frames, dim=0)
    if which == "full sheet, one picture":
        return _load_png(folder / "female-sheet.png")
    if which not in CELLS:
        raise ValueError("unknown bible picture " + which)
    return _load_png(folder / f"female-{which}.png")


def _crisp(image):
    import torch

    steps = 4
    values = image.clamp(0, 1)
    levels = torch.round(values * (steps - 1)) / (steps - 1)
    red, green, blue = levels[..., 0], levels[..., 1], levels[..., 2]
    plate = (red > 0.7) & (blue > 0.7) & (green < 0.35)
    levels = levels.clone()
    levels[..., 0] = torch.where(plate, torch.ones_like(red), red)
    levels[..., 1] = torch.where(plate, torch.zeros_like(green), green)
    levels[..., 2] = torch.where(plate, torch.ones_like(blue), blue)
    return levels


class WDBFinish:
    """Flatten soft shading into a few flat steps, then snap the plate to magenta."""

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"image": ("IMAGE",), "look": (["model output", "crisper flat colors"],)}}

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "apply"
    CATEGORY = CATEGORY

    def apply(self, image, look):
        if look != "crisper flat colors":
            return (image,)
        return (_crisp(image),)


class WDBFacing:
    """One bible cell. Down is the front, left is the side, up is the back."""

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"which": (CELLS, {"default": "down"})}}

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "load"
    CATEGORY = CATEGORY

    def load(self, which):
        return (_bible_image(which),)


class WDBStyleLock:
    """Combine the bible pictures that are wired into this node."""

    @classmethod
    def INPUT_TYPES(cls):
        required = {"which": (STYLE_CHOICES, {"default": "all nine cells, averaged"})}
        for name in CELLS:
            required[_CELL_LABEL[name]] = ("IMAGE",)
        required["Full sheet"] = ("IMAGE",)
        return {"required": required}

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "load"
    CATEGORY = CATEGORY

    def load(self, **kwargs):
        import torch

        which = kwargs["which"]
        if which == "all nine cells, averaged":
            frames = [kwargs[_CELL_LABEL[name]] for name in CELLS]
            return (torch.cat(frames, dim=0),)
        if which == "full sheet, one picture":
            return (kwargs["Full sheet"],)
        if which not in _CELL_LABEL:
            raise ValueError("unknown bible picture " + which)
        return (kwargs[_CELL_LABEL[which]],)


class WDBWords:
    """Facing words from the game walk prompts. The button copies them into What to keep."""

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "facing": (CELLS, {"default": "down"}),
                "job": (["pose still", "walk frame"],),
            }
        }

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("words",)
    FUNCTION = "build"
    CATEGORY = CATEGORY

    def build(self, facing, job):
        return (words(facing, job, "klein"),)


class WDBWalk:
    """Queue one picture per depth PNG. The button does the queue."""

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"folder": ("STRING", {"default": "wdb-walk"})}}

    RETURN_TYPES = ("STRING",)
    FUNCTION = "ready"
    OUTPUT_NODE = True
    CATEGORY = CATEGORY

    def ready(self, folder):
        return (folder,)


class WDBApprove:
    """Pass the picture through. Approve and Deny are buttons on the node."""

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "image": ("IMAGE",),
                "note": ("STRING", {"multiline": True, "default": "Say what is wrong, or what to keep."}),
                "character": ("STRING", {"default": "female"}),
                "ledger": ("STRING", {"default": LEDGER_DEFAULT}),
            }
        }

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "pass_image"
    OUTPUT_NODE = True
    CATEGORY = CATEGORY

    def pass_image(self, image, note, character, ledger):
        return (image,)


def _check_ledger(raw: str) -> Path:
    path = Path(raw).resolve()
    if path.name != "ledger.json" or path.parent.name != "comfy-character":
        raise ValueError("ledger must be the comfy-character/ledger.json book")
    return path


def _newest_frame() -> Path | None:
    import folder_paths

    folder = Path(folder_paths.get_output_directory()) / "wdb"
    found = list(folder.glob("gui-character-256_*.png")) + list(folder.glob("gui-style-256_*.png"))
    if not found:
        return None
    return max(found, key=lambda item: item.stat().st_mtime)


def _write_review(payload: dict) -> dict:
    decision = str(payload.get("decision", "")).strip().lower()
    if decision not in ("yes", "no"):
        raise ValueError("decision must be yes or no")
    ledger = _check_ledger(str(payload.get("ledger") or LEDGER_DEFAULT))
    source = _newest_frame()
    if source is None:
        raise ValueError("no picture yet. Press Queue Prompt, wait for it, then Approve or Deny")
    root = ledger.parent.parent.parent
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    dest_rel = Path("_src") / "comfy-character" / "frames" / f"{stamp}.png"
    dest = root / dest_rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(source.read_bytes())
    book = {"runs": []}
    if ledger.is_file():
        book = json.loads(ledger.read_text(encoding="utf-8-sig"))
        book.setdefault("runs", [])
    book["runs"].append({
        "id": stamp,
        "character": str(payload.get("character") or "female"),
        "source": "gui",
        "frame": dest_rel.as_posix(),
        "ref": str(payload.get("ref") or ""),
        "pose": str(payload.get("pose") or ""),
        "prompt": str(payload.get("prompt") or ""),
        "negative": str(payload.get("negative") or ""),
        "seed": payload.get("seed"),
        "steps": payload.get("steps"),
        "cfg": payload.get("cfg"),
        "denoise": payload.get("denoise"),
        "strength": payload.get("strength"),
        "look": str(payload.get("look") or ""),
        "review": decision,
        "note": str(payload.get("note") or "").strip(),
    })
    ledger.parent.mkdir(parents=True, exist_ok=True)
    ledger.write_text(json.dumps(book, indent=2) + "\n", encoding="utf-8", newline="\n")
    return {"ok": True, "id": stamp, "review": decision, "frame": dest_rel.as_posix()}


def _status_text(raw: str) -> str:
    ledger = _check_ledger(raw or LEDGER_DEFAULT)
    if not ledger.is_file():
        return "no runs yet"
    book = json.loads(ledger.read_text(encoding="utf-8-sig"))
    rows = book.get("runs") or []
    if not rows:
        return "no runs yet"
    lines = []
    for row in rows[-8:]:
        lines.append(f"{row.get('id')} {row.get('review')} {row.get('note', '')}")
    return "\n".join(lines)


def _save_workflow(payload: dict) -> dict:
    name = str(payload.get("name") or "")
    if name not in WORKFLOW_NAMES:
        raise ValueError("workflow name must be WDB Character.json or WDB Style lock.json")
    graph = payload.get("graph")
    if not isinstance(graph, dict) or "nodes" not in graph:
        raise ValueError("graph is missing")
    ledger = _check_ledger(str(payload.get("ledger") or LEDGER_DEFAULT))
    root = ledger.parent.parent.parent
    folder = root / "tools" / "data" / "comfy-workflows"
    folder.mkdir(parents=True, exist_ok=True)
    text = json.dumps(graph, indent=2) + "\n"
    (folder / name).write_text(text, encoding="utf-8", newline="\n")
    if name == "WDB Character.json":
        legacy = root / "tools" / "data" / "comfy-character-workflow.json"
        legacy.write_text(text, encoding="utf-8", newline="\n")
    return {"ok": True, "name": name}


def _walk_graph(ref_name: str, depth_name: str, prompt: str, negative: str, steps: int, cfg: float, seed: int, strength: float, look: str, prefix: str) -> dict:
    def node(class_type: str, inputs: dict) -> dict:
        return {"class_type": class_type, "inputs": inputs}

    return {
        "1": node("UNETLoader", {"unet_name": UNET, "weight_dtype": "default"}),
        "2": node("LoraLoaderModelOnly", {"model": ["1", 0], "lora_name": LORA, "strength_model": strength}),
        "3": node("CLIPLoader", {"clip_name": CLIP, "type": "flux2"}),
        "4": node("VAELoader", {"vae_name": VAE}),
        "5": node("CLIPTextEncode", {"text": prompt, "clip": ["3", 0]}),
        "6": node("CLIPTextEncode", {"text": negative, "clip": ["3", 0]}),
        "10": node("LoadImage", {"image": depth_name}),
        "11": node("LoadImage", {"image": ref_name}),
        "12": node("ImageScaleToTotalPixels", {"image": ["10", 0], "upscale_method": "nearest-exact", "megapixels": 1.0, "resolution_steps": 1}),
        "13": node("ImageScaleToTotalPixels", {"image": ["11", 0], "upscale_method": "nearest-exact", "megapixels": 1.0, "resolution_steps": 1}),
        "14": node("VAEEncode", {"pixels": ["12", 0], "vae": ["4", 0]}),
        "15": node("VAEEncode", {"pixels": ["13", 0], "vae": ["4", 0]}),
        "16": node("ReferenceLatent", {"conditioning": ["5", 0], "latent": ["14", 0]}),
        "17": node("ReferenceLatent", {"conditioning": ["16", 0], "latent": ["15", 0]}),
        "18": node("ReferenceLatent", {"conditioning": ["6", 0], "latent": ["14", 0]}),
        "19": node("ReferenceLatent", {"conditioning": ["18", 0], "latent": ["15", 0]}),
        "20": node("GetImageSize", {"image": ["12", 0]}),
        "21": node("EmptyFlux2LatentImage", {"width": ["20", 0], "height": ["20", 1], "batch_size": 1}),
        "22": node("Flux2Scheduler", {"steps": steps, "width": ["20", 0], "height": ["20", 1]}),
        "23": node("KSamplerSelect", {"sampler_name": "euler"}),
        "24": node("CFGGuider", {"model": ["2", 0], "positive": ["17", 0], "negative": ["19", 0], "cfg": cfg}),
        "25": node("RandomNoise", {"noise_seed": seed}),
        "26": node("SamplerCustomAdvanced", {"noise": ["25", 0], "guider": ["24", 0], "sampler": ["23", 0], "sigmas": ["22", 0], "latent_image": ["21", 0]}),
        "27": node("VAEDecode", {"samples": ["26", 0], "vae": ["4", 0]}),
        "28": node("WDBFinish", {"image": ["27", 0], "look": look or "model output"}),
        "29": node("ImageScale", {"image": ["28", 0], "upscale_method": "nearest-exact", "width": 256, "height": 256, "crop": "disabled"}),
        "30": node("SaveImage", {"images": ["29", 0], "filename_prefix": prefix}),
    }


if PromptServer is not None and web is not None:
    @PromptServer.instance.routes.post("/wdb/review")
    async def wdb_review(request):
        try:
            payload = await request.json()
            return web.json_response(_write_review(payload))
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.get("/wdb/status")
    async def wdb_status(request):
        raw = request.query.get("ledger", LEDGER_DEFAULT)
        try:
            return web.json_response({"ok": True, "text": _status_text(raw)})
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.get("/wdb/words")
    async def wdb_words(request):
        try:
            text = words(
                request.query.get("facing", "down"),
                request.query.get("job", "pose still"),
                request.query.get("model", "klein"),
            )
            return web.json_response({"ok": True, "text": text})
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.post("/wdb/save-workflow")
    async def wdb_save_workflow(request):
        try:
            payload = await request.json()
            return web.json_response(_save_workflow(payload))
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.post("/wdb/walk")
    async def wdb_walk(request):
        try:
            import execution

            payload = await request.json()
            which = str(payload.get("which") or "down")
            if which not in CELLS:
                raise ValueError("Pick one facing in Her picture. A walk frame uses one view.")
            folder_name = str(payload.get("folder") or "wdb-walk").strip().replace("\\", "/").strip("/")
            if not folder_name or folder_name.startswith("..") or "/" in folder_name:
                raise ValueError("walk folder must be one folder name inside the Comfy input folder")
            import folder_paths

            folder = Path(folder_paths.get_input_directory()) / folder_name
            frames = sorted(folder.glob("*.png")) if folder.is_dir() else []
            if not frames:
                raise ValueError("No walk test yet. Review the walk clips, mark Good, then Build the walk test.")
            marker = folder / "facing.txt"
            built = marker.read_text(encoding="utf-8").strip() if marker.is_file() else ""
            if built and built != which:
                raise ValueError("These depths are the " + built + " walk. Set Her picture to " + built + ", then queue again.")
            if not (_bible_dir() / f"female-{which}.png").is_file():
                raise ValueError("missing her picture. Stop the Comfy server, then run: python tools/media.py comfy-character setup")
            prompt = str(payload.get("prompt") or words(which, "walk frame", "klein"))
            negative = str(payload.get("negative") or _prompts()["avoid"])
            steps = int(payload.get("steps") or 28)
            cfg = float(payload.get("cfg") or 4)
            seed = int(payload.get("seed") or 7)
            strength = float(payload.get("strength") or 1)
            look = str(payload.get("look") or "model output")
            ids = []
            for frame in frames:
                graph = _walk_graph(
                    f"wdb-bible/female-{which}.png",
                    f"{folder_name}/{frame.name}",
                    prompt, negative, steps, cfg, seed, strength, look,
                    f"wdb/walk/{frame.stem}",
                )
                prompt_id = str(uuid.uuid4())
                valid = await execution.validate_prompt(prompt_id, graph, None)
                if not valid[0]:
                    raise ValueError(str(valid[1]))
                number = PromptServer.instance.number
                PromptServer.instance.number += 1
                extra = {"create_time": int(time.time() * 1000)}
                PromptServer.instance.prompt_queue.put((number, prompt_id, graph, extra, valid[2], {}))
                ids.append(prompt_id)
            return web.json_response({"ok": True, "queued": len(ids)})
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.get("/wdb/walk-reel")
    async def wdb_walk_reel(request):
        try:
            character, facing = _walk_who(request.query.get("character", "female"), request.query.get("facing", "down"))
            root = _repo_root(request.query.get("ledger", LEDGER_DEFAULT))
            reel = root / "_src" / "comfy-character" / "walk-reel" / character / facing
            if not reel.is_dir():
                raise ValueError("No walk frames yet. On the game repo run: python tools/media.py comfy-character walk-reel")
            marks = _pick_map(_picks_file(root), character, facing)
            frames = [{"name": path.name, "mark": marks.get(path.name, "")} for path in sorted(reel.glob("f*.png")) if _frame_ok(path.name)]
            return web.json_response({"ok": True, "facing": facing, "frames": frames})
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.get("/wdb/walk-frame")
    async def wdb_walk_frame(request):
        try:
            character, facing = _walk_who(request.query.get("character", "female"), request.query.get("facing", "down"))
            name = str(request.query.get("name") or "")
            if not _frame_ok(name):
                raise ValueError("bad frame name")
            root = _repo_root(request.query.get("ledger", LEDGER_DEFAULT))
            path = root / "_src" / "comfy-character" / "walk-reel" / character / facing / name
            if not path.is_file():
                raise ValueError("missing frame")
            return web.FileResponse(path)
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.post("/wdb/walk-pick")
    async def wdb_walk_pick(request):
        try:
            payload = await request.json()
            character, facing = _walk_who(payload.get("character", "female"), payload.get("facing", "down"))
            name = str(payload.get("name") or "")
            mark = str(payload.get("mark") or "")
            if not _frame_ok(name):
                raise ValueError("bad frame name")
            if mark not in ("good", "bad", ""):
                raise ValueError("mark must be good or bad")
            root = _repo_root(payload.get("ledger", LEDGER_DEFAULT))
            path = _picks_file(root)
            data = {}
            if path.is_file():
                data = json.loads(path.read_text(encoding="utf-8-sig"))
                if not isinstance(data, dict):
                    data = {}
            faces = data.setdefault(character, {}).setdefault(facing, {})
            if mark:
                faces[name] = mark
            else:
                faces.pop(name, None)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
            return web.json_response({"ok": True})
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)

    @PromptServer.instance.routes.post("/wdb/walk-build")
    async def wdb_walk_build(request):
        try:
            import asyncio

            payload = await request.json()
            character, facing = _walk_who(payload.get("character", "female"), payload.get("facing", "down"))
            root = _repo_root(payload.get("ledger", LEDGER_DEFAULT))
            proc = await asyncio.create_subprocess_exec(
                "python", "tools/media.py", "comfy-character", "walk-build",
                "--name", character, "--cell", facing, "--root", str(root),
                cwd=str(root),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            out, err = await proc.communicate()
            text = (out or b"").decode("utf-8", "replace").strip()
            if proc.returncode != 0:
                detail = (err or b"").decode("utf-8", "replace").strip() or text
                raise ValueError(detail.splitlines()[-1][:300] if detail else "walk build failed")
            line = next((row for row in text.splitlines() if row.startswith("built ")), text.splitlines()[-1] if text else "built")
            return web.json_response({"ok": True, "text": line, "facing": facing})
        except Exception as exc:
            return web.json_response({"ok": False, "error": str(exc)}, status=400)


def _frame_ok(name: str) -> bool:
    return len(name) == 8 and name.startswith("f") and name.endswith(".png") and name[1:4].isdigit()


def _walk_who(character: object, facing: object) -> tuple[str, str]:
    who = str(character or "female")
    face = str(facing or "down")
    if who not in ("female", "male"):
        raise ValueError("character must be female or male")
    if face not in CELLS or face == "face":
        raise ValueError("Pick a body facing. The face cell has no walk clip.")
    return who, face


def _repo_root(raw: object) -> Path:
    return _check_ledger(str(raw or LEDGER_DEFAULT)).parent.parent.parent


def _picks_file(root: Path) -> Path:
    return root / "_src" / "comfy-character" / "walk-picks.json"


def _pick_map(path: Path, character: str, facing: str) -> dict:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    faces = (data.get(character) or {}).get(facing) or {}
    return faces if isinstance(faces, dict) else {}


NODE_CLASS_MAPPINGS = {
    "WDBFinish": WDBFinish,
    "WDBApprove": WDBApprove,
    "WDBFacing": WDBFacing,
    "WDBStyleLock": WDBStyleLock,
    "WDBWords": WDBWords,
    "WDBWalk": WDBWalk,
}
NODE_DISPLAY_NAME_MAPPINGS = {
    "WDBFinish": "4. Finish",
    "WDBApprove": "5. Approve or deny",
    "WDBFacing": "1. Her picture",
    "WDBStyleLock": "Style lock",
    "WDBWords": "Facing words",
    "WDBWalk": "Walk frames",
}
WEB_DIRECTORY = "./web"
