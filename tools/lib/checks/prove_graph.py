"""Change set, reference graph and drift for `check.py prove` (check_prove.py).

Tree reads one revision (git objects) or the working tree. changes() lists what moved between base and head;
names_of() gives the names other files use for a file (path, res:// path, `entry.py sub`, module stem, class_name,
json file name); graph() finds every file that mentions a changed file; drift() diffs the old and new text of each
changed file for removed paths, subcommands, flags, functions, nodes, groups and data keys and reports where the
head tree still names them (DRIFT), plus REVIEW hints: a tool whose docstring changed while its dependents did not,
and new code comments that make a claim about a file this diff did not touch.
"""
from __future__ import annotations

import ast
import fnmatch
import functools
import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

SKILL_DIR = Path("/home/box/agent-data/workflows")
TEXT = (".md", ".py", ".gd", ".tscn", ".tres", ".json", ".yaml", ".yml", ".txt", ".sh", ".cfg", ".toml", ".godot", ".gdshader", ".shader", ".html")
SKIP = ("design/changelog/", "archives/", "_src/", "assets/", "scripts/data/changelog.json", "scripts/data/archive_catalog.json",
        "tools/data/dupes-fixture/", "tools/data/prove_rules.json", "tools/data/attack_keyframes_log.json")
KINDS = [  # (glob, kind) first match wins; the kind says what sort of reference an edge is
    ("design/routes.yaml", "routes"), ("BOT.md", "job-table"), ("AGENTS.md", "job-table"), ("design/tools*.md", "job-table"),
    ("design/tasks/*.md", "task"), ("skill:*", "skill"), (".github/*", "ci"), (".grok/hooks/*", "hook"), (".githooks/*", "hook"),
    ("tools/data/shot-flows/*", "shot-flow"), ("tools/data/shot-recipes.json", "shot-flow"), ("tools/data/*", "data"),
    ("tools/*.py", "tool"), ("scripts/*.gd", "script"), ("*.tscn", "scene"), ("*.tres", "resource"), ("*.md", "doc"), ("*", "other")]

def git(root: Path, *a: str) -> str:
    return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True).stdout

def kind_of(path: str) -> str:
    return next(k for g, k in KINDS if fnmatch.fnmatch(path, g))

def in_scope(p: str) -> bool:
    return p.endswith(TEXT) and not p.startswith(SKIP)

class Tree:
    """Files of one revision (rev) or of the working tree (rev None), plus the workflow skills when live."""
    def __init__(self, root: Path, rev: str | None):
        self.root, self.rev, self._text = root, rev, {}
        if rev:
            self.files = [p for p in git(root, "ls-tree", "-r", "--name-only", rev).splitlines() if p]
        else:
            listed = git(root, "ls-files", "--cached", "--others", "--exclude-standard").splitlines()
            self.files = [p for p in dict.fromkeys(listed) if p and (root / p).is_file()]
            self.files += [f"skill:{d.name}/SKILL.md" for d in sorted(SKILL_DIR.glob("*")) if (d / "SKILL.md").is_file()]
        self.set = set(self.files)

    def text(self, path: str) -> str | None:
        if path not in self._text:
            self._text[path] = self._read(path)
        return self._text[path]

    def _read(self, path: str) -> str | None:
        if path.startswith("skill:"):
            return (SKILL_DIR / path[6:]).read_text(encoding="utf-8", errors="replace")
        if path not in self.set:
            return None
        if self.rev:
            r = subprocess.run(["git", "show", f"{self.rev}:{path}"], cwd=self.root, capture_output=True)
            return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None
        return (self.root / path).read_text(encoding="utf-8-sig", errors="replace")

    def preload(self) -> None:
        """Read every in-scope file once (one cat-file process for a revision)."""
        want = [p for p in self.files if in_scope(p) or p.startswith("skill:")]
        if not self.rev:
            for p in want:
                self.text(p)
            return
        data = "".join(f"{self.rev}:{p}\n" for p in want).encode()
        out = subprocess.run(["git", "cat-file", "--batch"], cwd=self.root, input=data, capture_output=True).stdout
        i = 0
        for p in want:
            nl = out.index(b"\n", i)
            size = int(out[i:nl].split()[2])
            self._text[p] = out[nl + 1:nl + 1 + size].decode("utf-8", "replace")
            i = nl + 1 + size + 1

