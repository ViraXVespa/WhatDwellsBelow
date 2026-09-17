#!/usr/bin/env python3
"""Add, remove, or rename a live path on one design/code-map.md system row.

    python tools/patch_code_map.py --system Hub --add scripts/world/foo.gd
    python tools/patch_code_map.py --system Debug --remove old.gd
    python tools/patch_code_map.py --system Hub --rename camp_view.gd=camp_look.gd

Repeatable --add / --remove / --rename. Order: removes, then renames, then adds.
Writes _logs/code-map-patch/summary.txt. Agents read that file only.
Do not open design/code-map.md to add a helper path.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import code_map_lib as cm


def _parse_rename(raw: str) -> tuple[str, str] | None:
    if "=" not in raw:
        return None
    old, new = raw.split("=", 1)
    old, new = old.strip(), new.strip()
    if not old or not new:
        return None
    return old, new


def _write(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Patch one design/code-map.md system row."
    )
    ap.add_argument("--system", required=True, help="System row name (exact, else unique prefix)")
    ap.add_argument("--add", action="append", default=[], help="Live path to add (repeatable)")
    ap.add_argument("--remove", action="append", default=[], help="Live path to remove (repeatable)")
    ap.add_argument("--rename", action="append", default=[], help="old=new (repeatable)")
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    code_map = root / "design" / "code-map.md"
    out_dir = root / "_logs" / "code-map-patch"
    summary = out_dir / "summary.txt"
    out_dir.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now(timezone.utc).isoformat()
    lines = [
        f"code-map patch {stamp}",
        f"root={root}",
        f"system={args.system}",
    ]

    if not args.add and not args.remove and not args.rename:
        lines += ["", "RESULT changed=0 error=no-ops"]
        _write(summary, lines)
        print(f"Summary -> {summary}")
        return 1

    if not code_map.is_file():
        lines += ["", "RESULT changed=0 error=missing-code-map"]
        _write(summary, lines)
        print(f"Summary -> {summary}")
        return 1

    raw = code_map.read_text(encoding="utf-8")
    rows = cm.parse_rows(raw)
    row = cm.find_system(rows, args.system)
    if row is None:
        choices = cm.system_choices(rows, args.system)
        lines.append("matched=")
        lines.append("systems=" + ", ".join(choices))
        lines += ["", "RESULT changed=0 error=unknown-system"]
        _write(summary, lines)
        print(f"Summary -> {summary}")
        return 1

    lines.append(f"matched={row.system}")
    live = row.live
    added = 0
    removed = 0
    renamed = 0
    skipped = 0
    failed = 0

    for path in args.remove:
        live, resolved, action = cm.remove_path(live, path)
        if action == "removed":
            removed += 1
            lines.append(f"removed={resolved}")
        else:
            failed += 1
            lines.append(f"skip={cm.posix(path)} reason=not-listed")

    for spec in args.rename:
        parsed = _parse_rename(spec)
        if parsed is None:
            failed += 1
            lines.append(f"skip={spec} reason=bad-rename")
            continue
        old, new = parsed
        live, resolved, new_token, action = cm.rename_path(live, old, new)
        if action == "renamed":
            renamed += 1
            lines.append(f"renamed={resolved}->{new_token}")
        else:
            failed += 1
            lines.append(f"skip={cm.posix(old)} reason=not-listed")

    for path in args.add:
        live, token, action = cm.add_path(live, path)
        if action == "added":
            added += 1
            lines.append(f"added={cm.posix(path)} as={token}")
        else:
            skipped += 1
            lines.append(f"skip={cm.posix(path)} reason=already-listed")

    changed = int(live != row.live)
    if changed:
        file_lines = raw.splitlines(keepends=True)
        new_line = cm.format_row(row.system, live)
        old_line = file_lines[row.index]
        nl = "\n" if old_line.endswith("\n") else ""
        if old_line.endswith("\r\n"):
            nl = "\r\n"
            new_line = new_line.rstrip("\r\n")
        file_lines[row.index] = new_line + nl
        text = "".join(file_lines)
        if raw.endswith("\n") and not text.endswith("\n"):
            text += "\n"
        code_map.write_text(text, encoding="utf-8", newline="\n")

    lines.append(f"live={live}")
    lines.append("measure=mutate one code-map row; do not read the rest of the map")
    lines.append("")
    lines.append(
        f"RESULT changed={changed} added={added} removed={removed} "
        f"renamed={renamed} skipped={skipped} failed={failed}"
    )
    _write(summary, lines)
    print(
        f"changed={changed} added={added} removed={removed} "
        f"renamed={renamed} failed={failed}"
    )
    print(f"Summary -> {summary}")
    if failed:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
