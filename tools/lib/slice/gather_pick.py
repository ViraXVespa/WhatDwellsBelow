#!/usr/bin/env python3
"""Local-model pick of edit funcs. `slice.py open` runs `--chain` after start.

    python tools/slice.py gather-pick [--task ID] [--model NAME] [--chain] [--dry-run]
Names-only mode offers at most 8 scripts (task, job doc, door code-map stems). `--chain` offers the
whole door code-map, paged, with no file cap. Fresh sessions share the session plan and each has its
own instructions in `tools/data/gather/skills/` (scout, mark, follow, gap, trim, review). The conductor
writes `slice.py adjust` between sessions. A runaway guard stops a chain that does not finish and
keeps marks when a core func remains. Tools stay off. Invalid JSON on scout or mark is repaired once,
then the mechanical seed stays. Follow, gap, trim, and review keep the marks when their reply is not JSON.
A pick that passes the check sets `gather: agent`. No Approach. `--selftest` uses a stub model.
Open still launches when the chain misses: the packet stays the mechanical seed.
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import gd_lib
import md_format_lib as md
import plan_adjust
import plan_expand
import session_plan

MODEL = "qwen3-coder:30b"
CAP = 8  # names-only table; --chain does not use this
PAGE = 12  # one scout or gap page; the chain walks every page
FILE_CHARS = 16000  # one mark session; a larger file is split on function boundaries
MAX_READS = 200  # runaway guard, not a cap on a finished chain
MAX_SESSIONS = 400
TIMEOUT = 480  # one completion; a chain is several of these
ROLES = ("scout", "mark", "follow", "gap", "trim", "review")
PATH_RE = re.compile(r"(?<![\w./-])((?:[\w.-]+/)*[\w.-]+\.(?:gd|tscn))")
WORD_RE = re.compile(r"[A-Za-z][A-Za-z0-9_]{2,}")
SCENE_SCRIPT_RE = re.compile(r'path="res://([^"]+\.gd)"')
CALL_RE = re.compile(r"(?<!\w)([A-Za-z_][A-Za-z0-9_]*)\s*\(")
WHY = "picker: edit owner"
_SKILLS: dict[str, str] = {}
MEMORY = (
    "The session plan is your only memory. If you compact, re-read that plan and continue this same job. "
    "Do not implement the change. The conductor writes the plan from your JSON."
)


class ModelError(RuntimeError):
    """Ollama did not return a completion. The plan is left untouched."""


@dataclass
class Script:
    path: str
    funcs: list[str]
    rank: int


@dataclass
class Report:
    route: str
    body: str
    accepted: int = 0
    scripts: int = 0
    repair: int = 0
    dropped: int = 0
    sessions: int = 0


def _words(text: str) -> set[str]:
    return {w.lower() for w in WORD_RE.findall(text or "")}


def _task_body(text: str) -> str:
    return re.split(r"\n## Next Steps\b", text or "", maxsplit=1)[0].strip()


def _funcs(root: Path, rel: str) -> list[str]:
    path = root / rel
    if not path.is_file():
        return []
    try:
        text = md.read_text(path)
    except (OSError, UnicodeError):
        return []
    return [name for name, *_rest in gd_lib.funcs_of(text)]


def _scene_script(root: Path, rel: str) -> str:
    path = root / rel
    if not path.is_file():
        return ""
    try:
        text = md.read_text(path)
    except (OSError, UnicodeError):
        return ""
    match = SCENE_SCRIPT_RE.search(text)
    if not match:
        return ""
    script = match.group(1).replace("\\", "/")
    return script if (root / script).is_file() else ""


def _as_script(root: Path, token: str, rows: list, prefer: list) -> str:
    token = token.strip().replace("\\", "/")
    if token.endswith(".tscn"):
        rel = token if (root / token).is_file() else ""
        if not rel:
            base = Path(token).name
            for row in prefer or rows:
                for item in row.listed:
                    if item == base or item.endswith("/" + base):
                        if (root / item).is_file():
                            rel = item
                            break
        return _scene_script(root, rel) if rel else ""
    if token.endswith(".gd"):
        if (root / token).is_file():
            return token
        return session_plan._resolve(root, token, rows, prefer)
    return ""


def _offer(found: dict[str, Script], root: Path, rel: str, rank: int) -> None:
    names = _funcs(root, rel)
    if not names:
        return
    old = found.get(rel)
    if old is None or rank < old.rank:
        found[rel] = Script(rel, names, rank)


def _skill(name: str) -> str:
    """Role instructions. A missing file fails loudly; the chain does not invent a prompt."""
    if name in _SKILLS:
        return _SKILLS[name]
    path = Path(__file__).resolve().parents[2] / "data" / "gather" / "skills" / f"{name}.md"
    if not path.is_file():
        agent_log.fail(f"missing gather skill {path.as_posix()}")
    _SKILLS[name] = md.read_text(path).strip()
    return _SKILLS[name]


def _collect(root: Path, door: str, job: str, task: str) -> tuple[list[Script], str]:
    """Every offered script, best rank first. Rank 4 is the rest of the door code-map row."""
    door, job = session_plan._door_job(door, job)
    _door_file, job_file, _door_text = session_plan._docs(root, door, job)
    job_text = session_plan._read(root, job_file) if job_file else ""
    task_text = ""
    if task and (root / "design" / "tasks" / f"{task}.md").is_file():
        task_text = _task_body(session_plan._read(root, f"design/tasks/{task}.md"))
    rows = session_plan._rows(root)
    prefer = [r for r in (session_plan.cm.find_system(rows, n) for n in session_plan._needles(door, job)) if r is not None] if rows else []
    found: dict[str, Script] = {}

    def take(tokens: list[str], rank: int) -> None:
        for token in tokens:
            rel = _as_script(root, token, rows, prefer or rows)
            if rel:
                _offer(found, root, rel, rank)

    take(PATH_RE.findall(task_text), 0)
    take(PATH_RE.findall(job_text), 2)
    task_words, job_words = _words(task_text), _words(job_text)

    def stems(words: set[str], rank: int) -> None:
        for word in words:
            scene = f"scenes/{word}.tscn"
            if (root / scene).is_file():
                rel = _scene_script(root, scene)
                if rel:
                    _offer(found, root, rel, rank)
        for row in prefer:
            for item in row.listed:
                if not str(item).endswith(".gd"):
                    continue
                rel = item if (root / item).is_file() else session_plan._resolve(root, item, rows, prefer)
                if rel and Path(rel).stem.lower() in words:
                    _offer(found, root, rel, rank)

    stems(task_words, 1)
    stems(job_words, 3)
    for row in prefer:
        for rel in session_plan.cm.listed_file_paths([row]):
            if rel.endswith(".gd"):
                _offer(found, root, rel, 4)
    ordered = sorted(found.values(), key=lambda s: (s.rank, s.path))
    return ordered, task_text


def table(root: Path, door: str, job: str, task: str) -> tuple[list[Script], str]:
    """Names-only offer: ranks 0-3, at most CAP scripts."""
    ordered, task_text = _collect(root, door, job, task)
    return [script for script in ordered if script.rank < 4][:CAP], task_text


def catalog(root: Path, door: str, job: str, task: str) -> tuple[list[Script], str]:
    """Chain offer: the names-only table plus the rest of the door's code-map scripts."""
    return _collect(root, door, job, task)