@dataclass
class Change:
    path: str
    status: str  # A M D R
    old: str = ""
    removed: list[str] = field(default_factory=list)
    added: list[str] = field(default_factory=list)
    added_at: list[int] = field(default_factory=list)  # new-file line number of each added line
    removed_at: list[int] = field(default_factory=list)  # old-file line number of each removed line

def changes(root: Path, base: str, head: str | None) -> list[Change]:
    rng = [base, head] if head else [base]
    out: dict[str, Change] = {}
    for line in git(root, "diff", "--name-status", "-M", *rng).splitlines():
        parts = line.split("\t")
        st = parts[0][0]
        c = Change(parts[-1], st, parts[1] if st == "R" else parts[-1])
        out[c.path] = c
    if not head:
        for p in git(root, "ls-files", "--others", "--exclude-standard").splitlines():
            out.setdefault(p, Change(p, "A", p))
    cur, minus, no, ono = None, "", 0, 0
    for d in git(root, "diff", "-U0", "-M", *rng).splitlines():
        if d.startswith("diff --git "):
            cur, minus = None, ""
        elif d.startswith("--- ") and cur is None:
            minus = d[6:] if d[4:6] == "a/" else ""
        elif d.startswith("+++ ") and cur is None:
            cur = out.get(d[6:]) if d[4:6] == "b/" else next((c for c in out.values() if c.old == minus and c.status == "D"), None)
        elif cur is None:
            continue
        elif d.startswith("@@"):
            m = re.match(r"@@ -(\d+)\S* \+(\d+)", d)
            ono, no = int(m.group(1)), int(m.group(2))
        elif d.startswith("-"):
            cur.removed.append(d[1:])
            cur.removed_at.append(ono)
            ono += 1
        elif d.startswith("+"):
            cur.added.append(d[1:])
            cur.added_at.append(no)
            no += 1
    for c in out.values():
        if c.status == "A" and not head and not c.added and (root / c.path).is_file():
            c.added = (root / c.path).read_text(errors="replace").splitlines()
            c.added_at = list(range(1, len(c.added) + 1))
    return sorted(out.values(), key=lambda c: c.path)

def entries(tree: Tree) -> dict[str, tuple[str, str | None]]:
    """module path (tools/lib/...py) -> (entry stem, subcommand or None), from the tree's entry COMMANDS tables."""
    out: dict[str, tuple[str, str | None]] = {}
    for p in tree.files:
        if not re.fullmatch(r"tools/[^/]+\.py", p):
            continue
        for e, sub, mod in _commands(tree.text(p) or ""):
            out[f"tools/lib/{mod}.py"] = (Path(p).stem, sub)
    return out

def _commands(src: str) -> list[tuple[str, str | None, str]]:
    try:
        body = ast.parse(src).body
    except SyntaxError:
        return []
    for node in body:
        if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name) and node.targets[0].id in ("COMMANDS", "MODULE"):
            val = ast.literal_eval(node.value)
            return [("", r[0], r[1]) for r in val] if node.targets[0].id == "COMMANDS" else [("", None, val)]
    return []

def subcommands(src: str | None) -> set[str]:
    return {s for _, s, _ in _commands(src or "") if s}

