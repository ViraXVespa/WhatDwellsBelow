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

  tile       game-asset-core + game-tilesets + imagine     image_gen / style-only image_edit
  character  game-asset-core + game-character-consistency  image_gen (new Bible) / image_edit (after lock)
  i2v        game-asset-core + game-animation-frames       image_to_video from staged seed
  ui         game-asset-core + game-ui-icons + imagine     image_gen / image_edit
  still      game-asset-core + imagine                     image_gen fallback

  python tools/run_isolated_grok.py --kind tile --dry-run --bible-style --keep
  python tools/run_isolated_grok.py --kind tile --bible-style --out /path/out
  python tools/run_isolated_grok.py --kind i2v --seed seed.png --prompt-file prompt.txt --out /path/out

`--keep` leaves the scratch dir for hand inspection. Without it the temp dir is
deleted after outputs are copied. `--dry-run` still runs inspect; it does not generate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
LOCKED_BIBLES = (
    REPO / "assets" / "sprites" / "player" / "bible_locked_male.png",
    REPO / "assets" / "sprites" / "player" / "bible_locked_female.png",
)
KINDS = ("tile", "character", "i2v", "ui", "still")
INGEST_MAX_TURNS = 4
RESULT_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".mp4", ".webm", ".mov"}
DEFAULT_DEST = {
    "tile": "plaza_roof.png",
    "character": "still.png",
    "i2v": "clip.mp4",
    "ui": "icon.png",
    "still": "still.png",
}

