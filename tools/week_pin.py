#!/usr/bin/env python3
"""Add a weekly archive pin to scripts/data/archive_catalog.json (the `archives` rows) and tag the commit.

    python3 tools/week_pin.py --web N   [--commit SHA] [--dry-run]   # grok_web_wN   + tag archive/grok-web-wN
    python3 tools/week_pin.py --build N [--commit SHA] [--dry-run]   # grok_build_wN + tag archive/grok-build-wN
    python3 tools/week_pin.py --id ID --label L --desc D --commit SHA [--dry-run]   # any other row (no tag)
--commit defaults to HEAD. A row that already exists is left alone ("exists", exit 0). The tag is local (the User
pushes tags). --web N copies the changelog notes of series N and --build N those of series N-1 into
archives/docs/<id>/ (from design/changelog/ or design/changelog/archive/); docs[] lists design/ as it is on the
pinned commit plus those copies. Does not bump version.json. Sequence and CI trigger: design/archives-catalog.md.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib


def pin_spec(kind: str, n: int) -> dict:
    web = kind == "web"
    return {
        "id": f"grok_{kind}_w{n}",
        "label": f"Grok {'Web' if web else 'Build'} Results (Week {n})",
        "desc": (f"Live path at the end of Grok Web week {n}." if web else f"Live path at the open of Grok Build week {n} (the series {n} seed commit)."),
        "tag": f"archive/grok-{kind}-w{n}",
        "notes_series": n if web else n - 1,
    }


def design_docs(root: Path, commit: str) -> list[str]:
    """design/ md and yaml paths as they exist on `commit`; the working tree when git cannot list it."""
    code, out = repo_lib.run_git(root, "ls-tree", "-r", "--name-only", commit, "design")
    names = out.splitlines() if code == 0 else [p.relative_to(root).as_posix() for p in sorted((root / "design").rglob("*")) if p.is_file()]
    return [n for n in names if n.lower().endswith((".md", ".yaml", ".yml"))]


def copy_notes(root: Path, epoch: int, series: int, dest: Path, dry: bool) -> list[str]:
    """Copy that series' per-build notes (flat, else archive/{epoch}.{series}/) to `dest`. Returns repo-relative targets."""
    base = repo_lib.changelog_dir(root)
    rx = re.compile(rf"^{epoch}\.{series}\.\d+\.md$")
    srcs = sorted(p for p in base.glob("*.md") if rx.match(p.name)) or sorted(p for p in (base / "archive" / f"{epoch}.{series}").glob("*.md") if rx.match(p.name))
    if not dry:
        dest.mkdir(parents=True, exist_ok=True)
        for p in srcs:
            shutil.copy2(p, dest / p.name)
    return [(dest / p.name).relative_to(root).as_posix() for p in srcs]


def rows_of(data: dict) -> list:
    """The catalog rows the game and the Pages export read: the `archives` list."""
    return data.setdefault("archives", [])


def main() -> int:
    ap = agent_log.std_parser("Add a weekly archive pin (catalog row + local tag) for a commit; does not bump version.json.", writes=True)
    ap.add_argument("--web", type=int, default=0, metavar="N", help="Pin grok_web_wN (the closing week's web results) and tag archive/grok-web-wN.")
    ap.add_argument("--build", type=int, default=0, metavar="N", help="Pin grok_build_wN (the series N seed commit) and tag archive/grok-build-wN.")
    ap.add_argument("--id", default="", help="Row id for a pin that is not a weekly one.")
    ap.add_argument("--label", default="", help="Row label (with --id).")
    ap.add_argument("--desc", default="", help="Row description (with --id).")
    ap.add_argument("--commit", default="", help="Commit to pin (default HEAD).")
    args = ap.parse_args()
    root = agent_log.resolve_root(args)
    modes = [bool(args.web), bool(args.build), bool(args.id)]
    if sum(modes) != 1:
        agent_log.fail("pick one: --web N, --build N, or --id ID --label L --desc D")
    if args.id and not (args.label and args.desc):
        agent_log.fail("--id needs --label and --desc")
    if args.web < 0 or args.build < 0:
        agent_log.fail("N must be a positive week number")
    spec = pin_spec("web", args.web) if args.web else pin_spec("build", args.build) if args.build else \
        {"id": args.id, "label": args.label, "desc": args.desc, "tag": "", "notes_series": None}
    code, head = repo_lib.run_git(root, "rev-parse", "HEAD")
    sha = args.commit or (head if code == 0 else "")
    if not sha:
        agent_log.fail("no commit: pass --commit SHA")
    cat_path = root / "scripts" / "data" / "archive_catalog.json"
    raw = cat_path.read_bytes()
    bom, crlf = raw.startswith(b"\xef\xbb\xbf"), b"\r\n" in raw
    data = json.loads(raw.decode("utf-8-sig"))
    if isinstance(data, list):
        agent_log.fail("archive_catalog.json must be an object with an `archives` list")
    rows = rows_of(data)
    if any(b.get("id") == spec["id"] for b in rows):
        print(f"exists {spec['id']}")
        return agent_log.emit_result("PASS", id=spec["id"], added=0)
    notes: list[str] = []
    if spec["notes_series"] and spec["notes_series"] > 0:
        epoch = int(repo_lib.read_version(root)["epoch"])
        notes = copy_notes(root, epoch, spec["notes_series"], root / "archives" / "docs" / spec["id"], args.dry_run)
    docs = design_docs(root, sha) + notes
    rows.append({"id": spec["id"], "label": spec["label"], "desc": spec["desc"], "commit": sha,
                 "pages_slug": f"archives/{spec['id']}", "video": "", "docs": docs})
    tag = spec["tag"]
    tag_state = "none"
    if tag:
        tag_state = "exists" if repo_lib.run_git(root, "tag", "--list", tag)[1].strip() else ("would-create" if args.dry_run else "created")
    if not args.dry_run:
        text = json.dumps(data, indent="\t") + "\n"
        if crlf:
            text = text.replace("\n", "\r\n")
        cat_path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8"))
        if tag_state == "created":
            repo_lib.run_git(root, "tag", tag, sha)
    verb = "would add" if args.dry_run else "added"
    print(f"{verb} {spec['id']} commit={sha} docs={len(docs)} notes={'would copy ' if args.dry_run else ''}{len(notes)} tag={tag or '-'} ({tag_state})")
    return agent_log.emit_result("PASS", id=spec["id"], added=0 if args.dry_run else 1, would_add=1 if args.dry_run else None,
                                 docs=len(docs), notes=len(notes), tag=tag_state, dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
