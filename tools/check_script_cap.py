#!/usr/bin/env python3
"""Fail if live scripts/**/*.gd are at or over the ship floor. Linux twin of check_script_cap.ps1."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

DEFAULT_OVER_KB = 10
GD_SKIP_PARTS = ("archives", ".archive_worktrees")


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def _rel(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def iter_gd(root: Path) -> list[Path]:
    scripts = root / "scripts"
    if not scripts.is_dir():
        return []
    out: list[Path] = []
    for path in scripts.rglob("*.gd"):
        if not path.is_file():
            continue
        if set(path.parts) & set(GD_SKIP_PARTS):
            continue
        out.append(path)
    return out


def git_changed_scripts(root: Path) -> list[Path] | None:
    try:
        proc = subprocess.run(
            ["git", "status", "--porcelain", "--", "scripts"],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return None
    if proc.returncode != 0:
        return None
    paths: list[Path] = []
    for line in (proc.stdout or "").splitlines():
        if len(line) < 4:
            continue
        rel = line[3:].strip()
        if " -> " in rel:
            rel = rel.split(" -> ", 1)[1]
        rel = rel.replace("\\", "/")
        if not rel.endswith(".gd"):
            continue
        path = root / rel
        if path.is_file():
            paths.append(path)
    return paths


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check scripts/**/*.gd against the on-disk byte cap."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--over-kb",
        dest="over_kb",
        type=float,
        default=DEFAULT_OVER_KB,
        help="Ship floor in KB. Limit is round(over_kb * 1000) bytes (default 10 -> 10000).",
    )
    parser.add_argument(
        "--git-changed",
        dest="git_changed",
        action="store_true",
        help="Only files listed by git status --porcelain -- scripts.",
    )
    parser.add_argument(
        "--path",
        action="append",
        default=[],
        help="Explicit script path (repeatable). Relative to --root unless absolute.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = Path(args.root).expanduser().resolve()
    limit = int(round(args.over_kb * 1000))

    if args.path:
        files: list[Path] = []
        for raw in args.path:
            path = Path(raw)
            if not path.is_absolute():
                path = root / path
            if path.is_file():
                files.append(path)
    elif args.git_changed:
        found = git_changed_scripts(root)
        if found is None:
            print("git status failed", file=sys.stderr)
            return 2
        files = found
    else:
        files = iter_gd(root)

    over: list[tuple[int, str]] = []
    for path in files:
        size = path.stat().st_size
        if size >= limit:
            over.append((size, _rel(root, path)))
    over.sort(key=lambda row: (-row[0], row[1]))

    lines = [
        "script cap",
        f"root={root}",
        f"overKb={args.over_kb} limit={limit}",
        "measure=os.path.getsize (== Get-Item Length)",
        f"checked={len(files)} over={len(over)}",
        "",
        "bytes\tpath",
    ]
    for size, rel in over:
        lines.append(f"{size}\t{rel}")
    lines.append("")
    lines.append(f"RESULT count={len(over)}")
    body = "\n".join(lines)

    out = agent_log.ensure_agent_log_dir("script-cap", root) / "summary.txt"
    _write(out, body)
    print(body)
    print("")
    print(f"Summary -> {out}")
    return 1 if over else 0


if __name__ == "__main__":
    raise SystemExit(main())