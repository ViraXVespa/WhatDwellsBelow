#!/usr/bin/env python3
"""Check design-doc routing against design/routes.yaml.

    python tools/check_load_graph.py
    python tools/check_load_graph.py --root .

Exit 0 if every check passes. Exit 1 and print FAIL lines otherwise.
Exit 2 if the tree is not a WDB root or routes.yaml cannot be parsed.

Increment 4: door read_when phrases must not share content tokens;
protocol-family files must stay under a citation budget.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from load_routes import (  # noqa: E402
    CYCLE_ROLES,
    RoutesError,
    allowed_citations,
    all_route_files,
    door_job_targets,
    load_routes,
    parked_job_files,
    role_of,
    skill_files,
)

CHANGELOG_PREFIX = "design/changelog/"
CITE_RE = re.compile(
    r"(?:`)?((?:design/[\w./-]+\.md)|AGENTS\.md)(?:`)?"
)
SEE_ALSO_RE = re.compile(r"^See also\s*:", re.I | re.M)
JOB_HEAD_RE = re.compile(r"^\|\s*Job\s*\|", re.I)
JOB_DIV_RE = re.compile(r"^\|\s*-+")
SKIP_DOOR_RE = re.compile(r"\bthe\s+([a-z0-9][a-z0-9 _/-]{1,40}?)\s+door\b", re.I)
PARKED_NAME_RE = re.compile(r"attack.?keyframe", re.I)
READ_WHEN_TOKEN_RE = re.compile(r"[a-z0-9]+", re.I)
READ_WHEN_STOP = frozenset(
    {
        "a",
        "an",
        "and",
        "as",
        "at",
        "changing",
        "deciding",
        "for",
        "from",
        "in",
        "into",
        "is",
        "not",
        "of",
        "on",
        "or",
        "the",
        "to",
        "touching",
        "vs",
        "when",
        "whether",
        "with",
        "writing",
        "something",
        "asked",
        "user",
        "named",
        "live",
        "rules",
        "notes",
        "text",
        "copy",
        "feature",
        "system",
        "internals",
        "chrome",
        "layout",
        "flow",
        "check",
        "gap",
        "missing",
        "bar",
        "scale",
        "vs",
    }
)
CITE_BUDGET = {
    "agents": 30,
    "path": 16,
    "requires": 12,
    "recipe": 8,
    "bot_job": 8,
    "gate": 8,
}


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def scanned_md_files(root: Path) -> list[Path]:
    out: list[Path] = []
    design = root / "design"
    for path in sorted(design.rglob("*.md")):
        posix = rel(path, root)
        if posix.startswith(CHANGELOG_PREFIX):
            continue
        out.append(path)
    skills_root = root / ".grok" / "skills"
    if skills_root.is_dir():
        for path in sorted(skills_root.rglob("*.md")):
            out.append(path)
    for extra in ("AGENTS.md",):
        p = root / extra
        if p.is_file():
            out.append(p)
    return out


def citations(text: str) -> list[str]:
    found: list[str] = []
    for match in CITE_RE.finditer(text):
        item = match.group(1)
        if item.startswith(CHANGELOG_PREFIX):
            continue
        found.append(item)
    return found


def job_table_paths(text: str) -> list[str]:
    paths: list[str] = []
    in_job = False
    for line in text.splitlines():
        if JOB_HEAD_RE.match(line):
            in_job = True
            continue
        if not in_job:
            continue
        if not line.startswith("|"):
            in_job = False
            continue
        if JOB_DIV_RE.match(line):
            continue
        paths.extend(citations(line))
    return paths


def body_citations(text: str) -> list[str]:
    keep: list[str] = []
    in_job = False
    for line in text.splitlines():
        if JOB_HEAD_RE.match(line):
            in_job = True
            continue
        if in_job:
            if not line.startswith("|"):
                in_job = False
            else:
                continue
        keep.extend(citations(line))
    return keep


def _normalize_cycle(nodes: list[str]) -> tuple[str, ...]:
    i = nodes.index(min(nodes))
    return tuple(nodes[i:] + nodes[:i])


def citation_cycles(
    routes: dict, texts: dict[str, str]
) -> list[tuple[str, ...]]:
    graph: dict[str, set[str]] = {}
    for posix, text in texts.items():
        if role_of(routes, posix) not in CYCLE_ROLES:
            continue
        graph.setdefault(posix, set())
        for dest in set(citations(text)):
            if dest == posix:
                continue
            if role_of(routes, dest) in CYCLE_ROLES:
                graph[posix].add(dest)
    found: list[tuple[str, ...]] = []
    seen: set[tuple[str, ...]] = set()
    color: dict[str, int] = {}
    stack: list[str] = []

    def dfs(u: str) -> None:
        color[u] = 1
        stack.append(u)
        for v in sorted(graph.get(u, ())):
            if v not in graph:
                graph.setdefault(v, set())
            state = color.get(v, 0)
            if state == 0:
                dfs(v)
            elif state == 1:
                start = stack.index(v)
                cyc = _normalize_cycle(stack[start:])
                if cyc not in seen:
                    seen.add(cyc)
                    found.append(cyc)
        stack.pop()
        color[u] = 2

    for node in sorted(graph):
        if color.get(node, 0) == 0:
            dfs(node)
    return found


def route_memberships(routes: dict) -> dict[str, list[str]]:
    found: dict[str, list[str]] = {}

    def add(posix: str, tag: str) -> None:
        if not posix:
            return
        bucket = found.setdefault(str(posix), [])
        if tag not in bucket:
            bucket.append(tag)

    boot = routes.get("boot") or {}
    add(str(boot.get("agents") or "AGENTS.md"), "agents")
    for name, posix in ((boot.get("paths") or {}).items()):
        add(str(posix), f"path.{name}")
    for _name, items in ((routes.get("requires") or {}).items()):
        for posix in items or []:
            add(str(posix), "requires")
    for name, posix in ((routes.get("indexes") or {}).items()):
        add(str(posix), f"indexes.{name}")
    for name, posix in ((routes.get("recipes") or {}).items()):
        add(str(posix), f"recipes.{name}")
    for name, posix in ((routes.get("bot_jobs") or {}).items()):
        add(str(posix), f"bot_jobs.{name}")
    for posix in routes.get("notes_exempt") or []:
        add(str(posix), "notes_exempt")
    skills = routes.get("skills") or {}
    if isinstance(skills, dict):
        for name, posix in skills.items():
            add(str(posix), f"skills.{name}")
    for posix in routes.get("parked_jobs") or []:
        add(str(posix), "parked_jobs")
    for name, door in (routes.get("doors") or {}).items():
        add(str(door["file"]), f"doors.{name}")
        for job_name, target in (door.get("jobs") or {}).items():
            add(str(target), f"doors.{name}.{job_name}")
    for name, gate in (routes.get("gates") or {}).items():
        add(str((gate or {}).get("file") or ""), f"gates.{name}")
    return found


def _norm_stem(raw: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", raw.lower())


def door_stem_index(routes: dict) -> dict[str, str]:
    index: dict[str, str] = {}
    for name, door in (routes.get("doors") or {}).items():
        posix = str(door["file"])
        stems = {
            name,
            name.replace("_", " "),
            name.replace("_", "-"),
            Path(posix).stem,
            Path(posix).stem.replace("-", " "),
        }
        for stem in stems:
            key = _norm_stem(stem)
            if key:
                index[key] = posix
    return index


def skip_door_hits(text: str, posix: str, stems: dict[str, str]) -> list[str]:
    hits: list[str] = []
    seen: set[str] = set()
    for match in SKIP_DOOR_RE.finditer(text):
        key = _norm_stem(match.group(1))
        target = stems.get(key)
        if not target or target == posix:
            continue
        phrase = match.group(0)
        if phrase in seen:
            continue
        seen.add(phrase)
        hits.append(f"{phrase} -> {target}")
    return hits


def on_disk_skills(root: Path) -> set[str]:
    found: set[str] = set()
    skills_root = root / ".grok" / "skills"
    if not skills_root.is_dir():
        return found
    for path in skills_root.rglob("*.md"):
        found.add(rel(path, root))
    return found


def read_when_overlaps(routes: dict) -> list[str]:
    token_doors: dict[str, list[str]] = {}
    for name, door in (routes.get("doors") or {}).items():
        phrase = str(door.get("read_when") or "")
        for raw in READ_WHEN_TOKEN_RE.findall(phrase):
            token = raw.lower()
            if token in READ_WHEN_STOP or len(token) < 3:
                continue
            bucket = token_doors.setdefault(token, [])
            if name not in bucket:
                bucket.append(name)
    fails: list[str] = []
    for token, names in sorted(token_doors.items()):
        if len(names) > 1:
            fails.append(f"read_when overlap {token!r}: {names}")
    return fails


def citation_budget_fails(routes: dict, texts: dict[str, str]) -> list[str]:
    fails: list[str] = []
    for posix, text in sorted(texts.items()):
        role = role_of(routes, posix)
        max_n = CITE_BUDGET.get(role)
        if max_n is None:
            continue
        named = {p for p in citations(text) if p != posix}
        if len(named) > max_n:
            fails.append(
                f"citation budget exceeded for role {role}: {posix} "
                f"has {len(named)} cites (max {max_n}) -> {sorted(named)}"
            )
    return fails


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Check design-doc routing against design/routes.yaml."
    )
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    if not (root / "AGENTS.md").is_file() or not (root / "design").is_dir():
        print(f"FAIL  not a WDB root: {root}", file=sys.stderr)
        return 2

    try:
        routes = load_routes(root)
    except RoutesError as exc:
        print(f"FAIL  routes.yaml: {exc}", file=sys.stderr)
        return 2

    fails: list[str] = []
    known = all_route_files(routes)
    on_disk = {rel(p, root) for p in scanned_md_files(root)}
    extra_on_disk = sorted(
        p for p in on_disk if p not in known and p != "design/routes.yaml"
    )
    missing = sorted(p for p in known if p not in on_disk)
    if extra_on_disk:
        for posix in extra_on_disk:
            fails.append(f"unclassified markdown: {posix}")
    if missing:
        for posix in missing:
            fails.append(f"routes.yaml names missing file: {posix}")

    door_files: dict[str, str] = {}
    job_owner: dict[str, str] = {}
    job_key_owner: dict[str, str] = {}
    for name, door in (routes.get("doors") or {}).items():
        f = str(door["file"])
        if f in door_files:
            fails.append(f"duplicate door file: {f} ({door_files[f]}, {name})")
        door_files[f] = name
        for job_name, target in (door.get("jobs") or {}).items():
            t = str(target)
            if t in job_owner:
                fails.append(
                    f"job target {t} owned by {job_owner[t]} and {name}.{job_name}"
                )
            job_owner[t] = f"{name}.{job_name}"
            if job_name in job_key_owner:
                fails.append(
                    f"duplicate job key {job_name!r}: {job_key_owner[job_name]} and {name}"
                )
            else:
                job_key_owner[job_name] = name

    path_files = {
        str(v) for v in ((routes.get("boot") or {}).get("paths") or {}).values()
    }
    recipe_files = {str(v) for v in (routes.get("recipes") or {}).values()}
    for src in recipe_files:
        if src in path_files:
            fails.append(f"recipe is a path file: {src}")

    bot_targets = {str(v) for v in (routes.get("bot_jobs") or {}).values()}
    if set(bot_targets) & set(door_files):
        fails.append("bot job reuses a topic door file")

    gate_files = {
        str((gate or {}).get("file"))
        for gate in (routes.get("gates") or {}).values()
        if (gate or {}).get("file")
    }
    dual = sorted(set(job_owner) & gate_files)
    if dual:
        fails.append(f"file is both a door job and a gate: {dual}")

    parked = parked_job_files(routes)
    for posix in sorted(parked):
        if role_of(routes, posix) != "job":
            fails.append(f"parked_jobs entry is not a door job: {posix}")
    for target, owner in job_owner.items():
        if PARKED_NAME_RE.search(target) or PARKED_NAME_RE.search(owner):
            if target not in parked:
                fails.append(f"parked job unmarked in parked_jobs: {target}")

    listed_skills = skill_files(routes)
    disk_skills = on_disk_skills(root)
    for posix in sorted(disk_skills - listed_skills):
        fails.append(f"unclassified skill markdown: {posix}")
    for posix in sorted(listed_skills - disk_skills):
        fails.append(f"skills: names missing file: {posix}")

    for posix, tags in sorted(route_memberships(routes).items()):
        meaningful = [t for t in tags if t != "parked_jobs"]
        if len(meaningful) > 1:
            fails.append(f"file has multiple route roles: {posix} -> {meaningful}")

    fails.extend(read_when_overlaps(routes))

    door_stems = door_stem_index(routes)
    files = scanned_md_files(root)
    texts: dict[str, str] = {}
    for path in files:
        posix = rel(path, root)
        text = path.read_text(encoding="utf-8")
        texts[posix] = text
        if SEE_ALSO_RE.search(text):
            fails.append(f"See also field present: {posix}")
        if re.search(r"\bGDD\b|Demo_GDD\.md", text):
            fails.append(f"leftover GDD token: {posix}")
        if re.search(r"notes/[A-Za-z0-9]", text):
            fails.append(f"names notes/ file: {posix}")
        if posix == "design/doc-refactor.md" and re.search(
            r"See also", text, re.I
        ):
            fails.append("doc-refactor.md still tells facades to keep See also")

        role = role_of(routes, posix)
        if role in {"door", "job"}:
            for hit in skip_door_hits(text, posix, door_stems):
                fails.append(f"skip-door phrase: {posix} ({hit})")
        if role == "unknown":
            continue

        table_paths = job_table_paths(text)
        body_paths = body_citations(text)
        allowed = allowed_citations(routes, posix)

        if role == "door":
            expected = door_job_targets(routes, posix)
            if expected and not table_paths:
                fails.append(f"door missing Job table: {posix}")
            unexpected = [p for p in table_paths if p not in expected and p != posix]
            if unexpected:
                fails.append(
                    f"Job table not in routes.yaml: {posix} -> {unexpected}"
                )
            missing_jobs = sorted(expected - set(table_paths))
            if missing_jobs:
                fails.append(
                    f"Job table missing routes.yaml jobs: {posix} -> {missing_jobs}"
                )
            stray = [p for p in body_paths if p != posix]
            if stray:
                fails.append(f"topic body names design doc: {posix} -> {stray}")
            continue

        if role == "job":
            stray = [p for p in body_paths + table_paths if p != posix]
            if stray:
                fails.append(f"topic body names design doc: {posix} -> {stray}")
            continue

        named = [p for p in body_paths + table_paths if p != posix]
        illegal = [p for p in named if p not in allowed]
        if illegal:
            fails.append(
                f"citation not allowed for role {role}: {posix} -> {illegal}"
            )

        if role == "recipe":
            leaked = [p for p in named if p in path_files]
            if leaked:
                fails.append(f"recipe names path file: {posix} -> {leaked}")
            bot_hit = [p for p in named if p in bot_targets]
            if bot_hit:
                fails.append(f"recipe names bot job: {posix} -> {bot_hit}")

        if role == "index" and posix == "design/README.md":
            if "design/code-map.md" in named and re.search(
                r"Live scripts, scenes, and tools:\s*`design/code-map\.md`",
                text,
            ):
                fails.append("README.md points at code-map.md as the live-path fetch")
        if role == "index" and posix == "design/code-map.md":
            if "Topic index: `design/README.md`" in text:
                fails.append("code-map.md points at README.md as the topic-index fetch")
            if "| Staged Bot reuse brief |" in text:
                fails.append("code-map.md still has a design-doc system row: reuse-map")
            if "| Isolated media (CLI) |" in text:
                fails.append(
                    "code-map.md still has a design-doc system row: isolated-media"
                )

        if posix == "design/sessions.md":
            m = re.search(r"^Read when:\s*(.*)$", text, re.I | re.M)
            rw = (m.group(1) if m else "").lower()
            if "fresh" in rw and "instance" in rw:
                fails.append(
                    "sessions.md Read when still boots a fresh Grok Build instance"
                )
            if "design/grok-build.md" in text:
                fails.append("sessions.md names the Build path file")
            if "design/web-session.md" in text:
                fails.append("sessions.md names the web path file")
        if posix == "notes" or posix.startswith("notes/"):
            fails.append(f"agent-facing scan hit notes/: {posix}")
        if posix == "design/load-graph.md":
            if "not enough to pick the next file" in text:
                fails.append(
                    "load-graph.md Read when still licenses a routing crawl"
                )
        if posix == "design/player.md":
            if "design/art-i2v.md" in text:
                fails.append("player.md still names art-i2v.md (skip-door)")
            if "design/art-pack.md" in text:
                fails.append("player.md still names art-pack.md (skip-door)")
        if posix == "design/grok-build.md":
            if "one row in `design/README.md`" in text:
                fails.append("grok-build.md Read order still fetches README.md")
        if posix == "design/web-session.md":
            if "sessions.md` is context only" in text:
                fails.append("web-session.md still treats sessions.md as context")

    fails.extend(citation_budget_fails(routes, texts))
    for cyc in citation_cycles(routes, texts):
        loop = " -> ".join(list(cyc) + [cyc[0]])
        fails.append(f"citation cycle: {loop}")

    n = len(files)
    if fails:
        print(f"FAIL  {len(fails)} load-graph issue(s) across {n} files")
        for line in fails:
            print(f"  - {line}")
        return 1
    print(f"PASS  {n} files, routes.yaml ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())