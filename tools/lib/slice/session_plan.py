#!/usr/bin/env python3
"""Mechanical seed of the context index for a named door or job, written to session-plan.md in the worktree root.

    python tools/slice.py plan [--door D | --job door.job] [--task ID] [--refresh [--clean]] [--dry-run]
The file is gitignored: the same-worktree continuity note and the single source of truth for what belongs in context.
It does not replace the task file or a survey handoff. `slice.py open` (or `start`) writes it when it is missing; the
gather agent then refines the index below the marker with `slice.py adjust` (format: plan_index.py). `--refresh`
re-seeds the index and replays the logged adjustments; `--clean` drops them. The sections above the marker
(Outcome, Open questions, Changed files, Latest results, Approach) are always kept. Approach is written with
`slice.py adjust approach`, not by hand.

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
import load_routes
import md_format_lib as md
import plan_adjust
import plan_index as pi
import slice_lib
import slice_state

REL = "session-plan.md"
MARKER = pi.MARKER
MAX_SCRIPTS = 12
MAX_PATHS = 30
MAX_CANDS = 12  # code-map candidates per system; the gather agent prunes or adds
KEPT_HEADS = (
    ("## Outcome", "(one line: what will be observably different, and how to measure it)"),
    ("## Open questions", "- none yet"),
    ("## Changed files", "- none yet"),
    ("## Latest results", "- none yet"),
    ("## Approach", "(the edit, in the order to type it)"),
)
INTRO = (
    "# Session plan\n\n"
    "Same-worktree continuity after a compact. Not a task file and not a survey handoff.\n"
    "Write Outcome, Open questions, Changed files and Latest results above the marker in the same turn a fact lands.\n"
    "Approach is the edit in the order to type it. Write it only with `python tools/slice.py adjust approach`.\n"
    "Below the marker is the context index: change it with `python tools/slice.py adjust`, never by hand; `python tools/slice.py expand` builds the packet.\n"
)
CODE_RE = re.compile(r"^Code:\s*(.+)$", re.M)
TICK_RE = re.compile(r"`([^`]+)`")
NAMED_RE = re.compile(r"`([^`\s]+?\.gd)`(?:\s*\(([^)]{0,200})\))?")
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

def _named_scripts(root: Path, text: str, rows: list, prefer: list, skip: list[str]) -> list[tuple[str, str]]:
    """(.gd path, condition) for every script the doc names in backticks outside its Code: lines, in doc order; the
    parenthetical after a name (its functions) goes into the condition."""
    out: list[tuple[str, str]] = []
    for line in (text or "").splitlines():
        if CODE_RE.match(line):
            continue
        for m in NAMED_RE.finditer(line):
            path = _resolve(root, m.group(1), rows, prefer)
            if path and path not in skip and path not in [p for p, _ in out]:
                funcs = (m.group(2) or "").strip()
                out.append((path, f"the change reaches it (job doc: {funcs})" if funcs else "the change reaches it (named in the job doc)"))
    return out[:MAX_SCRIPTS]

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

def _git_head(root: Path) -> str:
    proc = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=root, capture_output=True, text=True)
    return proc.stdout.strip() if proc.returncode == 0 else "(no git)"

def _unit_specs(data: dict, door: str, job: str, key: str) -> list[str]:
    raw = data.get(key) if isinstance(data.get(key), dict) else {}
    out: list[str] = []
    for k in (door, job):
        if k and raw.get(k):
            out += [x.strip() for x in str(raw[k]).split(";") if x.strip()]
    return out

def seed(root: Path, door: str, job: str, area: str, mode: str, task: str, route_lines: list[str] | None) -> pi.Index:
    """The mechanical seed: identity, core (job doc, unit docs/files, key scripts' names, task file) and candidates
    (door doc when a job is named; the scripts the job doc names in its text, else the system's code-map paths), plus
    the route card. Deterministic for one commit."""
    door, job = _door_job(door, job)
    door_file, job_file, door_text = _docs(root, door, job)
    job_text = _read(root, job_file) if job_file else ""
    rows = _rows(root)
    prefer = [r for r in (cm.find_system(rows, n) for n in _needles(door, job)) if r is not None] if rows else []
    scripts, missing = _key_scripts(root, door_text, job_text, rows, prefer or rows)
    systems = _systems(rows, door, job, scripts) if rows else []
    try:
        data = load_routes.load_routes(root)
    except (OSError, ValueError):
        data = {}
    idx = pi.Index(identity=[("door", door or "(none)"), ("job", job or "(none)"), ("task", task or "(none)"),
                             ("area", area or job or door or "(none)"), ("mode", mode or "(none)"),
                             ("systems", ", ".join(r.system for r in systems) or "(none matched)"),
                             ("seed", _git_head(root)), ("gather", "seed")])
    seen: set[str] = set()

    def add(kind: str, ref: str, core: bool, note: str) -> None:
        if ref in seen or not ref:
            return
        seen.add(ref)
        idx.items.append(pi.Item(idx.next_id(core), kind, ref, core, note))

    tid = task.strip()
    if tid and (root / "design" / "tasks" / f"{tid}.md").is_file():
        add("doc", f"design/tasks/{tid}.md", True, "the assignment")
    if job_file:
        add("doc", job_file, True, "job doc")
    for spec in _unit_specs(data, door, job, "unit_docs"):
        add("doc", spec, True, "unit doc section")
    for spec in _unit_specs(data, door, job, "unit_files"):
        path, _, names = spec.partition(":")
        funcs = [n.strip() for n in names.split(",") if n.strip()]
        for name in funcs:
            add("func", f"{path.strip()}:{name}", True, "unit file")
        if not funcs:
            add("names", path.strip(), True, "unit file")
    if door_file:
        if job_file:
            add("doc", door_file, False, "the change touches door-wide rules or a sibling job")
        else:
            add("doc", door_file, True, "door doc")
    for rel in scripts:
        add("names", rel, True, "key script (declared names)")
    named = _named_scripts(root, job_text or door_text, rows, prefer or rows, scripts)
    for rel, cond in named:
        add("names", rel, False, cond)
    for row in [] if named else systems:  # a doc that names its scripts beats the whole system row
        for rel in [x for x in row.listed if x.endswith(".gd") and (root / x).is_file()][:MAX_CANDS]:
            add("names", rel, False, f"the change reaches {row.system} code")
    if missing:
        idx.set("unresolved", ", ".join(missing))
    idx.card = _card(root, door, job, route_lines)
    return idx

def render(root: Path, existing: str, door: str, job: str, area: str, mode: str, task: str,
           route_lines: list[str] | None) -> str:
    return pi.join_plan(kept_block(existing), seed(root, door, job, area, mode, task, route_lines))

def ensure(root: Path, door: str, job: str, area: str = "", mode: str = "", task: str = "",
           route_lines: list[str] | None = None, refresh: bool = False, clean: bool = False) -> str:
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
        if clean:
            plan_adjust.clear_delta(root)
            return "session-plan.md refreshed clean (index re-seeded; adjustments dropped; the sections above the marker kept)."
        n = plan_adjust.replay(root)
        return f"session-plan.md refreshed (index re-seeded, {n} logged adjustments replayed; the sections above the marker kept)."
    return "session-plan.md written (mechanical seed)."

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
    ap.add_argument("--refresh", action="store_true", help="Re-seed the index and replay the logged adjustments (_logs/gather/delta.jsonl). Keeps the sections above the marker.")
    ap.add_argument("--clean", action="store_true", help="With --refresh: drop the logged adjustments instead of replaying them.")
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
    line = ensure(root, door, job, area, mode, task, None, refresh=args.refresh, clean=args.clean)
    if not line:
        line = "session-plan.md present. Pass --refresh only when the index is stale (adjustments are replayed)."
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
        idx = pi.parse(pi.split_plan(text)[1])
        job, door, key = idx.find("design/demo-part.md"), idx.find("design/demo.md"), idx.find("scripts/demo.gd")
        if not (job and job.core) or not (door and not door.core and door.note) or not (key and key.core):
            bad.append("seed: job doc and key script core; door doc a candidate with a condition when a job is named")
        for need in ("task: demo-task", "card line", "unresolved: nope.gd", "systems: Demo", "## Outcome"):
            if need not in text:
                bad.append(f"seed missing {need!r}")
        if "Unique door sentence." in text or "func alpha" in text:
            bad.append("the seed is an index: no pasted doc or code bodies")
        (root / "scripts" / "other.gd").write_text("extends Node\n", encoding="utf-8")
        (root / "scripts" / "noise.gd").write_text("extends Node\n", encoding="utf-8")
        cmap = (root / "design" / "code-map.md").read_text(encoding="utf-8")
        (root / "design" / "code-map.md").write_text(cmap.replace("(facade) |", "(facade), `scripts/noise.gd` |"), encoding="utf-8")
        named = render(root, "", "demo", "demo.part", "", "implement", "", [])
        if "noise.gd" not in render(root, "", "demo", "demo.part", "", "implement", "", []) or "area: demo.part" not in named:
            bad.append("seed: with no scripts named in the job text, the system row gives candidates; area defaults to the job")
        (root / "design" / "demo-part.md").write_text("# Part\n\nForm code: `scripts/other.gd` (build, send).\n", encoding="utf-8")
        named = pi.parse(pi.split_plan(render(root, "", "demo", "demo.part", "", "implement", "", []))[1])
        other = named.find("scripts/other.gd")
        if not (other and not other.core and "build, send" in other.note) or named.find("scripts/noise.gd"):
            bad.append("seed: a script the job doc names in its text is a candidate (with its functions); the system row is then left out")
        (root / "design" / "demo-part.md").write_text("# Part\n\nJob sentence.\n", encoding="utf-8")
        (root / "design" / "code-map.md").write_text(cmap, encoding="utf-8")
        if pi.render(idx) != pi.split_plan(text)[1]:
            bad.append("seed must round-trip through plan_index")
        path = plan_path(root)
        md.write_text(path, text.replace(KEPT_HEADS[0][1], "the marker is visible"))
        env_root = str(root)
        proc = subprocess.run([*boot.cmd("plan_adjust"), "--root", env_root, "rem", "design/demo.md"], capture_output=True, text=True)
        again = ensure(root, "demo", "demo.part", "demo", "implement", "demo-task", ["card line"], refresh=True)
        got = md.read_text(path)
        if "the marker is visible" not in got or "design/demo.md`" in got or proc.returncode:
            bad.append(f"refresh must keep the outcome and replay the logged rem ({again}; {proc.stdout[-200:]})")
        if got.count(MARKER) != 1:
            bad.append("the plan must keep one gathered marker")
        ensure(root, "demo", "demo.part", "demo", "implement", "demo-task", ["card line"], refresh=True, clean=True)
        if "design/demo.md`" not in md.read_text(path):
            bad.append("refresh --clean must drop the logged adjustments")
    return agent_log.selftest_result(bad)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
