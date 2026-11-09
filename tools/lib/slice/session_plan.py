#!/usr/bin/env python3
"""Opening gather for a named door or job, written to session-plan.md in the worktree root.

    python tools/slice.py plan [--door D | --job door.job] [--task ID] [--refresh] [--dry-run]
The file is gitignored. It is the same-worktree continuity note across a compact. It does not replace
the task file or a survey handoff. `slice.py start` writes it when it is missing. Build trims the gathered
half to the working set; `--refresh` replaces that half and erases the trim. It keeps Outcome, Open questions,
Changed files, and Latest results.

--selftest builds a throwaway repo and checks the gather, the refresh keep, and the worktree guard.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import code_map_lib as cm
import gd_lib
import load_routes
import md_format_lib as md
import slice_lib
import slice_state

REL = "session-plan.md"
MARKER = "<!-- gathered -->"
MAX_SCRIPTS = 12
MAX_PATHS = 30
KEPT_HEADS = (
    ("## Outcome", "(one line: what will be observably different, and how to measure it)"),
    ("## Open questions", "- none yet"),
    ("## Changed files", "- none yet"),
    ("## Latest results", "- none yet"),
)
INTRO = (
    "# Session plan\n\n"
    "Same-worktree continuity after a compact. Not a task file and not a survey handoff.\n"
    "Write the four sections above the marker in the same turn a fact lands. Trim the gathered half to this unit once the working set is known, before the first edit.\n"
    "`python tools/slice.py plan --refresh` rebuilds the gathered half and erases that trim. Use it only when the gather is stale.\n"
    "On a post-compact turn, read this file first. Do not re-run the lookups it still holds.\n"
)
CODE_RE = re.compile(r"^Code:\s*(.+)$", re.M)
TICK_RE = re.compile(r"`([^`]+)`")
FACADE_RE = re.compile(r"`([^`]+?\.gd)`\s*\(([^)]{0,600})\)")


def plan_path(root: Path) -> Path:
    return root / REL

def default_kept() -> str:
    parts = [INTRO]
    for title, body in KEPT_HEADS:
        parts.append(f"{title}\n\n{body}\n")
    return "\n".join(parts).rstrip() + "\n\n"

def kept_block(existing: str) -> str:
    """Agent sections above the marker. A missing marker keeps the old text so a refresh cannot drop it."""
    if not existing.strip():
        return default_kept()
    head = existing.split(MARKER, 1)[0].rstrip() + "\n"
    if not head.lstrip().startswith("# Session plan"):
        head = INTRO + "\n" + head
    for title, body in KEPT_HEADS:
        if title not in head:
            head += f"\n{title}\n\n{body}\n"
    return head.rstrip() + "\n\n"

def _read(root: Path, rel: str) -> str:
    path = root / rel
    if not rel or not path.is_file():
        return ""
    try:
        return md.read_text(path)
    except (OSError, UnicodeError) as exc:
        return f"(unreadable {rel}: {exc})"

def _door_job(door: str, job: str) -> tuple[str, str]:
    door, job = door.strip(), job.strip()
    if job and "." in job and not door:
        door = job.split(".", 1)[0]
    return door, job

def _docs(root: Path, door: str, job: str) -> tuple[str, str, str]:
    """(door file, job file, task is separate). Empty strings when the route has no such file."""
    try:
        data = load_routes.load_routes(root)
    except (OSError, ValueError):
        return "", "", ""
    rec = (data.get("doors") or {}).get(door) or {}
    door_file = str(rec.get("file") or "")
    job_file = ""
    if job:
        job_file = str(load_routes.job_index(data)["by_id"].get(job) or "")
    return door_file, job_file, _read(root, door_file)

def _rows(root: Path) -> list:
    path = root / "design" / "code-map.md"
    if not path.is_file():
        return []
    try:
        return cm.parse_rows(md.read_text(path))
    except (OSError, UnicodeError):
        return []

def _needles(door: str, job: str) -> list[str]:
    raws = [door]
    if job and "." in job:
        raws.append(job.split(".", 1)[0])
    out: list[str] = []
    for raw in raws:
        raw = raw.strip()
        if not raw or raw in out:
            continue
        out.append(raw)
        if "_" in raw:
            spaced = raw.replace("_", " ")
            first = raw.split("_", 1)[0]
            for extra in (spaced, first):
                if extra not in out:
                    out.append(extra)
    return out

def _resolve(root: Path, token: str, rows: list, prefer: list) -> str:
    token = token.strip().strip("`").replace("\\", "/")
    if not token:
        return ""
    if token.endswith(".gd") and (root / token).is_file():
        return token
    base = Path(token).name
    if not base.endswith(".gd"):
        base += ".gd"
    if (root / token).is_file() and token.endswith(".gd"):
        return token

    def hits(pool: list) -> list[str]:
        found: list[str] = []
        for row in pool:
            for item in row.listed:
                if item == base or item.endswith("/" + base):
                    found.append(item)
        return list(dict.fromkeys(found))

    got = hits(prefer) or hits(rows)
    exist = [item for item in got if (root / item).is_file()]
    if len(exist) == 1:
        return exist[0]
    if len(got) == 1 and (root / got[0]).is_file():
        return got[0]
    return ""

def _key_scripts(root: Path, door_text: str, job_text: str, rows: list, prefer: list) -> tuple[list[str], list[str]]:
    """(resolved .gd paths, unresolved tokens). Code: lines win (the job's first, so the MAX_SCRIPTS cap
    keeps a job binding over a long door line); otherwise facade groups on the preferred rows."""
    tokens: list[str] = []
    for text in (job_text, door_text):
        for line in CODE_RE.findall(text or ""):
            tokens.extend(TICK_RE.findall(line))
    resolved: list[str] = []
    missing: list[str] = []
    for token in tokens:
        path = _resolve(root, token, rows, prefer)
        if path and path not in resolved:
            resolved.append(path)
        elif token.strip("`") not in missing:
            missing.append(token.strip("`"))
    if resolved:
        return resolved[:MAX_SCRIPTS], missing
    for row in prefer:
        for match in FACADE_RE.finditer(row.live):
            if "facade" not in match.group(2).lower():
                continue
            facade = _resolve(root, match.group(1), rows, prefer)
            if facade and facade not in resolved:
                resolved.append(facade)
            for helper in TICK_RE.findall(match.group(2)):
                if not helper.endswith(".gd"):
                    continue
                path = _resolve(root, helper, rows, prefer)
                if path and path not in resolved:
                    resolved.append(path)
            if len(resolved) >= MAX_SCRIPTS:
                return resolved[:MAX_SCRIPTS], missing
    return resolved[:MAX_SCRIPTS], missing

def _systems(rows: list, door: str, job: str, scripts: list[str]) -> list:
    chosen = []
    for needle in _needles(door, job):
        row = cm.find_system(rows, needle)
        if row is not None and row not in chosen:
            chosen.append(row)
    for path in scripts:
        for row in rows:
            if path in row.listed and row not in chosen:
                chosen.append(row)
    return chosen[:4]

def _names(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        return f"(unreadable: {exc})"
    names = [item[0] for item in gd_lib.funcs_of(text)]
    return ", ".join(names) if names else "(none)"

def _card(root: Path, door: str, job: str, route_lines: list[str] | None) -> str:
    if route_lines is not None:
        lines = [ln for ln in route_lines if ln and not ln.startswith("RESULT ")]
        return "\n".join(lines) if lines else "(no card)"
    cmd = [*boot.cmd("list_route"), "--root", str(root)]
    cmd += (["--door", door] if door else []) + (["--job", job] if job else [])
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    lines = [ln for ln in (proc.stdout + proc.stderr).splitlines() if ln and not ln.startswith("RESULT ")]
    if proc.returncode != 0:
        lines.insert(0, f"(route exit {proc.returncode})")
    return "\n".join(lines) if lines else "(no card)"

def render(root: Path, existing: str, door: str, job: str, area: str, mode: str, task: str,
           route_lines: list[str] | None) -> str:
    door, job = _door_job(door, job)
    door_file, job_file, door_text = _docs(root, door, job)
    if not door_text and door_file:
        door_text = f"(missing {door_file})"
    job_text = _read(root, job_file) if job_file else ""
    if job_file and not job_text:
        job_text = f"(missing {job_file})"
    rows = _rows(root)
    prefer = []
    if rows:
        for needle in _needles(door, job):
            row = cm.find_system(rows, needle)
            if row is not None and row not in prefer:
                prefer.append(row)
    scripts, missing = _key_scripts(root, door_text, job_text, rows, prefer or rows)
    systems = _systems(rows, door, job, scripts) if rows else []
    lines = [
        "### Identity",
        "",
        f"- door: {door or '(none)'}",
        f"- job: {job or '(none)'}",
        f"- task: {task or '(none)'}",
        f"- area: {area or '(none)'}",
        f"- mode: {mode or '(none)'}",
        f"- systems: {', '.join(row.system for row in systems) if systems else '(none matched)'}",
        f"- primary doc: {door_file or '(none)'}",
        f"- job doc: {job_file or '(none)'}",
        "",
        "### Card",
        "",
        _card(root, door, job, route_lines),
        "",
        "### Systems",
        "",
    ]
    if not (root / "design" / "code-map.md").is_file():
        lines.append("MISSING design/code-map.md")
        lines.append("")
    elif not systems:
        lines.append("(no code-map row matched this door)")
        lines.append("")
    for row in systems:
        paths = [item for item in row.listed if item.endswith(".gd")]
        lines.append(f"#### {row.system}")
        lines.append("")
        shown = paths[:MAX_PATHS]
        lines.extend(f"- `{item}`" for item in shown)
        if len(paths) > len(shown):
            lines.append(f"- (+{len(paths) - len(shown)} more .gd paths on this row)")
        lines.append("")
    lines += ["### Functions", ""]
    if not scripts:
        lines.append("(no key scripts resolved)")
    for rel in scripts:
        lines.append(f"- `{rel}`: {_names(root / rel)}")
    if missing:
        lines.append("- unresolved: " + ", ".join(f"`{item}`" for item in missing))
    lines.append("")
    lines += ["### Door doc", "", door_text.strip() or "(none)", ""]
    if job_file:
        lines += ["### Job doc", "", job_text.strip() or "(none)", ""]
    gathered = "\n".join(lines).rstrip() + "\n"
    return kept_block(existing) + MARKER + "\n\n" + gathered

def ensure(root: Path, door: str, job: str, area: str = "", mode: str = "", task: str = "",
           route_lines: list[str] | None = None, refresh: bool = False) -> str:
    """Write session-plan.md when missing, or when refresh replaces the gathered half. '' when left as it is."""
    door, job = _door_job(door, job)
    if not door and not job:
        return ""
    path = plan_path(root)
    if path.is_file() and not refresh:
        return ""
    existing = md.read_text(path) if path.is_file() else ""
    md.write_text(path, render(root, existing, door, job, area, mode, task, route_lines))
    if refresh and existing:
        return "session-plan.md refreshed (gathered half replaced; outcome, questions, changed files, and results kept). Read it next."
    return "session-plan.md written. Read it next. Use find.py only for a gap it does not cover, then trim the gathered half to this unit in that same turn and write the four sections above the marker. --refresh erases a trim."

def _from_state(root: Path, door: str, job: str, area: str, task: str) -> tuple[str, str, str, str, str]:
    st = slice_state.load(root)
    door, job = _door_job(door or st.get("door", ""), job or st.get("job", ""))
    area = area or st.get("area", "")
    task = task or st.get("task", "")
    mode = st.get("mode", "")
    return door, job, area, task, mode

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Write session-plan.md for a named door or job (opening gather).", writes=True)
    ap.add_argument("--door", default="", help="routes.yaml door. Default: this worktree's slice state.")
    ap.add_argument("--job", default="", help="routes.yaml door.job. Default: this worktree's slice state.")
    ap.add_argument("--area", default="", help="Slice area label stored in the plan (default: slice state).")
    ap.add_argument("--task", default="", metavar="ID", help="Task id stored in the plan. The task file stays the assignment.")
    ap.add_argument("--refresh", action="store_true", help="Replace the gathered half. Keeps Outcome, Open questions, Changed files, and Latest results.")
    ap.add_argument("--selftest", action="store_true", help="Run the gather cases in a throwaway repo.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest(boot.cmd("session_plan"))
    root = agent_log.resolve_root(args)
    door, job, area, task, mode = _from_state(root, args.door, args.job, args.area, args.task)
    if not door and not job:
        agent_log.fail("pass --door D or --job door.job (or start the slice so the worktree state has one).")
    if not args.dry_run and not slice_lib.worktree_kind(root):
        agent_log.fail("session-plan.md is written in a slice worktree. The User opens one with `python tools/slice.py open`.")
    if load_routes.check_route(load_routes.load_routes(root), door, job):
        agent_log.fail(load_routes.check_route(load_routes.load_routes(root), door, job))
    if args.dry_run:
        text = render(root, "", door, job, area, mode, task, None)
        return agent_log.finish("session-plan", root, text, "PASS", args=args, write=False,
                                echo=f"dry-run: session-plan.md not written ({len(text.splitlines())} lines). door={door} job={job}",
                                door=door, plan_job=job)
    path = plan_path(root)
    existed = path.is_file()
    line = ensure(root, door, job, area, mode, task, None, refresh=args.refresh)
    if not line:
        line = "session-plan.md present. Read it. Pass --refresh only when the gathered half is stale. A refresh erases a trim."
    return agent_log.finish("session-plan", root, line, "PASS", args=args, write=not args.dry_run, echo=line,
                            door=door, plan_job=job, refreshed=bool(args.refresh and existed))

def selftest(script: list[str]) -> int:
    import tempfile

    import repo_lib

    bad: list[str] = []

    def run(root: Path, *a: str) -> tuple[int, str]:
        proc = subprocess.run([*script, "--root", str(root), *a], capture_output=True, text=True, encoding="utf-8", errors="replace")
        return proc.returncode, proc.stdout + proc.stderr

    with tempfile.TemporaryDirectory() as td:
        root = repo_lib.selftest_repo(td, empty_commit=True)
        (root / "design").mkdir(exist_ok=True)
        (root / "scripts").mkdir(exist_ok=True)
        (root / "design" / "routes.yaml").write_text(
            "version: 1\ndoors:\n  demo:\n    file: design/demo.md\n    read_when: \"x\"\n    jobs:\n      part: design/demo-part.md\n",
            encoding="utf-8")
        (root / "design" / "demo.md").write_text("# Demo\n\nCode: `scripts/demo.gd`, `nope.gd`\n\nUnique door sentence.\n", encoding="utf-8")
        (root / "design" / "demo-part.md").write_text("# Part\n\nJob sentence.\n", encoding="utf-8")
        (root / "design" / "code-map.md").write_text(
            "# Live code map\n\n| System | Live files |\n|--------|------------|\n| Demo | `scripts/demo.gd` (facade) |\n",
            encoding="utf-8")
        (root / "scripts" / "demo.gd").write_text("extends Node\n\nfunc alpha() -> void:\n\tpass\n\nfunc beta() -> void:\n\tpass\n", encoding="utf-8")
        code, out = run(root, "--door", "demo", "--job", "demo.part")
        if code == 0 or "slice worktree" not in out:
            bad.append("outside a worktree a real write must fail")
        code, out = run(root, "--door", "demo", "--job", "demo.part", "--dry-run")
        if code != 0 or "not written" not in out or (root / REL).exists():
            bad.append(f"dry-run must not write session-plan.md (code={code} exists={(root / REL).exists()})")
        text = render(root, "", "demo", "demo.part", "demo", "implement", "demo-task", ["card line"])
        for need in ("Unique door sentence.", "Job sentence.", "alpha, beta", "scripts/demo.gd", "demo-task", "card line", "nope.gd", "## Outcome"):
            if need not in text:
                bad.append(f"gather missing {need!r}")
        if "#### Demo" not in text:
            bad.append("the matching code-map system must be named")
        path = plan_path(root)
        md.write_text(path, text)
        edited = md.read_text(path).replace(KEPT_HEADS[0][1], "the marker is visible")
        md.write_text(path, edited)
        (root / "design" / "demo.md").write_text("# Demo\n\nCode: `scripts/demo.gd`\n\nChanged body.\n", encoding="utf-8")
        again = ensure(root, "demo", "demo.part", "demo", "implement", "demo-task", ["card line"], refresh=True)
        got = md.read_text(path)
        if "the marker is visible" not in got or "Changed body." not in got or "Unique door sentence." in got:
            bad.append(f"refresh must keep the outcome and replace the doc ({again})")
        if got.count(MARKER) != 1:
            bad.append("the plan must keep one gathered marker")
    return agent_log.selftest_result(bad)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
