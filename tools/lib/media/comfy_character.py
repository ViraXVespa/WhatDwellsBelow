#!/usr/bin/env python3
"""Local Comfy character pipeline and the approve / deny book.

Open the GUI workflow (after setup) and follow the note on the left.
Headless runs read that same book: the last Approve becomes the next
reference, and Deny notes are added to the avoid text.

Stop the Comfy server before setup. Generated pictures under depth,
walk-reel, walk-test, walk-good, frames, and lora-set stay out of git.
ledger.json and walk-picks.json stay in git.

    python tools/media.py comfy-character setup
    python tools/media.py comfy-character install
    python tools/media.py comfy-character status
    python tools/media.py comfy-character review --no --note "shading is washed out"
    python tools/media.py comfy-character run --dry-run
    python tools/media.py comfy-character export-set --dry-run
    python tools/media.py comfy-character depth --cell side
    python tools/media.py comfy-character walk-reel
    python tools/media.py comfy-character walk-build --cell side

Summary: _logs/comfy-character/<stamp>-comfy-character.txt.
"""
from __future__ import annotations

import ast
import json
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
from PIL import Image

CELL_ORDER = [
    "up_left", "up", "up_right",
    "left", "face", "right",
    "down_left", "down", "down_right",
]
CELL_ALIAS = {"front": "down", "side": "left", "back": "up"}
WALK_FACINGS = [name for name in CELL_ORDER if name != "face"]
PICKS_REL = Path("_src/comfy-character/walk-picks.json")
# Pictures under these folders are gitignored. setup rebuilds the depths and the reel.
REEL_REL = Path("_src/comfy-character/walk-reel")
DEPTH_REL = Path("_src/comfy-character/depth")
WALK_TEST_REL = Path("_src/comfy-character/walk-test")
WALK_FPS = 8
# Titles on the style page. The same words are the WDBStyleLock input names.
BIBLE_VIEW = [
    ("up_left", "Up left"),
    ("up", "Up"),
    ("up_right", "Up right"),
    ("left", "Left"),
    ("face", "Face"),
    ("right", "Right"),
    ("down_left", "Down left"),
    ("down", "Down"),
    ("down_right", "Down right"),
]
SHEET = Path("_src/new_bibles/female.png")
BOOK = Path("_src/comfy-character/ledger.json")
NODE_SRC = Path("tools/data/comfy_wdb_character")
WORKFLOW_REL = Path("tools/data/comfy-character-workflow.json")
UNET = "flux-2-klein-base-4b-fp8.safetensors"
LORA = "flux2_klein_4b_refcontrol_depth.safetensors"
CLIP = "qwen_3_4b_fp4_flux2.safetensors"
VAE = "flux2-vae.safetensors"
LEDGER_DEFAULT = r"C:\Users\Vira\source\repos\WhatDwellsBelow\_src\comfy-character\ledger.json"
CAPTION = "wdbfemale, pixel art woman, flat colors, hard edges, magenta background"
MIN_YES = 15
STEP = {
    "1": ("#8ec8f8", "#1c3d5c"),
    "2": ("#8ee0c8", "#1c4638"),
    "3": ("#d8e89a", "#3c4818"),
    "4": ("#f0c888", "#5c3c18"),
    "5": ("#e0b0e8", "#4c2450"),
}
PIPE = ("#9aa4b0", "#2a3038")


def _prompt_path() -> Path:
    return Path(__file__).resolve().parents[2] / "data" / "comfy_wdb_character" / "prompts.json"


def _prompt_data() -> dict:
    path = _prompt_path()
    if not path.is_file():
        agent_log.fail("missing comfy character prompts")
    return json.loads(path.read_text(encoding="utf-8"))


def cell_name(name: str) -> str:
    return CELL_ALIAS.get(name, name)


def keep_for(facing: str, job: str, model: str) -> str:
    data = _prompt_data()
    key = cell_name(facing)
    if key == "face":
        view = "The face cell from the bible. Keep this face and this hair."
        identity = data["identity"]["female"]
    elif key == "up":
        view = data["facing"]["up"]
        identity = data["identity"]["female_up"]
    elif key in data["facing"]:
        view = data["facing"][key]
        identity = data["identity"]["female"]
    else:
        agent_log.fail(f"unknown facing {facing}")
    if model == "sdxl":
        template = data["sdxl_style"]
    elif job == "walk frame":
        template = data["klein_walk"]
    else:
        template = data["klein_still"]
    return template.format(facing=view, identity=identity)


def _avoid() -> str:
    return _prompt_data()["avoid"]


def comfy_root() -> Path | None:
    import os

    env = os.environ.get("WDB_COMFY_ROOT", "").strip()
    guess = Path(env) if env else Path(r"C:\Users\Vira\AppData\Local\Comfy-Desktop")
    return guess if guess.is_dir() else None


def _install_root(root: Path) -> Path | None:
    base = comfy_root()
    if base is None:
        return None
    install = base / "ComfyUI-Installs" / "ComfyUI" / "ComfyUI"
    return install if install.is_dir() else None


def _input_dir() -> Path | None:
    base = comfy_root()
    if base is None:
        return None
    folder = base / "ComfyUI-Shared" / "input"
    return folder if folder.is_dir() else None


def _venv_python() -> Path | None:
    install = _install_root(Path("."))
    if install is None:
        return None
    py = install / ".venv" / "Scripts" / "python.exe"
    return py if py.is_file() else None


def load_book(path: Path) -> dict:
    if not path.is_file():
        return {"runs": []}
    book = json.loads(path.read_text(encoding="utf-8-sig"))
    book.setdefault("runs", [])
    return book


def save_book(path: Path, book: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(book, indent=2) + "\n", encoding="utf-8", newline="\n")


def avoid_notes(book: dict, character: str, limit: int = 5) -> list[str]:
    notes = []
    for row in book.get("runs") or []:
        if row.get("character") != character or row.get("review") != "no":
            continue
        text = str(row.get("note") or "").strip()
        if text:
            notes.append(text)
    return notes[-limit:]


def negative_for(book: dict, character: str, base: str | None = None) -> str:
    text = _avoid() if base is None else base
    notes = avoid_notes(book, character)
    if not notes:
        return text
    return text + ", avoid: " + "; ".join(notes)


def latest_yes(book: dict, character: str) -> dict | None:
    found = [
        row for row in book.get("runs") or []
        if row.get("character") == character and row.get("review") == "yes" and row.get("frame")
    ]
    return found[-1] if found else None


def _node(nid: int, ntype: str, pos: list, size: list, widgets: list, inputs: list, outputs: list, title: str | None = None, step: str = "", collapsed: bool = False) -> dict:
    header, body = STEP.get(step, PIPE)
    node = {
        "id": nid,
        "type": ntype,
        "pos": pos,
        "size": size,
        "flags": {"collapsed": True} if collapsed else {},
        "order": nid,
        "mode": 0,
        "inputs": inputs,
        "outputs": outputs,
        "properties": {"Node name for S/R": ntype},
        "widgets_values": widgets,
        "color": header,
        "bgcolor": body,
    }
    if title:
        node["title"] = title
    return node


def _pipe(nid: int, slot: int, ntype: str, widgets: list, inputs: list, outputs: list, title: str, y: int = 790) -> dict:
    return _node(nid, ntype, [44 + slot * 156, y], [148, 70], widgets, inputs, outputs, title, collapsed=True)


def _in(name: str, typ: str, widget: bool = False) -> dict:
    slot = {"localized_name": name, "name": name, "type": typ, "link": None}
    if widget:
        slot["widget"] = {"name": name}
    return slot


def _out(name: str, typ: str) -> dict:
    return {"localized_name": name, "name": name, "type": typ, "links": []}


