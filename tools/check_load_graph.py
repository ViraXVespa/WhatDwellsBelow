#!/usr/bin/env python3
"""Check design-doc routing against design/routes.yaml.

    python tools/check_load_graph.py
    python tools/check_load_graph.py --root .

Exit 0 if every check passes. Exit 1 and print FAIL lines otherwise.
Exit 2 if the tree is not a WDB root or routes.yaml cannot be parsed.

Navigation lives only in design/routes.yaml. Topic bodies (doors and job
siblings) may not name design/*.md, AGENTS.md, or Demo_GDD.md except:
  - the file's own path
  - a door Job-table Open cell that matches that door's jobs in routes.yaml
  - design/changelog/ paths (ship labels, not topic routing)

`See also:` is forbidden on every scanned markdown file.
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
    RoutesError,
    allowed_citations,
    all_route_files,
    door_job_targets,
    load_routes,
    role_of,
)

CHANGELOG_PREFIX = "design/changelog/"
CITE_RE = re.compile(
    r"(?:`)?((?:design/[\w./-]+\.md)|AGENTS\.md|Demo_GDD\.md)(?:`)?"
)
SEE_ALSO_RE = re.compile(r"^See also\s*:", re.I | re.M)
JOB_HEAD_RE = re.compile(r"^\|\s*Job\s*\|", re.I)
JOB_DIV_RE = re.compile(r"^\|\s*-+")


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
    for extra in ("AGENTS.md", "Demo_GDD.md"):
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
    """Citations outside a Job table."""
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

    files = scanned_md_files(root)
    for path in files:
        posix = rel(path, root)
        text = path.read_text(encoding="utf-8")
        if SEE_ALSO_RE.search(text):
            fails.append(f"See also field present: {posix}")

        role = role_of(routes, posix)
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
            fails.append(f"citation not in routes.yaml: {posix} -> {illegal}")

        if role == "recipe":
            leaked = [p for p in named if p in path_files]
            if leaked:
                fails.append(f"recipe names path file: {posix} -> {leaked}")

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