def _prompt(task_text: str, scripts: list[Script]) -> list[dict[str, str]]:
    lines = []
    for script in scripts:
        lines.append(f"- {script.path}: {', '.join(script.funcs)}")
    system = (
        "You choose functions whose bodies must be edited. "
        'Reply with one JSON object and nothing else: {"edit":[{"path":"scripts/a.gd","func":"name"}]}. '
        "Copy every path and func from the list. Omit a script that is only a neighbor."
    )
    user = "Task:\n" + (task_text or "(no task text)") + "\n\nFunctions:\n" + "\n".join(lines)
    return [{"role": "system", "content": system}, {"role": "user", "content": user}]


def _load_json(raw: str) -> dict | None:
    text = (raw or "").strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-zA-Z]*\n?", "", text)
        text = re.sub(r"\n?```$", "", text).strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start < 0 or end <= start:
            return None
        try:
            data = json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            return None
    return data if isinstance(data, dict) else None


def _clean_path(item: str) -> str:
    path = item.strip().strip("`").strip('"').strip("'").replace("\\", "/")
    return path[6:] if path.startswith("res://") else path


def _why_of(why: str) -> str:
    text = " ".join((why or "").split())
    return (text[:160].rstrip() or WHY)


def parse_edit(raw: str) -> list[tuple[str, str, str]] | None:
    """(path, func, why) from a JSON object, or None when the reply is not that object."""
    data = _load_json(raw)
    if data is None or not isinstance(data.get("edit"), list):
        return None
    out: list[tuple[str, str, str]] = []
    for row in data["edit"]:
        if not isinstance(row, dict):
            return None
        path = _clean_path(str(row.get("path") or ""))
        func = str(row.get("func") or "").strip()
        if not path or not func:
            return None
        out.append((path, func, _why_of(str(row.get("why") or ""))))
    return out


def _string_list(data: dict | None, key: str) -> list[str] | None:
    """Strings under key, or None when the reply is not that object. An empty list is valid."""
    if data is None or not isinstance(data.get(key), list):
        return None
    out: list[str] = []
    for item in data[key]:
        if not isinstance(item, str) or not item.strip():
            return None
        out.append(_clean_path(item))
    return out


def _ollama_post(body: dict) -> dict:
    req = urllib.request.Request(
        "http://127.0.0.1:11434/api/chat",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def ollama_complete(messages: list[dict[str, str]], model: str) -> str:
    """One /api/chat completion. think=false so the reply is the JSON, not a trace.

    A model that rejects the think field is retried once without it.
    """
    body = {
        "model": model,
        "messages": messages,
        "stream": False,
        "format": "json",
        "think": False,
        "options": {"temperature": 0, "num_predict": 2048},
    }
    try:
        try:
            payload = _ollama_post(body)
        except urllib.error.HTTPError as exc:
            if exc.code != 400:
                raise
            body.pop("think", None)
            payload = _ollama_post(body)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
        raise ModelError(str(exc)) from exc
    message = payload.get("message") or {}
    content = str(message.get("content") or message.get("thinking") or "").strip()
    if content:
        return content
    raise ModelError("ollama returned an empty completion")


def _accept(scripts: list[Script], pairs: list[tuple[str, str, str]]) -> tuple[list[tuple[str, str, str]], int]:
    allowed = {script.path: set(script.funcs) for script in scripts}
    kept: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str]] = set()
    dropped = 0
    for path, func, why in pairs:
        if (path, func) in seen:
            continue
        seen.add((path, func))
        if func in allowed.get(path, ()):
            kept.append((path, func, why))
        else:
            dropped += 1
    return kept, dropped


def _restore(root: Path, plan_text: str, delta_text: str | None) -> None:
    md.write_text(root / plan_adjust.PLAN, plan_text)
    delta = plan_adjust.delta_path(root)
    if delta_text is None:
        if delta.is_file():
            delta.unlink()
    else:
        delta.parent.mkdir(parents=True, exist_ok=True)
        delta.write_text(delta_text, encoding="utf-8")


def _ops(root: Path, ops: list[list[str]]) -> tuple[list[str], list[str]]:
    """Run adjust ops. Never sets gather: agent, even when the shell has WDB_ROLE=gather."""
    role = os.environ.pop("WDB_ROLE", None)
    try:
        return plan_adjust.run_ops(root, ops, False)
    finally:
        if role is not None:
            os.environ["WDB_ROLE"] = role


def _apply(root: Path, pairs: list[tuple[str, str, str]]) -> list[str]:
    """Add the funcs and drop seed-when candidates. Returns expand errors (plan restored on any)."""
    import gather_agent

    plan = root / plan_adjust.PLAN
    before = md.read_text(plan)
    delta = plan_adjust.delta_path(root)
    delta_before = delta.read_text(encoding="utf-8") if delta.is_file() else None
    ops = [["add-func", path, func, "--why", why] for path, func, why in pairs]
    for kid in gather_agent.seed_candidate_ids(before):
        ops.append(["rem", kid])
    _done, errs = _ops(root, ops)
    if errs:
        _restore(root, before, delta_before)
        return errs
    text = md.read_text(plan)
    if not gather_agent.core_has_func(text):
        _restore(root, before, delta_before)
        return ["core has no func after the pick"]
    if "gather: agent" in text:
        _restore(root, before, delta_before)
        return ["picker must leave gather: seed"]
    _kept, idx = plan_adjust.load(root)
    bad = plan_expand.check(root, idx)
    if bad:
        _restore(root, before, delta_before)
    return bad


