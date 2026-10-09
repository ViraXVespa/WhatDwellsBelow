#!/usr/bin/env python3
"""Stage one prove folder and open the first sheet in Photos.

    python tools/show_png.py --ask NAME --group AREA PATH=description PATH=description ...
    python tools/show_png.py PATH=description ...

One call per ask. Each group is one area or source asset, composed into one PNG.
Two frames sit side by side when each is taller than wide, stacked when each is
wider than tall. More than two use that same grid. A bare path is its own group
unless several share one shot-flow directory. Opens only the first file so
Photos can arrow through the folder. --no-open only prints. Relative paths are
from the worktree.
"""
from __future__ import annotations

import os
import subprocess
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import session_lib
from imglib import compare

EXT = re.compile(r"^(.*?\.(?:png|jpe?g|webp|gif|bmp))(?:=(.*))?$", re.I)
SAFE = re.compile(r"[^A-Za-z0-9._-]+")


def split_item(item: str) -> tuple[str, str]:
    m = EXT.match(item)
    return (m.group(1), (m.group(2) or "").strip()) if m else (item, "")


def sanitize(name: str) -> str:
    cleaned = SAFE.sub("-", name.strip()).strip(".-")
    return (cleaned or "sheet")[:40]


def flow_key(path: Path) -> str | None:
    parts = [p.lower() for p in path.parts]
    if "shot-flow" not in parts:
        return None
    i = parts.index("shot-flow")
    if i + 1 >= len(path.parts):
        return None
    return path.parts[i + 1]


def open_files(paths: list[Path], native: bool | None = None) -> int:
    """Open the first file only. Returns how many were opened (0 when there is no viewer)."""
    if native is None:
        native = os.name == "nt"
    if not native or not paths:
        return 0
    try:
        os.startfile(str(paths[0]))  # type: ignore[attr-defined]
        time.sleep(0.4)
        return 1
    except (OSError, AttributeError):
        print(f"WARN: could not open {paths[0]}")
        return 0


def parse_groups(groups: list[list[str]], bare: list[str]) -> list[tuple[str, list[tuple[str, str]]]]:
    out: list[tuple[str, list[tuple[str, str]]]] = []
    for spec in groups:
        if len(spec) < 2:
            agent_log.fail("--group needs a name and at least one PATH=description")
        out.append((spec[0], [split_item(item) for item in spec[1:]]))
    loose: list[tuple[str, str]] = [split_item(item) for item in bare]
    buckets: dict[str, list[tuple[str, str]]] = {}
    order: list[str] = []
    for path, desc in loose:
        key = flow_key(Path(path))
        if key is None:
            out.append((Path(path).stem, [(path, desc)]))
            continue
        if key not in buckets:
            buckets[key] = []
            order.append(key)
        buckets[key].append((path, desc))
    for key in order:
        out.append((key, buckets[key]))
    return out