def names_of(path: str, tree: Tree, ents: dict, basenames: dict[str, int]) -> list[str]:
    """What other files call `path`: the path, res:// path, a unique long basename, `entry.py sub`, class_name."""
    names = [path]
    base = path.rsplit("/", 1)[-1]
    data = path.startswith(("tools/data/", "scripts/data/"))
    if basenames.get(base, 0) <= 1 and (len(base) >= 9 or data) and base not in ("README.md", "SKILL.md", "__init__.py"):
        names.append(base)
    if path in ents:
        e, sub = ents[path]
        names.append(f"{e}.py {sub}" if sub else f"{e}.py")
    if re.fullmatch(r"tools/[^/]+\.py", path):
        names.append(base)
    if path.endswith(".gd"):
        m = re.search(r"^class_name\s+(\w+)", tree.text(path) or "", re.M)
        if m:
            names.append(m.group(1))
    if path.startswith("tools/lib/") and path.endswith(".py") and path not in ents:
        names.append(f"import {Path(path).stem}")
        names.append(f"from {Path(path).stem} import")
    return list(dict.fromkeys(names))

TOK = re.compile(r"[\w.-]+")

def _key(name: str) -> str:
    toks = [t for t in TOK.findall(name) if t not in ("import", "from")]
    return max(toks, key=len).strip(".-") if toks else name

def scan(tree: Tree, names: dict[str, str]) -> dict[str, list[tuple[str, str, int, str]]]:
    """name -> [(file, kind, line no, line)] for every in-scope file of the tree that mentions it."""
    hits: dict[str, list] = {n: [] for n in names}
    by_key: dict[str, list[str]] = {}
    for n in names:
        by_key.setdefault(_key(n), []).append(n)
    rx: dict[str, re.Pattern] = {}
    for f in tree.files:
        if not (in_scope(f) or f.startswith("skill:")):
            continue
        src = tree.text(f) or ""
        cand = [n for k in by_key.keys() & {t.strip(".-") for t in TOK.findall(src)} for n in by_key[k] if n in src]
        if not cand:
            continue
        lines = src.splitlines()
        for n in cand:
            r = rx.setdefault(n, re.compile(rf"(?<![\w.-])(?<![\w.-]/){re.escape(n)}(?![\w-])"))
            for no, line in enumerate(lines, 1):
                if n in line and r.search(line):
                    hits[n].append((f, kind_of(f), no, line.strip()))
    return hits

# ---- drift: what the diff removed or changed, and who still names it -------------------------------------------
PY_DEF = re.compile(r"^\s*def\s+(\w+)\s*\(([^)]*)", re.M)
GD_DEF = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)\s*\(([^)]*)", re.M)
FLAG = re.compile(r"add_argument\(\s*[\"'](--[\w-]+)")
GD_MEMBER = re.compile(r"^(?:static\s+)?(?:const|var|signal)\s+([A-Za-z]\w*)", re.M)  # top-level only
NODE = re.compile(r"\[node name=\"(\w+)\"|\.name\s*=\s*\"(\w+)\"|add_to_group\(\s*\"(\w+)\"|^\s*(?:var|const)\s+\w+[^=\n]*=\s*\"(\w+)\"\s*#\s*node", re.M)
LIVE_KINDS = ("routes", "job-table", "task", "skill", "ci", "hook", "shot-flow", "data", "tool", "script", "scene", "resource", "doc", "other")

@dataclass
class Gone:
    what: str     # path | command | flag | def | node | key | sig
    symbol: str   # what to look for
    owner: str    # the changed file it came from
    ctx: list[str] = field(default_factory=list)  # flag: a line must also name one of these (the tool)

def _defs(rx: re.Pattern, src: str) -> dict[str, str]:
    return {m.group(1): re.sub(r"\s+", "", m.group(2)) for m in rx.finditer(src)}

def _keys(src: str) -> set[str]:
    import json
    try:
        d = json.loads(src)
    except ValueError:
        return set()
    out: set[str] = set()
    if isinstance(d, dict):
        for k, v in d.items():
            out.add(k)
            if isinstance(v, dict):
                out |= set(v)
    return {k for k in out if len(k) >= 4}

def _nodes(src: str) -> set[str]:
    return {next(g for g in m.groups() if g) for m in NODE.finditer(src)}

