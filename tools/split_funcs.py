#!/usr/bin/env python3
"""Split a static-helper GDScript into a facade plus sibling helper modules (stdlib only).

  python tools/split_funcs.py FILE --list                  # sizes, calls, decls used, outside callers
  python tools/split_funcs.py FILE --plan plan.json --dry-run
  python tools/split_funcs.py FILE --plan plan.json        # write, qualify, check

plan.json maps helper file stem -> names to move (static funcs, consts, top-level vars):
  {"light_stamp_walk": ["_walk_mask", "_lift_floor", "_walk_buf"]}
Writes <stem>.gd beside FILE (extends Object, static funcs), removes the items from FILE, adds
`const Mod := preload(...)`, leaves a one-line delegate (same signature) for each moved public
func (and any func an outside script calls through FILE; `await` kept if the body awaits), copies preload consts the moved code
uses, then runs tools/facade_requal.py (rewrite + --check) on every file and prints a
line-multiset check (missing lines must be 0) and byte sizes. Keeps BOM and line endings.
Errors (nothing written): instance funcs, moved code using a facade-only const/var/func,
helper cycles. Fix the plan (move the name too) and re-run.
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import facade_requal as fr  # noqa: E402

START = re.compile(
    r"^(?P<func>(?:static\s+)?func\s+(?P<fn>\w+))|^const\s+(?P<cn>\w+)|^(?:@[\w()\", ]+\s+)?(?:static\s+)?var\s+(?P<vn>\w+)"
    r"|^(?:extends|class_name|signal|enum|class|@)\b"
)


def parse(text: str):
    """-> items: dicts kind(pre/func/const/var/other) name lines."""
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if START.match(l)]
    for k, i in enumerate(starts):  # pull directly-attached comment lines up to this item
        j = i
        floor = starts[k - 1] + 1 if k else 0
        while j - 1 >= floor and lines[j - 1].startswith("#"):
            j -= 1
        starts[k] = j
    items = []
    if starts and starts[0] > 0:
        items.append({"kind": "pre", "name": None, "lines": lines[: starts[0]]})
    for k, i in enumerate(starts):
        end = starts[k + 1] if k + 1 < len(starts) else len(lines)
        block = lines[i:end]
        head = next(l for l in block if not l.startswith("#"))
        m = START.match(head)
        kind, name = ("other", None)
        if m.group("fn"):
            kind, name = "func", m.group("fn")
        elif m.group("cn"):
            kind, name = "const", m.group("cn")
        elif m.group("vn"):
            kind, name = "var", m.group("vn")
        items.append({"kind": kind, "name": name, "lines": block,
                      "static": head.startswith("static") if kind == "func" else None})
    return items


def body(it) -> str:
    return "\n".join(it["lines"])


def refs(it, names, cls_cache=None) -> set[str]:
    t = body(it)
    cls = fr.kinds(t)
    out = set()
    for n, k in names.items():
        for m in re.finditer(r"(?<![\w.])" + re.escape(n) + (r"(?=\()" if k == "func" else r"\b"), t):
            ls = t.rfind("\n", 0, m.start()) + 1
            if cls[m.start()] == "c" and not re.match(r"\s*(static\s+)?(func|var|const)\s+$", t[ls:m.start()]):
                out.add(n)
                break
    return out - {it["name"]}


def sig_of(it):
    b = body(it)
    i0 = b.index("(", b.index("func"))
    d = 0
    for k in range(i0, len(b)):
        d += (b[k] == "(") - (b[k] == ")")
        if d == 0:
            i1 = k
            break
    e = b.index(":\n", i1) if ":\n" in b[i1:] else len(b)
    sig = b[: e + 1]
    inner, depth, cur, params = b[i0 + 1 : i1], 0, "", []
    for ch in inner:
        depth += ch in "([{"
        depth -= ch in ")]}"
        if ch == "," and depth == 0:
            params.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        params.append(cur)
    names = [re.match(r"\s*(\w+)", p).group(1) for p in params]
    ret = re.search(r"->\s*(\w+)", b[i1:e])
    return sig, names, (ret.group(1) if ret else None)


def outside(path: Path, root: Path) -> collections.Counter:
    rel = path.resolve().relative_to(root).as_posix()
    alias = re.compile(r'(?:const|var)\s+(\w+)\s*(?::[^=]*)?:?=\s*(?:preload|load)\("res://' + re.escape(rel) + r'"\)')
    cnt: collections.Counter = collections.Counter()
    for f in (root / "scripts").rglob("*.gd"):
        if f.resolve() == path.resolve():
            continue
        t = f.read_text(encoding="utf-8-sig", errors="replace")
        for a in {m.group(1) for m in alias.finditer(t)}:
            for m in re.finditer(r"\b" + re.escape(a) + r"\.(\w+)", t):
                cnt[m.group(1)] += 1
    return cnt


def camel(s: str) -> str:
    return "".join(w.capitalize() for w in s.split("_") if w)


def decode(path: Path):
    raw = path.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    t = raw.decode("utf-8-sig")
    crlf = "\r\n" in t
    return t.replace("\r\n", "\n"), bom, crlf


def encode(t: str, bom: bool, crlf: bool) -> bytes:
    t = re.sub(r"\n{3,}", "\n\n", t).rstrip("\n") + "\n"
    if crlf:
        t = t.replace("\n", "\r\n")
    return (b"\xef\xbb\xbf" if bom else b"") + t.encode("utf-8")


def do_list(items, path, root):
    names = {it["name"]: it["kind"] for it in items if it["name"]}
    ext = outside(path, root)
    for it in items:
        if not it["name"]:
            continue
        sz = len(body(it).encode()) + len(it["lines"])
        r = sorted(refs(it, names))
        extra = f" ext={ext[it['name']]}" if ext[it["name"]] else ""
        print(f"{it['kind']:5} {it['name']:<28}{sz:>6}B uses={r}{extra}")


def build(items, plan, path, root):
    names = {it["name"]: it["kind"] for it in items if it["name"]}
    owner = {}
    for stem, lst in plan.items():
        for n in lst:
            if n not in names:
                raise SystemExit(f"error: {n} (helper {stem}) is not a top-level func/const/var")
            if n in owner:
                raise SystemExit(f"error: {n} listed twice")
            owner[n] = stem
    byname = {it["name"]: it for it in items if it["name"]}
    for n in owner:
        it = byname[n]
        if it["kind"] == "func" and not it["static"]:
            raise SystemExit(f"error: {n} is an instance func; use the static-helper pattern by hand (refactor.md rule 4)")
    base = path.stem
    alias = {}
    for stem in plan:
        a = camel(stem[len(base) + 1 :] if stem.startswith(base + "_") else stem)
        alias[stem] = a if a not in names else a + "S"
    preloads = {it["name"]: it for it in items if it["kind"] == "const" and "preload(" in body(it)}
    pre_unmoved = {n: it for n, it in preloads.items() if n not in owner}
    dep = {s: set() for s in plan}
    copy = {s: [] for s in plan}
    for n, stem in owner.items():
        for r in sorted(refs(byname[n], {k: v for k, v in names.items() if k != n})):
            if owner.get(r) == stem:
                continue
            if r in owner:
                dep[stem].add(owner[r])
            elif r in pre_unmoved:
                if r not in copy[stem]:
                    copy[stem].append(r)
            else:
                raise SystemExit(f"error: moved {n} ({stem}) uses facade-only {names[r]} {r}; add {r} to the plan")
    for s in plan:  # cycle check
        seen, stack = set(), [s]
        while stack:
            for d in dep[stack.pop()]:
                if d == s:
                    raise SystemExit(f"error: helper cycle through {s}")
                if d not in seen:
                    seen.add(d)
                    stack.append(d)
    ext = outside(path, root)
    resdir = path.resolve().parent.relative_to(root).as_posix()
    out = {}
    for stem, lst in plan.items():
        parts = [f"extends Object\n\n## Split from {path.name}: {', '.join(lst[:3])}{'...' if len(lst) > 3 else ''}.\n"]
        for r in copy[stem]:
            parts.append(body(preloads[r]).rstrip("\n"))
        for d in sorted(dep[stem]):
            parts.append(f'const {alias[d]} := preload("res://{resdir}/{d}.gd")')
        pre = "\n".join(parts[1:])
        decls = [body(byname[n]) for n in lst if byname[n]["kind"] != "func"]
        funcs = [body(byname[n]) for n in lst if byname[n]["kind"] == "func"]
        txt = parts[0] + "\n" + (pre + "\n\n" if pre else "") + ("\n".join(decls) + "\n\n" if decls else "") + "\n".join(funcs)
        out[path.with_name(stem + ".gd")] = txt
    fac, added = [], False
    new_pre = "\n".join(f'const {alias[s]} := preload("res://{resdir}/{s}.gd")' for s in plan)
    last_pre = max([i for i, it in enumerate(items) if it["name"] in preloads and it["name"] not in owner], default=-1)
    if last_pre < 0:
        last_pre = max([i for i, it in enumerate(items) if it["kind"] in ("pre", "other")], default=-1)
    for i, it in enumerate(items):
        n = it["name"]
        if n in owner:
            if it["kind"] == "func" and (not n.startswith("_") or ext[n]):
                sig, args, ret = sig_of(it)
                call = f"{alias[owner[n]]}.{n}({', '.join(args)})"
                if re.search(r"(?<![\w.])await\b", body(it)):  # coroutine: keep the delegate awaiting it
                    call = "await " + call
                fac.append(sig + "\n\t" + ("" if ret == "void" else "return ") + call + "\n")
            elif it["kind"] == "const" and ext[n]:
                fac.append(f"const {n} := {alias[owner[n]]}.{n}")
        else:
            fac.append(body(it))
        if i == last_pre:
            fac.append(new_pre)
            added = True
    if not added:
        fac.insert(0, new_pre)
    out[path] = "\n".join(fac)
    return out, alias


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("file")
    p.add_argument("--list", action="store_true")
    p.add_argument("--plan")
    p.add_argument("--dry-run", action="store_true")
    ns = p.parse_args()
    path = Path(ns.file)
    root = fr.project_root(path)
    text, bom, crlf = decode(path)
    items = parse(text)
    if ns.list or not ns.plan:
        do_list(items, path, root)
        return 0
    plan = json.loads(Path(ns.plan).read_text(encoding="utf-8"))
    out, alias = build(items, plan, path, root)
    before = path.stat().st_size
    if ns.dry_run:
        for f, t in out.items():
            print(f"would write {f}  ~{len(encode(t, bom, crlf))}B" + (f"  (was {before}B)" if f == path else ""))
        return 0
    for f, t in out.items():
        f.write_bytes(encode(t, bom, crlf))
    tool = Path(__file__).resolve().parent / "facade_requal.py"
    bad = 0
    for f in out:
        subprocess.run([sys.executable, str(tool), str(f)], capture_output=True)
    for f in out:
        r = subprocess.run([sys.executable, str(tool), str(f), "--check"], capture_output=True, text=True)
        if r.returncode:
            bad += 1
            print(r.stdout.strip())
    strip = re.compile(r"\b(" + "|".join(alias.values()) + r")\.")
    ign = ("extends", "##", "const ")

    def lines(t):
        return collections.Counter(l.strip() for l in strip.sub("", t).split("\n") if l.strip() and not l.strip().startswith(ign))
    new = "\n".join(f.read_bytes().decode("utf-8-sig").replace("\r\n", "\n") for f in out)
    miss = lines(text) - lines(new)
    print(f"line-multiset: missing={sum(miss.values())}" + (f" {list(miss)[:3]}" if miss else ""))
    print(f"requal --check problems in {bad} file(s)")
    for f in out:
        print(f"{os.path.getsize(f):>7}B {f}" + (f"  (was {before}B)" if f == path else ""))
    return 1 if bad or miss else 0


if __name__ == "__main__":
    sys.exit(main())
