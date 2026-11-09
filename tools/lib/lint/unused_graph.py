"""Reference graph behind `lint.py unused`: which GDScript funcs, vars and files are reachable from real roots.

Roots: project.godot (autoloads, main scene), scenes a root reaches, paths named by tools/CI/flow data (CLI and test
roots), lifecycle hooks of every reached script, scene signal callbacks and flow `"method"` ops.
Edges are file/module aware: `Alias.fn` (const/var preload or load, class_name, autoload, `Dbg.script("x")` locals),
bare and `self.` calls through the extends chain, `super.`, overrides, `"res://dir/" + name` loaders whose stems are
named as strings, and string callbacks (`call("fn")`, `"prefix_" + x`). A call on a receiver we cannot type
(`host.fn`, `x.fn`, `).fn`) first resolves to same-named defs in related files (loaders, loaded files, siblings,
the extends chain: the facade convention) and otherwise reaches every same-named def as an UNRESOLVED edge.
Anything reached only through unresolved or ambiguous dynamic edges is reported `ambiguous`, never dead.
Nothing here deletes; `verified()` picks the rows `--apply` may remove and says why each other row is refused."""
from __future__ import annotations

import json
import re
import subprocess
from collections import defaultdict
from pathlib import Path

VIRTUAL = frozenset({
    "_init", "_static_init", "_enter_tree", "_exit_tree", "_ready", "_process", "_physics_process", "_input",
    "_shortcut_input", "_unhandled_input", "_unhandled_key_input", "_gui_input", "_draw", "_notification",
    "_get_configuration_warnings", "_get_property_list", "_validate_property", "_set", "_get",
    "_property_can_revert", "_property_get_revert", "_to_string", "_iter_init", "_iter_next", "_iter_get",
    "_can_drop_data", "_drop_data", "_get_drag_data", "_make_custom_tooltip", "_get_minimum_size", "_has_point",
    "_clips_input", "_mouse_enter", "_mouse_exit", "_import", "_export_begin", "_export_end", "_export_file",
    "_initialize", "_finalize", "_integrate_forces", "_input_event", "_mouse_shape_enter", "_mouse_shape_exit",
    "_get_tooltip", "_structured_text_parser", "_run", "_handles", "_edit", "_make_visible",
    "_get_plugin_name", "_has_main_screen", "_get_import_options", "_get_recognized_extensions",
})
FUNC_RE = re.compile(r"^(?:static[ \t]+)?func[ \t]+([A-Za-z_]\w*)[ \t]*\(")
VAR_RE = re.compile(r"^(?:@\w+(?:\([^)]*\))?[ \t]+)*(?:static[ \t]+)?var[ \t]+([A-Za-z_]\w*)")
ALIAS_RE = re.compile(r"(?:const|var)[ \t]+([A-Za-z_]\w*)[ \t]*(?::[^=]*)?:?=[ \t]*[\w.]*\([ \t]*[\"']res://([^\"']+\.gd)[\"'][ \t]*\)(?=[ \t]*(?:as[ \t]+\w+[ \t]*)?(?:$|[;#]))")
CALL_RES_RE = re.compile(r"\([ \t]*[\"']res://([^\"']+\.gd)[\"'][ \t]*\)[ \t]*(?:as[ \t]+\w+[ \t]*)?$")
DBG_ALIAS_RE = re.compile(r"(?:const|var)[ \t]+([A-Za-z_]\w*)[ \t]*(?::[^=]*)?:?=[ \t]*(?:Dbg\.)?(?:script|make)\([ \t]*\"([\w/]+)\"[ \t]*\)(?=[ \t]*(?:as[ \t]+\w+[ \t]*)?(?:$|[;#]))")
DBG_CALL_RE = re.compile(r"\b(?:Dbg\.)?(?:script|make)\([ \t]*\"([\w/]+)\"")
CLASS_RE = re.compile(r"^class_name[ \t]+([A-Za-z_]\w*)")
EXTENDS_RE = re.compile(r"^extends[ \t]+(?:\"res://([^\"]+\.gd)\"|([A-Za-z_]\w*))")
RES_RE = re.compile(r"res://([\w./-]+\.(?:gd|tscn|tres))")
UID_RE = re.compile(r"uid://[a-z0-9]+")
PATH_RE = re.compile(r"(?<![\w/])((?:scripts|tools/data|scenes)/[\w./-]+\.(?:gd|tscn|tres))")
DIR_PREFIX_RE = re.compile(r"[\"']res://([\w/]+/)[\"']")
TYPE_RE = re.compile(r"(?:\bvar[ \t]+)?([A-Za-z_]\w*)[ \t]*(?::[ \t]*([A-Z]\w*)\b[^=]*=?|:?=[ \t]*([A-Z]\w*)\.new\()")
RETCALL_RE = re.compile(r"(?:const|var)[ \t]+([A-Za-z_]\w*)[ \t]*(?::[^=]*)?:?=[ \t]*(?:pre)?load\([ \t]*[\"']res://([^\"']+\.gd)[\"'][ \t]*\)\.([A-Za-z_]\w*)\([ \t]*\)(?=[ \t]*(?:as[ \t]+\w+[ \t]*)?(?:$|[;#]))")
LOCAL_RE = re.compile(r"\b(?:var|const|for)[ \t]+([A-Za-z_]\w*)")
RET_LOAD_RE = re.compile(r"return[ \t]+(?:pre)?load\([ \t]*[\"']res://([^\"']+\.gd)[\"'][ \t]*\)(?:[ \t]+as[ \t]+\w+)?$")
METHOD_POS_RE = re.compile(r"\b(?:call|call_deferred|callv|has_method|connect|disconnect|is_connected|rpc|rpc_id|emit_signal|tween_method)[ \t]*\([ \t]*[\"'](\w+)[\"']|\bCallable[ \t]*\([^,()]+,[ \t]*[\"'](\w+)[\"']|[\"']method[\"'][ \t]*:[ \t]*[\"'](\w+)[\"']")
CHAIN_RE = re.compile(r"[ \t]*(?:static[ \t]+)?var[ \t]+([A-Za-z_]\w*)[ \t]*(?::[ \t]*\w+[ \t]*)?:?=[ \t]*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+)[ \t]*$")
HOSTS = frozenset({"host", "_host", "h", "fac", "_fac", "p", "pt", "ui", "_ui", "owner_host"})
TOKEN_RE = re.compile(r"[A-Za-z_]\w*")
USE_RE = re.compile(r"(?:([A-Za-z_]\w*)[ \t]*\.[ \t]*|(\.)[ \t]*)?\b([A-Za-z_]\w*)\b")
IDENT = re.compile(r"[A-Za-z_]\w*")
STR_RE = re.compile(r"\"([^\"\\\n]*(?:\\.[^\"\\\n]*)*)\"|'([^'\\\n]*(?:\\.[^'\\\n]*)*)'")
CALLISH = re.compile(r"\b(?:call|call_deferred|callv|Callable|has_method|connect|emit_signal|method|bind|callback|rpc)\b")
PREFIX_RE = re.compile(r"[\"']([A-Za-z_]\w*_)[\"'][ \t]*\+")
SUFFIX_RE = re.compile(r"\+[ \t]*[\"'](_\w+)[\"']")
FMT_RE = re.compile(r"[\"'](\w*)%s(\w*)[\"']")
FLOW_RE = re.compile(r"\"target\"\s*:\s*\"script:([\w/]+)\"[^{}]*?\"method\"\s*:\s*\"(\w+)\"|\"method\"\s*:\s*\"(\w+)\"[^{}]*?\"target\"\s*:\s*\"script:([\w/]+)\"")
METHOD_RE = re.compile(r"(?:\bmethod\s*=\s*|\"method\"\s*:\s*)\"(\w+)\"")
WRITE_AFTER = re.compile(r"[ \t]*(?:[-+*/%|&^]|<<|>>)?=(?!=)")
SKIP_PARTS = frozenset({"node_modules", "__pycache__", ".godot", ".git", "_logs", ".archive_worktrees", ".archive_export_cache", "retired"})
STRONG = ("call", "self", "alias", "super", "override", "host", "hook", "scene", "flow", "dynamic", "file")
WEAK = ("unresolved", "dynamic_ambiguous", "arity_mismatch")