def _wire(nodes: list[dict], edges: list[tuple]) -> list:
    by_id = {node["id"]: node for node in nodes}
    links = []
    for index, (src, src_slot, dst, dst_slot, typ) in enumerate(edges, start=1):
        links.append([index, src, src_slot, dst, dst_slot, typ])
        by_id[dst]["inputs"][dst_slot]["link"] = index
        by_id[src]["outputs"][src_slot]["links"].append(index)
    return links


def _group(title: str, box: list, color: str) -> dict:
    return {"title": title, "bounding": box, "color": color, "font_size": 24, "flags": {}}


def ui_workflow() -> dict:
    """Five step columns. The model row under them stays collapsed."""
    note = (
        "Read across the five steps, then press Queue Prompt.\n\n"
        "1. Who she is. Down is the front. Left is the side. Up is the back.\n"
        "2. The pose. This depth matches the left facing.\n"
        "3. Words. Click Use these words. The crown braid is hair, not a circlet.\n"
        "4. Knobs. Strength 1, steps 28, guidance 4. Leave the seed fixed.\n"
        "5. Decide. Approve or Deny writes the book and does not redraw.\n"
        "   Save knobs stores this page in the game repo.\n\n"
        "The gray row is wiring. Leave those nodes collapsed.\n"
        "Pose depth stays on the side depth. The other cells are in that\n"
        "same list: wdb-depth-down.png and one file per facing.\n"
        "Walk: Review the walk clips, mark Good or Bad, Build the walk test,\n"
        "then Queue the walk folder. Set Her picture to that same facing.\n"
        "A new machine runs: python tools/media.py comfy-character setup.\n"
        "Whole-bible shading is the other page: WDB Style lock."
    )
    keep = keep_for("down", "pose still", "klein")
    avoid = _avoid()
    nodes = [
        _node(1, "MarkdownNote", [44, 56], [380, 640], [note], [], [], "Start here", "1"),
        _node(2, "WDBFacing", [440, 56], [380, 250], ["down"],
              [_in("which", "COMBO", True)], [_out("IMAGE", "IMAGE")], "1. Her picture", "1"),
        _node(31, "WDBWords", [440, 330], [380, 200], ["down", "pose still"],
              [_in("facing", "COMBO", True), _in("job", "COMBO", True)], [_out("words", "STRING")], "Facing words", "1"),
        _node(3, "LoadImage", [884, 56], [380, 320], ["female-side-depth-hard.png", "image"],
              [_in("image", "COMBO", True)], [_out("IMAGE", "IMAGE"), _out("MASK", "MASK")], "2. Pose depth", "2"),
        _node(32, "WDBWalk", [884, 400], [380, 240], ["wdb-walk"],
              [_in("folder", "STRING", True)], [_out("folder", "STRING")], "Walk frames", "2"),
        _node(8, "CLIPTextEncode", [1324, 56], [440, 280], [keep],
              [_in("clip", "CLIP"), _in("text", "STRING", True)], [_out("CONDITIONING", "CONDITIONING")],
              "3. What to keep", "3"),
        _node(9, "CLIPTextEncode", [1324, 360], [440, 280], [avoid],
              [_in("clip", "CLIP"), _in("text", "STRING", True)], [_out("CONDITIONING", "CONDITIONING")],
              "3. What to avoid", "3"),
        _node(5, "LoraLoaderModelOnly", [1824, 56], [380, 140], [LORA, 1.0],
              [_in("model", "MODEL"), _in("lora_name", "COMBO", True), _in("strength_model", "FLOAT", True)],
              [_out("MODEL", "MODEL")], "Style strength", "4"),
        _node(20, "Flux2Scheduler", [1824, 220], [380, 130], [28, 1024, 1024],
              [_in("steps", "INT", True), _in("width", "INT", True), _in("height", "INT", True)],
              [_out("SIGMAS", "SIGMAS")], "Steps", "4"),
        _node(22, "CFGGuider", [1824, 370], [380, 150], [4.0],
              [_in("model", "MODEL"), _in("positive", "CONDITIONING"), _in("negative", "CONDITIONING"), _in("cfg", "FLOAT", True)],
              [_out("GUIDER", "GUIDER")], "Guidance", "4"),
        _node(23, "RandomNoise", [1824, 540], [380, 100], [7, "fixed"],
              [_in("noise_seed", "INT", True)], [_out("NOISE", "NOISE")], "Seed", "4"),
        _node(26, "WDBFinish", [2264, 56], [400, 110], ["model output"],
              [_in("image", "IMAGE"), _in("look", "COMBO", True)], [_out("IMAGE", "IMAGE")], "4. Finish", "5"),
        _node(27, "ImageScale", [2264, 186], [400, 150], ["nearest-exact", 256, 256, "disabled"],
              [_in("image", "IMAGE"), _in("upscale_method", "COMBO", True), _in("width", "INT", True), _in("height", "INT", True), _in("crop", "COMBO", True)],
              [_out("IMAGE", "IMAGE")], "Down to 256", "5"),
        _node(28, "SaveImage", [2264, 356], [400, 90], ["wdb/gui-character-256"],
              [_in("images", "IMAGE"), _in("filename_prefix", "STRING", True)], [], "Save the 256", "5"),
        _node(30, "WDBApprove", [2264, 466], [400, 220],
              ["Say what is wrong, or what to keep.", "female", LEDGER_DEFAULT],
              [_in("image", "IMAGE"), _in("note", "STRING", True), _in("character", "STRING", True), _in("ledger", "STRING", True)],
              [_out("IMAGE", "IMAGE")], "5. Approve or deny", "5"),
        _pipe(4, 0, "UNETLoader", [UNET, "default"],
              [_in("unet_name", "COMBO", True), _in("weight_dtype", "COMBO", True)], [_out("MODEL", "MODEL")], "Picture model"),
        _pipe(6, 1, "CLIPLoader", [CLIP, "flux2", "default"],
              [_in("clip_name", "COMBO", True), _in("type", "COMBO", True), _in("device", "COMBO", True)], [_out("CLIP", "CLIP")], "Text model"),
        _pipe(7, 2, "VAELoader", [VAE],
              [_in("vae_name", "COMBO", True)], [_out("VAE", "VAE")], "Color model"),
        _pipe(10, 3, "ImageScaleToTotalPixels", ["nearest-exact", 1, 1],
              [_in("image", "IMAGE"), _in("upscale_method", "COMBO", True), _in("megapixels", "FLOAT", True), _in("resolution_steps", "INT", True)],
              [_out("IMAGE", "IMAGE")], "Scale the pose"),
        _pipe(11, 4, "ImageScaleToTotalPixels", ["nearest-exact", 1, 1],
              [_in("image", "IMAGE"), _in("upscale_method", "COMBO", True), _in("megapixels", "FLOAT", True), _in("resolution_steps", "INT", True)],
              [_out("IMAGE", "IMAGE")], "Scale her picture"),
        _pipe(12, 5, "VAEEncode", [], [_in("pixels", "IMAGE"), _in("vae", "VAE")], [_out("LATENT", "LATENT")], "Encode the pose"),
        _pipe(13, 6, "VAEEncode", [], [_in("pixels", "IMAGE"), _in("vae", "VAE")], [_out("LATENT", "LATENT")], "Encode her picture"),
        _pipe(14, 7, "ReferenceLatent", [], [_in("conditioning", "CONDITIONING"), _in("latent", "LATENT")], [_out("CONDITIONING", "CONDITIONING")], "Keep + pose"),
        _pipe(15, 8, "ReferenceLatent", [], [_in("conditioning", "CONDITIONING"), _in("latent", "LATENT")], [_out("CONDITIONING", "CONDITIONING")], "Keep + her picture"),
        _pipe(16, 9, "ReferenceLatent", [], [_in("conditioning", "CONDITIONING"), _in("latent", "LATENT")], [_out("CONDITIONING", "CONDITIONING")], "Avoid + pose"),
        _pipe(17, 10, "ReferenceLatent", [], [_in("conditioning", "CONDITIONING"), _in("latent", "LATENT")], [_out("CONDITIONING", "CONDITIONING")], "Avoid + her picture"),
        _pipe(18, 11, "GetImageSize", [], [_in("image", "IMAGE")], [_out("width", "INT"), _out("height", "INT"), _out("batch", "INT")], "Pose size"),
        _pipe(19, 12, "EmptyFlux2LatentImage", [1024, 1024, 1],
              [_in("width", "INT", True), _in("height", "INT", True), _in("batch_size", "INT", True)], [_out("LATENT", "LATENT")], "Empty canvas"),
        _pipe(21, 13, "KSamplerSelect", ["euler"], [_in("sampler_name", "COMBO", True)], [_out("SAMPLER", "SAMPLER")], "Euler"),
        _pipe(24, 14, "SamplerCustomAdvanced", [],
              [_in("noise", "NOISE"), _in("guider", "GUIDER"), _in("sampler", "SAMPLER"), _in("sigmas", "SIGMAS"), _in("latent_image", "LATENT")],
              [_out("output", "LATENT"), _out("denoised_output", "LATENT")], "Draw"),
        _pipe(25, 15, "VAEDecode", [], [_in("samples", "LATENT"), _in("vae", "VAE")], [_out("IMAGE", "IMAGE")], "Decode"),
        _pipe(29, 16, "SaveImage", ["wdb/gui-character"],
              [_in("images", "IMAGE"), _in("filename_prefix", "STRING", True)], [], "Save the large one"),
    ]
    edges = [
        (4, 0, 5, 0, "MODEL"),
        (6, 0, 8, 0, "CLIP"),
        (6, 0, 9, 0, "CLIP"),
        (3, 0, 10, 0, "IMAGE"),
        (2, 0, 11, 0, "IMAGE"),
        (10, 0, 12, 0, "IMAGE"),
        (7, 0, 12, 1, "VAE"),
        (11, 0, 13, 0, "IMAGE"),
        (7, 0, 13, 1, "VAE"),
        (8, 0, 14, 0, "CONDITIONING"),
        (12, 0, 14, 1, "LATENT"),
        (14, 0, 15, 0, "CONDITIONING"),
        (13, 0, 15, 1, "LATENT"),
        (9, 0, 16, 0, "CONDITIONING"),
        (12, 0, 16, 1, "LATENT"),
        (16, 0, 17, 0, "CONDITIONING"),
        (13, 0, 17, 1, "LATENT"),
        (10, 0, 18, 0, "IMAGE"),
        (18, 0, 19, 0, "INT"),
        (18, 1, 19, 1, "INT"),
        (18, 0, 20, 1, "INT"),
        (18, 1, 20, 2, "INT"),
        (5, 0, 22, 0, "MODEL"),
        (15, 0, 22, 1, "CONDITIONING"),
        (17, 0, 22, 2, "CONDITIONING"),
        (23, 0, 24, 0, "NOISE"),
        (22, 0, 24, 1, "GUIDER"),
        (21, 0, 24, 2, "SAMPLER"),
        (20, 0, 24, 3, "SIGMAS"),
        (19, 0, 24, 4, "LATENT"),
        (24, 0, 25, 0, "LATENT"),
        (7, 0, 25, 1, "VAE"),
        (25, 0, 26, 0, "IMAGE"),
        (26, 0, 27, 0, "IMAGE"),
        (27, 0, 28, 0, "IMAGE"),
        (26, 0, 29, 0, "IMAGE"),
        (27, 0, 30, 0, "IMAGE"),
    ]
    links = _wire(nodes, edges)
    return {
        "id": "wdb-character",
        "revision": 0,
        "last_node_id": 32,
        "last_link_id": len(links),
        "nodes": nodes,
        "links": links,
        "groups": [
            _group("Step 1. Who she is", [24, 20, 820, 700], STEP["1"][0]),
            _group("Step 2. The pose", [864, 20, 420, 700], STEP["2"][0]),
            _group("Step 3. Words", [1304, 20, 480, 700], STEP["3"][0]),
            _group("Step 4. Knobs", [1804, 20, 420, 700], STEP["4"][0]),
            _group("Step 5. Decide", [2244, 20, 440, 700], STEP["5"][0]),
            _group("Wiring. Leave this row collapsed.", [24, 750, 2680, 140], PIPE[0]),
        ],
        "definitions": {"subgraphs": []},
        "config": {},
        "extra": {"wdb": "character"},
        "version": 0.4,
    }


