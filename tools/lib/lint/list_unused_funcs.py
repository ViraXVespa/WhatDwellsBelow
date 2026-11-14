#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

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

SCAN_SUFFIX = (".gd", ".tscn", ".tres", ".json", ".js", ".html", ".godot", ".gdshader", ".gdshaderinc", ".py", ".cfg")

def files_of(root: Path) -> list[Path]:
    """GDScript plus every non-script file that can name a func (scenes, flow json, web shells).
    Tracked + untracked-not-ignored files only; node_modules, caches, logs and archives are skipped
    (unused_graph.listing), so a vendored directory named like a file can no longer crash the walk."""
    import unused_graph
    return [p for p in unused_graph.listing(root) if p.suffix in SCAN_SUFFIX and p.is_file()]

DECL_RE = re.compile(r"^(const|signal)[ \t]+([A-Za-z_][A-Za-z0-9_]*)")
# Tunable registry: read by tools/docs.py tunable and docs, so an unreferenced const is a knob, not dead code.
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
            start = span_start(lines, idx)
            end = span_end(lines, idx)
            del lines[start:end]
            deleted += 1
        text = collapse_blanks(lines)
        path.write_text(text, encoding="utf-8", newline=chr(10))
    return deleted

def facade_auto(root: Path) -> list[tuple[str, int, str, int]]:
    """One-line private forwarders whose twin in a preloaded sibling is live and never calls back: report only."""
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
    return [(rel, lineno, name, 0) for rel, lineno, name in sorted(auto)]

REPORT = ("orphan_file", "unused", "shadowed", "dead_chain", "unused_var", "write_only_var", "init_only_var",
          "arity_mismatch", "debug_only", "ambiguous")
LEGACY = ("decl", "maybe", "facade_auto", "dynamic")
VAR_LINE = re.compile(r"^(?:static[ \t]+)?var[ \t]+([A-Za-z_]\w*)\b")
PURE_INIT = re.compile(r"^[^()]*$|^(?:Vector[234]i?|Color|Rect2i?|Transform[23]D|Basis|Quaternion|Packed\w+Array|Array|Dictionary|StringName|NodePath)\([^()]*\)[ \t]*$")

def analyse(root: Path) -> tuple[object, dict]:
    import unused_graph
    g = unused_graph.Graph(root)
    return g, g.analyse()

def multiline_decl(lines: list[str], idx: int) -> bool:
    """A var/const/signal line that opens a block, continues, or has an indented body under it."""
    head = lines[idx].split("#", 1)[0].rstrip() if 0 <= idx < len(lines) else ""
    nxt = lines[idx + 1] if idx + 1 < len(lines) else ""
    return head.endswith(("(", "[", "{", ",", "\\", ":")) or bool(nxt.strip() and nxt[:1].isspace())

def _is_design_md(rel: str) -> bool:
    """True when the only mention is a design doc (not a live call, shot-flow, or tool runner)."""
    p = rel.replace("\\", "/")
    return p.startswith("design/") and p.endswith(".md")

