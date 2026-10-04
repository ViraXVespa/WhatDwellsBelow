#!/usr/bin/env python3
"""Add a weekly archive pin to scripts/data/archive_catalog.json (the `archives` rows) and tag the commit.

    python tools/week_pin.py --web N   [--commit SHA] [--dry-run]   # grok_web_wN   + tag archive/grok-web-wN
    python tools/week_pin.py --build N [--commit SHA] [--dry-run]   # grok_build_wN + tag archive/grok-build-wN
    python tools/week_pin.py --id ID --label L --desc D --commit SHA [--dry-run]   # any other row (no tag)
--commit defaults to HEAD. Idempotent: a row that exists is left alone and a missing tag is created at the row's
commit ("exists", exit 0). The tag is local; CI (ci_archive.py) pushes it, else the User does. --web N and --build N
both copy the changelog notes of series N into archives/docs/<id>/ (from design/changelog/ or
design/changelog/archive/); docs[] lists design/ as it is on the pinned commit plus those copies. Does not bump
version.json. CI runs this on the week-close merge (ci_archive.py); sequence: design/versioning.md.
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

CATALOG = "scripts/data/archive_catalog.json"


def pin_spec(kind: str, n: int) -> dict:
    """Row facts for a weekly pin. Web and Build both pin the week-close merge, so both copy series n's notes."""
    web = kind == "web"
    return {
        "id": f"grok_{kind}_w{n}",
        "label": f"Grok {'Web' if web else 'Build'} Results (Week {n})",
        "desc": (f"Live path at the end of Grok Web week {n}." if web else f"Live path at the end of Grok Build week {n} (the week-close merge)."),
        "tag": f"archive/grok-{kind}-w{n}",
        "notes_series": n,
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


def read_catalog(root: Path) -> tuple[dict, bool, bool]:
    """(catalog object, had BOM, had CRLF). The file keeps its BOM / line endings on write."""
    raw = (root / CATALOG).read_bytes()
    data = json.loads(raw.decode("utf-8-sig"))
    if isinstance(data, list):
        agent_log.fail("archive_catalog.json must be an object with an `archives` list")
    return data, raw.startswith(b"\xef\xbb\xbf"), b"\r\n" in raw


def write_catalog(root: Path, data: dict, bom: bool, crlf: bool) -> None:
    text = json.dumps(data, indent="\t") + "\n"
    if crlf:
        text = text.replace("\n", "\r\n")
    (root / CATALOG).write_bytes((b"\xef\xbb\xbf" if bom else b"") + text.encode("utf-8"))


def tag_commit(root: Path, tag: str) -> str:
    """Commit a local tag points at, '' when the tag does not exist."""
    code, out = repo_lib.run_git(root, "rev-list", "-n", "1", f"refs/tags/{tag}")
    return out.strip() if code == 0 else ""


def commit_exists(root: Path, sha: str) -> bool:
    return repo_lib.run_git(root, "cat-file", "-e", f"{sha}^{{commit}}")[0] == 0


def pin_row(root: Path, spec: dict, sha: str, epoch: int, dry: bool) -> dict:
    """Add the catalog row for `spec` (when absent), copy its notes and create its local tag (when absent).

    Returns {row: added|exists, tag: created|exists|none|no-commit, commit, docs, notes}. `dry` writes nothing.
    A row that exists keeps its commit; a tag that is missing then points at that commit."""
    data, bom, crlf = read_catalog(root)
    rows = rows_of(data)
    have = next((b for b in rows if b.get("id") == spec["id"]), None)
    notes: list[str] = []
    docs = 0
    if have is None:
        if spec["notes_series"]:
            notes = copy_notes(root, epoch, spec["notes_series"], root / "archives" / "docs" / spec["id"], dry)
        docs_list = design_docs(root, sha) + notes
        docs = len(docs_list)
        rows.append({"id": spec["id"], "label": spec["label"], "desc": spec["desc"], "commit": sha,
                     "pages_slug": f"archives/{spec['id']}", "video": "", "docs": docs_list})
        if not dry:
            write_catalog(root, data, bom, crlf)
    at = have.get("commit", sha) if have else sha
    tag, tag_state = spec["tag"], "none"
    if tag:
        if tag_commit(root, tag):
            tag_state = "exists"
        elif not commit_exists(root, at):
            tag_state = "no-commit"
        else:
            tag_state = "would-create" if dry else "created"
            if not dry:
                repo_lib.run_git(root, "tag", tag, at)
    return {"row": "exists" if have else ("would-add" if dry else "added"), "tag": tag_state, "commit": at, "docs": docs, "notes": len(notes)}


def main() -> int:
    ap = agent_log.std_parser("Add a weekly archive pin (catalog row + local tag) for a commit; does not bump version.json.", writes=True)
    ap.add_argument("--web", type=int, default=0, metavar="N", help="Pin grok_web_wN (week N results) and tag archive/grok-web-wN.")
    ap.add_argument("--build", type=int, default=0, metavar="N", help="Pin grok_build_wN (week N results) and tag archive/grok-build-wN.")
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
    sha = args.commit or (head.strip() if code == 0 else "")
    if not sha:
        agent_log.fail("no commit: pass --commit SHA")
    epoch = int(repo_lib.read_version(root)["epoch"]) if spec["notes_series"] else 0
    res = pin_row(root, spec, sha, epoch, args.dry_run)
    if res["row"] == "exists":
        print(f"exists {spec['id']} tag={spec['tag'] or '-'} ({res['tag']})")
    else:
        verb = "would add" if args.dry_run else "added"
        print(f"{verb} {spec['id']} commit={sha} docs={res['docs']} notes={'would copy ' if args.dry_run else ''}{res['notes']} tag={spec['tag'] or '-'} ({res['tag']})")
    added = 1 if res["row"] == "added" else 0
    return agent_log.emit_result("PASS", id=spec["id"], added=added, would_add=1 if res["row"] == "would-add" else None,
                                 docs=res["docs"], notes=res["notes"], tag=res["tag"], dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