def _check_links(wf: dict) -> list[str]:
    bad = []
    by_id = {node["id"]: node for node in wf["nodes"]}
    for link in wf["links"]:
        lid, src, src_slot, dst, dst_slot, typ = link
        if src not in by_id or dst not in by_id:
            bad.append(f"link {lid} missing node")
            continue
        try:
            out = by_id[src]["outputs"][src_slot]
            inn = by_id[dst]["inputs"][dst_slot]
        except IndexError:
            bad.append(f"link {lid} bad slot")
            continue
        if out["type"] != typ or inn["type"] != typ:
            bad.append(f"link {lid} type {typ}")
        if lid not in out["links"] or inn["link"] != lid:
            bad.append(f"link {lid} not attached")
    return bad


def check_workflow(wf: dict) -> list[str]:
    bad = _check_links(wf)
    titles = {node.get("title") for node in wf["nodes"]}
    for need in ("1. Her picture", "2. Pose depth", "3. What to keep", "3. What to avoid", "Style strength", "Steps", "Guidance", "Seed", "4. Finish", "5. Approve or deny"):
        if need not in titles:
            bad.append(f"missing title {need}")
    if any(node["id"] == 2 and node["type"] != "WDBFacing" for node in wf["nodes"]):
        bad.append("her picture is not the facing picker")
    return bad


def _load_image(nid: int, pos: list, size: list, filename: str, title: str, step: str) -> dict:
    """LoadImage lists only the input folder root, so filename has no slash."""
    return _node(
        nid, "LoadImage", pos, size, [filename, "image"],
        [_in("image", "COMBO", True)], [_out("IMAGE", "IMAGE"), _out("MASK", "MASK")], title, step,
    )


