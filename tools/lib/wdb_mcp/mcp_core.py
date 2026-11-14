"""Handle store, paging and no-repeat ledger for the wdb MCP (tools/wdb_mcp.py serve). No CLI of its own.

Every tool call runs the real repository command once (`run_tool`), keeps its full result under a short handle and
answers with a STATUS header plus at most one page. Follow-ups page the cached text; they never re-run the command.
Shown source lines are remembered per file for the current epoch: a later read that overlaps them elides the unchanged
lines and sends only what is new or changed. `_logs/gather/epoch` (bumped by the PostCompact / resume hook) starts a
new epoch, because the model no longer holds what was shown before the compact. State persists in
`_logs/gather/mcp-handles.json` so a server restart keeps it. Handles expire after TTL seconds (MAX_HANDLES kept).
"""
from __future__ import annotations

import difflib
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

PAGE_LINES = 20
TTL = 2 * 3600
MAX_HANDLES = 64
STATE_REL = "_logs/gather/mcp-handles.json"
EPOCH_REL = "_logs/gather/epoch"
RESULT_RE = re.compile(r"^RESULT (PASS|FAIL|INFO|SKIP)\b(.*)$", re.M)
SUMMARY_RE = re.compile(r"\bsummary=(\S+)")
LINES_RE = re.compile(r"^lines=(\d+)-(\d+) of (\d+)$", re.M)
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif")

def read_epoch(root: Path, state: Path | None = None) -> str:
    try:
        return ((state / "epoch") if state else (root / EPOCH_REL)).read_text(encoding="utf-8").strip() or "0"
    except OSError:
        return "0"

def bump_epoch(root: Path, state: Path | None = None) -> str:
    """Start a new epoch (the hook calls this after a compact or a resume)."""
    path = (state / "epoch") if state else (root / EPOCH_REL)
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        n = int(read_epoch(root, state)) + 1
    except ValueError:
        n = 1
    path.write_text(str(n), encoding="utf-8")
    return str(n)

def denied(rel: str) -> str:
    """Reason a path may not be read through the MCP ('' when allowed). Mirrors the Build hook's read rules."""
    low = rel.replace("\\", "/").lstrip("./").lower()
    if low.startswith("_logs/") or "/_logs/" in low:
        return "reading _logs/ is denied: use lookup action=summary job=JOB"
    if low.startswith("notes/"):
        return "notes/ is never opened"
    if low.endswith(IMAGE_EXT):
        return "images are not read through the MCP: use isolated shots.py review, or a reference grant and a direct read"
    if ".." in Path(low).parts:
        return "path leaves the repo"
    return ""