def plan_of(root: Path, g, rows: dict, decls: list) -> tuple[list[dict], list[dict]]:
    """Verified removals (unused_graph.verified + var/decl side-effect checks) and refusals, each with evidence."""
    import unused_graph
    ok, refused = unused_graph.verified(g, rows, unused_graph.load_hold(root))
    plan = []
    words = text_words(root)
    for r in ok + [dict(kind="decl", rel=a, line=b, name=c, conf="high", why="const/signal/alias with zero references in any scanned file") for a, b, c, _n in decls]:
        if (r["rel"], r["name"]) in unused_graph.load_hold(root):
            continue
        seen = [w for w in words.get(r["name"], []) if w != r["rel"]] if r["kind"] != "orphan_file" else []
        # 0c: a design/*.md word-hit alone must not block high-confidence shadowed/dead_chain.
        # 0d: the same doc-only mention must not block a high unused_var (JSON, tools, and other
        # docs still hold). Unused funcs + any doc mention stay refused (documented_fn).
        if r["kind"] in ("shadowed", "dead_chain"):
            hold_hits = [w for w in seen if not _is_design_md(w)]
        elif r["kind"] == "unused_var":
            if r["rel"].replace("\\", "/").startswith("scripts/data/balance/"):
                refused.append(dict(r, refuse="balance unused_var is not auto-promoted"))
                continue
            hold_hits = [w for w in seen if not _is_design_md(w)]
        else:
            hold_hits = seen
        if hold_hits:
            refused.append(dict(r, refuse="name appears in non-GDScript text: " + ", ".join(sorted(hold_hits)[:3])))
            continue
        if r["kind"] == "decl" and r["rel"] in g.scripts and multiline_decl(g.scripts[r["rel"]].lines, r["line"] - 1):
            refused.append(dict(r, refuse="multi-line declaration"))
            continue
        if r["kind"] == "unused_var":
            raw = g.scripts[r["rel"]].lines[r["line"] - 1]
            init = raw.split("#", 1)[0].split("=", 1)[1].strip() if "=" in raw.split("#", 1)[0] else ""
            init = init.lstrip(":= ").strip() if init else ""
            lines = g.scripts[r["rel"]].lines
            nxt = lines[r["line"]] if r["line"] < len(lines) else ""
            block = raw.split("#", 1)[0].rstrip().endswith((":", "(", "[", "{", "\\")) or (nxt.strip() and nxt[:1].isspace())
            if VAR_LINE.match(raw) is None or (init and PURE_INIT.match(init) is None) or block or "set(" in raw or "get:" in raw:
                refused.append(dict(r, refuse="property block (get/set), multi-line or call initializer: side effects possible"))
                continue
        plan.append(dict(r, evidence=r["why"] + "; no word match in docs/tools/data text"))
    return plan, refused

_WORDS: dict = {}

def text_words(root: Path) -> dict[str, list[str]]:
    """word -> non-.gd text files (docs, tools, data, shaders) naming it: any such mention blocks --apply."""
    key = str(root.resolve())
    if key not in _WORDS:
        import unused_graph
        idx: dict[str, set[str]] = defaultdict(set)
        for p in unused_graph.listing(root):
            if p.suffix in (".gd", ".png", ".jpg", ".webp", ".glb", ".ogg", ".wav", ".mp3", ".ttf", ".otf", ".import", ".uid", ".res", ".scn", ".exr", ".zip", ".wasm", ".pck"):
                continue
            try:
                if p.stat().st_size > 4_000_000:
                    continue
                text = p.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            rel = p.relative_to(root).as_posix()
            # The unused linter's own sources mention symbol names in docs and fixtures;
            # those are not live calls and must not hold --apply.
            if rel.startswith("tools/lib/lint/"):
                continue
            for w in set(IDENT.findall(text)):
                idx[w].add(rel)
        _WORDS[key] = {k: sorted(v) for k, v in idx.items()}
    return _WORDS[key]

def apply_plan(root: Path, plan: list[dict]) -> list[str]:
    """Delete exactly the planned items. Funcs/decls: their span (+ ## docs); vars: the one line; files: .gd + .uid."""
    done = []
    by_file = defaultdict(list)
    for r in plan:
        if r["kind"] == "orphan_file":
            path = root / r["rel"]
            if path.is_file():
                path.unlink()
                path.with_name(path.name + ".uid").unlink(missing_ok=True)
                done.append(f"deleted_file\t{r['rel']}\t{r['evidence']}")
        else:
            by_file[r["rel"]].append(r)
    for rel, items in by_file.items():
        path = root / rel
        if not path.is_file():
            continue
        import unused_graph
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for r in sorted(items, key=lambda x: -x["line"]):
            idx = r["line"] - 1
            sc = unused_graph.Script(rel, "\n".join(lines) + "\n")  # masked lexer: spans step over multi-line strings
            head = sc.lines[idx].split("#", 1)[0] if 0 <= idx < len(lines) else ""
            if sc.inner_at(idx):
                done.append(f"skip\t{rel}:{r['line']}\t{r['name']}\tinside an inner class")
                continue
            fm, vm, dm = FUNC_RE.match(head), VAR_LINE.match(head), DECL_RE.match(head)
            name = (fm and fm.group(1)) or (vm and vm.group(1)) or (dm and dm.group(2)) or (ALIAS_RE.match(head) and ALIAS_RE.match(head).group(1))
            if name != r["name"]:
                done.append(f"skip\t{rel}:{r['line']}\t{r['name']}\tline no longer declares it")
                continue
            start = span_start(lines, idx)
            if fm:
                _ln, a, end = sc.funcs.get(name, (0, -1, -1))
                if a != idx:
                    done.append(f"skip\t{rel}:{r['line']}\t{name}\tspan mismatch")
                    continue
                while end > idx + 1 and not lines[end - 1].strip():
                    end -= 1
            else:
                if multiline_decl(sc.lines, idx):
                    done.append(f"skip\t{rel}:{r['line']}\t{name}\tmulti-line declaration")
                    continue
                end = idx + 1
            del lines[start:end]
            done.append(f"deleted_{r['kind']}\t{rel}:{r['line']}\t{r['name']}\t{r['evidence']}")
        path.write_text(collapse_blanks(lines), encoding="utf-8", newline=chr(10))
    return done


