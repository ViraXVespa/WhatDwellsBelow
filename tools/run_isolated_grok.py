#!/usr/bin/env python3
"""Stage a scratch directory outside the git tree and run a thin Grok Build media job.

The parent (game repo) session must not call Imagine unless design/isolated-media.md
lists an in-session exception. This runner copies only the named inputs into a scratch
cwd outside the git tree, writes a kind-specific job.md, runs `grok inspect` (including
with --dry-run), then runs the child generate unless --dry-run. Child cwd must not
discover WhatDwellsBelow/AGENTS.md.

Reference reuse: hashed staged images key a durable scratch under ~/.grok/wdb-iso/.
First run ingests those files in one child session, then forks a generate turn.
Later runs with the same hashes fork from that ingest session (CLI has no rewind;
fork-from-ingest is the same token win). `--no-reuse` keeps the old one-shot tempfile.

Kinds (bundled specialist + Imagine tool):

  tile       imagine + game-assets (tilesets.md)          image_gen / style-only image_edit
  character  imagine + game-assets (characters.md)         image_gen (new Bible) / image_edit (after lock)
  i2v        imagine + game-assets (animation.md)          image_to_video from staged seed
  ui         imagine + staged UI style (ui-style.md here)   image_gen / image_edit; menus, screens, panels, mockups; text allowed
  npc        imagine + game-assets (characters.md)         image_gen; redesign from --brief, --copy old sprite for size / pose
  still      imagine + game-assets (assets.md)             image_gen fallback; do not read animation.md

  python tools/run_isolated_grok.py --kind tile --dry-run --bible-style --keep
  python tools/run_isolated_grok.py --kind tile --bible-style --out /path/out
  python tools/run_isolated_grok.py --kind ui --dest-name mockups/title.png --out design/refs/ui-png-art --brief "..."
  python tools/run_isolated_grok.py --kind i2v --seed seed.png --prompt-file prompt.txt --out /path/out

`--keep` leaves the scratch dir for hand inspection. Without it the temp dir is
deleted after outputs are copied. `--dry-run` still runs inspect; it does not generate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
sys.path.insert(0, str(TOOLS))
from repo_lib import under  # noqa: E402
LOCKED_BIBLES = (
    REPO / "assets" / "sprites" / "player" / "bible_locked_male.png",
    REPO / "assets" / "sprites" / "player" / "bible_locked_female.png",
)
KINDS = ("tile", "character", "i2v", "ui", "npc", "still")
# image_gen / image_edit `aspect_ratio` values in the bundled imagine skill (grok-build skills/imagine/SKILL.md)
ASPECTS = ("1:1", "16:9", "9:16", "4:3", "3:4")
# --kind ui stages the standing UI look: this section of the ui style doc as ui-style.md, plus any image it names (task refs go in with --copy).
UI_STYLE_DOC = REPO / "design" / "ui-style.md"
UI_STYLE_SECTION = "## Generated art look"
INGEST_MAX_TURNS = 4
RESULT_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".mp4", ".webm", ".mov"}
DEFAULT_DEST = {
    "tile": "plaza_roof.png",
    "character": "still.png",
    "i2v": "clip.mp4",
    "ui": "ui.png",
    "npc": "npc.png",
    "still": "still.png",
}

REFERENCE = {
    "tile": "tilesets.md",
    "character": "characters.md",
    "i2v": "animation.md",
    "ui": "",
    "npc": "characters.md",
    "still": "assets.md",
}
SKILLS = "`imagine` and `game-assets`"
STACK = {
    "tile": (
        SKILLS,
        "One tileable world texture. One `image_gen` call, then copy the file into this directory.",
    ),
    "character": (
        SKILLS,
        "One character / overlay still. New Bible: one `image_gen`. After lock: one `image_edit` from the staged base. "
        "Then copy the file into this directory.",
    ),
    "i2v": (
        SKILLS,
        "One Image-to-Video unit from the staged seed and prompt. Then copy the clip into this directory. "
        "Do not harvest or pack frames.",
    ),
    "ui": (
        "`imagine`",
        "One UI still: a menu, screen, panel, HUD or mockup. Text and labels are allowed where the brief asks for them. "
        "Follow `ui-style.md` in this directory when it is staged. One media call, then copy the file into this directory.",
    ),

    "npc": (
        SKILLS,
        "One NPC sprite still, redesigned from the brief. A staged sprite is the old version: match its framing, "
        "pose, facing and body size only; do not keep its look. One `image_gen` call, then copy the file into this directory.",
    ),
    "still": (
        SKILLS,
        "One still. One media call, then copy the file into this directory.",
    ),
}

DEFAULT_BRIEF = {
    "tile": (
        "Seamless Placeholdia roof albedo tile. Uniform stochastic roof texture. "
        "The pattern continues off every edge. No landmark motif, emblem, cap strip, or footer strip. "
        "Neutral lighting. Player must not see the grid when the tile repeats on a 3D roof plane."
    ),
    "character": (
        "One character still that matches the locked Bible identity, proportions, palette, and pixel-art finish. "
        "Opaque #FF00FF plate. Empty hands unless the brief names an overlay."
    ),
    "i2v": "",
    "ui": "One UI screen or panel still in the game's pixel-art style. Readable text where the layout needs it.",

    "npc": (
        "Full-body NPC, whole figure in frame with margin, on an opaque flat #FF00FF plate (no shadow on the plate). "
        "Chunky SNES pixel-art finish matching the hub."
    ),
    "still": "One still. Match the locked Bible palette and pixel-art finish when style sheets are staged.",
}

def _die(msg: str, code: int = 2) -> None:
    print(f"run_isolated_grok: {msg}", file=sys.stderr)
    raise SystemExit(code)

def _which_grok(name: str) -> str | None:
    return shutil.which(name)

def _style_lines(*, use_bibles: bool, kind: str, staged: bool = False) -> str:
    if kind == "npc" and not use_bibles:
        return "A staged sprite is the old version: framing, pose and body size only. The look comes from the brief."
    if not use_bibles and staged:
        return "No locked Bibles were staged. Use the staged images as style and layout references, not exact copies."
    if not use_bibles:
        return (
            "No style-sheet images were staged. Infer a coherent pixel-art finish from the brief only."
        )
    if kind == "character":
        return (
            "Staged `bible_locked_male.png` / `bible_locked_female.png` are identity lock. "
            "Match them. Do not redesign the character. After lock use `image_edit` from that base."
        )
    return (
        "Staged Bibles are style sheets only. Do not open them. Do not draw the character. "
        "Match a chunky SNES pixel-art finish from the brief."
    )

def _parse_keyframe(spec: str) -> tuple[Path, float]:
    if "@" not in spec:
        _die("--keyframe must be path@seconds (Windows paths contain a colon)")
    raw, _, seconds = spec.rpartition("@")
    try:
        stamp = float(seconds)
    except ValueError:
        _die(f"--keyframe seconds are not a number: {spec}")
    if stamp <= 0:
        _die(f"--keyframe timestamp must be inside the clip: {spec}")
    return Path(raw), stamp

def _walk_prompt(path: Path) -> bool:
    return WALK_MARK in path.read_text(encoding="utf-8")

def _tool_lines(kind: str, *, pinned: bool = False) -> str:
    if kind == "i2v" and pinned:
        return (
            "Tools:\n"
            "- Call `reference_to_video` once. Do not call `image_to_video`.\n"
            "- Pass `first_frame` and `last_frame` as the absolute paths named below. "
            "Those stills are literal pins. Do not key them.\n"
            "- Pass staged `--ref` files as `images` only. They are references, not pins.\n"
            "- Pass staged `--keyframe` files as `keyframes` entries `{image, timestamp_s}`. "
            "Timestamps stay exactly as written.\n"
            "- Do not pass `duration`. Do not call `image_gen` or `image_edit`.\n"
        )
    if kind == "i2v":
        return (
            "Tools:\n"
            "- `image_to_video` from the staged first frame.\n"
            "- Do not call `image_gen` unless that seed is missing.\n"
            "- Do not call `image_edit` unless the brief says to repair the seed first.\n"
            "- Do not call `reference_to_video` unless this job names a last frame.\n"
        )
    if kind == "character":
        return (
            "Tools:\n"
            "- `image_gen` only for a brand-new Bible or style candidate with no locked base.\n"
            "- `image_edit` for anything after lock, and for overlays registered to a staged body frame.\n"
            "- Do not call `image_to_video` in this job.\n"
        )
    if kind == "tile":
        return (
            "Tools:\n"
            "- `image_gen` once.\n"
            "- Do not call `image_edit` or `image_to_video`.\n"
            "- Do not open any other `game-assets` reference, list the directory, or run a 2x2 / 4x4 composite. The parent does that.\n"
        )
    return (
        "Tools:\n"
        "- `image_gen` for a brand-new still with no source image.\n"
        "- `image_edit` to iterate the still you just wrote, or to use staged PNGs as style sheets.\n"
        "- Do not call `image_to_video` in this job.\n"
    )

def build_ingest_job(names: list[str]) -> str:
    listed = ", ".join(f"`{n}`" for n in names)
    return (
        "# Isolated ingest\n\n"
        "You are in a scratch directory on purpose. There is no game `AGENTS.md` here.\n\n"
        f"Read these staged files with `read_file` (images as images): {listed}.\n"
        "Do not open skill files. Do not list the directory. Do not generate or edit images.\n"
        "Stop as soon as those files are in this conversation.\n"
    )

def build_job(
    *,
    kind: str,
    brief: str,
    use_bibles: bool,
    dest_name: str,
    seed_name: str = "",
    prompt_name: str = "",
    last_name: str = "",
    ref_names: list[str] | None = None,
    keyframes: list[tuple[str, float]] | None = None,
    ingested: bool = False,
    aspect: str = "",
) -> str:
    skills, specialist = STACK[kind]
    ref = REFERENCE[kind]
    still_note = " Do not read `animation.md`." if kind == "still" else ""
    body = brief.strip() if brief.strip() else DEFAULT_BRIEF[kind]
    brief_block = f"Brief:\n{body}\n\n" if body else ""
    if aspect:
        brief_block += (f"Aspect ratio {aspect}: pass `aspect_ratio: \"{aspect}\"` to `image_gen`, or to `image_edit` with several images. "
                        f"A single-image `image_edit` keeps its source's ratio, so for {aspect} from one source use `image_gen`.\n\n")
    i2v_block = ""
    if kind == "i2v":
        pin_lines = ""
        if last_name:
            refs = ", ".join(f"`{n}`" for n in (ref_names or [])) or "(none)"
            frames = ", ".join(f"`{n}` at {stamp:g}s" for n, stamp in (keyframes or [])) or "(none)"
            pin_lines = (
                f"Last frame: `{last_name}` (same idle still as the first frame when the names match).\n"
                f"Reference images: {refs}\n"
                f"Mid-clip pins: {frames}\n"
            )
        i2v_block = (
            f"First frame: `{seed_name}` (opaque chroma plate — do not key it).\n"
            f"{pin_lines}"
            f"Prompt (use verbatim): `{prompt_name}`\n\n"
        )
    already = (
        "Staged images are already in this conversation. Do not read those images again.\n\n"
        if ingested
        else ""
    )
    return (
        f"# Isolated {kind} job\n\n"
        "You are in a scratch directory on purpose. There is no game `AGENTS.md` here.\n\n"
        f"{already}"
        + (f"Bundled skills for this job: {skills}. Read `{ref}` only.{still_note} "
           "Do not open the other `game-assets` references.\n\n" if ref else
           f"Bundled skills for this job: {skills}. Do not open `game-assets` references; staged images are style references.\n\n")
        + f"{specialist}\n\n"
        f"{_tool_lines(kind, pinned=bool(last_name))}\n"
        f"{_style_lines(use_bibles=use_bibles, kind=kind, staged=ingested)}\n\n"
        f"{i2v_block}"
        f"{brief_block}"
        "One media call. Do not retry. Do not composite. Do not inspect the result beyond copying it.\n"
        f"Imagine may write under the session `images/` folder. Copy that file to `{dest_name}` "
        "in this scratch directory (convert to PNG if needed) and stop.\n"
        "Do not walk a parent repo. Do not edit Godot scenes.\n"
    )

def ui_style_text(doc: Path = UI_STYLE_DOC) -> str:
    """The Generated art look section of the ui style doc; dies when it is missing."""
    lines = doc.read_text(encoding="utf-8-sig").splitlines() if doc.is_file() else []
    out: list[str] = []
    keep = False
    for line in lines:
        if line.startswith("## "):
            keep = line.strip() == UI_STYLE_SECTION
        if keep:
            out.append(line)
    if not out:
        _die(f"--kind ui: no '{UI_STYLE_SECTION}' section in {doc} (pass --no-ui-style to run without the locked look)")
    return "\n".join(out).strip()

def ui_style_refs(text: str) -> list[Path]:
    """Repo image paths named in backticks in the style section; a missing one dies."""
    refs = [REPO / m for m in re.findall(r"`(design/[^`]+\.(?:png|jpg))`", text)]
    for r in refs:
        if not r.is_file():
            _die(f"ui style ref missing: {r}")
    return refs

def safe_dest(name: str) -> str:
    """A relative path inside scratch (subfolders allowed: mockups/title.png)."""
    rel = Path(name)
    if rel.is_absolute() or ".." in rel.parts or not rel.name:
        _die(f"--dest-name must be a relative path inside scratch: {name}")
    return rel.as_posix()

def write_job(path: Path, text: str) -> None:
    path.write_text(text.replace("\r\n", "\n"), encoding="utf-8")

def copy_into(src: Path, dest_dir: Path) -> Path:
    if not src.is_file():
        _die(f"missing input file: {src}")
    dest = dest_dir / src.name
    shutil.copy2(src, dest)
    return dest

def collect_results(scratch: Path, staged_names: set[str]) -> list[Path]:
    out: list[Path] = []
    for child in sorted(scratch.rglob("*")):
        if not child.is_file() or child.name.startswith("."):
            continue
        if child.name in ("job.md", "ingest.md") or child.relative_to(scratch).as_posix() in staged_names:
            continue
        if child.suffix.lower() in RESULT_SUFFIXES:
            out.append(child)
    return out

def grok_home() -> Path:
    env = os.environ.get("GROK_HOME")
    return Path(env) if env else Path.home() / ".grok"

def iso_home() -> Path:
    return grok_home() / "wdb-iso"

def catalog_path() -> Path:
    return iso_home() / "catalog.json"

def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def ref_key(kind: str, sources: list[Path]) -> str:
    h = hashlib.sha256()
    h.update(kind.encode("utf-8"))
    h.update(b"\n")
    for src in sorted(sources, key=lambda p: p.name.lower()):
        h.update(src.name.encode("utf-8"))
        h.update(b"\t")
        h.update(file_sha256(src).encode("ascii"))
        h.update(b"\n")
    return h.hexdigest()

def load_catalog() -> dict:
    path = catalog_path()
    if not path.is_file():
        return {"version": 1, "entries": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"version": 1, "entries": {}}
    if not isinstance(data, dict):
        return {"version": 1, "entries": {}}
    entries = data.get("entries")
    if not isinstance(entries, dict):
        data["entries"] = {}
    return data

def save_catalog(data: dict) -> None:
    path = catalog_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent="\t") + "\n", encoding="utf-8")

def session_alive(session_id: str, cwd: Path) -> bool:
    if not session_id:
        return False
    root = grok_home() / "sessions" / quote(str(cwd.resolve()), safe="") / session_id
    return (root / "summary.json").is_file()

def parse_session_id(text: str) -> str:
    blob = text.strip()
    if not blob:
        return ""
    try:
        obj = json.loads(blob)
    except json.JSONDecodeError:
        start = blob.rfind("{")
        if start < 0:
            return ""
        try:
            obj = json.loads(blob[start:])
        except json.JSONDecodeError:
            return ""
    if not isinstance(obj, dict):
        return ""
    return str(obj.get("sessionId") or obj.get("session_id") or "")

def grok_child_argv(
    grok_bin: str,
    job_path: Path,
    scratch: Path,
    max_turns: int,
    *,
    resume: str | None = None,
    fork: bool = False,
    output_format: str = "plain",
) -> list[str]:
    argv = [grok_bin]
    if resume:
        argv += ["--resume", resume]
        if fork:
            argv.append("--fork-session")
    argv += [
        "--prompt-file",
        str(job_path),
        "--cwd",
        str(scratch),
        "--verbatim",
        "--max-turns",
        str(max_turns),
        "--disable-web-search",
        "--no-subagents",
        "--always-approve",
        "--output-format",
        output_format,
    ]
    return argv

def harvest_session_media(scratch: Path, dest: Path) -> Path | None:
    """If the child left Imagine output in its session folder, copy it to scratch."""
    root = grok_home() / "sessions" / quote(str(scratch), safe="")
    if not root.is_dir():
        return None
    images = [
        p
        for p in root.rglob("*")
        if p.is_file() and p.suffix.lower() in RESULT_SUFFIXES and p.parent.name == "images"
    ]
    if not images:
        return None
    images.sort(key=lambda p: p.stat().st_mtime)
    src = images[-1]
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.suffix.lower() == ".png" and src.suffix.lower() != ".png":
        from PIL import Image

        Image.open(src).convert("RGB").save(dest)
    else:
        shutil.copy2(src, dest)
    return dest

def inspect_mentions_repo_agents(text: str) -> bool:
    low = text.replace("\\", "/").lower()
    if "agents.md" not in low:
        return False
    return "whatdwellsbelow" in low or "dwellsbelow" in low

def inspect_instruction_count(text: str) -> int | None:
    marker = "Project Instructions ("
    start = text.find(marker)
    if start < 0:
        return None
    i = start + len(marker)
    j = text.find(")", i)
    if j < 0 or j - i > 6:
        return None
    raw = text[i:j].strip()
    if raw.lower() == "none":
        return 0
    if not raw.isdigit():
        return None
    return int(raw)

def session_model_calls(scratch: Path) -> int | None:
    root = grok_home() / "sessions" / quote(str(scratch.resolve()), safe="")
    if not root.is_dir():
        return None
    newest: Path | None = None
    newest_mtime = -1.0
    for p in root.glob("*/usage.json"):
        mt = p.stat().st_mtime
        if mt >= newest_mtime:
            newest_mtime = mt
            newest = p
    if newest is None:
        return None
    try:
        data = json.loads(newest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    usage = data.get("modelUsage")
    if not isinstance(usage, dict):
        return None
    total = 0
    found = False
    for row in usage.values():
        if isinstance(row, dict) and "modelCalls" in row:
            total += int(row["modelCalls"])
            found = True
    return total if found else None

def run_cmd(
    argv: list[str],
    *,
    cwd: Path,
    dry_run: bool,
) -> subprocess.CompletedProcess[str] | None:
    print("+", " ".join(argv), f"(cwd={cwd})")
    if dry_run:
        return None
    try:
        return subprocess.run(
            argv,
            cwd=str(cwd),
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError:
        _die(f"executable not found: {argv[0]}")
    return None

FAKE_GROK = """#!/usr/bin/env python3
import re, sys, pathlib
if sys.argv[1:2] == ["inspect"]:
    print("Project Instructions (none)"); sys.exit(0)
