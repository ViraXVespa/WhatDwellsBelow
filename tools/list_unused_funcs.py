from __future__ import annotations

import argparse
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

FUNC_RE = re.compile(
    r"^(?:static[ \t]+)?func[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\("
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


def scan(line: str):
    i = 0
    n = len(line)
    quote = ""
    while i < n:
        ch = line[i]
        if quote:
            if ch == "\\" and i + 1 < n:
                i += 2
                continue
            if ch == quote:
                quote = ""
                i += 1
                continue
            if ch.isalpha() or ch == "_":
                j = i + 1
                while j < n and (line[j].isalnum() or line[j] == "_"):
                    j += 1
                yield line[i:j], True
                i = j
                continue
            i += 1
            continue
        if ch == "#":
            return
        if ch in "\"'":
            quote = ch
            i += 1
            continue
        if ch.isalpha() or ch == "_":
            j = i + 1
            while j < n and (line[j].isalnum() or line[j] == "_"):
                j += 1
            yield line[i:j], False
            i = j
            continue
        i += 1


def files_of(root: Path) -> list[Path]:
    found = sorted((root / "scripts").rglob("*.gd"))
    scenes = root / "scenes"
    if scenes.is_dir():
        found.extend(sorted(scenes.rglob("*.tscn")))
    project = root / "project.godot"
    if project.is_file():
        found.append(project)
    return found


def collect(root: Path):
    hits: Counter[str] = Counter()
    quoted: Counter[str] = Counter()
    defs: list[tuple[str, int, str]] = []
    sizes: dict[str, int] = {}
    for path in files_of(root):
        rel = path.relative_to(root).as_posix()
        if rel.endswith(".gd"):
            sizes[rel] = path.stat().st_size
        text = path.read_text(encoding="utf-8", errors="replace")
        for lineno, raw in enumerate(text.splitlines(), 1):
            skip = ""
            if rel.endswith(".gd"):
                matched = FUNC_RE.match(raw.split("#", 1)[0])
                if matched:
                    skip = matched.group(1)
                    if skip not in VIRTUAL:
                        defs.append((rel, lineno, skip))
            skipped = False
            for name, in_quote in scan(raw):
                if skip and not skipped and not in_quote and name == skip:
                    skipped = True
                    continue
                hits[name] += 1
                if in_quote:
                    quoted[name] += 1
    unused = []
    maybe = []
    for rel, lineno, name in defs:
        used = hits[name]
        if used == 0:
            unused.append((rel, lineno, name, sizes.get(rel, 0)))
        elif quoted[name] == used:
            maybe.append((rel, lineno, name, sizes.get(rel, 0)))
    return unused, maybe, defs


DECL_END = re.compile(
    "^(?P<indent>[ " + chr(9) + "]*)(?:static[ " + chr(9) + "]+)?(?:func|const|var|class_name|enum|signal)[ " + chr(9) + "]+"
)


def span_end(lines: list[str], start: int) -> int:
    base = re.match(r"[ \t]*", lines[start]).group(0)
    end = start + 1
    while end < len(lines):
        raw = lines[end]
        if raw.strip() == "":
            end += 1
            continue
        body = raw.lstrip(" \t")
        indent = raw[: len(raw) - len(body)]
        if indent == base and body.startswith("#") and not body.startswith("##"):
            break
        matched = DECL_END.match(raw)
        if matched and matched.group("indent") == base:
            break
        if len(indent) < len(base) and not body.startswith("#"):
            break
        end += 1
    while end > start + 1 and lines[end - 1].strip() == "":
        end -= 1
    return end
def span_start(lines: list[str], func_at: int) -> int:
    start = func_at
    while start > 0:
        prev = lines[start - 1].strip()
        if prev.startswith("@") or prev.startswith("##"):
            start -= 1
            continue
        break
    return start


def collapse_blanks(lines: list[str]) -> str:
    out: list[str] = []
    blank = 0
    for line in lines:
        if line.strip() == "":
            blank += 1
            if blank == 1:
                out.append("")
            continue
        blank = 0
        out.append(line)
    while out and out[0] == "":
        out.pop(0)
    text = "\n".join(out)
    if text and not text.endswith("\n"):
        text += "\n"
    return text


def apply_unused(root: Path, unused: list[tuple[str, int, str, int]]) -> int:
    by_file: dict[str, list[int]] = defaultdict(list)
    for rel, lineno, _name, _nbytes in unused:
        by_file[rel].append(lineno)
    deleted = 0
    for rel, linenos in by_file.items():
        path = root / rel
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for lineno in sorted(set(linenos), reverse=True):
            idx = lineno - 1
            if idx < 0 or idx >= len(lines):
                print("skip\t%s:%s\tmissing" % (rel, lineno))
                continue
            if FUNC_RE.match(lines[idx].split("#", 1)[0]) is None:
                print("skip\t%s:%s\tnot a func line" % (rel, lineno))
                continue
            start = span_start(lines, idx)
            end = span_end(lines, idx)
            del lines[start:end]
            deleted += 1
        text = collapse_blanks(lines)
        path.write_text(text, encoding="utf-8", newline=chr(10))
        if not FUNC_RE.search(text):
            res = "res://" + rel
            held = False
            for other in files_of(root):
                if other.resolve() == path.resolve():
                    continue
                blob = other.read_text(encoding="utf-8", errors="replace")
                if res in blob or rel in blob:
                    held = True
                    break
            if not held:
                path.unlink()
                print("deleted_file\t%s" % rel)
    return deleted


def write_summary(root: Path, unused, maybe, defs, elapsed: float) -> Path:
    log_dir = root / "_logs" / "unused-funcs"
    log_dir.mkdir(parents=True, exist_ok=True)
    summary = log_dir / "summary.txt"
    rows = []
    for kind, items in (("unused", unused), ("maybe", maybe)):
        for rel, lineno, name, nbytes in items:
            rows.append("%s\t%s:%s\t%s\t%s" % (kind, rel, lineno, name, nbytes))
    rows.append("funcs_scanned=%s" % len(defs))
    rows.append("unused_count=%s" % len(unused))
    rows.append("maybe_count=%s" % len(maybe))
    rows.append("seconds=%.2f" % elapsed)
    summary.write_text("\n".join(rows) + "\n", encoding="utf-8", newline="\n")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Unused GDScript funcs")
    parser.add_argument("--limit", type=int, default=80)
    parser.add_argument("--apply", action="store_true")
    ns = parser.parse_args()
    started = time.perf_counter()
    root = repo_root()
    unused, maybe, defs = collect(root)
    deleted = 0
    if ns.apply:
        deleted = apply_unused(root, unused)
        unused, maybe, defs = collect(root)
    elapsed = time.perf_counter() - started
    summary = write_summary(root, unused, maybe, defs, elapsed)
    shown = 0
    for rel, lineno, name, nbytes in unused:
        if shown >= ns.limit:
            break
        print("unused\t%s:%s\t%s\t%s" % (rel, lineno, name, nbytes))
        shown += 1
    print("funcs_scanned=%s" % len(defs))
    print("unused_count=%s" % len(unused))
    print("maybe_count=%s" % len(maybe))
    print("deleted=%s" % deleted)
    print("seconds=%.2f" % elapsed)
    print("full=%s" % summary.as_posix())
    print("report=PASS")
    if ns.apply and unused:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
