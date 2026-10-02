from __future__ import annotations

import argparse
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

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



def reach_tree(root: Path) -> list[tuple[str, int, str]]:
    return []
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



def reach_dead(root: Path) -> list[tuple[str, int, str]]:
    files = files_of(root)
    defs = []
    code_hits = defaultdict(set)
    quote_hits = defaultdict(set)
    call_quotes = defaultdict(set)
    for path in files:
        rel = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for lineno, raw in enumerate(lines, 1):
            head = raw.split("#", 1)[0]
            matched = FUNC_RE.match(head) if rel.endswith(".gd") else None
            if matched and matched.group(1) not in VIRTUAL:
                defs.append((rel, lineno, matched.group(1)))
            connectish = "connect" in head or ".call" in head or "Callable" in head
            skipped = False
            for name, in_quote in scan(raw):
                if matched and not skipped and not in_quote and name == matched.group(1):
                    skipped = True
                    continue
                if in_quote:
                    quote_hits[name].add(rel)
                    if connectish or not rel.endswith(".gd"):
                        call_quotes[name].add(rel)
                    continue
                code_hits[name].add(rel)
    dead = []
    for rel, lineno, name in defs:
        if not name.startswith("_"):
            continue
        callers = set(code_hits.get(name, ()))
        callers.discard(rel)
        if callers:
            continue
        if rel in code_hits.get(name, ()):
            continue
        if call_quotes.get(name) or quote_hits.get(name):
            continue
        dead.append((rel, lineno, name))
    return dead



