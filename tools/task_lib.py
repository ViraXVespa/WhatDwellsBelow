"""Shared task files in design/tasks/ (library for task.py, handoff_lib.py, start_build_slice.py and check_load_graph.py; import only).

One open task is one `design/tasks/<id>.md`. Its header (the lines before the first `## `) holds `key: value` fields: id, owner (build, web or
bot), status (open, active or blocked), done-when, resume (or a Build handoff's `Your first command ...:` line), optional title and needs
(comma-separated ids it waits on). The body is free sections. design/tasks/README.md holds the rules and a generated index between markers.
A finished task is deleted, its dependants lose it from `needs:` (a blocked task with nothing left becomes open), and one changelog line is added.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

import md_format_lib as md

TASKS_REL = "design/tasks"
README = "README.md"
BEGIN, END = "<!-- tasks:begin -->", "<!-- tasks:end -->"
OWNERS = ("build", "web", "bot")
STATUSES = ("open", "active", "blocked")
KEYS = ("id", "title", "owner", "status", "done-when", "resume", "needs", "needs-local", "area", "door", "job", "units", "done", "from")
ID_RE = re.compile(r"[a-z0-9][a-z0-9-]*$")
FIRST_RE = re.compile(r"Your first command[^:]*:\s*(.+)$")
FILL = "<fill"
LOCAL = ("_src",)  # main-checkout-only (gitignored) folders open_slice.py may link into a worktree
OPT_FLOOR = 4  # the old grok-bot-opt.md queue ended at opt-004; opt ids are never reused


def tasks_dir(root: Path) -> Path:
    return root / TASKS_REL


def task_path(root: Path, tid: str) -> Path:
    return tasks_dir(root) / f"{tid}.md"


def split(raw: str) -> list[str]:
    return [p.strip() for p in (raw or "").split(",") if p.strip() and p.strip() != "none"]


def head(text: str) -> dict[str, str]:
    """Header fields; `title` falls back to the `# ` heading, `resume` to a handoff's first-command line."""
    out: dict[str, str] = {}
    for line in text.splitlines():
        if line.startswith("## "):
            break
        if line.startswith("# ") and "heading" not in out:
            out["heading"] = line[2:].strip()
            continue
        m = re.match(r"([a-z-]+):\s*(.*)$", line)
        if m and m.group(1) in KEYS and m.group(1) not in out:
            out[m.group(1)] = m.group(2).strip()
            continue
        f = FIRST_RE.search(line)
        if f and "first" not in out:
            out["first"] = f.group(1).strip()
    out.setdefault("title", out.get("heading", ""))
    if not out.get("resume") and out.get("first"):
        out["resume"] = out["first"]
    return out


def files(root: Path) -> list[Path]:
    d = tasks_dir(root)
    return sorted(p for p in d.glob("*.md") if p.name != README) if d.is_dir() else []


def load(root: Path) -> dict[str, dict[str, str]]:
    return {p.stem: {**head(md.read_text(p)), "path": f"{TASKS_REL}/{p.name}"} for p in files(root)}


def set_head(path: Path, key: str, value: str) -> bool:
    """Replace one header line `key: ...` (or a handoff's first-command line when key is 'first'); True when the file changed."""
    text, eol, bom = md.read_text(path, with_meta=True)
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.startswith("## "):
            break
        hit = FIRST_RE.search(line) if key == "first" else re.match(re.escape(key) + r":\s*", line)
        if hit:
            new = line[:hit.start(1)] + value if key == "first" else f"{key}: {value}"
            if new == line:
                return False
            lines[i] = new
            md.write_text(path, "\n".join(lines), eol="crlf" if eol == "\r\n" else "lf", bom=bom)
            return True
    return False


def set_section(path: Path, title: str, body: str) -> bool:
    """Replace the body of `## title` (added at the end when missing); True when the file changed."""
    text, eol, bom = md.read_text(path, with_meta=True)
    lines = text.rstrip("\n").split("\n")
    start = next((i for i, l in enumerate(lines) if l.strip() == f"## {title}"), -1)
    new_body = body.strip("\n").split("\n")
    if start < 0:
        out = lines + ["", f"## {title}"] + new_body
    else:
        end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
        tail = [""] + lines[end:] if end < len(lines) else []
        out = lines[:start + 1] + new_body + tail
    new = "\n".join(out) + "\n"
    if new == text:
        return False
    md.write_text(path, new, eol="crlf" if eol == "\r\n" else "lf", bom=bom)
    return True


def index_lines(tasks: dict[str, dict[str, str]]) -> list[str]:
    rows = ["id | owner | status | title | needs", "--- | --- | --- | --- | ---"]
    for tid, t in sorted(tasks.items(), key=lambda kv: (OWNERS.index(kv[1].get("owner")) if kv[1].get("owner") in OWNERS else 9, kv[0])):
        rows.append(f"{tid} | {t.get('owner', '')} | {t.get('status', '')} | {t.get('title', '')} | {', '.join(split(t.get('needs', ''))) or '-'}")
    return rows if tasks else ["(no open tasks)"]


def write_index(root: Path, dry: bool = False) -> bool:
    """Regenerate the README index block; True when it changed."""
    p = tasks_dir(root) / README
    if not p.is_file():
        return False
    text, eol, bom = md.read_text(p, with_meta=True)
    block = "\n".join([BEGIN] + index_lines(load(root)) + [END])
    new = md.splice_marker_block(text, BEGIN, END, block)
    if new is None or new == text:
        return False
    if not dry:
        md.write_text(p, new, eol="crlf" if eol == "\r\n" else "lf", bom=bom)
    return True