job = pathlib.Path(sys.argv[sys.argv.index("--prompt-file") + 1]).read_text()
pathlib.Path("seen-job.txt").write_text(job)
dest = re.search(r"Copy that file to `([^`]+)`", job).group(1)
pathlib.Path(dest).parent.mkdir(parents=True, exist_ok=True)
pathlib.Path(dest).write_bytes(b"\\x89PNG\\r\\n\\x1a\\n")
"""

def selftest() -> int:
    """Mock grok: ui job text, staged style, subfolder dest copied under --out, bad dest refused."""
    bad: list[str] = []
    ui = build_job(kind="ui", brief="", use_bibles=False, dest_name="ui.png")
    for need, ok in (("ui allows text", "Text and labels are allowed" in ui), ("ui no icon rule", "No text in the art" not in ui),
                     ("ui no ui-icons.md", "ui-icons.md" not in ui), ("ui default dest", DEFAULT_DEST["ui"] == "ui.png"),
                     ("aspect in brief", 'aspect_ratio: "16:9"' in build_job(kind="ui", brief="", use_bibles=False, dest_name="a.png", aspect="16:9")),
                     ("npc no identity lock", "identity lock" not in build_job(kind="npc", brief="b", use_bibles=False, dest_name="n.png")),
                     ("npc reads characters.md", "Read `characters.md` only" in build_job(kind="npc", brief="b", use_bibles=False, dest_name="n.png")),
                     ("style section", "No pink" in ui_style_text()), ("style refs exist", isinstance(ui_style_refs(ui_style_text()), list))):
        if not ok:
            bad.append(need)
    with tempfile.TemporaryDirectory(prefix="wdb-iso-st-") as tmp:
        t = Path(tmp)
        fake = t / "grok"
        fake.write_text(FAKE_GROK, encoding="utf-8")
        fake.chmod(0o755)
        me = [sys.executable, str(Path(__file__).resolve()), "--kind", "ui", "--grok", str(fake), "--no-reuse", "--keep"]
        r = subprocess.run(me + ["--dest-name", "mockups/title.png", "--out", str(t / "out")], text=True, capture_output=True)
        keep = next((ln[5:] for ln in r.stdout.splitlines() if ln.startswith("keep=")), "")
        seen = (Path(keep) / "seen-job.txt").read_text() if keep and (Path(keep) / "seen-job.txt").is_file() else ""
        if r.returncode or "dest=ok" not in r.stdout or not (t / "out" / "mockups" / "title.png").is_file():
            bad.append("subfolder dest: " + (r.stdout + r.stderr)[-300:])
        if "ui_style=staged" not in r.stdout or "ui-style.md" not in seen:
            bad.append("ui style not staged")
        if keep:
            shutil.rmtree(keep, ignore_errors=True)
        r = subprocess.run(me + ["--dest-name", "../x.png", "--dry-run"], text=True, capture_output=True)
        if r.returncode == 0:
            bad.append("../ dest accepted")
    for b in bad:
        print("BAD", b)
    print(f"RESULT {'PASS' if not bad else 'FAIL'} cmd=selftest problems={len(bad)}")
    return 1 if bad else 0

def main() -> None:
    if "--selftest" in sys.argv[1:]:
        raise SystemExit(selftest())
    p = argparse.ArgumentParser(epilog="No --root: explicit-path tool, exempt by design (paths are arguments).", 
        description="Run one isolated Grok Build media job outside the game repo."
    )
    p.add_argument("--kind", choices=KINDS, required=True, help="Job kind.")
    p.add_argument("--grok", default="grok", help="Grok Build executable (default: grok)")
    p.add_argument("--max-turns", type=int, default=8, help="Max Grok turns (default 8).")
    p.add_argument("--dry-run", action="store_true", help="Print the plan; generate nothing (inspect still runs unless --skip-inspect).")
    p.add_argument("--keep", action="store_true", help="Do not delete scratch; print its path")
    p.add_argument("--out", type=Path, default=None, help="Copy result media here after the child exits")
    p.add_argument("--job-file", type=Path, default=None, help="Use this markdown as job.md instead of the built-in template")
    p.add_argument("--brief", default="", help="Extra / replacement brief text folded into the built-in job.md")
    p.add_argument("--dest-name", default="", help="Output path inside scratch; subfolders allowed and kept under --out (ui default ui.png)")
    p.add_argument("--copy", type=Path, action="append", default=[], help="Extra file to copy into scratch (repeatable)")
    p.add_argument("--bible-style", action="store_true", help="Copy locked player Bibles as style / identity sheets")
    p.add_argument("--seed", type=Path, default=None, help="I2V first-frame PNG (required for --kind i2v)")
    p.add_argument("--prompt-file", type=Path, default=None, help="I2V prompt text (required for --kind i2v)")
    p.add_argument("--last-frame", type=Path, default=None, help="I2V last-frame pin. Walk defaults this to the idle seed.")
    p.add_argument("--ref", type=Path, action="append", default=[], help="I2V reference image (repeatable). Not a pinned frame.")
    p.add_argument("--keyframe", action="append", default=[], help="I2V mid-clip pin as path@seconds (repeatable, up to 4).")
    p.add_argument("--pin-ends", action="store_true", help="Pin last_frame to the seed even if the prompt is not the walk wrapper.")
    p.add_argument("--no-pin-ends", action="store_true", help="Do not auto-pin a walk. One-shots stay on image_to_video.")
    p.add_argument("--no-ui-style", action="store_true", help="--kind ui: do not stage the locked UI look (design/ui-style.md) and its refs")
    p.add_argument("--aspect", choices=ASPECTS, default="", help="aspect_ratio for image_gen (and multi-image image_edit); single-image edits keep the source ratio")
    p.add_argument("--skip-inspect", action="store_true", help="Skip the `grok inspect` isolation check.")
    p.add_argument(
        "--no-reuse",
        action="store_true",
        help="One-shot tempfile scratch; do not reuse an ingest session",
    )
    args = p.parse_args()

    if args.max_turns < 1:
        _die("--max-turns must be >= 1")
    keyframes: list[tuple[Path, float]] = []
    if args.kind == "i2v":
        if args.seed is None or args.prompt_file is None:
            _die("--kind i2v requires --seed and --prompt-file")
        if args.pin_ends and args.no_pin_ends:
            _die("pass only one of --pin-ends and --no-pin-ends")
        if len(args.keyframe) > 4:
            _die("--keyframe accepts at most 4 mid-clip pins")
        for spec in args.keyframe:
            keyframes.append(_parse_keyframe(spec))
        if args.no_pin_ends:
            pin_last = args.last_frame
        elif args.last_frame is not None:
            pin_last = args.last_frame
        elif args.pin_ends or _walk_prompt(args.prompt_file):
            pin_last = args.seed
        else:
            pin_last = None
    else:
        pin_last = None
        if args.last_frame or args.ref or args.keyframe or args.pin_ends:
            _die("--last-frame, --ref, --keyframe, and --pin-ends are i2v only")
    if args.job_file is not None and not args.job_file.is_file():
        _die(f"--job-file not found: {args.job_file}")
    if args.out is not None:
        args.out = args.out.resolve()
        args.out.mkdir(parents=True, exist_ok=True)

    sources: list[Path] = []
    ui_text = ui_style_text() if args.kind == "ui" and not args.no_ui_style else ""
    if ui_text:
        sources.extend(ui_style_refs(ui_text))
    if args.bible_style:
        bibles = [b for b in LOCKED_BIBLES if b.is_file()]
        if not bibles:
            _die("--bible-style set but locked Bibles are missing under assets/sprites/player/")
        sources.extend(bibles)
    sources.extend(args.copy)
    if args.kind == "i2v":
        assert args.seed is not None and args.prompt_file is not None
        sources.append(args.seed)
        if pin_last is not None and pin_last.resolve() != args.seed.resolve():
            sources.append(pin_last)
        sources.extend(args.ref)
        sources.extend(path for path, _stamp in keyframes)

    ref_sources = [s for s in sources if s.suffix.lower() in RESULT_SUFFIXES]
    use_reuse = (not args.no_reuse) and bool(ref_sources)
    key = ref_key(args.kind, ref_sources) if use_reuse else ""

    scratch_holder: tempfile.TemporaryDirectory[str] | None = None
    if use_reuse:
        scratch = (iso_home() / "work" / key).resolve()
        scratch.mkdir(parents=True, exist_ok=True)
    elif args.keep:
        scratch = Path(tempfile.mkdtemp(prefix="wdb-iso-")).resolve()
    else:
        scratch_holder = tempfile.TemporaryDirectory(prefix="wdb-iso-")
        scratch = Path(scratch_holder.name).resolve()
    if under(scratch, REPO):
        _die(f"scratch resolved inside the game repo: {scratch}")

    try:
        copied: list[str] = []
        for src in sources:
            copy_into(src, scratch)
            copied.append(src.name)
        if args.kind == "ui":
            if ui_text:
                write_job(scratch / "ui-style.md", re.sub(r"`design/(?:[^`/]+/)*([^`/]+\.(?:png|jpg))`", r"`\1`", ui_text) + "\n")
                copied.append("ui-style.md")
            print("ui_style=" + ("staged" if ui_text else "none (--no-ui-style)"))
        if args.kind == "i2v":
            assert args.prompt_file is not None
            copy_into(args.prompt_file, scratch)
            copied.append(args.prompt_file.name)

        dest_name = safe_dest(args.dest_name.strip() or DEFAULT_DEST[args.kind])
        (scratch / dest_name).parent.mkdir(parents=True, exist_ok=True)
        job_path = scratch / "job.md"
        ingest_session = ""
        reuse_state = "off" if args.no_reuse else ("skip-no-refs" if not ref_sources else "miss")
        if use_reuse:
            cat = load_catalog()
            entry = cat.get("entries", {}).get(key)
            if isinstance(entry, dict):
                sid = str(entry.get("session_id", ""))
                if session_alive(sid, scratch):
                    ingest_session = sid
                    reuse_state = "hit"
            print(f"ref_key={key}")
        print(f"reuse={reuse_state}")
        if ingest_session:
            print(f"ingest_session={ingest_session}")

        ingested = bool(ingest_session) or (use_reuse and reuse_state == "miss")
        if args.job_file is not None:
            write_job(job_path, args.job_file.read_text(encoding="utf-8"))
        else:
            seed_name = args.seed.name if args.seed is not None else ""
            prompt_name = args.prompt_file.name if args.prompt_file is not None else ""
            last_name = pin_last.name if pin_last is not None else ""
            ref_names = [path.name for path in args.ref]
            keyframe_names = [(path.name, stamp) for path, stamp in keyframes]
            write_job(
                job_path,
                build_job(
                    kind=args.kind,
                    brief=args.brief,
                    use_bibles=args.bible_style,
                    dest_name=dest_name,
                    seed_name=seed_name,
                    prompt_name=prompt_name,
                    last_name=last_name,
                    ref_names=ref_names,
                    keyframes=keyframe_names,
                    ingested=ingested,
                    aspect=args.aspect,
                ),
            )

        print(f"scratch={scratch}")
        print(f"kind={args.kind}")
        print(f"copied={copied}")
        print(f"job={job_path}")

        grok_bin = args.grok
        resolved = _which_grok(grok_bin)
        if resolved is None and not args.dry_run:
            _die(f"grok executable not on PATH: {grok_bin}")
        if resolved is None and args.dry_run:
            print(f"grok=missing ({grok_bin})")
        if resolved is not None:
            print(f"grok={resolved}")

        # Inspect is not a generate. Run it even on --dry-run so isolation can be proven.
        if not args.skip_inspect:
            if resolved is None:
                print("inspect=skipped (grok not on PATH)")
            else:
                ins = run_cmd([grok_bin, "inspect"], cwd=scratch, dry_run=False)
                if ins is not None:
                    text = (ins.stdout or "") + "\n" + (ins.stderr or "")
                    if inspect_mentions_repo_agents(text):
                        _die("inspect still sees WhatDwellsBelow AGENTS.md; refuse to generate", 3)
                    n = inspect_instruction_count(text)
                    if n is None:
                        _die("inspect missing Project Instructions count", 3)
                    if ins.returncode != 0:
                        _die(f"grok inspect exited {ins.returncode}", ins.returncode)
                    if n != 0:
                        _die(f"inspect Project Instructions ({n}); refuse to generate", 3)
                    print(f"inspect=ok instructions={n}")

        # `--prompt-file` is already single-turn. Do not also pass `-p` /
        # `--single`; current grok requires a value for that flag.
        child_code = 0
        if use_reuse and reuse_state == "miss":
            ingest_path = scratch / "ingest.md"
            write_job(ingest_path, build_ingest_job([p.name for p in ref_sources]))
            print(f"ingest_job={ingest_path}")
            ingest_argv = grok_child_argv(
                grok_bin,
                ingest_path,
                scratch,
                min(INGEST_MAX_TURNS, args.max_turns),
                output_format="json",
            )
            ingest_child = run_cmd(ingest_argv, cwd=scratch, dry_run=args.dry_run)
            if ingest_child is not None:
                if ingest_child.stderr:
                    sys.stderr.write(ingest_child.stderr)
                if ingest_child.returncode != 0:
                    sys.stdout.write(ingest_child.stdout or "")
                    _die(f"grok ingest exited {ingest_child.returncode}", ingest_child.returncode)
                ingest_session = parse_session_id(ingest_child.stdout or "")
                if not ingest_session:
                    sys.stdout.write(ingest_child.stdout or "")
                    _die("grok ingest did not return sessionId", 2)
                print(f"ingest_session={ingest_session}")
                cat = load_catalog()
                entries = cat.setdefault("entries", {})
                entries[key] = {
                    "kind": args.kind,
                    "session_id": ingest_session,
                    "cwd": str(scratch),
                    "files": [p.name for p in ref_sources],
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
                save_catalog(cat)
            elif args.dry_run:
                print("ingest_session=(dry-run)")

        gen_resume = ingest_session if use_reuse and ingest_session else None
        argv = grok_child_argv(
            grok_bin,
            job_path,
            scratch,
            args.max_turns,
            resume=gen_resume,
            fork=bool(gen_resume),
            output_format="plain",
        )
        child = run_cmd(argv, cwd=scratch, dry_run=args.dry_run)
        if child is not None:
            # Parent only needs dest status; the full child transcript is noise.
            # Keep stderr on failure. Do not dump the child's reasoning or tool calls.
            if child.returncode != 0 and child.stderr:
                sys.stderr.write(child.stderr)
            child_code = int(child.returncode)

        results = collect_results(scratch, set(copied))
        dest_path = scratch / dest_name
        rel = lambda r: r.relative_to(scratch).as_posix()  # noqa: E731
        if dest_name not in {rel(r) for r in results}:
            harvested = harvest_session_media(scratch, dest_path)
            if harvested is not None:
                print(f"harvest={harvested}")
                results = collect_results(scratch, set(copied))
        print("results=" + ",".join(rel(r) for r in results))
        dest_ok = dest_name in {rel(r) for r in results}
        print("dest=" + ("ok" if dest_ok else "missing"))
        calls = session_model_calls(scratch)
        if calls is not None:
            print(f"modelCalls={calls}")
        if child_code != 0:
            _die(f"grok child exited {child_code}", child_code)
        if args.out is not None:
            named = [r for r in results if rel(r) == dest_name]
            for src in named or results:
                target = args.out / rel(src)
                if not args.dry_run:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, target)
                print(f"out={target}")
        if args.keep or use_reuse:
            print(f"keep={scratch}")
    finally:
        if scratch_holder is not None:
            scratch_holder.cleanup()

if __name__ == "__main__":
    main()
