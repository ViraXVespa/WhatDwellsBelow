#!/usr/bin/env python3
"""Hash game-affecting paths so Pages can skip a full Godot export."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

GAME_FILES = (
    "export_presets.cfg",
    "project.godot",
    "tools/web_postexport.py",
    "tools/web_shell.html",
    "tools/enable_texture_mips.py",
    "tools/export_web.ps1",
    "tools/publish_notes_site.py",
)

GAME_DIRS = (
    "scripts",
    "scenes",
    "assets",
)

NOTES_SKIP = {
    "scripts/data/version.json",
    "scripts/data/changelog.json",
}

SKIP_PARTS = {".git", "_logs", "site", "docs", "_pages", ".godot"}


def _posix(root: Path, path: Path) -> str:
    return path.resolve().relative_to(root).as_posix()


def _iter_game_files(root: Path) -> list[Path]:
    out: list[Path] = []
    for rel in GAME_FILES:
        path = root / rel
        if path.is_file():
            out.append(path)
    for folder in GAME_DIRS:
        base = root / folder
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            if any(part in SKIP_PARTS for part in path.parts):
                continue
            rel = _posix(root, path)
            if rel in NOTES_SKIP:
                continue
            out.append(path)
    out.sort(key=lambda p: _posix(root, p))
    return out


def game_hash(root: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    files = _iter_game_files(root)
    for path in files:
        rel = _posix(root, path)
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest(), len(files)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print a stable hash of game-affecting export inputs."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--out", default="", help="Optional stamp file")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    root = Path(args.root).expanduser().resolve()
    digest, count = game_hash(root)
    summary = "game_hash=%s files=%s\n" % (digest, count)
    log = root / "_logs" / "pages-game-hash" / "summary.txt"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(summary, encoding="utf-8")
    if args.out:
        Path(args.out).write_text(digest + "\n", encoding="utf-8")
    print(summary, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())