def style_workflow() -> dict:
    """SDXL page. The nine cells and the sheet sit in step 2 and feed the style lock."""
    note = (
        "This page restyles one picture. The bible cells are the style lock.\n\n"
        "1. Picture to restyle. It starts as the front cell, Down.\n"
        "   Drop a pose you just made onto that box.\n"
        "2. The bible. Nine cells, in the same 3x3 as the sheet.\n"
        "   Full sheet is that 3x3 as one picture.\n"
        "   Style lock: all nine averaged, the sheet, or one cell.\n"
        "3. Words. Click Use these words, then edit if you want.\n"
        "4. Style strength is the IP-Adapter. 0.8 is the start.\n"
        "   Sampler knobs: the last number is how much to repaint.\n"
        "   0.45 keeps the pose. 1 redraws it.\n"
        "5. Queue Prompt, then Approve or Deny.\n\n"
        "This page does not turn her. New poses are WDB Character.\n"
        "The gray row is the model load. Leave it collapsed."
    )
    keep = keep_for("down", "pose still", "sdxl")
    avoid = _avoid()
    lock_inputs = [_in("which", "COMBO", True)]
    for _key, label in BIBLE_VIEW:
        lock_inputs.append(_in(label, "IMAGE"))
    lock_inputs.append(_in("Full sheet", "IMAGE"))
    nodes = [
        _node(1, "MarkdownNote", [44, 56], [380, 280], [note], [], [], "Start here", "1"),
        _load_image(2, [44, 360], [380, 320], "wdb-bible-down.png", "Picture to restyle", "1"),
        _node(3, "WDBStyleLock", [1240, 380], [300, 560], ["all nine cells, averaged"],
              lock_inputs, [_out("IMAGE", "IMAGE")], "Style lock", "2"),
        _node(8, "CLIPTextEncode", [1604, 64], [440, 280], [keep],
              [_in("clip", "CLIP"), _in("text", "STRING", True)], [_out("CONDITIONING", "CONDITIONING")],
              "3. What to keep", "3"),
        _node(9, "CLIPTextEncode", [1604, 370], [440, 240], [avoid],
              [_in("clip", "CLIP"), _in("text", "STRING", True)], [_out("CONDITIONING", "CONDITIONING")],
              "3. What to avoid", "3"),
        _node(18, "WDBWords", [1604, 640], [440, 180], ["down", "pose still"],
              [_in("facing", "COMBO", True), _in("job", "COMBO", True)], [_out("words", "STRING")], "Facing words", "3"),
        _node(7, "IPAdapterAdvanced", [2104, 64], [400, 280],
              [0.8, "style transfer", "average", 0.0, 1.0, "V only"],
              [_in("model", "MODEL"), _in("ipadapter", "IPADAPTER"), _in("image", "IMAGE"),
               _in("weight", "FLOAT", True), _in("weight_type", "COMBO", True), _in("combine_embeds", "COMBO", True),
               _in("start_at", "FLOAT", True), _in("end_at", "FLOAT", True), _in("embeds_scaling", "COMBO", True)],
              [_out("MODEL", "MODEL"), _out("face", "IMAGE")], "Style strength", "4"),
        _node(11, "KSampler", [2104, 380], [400, 340], [7, "fixed", 25, 6.0, "euler", "normal", 0.45],
              [_in("model", "MODEL"), _in("seed", "INT", True), _in("steps", "INT", True), _in("cfg", "FLOAT", True),
               _in("sampler_name", "COMBO", True), _in("scheduler", "COMBO", True),
               _in("positive", "CONDITIONING"), _in("negative", "CONDITIONING"), _in("latent_image", "LATENT"),
               _in("denoise", "FLOAT", True)],
              [_out("LATENT", "LATENT")], "Sampler knobs", "4"),
        _node(13, "WDBFinish", [2564, 64], [400, 110], ["model output"],
              [_in("image", "IMAGE"), _in("look", "COMBO", True)], [_out("IMAGE", "IMAGE")], "4. Finish", "5"),
        _node(14, "ImageScale", [2564, 190], [400, 150], ["nearest-exact", 256, 256, "disabled"],
              [_in("image", "IMAGE"), _in("upscale_method", "COMBO", True), _in("width", "INT", True), _in("height", "INT", True), _in("crop", "COMBO", True)],
              [_out("IMAGE", "IMAGE")], "Down to 256", "5"),
        _node(15, "SaveImage", [2564, 360], [400, 90], ["wdb/gui-style-256"],
              [_in("images", "IMAGE"), _in("filename_prefix", "STRING", True)], [], "Save the 256", "5"),
        _node(17, "WDBApprove", [2564, 470], [400, 260],
              ["Say what is wrong, or what to keep.", "female", LEDGER_DEFAULT],
              [_in("image", "IMAGE"), _in("note", "STRING", True), _in("character", "STRING", True), _in("ledger", "STRING", True)],
              [_out("IMAGE", "IMAGE")], "5. Approve or deny", "5"),
        _load_image(28, [1240, 64], [300, 290], "wdb-bible-sheet.png", "Full sheet", "2"),
        _pipe(4, 0, "CheckpointLoaderSimple", ["sd_xl_base_1.0.safetensors"],
              [_in("ckpt_name", "COMBO", True)], [_out("MODEL", "MODEL"), _out("CLIP", "CLIP"), _out("VAE", "VAE")], "SDXL checkpoint", 1060),
        _pipe(5, 1, "VAELoader", ["sdxl-vae-fp16-fix.safetensors"],
              [_in("vae_name", "COMBO", True)], [_out("VAE", "VAE")], "SDXL color model", 1060),
        _pipe(6, 2, "IPAdapterUnifiedLoader", ["PLUS (high strength)"],
              [_in("model", "MODEL"), _in("preset", "COMBO", True)],
              [_out("MODEL", "MODEL"), _out("IPADAPTER", "IPADAPTER")], "IP-Adapter loader", 1060),
        _pipe(10, 3, "VAEEncode", [], [_in("pixels", "IMAGE"), _in("vae", "VAE")], [_out("LATENT", "LATENT")], "Encode the picture", 1060),
        _pipe(12, 4, "VAEDecode", [], [_in("samples", "LATENT"), _in("vae", "VAE")], [_out("IMAGE", "IMAGE")], "Decode", 1060),
        _pipe(16, 5, "SaveImage", ["wdb/gui-style"],
              [_in("images", "IMAGE"), _in("filename_prefix", "STRING", True)], [], "Save the large one", 1060),
    ]
    edges = [
        (4, 0, 6, 0, "MODEL"),
        (6, 0, 7, 0, "MODEL"),
        (6, 1, 7, 1, "IPADAPTER"),
        (3, 0, 7, 2, "IMAGE"),
        (4, 1, 8, 0, "CLIP"),
        (4, 1, 9, 0, "CLIP"),
        (2, 0, 10, 0, "IMAGE"),
        (5, 0, 10, 1, "VAE"),
        (7, 0, 11, 0, "MODEL"),
        (8, 0, 11, 6, "CONDITIONING"),
        (9, 0, 11, 7, "CONDITIONING"),
        (10, 0, 11, 8, "LATENT"),
        (11, 0, 12, 0, "LATENT"),
        (5, 0, 12, 1, "VAE"),
        (12, 0, 13, 0, "IMAGE"),
        (13, 0, 14, 0, "IMAGE"),
        (13, 0, 16, 0, "IMAGE"),
        (14, 0, 15, 0, "IMAGE"),
        (14, 0, 17, 0, "IMAGE"),
        (28, 0, 3, 10, "IMAGE"),
    ]
    for index, (key, _label) in enumerate(BIBLE_VIEW):
        col, row = index % 3, index // 3
        nodes.append(_load_image(
            19 + index, [484 + col * 252, 64 + row * 262], [240, 250],
            f"wdb-bible-{key}.png", BIBLE_VIEW[index][1], "2",
        ))
        edges.append((19 + index, 0, 3, index + 1, "IMAGE"))
    links = _wire(nodes, edges)
    return {
        "id": "wdb-style-lock",
        "revision": 0,
        "last_node_id": 28,
        "last_link_id": len(links),
        "nodes": nodes,
        "links": links,
        "groups": [
            _group("Step 1. Picture to restyle", [24, 20, 420, 1000], STEP["1"][0]),
            _group("Step 2. The bible", [464, 20, 1100, 1000], STEP["2"][0]),
            _group("Step 3. Words", [1584, 20, 480, 1000], STEP["3"][0]),
            _group("Step 4. How strongly", [2084, 20, 440, 1000], STEP["4"][0]),
            _group("Step 5. Decide", [2544, 20, 440, 1000], STEP["5"][0]),
            _group("Wiring. Leave this row collapsed.", [24, 1040, 2960, 140], PIPE[0]),
        ],
        "definitions": {"subgraphs": []},
        "config": {},
        "extra": {"wdb": "style"},
        "version": 0.4,
    }


def check_style(wf: dict) -> list[str]:
    bad = _check_links(wf)
    titles = {node.get("title") for node in wf["nodes"]}
    for need in ("Picture to restyle", "Style lock", "Sampler knobs", "Facing words", "Full sheet"):
        if need not in titles:
            bad.append(f"missing title {need}")
    for _key, label in BIBLE_VIEW:
        if label not in titles:
            bad.append(f"missing bible cell {label}")
    types = {node["type"] for node in wf["nodes"]}
    if "IPAdapterAdvanced" not in types or "WDBStyleLock" not in types:
        bad.append("style lock nodes missing")
    for node in wf["nodes"]:
        if node["type"] != "LoadImage":
            continue
        name = str(node["widgets_values"][0])
        if "/" in name or "\\" in name or not name.startswith("wdb-bible-"):
            bad.append("image is not a root bible file: " + name)
    lock = next(node for node in wf["nodes"] if node["type"] == "WDBStyleLock")
    names = [slot["name"] for slot in lock["inputs"]]
    expect = ["which"] + [label for _key, label in BIBLE_VIEW] + ["Full sheet"]
    if names != expect:
        bad.append("style lock inputs " + ", ".join(names))
    if any(slot.get("link") is None for slot in lock["inputs"] if slot["name"] != "which"):
        bad.append("a bible picture is not wired into the style lock")
    return bad


