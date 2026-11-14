"""The three wdb MCP tools, as plain functions over mcp_core.Store: lookup, check, protocol. No CLI of its own.

Thin wrappers: each first call runs the real `find.py` / `docs.py` / `session.py` / `slice.py expand` /
`check.py` / `gate.py gd-load` command once and caches its full result under a handle; follow-ups page or filter that
cache (`more` sends only the rest) and never re-run it. `whole` (all=true) sends the whole result in the first reply;
`lookup reads=[...]` answers several independent reads in one reply. File reads live in mcp_read.py. Commands outside the caller's catalog surface (Surf column, `design/tools*.md`) are refused.
Read-only: nothing here writes repo files (state lives in `_logs/gather/`).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import mcp_core as core
import mcp_read

PATH_RE = re.compile(r"(?<![\w/.-])((?:scripts|scenes|tools|design|assets|_out)/[\w./-]+\.\w+)")
FAIL_RE = re.compile(r"\b(FAIL|ERROR|DRIFT|STALE|MISSING|UNMAPPED|SCRIPT ERROR)\b|^error:", re.M)
MAX_CHECK_RUNS = 3  # Build only: one run + 2 reruns per target and args (tools.md rule 10), counted per worktree
CHECKS = {  # target -> (catalog command, argv builder)
    "tool_cli": ("check.py tool-cli", lambda a: ["check.py", "tool-cli"] + (["--only", a["stem"]] if a.get("stem") else [])),
    "tool_docs": ("check.py tool-docs", lambda a: ["check.py", "tool-docs"]),
    "script_cap": ("check.py script-cap", lambda a: ["check.py", "script-cap"] + sum((["--path", p] for p in a.get("files", [])), [])),
    "load_graph": ("check.py load-graph", lambda a: ["check.py", "load-graph"]),
    "gd_load": ("gate.py gd-load", lambda a: ["gate.py", "gd-load"] + (["--files", *a["files"]] if a.get("files") else [])),
}
BATCH_KEYS = ("path", "name", "pattern", "pairs", "start", "end", "door", "job", "query", "regex", "expand")

def _surfaces(root: Path) -> dict[str, str]:
    """`entry.py sub` -> Surf letters, from every catalog row in design/tools*.md."""
    out: dict[str, str] = {}
    for doc in sorted((root / "design").glob("tools*.md")):
        for line in doc.read_text(encoding="utf-8-sig").splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) >= 5 and cells[0].startswith("`") and re.fullmatch(r"[BWD]*", cells[2]):
                out[cells[0].strip("`")] = cells[2]
    return out

class Tools:
    def __init__(self, root: Path, surface: str = "D", persist: bool = True, state: Path | None = None, rerun_limit: bool = True):
        self.root, self.surface, self.rerun_limit = root, surface, rerun_limit
        self.store = core.Store(root, persist, state)
        self.surf = _surfaces(root)

    # helpers
    def _allowed(self, catalog_cmd: str) -> str:
        letters = self.surf.get(catalog_cmd)
        if letters is None or self.surface in letters:
            return ""
        return f"{catalog_cmd} is not on surface {self.surface} (catalog Surf={letters})"

    def _run(self, argv: list[str], catalog_cmd: str) -> dict:
        why = self._allowed(catalog_cmd)
        if why:
            return {"status": "DENIED", "text": why}
        self.store.runs += 1
        return core.run_tool(self.root, argv)

    def _refuse(self, why: str) -> str:
        return core.fail(why)

    @staticmethod
    def _strip(text: str) -> list[str]:
        return [ln for ln in text.splitlines() if not ln.startswith("RESULT ")]

    def _follow(self, handle: str, action: str, budget: int) -> str:
        rec = self.store.get(handle)
        if rec is None:
            return core.fail(f"expired or unknown handle {handle}; rerun the original call")
        if action in ("failures", "files"):
            rows = rec.get(action) or []
            h = self.store.new("v", rows or [f"(no {action})"], status=rec.get("status", "PASS"))
            return core.page(self.store, h, budget, rec.get("status", "PASS"), first=True)
        if action == "full":
            rec["pos"] = 0
            return core.page(self.store, handle, budget or core.ALL, rec.get("status", "PASS"), first=True)
        return core.page(self.store, handle, budget, rec.get("status", "PASS"))

    # lookup
    def lookup(self, action: str = "more", handle: str = "", path: str = "", name: str = "", pattern: str = "",
               pairs: list | None = None, start: int = 0, end: int = 0, door: str = "", job: str = "",
               query: str = "", regex: bool = False, expand: str = "", budget: int = 0, whole: bool = False,
               reads: list | None = None) -> str:
        self.store.tick()
        budget = core.ALL if whole else budget
        if reads or action == "batch":
            return self._batch(reads or [], budget, whole)
        if handle or action in ("more", "full"):
            return self._follow(handle, action or "more", budget)
        kw = dict(path=path, name=name, pattern=pattern, pairs=pairs, start=start, end=end, door=door, job=job,
                  query=query, regex=regex, expand=expand)
        try:
            status, body, files, summary = self._one(action, whole, **kw)
        except core.Refused as exc:
            return self._refuse(str(exc))
        h = self.store.new({"func": "f", "lines": "r", "doc": "r"}.get(action, "l"), body, status=status, files=files)
        return core.page(self.store, h, budget, status, summary, first=True)

    def _one(self, action: str, whole: bool, path: str = "", name: str = "", pattern: str = "", pairs: list | None = None,
             start: int = 0, end: int = 0, door: str = "", job: str = "", query: str = "", regex: bool = False,
             expand: str = "") -> tuple[str, list[str], list[str], str]:
        """(status, body, files, summary) for one lookup read; raises core.Refused."""
        if action == "func":
            return self._funcs([tuple(p) for p in (pairs or [])] or [(path, name)])
        if action in ("lines", "doc") or (action in ("names", "all_names") and path.endswith(".py")):
            return "PASS", mcp_read.read(self.root, action, path, start, end, whole), [], ""
        why = next((w for w in (core.denied(x) for x in (path.split() + [expand])) if w), "")
        if why:
            raise core.Refused(why)
        argv, cmd = self._lookup_argv(action, path, name, pattern, door, job, query, regex, expand)
        if not argv:
            raise core.Refused(cmd)
        res = self._run(argv, cmd)
        if res["status"] == "DENIED":
            raise core.Refused(res["text"])
        body = core.clean(self._strip(res["text"]), banners=action != "packet")
        if action == "packet":
            body = core.clean([ln for ln in body if not ln.startswith("# Session context (generated") and not ln.endswith(": (none)")])
        status = "FAIL" if res["status"] == "FAIL" else "PASS"
        return status, body or [res["result"]], sorted(set(PATH_RE.findall(res["text"]))), ""

    def _batch(self, reads: list, budget: int, whole: bool) -> str:
        """Several independent reads (any lookup action but more/full/batch) answered in one reply, in order."""
        if not reads or not all(isinstance(r, dict) and r.get("action") for r in reads):
            return self._refuse("batch needs reads=[{action, ...}, ...] (each a lookup call's arguments)")
        body: list[str] = []
        files: set[str] = set()
        fails = 0
        for i, r in enumerate(reads, 1):
            kw = {k: v for k, v in r.items() if k in BATCH_KEYS}
            act = str(r["action"])
            label = f"## [{i}] {act} " + " ".join(str(r[k]) for k in ("path", "name", "pattern", "query") if r.get(k))
            try:
                if act in ("more", "full", "batch"):
                    raise core.Refused(f"{act} is not a batch read")
                status, lines, fl, summary = self._one(act, whole or bool(r.get("all")), **kw)
            except core.Refused as exc:
                status, lines, fl, summary = "FAIL", [f"error: {exc}"], [], ""
            fails += status == "FAIL"
            files.update(fl)
            head = [] if lines and lines[0].startswith("## ") and act in ("func", "lines", "doc") else [label.rstrip()]
            body += ([""] if body else []) + head + ([f"summary: {summary}"] if summary else []) + lines
        status = "FAIL" if fails else "PASS"
        h = self.store.new("b", body, status=status, files=sorted(files))
        return core.page(self.store, h, budget, status, f"{fails} of {len(reads)} reads failed" if fails else "", first=True,
                         fails=fails)

    def _lookup_argv(self, action, path, name, pattern, door, job, query, regex, expand) -> tuple[list[str], str]:
        if action == "xref":
            if not pattern:
                return [], "xref needs pattern"
            argv = ["find.py", "xref", "--pattern", pattern] + (["--path", path] if path else []) + (["--regex"] if regex else [])
            return argv + (["--expand", expand] if expand else []), "find.py xref"
        if action in ("names", "all_names"):  # every declared function, in source order (the CLI's --names keeps the biggest few)
            return (["find.py", "scripts", "--all-names", "--path", path], "find.py scripts") if path else ([], "names needs path")
        simple = {
            "route": (["find.py", "route"] + (["--job", job] if job else []) + (["--door", door] if door and not job else []), "find.py route"),
            "scenes": (["find.py", "scenes", "--path", path], "find.py scenes"),
            "facade": (["find.py", "facade", path], "find.py facade"),
            "stat": (["find.py", "stat", path], "find.py stat"),
            "changed": (["find.py", "changed"] + (["--since", query] if query else []) + (["--history", *path.split()] if path else []), "find.py changed"),
            "code_map": (["docs.py", "code-map", "row", "--path", path], "docs.py code-map"),
            "task": (["docs.py", "task", "show", query or name], "docs.py task"),
            "summary": (["session.py", "summary", query or name] + (["--match", pattern] if pattern else []), "session.py summary"),
            "packet": (["slice.py", "expand"] + (["--only", query] if query else []), "slice.py expand"),
        }
        if action not in simple:
            return [], f"unknown lookup action {action!r} (func xref names lines doc route scenes facade stat changed code_map task summary packet batch more full)"
        return simple[action]

    def _funcs(self, items: list[tuple]) -> tuple[str, list[str], list[str], str]:
        body: list[str] = []
        status, fails = "PASS", 0
        for rel, nm in items:
            why = core.denied(rel)
            if why:
                raise core.Refused(why)
            res = self._run(["find.py", "func", rel, nm, "--full"], "find.py func")
            if res["status"] == "DENIED":
                raise core.Refused(res["text"])
            lines = self._strip(res["text"])
            m = core.LINES_RE.search(res["text"])
            if res["status"] != "PASS" or not m:
                status, fails = "FAIL", fails + 1
                body += [f"## {rel}:{nm}"] + [ln for ln in core.clean(lines[-2:], banners=True) if ln]
                continue
            a, b = int(m.group(1)), int(m.group(2))
            src = lines[lines.index(m.group(0)) + 3:] if m.group(0) in lines else []
            body += [f"## {rel}:{nm} L{a}-{b}"] + src
        return status, body, [], f"{fails} of {len(items)} not found" if fails and len(items) > 1 else ""

    def _read(self, action: str, path: str, budget: int) -> str:
        try:
            body = mcp_read.read(self.root, action, path, 0, 0, False)
        except core.Refused as exc:
            return self._refuse(str(exc))
        return core.page(self.store, self.store.new("r", body), budget, "PASS", first=True)

    # check
    def check(self, target: str = "", handle: str = "", action: str = "", stem: str = "", files: list | None = None,
              budget: int = 0, whole: bool = False) -> str:
        self.store.tick()
        if handle:
            return self._follow(handle, action or "failures", core.ALL if whole else budget)
        if target not in CHECKS:
            return self._refuse(f"unknown check target {target!r} (choose: {', '.join(CHECKS)}); prove, selftests and docs-size are Bot-only")
        cmd, build = CHECKS[target]
        key = " ".join([target, stem, *sorted(files or [])]).strip()
        runs = self.store.check_runs().get(key, [])
        if self.rerun_limit and len(runs) >= MAX_CHECK_RUNS:
            return core.fail(f"{key} already ran {len(runs)} times (tools.md rule 10): not re-run; read handle={runs[-1]}, then stop and report")
        res = self._run(build({"stem": stem, "files": files or []}), cmd)
        if res["status"] == "DENIED":
            return self._refuse(res["text"])
        lines = core.clean(self._strip(res["text"]))
        failures = [ln for ln in lines if FAIL_RE.search(ln)] if res["status"] == "FAIL" else []
        status = "FAIL" if res["status"] == "FAIL" else "PASS"
        h = self.store.new("c", lines, status=status, failures=failures, files=sorted(set(PATH_RE.findall(res["text"]))))
        self.store.add_check_run(key, h)
        summary = core.SUMMARY_RE.sub("", re.sub(r"^RESULT \w+ ?", "", res["result"])).strip() or (failures[0] if failures else "")
        if whole:
            return core.page(self.store, h, core.ALL, status, summary[:200], first=True)
        nxt = "failures | full | files" if status == "FAIL" else "full | files"
        return "\n".join(core.header(status, f"summary: {summary[:200]}" if summary else "", f"handle: {h} ({nxt})",
                                     fails=len(failures) or 1))

    # protocol
    def protocol(self, action: str = "now", situation: str = "", query: str = "", handle: str = "", budget: int = 0,
                 whole: bool = False) -> str:
        self.store.tick()
        budget = core.ALL if whole else budget
        if handle:
            return self._follow(handle, action or "more", budget)
        data = json.loads((self.root / "tools/data/mcp_protocol.json").read_text(encoding="utf-8"))
        if action == "doc":
            ref = data["situations"].get(situation)
            if not ref:
                return self._refuse(f"unknown situation {situation!r} (choose: {', '.join(data['situations'])})")
            return self._read("doc", ref, budget)
        if action == "packet":
            return self.lookup("packet", query=query, budget=budget)
        if action == "suggest":
            return self._suggest(query, budget)
        if action == "list":
            h = self.store.new("p", [f"{k}: {v}" for k, v in data["situations"].items()])
            return core.page(self.store, h, budget, "PASS", first=True)
        phase, ident = current_phase(self.root)
        rows = [f"slice: {ident}", f"phase: {phase}", "next actions:"] + [f"- {a}" for a in data["phases"].get(phase, [])]
        h = self.store.new("p", rows)
        return core.page(self.store, h, budget, "PASS", first=True)

    def _suggest(self, query: str, budget: int) -> str:
        words = {w for w in re.findall(r"[a-z]{3,}", query.lower())}
        rows = []
        for line in (self.root / "design/tools.md").read_text(encoding="utf-8-sig").splitlines():
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) == 3 and cells[0] not in ("Job", "---"):
                score = len(words & set(re.findall(r"[a-z]{3,}", cells[0].lower())))
                if score:
                    rows.append((score, f"{cells[0]}: {cells[1]} ({cells[2]})"))
        rows.sort(key=lambda r: -r[0])
        h = self.store.new("p", [r for _, r in rows[:3]] or ["(no match; protocol action=doc situation=pick-a-tool)"])
        return core.page(self.store, h, budget, "PASS", first=True)

def current_phase(root: Path) -> tuple[str, str]:
    """Best guess from slice state and the session-plan kept half: understand, implement, verify."""
    ident = "(no slice state)"
    try:
        st = json.loads((root / "_logs/slice-state.json").read_text(encoding="utf-8"))
        ident = " ".join(f"{k}={st[k]}" for k in ("door", "job", "task") if st.get(k)) or ident
    except (OSError, ValueError):
        pass
    try:
        plan = (root / "session-plan.md").read_text(encoding="utf-8-sig").split("<!-- gathered -->", 1)[0]
    except OSError:
        return "understand", ident
    outcome = re.search(r"## Outcome\s+(.*?)\n##", plan, re.S)
    changed = re.search(r"## Changed files\s+(.*?)\n##", plan, re.S)
    if not outcome or outcome.group(1).strip().startswith("(one line"):
        return "understand", ident
    if changed and "none yet" not in changed.group(1):
        return "verify", ident
    return "implement", ident