def head_defs(tree: Tree, rx: re.Pattern, ext: str) -> set[str]:
    """Function names the tree still defines in any `ext` file: a def that moved is not removed."""
    key = f"_defs{ext}"
    if not hasattr(tree, key):
        setattr(tree, key, set().union(*(set(_defs(rx, tree.text(p) or "")) for p in tree.files if p.endswith(ext) and in_scope(p))))
    return getattr(tree, key)

def head_members(tree: Tree) -> set[str]:
    """Top-level const/var/signal names any .gd in the tree still declares: a member that moved is not removed."""
    if not hasattr(tree, "_members"):
        tree._members = set().union(*(set(GD_MEMBER.findall(tree.text(p) or "")) for p in tree.files if p.endswith(".gd")))
    return tree._members

def head_nodes(tree: Tree) -> set[str]:
    """Every node name and group the tree still declares (scenes, `.name =`, add_to_group)."""
    if not hasattr(tree, "_nodes"):
        tree._nodes = set().union(*(_nodes(tree.text(p) or "") for p in tree.files if p.endswith((".gd", ".tscn"))))
    return tree._nodes

def node_ref(name: str, line: str) -> bool:
    """The line uses `name` as a node path or group: $Name, %Name, "a/Name", get_node / group calls with "Name"."""
    q = re.escape(name)
    line = re.sub(r'"(?:res|user)://[^"]*"', '""', line)  # a script/scene path is not a node path
    return bool(re.search(rf"[$%]{q}\b|/{q}\b[^\s]*\"|\"[^\"\s]*/{q}\b|(node|group|child)\w*\(\s*\"{q}\"|\"(node|group|path)\"\s*:\s*\"[^\"]*\b{q}\b", line))

def gone(c: Change, old: Tree, new: Tree, ents_new: dict, basenames_new: dict) -> list[Gone]:
    """Names the change removed (or whose signature changed) that other files could still use."""
    out: list[Gone] = []
    o, n = old.text(c.old) or "", new.text(c.path) or ""
    if c.status in ("D", "R"):
        out.append(Gone("path", c.old, c.path))
        b = c.old.rsplit("/", 1)[-1]
        if b not in basenames_new and len(b) >= 9:
            out.append(Gone("path", b, c.path))
    if re.fullmatch(r"tools/[^/]+\.py", c.old):
        e = Path(c.old).stem
        for sub in subcommands(o) - subcommands(n if c.status != "D" else ""):
            out.append(Gone("command", f"{e}.py {sub}", c.path))
    if c.status == "D":
        return out
    if c.path.endswith(".py") and c.path.startswith("tools/"):
        tool = names_of(c.path, new, ents_new, basenames_new)
        for f in sorted(set(FLAG.findall(o)) - set(FLAG.findall(n)) - set(re.findall(r"--[\w-]+", n))):
            out.append(Gone("flag", f, c.path, [t for t in tool if not t.startswith(("import ", "from "))]))
    for rx, ext in ((PY_DEF, ".py"), (GD_DEF, ".gd")):
        if c.path.endswith(ext):
            do, dn = _defs(rx, o), _defs(rx, n)
            for name in sorted(set(do) - set(dn) - head_defs(new, rx, ext)):
                if len(name) >= 4 and not name.startswith("_") and name not in ("main", "selftest", "_ready", "_process"):
                    out.append(Gone("def", name, c.path))
            for name in sorted(set(do) & set(dn)):
                if do[name] != dn[name] and not name.startswith("_"):
                    out.append(Gone("sig", name, c.path))
    if c.path.endswith(".gd"):  # a dropped const/var/signal (an old *_REV const): docs and dependents that still name it
        for name in sorted(set(GD_MEMBER.findall(o)) - set(GD_MEMBER.findall(n)) - head_members(new)):
            if len(name) >= 5 and "_" in name.strip("_"):
                out.append(Gone("member", name, c.path))
            elif len(name) >= 4 and name.isupper():  # REQUIRED: too common a word, so only a backticked doc mention counts
                out.append(Gone("member", name, c.path, ["`"]))
    if c.path.endswith((".gd", ".tscn")):
        for name in sorted(_nodes(o) - head_nodes(new)):
            if len(name) >= 4:
                out.append(Gone("node", name, c.path))
    if c.path.endswith(".json"):
        for k in sorted(_keys(o) - _keys(n)):
            if f'"{k}"' not in n:
                out.append(Gone("key", k, c.path))
    return out

