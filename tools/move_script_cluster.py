#!/usr/bin/env python3
"""Move a facade + sibling helpers into a folder and rewrite res:// paths.

Usage (from repo root):
  python tools/move_script_cluster.py --dry-run --stem gear_board --from-dir scripts/ui --to-dir scripts/ui/gear_board
  python tools/move_script_cluster.py --stem debug_menu --from-dir scripts/combat --to-dir scripts/debug/debug_menu
  python tools/move_script_cluster.py --files scripts/combat/sfx.gd --to-dir scripts/audio
  powershell -File tools/move_script_cluster.ps1 ...

Writes _logs/move-cluster/summary.txt. Does not commit.
"""
from __future__ import annotations

import argparse
import subprocess
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "_logs" / "move-cluster"
SUMMARY = OUT_DIR / "summary.txt"
SCAN_ROOTS = ("scripts", "design", "scenes", "assets")
SCAN_FILES = ("project.godot", "AGENTS.md", "README.md")
SCAN_SUFFIXES = {".gd", ".tscn", ".tres", ".md", ".json", ".godot", ".cfg", ".txt"}


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT)).replace("\\", "/")


def run_git(args: list[str]) -> None:
    subprocess.run(["git", *args], cwd=ROOT, check=True)


def list_cluster(from_dir: Path, stem: str) -> list[Path]:
    files = []
    for p in sorted(from_dir.glob("*.gd")):
        if p.name == f"{stem}.gd" or p.name.startswith(f"{stem}_"):
            files.append(p)
    return files


def collect_files(args: argparse.Namespace) -> list[Path]:
    if args.files:
        out = []
        for f in args.files:
            p = Path(f)
            if not p.is_absolute():
                p = ROOT / p
            if not p.exists():
                raise SystemExit(f"missing file: {f}")
            out.append(p.resolve())
        return out
    if not args.stem or not args.from_dir:
        raise SystemExit("need --stem/--from-dir or --files")
    from_dir = Path(args.from_dir)
    if not from_dir.is_absolute():
        from_dir = ROOT / from_dir
    files = list_cluster(from_dir, args.stem)
    if not files:
        raise SystemExit(f"no cluster files for stem={args.stem} in {from_dir}")
    return files


def build_moves(files: list[Path], to_dir: Path) -> list[tuple[Path, Path]]:
    moves = []
    for src in files:
        dst = to_dir / src.name
        moves.append((src, dst))
        uid = Path(str(src) + ".uid")
        if uid.exists():
            moves.append((uid, Path(str(dst) + ".uid")))
    return moves


def rewrite_map(moves: list[tuple[Path, Path]]) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for src, dst in moves:
        if src.suffix != ".gd":
            continue
        old = "res://" + rel(src)
        new = "res://" + rel(dst)
        pairs.append((old, new))
        # docs / code-map bare paths
        pairs.append((rel(src), rel(dst)))
    pairs.sort(key=lambda t: len(t[0]), reverse=True)
    return pairs


def iter_text_files() -> list[Path]:
    out: list[Path] = []
    seen: set[Path] = set()
    for name in SCAN_FILES:
        p = ROOT / name
        if p.exists():
            out.append(p)
            seen.add(p.resolve())
    for root_name in SCAN_ROOTS:
        root = ROOT / root_name
        if not root.is_dir():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            if p.suffix.lower() not in SCAN_SUFFIXES:
                continue
            s = str(p).replace("\\", "/")
            if "/archives/" in s or "/.archive_worktrees/" in s:
                continue
            rp = p.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            out.append(p)
    # loose scenes under repo root
    for p in ROOT.glob("*.tscn"):
        rp = p.resolve()
        if rp not in seen:
            out.append(p)
            seen.add(rp)
    return out


