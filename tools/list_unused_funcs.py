#!/usr/bin/env python3
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


IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
KEY_AFTER = re.compile(r"[ \t]*:(?!=)")  # {"key": v}
KEY_BEFORE = re.compile(r"(?:\.get|\.has|\.erase)\([ \t]*$|(?<=[\w)\]])\[[ \t]*$")  # d.get("key"), d["key"]
DYN = re.compile(r"call|connect|Callable|has_method|emit_signal|method=|bind|callback")


def scan(line: str):
    """Yield (identifier, in_quote). A string literal only yields when the whole literal is one
    identifier (a method/signal name); prose such as "sweep drop %s" is not a reference."""
    i = 0
    n = len(line)
    triple = '"""' in line or "'''" in line  # multi-line string edge (GLSL): count every word, never lose a hit
    while i < n:
        ch = line[i]
        if ch == "#" and not triple:
            return
        if ch in "\"'" and not triple:
            j = i + 1
            while j < n and line[j] != ch:
                j += 2 if line[j] == "\\" else 1
            lit = line[i + 1:j]
            if IDENT.fullmatch(lit) and not (KEY_AFTER.match(line, j + 1) or KEY_BEFORE.search(line, 0, i)):
                yield lit, True
            i = j + 1
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
    """GDScript plus every non-script file that can name a func (scenes, flow json, web shells)."""
    found = sorted((root / "scripts").rglob("*.gd"))
    for sub, pats in (("scenes", ("*.tscn", "*.tres")), ("tools", ("*.json", "*.js", "*.html")), ("site", ("*.js", "*.html"))):
        base = root / sub
        if base.is_dir():
            for pat in pats:
                found.extend(sorted(base.rglob(pat)))
    project = root / "project.godot"
    if project.is_file():
        found.append(project)
    return found


DECL_RE = re.compile(r"^(const|signal)[ \t]+([A-Za-z_][A-Za-z0-9_]*)")
# Tunable registry: read by tools/tunables.py and docs, so an unreferenced const is a knob, not dead code.
KEEP_DECLS = frozenset({"scripts/data/tunables.gd"})


def collect(root: Path):
    """Returns (unused funcs, maybe funcs, defs, dynamic funcs, unused const/signal decls).
    maybe = named only by a whole-string literal outside a call context; dynamic = such a literal
    on a call/connect/Callable line (live)."""
    hits: Counter[str] = Counter()
    quoted: Counter[str] = Counter()
    dyn: Counter[str] = Counter()
    defs: list[tuple[str, int, str]] = []
    decls: list[tuple[str, int, str, int]] = []
    sizes: dict[str, int] = {}
    for path in files_of(root):
        rel = path.relative_to(root).as_posix()
        is_gd = rel.endswith(".gd")
        if is_gd:
            sizes[rel] = path.stat().st_size
        text = path.read_text(encoding="utf-8", errors="replace")
        for lineno, raw in enumerate(text.splitlines(), 1):
            skip = ""
            if is_gd:
                head = raw.split("#", 1)[0]
                matched = FUNC_RE.match(head)
                if matched:
                    skip = matched.group(1)
                    if skip not in VIRTUAL:
                        defs.append((rel, lineno, skip))
                matched = DECL_RE.match(head)
                if matched and rel not in KEEP_DECLS:
                    skip = matched.group(2)
                    decls.append((rel, lineno, skip, sizes.get(rel, 0)))
            skipped = False
            for name, in_quote in scan(raw):
                if skip and not skipped and not in_quote and name == skip:
                    skipped = True
                    continue
                hits[name] += 1
                if in_quote:
                    quoted[name] += 1
                    if DYN.search(raw) or not is_gd:
                        dyn[name] += 1
    unused = []
    maybe = []
    dynamic = []
    for rel, lineno, name in defs:
        used = hits[name]
        row = (rel, lineno, name, sizes.get(rel, 0))
        if used == 0:
            unused.append(row)
        elif quoted[name] == used:
            (dynamic if dyn[name] else maybe).append(row)
    dead_decls = [row for row in decls if hits[row[2]] == 0]
    return unused, maybe, defs, dynamic, dead_decls


ALIAS_RE = re.compile(r"^(?:static[ \t]+)?const[ \t]+([A-Za-z_]\w*)[ \t]*(?::[^=]*)?:?=[ \t]*(?:pre)?load\([ \t]*[\"']res://([^\"']+\.gd)[\"']")
CLASS_RE = re.compile(r"^class_name[ \t]+([A-Za-z_]\w*)")
EXTENDS_RE = re.compile(r"^extends[ \t]+(?:\"res://([^\"]+\.gd)\"|([A-Za-z_]\w*))")
USE_RE = re.compile(r"(?:([A-Za-z_]\w*)[ \t]*\.[ \t]*|(\.)[ \t]*)?\b([A-Za-z_]\w*)\b")