def code_of(raw: str) -> str:
    """The line with comments cut and string literal contents blanked (quotes and positions kept)."""
    out, i, n = [], 0, len(raw)
    while i < n:
        ch = raw[i]
        if ch == "#":
            break
        if ch in "\"'":
            j = i + 1
            while j < n and raw[j] != ch:
                j += 2 if raw[j] == "\\" else 1
            width = min(j, n - 1) + 1 - i
            out.append(ch + " " * (width - 2) + ch if width >= 2 else " " * width)
            i = j + 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)

def strings_of(raw: str) -> list[str]:
    head = raw
    cut = code_of(raw)
    if "#" in raw and len(cut) < len(raw):
        head = raw[:len(cut)]
    return [a or b for a, b in STR_RE.findall(head)]

def _split_top(text: str) -> list[str]:
    parts, depth, cur = [], 0, ""
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return [x for x in parts if x.strip()]

def _arity(line: str) -> tuple[int, int]:
    """(required, max) params of a one-line def; (0, 99) when it cannot tell."""
    code = code_of(line)
    a = code.find("(")
    depth, b = 0, -1
    for j in range(a, len(code)):
        if code[j] == "(":
            depth += 1
        elif code[j] == ")":
            depth -= 1
            if depth == 0:
                b = j
                break
    if a < 0 or b < 0:
        return (0, 99)
    params = _split_top(code[a + 1:b])
    if any(x.strip().startswith("...") for x in params):
        return (len([x for x in params if "=" not in x and not x.strip().startswith("...")]), 99)
    return (len([x for x in params if "=" not in x]), len(params))

def _call_args(code: str, at: int) -> int:
    """Argument count of the call starting at code[at] ('(' expected), -1 when it is not a call or spans lines."""
    j = at
    while j < len(code) and code[j] in " \t":
        j += 1
    if j >= len(code) or code[j] != "(":
        return -1
    depth = 0
    for k in range(j, len(code)):
        if code[k] in "([{":
            depth += 1
        elif code[k] in ")]}":
            depth -= 1
            if depth == 0:
                return len(_split_top(code[j + 1:k]))
    return -2

def listing(root: Path) -> list[Path]:
    """Every tracked or untracked-but-not-ignored file (git), else a walk that skips vendor/cache folders.
    Directories named like files (node_modules/sql.js) are never returned."""
    try:
        out = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "-z"], cwd=root, capture_output=True, check=True)
        names = [n for n in out.stdout.decode("utf-8", "replace").split("\0") if n]
        if names:
            return sorted(p for n in names if not SKIP_PARTS.intersection(n.split("/")) for p in [root / n] if p.is_file())
    except (OSError, subprocess.CalledProcessError):
        pass
    return sorted(p for p in root.rglob("*") if p.is_file() and not SKIP_PARTS.intersection(p.relative_to(root).parts))