def _seal(root: Path) -> None:
    """Set gather: agent only after a pick that already passed expand --check."""
    import plan_index as pi

    kept, idx = plan_adjust.load(root)
    idx.set("gather", "agent")
    md.write_text(root / plan_adjust.PLAN, pi.join_plan(kept, idx))


class _Live(list):
    """A line list that prints each append. Open's live printer is the say callback."""

    def __init__(self, say):
        super().__init__()
        self.say = say

    def append(self, item):
        super().append(item)
        if self.say is not None:
            self.say(str(item) + "\n")


def _index(root: Path) -> str:
    text = md.read_text(root / plan_adjust.PLAN)
    mark = "<!-- gathered -->"
    return text.split(mark, 1)[1].strip() if mark in text else text


def _ask(complete, messages: list[dict[str, str]], model: str) -> tuple[str, int]:
    raw = complete(messages, model)
    if _load_json(raw) is not None:
        return raw, 0
    again = [*messages, {"role": "assistant", "content": raw},
             {"role": "user", "content": "That reply was not a JSON object. Reply with only the JSON object."}]
    return complete(again, model), 1


def _file_chunks(root: Path, rel: str) -> list[str]:
    """Full source, or function-sized pieces when the file would fill the window."""
    text = md.read_text(root / rel)
    if len(text) <= FILE_CHARS:
        return [text]
    spans = gd_lib.funcs_of(text)
    if not spans:
        return [text[:FILE_CHARS]]
    lines = text.splitlines(True)
    chunks: list[str] = []
    buf: list[str] = []
    size = 0
    for name, start, end, _nbytes in spans:
        piece = f"func {name}\n" + "".join(lines[start - 1:end])
        if buf and size + len(piece) > FILE_CHARS:
            chunks.append("".join(buf))
            buf, size = [], 0
        buf.append(piece)
        size += len(piece)
    if buf:
        chunks.append("".join(buf))
    return chunks or [text[:FILE_CHARS]]


def _pages(items: list, size: int) -> list[list]:
    return [items[i:i + size] for i in range(0, len(items), size)]


def _role(role: str, body: str) -> list[dict[str, str]]:
    return [{"role": "system", "content": _skill(role) + "\n\n" + MEMORY},
            {"role": "user", "content": f"Role: {role}\n\n{body}"}]


def _list_scripts(scripts: list[Script]) -> str:
    return "\n".join(f"- {script.path}: {', '.join(script.funcs)}" for script in scripts)


def _scout_messages(task: str, page: list[Script], index: str, n: int, total: int) -> list[dict[str, str]]:
    body = (
        f"Page {n} of {total}.\n\n{MEMORY}\n\nTask:\n{task or '(no task text)'}\n\n"
        f"Session plan:\n{index}\n\nFunctions:\n{_list_scripts(page)}"
    )
    return _role("scout", body)


def _mark_messages(task: str, index: str, path: str, source: str) -> list[dict[str, str]]:
    body = f"File: {path}\n\n{MEMORY}\n\nTask:\n{task}\n\nSession plan:\n{index}\n\nSource:\n{source}"
    return _role("mark", body)


def _follow_messages(task: str, index: str, edges: list[tuple[str, str, str, str]]) -> list[dict[str, str]]:
    listed = "\n".join(f"- {owner}:{name} called from {src}:{func}" for owner, name, src, func in edges)
    body = f"{MEMORY}\n\nTask:\n{task}\n\nSession plan:\n{index}\n\nCalls:\n{listed}"
    return _role("follow", body)


def _gap_messages(task: str, index: str, page: list[Script], n: int, total: int, marked: list[tuple[str, str, str]]) -> list[dict[str, str]]:
    names = "\n".join(f"- {path}:{func}" for path, func, _why in marked) or "(none)"
    body = (
        f"Page {n} of {total}.\n\n{MEMORY}\n\nTask:\n{task}\n\nSession plan:\n{index}\n\n"
        f"Already marked:\n{names}\n\nUnread:\n{_list_scripts(page)}"
    )
    return _role("gap", body)


def _marked_source(root: Path, path: str, funcs: list[str]) -> str:
    """Bodies of the marked funcs, so a trim session does not re-read the rest of the file."""
    text = md.read_text(root / path)
    spans = {name: (start, end) for name, start, end, _nbytes in gd_lib.funcs_of(text)}
    lines = text.splitlines(True)
    parts: list[str] = []
    for func in funcs:
        if func not in spans:
            continue
        start, end = spans[func]
        parts.append(f"func {func}\n" + "".join(lines[start - 1:end]))
    return "".join(parts)[:FILE_CHARS]


def _trim_messages(task: str, index: str, path: str, source: str, funcs: list[str]) -> list[dict[str, str]]:
    body = (
        f"File: {path}\nMarked: {', '.join(funcs)}\n\n{MEMORY}\n\nTask:\n{task}\n\n"
        f"Session plan:\n{index}\n\nSource:\n{source}"
    )
    return _role("trim", body)


def _review_messages(task: str, index: str, marked: list[tuple[str, str, str]]) -> list[dict[str, str]]:
    by: dict[str, list[str]] = {}
    for path, func, _why in marked:
        by.setdefault(path, []).append(func)
    listed = "\n".join(f"- {path}: {', '.join(funcs)}" for path, funcs in by.items())
    body = f"{MEMORY}\n\nTask:\n{task}\n\nSession plan:\n{index}\n\nMarked files:\n{listed}"
    return _role("review", body)


def _noted(index: str, pairs: list[tuple[str, str, str]]) -> str:
    extra = "\n".join(f"- mark func `{path}:{func}` - {why}" for path, func, why in pairs)
    return index if not extra else index.rstrip() + "\n" + extra + "\n"