def _crop_cell(sheet: Path, cell: str, dest: Path) -> None:
    key = cell_name(cell)
    if key not in CELL_ORDER:
        agent_log.fail("unknown cell " + cell + " (front, side, back, or a facing name)")
    index = CELL_ORDER.index(key)
    row, col = divmod(index, 3)
    box = (col * 256, row * 256, col * 256 + 256, row * 256 + 256)
    im = Image.open(sheet).convert("RGB")
    if im.size != (768, 768):
        agent_log.fail(f"bible sheet is {im.size[0]}x{im.size[1]}, expected 768x768")
    im.crop(box).save(dest)


def publish_bible(root: Path, folder: Path) -> int:
    sheet = root / SHEET
    if not sheet.is_file():
        agent_log.fail(f"missing bible sheet {SHEET.as_posix()}")
    im = Image.open(sheet).convert("RGB")
    if im.size != (768, 768):
        agent_log.fail(f"bible sheet is {im.size[0]}x{im.size[1]}, expected 768x768")
    folder.mkdir(parents=True, exist_ok=True)
    flat = folder.parent
    im.save(folder / "female-sheet.png")
    im.save(flat / "wdb-bible-sheet.png")
    written = 1
    for index, name in enumerate(CELL_ORDER):
        row, col = divmod(index, 3)
        box = (col * 256, row * 256, col * 256 + 256, row * 256 + 256)
        crop = im.crop(box)
        crop.save(folder / f"female-{name}.png")
        crop.save(flat / f"wdb-bible-{name}.png")
        written += 1
    return written


def _post(server: str, path: str, payload: dict | None = None, timeout: int = 180) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(server + path, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as exc:
        agent_log.fail(exc.read().decode("utf-8", "replace")[:500])
    except urllib.error.URLError as exc:
        agent_log.fail(f"Comfy is not answering at {server} ({exc.reason})")
    return json.loads(raw) if raw else {}


def api_graph(ref_name: str, depth_name: str, prompt: str, negative: str, steps: int, cfg: float, seed: int, strength: float) -> dict:
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
        "28": node("SaveImage", {"images": ["27", 0], "filename_prefix": "wdb/cli-character"}),
        "29": node("ImageScale", {"image": ["27", 0], "upscale_method": "nearest-exact", "width": 256, "height": 256, "crop": "disabled"}),
        "30": node("SaveImage", {"images": ["29", 0], "filename_prefix": "wdb/cli-character-256"}),
    }


def _selftest(args, root: Path) -> int:
    bad = check_workflow(ui_workflow())
    bad.extend(check_style(style_workflow()))
    down = keep_for("down", "pose still", "klein")
    if "refcontrol" not in down or "not a worn circlet" not in down:
        bad.append("klein words")
    if "neckband" in keep_for("up", "pose still", "klein"):
        bad.append("up words mention the neckband")
    if "refcontrol" in keep_for("down", "pose still", "sdxl"):
        bad.append("style words include the pose trigger")
    node_py = root / NODE_SRC / "__init__.py"
    js = root / NODE_SRC / "web" / "review.js"
    if not node_py.is_file() or not js.is_file():
        bad.append("missing comfy node source")
    else:
        ast.parse(node_py.read_text(encoding="utf-8"))
        script = js.read_text(encoding="utf-8")
        if "Approve" not in script or "Deny" not in script or "Review the walk clips" not in script or "Build the walk test" not in script or "Queue the walk folder" not in script:
            bad.append("review buttons missing")
        sample = {"female": {"left": {"f001.png": "good", "f002.png": "bad", "nope.txt": "good"}}}
        if good_names(sample, "female", "left") != ["f001.png"]:
            bad.append("good frame pick")
        square = Image.new("RGB", (4, 4), (255, 0, 255))
        square.putpixel((0, 0), (180, 20, 20))
        square_canvas, square_mask = letterbox_depth_input(square, side=8)
        if square_canvas.size != (8, 8) or square_mask.getpixel((0, 0)) != 255 or square_mask.getpixel((7, 7)) != 0:
            bad.append("square depth should stay full-bleed")
        portrait = Image.new("RGB", (4, 16), (255, 0, 255))
        for y in range(4, 12):
            portrait.putpixel((1, y), (180, 20, 20))
        portrait_canvas, portrait_mask = letterbox_depth_input(portrait, side=32)
        body_cols = [x for x in range(32) if any(portrait_mask.getpixel((x, y)) > 127 for y in range(32))]
        body_rows = [y for y in range(32) if any(portrait_mask.getpixel((x, y)) > 127 for x in range(32))]
        tall = body_rows and body_cols and (body_rows[-1] - body_rows[0]) > (body_cols[-1] - body_cols[0]) * 2
        if portrait_canvas.size != (32, 32) or portrait_mask.getpixel((0, 16)) != 0 or not tall:
            bad.append("walk depth squashes a portrait frame")
        style = style_workflow()
        lock = next(node for node in style["nodes"] if node["type"] == "WDBStyleLock")
        node_text = node_py.read_text(encoding="utf-8")
        for slot in lock["inputs"]:
            if slot["name"] not in node_text:
                bad.append("style input missing on the node: " + slot["name"])
    with tempfile.TemporaryDirectory() as tmp:
        book_path = Path(tmp) / "ledger.json"
        book = {"runs": []}
        book["runs"].append({
            "id": "t1", "character": "female", "review": "no", "note": "shading washed out", "frame": "a.png",
        })
        book["runs"].append({
            "id": "t2", "character": "female", "review": "yes", "note": "closer", "frame": "_src/comfy-character/frames/t2.png",
        })
        save_book(book_path, book)
        loaded = load_book(book_path)
        if latest_yes(loaded, "female")["id"] != "t2":
            bad.append("latest yes")
        if "shading washed out" not in negative_for(loaded, "female"):
            bad.append("deny note was not added")
    echo = "selftest ok" if not bad else "\n".join(bad)
    return agent_log.finish(
        "comfy-character", root, echo, "FAIL" if bad else "PASS",
        args=args, echo=echo, problems=len(bad),
    )


def _install(args, root: Path) -> int:
    install = _install_root(root)
    lines = ["install"]
    if install is None:
        lines.append("comfy not installed")
        return agent_log.finish("comfy-character", root, "\n".join(lines), "INFO" if args.dry_run else "FAIL", args=args, echo="\n".join(lines), installed=0)
    wf = ui_workflow()
    style = style_workflow()
    bad = check_workflow(wf) + check_style(style)
    if bad:
        agent_log.fail("; ".join(bad))
    node_dest = install / "custom_nodes" / "ComfyUI_WDB_Character"
    pose_path = install / "user" / "default" / "workflows" / "WDB Character.json"
    style_path = install / "user" / "default" / "workflows" / "WDB Style lock.json"
    stale = install / "blueprints" / "WDB Character.json"
    lines.append("pose page, style page, and bible cells ready" if args.dry_run else "installed pose page, style page, and bible cells")
    lines.append("open WDB Character and WDB Style lock from the workflow list")
    if not args.dry_run:
        src = root / NODE_SRC
        try:
            if node_dest.exists():
                shutil.rmtree(node_dest)
            shutil.copytree(src, node_dest)
        except OSError:
            agent_log.fail("close the Comfy server, then run setup again")
        pose_text = json.dumps(wf, indent=2) + "\n"
        style_text = json.dumps(style, indent=2) + "\n"
        for path, text in ((pose_path, pose_text), (style_path, style_text)):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8", newline="\n")
        (root / WORKFLOW_REL).write_text(pose_text, encoding="utf-8", newline="\n")
        repo_dir = root / "tools" / "data" / "comfy-workflows"
        repo_dir.mkdir(parents=True, exist_ok=True)
        (repo_dir / "WDB Character.json").write_text(pose_text, encoding="utf-8", newline="\n")
        (repo_dir / "WDB Style lock.json").write_text(style_text, encoding="utf-8", newline="\n")
        if stale.is_file():
            stale.unlink()
        folder = _input_dir()
        if folder is not None:
            publish_bible(root, folder / "wdb-bible")
            (folder / "wdb-walk").mkdir(parents=True, exist_ok=True)
    echo = "\n".join(lines)
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, installed=0 if args.dry_run else 1)