class Script:
    def __init__(self, rel: str, text: str):
        self.rel = rel
        self.lines = text.splitlines()
        self.size = len(text.encode("utf-8"))
        self.funcs: dict[str, tuple[int, int, int]] = {}  # name -> (lineno, start idx, end idx)
        self.vars: dict[str, int] = {}
        self.exported: set[str] = set()
        self.parent = ""
        self.klass = ""
        self.aliases: dict[str, str] = {}
        self.dbg_aliases: dict[str, str] = {}
        self.loads: set[str] = set()
        self.dbg_names: set[str] = set()
        self.dir_prefixes: set[str] = set()
        self.uids: set[str] = set()
        self.var_type: dict[str, str] = {}
        self.var_chain: dict[str, str] = {}
        self.alias_targets: set[str] = set()
        self.dbg_targets: set[str] = set()
        self.fn_scope: dict[str, dict[str, dict[str, str]]] = {}
        pend = []
        starts = []
        for i, raw in enumerate(self.lines):
            head = raw.split("#", 1)[0]
            m = FUNC_RE.match(head)
            if m:
                starts.append((i, m.group(1)))
            m = VAR_RE.match(head)
            if m and not raw[:1].isspace():
                self.vars.setdefault(m.group(1), i + 1)
                if "@export" in head:
                    self.exported.add(m.group(1))
            m = EXTENDS_RE.match(head)
            if m:
                self.parent = m.group(1) or m.group(2)
            m = CLASS_RE.match(head)
            if m:
                self.klass = m.group(1)
            inner = raw[:1].isspace()
            for m in ALIAS_RE.finditer(head):
                self.alias_targets.add(m.group(2))
                if inner:
                    pend.append((i, "alias", m.group(1), m.group(2)))
                else:
                    self.aliases[m.group(1)] = m.group(2)
            for m in RETCALL_RE.finditer(head):
                self.alias_targets.add(m.group(2))
                pend.append((i, "ret", m.group(1), m.group(2) + "::" + m.group(3)))
            m = CHAIN_RE.match(head)
            if m:
                if inner:
                    pend.append((i, "chain", m.group(1), m.group(2)))
                else:
                    self.var_chain.setdefault(m.group(1), m.group(2))
            for m in TYPE_RE.finditer(head):
                if inner:
                    pend.append((i, "type", m.group(1), m.group(2) or m.group(3)))
                else:
                    self.var_type.setdefault(m.group(1), m.group(2) or m.group(3))
            for m in DBG_ALIAS_RE.finditer(head):
                self.dbg_targets.add(m.group(2))
                if inner:
                    pend.append((i, "dbg", m.group(1), m.group(2)))
                else:
                    self.dbg_aliases[m.group(1)] = m.group(2)
            for m in DBG_CALL_RE.finditer(head):
                self.dbg_names.add(m.group(1))
            for m in RES_RE.finditer(raw):
                self.loads.add(m.group(1))
            for m in DIR_PREFIX_RE.finditer(raw):
                self.dir_prefixes.add(m.group(1))
            self.uids.update(UID_RE.findall(raw))
        self.arity: dict[str, tuple[int, int]] = {}
        for i, name in starts:
            self.arity.setdefault(name, _arity(self.lines[i]))
        for k, (i, name) in enumerate(starts):
            end = i + 1
            while end < len(self.lines):
                ln = self.lines[end]
                if ln and not ln[0].isspace() and not ln.startswith("#"):
                    break
                end += 1
            self.funcs.setdefault(name, (i + 1, i, end))
        for i, kind, name, val in pend:
            sc = self.fn_scope.setdefault(self.owner_of(i), {"alias": {}, "chain": {}, "type": {}, "dbg": {}, "ret": {}})
            sc[kind].setdefault(name, val)
        self.locals: dict[str, set[str]] = {}
        self.func_ret: dict[str, str] = {}
        for name, (_ln, a, e) in self.funcs.items():
            head = code_of(self.lines[a])
            pa, pb = head.find("("), head.rfind(")")
            names = {x.split(":")[0].split("=")[0].strip().lstrip(".") for x in _split_top(head[pa + 1:pb])} if 0 <= pa < pb else set()
            body = [code_of(x) for x in self.lines[a + 1:e]]
            for ln in body:
                names.update(LOCAL_RE.findall(ln))
            self.locals[name] = {n for n in names if n}
            real = [x.strip() for x in body if x.strip()]
            if len(real) == 1:
                m = RET_LOAD_RE.match(self.lines[a + 1 + body.index(next(x for x in body if x.strip()))].strip())
                if m:
                    self.func_ret[name] = m.group(1)

    def owner_of(self, idx: int) -> str:
        for name, (_ln, s, e) in self.funcs.items():
            if s <= idx < e:
                return name
        return "<file>"

