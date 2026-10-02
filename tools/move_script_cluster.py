#!/usr/bin/env python3
"""Move or rename a facade + helpers (cluster folders: facade beside <stem>/, trimmed helper names) and rewrite references.

Usage (from repo root):
  python tools/move_script_cluster.py --dry-run --stem gear_board --from-dir scripts/ui --to-dir scripts/ui/gear_board
  python tools/move_script_cluster.py --stem debug_menu --from-dir scripts/combat --to-dir scripts/debug/debug_menu
  python tools/move_script_cluster.py --files scripts/combat/sfx.gd --to-dir scripts/audio
  python tools/move_script_cluster.py --dry-run --plan plan.json     (batch: {"scripts/ui/hud": ["scripts/ui/hud.gd", ...], ...})
  python tools/move_script_cluster.py --dry-run --map map.json       (exact old->new: {"scripts/ui/hud/hud.gd": "scripts/ui/hud.gd", "scripts/ui/hud/hud_act.gd": "scripts/ui/hud/hud_act.gd"})
  python tools/move_script_cluster.py --list-cluster scripts/graphics/light_rt.gd   (facade + its <stem>/ helpers)
  powershell -File tools/move_script_cluster.ps1 ...

One run = one rewrite pass over every group in the plan/map (single regex pass, so chained moves cannot double-rewrite).
Rewrites exact paths (`res://`, bare) and, for renamed files, bare old basenames in prose/code-map rows (written
as the bare new basename). Globs like `dir/stem*.gd` and string-built paths need the manual pass in design/refactor.md; keeps BOM and CRLF/LF as found. Skips design/changelog/ and
scripts/data/changelog.json (history). Writes _logs/move-cluster/summary.txt. Does not commit.
"""
from __future__ import annotations

import argparse
import json
import re
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
    """Facade `<from_dir>/<stem>.gd` + helpers in `<from_dir>/<stem>/*.gd` (folder layout), plus legacy loose `<stem>_*.gd`."""
    files = []
    for p in sorted(from_dir.glob("*.gd")):
        if p.name == f"{stem}.gd" or p.name.startswith(f"{stem}_"):
            files.append(p)
    sub = from_dir / stem
    if sub.is_dir():
        files += sorted(sub.glob("*.gd"))
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


def build_moves(files: list[Path], to_dir: Path, stem: str = "") -> list[tuple[Path, Path]]:
    """`stem` set (--stem mode): helpers that live in `<stem>/` keep that folder under to_dir (facade lands beside it)."""
    moves = []
    for src in files:
        dst = to_dir / (stem if stem and src.parent.name == stem and src.stem != stem else "") / src.name
        moves.append((src, dst))
        uid = Path(str(src) + ".uid")
        if uid.exists():
            moves.append((uid, Path(str(dst) + ".uid")))
    return moves


def read_map(path: str) -> list[tuple[Path, Path]]:
    """--map JSON {old_file: new_file} (repo-relative or absolute) -> moves incl. .uid sidecars."""
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    moves: list[tuple[Path, Path]] = []
    for old, new in raw.items():
        src = (Path(old) if Path(old).is_absolute() else ROOT / old).resolve()
        dst = Path(new) if Path(new).is_absolute() else ROOT / new
        if not src.is_file():
            raise SystemExit(f"missing file: {old}")
        moves.append((src, dst))
        uid = Path(str(src) + ".uid")
        if uid.exists():
            moves.append((uid, Path(str(dst) + ".uid")))
    return moves


def rename_basenames(moves: list[tuple[Path, Path]]) -> list[tuple[str, str]]:
    """(old basename, new basename) for moves whose file name changed (bare mentions in docs/code-map rows stay bare:
    check_code_map treats any tick containing `/` as a full repo path; basenames are unique repo-wide)."""
    out = []
    for src, dst in moves:
        if src.suffix == ".gd" and src.name != dst.name:
            out.append((src.name, dst.name))
    return out


_BARE_LB = r"(?<![A-Za-z0-9_/.\-])"
_BARE_LA = r"(?![A-Za-z0-9_])"


def rewrite_text(text: str, pairs: list[tuple[str, str]], names: list[tuple[str, str]]) -> str:
    if pairs:
        table = dict(pairs)
        rx = re.compile("|".join(re.escape(o) for o, _ in sorted(pairs, key=lambda t: len(t[0]), reverse=True)))
        text = rx.sub(lambda m: table[m.group(0)], text)
    if names:
        table = dict(names)
        rx = re.compile(_BARE_LB + "(" + "|".join(re.escape(o) for o, _ in sorted(names, key=lambda t: len(t[0]), reverse=True)) + ")" + _BARE_LA)
        text = rx.sub(lambda m: table[m.group(1)], text)
    return text


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


def apply_rewrites(pairs: list[tuple[str, str]], dry_run: bool, names: list[tuple[str, str]] | None = None) -> tuple[list[str], dict[Path, str]]:
    """Return changed paths and optional in-memory texts for residual checks before write."""
    changed: list[str] = []
    texts: dict[Path, str] = {}
    for path in iter_text_files():
        try:
            text = path.read_bytes().decode("utf-8")
        except Exception:
            continue
        orig = text
        text = rewrite_text(text, pairs, names or [])
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
    ap.add_argument("--stem", "-Stem", default="", help="Facade stem to move (with --from-dir / --to-dir).")
    ap.add_argument("--from-dir", "-FromDir", default="", help="Folder the cluster lives in now.")
    ap.add_argument("--to-dir", "-ToDir", default="", help="Folder to move the cluster to.")
    ap.add_argument("--plan", "-Plan", default="", help="JSON {to_dir: [facade/helper .gd paths]} for a batch (one rewrite pass).")
    ap.add_argument("--map", "-Map", default="", help="JSON {old_file: new_file} exact moves/renames (facade-out + trimmed helper names); .uid sidecars follow.")
    ap.add_argument("--list-cluster", "-ListCluster", default="", help="Print facade + <stem>/ helpers for a facade path and exit.")
    ap.add_argument("--files", "-Files", nargs="*", default=[], help="Explicit files to move instead of --stem.")
    ap.add_argument("--wrapper", "-Wrapper", action="store_true", help="Leave a one-line wrapper at each old .gd path.")
    ap.add_argument("--no-git", "-NoGit", action="store_true", help="Use plain moves instead of git mv.")
    args = ap.parse_args()
    ROOT = agent_log.resolve_root(args)

    if args.list_cluster:
        fac = (Path(args.list_cluster) if Path(args.list_cluster).is_absolute() else ROOT / args.list_cluster).resolve()
        for f in list_cluster(fac.parent, fac.stem):
            print(rel(f))
        return 0
    names: list[tuple[str, str]] = []
    if args.map:
        moves = read_map(args.map)
        files = [s for s, _ in moves if s.suffix == ".gd"]
        names = rename_basenames(moves)
        to_dir = ROOT / "scripts"
        args.to_dir = f"(map {len(files)} files)"
        args.plan = args.plan or ""
    elif args.plan:
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
        moves = build_moves(files, to_dir, "" if args.files else args.stem)
    pairs = rewrite_map(moves)
    if args.map:
        args.plan = args.map  # reuse plan-style labels below

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

    changed, _texts = apply_rewrites(pairs, dry_run=args.dry_run, names=names)
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
    raise SystemExit(agent_log.guarded(main))