def _status(args, root: Path) -> int:
    book = load_book(root / BOOK)
    rows = [row for row in book["runs"] if not args.name or row.get("character") == args.name]
    lines = []
    for row in rows:
        lines.append(f"{row.get('id')} {row.get('character')} {row.get('review') or 'pending'} {row.get('note') or ''}".rstrip())
    if not lines:
        lines = ["no runs yet"]
    yes = sum(1 for row in rows if row.get("review") == "yes")
    head = f"runs={len(rows)} yes={yes} lora_wants={MIN_YES}"
    echo = "\n".join(agent_log.fold(lines, args.verbose) + [head])
    body = "\n".join(lines + [head])
    return agent_log.finish("comfy-character", root, body, "PASS", args=args, echo=echo, runs=len(rows), yes=yes)


def _review(args, root: Path) -> int:
    if args.yes == args.no:
        agent_log.fail("pass --yes or --no")
    decision = "yes" if args.yes else "no"
    path = root / BOOK
    book = load_book(path)
    rows = [row for row in book["runs"] if row.get("character") == args.name]
    target = None
    if args.id:
        target = next((row for row in rows if row.get("id") == args.id), None)
        if target is None:
            agent_log.fail(f"no run {args.id}")
    else:
        pending = [row for row in rows if not row.get("review")]
        target = pending[-1] if pending else (rows[-1] if rows else None)
        if target is None:
            agent_log.fail("no run to review; queue a picture first")
    if args.dry_run:
        echo = f"would mark {target.get('id')} {decision}"
        return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, review=decision)
    target["review"] = decision
    if args.note:
        target["note"] = args.note
    if not args.dry_run:
        save_book(path, book)
    echo = f"{target.get('id')} {decision}"
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, review=decision)


def _export(args, root: Path) -> int:
    book = load_book(root / BOOK)
    yes = [row for row in book["runs"] if row.get("character") == args.name and row.get("review") == "yes"]
    out = Path(args.out)
    if not out.is_absolute():
        out = root / out
    count = len(yes) + (9 if args.include_bible else 0)
    rel = agent_log.rel(root, out) if str(out).startswith(str(root)) else args.out
    if args.dry_run:
        echo = f"would export {count} pictures to {rel}"
        return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, exported=count)
    out.mkdir(parents=True, exist_ok=True)
    written = 0
    for row in yes:
        src = root / str(row["frame"])
        if not src.is_file():
            agent_log.fail(f"missing yes frame {row['frame']}")
        dest = out / f"{row['id']}.png"
        shutil.copy2(src, dest)
        dest.with_suffix(".txt").write_text(CAPTION + "\n", encoding="utf-8", newline="\n")
        written += 1
    if args.include_bible:
        sheet = root / SHEET
        if not sheet.is_file():
            agent_log.fail(f"missing bible sheet {SHEET.as_posix()}")
        im = Image.open(sheet).convert("RGB")
        if im.size != (768, 768):
            agent_log.fail(f"bible sheet is {im.size[0]}x{im.size[1]}, expected 768x768")
        for index, name in enumerate(CELL_ORDER):
            row, col = divmod(index, 3)
            box = (col * 256, row * 256, col * 256 + 256, row * 256 + 256)
            im.crop(box).save(out / f"bible-{name}.png")
            (out / f"bible-{name}.txt").write_text(CAPTION + "\n", encoding="utf-8", newline="\n")
            written += 1
    echo = f"exported {written} pictures. a LoRA wants about {MIN_YES} crisp ones"
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, exported=written)


def load_picks(path: Path) -> dict:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    return data if isinstance(data, dict) else {}