def resolve_groups(groups: list[tuple[str, list[tuple[Path, str]]]]) -> list[tuple[str, list[tuple[Path, str]]]]:
    resolved = []
    missing = []
    for name, frames in groups:
        rows = []
        for raw, desc in frames:
            path = Path(raw).expanduser()
            path = path if path.is_absolute() else Path.cwd() / path
            if not path.is_file():
                missing.append(str(path))
            rows.append((path, desc))
        resolved.append((name, rows))
    if missing:
        agent_log.fail("not a file: " + "; ".join(missing))
    return resolved


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(Path.cwd().resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def stage(ask: str, groups: list[tuple[str, list[tuple[Path, str]]]], no_open: bool) -> tuple[int, int]:
    from PIL import Image

    folder = Path.cwd() / "_logs" / "prove-view" / sanitize(ask)
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()
    sheets: list[tuple[Path, str]] = []
    used: dict[str, int] = {}
    for name, frames in groups:
        base = sanitize(name)
        used[base] = used.get(base, 0) + 1
        stem = base if used[base] == 1 else f"{base}-{used[base]}"
        images = [Image.open(path).convert("RGBA") for path, _ in frames]
        labels = [desc or path.stem for path, desc in frames]
        sheet = compare.compose_group(images, labels)
        dest = folder / f"{len(sheets) + 1:02d}-{stem}.png"
        sheet.save(dest)
        detail = " | ".join(labels)
        sources = ", ".join(rel(path) for path, _ in frames)
        sheets.append((dest, f"{name}: {detail} (from {sources})"))
    n = 0 if no_open or not sheets else open_files([sheets[0][0]])
    print(f"folder {rel(folder)}")
    for path, desc in sheets:
        print(f"{rel(path)} - {desc}")
    where = "opened on her screen" if n else "not opened (no viewer here); list them in the message"
    print(f"{where}: {n} of {len(sheets)}")
    print(session_lib.failed_block())
    return n, len(sheets)


def selftest() -> int:
    import tempfile

    from PIL import Image

    bad = []
    if split_item(r"C:\a b\x.png=the pause page") != (r"C:\a b\x.png", "the pause page") or split_item("y.PNG") != ("y.PNG", ""):
        bad.append("PATH=description must split on the first '=' after the extension")
    if compare.grid_shape(2, 10, 40) != (2, 1):
        bad.append("a tall pair must sit side by side")
    if compare.grid_shape(2, 40, 10) != (1, 2):
        bad.append("a wide pair must stack")
    wide_cols = compare.grid_shape(4, 100, 20)[0]
    tall_cols = compare.grid_shape(4, 20, 100)[0]
    if wide_cols >= tall_cols:
        bad.append("wide cells need fewer columns than tall cells")
    with tempfile.TemporaryDirectory() as td:
        folder = Path(td)
        a = folder / "before.png"
        b = folder / "after.png"
        Image.new("RGB", (12, 30), (200, 0, 0)).save(a)
        Image.new("RGB", (12, 30), (0, 200, 0)).save(b)
        if open_files([a, b], native=False) != 0:
            bad.append("a non-Windows run must open nothing")
        proc = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), "--no-open", "--ask", "selftest", "--group", "pause", f"{a}=before", f"{b}=after"],
            capture_output=True,
            text=True,
            cwd=td,
        )
        out = proc.stdout + proc.stderr
        if proc.returncode != 0 or "before" not in out or "opened=0" not in out or "01-pause.png" not in out:
            bad.append("a group stages one sheet and passes")
        sheet = folder / "_logs" / "prove-view" / "selftest" / "01-pause.png"
        if not sheet.is_file():
            bad.append("the group sheet must land in the prove folder")
        elif Image.open(sheet).width <= 12:
            bad.append("a tall pair sheet must contain both frames")
        missing = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), str(folder / "nope.png")],
            capture_output=True,
            text=True,
        )
        if missing.returncode == 0 or "not a file" not in missing.stdout + missing.stderr:
            bad.append("a missing path must fail")
    for item in bad:
        print("FAIL " + item)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Stage prove sheets into one folder and open the first in Photos.")
    ap.add_argument("--ask", default="ask", help="Folder name under _logs/prove-view/.")
    ap.add_argument("--no-open", action="store_true", help="Only print the lines.")
    ap.add_argument("--selftest", action="store_true", help="Run the built-in cases.")
    ap.add_argument("--group", action="append", nargs="+", default=[], metavar="NAME", help="NAME PATH=description ... One area, one sheet.")
    ap.add_argument("items", nargs="*", help="PATH or PATH=one-line description")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    if not args.items and not args.group:
        agent_log.fail("pass PATH[=description] or --group NAME PATH=description")
    groups = resolve_groups(parse_groups(args.group, args.items))
    opened, count = stage(args.ask, groups, args.no_open)
    return agent_log.emit_result("PASS", opened=opened, files=count)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