def fails(root: Path) -> list[str]:
    """Lint for check_load_graph.py and `task.py check`."""
    out: list[str] = []
    d = tasks_dir(root)
    if not d.is_dir():
        return [f"{TASKS_REL}/ is missing"]
    if not (d / README).is_file():
        out.append(f"{TASKS_REL}/README.md is missing")
    for p in sorted(d.iterdir()):
        if p.is_dir() or (p.suffix != ".md"):
            out.append(f"{TASKS_REL}/{p.name}: tasks are <id>.md files (convert it with `python tools/task.py new`)")
    tasks = load(root)
    for tid, t in tasks.items():
        where = t["path"]
        if not ID_RE.match(tid):
            out.append(f"{where}: file name must be a lowercase kebab id")
        if t.get("id") != tid:
            out.append(f"{where}: `id:` must equal the file name ({tid})")
        if t.get("owner") not in OWNERS:
            out.append(f"{where}: `owner:` must be one of {', '.join(OWNERS)}")
        if t.get("status") not in STATUSES:
            out.append(f"{where}: `status:` must be one of {', '.join(STATUSES)} (a done task is deleted: `python tools/task.py done {tid}`)")
        for key in ("done-when", "resume"):
            if not t.get(key) or FILL in t.get(key, ""):
                out.append(f"{where}: `{key}:` is empty or unfilled")
        needs = split(t.get("needs", ""))
        for n in needs:
            if n not in tasks:
                out.append(f"{where}: needs {n}, which is not an open task")
        for loc in split(t.get("needs-local", "")):
            if loc not in LOCAL:
                out.append(f"{where}: needs-local {loc} is not one of {', '.join(LOCAL)}")
        if t.get("status") == "blocked" and not needs:
            out.append(f"{where}: blocked with no `needs:` (name what it waits on, or make it open)")
    p = d / README
    if p.is_file():
        parts = md.split_marker_block(md.read_text(p), BEGIN, END)
        want = "\n".join([BEGIN] + index_lines(tasks) + [END])
        if parts is None:
            out.append(f"{TASKS_REL}/README.md has no {BEGIN} ... {END} index")
        elif parts[1].strip() != want:
            out.append(f"{TASKS_REL}/README.md index is stale: run `python tools/task.py index`")
    return out


def changelog_target(root: Path) -> Path | None:
    """The newest design/changelog/X.Y.Z.md that main does not have yet (this branch's own entry), else None."""
    def key(p: Path) -> tuple[int, ...]:
        return tuple(int(x) for x in p.stem.split("."))
    logs = sorted((p for p in (root / "design" / "changelog").glob("*.md") if re.fullmatch(r"\d+\.\d+\.\d+", p.stem)), key=key, reverse=True)
    for p in logs:
        rel = p.relative_to(root).as_posix()
        on_main = any(subprocess.run(["git", "cat-file", "-e", f"{ref}:{rel}"], cwd=root, capture_output=True).returncode == 0 for ref in ("origin/main", "main"))
        if not on_main:
            return p
        return None
    return None


def add_bullet(text: str, bullet: str) -> str:
    """The bullet after the entry's last `- ` line (before its `Summary:` line), else at the end."""
    lines = text.rstrip("\n").split("\n") if text.strip() else []
    last = max((i for i, l in enumerate(lines) if l.startswith("- ")), default=-1)
    if last < 0:
        last = next((i - 1 for i, l in enumerate(lines) if l.startswith("Summary:")), len(lines) - 1)
    return "\n".join(lines[:last + 1] + [bullet] + lines[last + 1:]) + "\n"


def done(root: Path, tid: str, changelog: Path, dry: bool = False) -> list[str]:
    """Delete the task, unblock its dependants, add one changelog line. Returns what changed."""
    tasks = load(root)
    t = tasks[tid]
    title = t.get("title") or tid
    out = [f"deleted {t['path']}", f"changelog {changelog.relative_to(root).as_posix()}: - Finished task {tid}: {title}."]
    for oid, o in tasks.items():
        needs = split(o.get("needs", ""))
        if tid in needs:
            rest = [n for n in needs if n != tid]
            out.append(f"{oid}: needs {', '.join(rest) or 'none'}" + ("; status open" if not rest and o.get("status") == "blocked" else ""))
            if not dry:
                op = root / o["path"]
                set_head(op, "needs", ", ".join(rest) or "none")
                if not rest and o.get("status") == "blocked":
                    set_head(op, "status", "open")
    if not dry:
        (root / t["path"]).unlink()
        text, eol, bom = md.read_text(changelog, with_meta=True) if changelog.is_file() else ("", "\r\n", False)
        md.write_text(changelog, add_bullet(text, f"- Finished task {tid}: {title}."), eol="crlf" if eol == "\r\n" else "lf", bom=bom)
        write_index(root)
    return out


def next_opt(root: Path) -> str:
    """`opt-next` for `task.py new`: one above every opt id open now or ever committed under design/tasks."""
    p = subprocess.run(["git", "log", "--all", "--format=", "--name-only", "--", f"{TASKS_REL}/opt-*.md"], cwd=root, capture_output=True, text=True)
    seen = [int(m) for m in re.findall(r"opt-(\d+)\.md", p.stdout + " ".join(f.name for f in files(root)))]
    return f"opt-{max(seen + [OPT_FLOOR]) + 1:03d}"


def skeleton(tid: str, owner: str, title: str, done_when: str, resume: str, needs: list[str], body: str) -> str:
    lines = [f"# {title}", "", f"id: {tid}", f"owner: {owner}", f"status: {'blocked' if needs else 'open'}", f"done-when: {done_when}", f"resume: {resume}"]
    if needs:
        lines.append("needs: " + ", ".join(needs))
    return "\n".join(lines + ["", body.strip() or "## Notes\nnone yet", ""])