def apply_rewrites(pairs: list[tuple[str, str]], dry_run: bool) -> tuple[list[str], dict[Path, str]]:
    """Return changed paths and optional in-memory texts for residual checks before write."""
    changed: list[str] = []
    texts: dict[Path, str] = {}
    for path in iter_text_files():
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            continue
        orig = text
        for old, new in pairs:
            if old in text:
                text = text.replace(old, new)
        if text != orig:
            changed.append(rel(path))
            texts[path] = text
            if not dry_run:
                raw = path.read_bytes()
                had_bom = raw.startswith(b"\xef\xbb\xbf") or text.startswith("\ufeff")
                body = text.lstrip("\ufeff")
                data = body.encode("utf-8")
                if had_bom:
                    data = b"\xef\xbb\xbf" + data
                path.write_bytes(data)
    return changed, texts


def write_wrappers(moves: list[tuple[Path, Path]], dry_run: bool) -> list[str]:
    written = []
    for src, dst in moves:
        if src.suffix != ".gd":
            continue
        body = f'extends "res://{rel(dst)}"\n'
        written.append(rel(src))
        if not dry_run:
            src.parent.mkdir(parents=True, exist_ok=True)
            src.write_text(body, encoding="utf-8", newline="\n")
    return written


def find_residuals(pairs: list[tuple[str, str]]) -> list[str]:
    residuals = []
    res_pairs = [(o, n) for o, n in pairs if o.startswith("res://")]
    for path in iter_text_files():
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            continue
        for old, _new in res_pairs:
            if old in text:
                residuals.append(f"{rel(path)} still has {old}")
    return residuals


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stem", default="")
    ap.add_argument("--from-dir", default="")
    ap.add_argument("--to-dir", required=True)
    ap.add_argument("--files", nargs="*", default=[])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--wrapper", action="store_true")
    ap.add_argument("--no-git", action="store_true")
    args = ap.parse_args()

    to_dir = Path(args.to_dir)
    if not to_dir.is_absolute():
        to_dir = ROOT / to_dir
    files = collect_files(args)
    moves = build_moves(files, to_dir)
    pairs = rewrite_map(moves)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines: list[str] = [
        f"move cluster {datetime.now().astimezone().isoformat()}",
        f"root={ROOT}",
        f"to_dir={rel(to_dir)} dry_run={args.dry_run} wrapper={args.wrapper}",
        f"files={len(files)} moves={len(moves)} rewrite_pairs={len(pairs)}",
        "",
        "## moves",
    ]
    for src, dst in moves:
        lines.append(f"{rel(src)} -> {rel(dst)}")

    if not args.dry_run:
        to_dir.mkdir(parents=True, exist_ok=True)
        for src, dst in moves:
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists():
                raise SystemExit(f"destination exists: {dst}")
            if args.no_git:
                src.rename(dst)
            else:
                run_git(["mv", "--", str(src), str(dst)])

    changed, _texts = apply_rewrites(pairs, dry_run=args.dry_run)
    lines.append("")
    lines.append(f"## rewrites files={len(changed)}")
    for c in changed:
        lines.append(c)

    wrappers: list[str] = []
    if args.wrapper:
        wrappers = write_wrappers(moves, dry_run=args.dry_run)
        lines.append("")
        lines.append(f"## wrappers files={len(wrappers)}")
        for w in wrappers:
            lines.append(w)

    residuals: list[str] = []
    if not args.dry_run:
        residuals = find_residuals(pairs)
        if args.wrapper:
            wrap_set = {rel(src) for src, _ in moves if src.suffix == ".gd"}
            residuals = [r for r in residuals if r.split(" still has ", 1)[0] not in wrap_set]

    lines.append("")
    lines.append(f"## residuals count={len(residuals)}")
    for r in residuals[:50]:
        lines.append(r)

    lines.append("")
    lines.append(
        f"RESULT moved={0 if args.dry_run else len(moves)} rewrite_files={len(changed)} residuals={len(residuals)} dry_run={args.dry_run}"
    )
    SUMMARY.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Summary -> {SUMMARY}")
    print(lines[-1])
    if residuals and not args.dry_run:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
