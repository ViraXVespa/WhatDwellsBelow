#!/usr/bin/env python3
"""Load design/routes.yaml (constrained YAML subset, stdlib only)."""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any


ROUTES_REL = "design/routes.yaml"

_KEY = re.compile(r"^([A-Za-z0-9_]+):\s*(.*)$")
_ITEM = re.compile(r"^- \s*(.*)$")

CYCLE_ROLES = frozenset(
    {"agents", "path", "requires", "recipe", "bot_job", "gate"}
)


class RoutesError(ValueError):
    pass


def _parse_scalar(raw: str) -> Any:
    raw = raw.strip()
    if raw == "" or raw == "|" or raw == ">":
        return ""
    if raw in ("[]",):
        return []
    if raw in ("{}",):
        return {}
    if raw in ("null", "~"):
        return None
    if raw == "true":
        return True
    if raw == "false":
        return False
    if (raw.startswith('"') and raw.endswith('"')) or (
        raw.startswith("'") and raw.endswith("'")
    ):
        return raw[1:-1]
    return raw


def parse_constrained_yaml(text: str) -> dict[str, Any]:
    """Map/list YAML with 2-space indent. No anchors, tags, or flow maps."""
    raw_lines = text.splitlines()
    lines: list[tuple[int, str]] = []
    for idx, line in enumerate(raw_lines, start=1):
        if line.strip() == "" or line.lstrip().startswith("#"):
            continue
        expanded = line.replace("\t", "  ")
        indent = len(expanded) - len(expanded.lstrip(" "))
        if indent % 2 != 0:
            raise RoutesError(f"line {idx}: indent must be a multiple of 2")
        lines.append((indent, expanded.lstrip(" ")))

    def parse_block(start: int, min_indent: int) -> tuple[Any, int]:
        if start >= len(lines):
            return {}, start
        indent, content = lines[start]
        if indent < min_indent:
            return {}, start
        if content.startswith("- "):
            return parse_list(start, indent)
        return parse_map(start, indent)

    def parse_map(start: int, indent: int) -> tuple[dict[str, Any], int]:
        out: dict[str, Any] = {}
        i = start
        while i < len(lines):
            ind, content = lines[i]
            if ind < indent:
                break
            if ind > indent:
                raise RoutesError(f"unexpected indent at {content!r}")
            m = _KEY.match(content)
            if not m:
                raise RoutesError(f"expected key: at {content!r}")
            key, rest = m.group(1), m.group(2).strip()
            if rest:
                out[key] = _parse_scalar(rest)
                i += 1
                continue
            child, i = parse_block(i + 1, indent + 2)
            out[key] = child
        return out, i

    def parse_list(start: int, indent: int) -> tuple[list[Any], int]:
        out: list[Any] = []
        i = start
        while i < len(lines):
            ind, content = lines[i]
            if ind < indent:
                break
            if ind > indent:
                raise RoutesError(f"unexpected indent at {content!r}")
            m = _ITEM.match(content)
            if not m:
                break
            rest = m.group(1).strip()
            if rest and not _KEY.match(rest):
                out.append(_parse_scalar(rest))
                i += 1
                continue
            if rest and _KEY.match(rest):
                nested, i2 = parse_map_from_inline(rest, i + 1, indent + 2)
                out.append(nested)
                i = i2
                continue
            child, i = parse_block(i + 1, indent + 2)
            out.append(child)
        return out, i

    def parse_map_from_inline(
        first: str, start: int, child_indent: int
    ) -> tuple[dict[str, Any], int]:
        m = _KEY.match(first)
        if not m:
            raise RoutesError(f"bad list map item {first!r}")
        key, rest = m.group(1), m.group(2).strip()
        node: dict[str, Any] = {key: _parse_scalar(rest) if rest else {}}
        more, i = parse_map(start, child_indent)
        node.update(more)
        return node, i

    data, end = parse_map(0, 0)
    if end != len(lines):
        raise RoutesError(f"unparsed trailing content at {lines[end][1]!r}")
    if not isinstance(data, dict):
        raise RoutesError("root must be a mapping")
    return data


def load_routes(root: Path) -> dict[str, Any]:
    path = root / ROUTES_REL
    if not path.is_file():
        raise RoutesError(f"missing {ROUTES_REL}")
    text = path.read_text(encoding="utf-8")
    data = parse_constrained_yaml(text)
    if int(data.get("version", 0)) != 1:
        raise RoutesError("routes.yaml version must be 1")
    return data


