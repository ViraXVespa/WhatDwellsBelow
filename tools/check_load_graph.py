#!/usr/bin/env python3
"""Check design-doc routing against design/routes.yaml.

    python tools/check_load_graph.py
    python tools/check_load_graph.py --root .

Exit 0 if every check passes. Exit 1 and print FAIL lines otherwise.
Exit 2 if the tree is not a WDB root or routes.yaml cannot be parsed.

Increment 4: door read_when phrases must not share content tokens;
protocol-family files must stay under a citation budget.

Increment 5: stem read_when tokens; treat "the X topic/sibling/job" as
skip-door on door/job files; ban index files from citing door/job paths;
built-in fetch-ban phrases; topic-body cycle graph.

Increment 6: require job_read_when, job_parked, conflicts_with, boot_max,
and fetch_ban in routes.yaml; parked jobs stay out of live Job tables.
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
    TOPIC_CYCLE_ROLES,
    RoutesError,
    allowed_citations,
    all_route_files,
    boot_max,
    conflicts_with,
    door_job_targets,
    fetch_ban,
    increment6_missing_keys,
    job_index,
    job_parked_ids,
    job_read_when,
    load_routes,
    parked_job_files,
    resolve_route_ref,
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
SKIP_DOOR_RE = re.compile(
    r"\bthe\s+([a-z0-9][a-z0-9 _/-]{1,40}?)\s+(?:door|topic|sibling|job)\b",
    re.I,
)
PARKED_NAME_RE = re.compile(r"attack.?keyframe", re.I)
READ_WHEN_TOKEN_RE = re.compile(r"[a-z0-9]+", re.I)
NEGATE_LINE_RE = re.compile(
    r"(?i)^\s*(?:-\s*)?(?:\*\*)?(?:do not|don't|never|must not)\b"
)
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
REQUIRED_BOOT_MAX = {
    "web": (
        "AGENTS.md",
        "design/web-session.md",
        "design/protocol.md",
        "design/constraints.md",
    ),
    "build": (
        "AGENTS.md",
        "design/grok-build.md",
        "design/protocol.md",
        "design/constraints.md",
    ),
    "bot": (
        "AGENTS.md",
        "design/grok-bot-session.md",
    ),
}
BUILTIN_FETCH_BANS = {
    "design/web-session.md": (
        "check against `design/`",
        "check the change against `design/`",
        "reopen the agents file",
        "left context",
    ),
    "design/grok-build.md": (
        "reopen the agents file",
        "left context",
    ),
    "design/grok-bot-session.md": (
        "reopen the agents file",
        "left context",
    ),
    "design/grok-bot-size.md": (
        "reopen the agents file",
        "left context",
    ),
    "design/protocol.md": (
        "topic index (one row): `design/README.md`",
    ),
}
RECIPE_PHRASE_BANS = (
    "Grok Bot every task",
    "open the Bot door",
    "open the Bot path",
)
INDEX_NO_TOPIC = (
    "design/README.md",
    "design/code-map.md",
)


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


def instruct_citations(text: str) -> list[str]:
    found: list[str] = []
    for line in text.splitlines():
        if NEGATE_LINE_RE.search(line):
            continue
        found.extend(citations(line))
    return found


def _normalize_cycle(nodes: list[str]) -> tuple[str, ...]:
    i = nodes.index(min(nodes))
    return tuple(nodes[i:] + nodes[:i])


def _dfs_cycles(graph: dict[str, set[str]]) -> list[tuple[str, ...]]:
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
    return _dfs_cycles(graph)


def topic_cycles(
    routes: dict, texts: dict[str, str], stems: dict[str, str]
) -> list[tuple[str, ...]]:
    graph: dict[str, set[str]] = {}
    for posix, text in texts.items():
        if role_of(routes, posix) not in TOPIC_CYCLE_ROLES:
            continue
        graph.setdefault(posix, set())
        for dest in set(body_citations(text)):
            if dest == posix:
                continue
            if role_of(routes, dest) in TOPIC_CYCLE_ROLES:
                graph[posix].add(dest)
        if role_of(routes, posix) in {"door", "job"}:
            for hit in skip_door_hits(text, posix, stems):
                dest = hit.split(" -> ", 1)[-1]
                if dest and dest != posix:
                    graph[posix].add(dest)
    return _dfs_cycles(graph)


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


def stem_token(token: str) -> str:
    word = token.lower()
    if word.endswith("ies") and len(word) > 4:
        return word[:-3] + "y"
    if word.endswith("sses"):
        return word[:-2]
    if word.endswith("es") and len(word) > 4:
        return word[:-2]
    if word.endswith("s") and not word.endswith("ss") and len(word) > 3:
        return word[:-1]
    return word


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


def _phrase_tokens(phrase: str) -> set[str]:
    tokens: set[str] = set()
    for raw in READ_WHEN_TOKEN_RE.findall(phrase):
        token = stem_token(raw)
        if token in READ_WHEN_STOP or len(token) < 3:
            continue
        tokens.add(token)
    return tokens


def read_when_overlaps(routes: dict) -> list[str]:
    token_owners: dict[str, list[str]] = {}
    for name, door in (routes.get("doors") or {}).items():
        phrase = str(door.get("read_when") or "")
        for token in _phrase_tokens(phrase):
            bucket = token_owners.setdefault(token, [])
            owner = f"door:{name}"
            if owner not in bucket:
                bucket.append(owner)
    for jid, phrase in job_read_when(routes).items():
        for token in _phrase_tokens(phrase):
            bucket = token_owners.setdefault(token, [])
            owner = f"job:{jid}"
            if owner not in bucket:
                bucket.append(owner)
    fails: list[str] = []
    for token, names in sorted(token_owners.items()):
        if len(names) > 1:
            fails.append(f"read_when overlap {token!r}: {names}")
    return fails


def conflict_fails(routes: dict) -> list[str]:
    fails: list[str] = []
    phrases: dict[str, str] = {}
    for name, door in (routes.get("doors") or {}).items():
        phrases[name] = str(door.get("read_when") or "")
    for jid, phrase in job_read_when(routes).items():
        phrases[jid] = phrase
    for src, targets in conflicts_with(routes).items():
        src_path = resolve_route_ref(routes, src)
        if src not in phrases and not src_path:
            fails.append(f"conflicts_with unknown source: {src}")
            continue
        src_tokens = _phrase_tokens(phrases.get(src, ""))
        for dest in targets:
            dest_path = resolve_route_ref(routes, dest)
            if dest not in phrases and not dest_path:
                fails.append(f"conflicts_with unknown target: {src} -> {dest}")
                continue
            dest_tokens = _phrase_tokens(phrases.get(dest, ""))
            shared = sorted(src_tokens & dest_tokens)
            if shared:
                fails.append(
                    f"conflicts_with shared tokens {src} ~ {dest}: {shared}"
                )
    return fails


def increment6_schema_fails(routes: dict) -> list[str]:
    fails: list[str] = []
    for key in increment6_missing_keys(routes):
        fails.append(f"routes.yaml missing {key}")
    idx = job_index(routes)
    expected_ids = set(idx["by_id"])
    listed = job_read_when(routes)
    if "job_read_when" in routes:
        missing = sorted(expected_ids - set(listed))
        extra = sorted(set(listed) - expected_ids)
        if missing:
            fails.append(f"job_read_when missing jobs: {missing}")
        if extra:
            fails.append(f"job_read_when unknown jobs: {extra}")
    parked_ids = job_parked_ids(routes)
    if "job_parked" in routes:
        bad = [jid for jid in parked_ids if jid not in idx["by_id"]]
        if bad:
            fails.append(f"job_parked unknown jobs: {bad}")
        from_ids = {idx["by_id"][jid] for jid in parked_ids if jid in idx["by_id"]}
        listed_files = {str(v) for v in (routes.get("parked_jobs") or [])}
        if listed_files != from_ids:
            fails.append(
                "parked_jobs and job_parked do not name the same files: "
                f"files={sorted(listed_files)} ids={sorted(from_ids)}"
            )
    listed_boot = boot_max(routes)
    if "boot_max" in routes:
        for name, required in REQUIRED_BOOT_MAX.items():
            have = listed_boot.get(name)
            if have is None:
                fails.append(f"boot_max missing path {name}")
                continue
            absent = [item for item in required if item not in have]
            if absent:
                fails.append(f"boot_max.{name} missing {absent}")
    return fails


def boot_instruct_fails(routes: dict, texts: dict[str, str]) -> list[str]:
    fails: list[str] = []
    listed = boot_max(routes)
    if not listed:
        return fails
    path_map = (routes.get("boot") or {}).get("paths") or {}
    recipes = {str(v) for v in (routes.get("recipes") or {}).values()}
    gates = {
        str((gate or {}).get("file") or "")
        for gate in (routes.get("gates") or {}).values()
    }
    notes = {str(v) for v in (routes.get("notes_exempt") or [])}
    indexes = {str(v) for v in (routes.get("indexes") or {}).values()}
    bot_jobs = {str(v) for v in (routes.get("bot_jobs") or {}).values()}
    skills = skill_files(routes)
    for name, posix in path_map.items():
        posix = str(posix)
        text = texts.get(posix)
        if text is None:
            continue
        allowed = set(listed.get(name) or [])
        allowed |= recipes | gates | notes | indexes | skills | {posix}
        if name == "bot":
            allowed |= bot_jobs
        extra = sorted(
            {
                cite
                for cite in instruct_citations(text)
                if cite != posix and cite not in allowed
            }
        )
        if extra:
            fails.append(f"boot instruct outside boot_max.{name}: {posix} -> {extra}")
    return fails


def fetch_ban_fails(routes: dict, texts: dict[str, str]) -> list[str]:
    fails: list[str] = []
    merged: dict[str, list[str]] = {}
    for posix, phrases in BUILTIN_FETCH_BANS.items():
        merged.setdefault(posix, [])
        for phrase in phrases:
            if phrase not in merged[posix]:
                merged[posix].append(phrase)
    for posix, phrases in fetch_ban(routes).items():
        merged.setdefault(posix, [])
        for phrase in phrases:
            if phrase not in merged[posix]:
                merged[posix].append(phrase)
    for posix, phrases in sorted(merged.items()):
        text = texts.get(posix)
        if text is None:
            continue
        lowered = text.lower()
        for phrase in phrases:
            if phrase.lower() in lowered:
                fails.append(f"fetch-ban phrase in {posix}: {phrase}")
    return fails


def recipe_phrase_fails(routes: dict, texts: dict[str, str]) -> list[str]:
    fails: list[str] = []
    recipe_files = {str(v) for v in (routes.get("recipes") or {}).values()}
    for posix in sorted(recipe_files):
        text = texts.get(posix)
        if text is None:
            continue
        lowered = text.lower()
        for phrase in RECIPE_PHRASE_BANS:
            if phrase.lower() in lowered:
                fails.append(f"recipe names bot flow: {posix} ({phrase})")
    return fails


def smash_fails(root: Path, texts: dict[str, str]) -> list[str]:
    fails: list[str] = []
    for posix, body in texts.items():
        if posix.startswith("design/changelog/"):
            continue
        if "_/_" in body or "_in_the_" in body:
            fails.append(f"smashed skip-door phrase: {posix}")
    return fails


def index_topic_cite_fails(routes: dict, texts: dict[str, str]) -> list[str]:
    fails: list[str] = []
    topic = set()
    for door in (routes.get("doors") or {}).values():
        topic.add(str(door["file"]))
        topic.update(str(v) for v in (door.get("jobs") or {}).values())
    for posix in INDEX_NO_TOPIC:
        text = texts.get(posix)
        if text is None:
            continue
        hits = sorted({cite for cite in citations(text) if cite in topic})
        if hits:
            fails.append(f"index cites topic path: {posix} -> {hits}")
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
    if disk_skills and "skills" not in routes:
        fails.append("routes.yaml missing skills")
    for posix in sorted(disk_skills - listed_skills):
        fails.append(f"unclassified skill markdown: {posix}")
    for posix in sorted(listed_skills - disk_skills):
        fails.append(f"skills: names missing file: {posix}")

    for posix, tags in sorted(route_memberships(routes).items()):
        meaningful = [t for t in tags if t != "parked_jobs"]
        if len(meaningful) > 1:
            fails.append(f"file has multiple route roles: {posix} -> {meaningful}")

    fails.extend(increment6_schema_fails(routes))
    fails.extend(read_when_overlaps(routes))
    fails.extend(conflict_fails(routes))

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
            live_expected = expected - parked
            if live_expected and not table_paths:
                fails.append(f"door missing Job table: {posix}")
            unexpected = [p for p in table_paths if p not in expected and p != posix]
            if unexpected:
                fails.append(
                    f"Job table not in routes.yaml: {posix} -> {unexpected}"
                )
            parked_listed = sorted(set(table_paths) & parked)
            if parked_listed:
                fails.append(
                    f"parked job listed as live Open path: {posix} -> {parked_listed}"
                )
            missing_jobs = sorted(live_expected - set(table_paths))
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

    fails.extend(index_topic_cite_fails(routes, texts))
    fails.extend(smash_fails(root, texts))
    fails.extend(fetch_ban_fails(routes, texts))
    fails.extend(recipe_phrase_fails(routes, texts))
    fails.extend(boot_instruct_fails(routes, texts))
    fails.extend(citation_budget_fails(routes, texts))
    for cyc in citation_cycles(routes, texts):
        loop = " -> ".join(list(cyc) + [cyc[0]])
        fails.append(f"citation cycle: {loop}")
    for cyc in topic_cycles(routes, texts, door_stems):
        loop = " -> ".join(list(cyc) + [cyc[0]])
        fails.append(f"topic citation cycle: {loop}")

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