def _edges(root: Path, marked: list[tuple[str, str, str]], scripts: list[Script]) -> list[tuple[str, str, str, str]]:
    """(owner path, called func, caller path, caller func) for catalog funcs named from a marked body."""
    owners: dict[str, list[str]] = {}
    for script in scripts:
        for func in script.funcs:
            owners.setdefault(func, []).append(script.path)
    out: list[tuple[str, str, str, str]] = []
    seen: set[tuple[str, str, str, str]] = set()
    for path, func, _why in marked:
        text = md.read_text(root / path)
        spans = {name: (start, end) for name, start, end, _nbytes in gd_lib.funcs_of(text)}
        if func not in spans:
            continue
        start, end = spans[func]
        body = "\n".join(text.splitlines()[start - 1:end])
        for name in CALL_RE.findall(body):
            if name == func:
                continue
            for owner in owners.get(name, ()):
                if owner == path:
                    continue
                key = (owner, name, path, func)
                if key not in seen:
                    seen.add(key)
                    out.append(key)
    return out


def _drop_files(root: Path, marked: list[tuple[str, str, str]], drop_paths: list[str], dry: bool, lines: list[str]) -> list[tuple[str, str, str]]:
    """Drop whole neighbor files. A review that would clear the plan is ignored."""
    drop = {path for path in drop_paths if any(got == path for got, _func, _why in marked)}
    if not drop:
        return marked
    if not any(path not in drop for path, _func, _why in marked):
        lines.append("review kept every marked file")
        return marked
    for path in sorted(drop):
        lines.append(f"drop {path}")
    if dry:
        return [(path, func, why) for path, func, why in marked if path not in drop]
    _kept, idx = plan_adjust.load(root)
    ops: list[list[str]] = []
    for path, func, _why in marked:
        if path not in drop:
            continue
        item = idx.find(f"{path}:{func}")
        if item is not None:
            ops.append(["rem", item.id])
    if ops:
        _done, errs = _ops(root, ops)
        if errs:
            lines.append("review: " + "; ".join(errs))
            return marked
    return [(path, func, why) for path, func, why in marked if path not in drop]


class _ChainStop(Exception):
    """A scout or mark failure already restored the seed."""

    def __init__(self, report: Report):
        self.report = report