MEMBER_RE = re.compile(r"^\s*(?:static\s+)?(?:func|var|const|signal|enum|class)\s+(\w+)", re.M)
CLASS_RE = re.compile(r"^class_name[ \t]+(\w+)", re.M)
PRELOAD_ALIAS_RE = re.compile(
    r"""(?:const|var)[ \t]+([A-Za-z_]\w*)[ \t]*(?::[^=]*)?:?=[ \t]*[\w.]*\([ \t]*["']res://([^"']+\.gd)["']""",
    re.M,
)
EXTENDS_RES_RE = re.compile(r'^extends\s+"res://([^"]+\.gd)"', re.M)
APPLY_MAX_PASSES = 16

def _pascal_stem(rel: str) -> str:
    return "".join(p.title() for p in Path(rel).stem.replace("-", "_").split("_"))

def _gd_text(root: Path, rel: str) -> str:
    p = root / rel
    return p.read_text(encoding="utf-8", errors="replace") if p.is_file() else ""

def _members_of(root: Path, rel: str, seen: tuple[str, ...] = ()) -> set[str]:
    """Declared members of rel, including an extends "res://..." chain."""
    if not rel or rel in seen:
        return set()
    text = _gd_text(root, rel)
    out = set(MEMBER_RE.findall(text))
    m = EXTENDS_RES_RE.search(text)
    if m:
        out |= _members_of(root, m.group(1), seen + (rel,))
    return out

def _aliases_for(root: Path, rel: str) -> set[str]:
    """class_name, unique preload alias, and conventional PascalCase file stem for a script."""
    names = {_pascal_stem(rel)}
    text = _gd_text(root, rel)
    m = CLASS_RE.search(text)
    if m:
        names.add(m.group(1))
    targets: dict[str, set[str]] = {}
    for p in root.rglob("*.gd"):
        try:
            rel_p = p.relative_to(root).as_posix()
        except ValueError:
            continue
        if "node_modules" in rel_p or ".godot" in rel_p:
            continue
        for alias, path in PRELOAD_ALIAS_RE.findall(p.read_text(encoding="utf-8", errors="replace")):
            targets.setdefault(alias, set()).add(path)
    for alias, paths in targets.items():
        if paths == {rel}:
            names.add(alias)
    return names

def _all_defs(root: Path) -> set[str]:
    out: set[str] = set()
    for p in root.rglob("*.gd"):
        rel = p.as_posix()
        if any(part in rel for part in ("/node_modules/", "/.godot/", "/retired/")):
            continue
        out.update(MEMBER_RE.findall(p.read_text(encoding="utf-8", errors="replace")))
    return out

def _applied_items(applied: list[str]) -> list[tuple[str, str, str]]:
    """(kind, rel, name) parsed from apply_plan lines; files use the path as the name."""
    out = []
    for line in applied:
        parts = line.split("\t")
        if not parts or not parts[0].startswith("deleted_"):
            continue
        kind = parts[0][len("deleted_"):]
        if kind == "file":
            rel = parts[1] if len(parts) > 1 else ""
            out.append((kind, rel, Path(rel).name))
            continue
        rel = parts[1].split(":")[0] if len(parts) > 1 else ""
        name = parts[2] if len(parts) > 2 else ""
        if rel and name:
            out.append((kind, rel, name))
    return out