STACK = {
    "tile": (
        "`imagine`, `game-asset-core`, and `game-tilesets`",
        "One tileable world texture. One `image_gen` call, then copy the file into this directory.",
    ),
    "character": (
        "`imagine`, `game-asset-core`, and `game-character-consistency`",
        "One character / overlay still. New Bible: one `image_gen`. After lock: one `image_edit` from the staged base. "
        "Then copy the file into this directory.",
    ),
    "i2v": (
        "`imagine`, `game-asset-core`, and `game-animation-frames`",
        "One Image-to-Video unit from the staged seed and prompt. Then copy the clip into this directory. "
        "Do not harvest or pack frames.",
    ),
    "ui": (
        "`imagine`, `game-asset-core`, and `game-ui-icons`",
        "One UI / HUD / icon still. No text in the art. One media call, then copy the file into this directory.",
    ),
    "still": (
        "`imagine` and `game-asset-core`",
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
    "ui": (
        "One UI icon or plate still. No letters, numbers, or words in the image. "
        "Match the locked Bible palette and pixel-art finish."
    ),
    "still": "One still. Match the locked Bible palette and pixel-art finish when style sheets are staged.",
}


def _die(msg: str, code: int = 2) -> None:
    print(f"run_isolated_grok: {msg}", file=sys.stderr)
    raise SystemExit(code)


def _inside(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def _which_grok(name: str) -> str | None:
    return shutil.which(name)


def _style_lines(*, use_bibles: bool, kind: str) -> str:
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


def _tool_lines(kind: str) -> str:
    if kind == "i2v":
        return (
            "Tools:\n"
            "- `image_to_video` from the staged first frame.\n"
            "- Do not call `image_gen` unless that seed is missing.\n"
            "- Do not call `image_edit` unless the brief says to repair the seed first.\n"
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
            "- Do not open skill files, list the directory, or run a 2x2 / 4x4 composite. The parent does that.\n"
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
    ingested: bool = False,
) -> str:
    skills, specialist = STACK[kind]
    body = brief.strip() if brief.strip() else DEFAULT_BRIEF[kind]
    brief_block = f"Brief:\n{body}\n\n" if body else ""
    i2v_block = ""
    if kind == "i2v":
        i2v_block = (
            f"First frame: `{seed_name}` (opaque chroma plate — do not key it).\n"
            f"Prompt (use verbatim): `{prompt_name}`\n\n"
        )
    already = (
        "Reference files are already in this conversation. Do not read them again.\n\n"
        if ingested
        else ""
    )
    return (
        f"# Isolated {kind} job\n\n"
        "You are in a scratch directory on purpose. There is no game `AGENTS.md` here.\n\n"
        f"{already}"
        f"Bundled skills that may auto-apply: {skills}. Do not open those skill files. "
        "Do not load any other game-asset specialist.\n\n"
        f"{specialist}\n\n"
        f"{_tool_lines(kind)}\n"
        f"{_style_lines(use_bibles=use_bibles, kind=kind)}\n\n"
        f"{i2v_block}"
        f"{brief_block}"
        "One media call. Do not retry. Do not composite. Do not inspect the result beyond copying it.\n"
        f"Imagine may write under the session `images/` folder. Copy that file to `{dest_name}` "
        "in this scratch directory (convert to PNG if needed) and stop.\n"
        "Do not walk a parent repo. Do not edit Godot scenes.\n"
    )


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
    for child in sorted(scratch.iterdir()):
        if not child.is_file():
            continue
        if child.name == "job.md" or child.name in staged_names:
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


def main() -> None:
    p = argparse.ArgumentParser(
        description="Run one isolated Grok Build media job outside the game repo."
    )
    p.add_argument("--kind", choices=KINDS, required=True)
    p.add_argument("--grok", default="grok", help="Grok Build executable (default: grok)")
    p.add_argument("--max-turns", type=int, default=8)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--keep", action="store_true", help="Do not delete scratch; print its path")
    p.add_argument("--out", type=Path, default=None, help="Copy result media here after the child exits")
    p.add_argument("--job-file", type=Path, default=None, help="Use this markdown as job.md instead of the built-in template")
    p.add_argument("--brief", default="", help="Extra / replacement brief text folded into the built-in job.md")
    p.add_argument("--dest-name", default="", help="Output filename inside scratch")
    p.add_argument("--copy", type=Path, action="append", default=[], help="Extra file to copy into scratch (repeatable)")
    p.add_argument("--bible-style", action="store_true", help="Copy locked player Bibles as style / identity sheets")
    p.add_argument("--seed", type=Path, default=None, help="I2V first-frame PNG (required for --kind i2v)")
    p.add_argument("--prompt-file", type=Path, default=None, help="I2V prompt text (required for --kind i2v)")
    p.add_argument("--skip-inspect", action="store_true")
    p.add_argument(
        "--no-reuse",
        action="store_true",
        help="One-shot tempfile scratch; do not reuse an ingest session",
    )
    args = p.parse_args()

    if args.max_turns < 1:
        _die("--max-turns must be >= 1")
    if args.kind == "i2v":
        if args.seed is None or args.prompt_file is None:
            _die("--kind i2v requires --seed and --prompt-file")
    if args.job_file is not None and not args.job_file.is_file():
        _die(f"--job-file not found: {args.job_file}")
    if args.out is not None:
        args.out = args.out.resolve()
        args.out.mkdir(parents=True, exist_ok=True)

    sources: list[Path] = []
    if args.bible_style:
        bibles = [b for b in LOCKED_BIBLES if b.is_file()]
        if not bibles:
            _die("--bible-style set but locked Bibles are missing under assets/sprites/player/")
        sources.extend(bibles)
    sources.extend(args.copy)
    if args.kind == "i2v":
        assert args.seed is not None and args.prompt_file is not None
        sources.append(args.seed)

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
    if _inside(scratch, REPO):
        _die(f"scratch resolved inside the game repo: {scratch}")

    try:
        copied: list[str] = []
        for src in sources:
            copy_into(src, scratch)
            copied.append(src.name)
        if args.kind == "i2v":
            assert args.prompt_file is not None
            copy_into(args.prompt_file, scratch)
            copied.append(args.prompt_file.name)

        dest_name = args.dest_name.strip() or DEFAULT_DEST[args.kind]
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
            write_job(
                job_path,
                build_job(
                    kind=args.kind,
                    brief=args.brief,
                    use_bibles=args.bible_style,
                    dest_name=dest_name,
                    seed_name=seed_name,
                    prompt_name=prompt_name,
                    ingested=ingested,
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
            sys.stdout.write(child.stdout or "")
            if child.stderr:
                sys.stderr.write(child.stderr)
            child_code = int(child.returncode)

        results = collect_results(scratch, set(copied))
        dest_path = scratch / dest_name
        if dest_name not in {r.name for r in results}:
            harvested = harvest_session_media(scratch, dest_path)
            if harvested is not None:
                print(f"harvest={harvested}")
                results = collect_results(scratch, set(copied))
        print("results=" + ",".join(str(r.name) for r in results))
        dest_ok = dest_name in {r.name for r in results}
        print("dest=" + ("ok" if dest_ok else "missing"))
        calls = session_model_calls(scratch)
        if calls is not None:
            print(f"modelCalls={calls}")
        if child_code != 0:
            _die(f"grok child exited {child_code}", child_code)
        if args.out is not None:
            named = [r for r in results if r.name == dest_name]
            for src in named or results:
                target = args.out / src.name
                if not args.dry_run:
                    shutil.copy2(src, target)
                print(f"out={target}")
        if args.keep or use_reuse:
            print(f"keep={scratch}")
    finally:
        if scratch_holder is not None:
            scratch_holder.cleanup()


if __name__ == "__main__":
    main()