def chain(root: Path, door: str, job: str, task: str, model: str, complete, dry: bool, say=None) -> Report:
    """Scout pages, mark files, follow calls, fill gaps, then drop neighbors. Each call is a fresh session."""
    for role in ROLES:
        _skill(role)
    if not (root / plan_adjust.PLAN).is_file():
        agent_log.fail("no session-plan.md here; `python tools/slice.py open --review` writes the seed first")
    scripts, task_text = catalog(root, door, job, task)
    if not scripts:
        return Report("seed", "chain: no scripts to offer\nroute=seed")
    plan = root / plan_adjust.PLAN
    before = md.read_text(plan)
    delta = plan_adjust.delta_path(root)
    delta_before = delta.read_text(encoding="utf-8") if delta.is_file() else None
    allowed = {script.path for script in scripts}
    pages = _pages(scripts, PAGE)
    lines = _Live(say)
    lines.append(f"chain: scripts={len(scripts)} pages={len(pages)} model={model}")
    sessions = 0
    repair = 0
    dropped = 0
    state = {"guard": False}

    def fail_closed(why: str) -> Report:
        if md.read_text(plan) != before or (delta.is_file() and delta.read_text(encoding="utf-8") != (delta_before or "")):
            _restore(root, before, delta_before)
        lines.append("route=seed")
        lines.append(why)
        return Report("seed", "\n".join(lines) + "\n", scripts=len(scripts), repair=repair, dropped=dropped, sessions=sessions)

    def ask_list(messages: list[dict[str, str]], key: str) -> list[str] | None:
        nonlocal sessions, repair
        try:
            raw, n = _ask(complete, messages, model)
        except ModelError:
            _restore(root, before, delta_before)
            raise
        sessions += 1 + n
        repair += n
        return _string_list(_load_json(raw), key)

    def room() -> bool:
        if state["guard"]:
            return False
        if sessions >= MAX_SESSIONS or len(read_files) >= MAX_READS:
            lines.append(f"guard: stopped after {len(read_files)} file reads")
            state["guard"] = True
            return False
        return True

    read_files: set[str] = set()
    marked: list[tuple[str, str, str]] = []
    seen_funcs: set[tuple[str, str]] = set()

    def mark_file(path: str) -> bool:
        nonlocal dropped, sessions, repair
        if path in read_files:
            return True
        if not room():
            return False
        read_files.add(path)
        lines.append(f"read {path}")
        for source in _file_chunks(root, path):
            if sessions >= MAX_SESSIONS:
                lines.append(f"guard: stopped after {len(read_files)} file reads")
                state["guard"] = True
                return False
            index = _noted(_index(root), marked) if dry else _index(root)
            try:
                raw, n = _ask(complete, _mark_messages(task_text, index, path, source), model)
            except ModelError:
                _restore(root, before, delta_before)
                raise
            sessions += 1 + n
            repair += n
            pairs = parse_edit(raw)
            if pairs is None:
                raise _ChainStop(fail_closed(f"chain: mark {path} did not return JSON; the mechanical seed stays"))
            got, skip = _accept(scripts, pairs)
            dropped += skip
            fresh = [(p, f, w) for p, f, w in got if p == path and (p, f) not in seen_funcs]
            for pair in fresh:
                seen_funcs.add((pair[0], pair[1]))
                marked.append(pair)
                lines.append(f"mark {pair[0]}:{pair[1]}")
            if fresh and not dry:
                _done, errs = _ops(root, [["add-func", p, f, "--why", w] for p, f, w in fresh])
                if errs:
                    raise _ChainStop(fail_closed("chain: " + "; ".join(errs)))
        return True

    def take(paths: list[str], page: set[str] | None) -> list[str]:
        out: list[str] = []
        for path in paths:
            if page is not None and path not in page:
                continue
            if path in allowed and path not in read_files and path not in out:
                out.append(path)
        return out

    try:
        chosen: list[str] = []
        chosen_set: set[str] = set()
        for n, page in enumerate(pages, 1):
            if not room():
                break
            got = ask_list(_scout_messages(task_text, page, _index(root), n, len(pages)), "read")
            if got is None:
                raise _ChainStop(fail_closed(f"chain: scout page {n} did not return JSON; the mechanical seed stays"))
            page_set = {script.path for script in page}
            for path in got:
                if path in page_set and path not in chosen_set:
                    chosen_set.add(path)
                    chosen.append(path)
        if not chosen and not state["guard"]:
            raise _ChainStop(fail_closed("chain: no offered script was chosen; the mechanical seed stays"))
        rank = {script.path: (script.rank, script.path) for script in scripts}
        chosen.sort(key=lambda path: rank[path])
        for path in chosen:
            if not mark_file(path):
                break
        while room():
            new: list[str] = []
            edges = [edge for edge in _edges(root, marked, scripts) if edge[0] not in read_files]
            for n, page in enumerate(_pages(edges, PAGE), 1):
                if not room():
                    break
                got = ask_list(_follow_messages(task_text, _index(root) if not dry else _noted(_index(root), marked), page), "read")
                if got is None:
                    lines.append(f"follow page {n}: not JSON; kept the marks")
                    continue
                for path in take(got, None):
                    if path not in new:
                        new.append(path)
            unread = [script for script in scripts if script.path not in read_files]
            for n, page in enumerate(_pages(unread, PAGE), 1):
                if not room():
                    break
                index = _index(root) if not dry else _noted(_index(root), marked)
                got = ask_list(_gap_messages(task_text, index, page, n, len(_pages(unread, PAGE)), marked), "read")
                if got is None:
                    lines.append(f"gap page {n}: not JSON; kept the marks")
                    continue
                for path in take(got, {script.path for script in page}):
                    if path not in new:
                        new.append(path)
            if not new or state["guard"]:
                break
            added = False
            for path in new:
                if not mark_file(path):
                    break
                added = True
            if not added:
                break
        if marked:
            by_file: dict[str, list[str]] = {}
            for path, func, _why in marked:
                by_file.setdefault(path, []).append(func)
            for path, funcs in by_file.items():
                if not room():
                    lines.append("guard: trim skipped")
                    break
                index = _index(root) if not dry else _noted(_index(root), marked)
                got = ask_list(_trim_messages(task_text, index, path, _marked_source(root, path, funcs), funcs), "keep")
                if got is None:
                    lines.append(f"trim {path}: not JSON; kept its marks")
                    continue
                keep = set(got)
                nxt = [(p, f, w) for p, f, w in marked if p != path or f in keep]
                if not nxt:
                    lines.append(f"trim kept {path}")
                    continue
                gone = [(p, f, w) for p, f, w in marked if p == path and f not in keep]
                for _p, func, _w in gone:
                    lines.append(f"trim {path}:{func}")
                if gone and not dry:
                    _kept, idx = plan_adjust.load(root)
                    ops = []
                    for _p, func, _w in gone:
                        item = idx.find(f"{path}:{func}")
                        if item is not None:
                            ops.append(["rem", item.id])
                    if ops:
                        _done, errs = _ops(root, ops)
                        if errs:
                            lines.append("trim: " + "; ".join(errs))
                            continue
                marked = nxt
        if marked and room():
            index = _index(root) if not dry else _noted(_index(root), marked)
            got = ask_list(_review_messages(task_text, index, marked), "drop")
            if got is None:
                lines.append("review: not JSON; kept every marked file")
            else:
                marked = _drop_files(root, marked, got, dry, lines)
        elif marked and state["guard"]:
            lines.append("guard: review skipped")
    except _ChainStop as stop:
        return stop.report
    except Exception:
        if md.read_text(plan) != before or (delta.is_file() and delta.read_text(encoding="utf-8") != (delta_before or "")):
            _restore(root, before, delta_before)
        raise

    if not marked:
        return fail_closed("chain: no listed func remained; the mechanical seed stays")
    if dry:
        lines.append("route=dry")
        lines.append("dry-run: session-plan.md not written")
        return Report("dry", "\n".join(lines) + "\n", accepted=len(marked), scripts=len(scripts),
                      repair=repair, dropped=dropped, sessions=sessions)
    bad = _apply(root, marked)
    if bad:
        _restore(root, before, delta_before)
        lines.append("route=seed")
        lines.extend(f"check: {err}" for err in bad)
        lines.append("chain: check failed; the mechanical seed stays")
        return Report("seed", "\n".join(lines) + "\n", scripts=len(scripts), repair=repair, dropped=dropped, sessions=sessions)
    try:
        _seal(root)
    except OSError as exc:
        _restore(root, before, delta_before)
        lines.append("route=seed")
        lines.append(f"chain: could not mark gather: agent ({exc})")
        return Report("seed", "\n".join(lines) + "\n", scripts=len(scripts), repair=repair, dropped=dropped, sessions=sessions)
    lines.append("route=pick")
    return Report("pick", "\n".join(lines) + "\n", accepted=len(marked), scripts=len(scripts),
                  repair=repair, dropped=dropped, sessions=sessions)