def run_tool(root: Path, argv: list[str], timeout: int = 900) -> dict:
    """Run `python tools/<entry>.py ...` from the repo root. Full text = the run's summary file when it names one."""
    cmd = [sys.executable, str(root / "tools" / argv[0]), *argv[1:]]
    try:
        proc = subprocess.run(cmd, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        out, err, code = proc.stdout, proc.stderr, proc.returncode
    except subprocess.TimeoutExpired:
        out, err, code = "", f"timeout after {timeout}s", 124
    m = list(RESULT_RE.finditer(out))
    status = m[-1].group(1) if m else ("PASS" if code == 0 else "FAIL")
    tail = m[-1].group(2) if m else ""
    text = out
    sm = SUMMARY_RE.search(tail)
    if sm:
        try:
            text = (root / sm.group(1)).read_text(encoding="utf-8", errors="replace")
        except OSError:
            pass
    if err.strip():
        text = text.rstrip("\n") + "\n" + err.strip()
    return {"status": status, "code": code, "result": f"RESULT {status}{tail}" if m else "", "text": text.rstrip("\n"),
            "argv": " ".join(["python", "tools/" + argv[0], *argv[1:]])}

def file_sha(path: Path) -> str:
    try:
        return hashlib.sha1(path.read_bytes()).hexdigest()[:12]
    except OSError:
        return ""

class Store:
    def __init__(self, root: Path, persist: bool = True, state: Path | None = None):
        self.root = root
        self.state = state  # None: root/_logs/gather (selftests pass a temp dir)
        self.persist = persist
        self.handles: dict[str, dict] = {}
        self.seen: dict[str, list[str]] = {}  # path -> source lines shown this epoch (file order)
        self.epoch = read_epoch(root, state)
        self.n = 0
        self.runs = 0  # real commands started (selftest: a follow-up must not raise it)
        self._load()

    # persistence
    def _path(self) -> Path:
        return (self.state / "mcp-handles.json") if self.state else self.root / STATE_REL

    def _load(self) -> None:
        if not self.persist:
            return
        try:
            data = json.loads(self._path().read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return
        self.handles, self.n = data.get("handles", {}), int(data.get("n", 0))
        self.seen = data.get("seen", {}) if data.get("epoch") == self.epoch else {}

    def save(self) -> None:
        if not self.persist:
            return
        self._path().parent.mkdir(parents=True, exist_ok=True)
        self._path().write_text(json.dumps({"epoch": self.epoch, "n": self.n, "handles": self.handles, "seen": self.seen}), encoding="utf-8")

    def tick(self) -> None:
        """New epoch: forget shown lines. Drop expired and surplus handles."""
        ep = read_epoch(self.root, self.state)
        if ep != self.epoch:
            self.epoch, self.seen = ep, {}
        now = time.time()
        for h in [h for h, v in self.handles.items() if now - v.get("t", 0) > TTL]:
            del self.handles[h]
        while len(self.handles) > MAX_HANDLES:
            del self.handles[min(self.handles, key=lambda k: self.handles[k].get("t", 0))]

    def new(self, prefix: str, body: list[str], **meta: object) -> str:
        self.n += 1
        h = f"{prefix}{self.n}"
        self.handles[h] = {"t": time.time(), "lines": body, "pos": 0, **meta}
        return h

    def get(self, h: str) -> dict | None:
        return self.handles.get(h)

    # no-repeat
    def elide(self, rel: str, start: int, lines: list[str], fresh: bool = False) -> tuple[list[str], list[str]]:
        """Source lines numbered from `start`: runs of 3+ lines already paged out this epoch collapse to one note.
        Returns (body, src): src[i] is `rel` for a source line (marked as seen once it is paged out), '' for a note."""
        old = self.seen.get(rel, [])
        if fresh or not old:
            return list(lines), [rel] * len(lines)
        out: list[str] = []
        src: list[str] = []
        i = 0
        for blk in difflib.SequenceMatcher(a=old, b=lines, autojunk=False).get_matching_blocks():
            if blk.size < 3:
                continue
            out += lines[i:blk.b]
            src += [rel] * (blk.b - i)
            out.append(f"... L{start + blk.b}-{start + blk.b + blk.size - 1} unchanged, already shown")
            src.append("")
            i = blk.b + blk.size
        out += lines[i:]
        src += [rel] * (len(lines) - i)
        return out, src

    def mark(self, rel: str, lines: list[str]) -> None:
        """Remember source lines the model has now been sent (this epoch)."""
        old = self.seen.get(rel, [])
        self.seen[rel] = (old + ["\x00"] + lines)[-4000:] if old else list(lines)

def cut(lines: list[str], pos: int, budget: int) -> int:
    """End index for a page from pos: at most `budget` lines, ending at a blank line or dedent in the last quarter when one exists."""
    end = min(len(lines), pos + budget)
    if end >= len(lines):
        return end
    lo = pos + max(1, budget * 3 // 4)
    for j in range(end, lo, -1):
        prev, nxt = lines[j - 1], lines[j] if j < len(lines) else ""
        if not prev.strip() or (nxt and not nxt[:1].isspace()):
            return j
    return end

def header(status: str, h: str, nxt: str, shown: str = "", summary: str = "", fails: int = 0) -> list[str]:
    head = [f"STATUS: {status}" + (f" ({fails})" if status == "FAIL" else ""), f"handle: {h}", f"next: {nxt}"]
    if shown:
        head.append(f"shown: {shown}")
    if summary:
        head.append(f"summary: {summary}")
    return head

def page(store: Store, h: str, budget: int = 0, status: str = "PASS", summary: str = "", first: bool = False) -> str:
    """Next page of handle h (first page when first). Never re-sends lines already paged out of this handle."""
    rec = store.get(h)
    if rec is None:
        return "\n".join(header("FAIL", h, "rerun the original call", summary="expired or unknown handle", fails=1))
    lines = rec["lines"]
    pos = 0 if first else rec["pos"]
    if not first and pos >= len(lines):
        return "\n".join(header(status, h, "done", summary="nothing left on this handle"))
    budget = budget or rec.get("budget") or PAGE_LINES
    end = cut(lines, pos, budget)
    rec["pos"], rec["t"] = end, time.time()
    more = end < len(lines)
    nxt = (rec.get("next_more") or "more") if more else (rec.get("next_done") or "done")
    shown = f"{pos + 1}-{end} of {len(lines)}" if len(lines) > budget or pos else ""
    body = lines[pos:end]
    src = rec.get("src") or []
    for rel in {r for r in src[pos:end] if r}:
        store.mark(rel, [ln for ln, r in zip(body, src[pos:end]) if r == rel])
    if not first and pos and body:
        body = [f"... continues at line {pos + 1}"] + body
    store.save()
    return "\n".join(header(status, h, nxt, shown, summary) + ([""] + body if body else []))