def save_picks(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")


def good_names(data: dict, character: str, facing: str) -> list[str]:
    faces = (data.get(character) or {}).get(facing) or {}
    if not isinstance(faces, dict):
        return []
    return sorted(name for name, mark in faces.items() if mark == "good" and _frame_name_ok(str(name)))


def _frame_name_ok(name: str) -> bool:
    return len(name) == 8 and name.startswith("f") and name.endswith(".png") and name[1:4].isdigit()


def letterbox_depth_input(image: Image.Image, side: int = 1024) -> tuple[Image.Image, Image.Image]:
    """Nearest-fit a pose onto a black square. A portrait walk frame keeps its shape.

    Square bible cells stay full-bleed. A portrait frame is cropped to the body
    first, then fitted, so the figure fills the long side without being squashed.
    """
    import numpy as np

    rgb = image.convert("RGB")
    arr = np.asarray(rgb)
    magenta = (arr[:, :, 0] > 240) & (arr[:, :, 1] < 30) & (arr[:, :, 2] > 240)
    if arr.shape[0] != arr.shape[1] and magenta.size and not bool(magenta.all()):
        body = ~magenta
        if body.any():
            ys, xs = np.where(body)
            pad = max(2, int(round(0.02 * max(arr.shape[0], arr.shape[1]))))
            y0 = max(0, int(ys.min()) - pad)
            y1 = min(arr.shape[0], int(ys.max()) + 1 + pad)
            x0 = max(0, int(xs.min()) - pad)
            x1 = min(arr.shape[1], int(xs.max()) + 1 + pad)
            arr = arr[y0:y1, x0:x1]
            magenta = magenta[y0:y1, x0:x1]
    painted = arr.copy()
    painted[magenta] = 0
    height, width = painted.shape[:2]
    scale = side / float(max(width, height))
    fitted_w = max(1, min(side, int(round(width * scale))))
    fitted_h = max(1, min(side, int(round(height * scale))))
    picture = Image.fromarray(painted, "RGB").resize((fitted_w, fitted_h), Image.Resampling.NEAREST)
    mask = Image.fromarray((~magenta).astype(np.uint8) * 255, "L").resize((fitted_w, fitted_h), Image.Resampling.NEAREST)
    canvas = Image.new("RGB", (side, side), (0, 0, 0))
    fitted_mask = Image.new("L", (side, side), 0)
    origin = ((side - fitted_w) // 2, (side - fitted_h) // 2)
    canvas.paste(picture, origin)
    fitted_mask.paste(mask, origin)
    return canvas, fitted_mask


def _depth_jobs(poses: list[tuple[Path, Path, list[Path]]], script: Path, jobs_path: Path) -> None:
    payload = [
        {"src": str(src), "mask": str(mask), "outs": [str(dest) for dest in outs]}
        for src, mask, outs in poses
    ]
    jobs_path.write_text(json.dumps(payload), encoding="utf-8")
    script.write_text(
        "import json\n"
        "from pathlib import Path\n"
        "import numpy as np\n"
        "from PIL import Image\n"
        "from transformers import pipeline\n"
        f"jobs = json.loads(Path(r'{jobs_path}').read_text(encoding='utf-8'))\n"
        "pipe = pipeline('depth-estimation', model='depth-anything/Depth-Anything-V2-Small-hf')\n"
        "for job in jobs:\n"
        "    image = Image.open(job['src']).convert('RGB')\n"
        "    mask = Image.open(job['mask']).convert('L')\n"
        "    depth = pipe(image)['depth']\n"
        "    if depth.size != image.size:\n"
        "        depth = depth.resize(image.size, Image.Resampling.BILINEAR)\n"
        "    values = np.asarray(depth).astype(np.float32)\n"
        "    body = np.asarray(mask) > 127\n"
        "    peak = float(values[body].max()) if body.any() else 1.0\n"
        "    floor = float(values[body].min()) if body.any() else 0.0\n"
        "    span = max(peak - floor, 1.0)\n"
        "    gray = np.zeros(values.shape, dtype=np.uint8)\n"
        "    gray[body] = np.clip((values[body] - floor) / span * 255.0, 0, 255).astype(np.uint8)\n"
        "    picture = Image.fromarray(gray, 'L').convert('RGB')\n"
        "    for dest in job['outs']:\n"
        "        Path(dest).parent.mkdir(parents=True, exist_ok=True)\n"
        "        picture.save(dest)\n"
        "    print(Path(job['outs'][0]).name)\n",
        encoding="utf-8",
        newline="\n",
    )


def _run_depth(py: Path, poses: list[tuple[Path, list[Path]]]) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        prepared: list[tuple[Path, Path, list[Path]]] = []
        for index, (src, outs) in enumerate(poses):
            with Image.open(src) as image:
                canvas, mask = letterbox_depth_input(image)
            picture = folder / f"in-{index}.png"
            mask_path = folder / f"mask-{index}.png"
            canvas.save(picture)
            mask.save(mask_path)
            prepared.append((picture, mask_path, outs))
        script = folder / "depth.py"
        jobs_path = folder / "jobs.json"
        _depth_jobs(prepared, script, jobs_path)
        proc = subprocess.run([str(py), str(script)], capture_output=True, text=True, timeout=900)
    if proc.returncode != 0:
        agent_log.fail(proc.stderr.strip().splitlines()[-1][:200] if proc.stderr.strip() else "depth failed")


def _depth(args, root: Path) -> int:
    if args.all and args.pose:
        agent_log.fail("--all reads the bible cells")
    cells = list(CELL_ORDER) if args.all else [cell_name(args.cell)]
    for cell in cells:
        if cell not in CELL_ORDER:
            agent_log.fail("unknown cell " + args.cell + " (front, side, back, or a facing such as down_left)")
    if args.dry_run:
        echo = "would write 9 cell depths" if args.all else "would write wdb-pose-depth.png"
        return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo)
    folder = _input_dir()
    py = _venv_python()
    if folder is None or py is None:
        agent_log.fail("Comfy input folder or its venv python is missing")
    sheet = root / SHEET
    if not args.pose and not sheet.is_file():
        agent_log.fail(f"missing bible sheet {SHEET.as_posix()}")
    names = []
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        poses = []
        if args.pose:
            src = Path(args.pose)
            if not src.is_file():
                src = root / args.pose
            if not src.is_file():
                agent_log.fail(f"missing pose {args.pose}")
            pose = tmp_path / "pose.png"
            Image.open(src).convert("RGB").save(pose)
            poses.append((pose, [folder / "wdb-pose-depth.png"]))
            names.append("wdb-pose-depth.png")
        else:
            for cell in cells:
                pose = tmp_path / f"{cell}.png"
                _crop_cell(sheet, cell, pose)
                outs = [root / DEPTH_REL / f"{cell}.png", folder / f"wdb-depth-{cell}.png"]
                if not args.all:
                    outs.append(folder / "wdb-pose-depth.png")
                poses.append((pose, outs))
                names.append(f"wdb-depth-{cell}.png")
        _run_depth(py, poses)
    echo = "\n".join(agent_log.fold(names, False) + [f"depth {len(names)}"])
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, depth=len(names))


def _clip_path(root: Path, character: str, facing: str) -> Path:
    return root / "_src" / "sources" / "clips" / "walk_final" / f"{character}_{facing}.mp4"


def _walk_reel(args, root: Path) -> int:
    if args.name not in ("female", "male"):
        agent_log.fail("walk clips are female or male")
    missing = [name for name in WALK_FACINGS if not _clip_path(root, args.name, name).is_file()]
    if missing:
        agent_log.fail("missing walk clip " + missing[0])
    if args.dry_run:
        echo = f"would extract {len(WALK_FACINGS)} walk clips at {WALK_FPS} fps"
        return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo)
    from pack_locomotion import extract

    lines = []
    for facing in WALK_FACINGS:
        frames = extract(_clip_path(root, args.name, facing), root / REEL_REL / args.name / facing, fps=WALK_FPS, reuse=True)
        lines.append(f"{facing} {len(frames)}")
    echo = "\n".join(lines + [f"reel {len(WALK_FACINGS)}"])
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, facings=len(WALK_FACINGS))


def _walk_build(args, root: Path) -> int:
    facing = cell_name(args.cell)
    if facing == "face":
        agent_log.fail("the face cell has no walk clip")
    if facing not in WALK_FACINGS:
        agent_log.fail("unknown cell " + args.cell + " (front, side, back, or a facing such as down_left)")
    names = good_names(load_picks(root / PICKS_REL), args.name, facing)
    if args.dry_run:
        echo = f"would build {len(names)} {facing} frames"
        return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, frames=len(names))
    if not names:
        agent_log.fail(f"no Good frames for {facing}. Mark Good on Review the walk clips, then build again.")
    reel = root / REEL_REL / args.name / facing
    missing = [name for name in names if not (reel / name).is_file()]
    if missing:
        agent_log.fail("missing reel frame " + missing[0] + ". Run walk-reel first.")
    folder = _input_dir()
    py = _venv_python()
    if folder is None or py is None:
        agent_log.fail("Comfy input folder or its venv python is missing")
    walk = folder / "wdb-walk"
    walk.mkdir(parents=True, exist_ok=True)
    for old in walk.glob("*.png"):
        old.unlink()
    poses = []
    numbered = []
    for index, name in enumerate(names, start=1):
        label = f"{index:02d}.png"
        outs = [root / WALK_TEST_REL / args.name / facing / label, walk / label]
        poses.append((reel / name, outs))
        numbered.append(label)
    _run_depth(py, poses)
    (walk / "facing.txt").write_text(facing + "\n", encoding="utf-8", newline="\n")
    kept = root / "_src" / "comfy-character" / "walk-good" / args.name / facing
    kept.mkdir(parents=True, exist_ok=True)
    for old in kept.glob("*.png"):
        old.unlink()
    for name in names:
        shutil.copy2(reel / name, kept / name)
    echo = f"built {len(numbered)} {facing}"
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, frames=len(numbered))


def _setup(args, root: Path) -> int:
    if args.dry_run:
        echo = "\n".join([
            "would install the pose page and the style page",
            "would write 9 cell depths",
            f"would extract {len(WALK_FACINGS)} walk clips at {WALK_FPS} fps",
            "depth, walk-reel, walk-test, walk-good, frames, and lora-set stay out of git",
        ])
        return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo)
    lines = []
    steps = (["install"], ["depth", "--all"], ["walk-reel", "--name", args.name])
    for step in steps:
        proc = subprocess.run(
            [sys.executable, str(root / "tools" / "media.py"), "comfy-character", *step, "--root", str(root)],
            cwd=root,
            capture_output=True,
            text=True,
        )
        out = (proc.stdout or "").strip()
        err = (proc.stderr or "").strip()
        if proc.returncode != 0:
            detail = (err or out or "setup failed").splitlines()[-1]
            agent_log.fail(detail[:200])
        kept = [row for row in out.splitlines() if row and not row.startswith("RESULT")]
        lines.append(kept[-1] if kept else step[0])
    lines.append("open WDB Character and WDB Style lock from the workflow list")
    echo = "\n".join(lines)
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo)


def _stage_named(src: Path, folder: Path, name: str) -> str:
    dest = folder / name
    shutil.copy2(src, dest)
    return name


