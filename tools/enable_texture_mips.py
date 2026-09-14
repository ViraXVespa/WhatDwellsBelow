#!/usr/bin/env python3
"""Turn on Godot texture mipmap generation for 3D world PNGs.

Rewrites tracked ``*.import`` files under ``assets/sprites``, ``assets/tiles``,
``assets/props``, and ``assets/fx``. Leaves ``assets/ui`` and non-texture
imports alone. ``tools/export_web.ps1`` runs this before headless ``--import``
so the web PCK ships baked mip chains.
"""

from __future__ import annotations

import argparse
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

FOLDERS = (
    ROOT / "assets" / "sprites",
    ROOT / "assets" / "tiles",
    ROOT / "assets" / "props",
    ROOT / "assets" / "fx",
)

FLAG = "mipmaps/generate"
ON = "mipmaps/generate=true"
OFF_PREFIXES = (
    "mipmaps/generate=false",
    "mipmaps/generate=0",
)


def _is_texture_import(text: str) -> bool:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("importer="):
            return stripped.split("=", 1)[1].strip().strip('"') == "texture"
    return False


def _enable(text: str) -> tuple[str, str]:
    """Return (new_text, action) where action is 'on' | 'already' | 'insert'."""
    lines = text.splitlines(keepends=True)
    if not lines:
        return text, "already"
    out: list[str] = []
    found = False
    changed = False
    in_params = False
    params_done = False
    for line in lines:
        raw = line.splitlines()[0] if line.endswith(("\n", "\r")) else line
        stripped = raw.strip()
        if stripped == "[params]":
            in_params = True
            out.append(line)
            continue
        if stripped.startswith("[") and stripped.endswith("]") and stripped != "[params]":
            if in_params and not found and not params_done:
                nl = "\r\n" if raw.endswith("\r") or line.endswith("\r\n") else "\n"
                out.append(ON + nl)
                found = True
                changed = True
                params_done = True
            in_params = False
            out.append(line)
            continue
        if stripped.startswith(FLAG + "="):
            found = True
            if stripped in ("mipmaps/generate=true", "mipmaps/generate=1"):
                out.append(line)
            else:
                ending = "\r\n" if line.endswith("\r\n") else ("\n" if line.endswith("\n") else "")
                out.append(ON + ending)
                changed = True
            continue
        out.append(line)
    if in_params and not found:
        nl = "\n"
        if lines and lines[-1].endswith("\r\n"):
            nl = "\r\n"
        elif lines and lines[-1].endswith("\n"):
            nl = "\n"
        out.append(ON + nl)
        found = True
        changed = True
    new = "".join(out)
    if not changed:
        return text, "already"
    if FLAG + "=" in text:
        return new, "on"
    return new, "insert"


def patch_file(path: pathlib.Path, write: bool) -> str:
    text = path.read_text(encoding="utf-8")
    if not _is_texture_import(text):
        return "skip"
    new, action = _enable(text)
    if action == "already":
        return "already"
    if write and new != text:
        path.write_text(new, encoding="utf-8", newline="")
    return action


def iter_imports(root: pathlib.Path) -> list[pathlib.Path]:
    folders = (
        root / "assets" / "sprites",
        root / "assets" / "tiles",
        root / "assets" / "props",
        root / "assets" / "fx",
    )
    found: list[pathlib.Path] = []
    for folder in folders:
        if not folder.is_dir():
            continue
        found.extend(sorted(folder.rglob("*.import")))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="Enable mipmaps/generate on 3D world texture imports.")
    parser.add_argument("--root", type=pathlib.Path, default=ROOT, help="Repo root")
    parser.add_argument("--dry-run", action="store_true", help="Report only; do not write")
    args = parser.parse_args()
    root = args.root.resolve()
    write = not args.dry_run
    counts = {"on": 0, "insert": 0, "already": 0, "skip": 0}
    paths = iter_imports(root)
    if not paths:
        print(f"no .import files under 3D asset folders in {root}")
        return 0
    for path in paths:
        action = patch_file(path, write)
        counts[action] = counts.get(action, 0) + 1
        rel = path.relative_to(root)
        if action in ("on", "insert"):
            print(f"{action}\t{rel}")
    print(
        "mipmaps generate=true "
        f"flipped={counts['on']} inserted={counts['insert']} "
        f"already={counts['already']} skipped={counts['skip']} "
        f"files={len(paths)} dry_run={args.dry_run}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())