def doc_changed(c: Change, old_src: str, new_src: str) -> int:
    """New line number of the first changed docstring/help line when the change both removed and added prose; else 0."""
    if c.status != "M" or not c.path.endswith(".py"):
        return 0
    spans = _doc_spans(old_src)
    gone_prose = any(any(a <= n <= b for a, b in spans) or "help=" in t for n, t in zip(c.removed_at, c.removed))
    new_prose = [c.added_at[i] for i in range(len(c.added)) if is_prose(c, i, new_src) or "help=" in c.added[i]]
    return new_prose[0] if gone_prose and new_prose else 0

def is_prose(c: Change, i: int, new_src: str) -> bool:
    """The i-th added line is a comment or sits inside a docstring of the new file."""
    line = c.added[i].strip()
    if line.startswith("#"):
        return True
    if not c.path.endswith(".py"):
        return False
    spans = _doc_spans(new_src)
    return any(a <= c.added_at[i] <= b for a, b in spans)

@functools.lru_cache(maxsize=64)
def _doc_spans(src: str) -> list[tuple[int, int]]:
    try:
        tree = ast.parse(src)
    except SyntaxError:
        return []
    out = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and node.body:
            first = node.body[0]
            if isinstance(first, ast.Expr) and isinstance(getattr(first, "value", None), ast.Constant) and isinstance(first.value.value, str):
                out.append((first.lineno, first.end_lineno or first.lineno))
    return out

def gd_code(src: str) -> str:
    """GDScript with comments, blank lines and trailing space dropped (quotes respected, a triple-quoted string
    spans lines): equal = a comment-only change."""
    out, q = [], ""
    for line in src.splitlines():
        held, i = bool(q), 0
        while i < len(line):
            ch = line[i]
            if q:
                if ch == "\\":
                    i += 1
                elif line.startswith(q, i):
                    i, q = i + len(q) - 1, ""
            elif line.startswith(('"""', "'''"), i):
                q, i = line[i:i + 3], i + 2
            elif ch in "\"'":
                q = ch
            elif ch == "#":
                line = line[:i]
                break
            i += 1
        if len(q) == 1:
            q = ""
        if line.strip() or held:
            out.append(line.rstrip())
    return "\n".join(out)

TOKEN = re.compile(r"[A-Za-z][\w{}-]*_[\w{}-]+")

def stale_lines(owner: str, names: list[str], added_prose: list[str], dep: str, text: str, skip: set[str]) -> list[tuple[int, str]]:
    """Lines of an untouched dependent that sit in a paragraph naming `owner` (any of its `names`) and repeat a distinctive token
    (has an underscore, 6+ chars, not a module stem in `skip`; help= lines count by their strings) of the owner's changed
    docstring: the exact line that may now be stale."""
    stem, own_stem = Path(owner).stem, Path(dep).stem
    prose = [" ".join(re.findall(r"[\"']([^\"']*)[\"']", ln)) if "help=" in ln else ln for ln in added_prose]
    toks = {t for ln in prose for t in TOKEN.findall(ln) if len(t) >= 6 and t not in skip | {stem, own_stem}}
    if not toks:
        return []
    lines, out, para = text.splitlines(), [], []
    for no, line in enumerate(lines + [""], 1):
        if line.strip():
            para.append((no, line))
            continue
        if para and any(n in ln for _, ln in para for n in names + [stem]):
            out += [(n, ln.strip()) for n, ln in para if set(TOKEN.findall(ln)) & toks]
        para = []
    return out