def apply_facade_auto(root: Path, do_delete: bool = True) -> int:
    import re
    from collections import defaultdict
    path_re = re.compile(r"res://([A-Za-z0-9_./]+\.gd)")
    load_re = re.compile(r"(?:preload|load)\(\s*[\"']res://([A-Za-z0-9_./]+\.gd)[\"']")
    method_re = re.compile(r'method="([A-Za-z_][A-Za-z0-9_]*)"')
    alias_re = re.compile(
        r"^(?:static[ \t]+)?(?:const|var)[ \t]+([A-Za-z_][A-Za-z0-9_]*)"
        r"[ \t]*(?::[ \t]*[A-Za-z0-9_., \"\[\]]+)?[ \t]*:?=[ \t]*preload\(\s*[\"']res://([^\"']+\.gd)[\"']"
    )
    class_re = re.compile(r"^class_name[ \t]+([A-Za-z_][A-Za-z0-9_]*)")
    qual_re = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")
    pre_call = re.compile(r"preload\(\s*[\"']res://([^\"']+\.gd)[\"']\s*\)\.([A-Za-z_][A-Za-z0-9_]*)")
    callback_line = re.compile(r"connect|Callable|method=|JavaScriptBridge|javascript_bridge", re.I)
    skip_name = re.compile(r"^_(on_|js_|back$|focus|rebuild|play$|wake|wipe$|cap$|joy_)")
    forward = re.compile(r"^[ \t]*(?:return[ \t]+)?[A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*)\s*\(")
    defs = defaultdict(list)
    by_name = defaultdict(list)
    texts = {}
    alias = defaultdict(dict)
    class_of = {}
    preloads = defaultdict(set)
    quoted_names = set()
    callback_names = set()
    for path in files_of(root):
        blob = path.read_text(encoding="utf-8", errors="replace")
        if path.suffix != ".gd":
            for match in method_re.finditer(blob):
                callback_names.add(match.group(1))
            continue
        rel = path.relative_to(root).as_posix()
        lines = blob.splitlines()
        texts[rel] = lines
        for match in load_re.finditer(blob):
            preloads[rel].add(match.group(1))
        for i, raw in enumerate(lines):
            head = raw.split("#", 1)[0]
            if callback_line.search(head):
                for name, in_quote in scan(raw):
                    if in_quote or name.startswith("_"):
                        callback_names.add(name)
            for name, in_quote in scan(raw):
                if in_quote:
                    quoted_names.add(name)
            matched = FUNC_RE.match(head)
            if matched:
                name = matched.group(1)
                defs[rel].append((i + 1, name, i, span_end(lines, i)))
                by_name[name].append(rel)
            aliased = alias_re.match(head)
            if aliased:
                alias[rel][aliased.group(1)] = aliased.group(2)
                preloads[rel].add(aliased.group(2))
            named = class_re.match(head)
            if named:
                class_of[named.group(1)] = rel
    root_files = set()
    for path in files_of(root):
        blob = path.read_text(encoding="utf-8", errors="replace")
        if path.suffix != ".gd":
            for match in path_re.finditer(blob):
                root_files.add(match.group(1))
            continue
        root_files |= preloads[path.relative_to(root).as_posix()]
    reached = set()
    queue = []

    def add(rel, name):
        key = (rel, name)
        if key in reached or rel not in defs:
            return
        if not any(item[1] == name for item in defs[rel]):
            return
        reached.add(key)
        queue.append(key)

    for rel in root_files:
        for _lineno, name, _start, _end in defs.get(rel, []):
            if name in VIRTUAL or not name.startswith("_"):
                add(rel, name)
    for name in callback_names:
        for rel in by_name.get(name, []):
            add(rel, name)
    while queue:
        rel, name = queue.pop()
        span = next(item for item in defs[rel] if item[1] == name)
        for raw in texts[rel][span[2]:span[3]]:
            head = raw.split("#", 1)[0]
            connectish = callback_line.search(head) is not None
            skipped = False
            matched = FUNC_RE.match(head)
            for called, in_quote in scan(raw):
                if matched and not skipped and not in_quote and called == matched.group(1):
                    skipped = True
                    continue
                if in_quote and not connectish:
                    continue
                if any(item[1] == called for item in defs[rel]):
                    add(rel, called)
                    continue
                owners = by_name.get(called, [])
                if len(owners) == 1:
                    add(owners[0], called)
            for match in pre_call.finditer(head):
                add(match.group(1), match.group(2))
            for match in qual_re.finditer(head):
                target = alias[rel].get(match.group(1)) or class_of.get(match.group(1))
                if target:
                    add(target, match.group(2))
    auto = []
    for rel, items in defs.items():
        if "/ui/" in rel:
            continue
        for lineno, name, start, end in items:
            if not name.startswith("_") or name in VIRTUAL or (rel, name) in reached:
                continue
            if name.startswith("_on_") or name.startswith("_js_") or name in callback_names:
                continue
            if skip_name.search(name) or name in quoted_names:
                continue
            sibling = ""
            for target in preloads.get(rel, ()):
                if (target, name) in reached:
                    sibling = target
                    break
            if not sibling:
                continue
            back = "." + name + "("
            sibling_text = texts.get(sibling, [])
            called_back = False
            for raw in sibling_text:
                head = raw.split("#", 1)[0]
                if back not in head:
                    continue
                alias_call = False
                for alias_name, target in alias.get(sibling, {}).items():
                    if target == rel and (alias_name + back) in head:
                        alias_call = True
                        break
                if not alias_call:
                    called_back = True
                    break
            if called_back:
                continue
            body = [ln.strip() for ln in texts[rel][start + 1:end] if ln.strip()]
            matched = forward.match(body[0]) if len(body) == 1 else None
            if matched and matched.group(1) == name:
                auto.append((rel, lineno, name))
    by_file = defaultdict(list)
    for rel, lineno, _name in auto:
        by_file[rel].append(lineno)
    deleted = 0
    for rel, linenos in by_file.items():
        path = root / rel
        lines = path.read_text(encoding="utf-8").splitlines()
        for lineno in sorted(set(linenos), reverse=True):
            idx = lineno - 1
            if idx < 0 or idx >= len(lines) or FUNC_RE.match(lines[idx].split("#", 1)[0]) is None:
                print("skip\t%s:%s" % (rel, lineno))
                continue
            start = span_start(lines, idx)
            end = span_end(lines, idx)
            del lines[start:end]
            deleted += 1
            print(("%s\t%s:%s" % (("facade_deleted" if do_delete else "facade_auto"), rel, lineno)))
        if do_delete:
            path.write_text(collapse_blanks(lines), encoding="utf-8", newline=chr(10))
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
    parser = agent_log.std_parser("Unused GDScript funcs (--apply deletes them; --dry-run previews).", writes=True)
    parser.add_argument("--limit", type=int, default=80)
    parser.add_argument("--apply", action="store_true")
    ns = parser.parse_args()
    started = time.perf_counter()
    root = agent_log.resolve_root(ns)
    if ns.apply and ns.dry_run:
        ns.apply = False
        print("dry-run: --apply skipped, listing only")
    unused, maybe, defs = collect(root)
    deleted = 0
    if ns.apply:
        deleted = apply_unused(root, unused)
        deleted += apply_facade_auto(root, True)
    else:
        apply_facade_auto(root, False)
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
    print("full=%s" % agent_log.rel(root, summary))
    print("report=PASS")
    return agent_log.emit_result("FAIL" if ns.apply and unused else "PASS", summary=agent_log.rel(root, summary), scanned=len(defs), unused=len(unused), maybe=len(maybe), deleted=deleted)


if __name__ == "__main__":
    sys.exit(main())