class Graph:
    def __init__(self, root: Path, files: list[Path] | None = None):
        self.root = root
        self.scripts: dict[str, Script] = {}
        self.other: dict[str, str] = {}
        for p in files if files is not None else listing(root):
            rel = p.relative_to(root).as_posix()
            if rel.endswith(".gd"):
                if rel.startswith(("scripts/", "tools/data/", "addons/")) or "/" not in rel:
                    self.scripts[rel] = Script(rel, p.read_text(encoding="utf-8", errors="replace"))
            elif p.suffix in (".tscn", ".tres", ".godot", ".py", ".json", ".js", ".html", ".yml", ".yaml", ".cfg", ".uid", ".sh"):
                self.other[rel] = p.read_text(encoding="utf-8", errors="replace")
        self.klass = {s.klass: r for r, s in self.scripts.items() if s.klass}
        self.autoload = {}
        for m in re.finditer(r"^(\w+)=\"\*?res://([^\"]+\.gd)\"", self.other.get("project.godot", ""), re.M):
            self.autoload[m.group(1)] = m.group(2)
        self.uid_file = {}
        for rel, text in self.other.items():
            if rel.endswith(".gd.uid"):
                self.uid_file[text.strip()] = rel[:-4]
        self._near: dict[str, set[str]] = {}
        self.defs = defaultdict(list)
        for rel, s in self.scripts.items():
            for name in s.funcs:
                self.defs[name].append(rel)
        self._build_files()
        self._build_edges()

    # ---- files -------------------------------------------------------------------------------------------
    def _parent(self, rel: str) -> str:
        p = self.scripts[rel].parent if rel in self.scripts else ""
        return p if p.endswith(".gd") and p in self.scripts else self.klass.get(p, "")

    def chain(self, rel: str) -> list[str]:
        out = []
        while rel and rel not in out:
            out.append(rel)
            rel = self._parent(rel)
        return out

    def _build_files(self) -> None:
        self.file_edges: dict[str, set[str]] = defaultdict(set)
        self.loaders: dict[str, set[str]] = defaultdict(set)
        stems = defaultdict(set)
        for rel, s in self.scripts.items():
            for lit in (x for raw in s.lines for x in strings_of(raw)):
                stems[lit].add(rel)
        self.dyn_loaded: dict[str, str] = {}
        for rel, s in self.scripts.items():
            tgt = set(s.loads) | s.alias_targets | {self.uid_file[u] for u in s.uids if u in self.uid_file}
            p = self._parent(rel)
            if p:
                tgt.add(p)
            words = set(IDENT.findall("\n".join(code_of(x) for x in s.lines)))
            tgt |= {self.klass[w] for w in words if w in self.klass}
            tgt |= {self.autoload[w] for w in words if w in self.autoload}
            for name in s.dbg_names | s.dbg_targets:
                cand = f"scripts/debug/{name}.gd"
                if cand in self.scripts:
                    tgt.add(cand)
            for prefix in s.dir_prefixes:
                for other in self.scripts:
                    if other.startswith(prefix) and other.endswith(".gd"):
                        stem = other[len(prefix):-3]
                        if stem in stems or other in tgt:
                            tgt.add(other)
                            self.dyn_loaded.setdefault(other, rel)
            tgt.discard(rel)
            self.file_edges[rel] = tgt
            for t in tgt:
                self.loaders[t].add(rel)
        for rel, text in self.other.items():
            if rel.endswith((".tscn", ".tres")):
                tgt = set(RES_RE.findall(text)) | {self.uid_file[u] for u in UID_RE.findall(text) if u in self.uid_file}
                self.file_edges[rel] = tgt
        game = set()
        proj = self.other.get("project.godot", "")
        game |= set(RES_RE.findall(proj))
        tools = set()
        for rel, text in self.other.items():
            if rel.endswith((".tscn", ".tres", ".uid")) or rel == "project.godot":
                continue
            found = set(RES_RE.findall(text))
            found |= {f"scripts/{m}.gd" for m in re.findall(r"script:([\w/]+)", text)}
            tools |= {f for f in found if f in self.scripts or f in self.other}
        self.roots_game, self.roots_tool = game, tools
        self.file_reach = self._walk_files(game | tools, set())
        self.file_ship = self._walk_files(game, {r for r in self.scripts if r.startswith("scripts/debug/")})
        self.file_game = self._walk_files(game, set())

    def _walk_files(self, start: set[str], block: set[str]) -> set[str]:
        seen, todo = set(), [s for s in start if s not in block]
        while todo:
            f = todo.pop()
            if f in seen:
                continue
            seen.add(f)
            todo.extend(t for t in self.file_edges.get(f, ()) if t not in seen and t not in block)
        return seen

    def related(self, rel: str) -> set[str]:
        if rel in self._near:
            return self._near[rel]
        near = set(self.chain(rel)) | self.file_edges.get(rel, set()) | self.loaders.get(rel, set())
        for up in list(self.loaders.get(rel, ())):
            near |= self.file_edges.get(up, set())
        for other, s in self.scripts.items():
            if rel in self.chain(other):
                near.add(other)
        self._near[rel] = near
        return near

    # ---- edges -------------------------------------------------------------------------------------------
    def find(self, rel: str, name: str) -> str:
        for r in self.chain(rel):
            if name in self.scripts[r].funcs or name in self.scripts[r].vars:
                return r
        return ""

    def _build_edges(self) -> None:
        """edges[(rel, fn)] = [(target_rel, name, kind, lineno)]; fn '<file>' is top-level code."""
        self.edges: dict[tuple[str, str], list] = defaultdict(list)
        self.patterns: list[tuple[str, str, str, str, int]] = []  # (src_rel, src_fn, 'prefix'|'suffix', text, lineno)
        self.weak_strings: dict[str, list[str]] = defaultdict(list)
        self.arity_miss: list = []
        self.var_uses: dict[tuple[str, str], list] = defaultdict(list)  # (rel, var) -> [(src rel, lineno, 'r'|'w')]
        all_names = set(self.defs)
        self.lit_all = {lit for s0 in self.scripts.values() for ln in s0.lines for lit in strings_of(ln) if IDENT.fullmatch(lit)}
        var_owners = defaultdict(set)
        for rel, s in self.scripts.items():
            for v in s.vars:
                var_owners[v].add(rel)
        for rel, s in self.scripts.items():
            near = None
            for idx, raw in enumerate(s.lines):
                src = (rel, s.owner_of(idx))
                head = raw.split("#", 1)[0]
                fdef = FUNC_RE.match(head)
                code = code_of(raw)
                callish = CALLISH.search(code) is not None
                mpos = {x for m in METHOD_POS_RE.finditer(raw) for x in m.groups() if x} if callish else set()
                for lit in strings_of(raw):
                    if IDENT.fullmatch(lit) and lit in var_owners and lit not in all_names:
                        self.weak_strings[lit].append(f"{rel}:{idx + 1}")
                    if IDENT.fullmatch(lit) and lit in all_names:
                        own = self.find(rel, lit)
                        if own and not callish:
                            # a literal naming a func of its own script (dispatch table, e.g. TABS [..., "_inv"])
                            self.edges[src].append((own, lit, "dynamic", idx + 1))
                        elif callish and (not mpos or lit in mpos):
                            own = self.find(rel, lit)
                            if own:
                                self.edges[src].append((own, lit, "dynamic", idx + 1))
                            else:
                                kind = "dynamic" if len(self.defs[lit]) == 1 else "dynamic_ambiguous"
                                self.edges[src].extend((t, lit, kind, idx + 1) for t in self.defs[lit])
                        else:
                            self.weak_strings[lit].append(f"{rel}:{idx + 1}")
                if callish:
                    for m in PREFIX_RE.finditer(raw):
                        self.patterns.append((rel, src[1], "prefix", m.group(1), idx + 1))
                    for m in SUFFIX_RE.finditer(raw):
                        self.patterns.append((rel, src[1], "suffix", m.group(1), idx + 1))
                    for m in FMT_RE.finditer(raw):
                        if m.group(1):
                            self.patterns.append((rel, src[1], "prefix", m.group(1), idx + 1))
                        if m.group(2):
                            self.patterns.append((rel, src[1], "suffix", m.group(2), idx + 1))
                vdef = VAR_RE.match(head) if not raw[:1].isspace() else None
                toks = [(m.start(), m.end(), m.group(0)) for m in TOKEN_RE.finditer(code)]
                for ti, (a, b, name) in enumerate(toks):
                    if code[a - 1:a].isdigit():
                        continue
                    if fdef and name == fdef.group(1) and a == code.find(fdef.group(1)):
                        continue
                    if vdef and name == vdef.group(1) and a == code.find(name):
                        continue
                    is_fn, is_var = name in all_names, name in var_owners
                    if not (is_fn or is_var):
                        continue
                    recv = self._receiver(code, toks, ti, raw)
                    targets, kind = [], ""
                    if recv is None and name in s.locals.get(src[1], ()):
                        continue
                    if recv is None or recv == ["self"]:
                        t = self.find(rel, name)
                        targets, kind = ([t], "call") if t else ([], "")
                    elif recv == ["super"]:
                        p = self._parent(rel)
                        t = self.find(p, name) if p else ""
                        targets, kind = ([t], "super") if t else ([], "")
                    else:
                        base = self.resolve(rel, recv, 0, src[1])
                        if base:
                            t = self.find(base, name)
                            targets, kind = ([t], "alias") if t else ([], "")
                        elif base == "":
                            nargs = _call_args(code, b)
                            if nargs == -1 and re.match(r"[ \t]*\.[ \t]*(?!(?:bind|unbind|call|call_deferred|callv|get_method|is_valid|get_object)\b)\w", code[b:]):
                                chained = True
                            else:
                                chained = False
                            if nargs == -1 and (chained or (not callish and (is_var or name in self.lit_all))):
                                if not is_var:
                                    continue
                                targets, kind = self._unresolved(rel, name, False, var_owners, recv)
                            else:
                                targets, kind = self._unresolved(rel, name, is_fn, var_owners, recv, nargs)
                    if not targets:
                        continue
                    after = code[b:]
                    for t in targets:
                        t, k2 = (t if isinstance(t, tuple) else (t, kind))
                        if name in self.scripts[t].funcs:
                            self.edges[src].append((t, name, k2, idx + 1))
                        else:
                            w = "w" if WRITE_AFTER.match(after) else "r"
                            self.var_uses[(t, name)].append((rel, idx + 1, w, k2, src[1], bool(re.search(r"\.new\(|instantiate\(|duplicate\(", after)) if w == "w" else False))
        for (src_rel, src_fn, how, text, ln) in self.patterns:
            hits = [(r, n) for n, rs in self.defs.items() for r in rs
                    if (n.startswith(text) if how == "prefix" else n.endswith(text))]
            kind = "dynamic" if len({n for _r, n in hits}) <= 8 else "dynamic_ambiguous"
            self.edges[(src_rel, src_fn)].extend((r, n, kind, ln) for r, n in hits)

    def _unresolved(self, rel: str, name: str, is_fn: bool, var_owners, recv: list[str], nargs: int = -1) -> tuple[list[str], str]:
        cands = list(self.defs[name]) if is_fn else []
        if nargs >= 0 and cands:
            fit = [c for c in cands if self.scripts[c].arity[name][0] <= nargs <= self.scripts[c].arity[name][1]]
            if not fit:
                # No def takes this many args: an engine/inner-class method of the same name (e.g. Vector3.dot).
                # Only private names are worth a warning; public ones get no edge.
                if name.startswith("_"):
                    self.arity_miss.append((rel, name, nargs, cands))
                    return cands, "arity_mismatch"
                return [], ""
            cands = fit
        cands += [r for r in var_owners.get(name, ()) if r not in cands]
        if not cands:
            return [], ""
        if len(recv) == 1 and recv[0] in HOSTS:
            near = self.related(rel)
            close = [c for c in cands if c in near]
            if close:
                return [(c, "host" if c in close else "unresolved") for c in cands], ""
        return cands, "unresolved"

    @staticmethod
    def _receiver(code: str, toks: list, ti: int, raw: str = ""):
        """None for a bare name; else the dotted receiver chain before it (['?'] when it ends in ) or ])."""
        a = toks[ti][0]
        j = a - 1
        while j >= 0 and code[j] in " \t":
            j -= 1
        if j < 0 or code[j] != ".":
            return None
        chain = []
        k = ti
        pos = j
        while True:
            q = pos - 1
            while q >= 0 and code[q] in " \t":
                q -= 1
            if q < 0 or not (code[q].isalnum() or code[q] == "_"):
                if q >= 0 and code[q] == ")":
                    m = CALL_RES_RE.search(raw[:q + 1])
                    if m:
                        return ["@" + m.group(1)] + chain
                    m = re.search(r"(?<![\w.])([A-Za-z_]\w*)[ \t]*\.[ \t]*new\([^()]*\)$", code[:q + 1])
                    if m:
                        return [m.group(1)] + chain
                    m = re.search(r"(?<![\w.])([A-Za-z_]\w*)\(\s*\)$", code[:q + 1])
                    if m:
                        return ["#" + m.group(1)] + chain
                return ["?"] + chain if q >= 0 and code[q] in ")]\"'" else (chain or ["?"])
            k -= 1
            while k >= 0 and toks[k][1] != q + 1:
                k -= 1
            if k < 0:
                return ["?"]
            chain.insert(0, toks[k][2])
            p = toks[k][0] - 1
            while p >= 0 and code[p] in " \t":
                p -= 1
            if p < 0 or code[p] != ".":
                return chain
            pos = p

    def resolve(self, rel: str, recv: list[str], depth: int = 0, fn: str = ""):
        """Script a receiver chain names: '' = unknown (untyped), None = known non-script (engine/global)."""
        if not recv or recv[0] == "?":
            return ""
        s = self.scripts[rel]
        head = recv[0]
        cur = None
        if head.startswith("@"):
            cur = head[1:]
        elif head.startswith("#"):
            own = self.find(rel, head[1:])
            cur = self.scripts[own].func_ret.get(head[1:], "") if own else ""
            if not cur:
                return ""
        elif head == "self":
            cur = rel
        elif fn and head in s.locals.get(fn, ()):
            sc = s.fn_scope.get(fn, {})
            if head in sc.get("alias", {}):
                cur = sc["alias"][head]
            elif head in sc.get("dbg", {}):
                cur = f"scripts/debug/{sc['dbg'][head]}.gd"
            elif head in sc.get("type", {}):
                t = sc["type"][head]
                cur = s.aliases.get(t) or self.klass.get(t) or self._typed(rel, t, depth) or ""
            elif head in sc.get("ret", {}):
                path, f = sc["ret"][head].split("::")
                own = self.find(path, f) if path in self.scripts else ""
                cur = self.scripts[own].func_ret.get(f, "") if own else ""
            elif head in sc.get("chain", {}) and depth < 3:
                cur = self.resolve(rel, sc["chain"][head].split("."), depth + 1, fn) or ""
            if not cur:
                return ""
        elif any(head in self.scripts[r].aliases for r in self.chain(rel)):
            cur = next(self.scripts[r].aliases[head] for r in self.chain(rel) if head in self.scripts[r].aliases)
        elif head in self.klass:
            cur = self.klass[head]
        elif head in self.autoload:
            cur = self.autoload[head]
        elif any(head in self.scripts[r].dbg_aliases for r in self.chain(rel)):
            cur = "scripts/debug/" + next(self.scripts[r].dbg_aliases[head] for r in self.chain(rel) if head in self.scripts[r].dbg_aliases) + ".gd"
        else:
            cur = self._typed(rel, head, depth)
            if not cur:
                if not hasattr(s, "locals_"):
                    s.locals_ = set(re.findall(r"\b(?:var|const|for)[ \t]+([A-Za-z_]\w*)", "\n".join(s.lines)))
                local = head in s.locals_
                return None if head[:1].isupper() and head not in self.defs and not local else ""
        for name in recv[1:]:
            if cur not in self.scripts:
                return ""
            nxt = ""
            for r in self.chain(cur):
                sc = self.scripts[r]
                if name in sc.aliases:
                    nxt = sc.aliases[name]
                    break
                t = self._typed(r, name, depth)
                if t:
                    nxt = t
                    break
            if not nxt:
                return ""
            cur = nxt
        return cur if cur in self.scripts else ""

    def _typed(self, rel: str, var: str, depth: int = 0) -> str:
        for r in self.chain(rel):
            sc = self.scripts[r]
            t = sc.var_type.get(var)
            if t:
                return sc.aliases.get(t) or self.klass.get(t) or ""
            c = sc.var_chain.get(var)
            if c and depth < 3:
                got = self.resolve(r, c.split("."), depth + 1)
                if got:
                    return got
        return ""

    def _overrides(self):
        for rel in self.scripts:
            ch = self.chain(rel)
            for up in ch[1:]:
                for name in self.scripts[rel].funcs:
                    if name in self.scripts[up].funcs:
                        yield (up, name, rel)

    # ---- reachability ------------------------------------------------------------------------------------
    def roots(self, files: set[str]) -> list[tuple[tuple[str, str], str]]:
        out = []
        for rel in files:
            if rel not in self.scripts:
                continue
            out.append(((rel, "<file>"), "file"))
            for name in self.scripts[rel].funcs:
                if name in VIRTUAL:
                    out.append(((rel, name), "hook"))
        for rel, text in self.other.items():
            if rel.endswith(".tscn"):
                for m in METHOD_RE.finditer(text):
                    for t in self.defs.get(m.group(1), []):
                        if t in files:
                            out.append(((t, m.group(1)), "scene"))
            elif not rel.endswith((".uid", ".godot")):
                for m in FLOW_RE.finditer(text):
                    path, meth = (m.group(1), m.group(2)) if m.group(1) else (m.group(4), m.group(3))
                    t = f"scripts/{path}.gd"
                    if t in self.scripts and t in files:
                        f = self.find(t, meth)
                        if f:
                            out.append(((f, meth), "flow"))
        return out

    def reach(self, files: set[str], kinds: tuple[str, ...]) -> dict[tuple[str, str], tuple]:
        over = defaultdict(list)
        for up, name, child in self._overrides():
            over[(up, name)].append(child)
        seen: dict[tuple[str, str], tuple] = {}
        todo = []
        for node, why in self.roots(files):
            if node not in seen:
                seen[node] = (why, "", 0)
                todo.append(node)
        while todo:
            node = todo.pop()
            nxt = [(t, n, k, ln) for t, n, k, ln in self.edges.get(node, ()) if k in kinds]
            nxt += [(c, node[1], "override", 0) for c in over.get(node, ())]
            for t, n, k, ln in nxt:
                if t not in files:
                    continue
                key = (t, n)
                if key not in seen:
                    seen[key] = (k, f"{node[0]}:{ln}" if ln else node[0], ln)
                    todo.append(key)
        return seen

    def analyse(self) -> dict:
        strong = self.reach(self.file_reach, STRONG)
        full = self.reach(self.file_reach, STRONG + WEAK)
        ship_files = self.file_ship
        ship = self.reach(ship_files, STRONG + WEAK)
        rows = defaultdict(list)
        refs_in = defaultdict(list)
        for src, outs in self.edges.items():
            for t, n, k, ln in outs:
                if (t, n) != src:
                    refs_in[(t, n)].append((src, k, ln))
        tokens = defaultdict(int)
        for rel, s in self.scripts.items():
            for raw in s.lines:
                for w in IDENT.findall(code_of(raw)):
                    tokens[w] += 1
        other_words = defaultdict(list)
        for rel, text in self.other.items():
            if rel.endswith(".uid") or rel == "tools/data/unused_hold.json":
                continue
            for w in set(IDENT.findall(text)):
                other_words[w].append(rel)
        seen_miss = set()
        for rel, name, nargs, cands in self.arity_miss:
            if (rel, name, nargs) in seen_miss:
                continue
            seen_miss.add((rel, name, nargs))
            ln = next((i + 1 for i, raw in enumerate(self.scripts[rel].lines) if re.search(r"\." + name + r"[ \t]*\(", code_of(raw))), 0)
            src_fn = self.scripts[rel].owner_of(ln - 1) if ln else "<file>"
            if (rel, src_fn) not in full and src_fn != "<file>":
                continue
            sig = ", ".join(f"{c}({self.scripts[c].arity[name][0]}..{self.scripts[c].arity[name][1]})" for c in cands[:3])
            rows["arity_mismatch"].append(dict(rel=rel, line=ln, name=name, bytes=self.scripts[rel].size, scope=self.scope(rel), conf="medium",
                                               why=f"untyped call .{name}() with {nargs} arg(s) matches no def's arity ({sig}); likely a broken call or a target the sweep cannot see"))
        orphan = sorted(r for r in self.scripts if r not in self.file_reach)
        for rel in orphan:
            s = self.scripts[rel]
            stem = rel.rsplit("/", 1)[-1][:-3]
            mention = [r for r, s2 in self.scripts.items() if r != rel and any(stem == x for raw in s2.lines for x in strings_of(raw))]
            mention += [r for r, t in self.other.items() if rel in t and not r.endswith(".uid")]
            conf = "medium" if mention else "high"
            why = "never loaded: no preload/load/res:// path, uid, class_name, extends or Dbg/dir loader reaches it from project.godot, scenes or tool roots"
            if mention:
                why += "; name appears in " + ", ".join(mention[:3])
            rows["orphan_file"].append(dict(rel=rel, line=1, name=rel.rsplit("/", 1)[-1], bytes=s.size, conf=conf,
                                             scope=self.scope(rel), why=why, funcs=sorted(s.funcs)))
        for rel, s in self.scripts.items():
            if rel not in self.file_reach:
                continue
            for name, (ln, _a, _b) in s.funcs.items():
                if name in VIRTUAL:
                    continue
                key = (rel, name)
                base = dict(rel=rel, line=ln, name=name, bytes=s.size, scope=self.scope(rel))
                if key in strong:
                    if key not in ship and rel in ship_files:
                        k, via, _ = strong[key]
                        rows["debug_only"].append(dict(base, conf="info", why=f"shipped script, reached only from debug/tool code (first via {via}, {k})"))
                    continue
                if key in full:
                    callers = [f"{a[0][0]}:{a[2]}" for a in refs_in[key] if a[0] in full and a[1] in WEAK]
                    rows["ambiguous"].append(dict(base, conf="low", why=f"reached only through untyped receivers or ambiguous strings: {', '.join(callers[:4]) or full[key][1]}"))
                    continue
                inn = refs_in[key]
                weak_s = self.weak_strings.get(name, [])
                elsewhere = other_words.get(name, [])
                extra = ""
                if weak_s:
                    extra += f"; plain string \"{name}\" at {', '.join(weak_s[:3])}"
                if elsewhere:
                    extra += f"; word in {', '.join(elsewhere[:3])}"
                conf = "medium" if (weak_s or elsewhere) else "high"
                selfrec = [e for e in self.edges.get(key, ()) if (e[0], e[1]) == key]
                if not inn:
                    own_tokens = tokens[name] - len(self.defs[name]) - len(selfrec)
                    if selfrec and own_tokens <= 0:
                        rows["unused"].append(dict(base, conf=conf, why="only calls itself (self-recursion); nothing else references it" + extra))
                    elif own_tokens <= 0:
                        rows["unused"].append(dict(base, conf=conf, why="no reference anywhere" + extra))
                    else:
                        other = [r for r in self.defs[name] if r != rel]
                        rows["shadowed"].append(dict(base, conf=conf, why=f"name used {own_tokens}x but every use resolves to another def ({', '.join(other[:3]) or 'a var/local'})" + extra))
                else:
                    srcs = sorted({f"{a[0][0]}:{a[2]}({a[0][1]})" for a in inn})
                    weak_in = any(a[1] in WEAK for a in inn)
                    rows["dead_chain"].append(dict(base, conf="medium" if weak_in else conf,
                                                   why="only called from unreachable code: " + ", ".join(srcs[:4]) + extra,
                                                   callers=[[a[0][0], a[0][1]] for a in inn]))
        self._cycles(rows["dead_chain"])
        for (rel, v), line in ((k, ln) for rel, s in self.scripts.items() for k, ln in (((rel, v), ln) for v, ln in s.vars.items())):
            if rel not in self.file_reach or v in self.scripts[rel].exported:
                continue
            uses = self.var_uses.get((rel, v), [])
            s = self.scripts[rel]
            base = dict(rel=rel, line=line, name=v, bytes=s.size, scope=self.scope(rel))
            strs = self.weak_strings.get(v, []) + other_words.get(v, [])
            if not uses:
                rows["unused_var"].append(dict(base, conf="medium" if strs else "high", why="declared, never read or written" + (f"; word also in {', '.join(strs[:3])}" if strs else "")))
            elif all(u[2] == "w" for u in uses):
                firsts = ", ".join(f"{u[0]}:{u[1]}" for u in uses[:3])
                note = f"; name also a string/word at {', '.join(strs[:2])} (reflective access possible)" if strs else ""
                rows["write_only_var"].append(dict(base, conf="low" if strs else "medium", why=f"assigned ({firsts}) but never read; the assignment and its initializer stay live (side effects){note}"))
            else:
                writers = {(u[0], u[4]) for u in uses if u[2] == "w"}
                if writers and any(u[5] for u in uses) and all((u[0], u[4]) in writers for u in uses):
                    init = ", ".join(sorted(f"{a}:{b}" for a, b in writers))
                    live = [w for w in writers if w in full]
                    rows["init_only_var"].append(dict(base, conf="low" if strs else "medium",
                        why=f"built and configured only inside its initializer ({init}){' which IS called (live)' if live else ''}; no other code reads it; the node/value is created but has no consumer, so this is not a zero-caller function"))
        for k in rows:
            rows[k].sort(key=lambda r: (r["rel"], r["line"]))
        self.full, self.strong = full, strong
        return rows

    def _cycles(self, chain_rows: list[dict]) -> None:
        dead = {(r["rel"], r["name"]) for r in chain_rows}
        adj = {n: {(t, m) for t, m, _k, _l in self.edges.get(n, ()) if (t, m) in dead and (t, m) != n} for n in dead}
        for r in chain_rows:
            start = (r["rel"], r["name"])
            seen, todo = set(), list(adj[start])
            while todo:
                n = todo.pop()
                if n == start:
                    r["why"] = "cycle among unreachable funcs; " + r["why"]
                    break
                if n in seen:
                    continue
                seen.add(n)
                todo.extend(adj.get(n, ()))

    def scope(self, rel: str) -> str:
        if rel.startswith("scripts/debug/"):
            return "debug"
        if rel in self.file_ship:
            return "ship"
        if rel in self.file_game:
            return "game"
        return "tool"