def _run(args, root: Path) -> int:
    book = load_book(root / BOOK)
    negative = negative_for(book, args.name, args.negative or None)
    yes = latest_yes(book, args.name)
    ref_note = "latest yes" if yes and not args.ref else (args.ref or f"cell {args.cell}")
    pose_note = args.pose or "side depth"
    if args.dry_run:
        echo = "\n".join([
            f"character {args.name}",
            f"ref {ref_note}",
            f"pose {pose_note}",
            f"notes {len(avoid_notes(book, args.name))}",
            f"steps {args.steps} guidance {args.cfg} seed {args.seed}",
        ])
        return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, queued=0)
    folder = _input_dir()
    if folder is None:
        agent_log.fail("Comfy input folder is missing")
    stamp = time.strftime("%Y%m%d-%H%M%S")
    if args.ref:
        ref_path = Path(args.ref)
        if not ref_path.is_file():
            ref_path = root / args.ref
        if not ref_path.is_file():
            agent_log.fail(f"missing ref {args.ref}")
    elif yes:
        ref_path = root / str(yes["frame"])
        if not ref_path.is_file():
            agent_log.fail(f"missing yes frame {yes['frame']}")
    else:
        ref_path = root / SHEET
        if not ref_path.is_file():
            agent_log.fail(f"missing bible sheet {SHEET.as_posix()}")
        cropped = folder / f"wdb-ref-{stamp}.png"
        _crop_cell(ref_path, args.cell, cropped)
        ref_path = cropped
    if args.pose:
        pose_path = Path(args.pose)
        if not pose_path.is_file():
            pose_path = root / args.pose
        if not pose_path.is_file():
            agent_log.fail(f"missing pose {args.pose}")
    else:
        pose_path = folder / "female-side-depth-hard.png"
        if not pose_path.is_file():
            agent_log.fail("missing female-side-depth-hard.png in the Comfy input folder; run depth --cell side")
    ref_name = _stage_named(ref_path, folder, f"wdb-ref-{stamp}.png")
    depth_name = _stage_named(pose_path, folder, f"wdb-depth-{stamp}.png")
    facing = args.cell if not (args.ref or yes) else "down"
    prompt = args.prompt or keep_for(facing, "pose still", "klein")
    queued = _post(args.server, "/prompt", {"prompt": api_graph(ref_name, depth_name, prompt, negative, args.steps, args.cfg, args.seed, args.strength)})
    if queued.get("node_errors"):
        agent_log.fail("Comfy rejected the graph")
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        agent_log.fail("Comfy did not return a prompt id")
    deadline = time.time() + 900
    item = None
    while time.time() < deadline:
        history = _post(args.server, f"/history/{prompt_id}")
        if prompt_id in history:
            item = history[prompt_id]
            break
        time.sleep(5)
    if not item or not item.get("status", {}).get("completed"):
        agent_log.fail("Comfy run did not finish")
    images = item.get("outputs", {}).get("30", {}).get("images") or []
    if not images:
        agent_log.fail("Comfy saved no 256 picture")
    info = images[0]
    query = urllib.parse.urlencode({
        "filename": info["filename"], "subfolder": info.get("subfolder", ""), "type": info.get("type", "output"),
    })
    with urllib.request.urlopen(args.server + "/view?" + query, timeout=60) as resp:
        raw = resp.read()
    frame_rel = Path("_src/comfy-character/frames") / f"{stamp}.png"
    dest = root / frame_rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(raw)
    book["runs"].append({
        "id": stamp,
        "character": args.name,
        "source": "cli",
        "frame": frame_rel.as_posix(),
        "ref": ref_name,
        "pose": depth_name,
        "prompt": prompt,
        "negative": negative,
        "seed": args.seed,
        "steps": args.steps,
        "cfg": args.cfg,
        "strength": args.strength,
        "review": None,
        "note": args.note or "",
    })
    save_book(root / BOOK, book)
    echo = f"queued {stamp} frame {frame_rel.as_posix()}"
    return agent_log.finish("comfy-character", root, echo, "PASS", args=args, echo=echo, queued=1)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(
        "Comfy character GUI plus the approve/deny book.\n\n"
        "setup     install the pages, write every cell depth, extract the walk clips\n"
        "install   copy the workflow into Comfy\n"
        "run       one headless picture (the book picks the last Approve)\n"
        "review    mark the latest picture --yes or --no\n"
        "status    list the book\n"
        "export-set  copy Approve pictures for a later LoRA\n"
        "depth     one cell, or --all for every bible cell\n"
        "walk-reel extract the walk clips so the page can mark frames\n"
        "walk-build turn Good frames of one facing into the walk test\n\n"
        "Stop the Comfy server before setup.\n"
        "depth, walk-reel, walk-test, walk-good, frames, and lora-set stay out of git.\n"
        "ledger.json and walk-picks.json stay in git.",
        writes=True,
        verbose=True,
    )
    ap.add_argument("cmd", nargs="?", default="", help="setup, install, run, review, status, export-set, depth, walk-reel, or walk-build")
    ap.add_argument("--all", action="store_true", help="With depth, write one gray depth for every bible cell.")
    ap.add_argument("--selftest", action="store_true", help="Check the workflow wires and the book logic; write nothing.")
    ap.add_argument("--name", default="female", help="Character name. female or male for the walk clips. Default: female.")
    ap.add_argument("--id", default="", help="Run id to review. Default: the latest unmarked run.")
    ap.add_argument("--yes", action="store_true", help="Mark the run approved.")
    ap.add_argument("--no", action="store_true", help="Mark the run denied.")
    ap.add_argument("--note", default="", help="What to keep, or what is wrong.")
    ap.add_argument("--cell", default="front", help="Bible cell when there is no Approve yet. front, side, back, or a facing such as down_left.")
    ap.add_argument("--ref", default="", help="Reference picture. Default: last Approve, else the bible cell.")
    ap.add_argument("--pose", default="", help="Pose or depth picture. Default: the side depth already in Comfy.")
    ap.add_argument("--prompt", default="", help="What to keep. Default includes refcontrol and flat colors.")
    ap.add_argument("--negative", default="", help="What to avoid. Deny notes are added on the end.")
    ap.add_argument("--steps", type=int, default=28, help="Sampler steps. 28 is the tested value. Higher is slower.")
    ap.add_argument("--cfg", type=float, default=4.0, help="Guidance. 4 is the value this LoRA was trained with.")
    ap.add_argument("--seed", type=int, default=7, help="Seed. Stays fixed unless you change it.")
    ap.add_argument("--strength", type=float, default=1.0, help="Style strength. 1 follows the picture and the pose.")
    ap.add_argument("--server", default="http://127.0.0.1:8188", help="Comfy server.")
    ap.add_argument("--out", default="_src/comfy-character/lora-set", help="Folder for export-set pictures and captions.")
    ap.add_argument("--include-bible", action="store_true", help="Also export the nine bible cells. Those are the crisp pictures.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.selftest:
        return _selftest(args, root)
    cmd = args.cmd
    if cmd not in ("setup", "install", "run", "review", "status", "export-set", "depth", "walk-reel", "walk-build"):
        agent_log.fail("choose a command: setup, install, run, review, status, export-set, depth, walk-reel, walk-build")
    if cmd == "setup":
        return _setup(args, root)
    if cmd == "install":
        return _install(args, root)
    if cmd == "status":
        return _status(args, root)
    if cmd == "review":
        return _review(args, root)
    if cmd == "export-set":
        return _export(args, root)
    if cmd == "depth":
        return _depth(args, root)
    if cmd == "walk-reel":
        return _walk_reel(args, root)
    if cmd == "walk-build":
        return _walk_build(args, root)
    return _run(args, root)


if __name__ == "__main__":
    try:
        if not {"--selftest", "--dry-run", "--json", "--help", "-h"} & set(sys.argv[1:]):
            import media.mobile_ui_server as studio_server
            studio_server.start_background()
    except Exception:
        pass
    raise SystemExit(main())
