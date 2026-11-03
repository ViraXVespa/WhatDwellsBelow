#!/usr/bin/env python3
"""Qualify names that moved to helper modules after a size split (stdlib only).

  python tools/lint.py requal scripts/x.gd            # auto: rewrite
  python tools/lint.py requal scripts/x.gd --dry-run  # list code vs comment/string matches
  python tools/lint.py requal scripts/x.gd --check    # change nothing; exit 1 if a problem is left

Auto mode: the modules are FILE's own `const Mod := preload("res://...")` lines for scripts in
the same folder or in the facade's cluster folder `<dir>/<stem>/` (facade beside its folder, helpers inside it,
trimmed names). A name used bare in FILE but not defined in FILE, and defined (func, const,
or top-level var) in exactly one such module, becomes Mod.name. Functions match call sites
only (`name(`), so a local variable of the same name is safe; consts and vars match any bare
use. Only CODE is rewritten; comment/string matches are listed (--all rewrites them too).
--check also lists BAD-CALLER lines for a name defined in FILE at git HEAD but gone now (a facade delegate is
missing): Alias.name from a preload alias or an autoload of FILE in any live .gd, a by-name call("name") /
has_method("name") no other live script defines, and a .tscn [connection] method= in a scene using FILE.
Manual: --sym NAME=Mod or NAME()=Mod (calls only) skips the auto lookup. Keeps BOM and EOLs.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log

DEF = re.compile(r"^(?:static\s+)?func\s+(\w+)|^const\s+(\w+)|^(?:static\s+)?var\s+(\w+)", re.M)

def kinds(text: str) -> list[str]:
    """Per-char class: c code, m comment, s string (single-line and triple quotes)."""
    out = ["c"] * len(text)
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch == "#":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out[i:j] = "m" * (j - i)
            i = j
        elif ch in "\"'":
            tri = text.startswith(ch * 3, i)
            q = ch * 3 if tri else ch
            j = i + len(q)
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text.startswith(q, j):
                    j += len(q)
                    break
                if not tri and text[j] == "\n":
                    break
                j += 1
            j = min(j, n)
            out[i:j] = "s" * (j - i)
            i = j
        else:
            i += 1
    return out

def defs(text: str) -> dict[str, str]:
    """name -> 'f' (func) or 'v' (const/var), top level only."""
    d = {}
    for m in DEF.finditer(text):
        d[m.group(1) or m.group(2) or m.group(3)] = "f" if m.group(1) else "v"
    return d

def find(text: str, name: str, cls: list[str], call: bool) -> dict[str, list[int]]:
    hits: dict[str, list[int]] = {"c": [], "m": [], "s": []}
    for m in re.finditer(r"(?<![\w.])" + re.escape(name) + (r"(?=\()" if call else r"\b"), text):
        ls = text.rfind("\n", 0, m.start()) + 1
        if re.match(r"\s*(static\s+)?(func|var|const)\s+$", text[ls:m.start()]):
            continue
        hits[cls[m.start()]].append(m.start())
    return hits

def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1

def project_root(p: Path) -> Path:
    for d in [p.resolve().parent, *p.resolve().parents]:
        if (d / "project.godot").is_file():
            return d
    return Path.cwd()

def modules(text: str, path: Path, root: Path) -> dict[str, dict[str, str]]:
    mods = {}
    for m in re.finditer(r'^const\s+(\w+)\s*(?::[^=]*)?:?=\s*preload\("res://([^"]+)"\)', text, re.M):
        f = root / m.group(2)
        here = path.resolve().parent
        if f.is_file() and f.resolve() != path.resolve() and f.parent.resolve() in (here, here / path.stem):
            mods[m.group(1)] = defs(f.read_text(encoding="utf-8-sig"))
    return mods

def auto_syms(text: str, path: Path, root: Path) -> tuple[list[tuple[str, str, bool]], list[str]]:
    own, mods = defs(text), modules(text, path, root)
    owners: dict[str, list[str]] = {}
    for mod, d in mods.items():
        for n in d:
            if n not in own:
                owners.setdefault(n, []).append(mod)
    cls = kinds(text)
    syms, notes = [], []
    for n, mm in sorted(owners.items()):
        kind = {mods[m][n] for m in mm}
        call = kind == {"f"}
        if not find(text, n, cls, call)["c"] and not any(find(text, n, cls, call)[k] for k in "ms"):
            continue
        if len(mm) > 1:
            notes.append(f"ambiguous {n}: {', '.join(mm)} (use --sym)")
            continue
        syms.append((n, mm[0], call))
    return syms, notes

def bad_callers(text: str, path: Path, root: Path) -> list[str]:
    rel = path.resolve().relative_to(root).as_posix()
    try:
        old = subprocess.run(["git", "show", f"HEAD:{rel}"], cwd=root, capture_output=True, check=True).stdout.decode("utf-8-sig")
    except Exception:
        return []
    gone = set(defs(old)) - set(defs(text))
    if not gone:
        return []
    out = []
    alias = re.compile(r'(?:const|var)\s+(\w+)\s*(?::[^=]*)?:?=\s*(?:preload|load)\("res://' + re.escape(rel) + r'"\)')
    pg = root / "project.godot"  # an autoload of FILE is a global alias in every script
    auto = set(re.findall(r'^(\w+)="\*?res://' + re.escape(rel) + '"', pg.read_text(encoding="utf-8", errors="replace"), re.M)) if pg.is_file() else set()
    import gd_lib
    files = gd_lib.live_gd(root)
    elsewhere = {n for f in files if f.resolve() != path.resolve() for n in defs(f.read_text(encoding="utf-8-sig", errors="replace"))}
    strcall = re.compile(r"""(?:call_deferred|callv|call|has_method|Callable\(\s*\w+\s*,)\(?\s*["'](\w+)["']""")
    for f in files:
        if f.resolve() == path.resolve():
            continue
        t = f.read_text(encoding="utf-8-sig", errors="replace")
        for a in {m.group(1) for m in alias.finditer(t)} | auto:
            for m in re.finditer(r"(?<![\w.])" + re.escape(a) + r"\.(\w+)", t):
                if m.group(1) in gone:
                    out.append(f"BAD-CALLER {f.relative_to(root)}:{line_of(t, m.start())}: {a}.{m.group(1)}")
        for m in strcall.finditer(t):  # by-name call of a gone func no other live script defines
            if m.group(1) in gone and m.group(1) not in elsewhere:
                out.append(f"BAD-CALLER {f.relative_to(root)}:{line_of(t, m.start())}: \"{m.group(1)}\" by name")
    for f in sorted(p for d in ("scenes", "scripts") for p in (root / d).rglob("*.tscn")):
        t = f.read_text(encoding="utf-8", errors="replace")
        if f'path="res://{rel}"' not in t:
            continue
        for m in re.finditer(r'^\[connection [^\n]*method="(\w+)"', t, re.M):  # signal wired in the scene FILE is attached to
            if m.group(1) in gone:
                out.append(f"BAD-CALLER {f.relative_to(root)}:{line_of(t, m.start())}: connection method=\"{m.group(1)}\"")
    return out

def _selftest() -> int:
    """Funcs removed from scripts/a.gd (committed at HEAD) and still called: preload alias in tools/data, autoload alias,
    call("name"), and a .tscn connection. All four must be BAD-CALLER rows (only the scripts/ preload one was before)."""
    import tempfile
    bad = []
    with tempfile.TemporaryDirectory(prefix="wdb-requal-st-") as td:
        t = Path(td)
        files = {"project.godot": 'config_version=5\n[autoload]\nAa="*res://scripts/a.gd"\n',
                 "scripts/a.gd": "extends Node\nfunc foo() -> void:\n\tpass\nfunc bar() -> void:\n\tpass\nfunc baz() -> void:\n\tpass\nfunc qux() -> void:\n\tpass\n",
                 "tools/data/c.gd": 'extends Node\nconst A := preload("res://scripts/a.gd")\nfunc f() -> void:\n\tA.foo()\n',
                 "scripts/b.gd": 'extends Node\nfunc f(n: Node) -> void:\n\tn.call("bar")\n',
                 "scripts/d.gd": "extends Node\nfunc f() -> void:\n\tAa.qux()\n",
                 "scenes/s.tscn": '[gd_scene format=3]\n[ext_resource type="Script" path="res://scripts/a.gd" id="1"]\n[node name="S" type="Node"]\nscript = ExtResource("1")\n[connection signal="ready" from="." to="." method="baz"]\n'}
        for rel, body in files.items():
            (t / rel).parent.mkdir(parents=True, exist_ok=True)
            (t / rel).write_text(body, encoding="utf-8")
        for args in (["init", "-q"], ["add", "-A"], ["-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "t"]):
            subprocess.run(["git", "-C", td, *args], check=True, capture_output=True)
        (t / "scripts/a.gd").write_text("extends Node\n", encoding="utf-8")
        rows = bad_callers("extends Node\n", t / "scripts/a.gd", t)
    for want in ("tools/data/c.gd", "scripts/d.gd", "scripts/b.gd", "scenes/s.tscn"):
        if not any(want in r for r in rows):
            bad.append(f"no BAD-CALLER row for {want}: got {rows}")
    return agent_log.selftest_result(bad)

def main() -> int:
    p = agent_log.std_parser(__doc__, writes=True)
    p.formatter_class = argparse.RawDescriptionHelpFormatter
    p.add_argument("file", nargs="?", default="", help="GDScript file to rewrite.")
    p.add_argument("--selftest", action="store_true", help="BAD-CALLER rows for preload, autoload, by-name and .tscn callers (throwaway repo)")
    p.add_argument("--sym", action="append", default=[], metavar="NAME=Mod", help="NAME=Module: qualify NAME as Module.NAME (repeatable).")
    p.add_argument("--check", action="store_true", help="Report unqualified moved names and exit 1 if any; edit nothing.")
    p.add_argument("--all", action="store_true", help="Also rewrite matches inside comments and strings.")
    ns = p.parse_args()
    if ns.selftest:
        return _selftest()
    path = Path(ns.file)
    root = agent_log.resolve_root(ns) if ns.root else project_root(path)
    if not ns.file or not path.is_file():
        agent_log.fail(f"want a GDScript file, got {ns.file or '(none)'!r}")
    text = path.read_bytes().decode("utf-8")
    if ns.sym:
        syms = []
        for spec in ns.sym:
            if "=" not in spec:
                agent_log.fail(f"bad --sym {spec!r} (want NAME=Mod)")
            n, mod = spec.split("=", 1)
            syms.append((n[:-2] if n.endswith("()") else n, mod, n.endswith("()")))
        notes: list[str] = []
    else:
        syms, notes = auto_syms(text, path, root)
    for n in notes:
        print("note " + n)
    if ns.check:
        cls, bad = kinds(text), 0
        for n, mod, call in syms:
            h = find(text, n, cls, call)
            for pos in h["c"]:
                bad += 1
                print(f"BARE {path}:{line_of(text, pos)}: {n} (use {mod}.{n})")
        for line in bad_callers(text, path, root):
            bad += 1
            print(line)
        print(f"check: problems={bad}")
        return agent_log.emit_result("FAIL" if bad else "PASS", mode="check", problems=bad)
    for n, mod, call in syms:
        cls = kinds(text)
        h = find(text, n, cls, call)
        todo = h["c"] + (h["m"] + h["s"] if ns.all else [])
        print(f"{n} -> {mod}.{n}: code={len(h['c'])} comment={len(h['m'])} string={len(h['s'])}")
        for k, label in (("m", "comment"), ("s", "string")):
            for pos in h[k]:
                print(f"  {label} line {line_of(text, pos)}{'' if ns.all else ' (left as is)'}")
        for pos in sorted(todo, reverse=True):
            text = text[:pos] + f"{mod}." + text[pos:]
    if not ns.dry_run:
        path.write_bytes(text.encode("utf-8"))
    return agent_log.emit_result("PASS", mode="rewrite", syms=len(syms), dry_run=ns.dry_run)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