def load_hold(root: Path) -> dict[tuple[str, str], str]:
    p = root / "tools/data/unused_hold.json"
    if not p.is_file():
        return {}
    data = json.loads(p.read_text(encoding="utf-8"))
    return {(h["path"], h["name"]): h["why"] for h in data.get("hold", [])}

def verified(g: Graph, rows: dict, hold: dict) -> tuple[list[dict], list[dict]]:
    """(removable, refused). A row is removable only when it is high confidence, has no plain-string or
    non-GDScript mention, no override/inherited twin, no hook-like name, no dynamic name pattern match,
    is not held, and (dead_chain) every caller is itself removable. Files: high-confidence orphans only."""
    pats = [(how, text) for _r, _f, how, text, _l in g.patterns]
    weak_in = {t for outs in g.edges.values() for t, _n, k, _l in outs if k in WEAK}
    ok, refused = [], []
    cand = {}
    for kind in ("unused", "shadowed", "dead_chain", "orphan_file", "unused_var"):
        for r in rows.get(kind, []):
            reason = ""
            name, rel = r["name"], r["rel"]
            if (rel, name) in hold or (rel, "*") in hold:
                reason = "held: " + hold.get((rel, name), hold.get((rel, "*"), ""))
            elif r["conf"] != "high":
                reason = f"confidence {r['conf']}"
            elif kind == "orphan_file" and rel in weak_in:
                reason = "untyped/dynamic calls elsewhere may target its funcs"
            elif kind != "orphan_file" and (name.startswith(("_on_", "_js_")) or name in VIRTUAL):
                reason = "hook-like name"
            elif kind != "orphan_file" and any((n.startswith(t) if h == "prefix" else n.endswith(t)) for h, t in pats for n in [name]):
                reason = "matches a dynamic name pattern"
            elif kind not in ("orphan_file", "unused_var") and any(name in g.scripts[x].funcs for x in g.chain(rel)[1:] + [o for o in g.scripts if rel in g.chain(o)[1:]]):
                reason = "inherited/overridden twin"
            elif kind != "orphan_file" and rel in g.scripts and _annotated(g.scripts[rel], r["line"]):
                reason = "annotated declaration"
            if reason:
                refused.append(dict(r, kind=kind, refuse=reason))
            else:
                cand[(rel, name)] = dict(r, kind=kind)
    changed = True
    while changed:
        changed = False
        for key, r in list(cand.items()):
            if r["kind"] == "dead_chain" and any(tuple(c) not in cand for c in r.get("callers", [])):
                refused.append(dict(r, refuse="a caller is not itself verified-removable"))
                del cand[key]
                changed = True
    ok = list(cand.values())
    return ok, refused

def _annotated(s: Script, line: int) -> bool:
    i = line - 2
    while i >= 0 and s.lines[i].strip().startswith("##"):
        i -= 1
    return i >= 0 and s.lines[i].strip().startswith("@") and not s.lines[i].strip().startswith("@warning_ignore")