def run(root: Path, door: str, job: str, task: str, model: str, complete, dry: bool) -> Report:
    """Pick and maybe write. complete(messages, model) -> str. Raises ModelError before any write."""
    if not (root / plan_adjust.PLAN).is_file():
        agent_log.fail("no session-plan.md here; `python tools/slice.py open --review` writes the seed first")
    scripts, task_text = table(root, door, job, task)
    if not scripts:
        return Report("seed", "picker: no scripts in the task, the job doc, or the door code-map row\nroute=seed", scripts=0)
    messages = _prompt(task_text, scripts)
    raw = complete(messages, model)
    repair = 0
    pairs = parse_edit(raw)
    if pairs is None:
        repair = 1
        messages = [*messages, {"role": "assistant", "content": raw},
                    {"role": "user", "content": "That reply was not a JSON object with an edit list. Reply with only that JSON object."}]
        raw = complete(messages, model)
        pairs = parse_edit(raw)
    lines = [f"picker: scripts={len(scripts)} model={model} repair={repair}"]
    for script in scripts:
        lines.append(f"offer {script.path} ({len(script.funcs)} funcs)")
    if pairs is None:
        lines.append("route=seed")
        lines.append("picker: the reply was not JSON; the mechanical seed stays")
        return Report("seed", "\n".join(lines) + "\n", scripts=len(scripts), repair=repair)
    kept, dropped = _accept(scripts, pairs)
    lines.append(f"dropped={dropped}")
    if not kept:
        lines.append("route=seed")
        lines.append("picker: no listed func was accepted; the mechanical seed stays")
        return Report("seed", "\n".join(lines) + "\n", scripts=len(scripts), repair=repair, dropped=dropped)
    for path, func, _why in kept:
        lines.append(f"accept {path}:{func}")
    if dry:
        lines.append("route=dry")
        lines.append("dry-run: session-plan.md not written")
        return Report("dry", "\n".join(lines) + "\n", accepted=len(kept), scripts=len(scripts), repair=repair, dropped=dropped)
    plan = root / plan_adjust.PLAN
    before = md.read_text(plan)
    delta = plan_adjust.delta_path(root)
    delta_before = delta.read_text(encoding="utf-8") if delta.is_file() else None
    bad = _apply(root, kept)
    if bad:
        lines.append("route=seed")
        lines.extend(f"check: {err}" for err in bad)
        lines.append("picker: check failed; the mechanical seed stays")
        return Report("seed", "\n".join(lines) + "\n", scripts=len(scripts), repair=repair, dropped=dropped)
    try:
        _seal(root)
    except OSError as exc:
        _restore(root, before, delta_before)
        lines.append("route=seed")
        lines.append(f"picker: could not mark gather: agent ({exc})")
        return Report("seed", "\n".join(lines) + "\n", scripts=len(scripts), repair=repair, dropped=dropped)
    lines.append("route=pick")
    return Report("pick", "\n".join(lines) + "\n", accepted=len(kept), scripts=len(scripts), repair=repair, dropped=dropped)


def _fixture(root: Path) -> None:
    (root / "design").mkdir(exist_ok=True)
    (root / "design" / "tasks").mkdir(exist_ok=True)
    (root / "scripts" / "ui").mkdir(parents=True)
    (root / "scenes").mkdir(exist_ok=True)
    (root / "design" / "routes.yaml").write_text(
        "version: 1\ndoors:\n  demo:\n    file: design/demo.md\n    read_when: \"x\"\n    jobs:\n      part: design/demo-part.md\n",
        encoding="utf-8")
    (root / "design" / "demo.md").write_text("# Demo\n\nDoor sentence.\n", encoding="utf-8")
    (root / "design" / "demo-part.md").write_text(
        "# Part\n\nThe menu is `scripts/title.gd`.\n", encoding="utf-8")
    (root / "design" / "code-map.md").write_text(
        "# Live code map\n\n| System | Live files |\n|--------|------------|\n"
        "| Demo | `scripts/ui/splash.gd`, `scripts/ui/noise.gd` |\n",
        encoding="utf-8")
    (root / "design" / "tasks" / "pick-task.md").write_text(
        "# Pick\n\nChange the splash so a click advances.\n\n## Next Steps (User Only)\n\ndo not follow\n",
        encoding="utf-8")
    (root / "scripts" / "ui" / "splash.gd").write_text(
        "extends Node\n\nfunc _ready() -> void:\n\tpass\n\nfunc _process(_d: float) -> void:\n\tpass\n\n"
        "func _unhandled_input(_e: InputEvent) -> void:\n\tpass\n\nfunc _advance() -> void:\n\tpass\n",
        encoding="utf-8")
    (root / "scripts" / "ui" / "noise.gd").write_text("extends Node\n\nfunc noise() -> void:\n\tpass\n", encoding="utf-8")
    (root / "scripts" / "title.gd").write_text("extends Node\n\nfunc _ready() -> void:\n\tpass\n\nfunc _play() -> void:\n\tpass\n", encoding="utf-8")
    (root / "scenes" / "splash.tscn").write_text(
        '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/ui/splash.gd" id="1"]\n',
        encoding="utf-8")