def code_of(raw: str) -> str:
    """Line with comments and string literals blanked (whole-identifier literals are kept as dynamic refs elsewhere)."""
    if '"""' in raw or "'''" in raw:
        return raw
    out = []
    i = 0
    n = len(raw)
    while i < n:
        ch = raw[i]
        if ch == "#":
            break
        if ch in "\"'":
            j = i + 1
            while j < n and raw[j] != ch:
                j += 2 if raw[j] == "\\" else 1
            out.append(" " * (j + 1 - i))
            i = j + 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def collision_dead(root: Path, plain_unused: list) -> list[tuple[str, int, str, int]]:
    """Funcs whose name is defined in 2+ files, so the bare-name count cannot tell them apart.
    A def is dead when nothing resolves to it: no `Alias.name` whose alias preloads that file (or
    class_name), no bare call in its own file, no receiver we cannot resolve (`host.name`, `x.name`,
    `).name`), no whole-string reference. Unresolved receivers count for every same-named def."""
    texts: dict[str, list[str]] = {}
    sizes: dict[str, int] = {}
    parent: dict[str, str] = {}
    other_words: set[str] = set()
    alias: dict[str, dict[str, str]] = defaultdict(dict)
    klass: dict[str, str] = {}
    defs_by: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for path in files_of(root):
        rel = path.relative_to(root).as_posix()
        if not rel.endswith(".gd"):
            other_words.update(IDENT.findall(path.read_text(encoding="utf-8", errors="replace")))
            continue
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        texts[rel] = lines
        sizes[rel] = path.stat().st_size
        for lineno, raw in enumerate(lines, 1):
            head = raw.split("#", 1)[0]
            matched = EXTENDS_RE.match(head)
            if matched:
                parent[rel] = matched.group(1) or matched.group(2)
            matched = FUNC_RE.match(head)
            if matched and matched.group(1) not in VIRTUAL:
                defs_by[matched.group(1)].append((rel, lineno))
            matched = ALIAS_RE.match(head)
            if matched:
                alias[rel][matched.group(1)] = matched.group(2)
            matched = CLASS_RE.match(head)
            if matched:
                klass[matched.group(1)] = rel
    multi = {n: d for n, d in defs_by.items() if len({r for r, _ in d}) > 1}
    live: set[tuple[str, str]] = set()
    everyone: set[str] = {n for n in multi if n in other_words}

    def mark(target: str, name: str) -> None:
        while target and (target, name) not in live:
            live.add((target, name))
            up = parent.get(target, "")
            target = up if up.endswith(".gd") else klass.get(up, "")

    own = {n: {r for r, _ in d} for n, d in multi.items()}
    for rel, lines in texts.items():
        for raw in lines:
            for name, in_quote in scan(raw):
                if in_quote and name in multi:
                    everyone.add(name)
            if not any(n in raw for n in multi):
                continue
            code = code_of(raw)
            is_def = FUNC_RE.match(code) is not None
            for m in USE_RE.finditer(code):
                name = m.group(3)
                if name not in multi:
                    continue
                if is_def and FUNC_RE.match(code).group(1) == name and m.start(3) == code.index(name):
                    continue
                recv, dot = m.group(1), m.group(2)
                if recv in ("self", "super"):
                    recv = None
                if recv:
                    target = alias[rel].get(recv) or klass.get(recv)
                    if target:
                        mark(target, name)
                    else:
                        everyone.add(name)
                elif dot:
                    everyone.add(name)
                elif rel in own[name]:
                    mark(rel, name)
                else:
                    everyone.add(name)
    seen = {(r, ln) for r, ln, _n, _s in plain_unused}
    dead = []
    for name, found in multi.items():
        if name in everyone:
            continue
        for rel, lineno in found:
            if (rel, name) not in live and (rel, lineno) not in seen:
                dead.append((rel, lineno, name, sizes.get(rel, 0)))
    return sorted(dead)


def dead_aliases(root: Path, known: list) -> list[tuple[str, int, str, int]]:
    """`const X := preload(...)` aliases never used in their own file and never read as `.X` elsewhere
    (the bare-name count cannot see these when other files reuse the alias name)."""
    texts: dict[str, list[str]] = {}
    for path in files_of(root):
        if path.suffix == ".gd":
            texts[path.relative_to(root).as_posix()] = path.read_text(encoding="utf-8", errors="replace").splitlines()
    dotted: set[str] = set()
    for lines in texts.values():
        for raw in lines:
            dotted.update(re.findall(r"\.[ \t]*([A-Za-z_]\w*)", code_of(raw)))
    seen = {(r, ln) for r, ln, _n, _s in known}
    dead = []
    for rel, lines in texts.items():
        for lineno, raw in enumerate(lines, 1):
            matched = ALIAS_RE.match(raw.split("#", 1)[0])
            if not matched or (rel, lineno) in seen or rel in KEEP_DECLS:
                continue
            name = matched.group(1)
            if name in dotted:
                continue
            uses = sum(1 for i, ln in enumerate(lines, 1) if i != lineno for n, _q in scan(ln) if n == name)
            if uses == 0:
                dead.append((rel, lineno, name, 0))
    return dead


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
        funcs_cut = False
        for lineno in sorted(set(linenos), reverse=True):
            idx = lineno - 1
            if idx < 0 or idx >= len(lines):
                print("skip\t%s:%s\tmissing" % (rel, lineno))
                continue
            head = lines[idx].split("#", 1)[0]
            is_func = FUNC_RE.match(head) is not None
            if not is_func and DECL_RE.match(head) is None:
                print("skip\t%s:%s\tnot a func/const/signal line" % (rel, lineno))
                continue
            funcs_cut = funcs_cut or is_func
            start = span_start(lines, idx)
            end = span_end(lines, idx)
            del lines[start:end]
            deleted += 1
        text = collapse_blanks(lines)
        path.write_text(text, encoding="utf-8", newline=chr(10))
        if funcs_cut and not FUNC_RE.search(text):
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
                path.with_name(path.name + ".uid").unlink(missing_ok=True)
                print("deleted_file\t%s" % rel)
    return deleted



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


