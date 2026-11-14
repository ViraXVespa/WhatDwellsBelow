"""The three wdb MCP tools, as plain functions over mcp_core.Store: lookup, check, protocol. No CLI of its own.

Thin wrappers: each first call runs the real `find.py` / `docs.py` / `session.py` / `slice.py expand` /
`check.py` / `gate.py gd-load` command once and caches its full result under a handle; follow-ups page or filter that
cache (`more` sends only the rest) and never re-run it. Commands outside the caller's catalog surface (Surf column, `design/tools*.md`) are refused.
Read-only: nothing here writes repo files (state lives in `_logs/gather/`).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import mcp_core as core

PATH_RE = re.compile(r"(?<![\w/.-])((?:scripts|scenes|tools|design|assets|_out)/[\w./-]+\.\w+)")
FAIL_RE = re.compile(r"\b(FAIL|ERROR|DRIFT|STALE|MISSING|UNMAPPED|SCRIPT ERROR)\b|^error:", re.M)
MAX_CHECK_RUNS = 3  # one run + 2 reruns per target and args (tools.md rule 10); the store keeps the count for the worktree
CHECKS = {  # target -> (catalog command, argv builder)
    "tool_cli": ("check.py tool-cli", lambda a: ["check.py", "tool-cli"] + (["--only", a["stem"]] if a.get("stem") else [])),
    "tool_docs": ("check.py tool-docs", lambda a: ["check.py", "tool-docs"]),
    "script_cap": ("check.py script-cap", lambda a: ["check.py", "script-cap"] + sum((["--path", p] for p in a.get("files", [])), [])),
    "load_graph": ("check.py load-graph", lambda a: ["check.py", "load-graph"]),
    "gd_load": ("gate.py gd-load", lambda a: ["gate.py", "gd-load"] + (["--files", *a["files"]] if a.get("files") else [])),
}

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
    def __init__(self, root: Path, surface: str = "D", persist: bool = True, state: Path | None = None):
        self.root, self.surface = root, surface
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
        return "\n".join(core.header("FAIL", "-", "fix the call", summary=why, fails=1))

    @staticmethod
    def _strip(text: str) -> list[str]:
        return [ln for ln in text.splitlines() if not ln.startswith("RESULT ")]

    def _follow(self, handle: str, action: str, budget: int) -> str:
        rec = self.store.get(handle)
        if rec is None:
            return "\n".join(core.header("FAIL", handle, "rerun the original call", summary="expired or unknown handle", fails=1))
        if action in ("failures", "files"):
            rows = rec.get(action) or []
            h = self.store.new("v", rows or [f"(no {action})"], status=rec.get("status", "PASS"))
            return core.page(self.store, h, budget, rec.get("status", "PASS"), first=True)
        if action == "full":
            rec["pos"] = 0
            return core.page(self.store, handle, budget or 10_000, rec.get("status", "PASS"), first=True)
        return core.page(self.store, handle, budget, rec.get("status", "PASS"))

    # lookup
    def lookup(self, action: str, handle: str = "", path: str = "", name: str = "", pattern: str = "",
               pairs: list | None = None, start: int = 0, end: int = 0, door: str = "", job: str = "",
               query: str = "", regex: bool = False, expand: str = "", budget: int = 0) -> str:
        self.store.tick()
        if handle or action in ("more", "full"):
            return self._follow(handle, action or "more", budget)
        if action == "func":
            items = [tuple(p) for p in (pairs or [])] or [(path, name)]
            return self._funcs(items, budget)
        if action in ("lines", "doc"):
            return self._read(action, path, start, end, budget)
        why = next((w for w in (core.denied(x) for x in (path.split() + [expand])) if w), "")
        if why:
            return self._refuse(why)
        argv, cmd = self._lookup_argv(action, path, name, pattern, door, job, query, regex, expand)
        if not argv:
            return self._refuse(cmd)
        res = self._run(argv, cmd)
        if res["status"] == "DENIED":
            return self._refuse(res["text"])
        body = self._strip(res["text"])
        status = "FAIL" if res["status"] == "FAIL" else "PASS"
        h = self.store.new("l", body, status=status, files=sorted(set(PATH_RE.findall(res["text"]))))
        return core.page(self.store, h, budget, status, "" if status == "PASS" else (body[-1] if body else res["result"]), first=True)

    def _lookup_argv(self, action, path, name, pattern, door, job, query, regex, expand) -> tuple[list[str], str]:
        if action == "xref":
            if not pattern:
                return [], "xref needs pattern"
            argv = ["find.py", "xref", "--pattern", pattern] + (["--path", path] if path else []) + (["--regex"] if regex else [])
            return argv + (["--expand", expand] if expand else []), "find.py xref"
        if action in ("names", "all_names"):
            return (["find.py", "scripts", "--" + action.replace("_", "-"), "--path", path], "find.py scripts") if path else ([], "names needs path")
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
            return [], f"unknown lookup action {action!r} (func xref names all_names lines doc route scenes facade stat changed code_map task summary packet more full)"
        return simple[action]

    def _funcs(self, items: list[tuple], budget: int) -> str:
        body: list[str] = []
        status, fails = "PASS", 0
        for rel, nm in items:
            why = core.denied(rel)
            if why:
                return self._refuse(why)
            res = self._run(["find.py", "func", rel, nm, "--full"], "find.py func")
            if res["status"] == "DENIED":
                return self._refuse(res["text"])
            lines = self._strip(res["text"])
            m = core.LINES_RE.search(res["text"])
            if res["status"] != "PASS" or not m:
                status, fails = "FAIL", fails + 1
                note = [f"## {rel}:{nm} not found"] + lines[-2:]
                body += note
                continue
            a, b = int(m.group(1)), int(m.group(2))
            src = lines[lines.index(m.group(0)) + 3:] if m.group(0) in lines else []
            body += [f"## {rel}:{nm} L{a}-{b}"] + src
        h = self.store.new("f", body, status=status)
        return core.page(self.store, h, budget, status, f"{fails} of {len(items)} not found" if fails else "", first=True)

    def _read(self, action: str, path: str, start: int, end: int, budget: int) -> str:
        rel, _, heading = path.partition("#")
        why = core.denied(rel)
        if why:
            return self._refuse(why)
        src = self.root / rel
        if not src.resolve().is_relative_to(self.root.resolve()):
            return self._refuse("path leaves the repo")
        if not src.is_file():
            return self._refuse(f"{rel} is not a file under the repo root")
        lines = src.read_text(encoding="utf-8-sig", errors="replace").splitlines()
        if action == "doc":
            span = heading_span(lines, heading)
            if span is None:
                heads = [ln for ln in lines if ln.startswith("#")][:20]
                return self._refuse(f"no heading {heading!r} in {rel}; headings: " + " | ".join(h.lstrip('# ') for h in heads))
            a, b = span
        else:
            a, b = max(1, start or 1), min(len(lines), end or len(lines))
        h = self.store.new("r", [f"## {path} L{a}-{b} of {len(lines)}"] + lines[a - 1:b])
        return core.page(self.store, h, budget, "PASS", first=True)

    # check
    def check(self, target: str = "", handle: str = "", action: str = "", stem: str = "", files: list | None = None, budget: int = 0) -> str:
        self.store.tick()
        if handle:
            return self._follow(handle, action or "failures", budget)
        if target not in CHECKS:
            return self._refuse(f"unknown check target {target!r} (choose: {', '.join(CHECKS)}); prove, selftests and docs-size are Bot-only")
        cmd, build = CHECKS[target]
        key = " ".join([target, stem, *sorted(files or [])]).strip()
        runs = self.store.check_runs().get(key, [])
        if len(runs) >= MAX_CHECK_RUNS:
            return "\n".join(core.header("FAIL", runs[-1], "read the last handle (failures | full | files); stop and report",
                                          summary=f"{key} already ran {len(runs)} times (a run + {MAX_CHECK_RUNS - 1} reruns, tools.md rule 10); not re-run", fails=1))
        res = self._run(build({"stem": stem, "files": files or []}), cmd)
        if res["status"] == "DENIED":
            return self._refuse(res["text"])
        lines = self._strip(res["text"])
        failures = [ln for ln in lines if FAIL_RE.search(ln)] if res["status"] == "FAIL" else []
        status = "FAIL" if res["status"] == "FAIL" else "PASS"
        h = self.store.new("c", lines, status=status, failures=failures, files=sorted(set(PATH_RE.findall(res["text"]))))
        self.store.add_check_run(key, h)
        summary = res["result"] or (failures[0] if failures else "")
        return "\n".join(core.header(status, h, "failures | full | files" if status == "FAIL" else "full | files",
                                     summary=summary[:200], fails=len(failures) or 1))

    # protocol
    def protocol(self, action: str = "now", situation: str = "", query: str = "", handle: str = "", budget: int = 0) -> str:
        self.store.tick()
        if handle:
            return self._follow(handle, action or "more", budget)
        data = json.loads((self.root / "tools/data/mcp_protocol.json").read_text(encoding="utf-8"))
        if action == "doc":
            ref = data["situations"].get(situation)
            if not ref:
                return self._refuse(f"unknown situation {situation!r} (choose: {', '.join(data['situations'])})")
            return self._read("doc", ref, 0, 0, budget)
        if action == "packet":
            return self.lookup("packet", query=query, budget=budget)
        if action == "suggest":
            return self._suggest(query, budget)
        if action == "list":
            h = self.store.new("p", [f"{k}: {v}" for k, v in data["situations"].items()])
            return core.page(self.store, h, budget, "PASS", first=True)
        phase, ident = current_phase(self.root)
        rows = [f"slice: {ident}", f"phase: {phase}", "next actions:"] + [f"- {a}" for a in data["phases"].get(phase, [])]
        rows.append("situations: " + ", ".join(data["situations"]))
        h = self.store.new("p", rows)
        return core.page(self.store, h, budget, "PASS", f"phase={phase}", first=True)

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

def heading_span(lines: list[str], heading: str) -> tuple[int, int] | None:
    """1-based [a, b] of a markdown heading's section (up to the next heading of the same or higher level)."""
    want = heading.strip().lower()
    for i, ln in enumerate(lines):
        m = re.match(r"^(#+)\s+(.*)$", ln)
        if m and m.group(2).strip().lower() == want:
            lvl = len(m.group(1))
            for j in range(i + 1, len(lines)):
                n = re.match(r"^(#+)\s", lines[j])
                if n and len(n.group(1)) <= lvl:
                    return i + 1, j
            return i + 1, len(lines)
    return None

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