def report_stale_docs(root: Path, applied: list[str]) -> list[dict]:
    """Design/doc lines that still name a symbol --apply just removed, when the qualified
    Class.member is now gone from that script, or the bare name has no remaining GDScript def.

    Does not edit docs; the cleanup commit should update or drop those lines. A design mention of
    a name that still has another live def (e.g. `LiveMod.helper` after a facade deletion)
    is not stale.
    """
    items = _applied_items(applied)
    if not items:
        return []
    defs = _all_defs(root)
    docs: list[Path] = []
    for folder, glob in ((root / "design", "*.md"), (root, "*.md")):
        if folder.is_dir():
            docs.extend(sorted(folder.glob(glob)))
    # unique
    seen_p: set[Path] = set()
    uniq = []
    for p in docs:
        if p.resolve() in seen_p or "changelog" in p.parts:
            continue
        seen_p.add(p.resolve())
        uniq.append(p)
    stale: list[dict] = []
    ident_re = re.compile(r"`([A-Z]\w+)\.(\w+)(?:\([^`]*)?`")
    word_re = re.compile(r"\b([A-Za-z_]\w*)\b")
    # qualified: aliases of the deleted file no longer have the member
    qual_keys: dict[tuple[str, str], tuple[str, str]] = {}
    bare_dead: set[str] = set()
    for kind, rel, name in items:
        if name not in defs:
            bare_dead.add(name)
        if kind == "file" or not (root / rel).exists() and kind == "file":
            continue
        if not name:
            continue
        members = _members_of(root, rel)
        if name in members:
            continue
        for alias in _aliases_for(root, rel):
            qual_keys[(alias, name)] = (rel, name)
        # if the whole file was deleted, still flag Alias.name
        if not (root / rel).exists():
            for alias in {_pascal_stem(rel)}:
                qual_keys[(alias, name)] = (rel, name)
    for p in uniq:
        try:
            rel_doc = p.relative_to(root).as_posix()
        except ValueError:
            continue
        for no, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for m in ident_re.finditer(line):
                key = (m.group(1), m.group(2))
                if key in qual_keys:
                    rel, name = qual_keys[key]
                    stale.append(dict(rel=rel_doc, line=no, name=f"{m.group(1)}.{m.group(2)}",
                                      why=f"qualified member removed from {rel}"))
            if bare_dead:
                # skip if already recorded as qualified on this line
                already = {s["name"] for s in stale if s["rel"] == rel_doc and s["line"] == no}
                for w in set(word_re.findall(line)):
                    if w in bare_dead and w not in already and not any(a.endswith("." + w) for a in already):
                        stale.append(dict(rel=rel_doc, line=no, name=w,
                                          why="no remaining GDScript def"))
    # unique (rel, line, name)
    uniq_s = []
    seen = set()
    for s in stale:
        k = (s["rel"], s["line"], s["name"])
        if k in seen:
            continue
        seen.add(k)
        uniq_s.append(s)
    return uniq_s

def _count_blob(rows: dict, legacy: dict, plan: list, refused: list, applied: list) -> dict:
    counts = {k: len(rows.get(k, [])) for k in REPORT} | {k: len(legacy.get(k, [])) for k in LEGACY}
    counts |= {"apply_ready": len(plan), "apply_refused": len(refused), "applied": len(applied)}
    return counts

