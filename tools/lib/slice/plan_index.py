"""The session-plan index: the gathered half of session-plan.md below `<!-- gathered -->` (library; import only).

The md is the single source of truth (no JSON copy). Shape:

    ### Identity            - key: value lines (door, job, task, area, mode, systems, seed, gather, judgment, unresolved)
    ### Core                - C1 func `scripts/x.gd:build` (L12-58) - why        (always expanded into the packet)
    ### Candidates          - K1 doc `design/x.md#Heading` - when: condition     (listed with the condition, opened on demand)
    ### Card                route card text (verbatim)

Kinds: func (`path:name`), file (`path`, optional `(La-b)`), doc (`path`, `path#Heading` or `path` `(La-b)`), names (`path`: the
script's declared names). One path may appear with several ranges. Ids are stable for delta replay: a promoted K or demoted C keeps its id; the section says
which it is now. `parse(render(x)) == x`; `render(parse(t)) == t` for any text this module wrote.
`slice.py adjust` mutates it (with `_logs/gather/delta.jsonl`); `slice.py expand` turns it into the packet.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

MARKER = "<!-- gathered -->"
KINDS = ("func", "file", "doc", "names")
ITEM_RE = re.compile(r"^- (?P<id>[CK]\d+) (?P<kind>\w+) `(?P<ref>[^`]+)`(?: \(L(?P<a>\d+)-(?P<b>\d+)\))?(?: - (?P<note>.*))?$")

@dataclass
class Item:
    id: str
    kind: str
    ref: str
    core: bool
    note: str = ""  # why (core) or the condition (candidate)
    lines: tuple[int, int] | None = None

    def line(self) -> str:
        rng = f" (L{self.lines[0]}-{self.lines[1]})" if self.lines else ""
        note = (f" - when: {self.note}" if not self.core else f" - {self.note}") if self.note else ""
        return f"- {self.id} {self.kind} `{self.ref}`{rng}{note}"

@dataclass
class Index:
    identity: list[tuple[str, str]] = field(default_factory=list)
    items: list[Item] = field(default_factory=list)
    card: str = ""

    def get(self, key: str) -> str:
        return next((v for k, v in self.identity if k == key), "")

    def set(self, key: str, value: str) -> None:
        for i, (k, _) in enumerate(self.identity):
            if k == key:
                self.identity[i] = (key, value)
                return
        self.identity.append((key, value))

    def find(self, token: str, lines: tuple[int, int] | None = None) -> Item | None:
        """By id (C3, K1) or by ref (`path:name`, `path`, `path#Heading`); with lines, the item for that range of the ref."""
        by_id = next((it for it in self.items if it.id == token), None)
        if by_id or lines is not None:
            return by_id or next((it for it in self.items if it.ref == token and it.lines == lines), None)
        return next((it for it in self.items if it.ref == token and it.lines is None), None) or \
            next((it for it in self.items if it.ref == token), None)

    def next_id(self, core: bool) -> str:
        nums = [int(it.id[1:]) for it in self.items] or [0]
        return ("C" if core else "K") + str(max(nums) + 1)

def parse(text: str) -> Index:
    idx = Index()
    sec = ""
    card: list[str] = []
    for line in text.splitlines():
        if line.startswith("### "):
            sec = line[4:].strip()
            continue
        if sec == "Card":
            card.append(line)
        elif sec == "Identity" and line.startswith("- ") and ": " in line:
            key, val = line[2:].split(": ", 1)
            idx.identity.append((key, val))
        elif sec in ("Core", "Candidates") and (m := ITEM_RE.match(line)):
            note = m.group("note") or ""
            core = sec == "Core"
            if not core and note.startswith("when: "):
                note = note[6:]
            rng = (int(m.group("a")), int(m.group("b"))) if m.group("a") else None
            idx.items.append(Item(m.group("id"), m.group("kind"), m.group("ref"), core, note, rng))
    idx.card = "\n".join(card).strip("\n")
    return idx

def render(idx: Index) -> str:
    out = ["### Identity", ""] + [f"- {k}: {v}" for k, v in idx.identity] + ["", "### Core", ""]
    core = [it.line() for it in idx.items if it.core]
    cand = [it.line() for it in idx.items if not it.core]
    out += (core or ["(none)"]) + ["", "### Candidates", ""] + (cand or ["(none)"])
    out += ["", "### Card", "", idx.card or "(no card)", ""]
    return "\n".join(out)

def split_plan(text: str) -> tuple[str, str]:
    """(kept half including its trailing blank line, gathered half) of a session-plan.md."""
    if MARKER not in text:
        return text, ""
    head, tail = text.split(MARKER, 1)
    return head, tail.lstrip("\n")

def join_plan(kept: str, idx: Index) -> str:
    return kept.rstrip() + "\n\n" + MARKER + "\n\n" + render(idx)

def doc_span(lines: list[str], heading: str) -> tuple[int, int] | None:
    """1-based [a, b] of a markdown heading's section, up to the next heading of the same or higher level."""
    want = heading.strip().lower()
    fence = False
    for i, ln in enumerate(lines):
        if ln.startswith("```"):
            fence = not fence
        m = None if fence else re.match(r"^(#+)\s+(.*)$", ln)
        if m and m.group(2).strip().lower() == want:
            lvl = len(m.group(1))
            for j in range(i + 1, len(lines)):
                n = re.match(r"^(#+)\s", lines[j])
                if n and len(n.group(1)) <= lvl:
                    return i + 1, j
            return i + 1, len(lines)
    return None

def resolve(root: Path, it: Item) -> tuple[str, list[str]]:
    """(error, body lines) for one item. error '' when it resolves."""
    import gd_lib
    import show_func

    path, _, rest = it.ref.partition("#") if it.kind == "doc" else (it.ref, "", "")
    if it.kind == "func":
        path, _, name = it.ref.partition(":")
    path = path.strip()
    f = root / path
    if not f.is_file():
        return f"missing file {path}", []
    try:
        lines = f.read_text(encoding="utf-8-sig").splitlines()
    except (OSError, UnicodeError) as exc:
        return f"unreadable {path}: {exc}", []
    if it.kind == "func":
        span = show_func.py_span(lines, name) if path.endswith(".py") else gd_lib.decl_span(lines, name)
        if span is None:
            return f"no declaration {name} in {path}", []
        return "", [f"(L{span[0] + 1}-{span[1]})"] + lines[span[0]:span[1]]
    if it.kind == "doc" and rest:
        span = doc_span(lines, rest)
        if span is None:
            return f"no heading {rest!r} in {path}", []
        return "", [f"(L{span[0]}-{span[1]})"] + lines[span[0] - 1:span[1]]
    if it.kind == "names":
        return "", [", ".join(show_func.declared_names(lines, path.endswith(".py"))) or "(none)"]
    if it.kind not in KINDS:
        return f"unknown kind {it.kind}", []
    a, b = it.lines or (1, len(lines))
    if a < 1 or b > len(lines) or a > b:
        return f"range L{a}-{b} outside {path} (1-{len(lines)})", []
    return "", [f"(L{a}-{b})"] + lines[a - 1:b]
