#!/usr/bin/env python3
"""Check design-doc load-graph rules. Run from the repo root.

    python tools/check_load_graph.py
    python tools/check_load_graph.py --root .

Exit 0 if every check passes. Exit 1 and print FAIL lines otherwise.

See also edges are only the rest of the `See also:` header line, and only
when that line is a path list. A sentence on that line (or below it) that
names a `.md` file is prose, not an edge.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PATH_FILES = {
    "AGENTS.md",
    "design/web-session.md",
    "design/grok-build.md",
    "design/grok-bot-session.md",
}

INDEX_FILES = {
    "design/README.md",
    "design/code-map.md",
    "design/load-graph.md",
    "Demo_GDD.md",
}

PROSE_ON_SEE_ALSO = re.compile(
    r"\b(the|this|do not|don't|binding|recipe|ship|load cap|already open)\b",
    re.I,
)


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def design_md_files(root: Path) -> list[Path]:
    out: list[Path] = []
    design = root / "design"
    if not design.is_dir():
        return out
    for path in sorted(design.rglob("*.md")):
        posix = rel(path, root)
        if posix.startswith("design/changelog/"):
            continue
        out.append(path)
    extra = root / "AGENTS.md"
    if extra.is_file():
        out.append(extra)
    demo = root / "Demo_GDD.md"
    if demo.is_file():
        out.append(demo)
    return out


def header_block(text: str) -> str:
    lines = text.splitlines()
    chunk: list[str] = []
    started = False
    for line in lines[1:]:
        if line.startswith("## "):
            break
        if line.startswith("| Job |") or line.startswith("| Job|"):
            break
        if line.startswith("# "):
            break
        if not started and not line.strip():
            continue
        started = True
        chunk.append(line)
        if len(chunk) > 40:
            break
    return "\n".join(chunk)


def field(block: str, name: str) -> str:
    """Only the rest of the matching header line. Following lines are not edges."""
    pat = re.compile(
        rf"^{re.escape(name)}:\s*(.*)$",
        re.IGNORECASE | re.MULTILINE,
    )
    m = pat.search(block)
    if not m:
        return ""
    return m.group(1).strip()


def cited_paths(blob: str) -> list[str]:
    found = re.findall(r"`([^`]+)`", blob)
    out: list[str] = []
    for item in found:
        item = item.strip()
        if item.endswith(".md") or item == "AGENTS.md" or item.startswith("design/"):
            if (
                not item.startswith("design/")
                and item.endswith(".md")
                and item != "AGENTS.md"
                and item != "Demo_GDD.md"
            ):
                item = "design/" + item
            out.append(item)
    return out


def see_also_paths(raw: str) -> list[str]:
    raw = raw.strip()
    if not raw:
        return []
    if PROSE_ON_SEE_ALSO.search(raw):
        return []
    return cited_paths(raw)


def parse_file(path: Path, root: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    block = header_block(text)
    see = field(block, "See also")
    read_when = field(block, "Read when")
    has_job = bool(re.search(r"^\| Job \|", text, re.M))
    posix = rel(path, root)
    return {
        "path": posix,
        "text": text,
        "see": see,
        "see_paths": see_also_paths(see),
        "read_when": read_when,
        "has_job": has_job,
    }


def is_sibling(posix: str) -> bool:
    name = Path(posix).name
    if posix.startswith("design/grok-bot-") and name != "grok-bot-session.md":
        return True
    if posix.startswith("design/art-") and name != "art-pipeline.md":
        return True
    if posix.startswith("design/ui-"):
        return True
    if posix.startswith("design/debug-"):
        return True
    if posix.startswith("design/input-"):
        return True
    if posix.startswith("design/inventory-"):
        return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description="Check design-doc load-graph rules.")
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    if not (root / "AGENTS.md").is_file() or not (root / "design").is_dir():
        print(f"FAIL  not a WDB root: {root}", file=sys.stderr)
        return 2

    parsed = [parse_file(p, root) for p in design_md_files(root)]
    by_path = {row["path"]: row for row in parsed}
    fails: list[str] = []

    see_map = {row["path"]: set(row["see_paths"]) for row in parsed}
    seen_pairs: set[tuple[str, str]] = set()
    for src, dests in see_map.items():
        for dest in dests:
            if dest not in see_map:
                continue
            if src in see_map[dest]:
                pair = tuple(sorted((src, dest)))
                if pair in seen_pairs:
                    continue
                seen_pairs.add(pair)
                fails.append(f"mutual See also: {pair[0]} <-> {pair[1]}")

    for row in parsed:
        if is_sibling(row["path"]) and row["see_paths"]:
            fails.append(
                f"sibling See also not empty: {row['path']} -> {row['see_paths']}"
            )

    for row in parsed:
        if not row["has_job"]:
            continue
        topic = [
            p
            for p in row["see_paths"]
            if p not in PATH_FILES and p not in INDEX_FILES
        ]
        if len(topic) > 1:
            fails.append(f"door See also >1 topic: {row['path']} -> {topic}")

    for row in parsed:
        if row["path"] in PATH_FILES or row["path"] in INDEX_FILES:
            continue
        leaked = [p for p in row["see_paths"] if p in PATH_FILES]
        if leaked:
            fails.append(f"path file on topic See also: {row['path']} -> {leaked}")

    readme = by_path.get("design/README.md", {})
    code_map = by_path.get("design/code-map.md", {})
    if readme:
        if re.search(
            r"Live scripts, scenes, and tools:\s*`design/code-map\.md`",
            readme["text"],
        ):
            fails.append("README.md points at code-map.md as the live-path fetch")
    if code_map:
        if "Topic index: `design/README.md`" in code_map["text"]:
            fails.append("code-map.md points at README.md as the topic-index fetch")
        if "| Staged Bot reuse brief |" in code_map["text"]:
            fails.append("code-map.md still has a design-doc system row: reuse-map")
        if "| Isolated media (CLI) |" in code_map["text"]:
            fails.append("code-map.md still has a design-doc system row: isolated-media")

    sessions = by_path.get("design/sessions.md")
    if sessions:
        rw = sessions["read_when"].lower()
        if "fresh" in rw and "instance" in rw:
            fails.append(
                "sessions.md Read when still boots a fresh Grok Build instance"
            )

    lg = by_path.get("design/load-graph.md")
    if lg and "not enough to pick the next file" in lg["text"]:
        fails.append("load-graph.md Read when still licenses a routing crawl")

    player = by_path.get("design/player.md")
    if player and "design/art-i2v.md" in player["text"]:
        fails.append("player.md still names art-i2v.md (skip-door)")
    if player and "design/art-pack.md" in player["text"]:
        fails.append("player.md still names art-pack.md (skip-door)")

    for recipe in (
        "design/refactor.md",
        "design/doc-refactor.md",
        "design/pc-offload.md",
    ):
        row = by_path.get(recipe)
        if not row:
            continue
        if recipe == "design/refactor.md" and row["see_paths"]:
            fails.append(f"{recipe} See also must be empty")
        if (
            "design/web-session.md" in row["text"]
            and "Cap still applies in Phase 6 per" in row["text"]
        ):
            fails.append(f"{recipe} still loads web-session.md")

    build = by_path.get("design/grok-build.md")
    if build and "one row in `design/README.md`" in build["text"]:
        fails.append("grok-build.md Read order still fetches README.md")

    web = by_path.get("design/web-session.md")
    if web and "sessions.md` is context only" in web["text"]:
        fails.append("web-session.md still treats sessions.md as context")

    overview = by_path.get("design/overview.md")
    if overview and overview["see_paths"]:
        fails.append(f"overview.md See also not empty: {overview['see_paths']}")
    coverage = by_path.get("design/coverage.md")
    if coverage and coverage["read_when"].lower() == "deciding whether a system is missing":
        fails.append("coverage.md Read when is still the broad missing-system trigger")
    tunables = by_path.get("design/tunables.md")
    if tunables and "changing feel, gen size" in tunables["read_when"]:
        fails.append("tunables.md Read when still pretends to be a topic door")

    for name in (
        "design/dungeon.md",
        "design/enemies.md",
        "design/combat.md",
        "design/skills.md",
        "design/camera.md",
        "design/feel.md",
        "design/interactables.md",
        "design/hub.md",
        "design/save-tech.md",
        "design/audio-visual.md",
    ):
        row = by_path.get(name)
        if row and row["see_paths"]:
            fails.append(f"{name} See also not empty: {row['see_paths']}")

    n = len(parsed)
    if fails:
        print(f"FAIL  {len(fails)} load-graph issue(s) across {n} files")
        for line in fails:
            print(f"  - {line}")
        return 1
    print(f"PASS  {n} files, no load-graph rule breaks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())