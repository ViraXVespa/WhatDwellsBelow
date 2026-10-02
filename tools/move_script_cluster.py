#!/usr/bin/env python3
"""Move a facade + sibling helpers into a folder and rewrite res:// paths.

Usage (from repo root):
  python tools/move_script_cluster.py --dry-run --stem gear_board --from-dir scripts/ui --to-dir scripts/ui/gear_board
  python tools/move_script_cluster.py --stem debug_menu --from-dir scripts/combat --to-dir scripts/debug/debug_menu
  python tools/move_script_cluster.py --files scripts/combat/sfx.gd --to-dir scripts/audio
  python tools/move_script_cluster.py --dry-run --plan plan.json     (batch: {"scripts/ui/hud": ["scripts/ui/hud.gd", ...], ...})
  powershell -File tools/move_script_cluster.ps1 ...

One run = one rewrite pass over every group in the plan. Rewrites exact paths (`res://`, bare) only (globs like
`dir/stem*.gd` in prose need a manual pass); keeps BOM and CRLF/LF as found. Skips design/changelog/ and
scripts/data/changelog.json (history). Writes _logs/move-cluster/summary.txt. Does not commit.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime
from pathlib import Path
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

ROOT = agent_log.repo_root()
SCAN_ROOTS = ("scripts", "design", "scenes", "assets", "tools", ".grok", ".github")
SCAN_FILES = ("project.godot", "AGENTS.md", "README.md", "BOT.md", "GROK-BOT.md", "export_presets.cfg")
SCAN_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".md", ".json", ".godot", ".cfg", ".txt", ".py", ".ps1", ".yml", ".yaml"}
SKIP_PREFIXES = ("archives/", ".archive_worktrees/", "design/changelog/", "_logs/")  # repo-root relative
SKIP_FILES = ("scripts/data/changelog.json", "tools/move_script_cluster.py")


def rel(p: Path) -> str:
    return agent_log.rel(ROOT, p)


def run_git(args: list[str]) -> None:
    subprocess.run(["git", *args], cwd=ROOT, check=True)


def list_cluster(from_dir: Path, stem: str) -> list[Path]:
    files = []
    for p in sorted(from_dir.glob("*.gd")):
        if p.name == f"{stem}.gd" or p.name.startswith(f"{stem}_"):
            files.append(p)
    return files


def collect_files(args: argparse.Namespace) -> list[Path]:
    args.files = agent_log.split_list(args.files)
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
            if rel(p).startswith(SKIP_PREFIXES) or rel(p) in SKIP_FILES or "/__pycache__/" in s:
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
            text = path.read_bytes().decode("utf-8")
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
                path.write_bytes(text.encode("utf-8"))
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
            text = path.read_bytes().decode("utf-8")
        except Exception:
            continue
        for old, _new in res_pairs:
            if old in text:
                residuals.append(f"{rel(path)} still has {old}")
    return residuals


def main() -> int:
    global ROOT
    ap = agent_log.std_parser("Move a script cluster into a folder and rewrite references.", writes=True)
    ap.add_argument("--stem", "-Stem", default="")
    ap.add_argument("--from-dir", "-FromDir", default="")
    ap.add_argument("--to-dir", "-ToDir", default="")
    ap.add_argument("--plan", "-Plan", default="", help="JSON {to_dir: [facade/helper .gd paths]} for a batch (one rewrite pass).")
    ap.add_argument("--files", "-Files", nargs="*", default=[])
    ap.add_argument("--wrapper", "-Wrapper", action="store_true")
    ap.add_argument("--no-git", "-NoGit", action="store_true")
    args = ap.parse_args()
    ROOT = agent_log.resolve_root(args)

    if args.plan:
        plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
        files, moves = [], []
        for dest, paths in plan.items():
            dest_dir = Path(dest) if Path(dest).is_absolute() else ROOT / dest
            grp = []
            for f in paths:
                fp = (Path(f) if Path(f).is_absolute() else ROOT / f).resolve()
                if not fp.is_file():
                    raise SystemExit(f"missing file: {f}")
                grp.append(fp)
            files += grp
            moves += build_moves(grp, dest_dir)
        to_dir = ROOT / "scripts"
        args.to_dir = f"(plan {len(plan)} folders)"
    else:
        if not args.to_dir:
            agent_log.fail("need --to-dir or --plan")
        to_dir = Path(args.to_dir)
        if not to_dir.is_absolute():
            to_dir = ROOT / to_dir
        files = collect_files(args)
        moves = build_moves(files, to_dir)
    pairs = rewrite_map(moves)

    lines: list[str] = [
        f"move cluster {datetime.now().astimezone().isoformat()}",
        "root=.",
        f"to_dir={args.to_dir if args.plan else rel(to_dir)} dry_run={args.dry_run} wrapper={args.wrapper}",
        f"files={len(files)} moves={len(moves)} rewrite_pairs={len(pairs)}",
        "",
        "## moves",
    ]
    for src, dst in moves:
        lines.append(f"{rel(src)} -> {rel(dst)}")

    if not args.dry_run:
        for src, dst in moves:
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists():
                agent_log.fail(f"destination exists: {rel(dst)}", 1)
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

    status = "FAIL" if residuals and not args.dry_run else "PASS"
    return agent_log.finish("move-cluster", ROOT, "\n".join(lines), status, args=args, moved=0 if args.dry_run else len(moves),
                            rewrite_files=len(changed), residuals=len(residuals), dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
