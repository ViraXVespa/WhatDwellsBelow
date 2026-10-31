"""Compact one task file at unit done (slice.py start --unit-done; docs.py task compact ID). Deterministic and conservative.

Rules, in order:
- The header (lines above the first `## `) is never touched.
- A section whose title names a done unit (`## Unit LABEL...`, `## LABEL: ...`, `## LABEL`) becomes one line under
  `## Done units`: `- LABEL SHA: RESULT` (SHA: first 7-40 hex word in it, else `-`; RESULT: its `Result:` line, else its first sentence).
- In other sections, a line is dropped only when it starts with a tried/failed/baseline marker (`Tried`, `Failed`, `Did not work`,
  `Baseline`), names a done unit, and names no open unit.
- Never dropped or collapsed: sections whose title says Vira, decision, question, open, next, resume, handoff, intent; any line
  naming Vira, a decision (`decid`, `Decision`, `agreed`, `approved`) or ending in `?`. A protected line inside a collapsed section moves
  under `## Done units` verbatim, after that unit's line.
"""
from __future__ import annotations

import difflib
import re

KEEP_TITLE = re.compile(r"vira|decision|question|open|next|resume|handoff|intent", re.I)
KEEP_LINE = re.compile(r"vira|decid|decision|agreed|approved", re.I)
DROP_LINE = re.compile(r"^\s*(?:[-*]\s*)?(?:tried|failed|did not work|baseline)\b", re.I)
SHA = re.compile(r"\b[0-9a-f]{7,40}\b")
DONE_TITLE = "Done units"

def _protected(line: str) -> bool:
    return bool(KEEP_LINE.search(line)) or line.rstrip().endswith("?")

def _names(line: str, labels: list[str]) -> bool:
    return any(re.search(r"(?<![\w.-])" + re.escape(u) + r"(?![\w-])", line) for u in labels)

def _unit_of(title: str, done: list[str]) -> str:
    t = re.sub(r"^unit\s+", "", title.strip(), flags=re.I)
    return next((u for u in done if re.match(re.escape(u) + r"(?![\w-])", t)), "")

def _split(text: str) -> tuple[str, list[tuple[str, list[str]]]]:
    head, secs = [], []
    for ln in text.splitlines():
        if ln.startswith("## "):
            secs.append((ln[3:].strip(), []))
        elif secs:
            secs[-1][1].append(ln)
        else:
            head.append(ln)
    return "\n".join(head), secs

def _summary(lines: list[str]) -> tuple[str, str]:
    body = " ".join(l.strip() for l in lines if l.strip())
    m = SHA.search(body)
    r = re.search(r"\bresult:\s*([^\n]+)", "\n".join(lines), re.I)
    sha, res = (m.group(0) if m else "-"), (r.group(1).strip() if r else "")
    res = res or re.split(r"(?<=[.!])\s", body, 1)[0][:160]
    return sha, res or "done"

def compact(text: str, done: list[str], units: list[str]) -> str:
    """The compacted task text (same text when nothing applies)."""
    open_u = [u for u in units if u not in done]
    head, secs = _split(text)
    rolled, out = [], []
    for title, lines in secs:
        u = _unit_of(title, done) if not KEEP_TITLE.search(title) else ""
        if u:
            sha, res = _summary(lines)
            rolled += [f"- {u} {sha}: {res}"] + [l for l in lines if l.strip() and _protected(l)]
        elif title == DONE_TITLE:
            rolled = [l for l in lines if l.strip()] + rolled
        elif KEEP_TITLE.search(title):
            out.append((title, lines))
        else:
            out.append((title, [l for l in lines if _protected(l) or not (DROP_LINE.match(l) and _names(l, done) and not _names(l, open_u))]))
    if rolled:
        out.append((DONE_TITLE, rolled + [""]))
    parts = [head] + [f"## {t}\n" + "\n".join(ls) for t, ls in out]
    new = "\n".join(p.rstrip("\n") + "\n" for p in parts if p is not None).rstrip("\n") + "\n"
    return text if new.strip() == text.strip() else new

def report(path: str, old: str, new: str, dry: bool) -> str:
    line = f"compact {path}: {len(old.encode())} -> {len(new.encode())} bytes" + ("" if new != old else " (no change)")
    if dry and new != old:
        line += "\n" + "".join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), path, path + " (compacted)"))
    return line

def apply(path, rel: str, dry: bool) -> tuple[str, int]:
    """Compact the file at path using its own `units:` / `done:` header; write unless dry. Returns (report, changed)."""
    from task_lib import head, split
    old = path.read_text(encoding="utf-8")
    h = head(old)
    done = [d for d in split(h.get("done", "")) if d != "none"]
    new = compact(old, done, split(h.get("units", ""))) if done else old
    if not dry and new != old:
        path.write_text(new, encoding="utf-8")
    return report(rel, old, new, dry), int(not dry and new != old)

FIXTURE = """# T

id: t
status: active
units: a, b
done: a

## Intent
Make the thing.

## Unit a
Landed in 1a2b3c4d. Result: walls draw in 4 ms.
Tried the old atlas for a; it failed.
Vira decided: keep the 2x scale.

## Notes
- Tried pooling for a: no gain.
- Tried pooling for b: pending.
- Baseline a: 9 ms.
- Is b still needed?
- Failed on a once, but Vira approved the retry.
"""

def selftest() -> int:
    got = compact(FIXTURE, ["a"], ["a", "b"])
    bad = []
    for must in ("units: a, b", "## Intent\nMake the thing.", "- a 1a2b3c4d: walls draw in 4 ms.", "Vira decided: keep the 2x scale.",
                 "Tried pooling for b", "Is b still needed?", "Vira approved the retry"):
        if must not in got:
            bad.append(f"lost: {must}")
    for gone in ("Tried pooling for a", "Baseline a", "Tried the old atlas", "## Unit a"):
        if gone in got:
            bad.append(f"kept: {gone}")
    if compact(got, ["a"], ["a", "b"]) != got:
        bad.append("not idempotent")
    for b in bad:
        print("FAIL " + b)
    print(f"RESULT {'FAIL' if bad else 'PASS'} selftest task-compact")
    return 1 if bad else 0