def all_route_files(data: dict[str, Any]) -> set[str]:
    files: set[str] = set()
    boot = data.get("boot") or {}
    files.add(str(boot.get("agents") or "AGENTS.md"))
    paths = boot.get("paths") or {}
    files.update(str(v) for v in paths.values())
    req = data.get("requires") or {}
    for items in req.values():
        files.update(str(v) for v in (items or []))
    indexes = data.get("indexes") or {}
    files.update(str(v) for v in indexes.values())
    for door in (data.get("doors") or {}).values():
        files.add(str(door["file"]))
        jobs = door.get("jobs") or {}
        files.update(str(v) for v in jobs.values())
    for gate in (data.get("gates") or {}).values():
        files.add(str(gate["file"]))
    recipes = data.get("recipes") or {}
    files.update(str(v) for v in recipes.values())
    bot_jobs = data.get("bot_jobs") or {}
    files.update(str(v) for v in bot_jobs.values())
    files.update(str(v) for v in (data.get("notes_exempt") or []))
    files.update(str(v) for v in (data.get("parked_jobs") or []))
    skills = data.get("skills") or {}
    if isinstance(skills, dict):
        files.update(str(v) for v in skills.values())
    return files


def role_of(data: dict[str, Any], posix: str) -> str:
    boot = data.get("boot") or {}
    if posix == str(boot.get("agents") or "AGENTS.md"):
        return "agents"
    if posix in {str(v) for v in (boot.get("paths") or {}).values()}:
        return "path"
    req_files = set()
    for items in (data.get("requires") or {}).values():
        req_files.update(str(v) for v in (items or []))
    if posix in req_files:
        return "requires"
    if posix in {str(v) for v in (data.get("indexes") or {}).values()}:
        return "index"
    if posix in {str(v) for v in (data.get("recipes") or {}).values()}:
        return "recipe"
    if posix in {str(v) for v in (data.get("bot_jobs") or {}).values()}:
        return "bot_job"
    if posix in {str(v) for v in (data.get("notes_exempt") or [])}:
        return "notes"
    skills = data.get("skills") or {}
    if isinstance(skills, dict) and posix in {str(v) for v in skills.values()}:
        return "skill"
    for door in (data.get("doors") or {}).values():
        if posix == str(door["file"]):
            return "door"
        if posix in {str(v) for v in (door.get("jobs") or {}).values()}:
            return "job"
    for gate in (data.get("gates") or {}).values():
        if posix == str(gate["file"]):
            return "gate"
    return "unknown"


def role_sets(data: dict[str, Any]) -> dict[str, set[str]]:
    grouped: dict[str, set[str]] = {}
    for posix in all_route_files(data):
        grouped.setdefault(role_of(data, posix), set()).add(posix)
    return grouped


def door_job_targets(data: dict[str, Any], door_file: str) -> set[str]:
    for door in (data.get("doors") or {}).values():
        if str(door["file"]) == door_file:
            return {str(v) for v in (door.get("jobs") or {}).values()}
    return set()


def parked_job_files(data: dict[str, Any]) -> set[str]:
    return {str(v) for v in (data.get("parked_jobs") or [])}


def skill_files(data: dict[str, Any]) -> set[str]:
    skills = data.get("skills") or {}
    if not isinstance(skills, dict):
        return set()
    return {str(v) for v in skills.values()}


def allowed_citations(data: dict[str, Any], posix: str) -> set[str]:
    """Paths this file may name. Topic job/door bodies are handled separately."""
    role = role_of(data, posix)
    grouped = role_sets(data)
    agents = grouped.get("agents", set())
    requires = grouped.get("requires", set())
    indexes = grouped.get("index", set())
    recipes = grouped.get("recipe", set())
    bot_jobs = grouped.get("bot_job", set())
    gates = grouped.get("gate", set())
    notes = grouped.get("notes", set())
    skills = grouped.get("skill", set())
    recipes_map = data.get("recipes") or {}
    pc_offload = (
        {str(recipes_map["pc_offload"])} if recipes_map.get("pc_offload") else set()
    )
    bot_path = str(((data.get("boot") or {}).get("paths") or {}).get("bot") or "")
    reuse_job = str((data.get("bot_jobs") or {}).get("reuse") or "")
    reuse_map = {n for n in notes if n.endswith("reuse-map.md")}

    if role == "agents":
        return (
            agents
            | grouped.get("path", set())
            | requires
            | indexes
            | recipes
            | bot_jobs
            | gates
            | notes
            | skills
        )
    if role == "path":
        allowed = {posix} | requires | indexes | recipes | gates | notes | skills
        if posix == bot_path:
            allowed |= bot_jobs
        return allowed
    if role == "requires":
        return {posix} | requires | indexes | recipes | gates | notes
    if role == "recipe":
        return {posix} | indexes | gates | notes | pc_offload
    if role == "bot_job":
        allowed = {posix} | recipes | indexes | gates
        if posix == reuse_job:
            allowed |= reuse_map
        return allowed
    if role == "gate":
        return {posix} | gates | indexes | notes
    if role == "skill":
        return {posix} | gates | indexes | notes | skills
    if role in {"index", "notes"}:
        return all_route_files(data)
    if role == "door":
        return {posix} | door_job_targets(data, posix)
    if role == "job":
        return {posix}
    return set()