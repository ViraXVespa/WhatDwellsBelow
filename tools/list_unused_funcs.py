"""Candidate unused GDScript functions. Report only. Does not edit.

A name is unused when it never appears outside its own func line in
scripts/, scenes/, and project.godot. Engine callbacks are skipped.
A name that appears only inside quotes is maybe, not unused.

  python tools/list_unused_funcs.py
  python tools/list_unused_funcs.py --limit 40
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FUNC_RE = re.compile(
    r"^(?P<indent>[ \t]*)(?:static[ \t]+)?func[ \t]+(?P<name>[A-Za-z_][A-Za-z0-9_]*)[ \t]*\("
)
VIRTUAL = frozenset({
    "_init", "_static_init", "_enter_tree", "_exit_tree", "_ready",
    "_process", "_physics_process", "_input", "_shortcut_input",
    "_unhandled_input", "_unhandled_key_input", "_gui_input", "_draw",
    "_notification", "_get_configuration_warnings", "_get_property_list",
    "_validate_property", "_set", "_get", "_property_can_revert",
    "_property_get_revert", "_to_string", "_iter_init", "_iter_next",
    "_iter_get", "_can_drop_data", "_drop_data", "_get_drag_data",
    "_make_custom_tooltip", "_get_minimum_size", "_has_point",
    "_clips_input", "_mouse_enter", "_mouse_exit", "_import",
    "_export_begin", "_export_end",
})


def repo_root() -> Path:
    here = Path(__file__).resolve().parents[1]
    if (here / "project.godot").is_file() and (here / "scripts").is_dir():
        return here
    raise SystemExit("FAIL list_unused_funcs: run from the WhatDwellsBelow checkout")


def strip_comment(line: str) -> str:
    out = []
    quote = ""
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == "\\" and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = ""
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == "#":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def quoted_only(line: str, name: str) -> bool:
    bare = re.sub(r"(\"[^\"]*\"|'[^']*')", " ", line)
    return re.search(r"\b" + re.escape(name) + r"\b", bare) is None


def load_corpus(root: Path) -> list[tuple[str, list[str]]]:
    files: list[Path] = []
    files.extend(sorted((root / "scripts").rglob("*.gd")))
    if (root / "scenes").is_dir():
        files.extend(sorted((root / "scenes").rglob("*.tscn")))
    project = root / "project.godot"
    if project.is_file():
        files.append(project)
    corpus = []
    for path in files:
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        corpus.append((rel, text.splitlines()))
    return corpus


def main() -> int:
    p = argparse.ArgumentParser(description="Candidate unused GDScript funcs")
    p.add_argument("--limit", type=int, default=80)
    ns = p.parse_args()
    root = repo_root()
    corpus = load_corpus(root)
    defs: list[tuple[str, int, str]] = []
    sizes: dict[str, int] = {}
    for rel, lines in corpus:
        if not rel.endswith(".gd"):
            continue
        sizes[rel] = (root / rel).stat().st_size
        for i, line in enumerate(lines, 1):
            m = FUNC_RE.match(strip_comment(line))
            if not m:
                continue
            name = m.group("name")
            if name in VIRTUAL:
                continue
            defs.append((rel, i, name))
    unused = []
    maybe = []
    for rel, lineno, name in defs:
        token = re.compile(r"\b" + re.escape(name) + r"\b")
        def_line = re.compile(r"\bfunc[ \t]+" + re.escape(name) + r"[ \t]*\(")
        uses = 0
        quoted = 0
        for crel, lines in corpus:
            for i, raw in enumerate(lines, 1):
                line = strip_comment(raw)
                if not token.search(line):
                    continue
                if crel == rel and i == lineno:
                    continue
                if def_line.search(line):
                    continue
                uses += 1
                if quoted_only(line, name):
                    quoted += 1
        row = (rel, lineno, name, sizes.get(rel, 0))
        if uses == 0:
            unused.append(row)
        elif quoted == uses:
            maybe.append(row)
    log_dir = root / "_logs" / "unused-funcs"
    log_dir.mkdir(parents=True, exist_ok=True)
    summary = log_dir / "summary.txt"
    lines_out = []
    for kind, rows in (("unused", unused), ("maybe", maybe)):
        for rel, lineno, name, nbytes in rows:
            lines_out.append(f"{kind}\t{rel}:{lineno}\t{name}\t{nbytes}")
    lines_out.append(f"funcs_scanned={len(defs)}")
    lines_out.append(f"unused_count={len(unused)}")
    lines_out.append(f"maybe_count={len(maybe)}")
    summary.write_text("\n".join(lines_out) + "\n", encoding="utf-8", newline="\n")
    shown = 0
    for line in lines_out:
        if line.startswith("funcs_scanned=") or line.startswith("unused_count=") or line.startswith("maybe_count="):
            print(line)
            continue
        if shown >= ns.limit:
            continue
        print(line)
        shown += 1
    hidden = len(unused) + len(maybe) - shown
    if hidden > 0:
        print(f"hidden={hidden}\tfull={summary.as_posix()}")
    else:
        print(f"full={summary.as_posix()}")
    print("report=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