def write_summaries(root: Path, rows: dict, legacy: dict, plan: list, refused: list, applied: list, elapsed: float, passes: list | None = None, stale_docs: list | None = None, doc_fixes: list | None = None) -> tuple[Path, Path]:

    out = ["# lint.py unused: categories (conf: high = no resolvable or plain-string reference; medium = a plain string or",
           "# non-GDScript word could name it; low = only untyped/ambiguous references; info = live but debug-only)"]
    for kind in REPORT:
        for r in rows.get(kind, []):
            out.append(f"{kind}\t{r['conf']}\t{r['scope']}\t{r['rel']}:{r['line']}\t{r['name']}\t{r['why']}")
    for kind in LEGACY:
        for rel, lineno, name, nbytes in legacy.get(kind, []):
            out.append(f"{kind}\t-\t-\t{rel}:{lineno}\t{name}\t{nbytes}")
    for r in plan:
        out.append(f"apply_ready\t{r['kind']}\t{r['rel']}:{r['line']}\t{r['name']}\t{r['evidence']}")
    for r in refused:
        out.append(f"apply_refused\t{r['kind']}\t{r['rel']}:{r['line']}\t{r['name']}\t{r['refuse']}")
    out.extend(applied)
    for s in doc_fixes or []:
        out.append(f"doc_fixed\t{s['rel']}:{s['line']}\t{s['name']}\t{s['why']}")
    for s in stale_docs or []:
        out.append(f"stale_doc\t{s['rel']}:{s['line']}\t{s['name']}\t{s['why']}")
    for rec in passes or []:
        c = rec.get("counts", {})
        names = rec.get("apply_ready_names", [])[:12]
        extra = ("\t" + ",".join(names)) if rec.get("phase") != "fixed_point" and names else ""
        out.append(f"apply_pass\t{rec.get("n", 0)}\t{rec.get('phase', '')}\tapply_ready={rec.get('apply_ready', 0)}\tapplied={len(rec.get('deleted', []))}{extra}")
    counts = _count_blob(rows, legacy, plan, refused, applied)
    counts |= {"stale_docs": len(stale_docs or []), "doc_fixed": len(doc_fixes or []), "apply_passes": len(passes or [])}
    out += [f"{k}_count={v}" for k, v in counts.items()] + ["seconds=%.2f" % elapsed]
    txt = agent_log.write_summary("unused-funcs", root, "\n".join(out), "INFO", " ".join(f"{k}={v}" for k, v in counts.items() if v))
    js = txt.parent / "unused-funcs.json"
    blob = dict(counts=counts, rows={k: rows.get(k, []) for k in REPORT},
                legacy={k: [dict(rel=a, line=b, name=c) for a, b, c, _d in legacy.get(k, [])] for k in LEGACY},
                apply_ready=plan, apply_refused=refused, applied=applied,
                passes=passes or [], stale_docs=stale_docs or [], doc_fixes=doc_fixes or [])
    js.write_text(json.dumps(blob, indent=1, default=list) + "\n", encoding="utf-8")
    return txt, js

def _sweep(root: Path):
    g, rows = analyse(root)
    unused, maybe, _defs, dynamic, decls = collect(root)
    decls = decls + dead_aliases(root, decls)
    plan, refused = plan_of(root, g, rows, decls)
    legacy = {"decl": decls, "maybe": maybe, "facade_auto": facade_auto(root), "dynamic": dynamic}
    return g, rows, unused, maybe, dynamic, decls, plan, refused, legacy

def run(root: Path, apply: bool, limit: int, quiet: bool = False, chunk: dict | None = None) -> int:
    started = time.perf_counter()
    applied: list[str] = []
    passes: list[dict] = []
    stale_docs: list[dict] = []
    doc_fixes: list[dict] = []
    if apply:
        for i in range(APPLY_MAX_PASSES):
            _g, rows, unused, maybe, dynamic, decls, plan, refused, legacy = _sweep(root)
            rec = dict(n=i, counts=_count_blob(rows, legacy, plan, refused, applied),
                       apply_ready=len(plan), apply_ready_names=[f"{r['rel']}:{r['name']}" for r in plan],
                       deleted=[])
            if not plan:
                rec["phase"] = "fixed_point"
                passes.append(rec)
                break
            rec["deleted"] = apply_plan(root, plan)
            rec["phase"] = "applied"
            applied += rec["deleted"]
            passes.append(rec)
        else:
            _g, rows, unused, maybe, dynamic, decls, plan, refused, legacy = _sweep(root)
            passes.append(dict(n=APPLY_MAX_PASSES, phase="capped",
                               counts=_count_blob(rows, legacy, plan, refused, applied),
                               apply_ready=len(plan),
                               apply_ready_names=[f"{r['rel']}:{r['name']}" for r in plan],
                               deleted=[]))
        import unused_docfix
        doc_fixes, stale_docs = unused_docfix.fix(root, _applied_items(applied), report_stale_docs(root, applied))
    else:
        _g, rows, unused, maybe, dynamic, decls, plan, refused, legacy = _sweep(root)
        passes.append(dict(n=0, phase="report", counts=_count_blob(rows, legacy, plan, refused, applied),
                           apply_ready=len(plan), apply_ready_names=[f"{r['rel']}:{r['name']}" for r in plan],
                           deleted=[]))
    txt, js = write_summaries(root, rows, legacy, plan, refused, applied, time.perf_counter() - started,
                              passes=passes, stale_docs=stale_docs, doc_fixes=doc_fixes)
    if chunk is not None and not quiet:
        import unused_chunk
        return unused_chunk.cli(root, _g, js, chunk, limit, txt)
    shown = list(applied) + [f"doc_fixed\t{d['rel']}:{d['line']}\t{d['name']}" for d in doc_fixes]
    for kind in ("orphan_file", "unused", "shadowed", "dead_chain", "arity_mismatch", "unused_var", "init_only_var"):
        for r in rows.get(kind, []):
            if r["conf"] in ("high", "medium") or kind in ("init_only_var", "arity_mismatch"):
                shown.append(f"{kind}\t{r['conf']}\t{r['rel']}:{r['line']}\t{r['name']}")
    if quiet:
        return 0
    for line in shown[:limit]:
        print(line[:200])
    if len(shown) > limit:
        print(f"... {len(shown) - limit} more rows (summary has every category; --limit N prints more)")
    print(f"json: {agent_log.rel(root, js)}")
    counts = {k: len(rows.get(k, [])) for k in REPORT}
    return agent_log.emit_result("PASS", summary=agent_log.rel(root, txt), **counts, decl=len(decls),
                                 facade_auto=len(legacy["facade_auto"]), apply_ready=len(plan), refused=len(refused),
                                 applied=len(applied), stale_docs=len(stale_docs), doc_fixed=len(doc_fixes), apply_passes=len(passes))