def write_summary(root: Path, found: dict, nfuncs: int, elapsed: float) -> Path:
    rows = []
    for kind, items in found.items():
        for rel, lineno, name, nbytes in items:
            rows.append("%s\t%s:%s\t%s\t%s" % (kind, rel, lineno, name, nbytes))
    rows.append("funcs_scanned=%s" % nfuncs)
    for kind, items in found.items():
        rows.append("%s_count=%s" % (kind, len(items)))
    rows.append("seconds=%.2f" % elapsed)
    return agent_log.write_summary("unused-funcs", root, "\n".join(rows), "INFO", f"funcs_scanned={nfuncs}")


def main() -> int:
    parser = agent_log.std_parser(
        "Unused GDScript funcs, consts and signals (--apply deletes the unused ones; --dry-run previews). "
        "unused = zero references anywhere; shadowed = name defined in 2+ files and no use resolves to this def (alias/class_name/extends aware, unresolved receivers keep every same-named def); maybe = only a bare-name string literal outside a call "
        "(check by hand); dynamic = named in call_deferred/call/connect/Callable/scene (live, listed in the summary). "
        "scripts/data/tunables.gd consts are knobs and never listed.", writes=True)
    parser.add_argument("--limit", type=int, default=80, help="Max rows listed (default 80).")
    parser.add_argument("--apply", action="store_true", help="DELETE the listed funcs (only when an opt item says so).")
    ns = parser.parse_args()
    started = time.perf_counter()
    root = agent_log.resolve_root(ns)
    if ns.apply and ns.dry_run:
        ns.apply = False
        print("dry-run: --apply skipped, listing only")
    unused, maybe, defs, dynamic, decls = collect(root)
    shadowed = collision_dead(root, unused)
    decls = decls + dead_aliases(root, decls)
    deleted = 0
    if ns.apply:
        for _pass in range(8):
            cut = apply_unused(root, unused + decls + shadowed)
            deleted += cut
            unused, maybe, defs, dynamic, decls = collect(root)
            shadowed = collision_dead(root, unused)
            decls = decls + dead_aliases(root, decls)
            if cut == 0 or not (unused or decls or shadowed):
                break
        deleted += apply_facade_auto(root, True)
        unused, maybe, defs, dynamic, decls = collect(root)
        shadowed = collision_dead(root, unused)
        decls = decls + dead_aliases(root, decls)
    else:
        apply_facade_auto(root, False)
    elapsed = time.perf_counter() - started
    found = {"unused": unused, "shadowed": shadowed, "decl": decls, "maybe": maybe, "dynamic": dynamic}
    summary = write_summary(root, found, len(defs), elapsed)
    shown = 0
    for kind in ("unused", "shadowed", "decl", "maybe"):
        for rel, lineno, name, nbytes in found[kind]:
            if shown >= ns.limit:
                break
            print("%s\t%s:%s\t%s\t%s" % (kind, rel, lineno, name, nbytes))
            shown += 1
    print("funcs_scanned=%s" % len(defs))
    print("unused_count=%s" % len(unused))
    print("shadowed_count=%s" % len(shadowed))
    print("decl_count=%s" % len(decls))
    print("maybe_count=%s" % len(maybe))
    print("dynamic_count=%s" % len(dynamic))
    print("deleted=%s" % deleted)
    print("seconds=%.2f" % elapsed)
    print("full=%s" % agent_log.rel(root, summary))
    print("report=PASS")
    left = len(unused) + len(decls) + len(shadowed)
    return agent_log.emit_result("FAIL" if ns.apply and left else "PASS", summary=agent_log.rel(root, summary), scanned=len(defs), unused=len(unused), shadowed=len(shadowed), decl=len(decls), maybe=len(maybe), dynamic=len(dynamic), deleted=deleted)


if __name__ == "__main__":
    sys.exit(main())
