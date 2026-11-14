"""Handle store and paging for the wdb MCP (tools/wdb_mcp.py serve). No CLI of its own.

Every tool call runs the real repository command once (`run_tool`), keeps its full result under a short handle and
answers with a STATUS header plus at most one page; `more` sends only the rest of that handle. Follow-ups never re-run
the command. Each handle is its own file in `_logs/gather/mcp/` (atomic temp + rename), so several servers on one
checkout (Build, its subagents, the gather agent, Grok Bot agents) never overwrite each other. Handles expire after
TTL seconds. Check rerun counts (`check-runs.json`, same atomic write) are per worktree.
"""
from __future__ import annotations

import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PAGE_LINES = 20
TTL = 2 * 3600
MAX_HANDLES = 256
STATE_REL = "_logs/gather/mcp"
HANDLE_RE = re.compile(r"^[a-z][0-9a-f]{6}$")
RESULT_RE = re.compile(r"^RESULT (PASS|FAIL|INFO|SKIP)\b(.*)$", re.M)
SUMMARY_RE = re.compile(r"\bsummary=(\S+)")
LINES_RE = re.compile(r"^lines=(\d+)-(\d+) of (\d+)$", re.M)
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp", ".gif")

def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise

def denied(rel: str) -> str:
    """Reason a path may not be read through the MCP ('' when allowed). Mirrors the Build hook's read rules."""
    low = rel.replace("\\", "/").lower()
    while low.startswith("./"):
        low = low[2:]
    if low.startswith("_logs/") or "/_logs/" in low:
        return "reading _logs/ is denied: use lookup action=summary query=JOB"
    if low.startswith("notes/"):
        return "notes/ is never opened"
    if low.endswith(IMAGE_EXT):
        return "images are not read through the MCP: use isolated shots.py review, or a reference grant and a direct read"
    if ".." in Path(low).parts or low.startswith("/") or ":" in low.split("/", 1)[0]:
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

class Store:
    """Handles: one JSON file each under the state dir (persist) or a dict (selftests with persist=False)."""

    def __init__(self, root: Path, persist: bool = True, state: Path | None = None):
        self.root = root
        self.dir = state or root / STATE_REL
        self.persist = persist
        self.mem: dict[str, dict] = {}
        self.runs = 0  # real commands started (selftest: a follow-up must not raise it)

    def _file(self, h: str) -> Path:
        return self.dir / f"{h}.json"

    def tick(self) -> None:
        """Drop expired handles and the oldest beyond MAX_HANDLES."""
        now = time.time()
        if not self.persist:
            for h in [h for h, v in self.mem.items() if now - v.get("t", 0) > TTL]:
                del self.mem[h]
            return
        try:
            files = sorted(self.dir.glob("[a-z]" + "[0-9a-f]" * 6 + ".json"), key=lambda f: f.stat().st_mtime)
        except OSError:
            return
        for i, f in enumerate(files):
            try:
                if i < len(files) - MAX_HANDLES or now - f.stat().st_mtime > TTL:
                    f.unlink(missing_ok=True)
            except OSError:
                pass

    def new(self, prefix: str, body: list[str], **meta: object) -> str:
        h = prefix[:1] + secrets.token_hex(3)
        self.put(h, {"t": time.time(), "lines": body, "pos": 0, **meta})
        return h

    def get(self, h: str) -> dict | None:
        if not HANDLE_RE.match(h or ""):
            return None
        if not self.persist:
            return self.mem.get(h)
        try:
            rec = json.loads(self._file(h).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None
        return rec if time.time() - rec.get("t", 0) <= TTL else None

    def put(self, h: str, rec: dict) -> None:
        rec["t"] = time.time()
        if self.persist:
            write_atomic(self._file(h), json.dumps(rec))
        else:
            self.mem[h] = rec

    # check rerun counts (per worktree)
    def check_runs(self) -> dict[str, list[str]]:
        if not self.persist:
            return self.mem.setdefault("__runs__", {})
        try:
            return json.loads((self.dir / "check-runs.json").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    def add_check_run(self, key: str, h: str) -> None:
        runs = self.check_runs()
        runs[key] = runs.get(key, []) + [h]
        if self.persist:
            write_atomic(self.dir / "check-runs.json", json.dumps(runs))

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

def header(status: str, *lines: str, fails: int = 0) -> list[str]:
    """`STATUS: PASS` or `STATUS: FAIL (N)`, then only the non-empty extra lines (page, handle, summary, error)."""
    return [f"STATUS: {status}" + (f" ({fails or 1})" if status == "FAIL" else "")] + [ln for ln in lines if ln]

def fail(why: str) -> str:
    return "\n".join(header("FAIL", f"error: {why}", fails=1))

ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
META_KEYS = {"root", "path", "pattern", "mode", "include", "scope", "facade", "stem", "dir", "maxNodes", "name", "count",
             "scanned", "rows_scanned", "matches", "siblings", "files", "top_funcs", "hits", "truncated", "scenes"}
BANNER_RE = re.compile(r"^(?:measure=|show_func |[\w -]+ \d{4}-\d\d-\d\dT\S+$|file-stat$)")

def clean(lines: list[str], banners: bool = False) -> list[str]:
    """Trailing whitespace and ANSI off, runs of blank lines to one, no leading/trailing blanks. banners: also drop a
    wrapped CLI's echo/legend lines (key=value lines of argument echoes and counts, `measure=`, a title with a timestamp)."""
    out: list[str] = []
    for raw in lines:
        ln = ANSI_RE.sub("", raw).rstrip()
        if banners:
            toks = ln.split()
            if BANNER_RE.match(ln) or (toks and all("=" in t and t.split("=", 1)[0] in META_KEYS for t in toks)
                                       and "truncated=True" not in toks):
                continue
        if not ln and (not out or not out[-1]):
            continue
        out.append(ln)
    while out and not out[-1]:
        out.pop()
    return out

def page(store: Store, h: str, budget: int = 0, status: str = "PASS", summary: str = "", first: bool = False) -> str:
    """One page of handle h. A reply that fits is just STATUS (+ summary) and the body; a cut one adds
    `page: A-B of N; more: handle=H` and `more` sends only the rest."""
    rec = store.get(h)
    if rec is None:
        return fail(f"expired or unknown handle {h}; rerun the original call")
    lines = rec["lines"]
    pos = 0 if first else rec["pos"]
    if not first and pos >= len(lines):
        return "\n".join(header(status, f"page: end (handle {h} has nothing left)"))
    budget = budget or rec.get("budget") or PAGE_LINES
    end = cut(lines, pos, budget)
    rec["pos"] = end
    store.put(h, rec)
    pg = ""
    if end < len(lines) or pos:
        pg = f"page: {pos + 1}-{end} of {len(lines)}" + (f"; more: handle={h}" if end < len(lines) else " (end)")
    body = lines[pos:end]
    while body and not body[0].strip():
        body = body[1:]
    return "\n".join(header(status, pg, f"summary: {summary}" if summary else "",
                             fails=1) + ([""] + body if body else []))