def main() -> int:
    parser = agent_log.std_parser(
        "Dead-code sweep over live GDScript. Roots: project.godot (main scene, autoloads), scenes, tool/flow `res://` and "
        "`script:` targets, engine hooks (_ready, _initialize, ...), scene `method=`, shot-flow methods. Edges resolve per file: "
        "preload/load aliases (const, var, helper `_gd(\"res://..\")`, `load(..)._fn()` returns, `var U = _fn()` locals), class_name, autoloads, extends, "
        "Dbg.script names, typed vars, host calls (weak when untyped), connect/Callable/call strings, literal-path load(..).call(\"fn\") and assembled name prefixes. "
        "Categories: orphan_file, unused, shadowed (name used, every use resolves elsewhere), dead_chain (only called from dead code; "
        "cycles named), unused_var, write_only_var, init_only_var (built in its initializer, never consumed), arity_mismatch, "
        "debug_only (shipped code reached only from debug/tools), ambiguous (only untyped/dynamic refs: never removed); "
        "legacy decl/maybe/dynamic and facade_auto (report only). Report mode (default) writes nothing but the summary + "
        "_logs/unused-funcs/unused-funcs.json and lists apply_ready (verified) and apply_refused rows. --apply DELETES only "
        "apply_ready rows (high confidence, no string/hook/override/dynamic-pattern/held/side-effect doubt; dead chains only "
        "when every caller is also removed); tools/data/unused_hold.json pins items.", writes=True)
    parser.add_argument("--limit", type=int, default=24, help="Max rows on stdout (default 24; the summary has all).")
    parser.add_argument("--apply", action="store_true", help="DELETE verified (apply_ready) items only; ambiguous stay warnings.")
    parser.add_argument("--selftest", action="store_true", help="Run the fixture cases in a throwaway root.")
    import unused_chunk
    unused_chunk.add_args(parser.add_argument_group("chunk view (unused_chunk.py)"), view=True)
    ns = parser.parse_args()
    if ns.selftest:
        import unused_selftest
        import unused_selftest_chunk
        return agent_log.selftest_result(unused_selftest.run() + unused_selftest_chunk.run())
    root = agent_log.resolve_root(ns)
    if ns.apply and ns.dry_run:
        print("dry-run: --apply skipped; apply_ready rows are the plan")
        ns.apply = False
    if (ns.baseline or ns.save_baseline or ns.plan_md or ns.plan_out) and not ns.paths:
        parser.error("--baseline/--save-baseline/--plan-md/--plan-out need --paths")
    if ns.plan_out and not ns.chunk:
        parser.error("--plan-out needs --chunk N")
    chunk = None
    if ns.paths or ns.why:
        chunk = dict(paths=agent_log.split_list(ns.paths), why=ns.why, baseline=ns.baseline, save_baseline=ns.save_baseline,
                     plan_md=ns.plan_md, plan_out=ns.plan_out, chunk=ns.chunk, json=ns.json)
    return run(root, ns.apply, ns.limit, chunk=chunk)

if __name__ == "__main__":
    sys.exit(main())
