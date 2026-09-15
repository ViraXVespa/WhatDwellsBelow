#!/usr/bin/env python3
"""Stage a scratch directory outside the git tree and run a thin Grok Build media job.

The parent (game repo) session must not call Imagine unless design/isolated-media.md
lists an in-session exception. This runner copies only the named inputs into OS temp,
writes a kind-specific job.md, runs `grok inspect` (including with --dry-run), then
`grok -p` unless --dry-run. Child cwd must not discover WhatDwellsBelow/AGENTS.md.

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
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
REPO = TOOLS.parent
LOCKED_BIBLES = (
    REPO / "assets" / "sprites" / "player" / "bible_locked_male.png",
    REPO / "assets" / "sprites" / "player" / "bible_locked_female.png",
)
KINDS = ("tile", "character", "i2v", "ui", "still")
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
        "Tileable world texture. Run the `game-tilesets` 2x2 PIL composite in this directory. "
        "Retry on seams, a motif you can spot in every quadrant, or checkerboard tone. "
        "Leave the composite PNG here.",
    ),
    "character": (
        "`imagine`, `game-asset-core`, and `game-character-consistency`",
        "Character / overlay still. New Bible or style candidate: `image_gen`. "
        "After lock, or any facing/variant/overlay of a locked body: `image_edit` chained from the staged base. "
        "Do not regenerate a cousin of a locked Bible.",
    ),
    "i2v": (
        "`imagine`, `game-asset-core`, and `game-animation-frames`",
        "One Image-to-Video unit. Motion law is the staged prompt file, not cinematic 6s/10s shot language. "
        "Do not harvest or pack frames.",
    ),
    "ui": (
        "`imagine`, `game-asset-core`, and `game-ui-icons`",
        "UI / HUD / icon still. No text in the art. Geometry-identical states if more than one state is requested. "
        "Input-prompt glyph sheets stay a repo script (`tools/gen_prompt_glyphs.py`), not this job.",
    ),
    "still": (
        "`imagine` and `game-asset-core`",
        "Generic still fallback. Prefer a tighter --kind when the asset is a tile, character, or UI icon.",
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
        "Style reference only: `bible_locked_male.png` (and `bible_locked_female.png` if present). "
        "Do not draw the character. Do not edit the Bible into this asset. "
        "Match palette, line weight, and pixel-art finish."
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
            "- `image_gen` for a brand-new tile with no source texture.\n"
            "- `image_edit` only to iterate the tile you just wrote, or to use staged PNGs as style sheets.\n"
            "- Do not call `image_to_video` in this job.\n"
        )
    return (
        "Tools:\n"
        "- `image_gen` for a brand-new still with no source image.\n"
        "- `image_edit` to iterate the still you just wrote, or to use staged PNGs as style sheets.\n"
        "- Do not call `image_to_video` in this job.\n"
    )


def build_job(
    *,
    kind: str,
    brief: str,
    use_bibles: bool,
    dest_name: str,
    seed_name: str = "",
    prompt_name: str = "",
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
    return (
        f"# Isolated {kind} job\n\n"
        "You are in a scratch directory on purpose. There is no game `AGENTS.md` here.\n\n"
        f"Follow bundled Grok Build skills when they are available: {skills}.\n"
        "Do not load the other game-asset specialists for this job.\n\n"
        f"{specialist}\n\n"
        f"{_tool_lines(kind)}\n"
        f"{_style_lines(use_bibles=use_bibles, kind=kind)}\n\n"
        f"{i2v_block}"
        f"{brief_block}"
        f"Write the accepted output as `{dest_name}` in this directory.\n"
        "Stop. Do not walk a parent repo. Do not edit Godot scenes.\n"
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


def inspect_mentions_repo_agents(text: str) -> bool:
    low = text.replace("\\", "/").lower()
    if "agents.md" not in low:
        return False
    return "whatdwellsbelow" in low or "dwellsbelow" in low


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

    scratch_holder: tempfile.TemporaryDirectory[str] | None = None
    if args.keep:
        scratch = Path(tempfile.mkdtemp(prefix="wdb-iso-"))
    else:
        scratch_holder = tempfile.TemporaryDirectory(prefix="wdb-iso-")
        scratch = Path(scratch_holder.name)
    scratch = scratch.resolve()
    if _inside(scratch, REPO):
        _die(f"scratch resolved inside the game repo: {scratch}")

    try:
        copied: list[str] = []
        if args.bible_style:
            found_bible = False
            for bible in LOCKED_BIBLES:
                if bible.is_file():
                    copy_into(bible, scratch)
                    copied.append(bible.name)
                    found_bible = True
            if not found_bible:
                _die("--bible-style set but locked Bibles are missing under assets/sprites/player/")
        for extra in args.copy:
            copy_into(extra, scratch)
            copied.append(extra.name)
        if args.kind == "i2v":
            assert args.seed is not None and args.prompt_file is not None
            copy_into(args.seed, scratch)
            copy_into(args.prompt_file, scratch)
            copied.append(args.seed.name)
            copied.append(args.prompt_file.name)

        dest_name = args.dest_name.strip() or DEFAULT_DEST[args.kind]
        job_path = scratch / "job.md"
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
                    sys.stdout.write(ins.stdout or "")
                    if ins.stderr:
                        sys.stderr.write(ins.stderr)
                    if inspect_mentions_repo_agents(text):
                        _die("inspect still sees WhatDwellsBelow AGENTS.md; refuse to generate", 3)
                    if ins.returncode != 0:
                        _die(f"grok inspect exited {ins.returncode}", ins.returncode)

        argv = [
            grok_bin,
            "-p",
            "--cwd",
            str(scratch),
            "--prompt-file",
            str(job_path),
            "--verbatim",
            "--max-turns",
            str(args.max_turns),
            "--disable-web-search",
            "--no-subagents",
            "--always-approve",
            "--output-format",
            "plain",
        ]
        child = run_cmd(argv, cwd=scratch, dry_run=args.dry_run)
        if child is not None:
            sys.stdout.write(child.stdout or "")
            if child.stderr:
                sys.stderr.write(child.stderr)
            if child.returncode != 0:
                _die(f"grok -p exited {child.returncode}", child.returncode)

        results = collect_results(scratch, set(copied))
        print("results=" + ",".join(str(r.name) for r in results))
        if args.out is not None:
            for src in results:
                target = args.out / src.name
                if not args.dry_run:
                    shutil.copy2(src, target)
                print(f"out={target}")
        if args.keep:
            print(f"keep={scratch}")
    finally:
        if scratch_holder is not None:
            scratch_holder.cleanup()


if __name__ == "__main__":
    main()