def selftest() -> int:
    import tempfile

    import gather_agent
    import repo_lib

    bad: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        root = repo_lib.selftest_repo(td, empty_commit=True)
        _fixture(root)
        session_plan.ensure(root, "demo", "demo.part", "demo", "implement", "pick-task", None)
        plan = root / "session-plan.md"
        before = md.read_text(plan)
        offered = table(root, "demo", "demo.part", "pick-task")[0]
        paths = [s.path for s in offered]
        if paths[:2] != ["scripts/ui/splash.gd", "scripts/title.gd"] or "scripts/ui/noise.gd" in paths:
            bad.append(f"table should be splash (task stem) then title (job path), not noise: {paths}")
        if "do not follow" in table(root, "demo", "demo.part", "pick-task")[1]:
            bad.append("the task prompt must drop Next Steps")

        def good(_messages: list[dict[str, str]], _model: str) -> str:
            return json.dumps({"edit": [
                {"path": "scripts/ui/splash.gd", "func": "_ready"},
                {"path": "scripts/ui/splash.gd", "func": "_process"},
                {"path": "scripts/ui/splash.gd", "func": "_unhandled_input"},
                {"path": "scripts/ui/splash.gd", "func": "_advance"},
                {"path": "scripts/nope.gd", "func": "nope"},
            ]})

        rep = run(root, "demo", "demo.part", "pick-task", "stub", good, False)
        text = md.read_text(plan)
        for name in ("_ready", "_process", "_unhandled_input", "_advance"):
            if f"func `scripts/ui/splash.gd:{name}`" not in text:
                bad.append(f"accepted func missing: {name}")
        if "func `scripts/title.gd" in text:
            bad.append("the pick must not add title.gd")
        if "gather: agent" not in text:
            bad.append("a successful pick marks gather: agent")
        if gather_agent.seed_candidate_ids(text):
            bad.append(f"seed-when candidates remain: {gather_agent.seed_candidate_ids(text)}")
        if rep.route != "pick" or rep.dropped != 1:
            bad.append(f"a listed pick should apply and drop the unknown pair: {rep.route} dropped={rep.dropped}")
        if plan_expand.check(root, plan_adjust.load(root)[1]):
            bad.append(f"expand check should pass: {plan_expand.check(root, plan_adjust.load(root)[1])}")

        md.write_text(plan, before)
        if plan_adjust.delta_path(root).is_file():
            plan_adjust.delta_path(root).unlink()
        calls = {"n": 0}

        def broken(_messages: list[dict[str, str]], _model: str) -> str:
            calls["n"] += 1
            return "not json"

        rep = run(root, "demo", "demo.part", "pick-task", "stub", broken, False)
        if md.read_text(plan) != before or calls["n"] != 2 or rep.route != "seed":
            bad.append(f"invalid JSON is repaired once and the seed stays ({calls['n']}, {rep.route})")

        def unknown(_messages: list[dict[str, str]], _model: str) -> str:
            return json.dumps({"edit": [{"path": "scripts/title.gd", "func": "missing"}]})

        rep = run(root, "demo", "demo.part", "pick-task", "stub", unknown, False)
        if md.read_text(plan) != before or rep.route != "seed":
            bad.append("a func that is not in the table must leave the seed")

        def one(_messages: list[dict[str, str]], _model: str) -> str:
            return '{"edit":[{"path":"scripts/ui/splash.gd","func":"_ready"}]}'

        rep = run(root, "demo", "demo.part", "pick-task", "stub", one, True)
        if md.read_text(plan) != before or rep.route != "dry" or "session-plan.md not written" not in rep.body:
            bad.append("dry-run must not write the plan")

        splash_edit = json.dumps({"edit": [
            {"path": "scripts/ui/splash.gd", "func": "_ready"},
            {"path": "scripts/ui/splash.gd", "func": "_process"},
            {"path": "scripts/ui/splash.gd", "func": "_unhandled_input"},
            {"path": "scripts/ui/splash.gd", "func": "_advance"},
        ]})

        def fresh() -> None:
            md.write_text(plan, before)
            if plan_adjust.delta_path(root).is_file():
                plan_adjust.delta_path(root).unlink()

        def chained(messages: list[dict[str, str]], _model: str) -> str:
            user = messages[-1]["content"]
            if user.startswith("Role: scout"):
                if "scripts/ui/splash.gd" in user:
                    return json.dumps({"read": ["scripts/ui/splash.gd", "scripts/title.gd"]})
                return json.dumps({"read": []})
            if user.startswith("Role: mark"):
                if "File: scripts/ui/splash.gd" in user:
                    return splash_edit
                if "File: scripts/title.gd" in user:
                    return json.dumps({"edit": [{"path": "scripts/title.gd", "func": "_ready"}]})
                return json.dumps({"edit": []})
            if user.startswith("Role: review"):
                return json.dumps({"drop": ["scripts/title.gd"]})
            if user.startswith("Role: trim"):
                if "File: scripts/ui/splash.gd" in user:
                    return json.dumps({"keep": ["_ready", "_process", "_unhandled_input", "_advance"]})
                return json.dumps({"keep": ["_ready"]})
            if user.startswith("Role: follow") or user.startswith("Role: gap"):
                return json.dumps({"read": []})
            return "not json"

        rep = chain(root, "demo", "demo.part", "pick-task", "stub", chained, False)
        text = md.read_text(plan)
        for name in ("_ready", "_process", "_unhandled_input", "_advance"):
            if f"func `scripts/ui/splash.gd:{name}`" not in text:
                bad.append(f"chain missed {name}")
        if "func `scripts/title.gd" in text or "gather: agent" not in text or rep.route != "pick" or "drop scripts/title.gd" not in rep.body:
            bad.append(f"chain should drop the neighbor file and mark gather: agent ({rep.route})")
        if rep.sessions < 4:
            bad.append(f"chain should scout, mark, check the gap, and review ({rep.sessions})")
        fresh()
        rep = chain(root, "demo", "demo.part", "pick-task", "stub", chained, True)
        if md.read_text(plan) != before or rep.route != "dry" or rep.accepted != 4:
            bad.append(f"chain dry-run must not write and must keep the splash marks ({rep.route}, accepted={rep.accepted})")

        def broken_choose(_messages: list[dict[str, str]], _model: str) -> str:
            return "not json"

        fresh()
        rep = chain(root, "demo", "demo.part", "pick-task", "stub", broken_choose, False)
        if md.read_text(plan) != before or rep.route != "seed" or rep.sessions != 2:
            bad.append(f"a bad scout is repaired once and the seed stays ({rep.route}, sessions={rep.sessions})")

        pages = {"n": 0}

        def paged(messages: list[dict[str, str]], _model: str) -> str:
            user = messages[-1]["content"]
            if user.startswith("Role: scout"):
                pages["n"] += 1
                if "scripts/ui/splash.gd" in user:
                    return json.dumps({"read": ["scripts/ui/splash.gd"]})
                return json.dumps({"read": []})
            if user.startswith("Role: mark") and "File: scripts/ui/splash.gd" in user:
                return splash_edit
            if user.startswith("Role: review"):
                return json.dumps({"drop": []})
            if user.startswith("Role: follow") or user.startswith("Role: gap"):
                return json.dumps({"read": []})
            return json.dumps({"edit": []})

        for i in range(25):
            rel = f"scripts/extra{i}.gd"
            (root / rel).write_text("extends Node\n\nfunc alpha() -> void:\n\tpass\n", encoding="utf-8")
        listed = ", ".join(["`scripts/ui/splash.gd`", "`scripts/ui/noise.gd`"] + [f"`scripts/extra{i}.gd`" for i in range(25)])
        (root / "design" / "code-map.md").write_text(
            "# Live code map\n\n| System | Live files |\n|--------|------------|\n| Demo | " + listed + " |\n",
            encoding="utf-8")
        fresh()
        rep = chain(root, "demo", "demo.part", "pick-task", "stub", paged, False)
        if pages["n"] < 2 or rep.route != "pick" or "func `scripts/extra0.gd" in md.read_text(plan):
            bad.append(f"a long catalog is paged and extras stay unread ({pages['n']}, {rep.route}, sessions={rep.sessions})")
        offered = catalog(root, "demo", "demo.part", "pick-task")[0]
        if len(offered) <= CAP or "scripts/ui/splash.gd" not in [s.path for s in offered]:
            bad.append(f"the chain catalog is not capped at {CAP}: {len(offered)}")

        (root / "scripts" / "ui" / "splash.gd").write_text(
            "extends Node\n\nfunc _ready() -> void:\n\t_play()\n\nfunc _process(_d: float) -> void:\n\tpass\n\n"
            "func _unhandled_input(_e: InputEvent) -> void:\n\tpass\n\nfunc _advance() -> void:\n\tpass\n",
            encoding="utf-8")

        def follow_title(messages: list[dict[str, str]], _model: str) -> str:
            user = messages[-1]["content"]
            if user.startswith("Role: scout"):
                return json.dumps({"read": ["scripts/ui/splash.gd"]} if "scripts/ui/splash.gd" in user else {"read": []})
            if user.startswith("Role: mark") and "File: scripts/ui/splash.gd" in user:
                return splash_edit
            if user.startswith("Role: mark") and "File: scripts/title.gd" in user:
                return json.dumps({"edit": [{"path": "scripts/title.gd", "func": "_ready"}]})
            if user.startswith("Role: follow"):
                return json.dumps({"read": ["scripts/title.gd"]} if "scripts/title.gd" in user else {"read": []})
            if user.startswith("Role: review"):
                return json.dumps({"drop": ["scripts/title.gd"]})
            if user.startswith("Role: gap"):
                return json.dumps({"read": []})
            return json.dumps({"edit": []})

        fresh()
        rep = chain(root, "demo", "demo.part", "pick-task", "stub", follow_title, False)
        if "read scripts/title.gd" not in rep.body or "drop scripts/title.gd" not in rep.body or "func `scripts/title.gd" in md.read_text(plan):
            bad.append("follow reads a callee and review drops that neighbor file")

        def drop_owner(messages: list[dict[str, str]], _model: str) -> str:
            user = messages[-1]["content"]
            if user.startswith("Role: scout"):
                return json.dumps({"read": ["scripts/ui/splash.gd"]} if "scripts/ui/splash.gd" in user else {"read": []})
            if user.startswith("Role: mark") and "File: scripts/ui/splash.gd" in user:
                return splash_edit
            if user.startswith("Role: review"):
                return json.dumps({"drop": ["scripts/ui/splash.gd"]})
            if user.startswith("Role: follow") or user.startswith("Role: gap"):
                return json.dumps({"read": []})
            return json.dumps({"edit": []})

        fresh()
        rep = chain(root, "demo", "demo.part", "pick-task", "stub", drop_owner, False)
        if "review kept every marked file" not in rep.body or "func `scripts/ui/splash.gd:_ready`" not in md.read_text(plan):
            bad.append("a review that would clear the plan is ignored")

        global MAX_READS
        saved_reads = MAX_READS
        MAX_READS = 1
        try:
            def guarded(messages: list[dict[str, str]], _model: str) -> str:
                user = messages[-1]["content"]
                if user.startswith("Role: scout"):
                    if "scripts/ui/splash.gd" in user:
                        return json.dumps({"read": ["scripts/ui/splash.gd", "scripts/title.gd"]})
                    return json.dumps({"read": []})
                if user.startswith("Role: mark") and "File: scripts/ui/splash.gd" in user:
                    return splash_edit
                if user.startswith("Role: review"):
                    return json.dumps({"drop": []})
                if user.startswith("Role: follow") or user.startswith("Role: gap"):
                    return json.dumps({"read": []})
                return json.dumps({"edit": []})

            fresh()
            rep = chain(root, "demo", "demo.part", "pick-task", "stub", guarded, False)
            if "guard:" not in rep.body or "read scripts/title.gd" in rep.body or rep.route != "pick":
                bad.append(f"the runaway guard stops extra reads and keeps the marks ({rep.route})")
        finally:
            MAX_READS = saved_reads

        for i in range(9):
            rel = f"scripts/extra{i}.gd"
            (root / rel).write_text("extends Node\n\nfunc alpha() -> void:\n\tpass\n", encoding="utf-8")
        extra = " ".join(f"`scripts/extra{i}.gd`" for i in range(9))
        (root / "design" / "demo-part.md").write_text("# Part\n\n" + extra + "\n", encoding="utf-8")
        capped = [s.path for s in table(root, "demo", "demo.part", "pick-task")[0]]
        if len(capped) != CAP or "scripts/ui/splash.gd" not in capped:
            bad.append(f"the cap keeps the task stem and drops the rest: {capped}")
    return agent_log.selftest_result(bad)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(
        "Ask the local model which funcs to inline. Fail closed keeps the mechanical seed. slice.py open runs --chain.",
        writes=True)
    ap.add_argument("--task", default="", metavar="ID", help="Task id. Default: this worktree's slice state.")
    ap.add_argument("--door", default="", help="routes.yaml door. Default: slice state.")
    ap.add_argument("--job", default="", help="routes.yaml door.job. Default: slice state.")
    ap.add_argument("--model", default=MODEL, help=f"Ollama model tag (default: {MODEL}).")
    ap.add_argument("--chain", action="store_true",
                    help="Fresh role sessions (scout, mark, follow, gap, trim, review) over the door code-map. The plan is the memory between sessions.")
    ap.add_argument("--selftest", action="store_true", help="Run the cases with a stub model.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    root = agent_log.resolve_root(args)
    door, job, _area, task, _mode = session_plan._from_state(root, args.door, args.job, "", args.task)
    if not door and not job:
        agent_log.fail("pass --door D or --job door.job (or start the slice so the worktree state has one).")
    go = chain if args.chain else run
    try:
        rep = go(root, door, job, task, args.model, ollama_complete, args.dry_run)
    except ModelError as exc:
        return agent_log.finish(
            "gather-pick", root, f"picker: model error; the mechanical seed stays\n{exc}", "FAIL",
            args=args, write=not args.dry_run, route="error")
    return agent_log.finish(
        "gather-pick", root, rep.body, "PASS", args=args, write=not args.dry_run,
        route=rep.route, accepted=rep.accepted, scripts=rep.scripts, repair=rep.repair,
        dropped=rep.dropped, sessions=rep.sessions)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
