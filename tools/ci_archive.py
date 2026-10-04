#!/usr/bin/env python3
"""Week-close archives in CI: both pins (web + build) for week N, created on the merge that adds design/changelog/0.N.0.md.

    python3 tools/ci_archive.py --before SHA --commit SHA --commit-changes --push origin   # what .github/workflows/archive.yml runs
    python3 tools/ci_archive.py --dry-run [--before SHA] [--commit SHA]                    # same detection, writes nothing
    python3 tools/ci_archive.py --week N [--commit SHA] ...                                # manual: skip detection (workflow_dispatch)
    python3 tools/ci_archive.py --selftest                                                # throwaway origin + clones, no GitHub

Trigger: a file `design/changelog/{epoch}.{N}.0.md` ADDED between --before and --commit (default HEAD^ .. HEAD), the
squash-merge of grok-build-wN. Files moved into design/changelog/archive/ and [skip ci] stamp commits never match.
For each of web and build (week_pin.py rows: `grok_web_wN`, `grok_build_wN`): add the catalog row when absent (commit =
the merge, or an existing tag's commit), copy that series' notes to archives/docs/<id>/, create tag
archive/grok-web-wN and archive/grok-build-wN at that commit. Idempotent per row and per tag: a rerun does nothing.
--commit-changes commits the catalog and docs as `chore: archive week N [skip ci]`. --push REMOTE pushes the new tags,
then the commit to --branch (default main; on a rejected push: fetch, rebase that one commit, retry, 3 times).
Never forces, never deletes. Writes `changed=` and `weeks=` to $GITHUB_OUTPUT when set. Sequence: design/versioning.md.
"""
from __future__ import annotations

import os
import re
import sys
import tempfile
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import repo_lib
import week_pin

WEEK_CLOSE = re.compile(r"^design/changelog/(\d+)\.(\d+)\.0\.md$")
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
KINDS = ("web", "build")


def git(root: Path, *args: str) -> tuple[int, str]:
    return repo_lib.run_git(root, *args)


def rev(root: Path, ref: str) -> str:
    code, out = git(root, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}")
    return out.strip() if code == 0 else ""


def detect(root: Path, before: str, head: str) -> list[tuple[int, int]]:
    """(epoch, series) of every week-close changelog added in before..head. A missing or all-zero `before`
    (new branch, force push) falls back to head's first parent, else the empty tree."""
    base = rev(root, before) if before and set(before) != {"0"} else ""
    base = base or rev(root, f"{head}^1") or EMPTY_TREE
    code, out = git(root, "diff", "--name-only", "--diff-filter=A", "--no-renames", base, head, "--", "design/changelog")
    found = []
    for line in out.splitlines() if code == 0 else []:
        m = WEEK_CLOSE.match(line.strip())
        if m and int(m.group(2)) > 0:
            found.append((int(m.group(1)), int(m.group(2))))
    return sorted(set(found), key=lambda e: (e[0], e[1]))


def pin_week(root: Path, epoch: int, n: int, head: str, dry: bool, say) -> tuple[list[str], list[str]]:
    """Pin web + build for week n. Returns (paths to commit, new local tags)."""
    paths, tags = [], []
    for kind in KINDS:
        spec = week_pin.pin_spec(kind, n)
        sha = week_pin.tag_commit(root, spec["tag"]) or head  # a surviving tag keeps its commit
        res = week_pin.pin_row(root, spec, sha, epoch, dry)
        say(f"{spec['id']} row={res['row']} tag={res['tag']} commit={res['commit'][:12]} docs={res['docs']} notes={res['notes']}")
        if res["row"] in ("added", "would-add"):
            paths.append(f"archives/docs/{spec['id']}")
        if res["tag"] in ("created", "would-create"):
            tags.append(spec["tag"])
    if paths or tags:
        paths.append(week_pin.CATALOG)
    return paths, tags


def commit_paths(root: Path, paths: list[str], message: str) -> str:
    """Commit only `paths` when they changed. Returns committed|clean|error."""
    code, out = git(root, "status", "--porcelain", "--", *paths)
    if code != 0 or not out.strip():
        return "clean" if code == 0 else "error"
    ident = [] if git(root, "config", "user.name")[1].strip() else ["-c", "user.name=github-actions[bot]", "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com"]
    if git(root, "add", "--", *paths)[0] != 0:
        return "error"
    return "committed" if git(root, *ident, "commit", "-m", message, "--", *paths)[0] == 0 else "error"


def push(root: Path, remote: str, branch: str, tags: list[str], commit: bool, say) -> str:
    """Plain pushes only: the new tags (refs/tags/..., never forced), then HEAD to the branch with fetch+rebase retries."""
    for tag in tags:
        code, out = git(root, "push", remote, f"refs/tags/{tag}:refs/tags/{tag}")
        if code != 0:
            say(f"push tag {tag} failed: {out.splitlines()[-1] if out else code}")
            return "error"
        say(f"pushed tag {tag}")
    if not commit:
        return "tags" if tags else "none"
    for attempt in range(1, 5):
        code, out = git(root, "push", remote, f"HEAD:refs/heads/{branch}")
        if code == 0:
            say(f"pushed {branch} (attempt {attempt})")
            return "pushed"
        say(f"push {branch} rejected (attempt {attempt}): fetch and rebase the archive commit")
        if attempt == 4 or git(root, "fetch", remote, branch)[0] != 0 or git(root, "rebase", "FETCH_HEAD")[0] != 0:
            git(root, "rebase", "--abort")
            return "error"
    return "error"


def run(root: Path, args) -> tuple[int, dict, list[str]]:
    lines: list[str] = []

    def say(s: str) -> None:
        lines.append(s)
        print(s)

    dry = bool(args.dry_run)
    head = rev(root, args.commit or "HEAD")
    if not head:
        agent_log.fail(f"--commit {args.commit}: not a commit in this checkout")
    if git(root, "merge-base", "--is-ancestor", head, "HEAD")[0] != 0:
        agent_log.fail(f"commit {head[:12]} is not an ancestor of the checked-out HEAD")
    if args.push and not dry:
        git(root, "fetch", args.push, "refs/tags/archive/*:refs/tags/archive/*")  # no force: a clashing tag stays untouched
    ver = repo_lib.read_version(root) if (root / repo_lib.VERSION_FILE).is_file() else {"epoch": 0, "series": 0}
    if args.week:
        weeks = [(int(args.epoch if args.epoch is not None else ver["epoch"]), args.week)]
        say(f"week={args.week} (manual, detection skipped)")
    else:
        weeks = detect(root, args.before, head)
        say(f"commit={head[:12]} before={(args.before or 'HEAD^')[:12]} week_close={','.join(f'{e}.{n}.0' for e, n in weeks) or 'none'}")
    paths: list[str] = []
    tags: list[str] = []
    for epoch, n in weeks:
        if int(ver["series"]) != n:
            say(f"WARN week {n} closes while version.json series is {ver['series']} (pinning on the changelog name)")
        p, t = pin_week(root, epoch, n, head, dry, say)
        paths += p
        tags += t
    paths = sorted(set(paths))
    state = "none"
    if paths and not dry and args.commit_changes:
        label = "+".join(str(n) for _, n in weeks)
        state = commit_paths(root, paths, f"chore: archive week {label} [skip ci]")
        say(f"commit={state}")
    pushed = "none"
    if args.push and not dry and (tags or state == "committed"):
        pushed = push(root, args.push, args.branch, tags, state == "committed", say)
    elif args.push and not dry:
        say("push=nothing to push")
    changed = bool(tags) or state == "committed"
    out = os.environ.get("GITHUB_OUTPUT")
    if out and not dry:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"changed={1 if changed else 0}\nweeks={','.join(str(n) for _, n in weeks)}\n")
    bad = "error" in (state, pushed)
    kv = dict(weeks=len(weeks), tags=len(tags), committed=1 if state == "committed" else 0, pushed=pushed, dry_run=dry)
    return (1 if bad else 0), kv, lines


def _g(cwd: Path, *a: str) -> str:
    import subprocess

    p = subprocess.run(["git", *a], cwd=cwd, capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError(f"git {' '.join(a)}: {p.stderr.strip()}")
    return p.stdout.strip()


def selftest() -> tuple[list[str], int]:
    """Prove the whole flow against a bare 'origin' on disk: squash-merge simulation, stamp commit, rerun, repair, race."""
    import contextlib
    import io
    import json
    import types

    bad: list[str] = []
    ran = [0]

    def check(ok: bool, what: str) -> None:
        ran[0] += 1
        if not ok:
            bad.append(what)

    def call(root: Path, **kw) -> tuple[int, str]:
        ns = types.SimpleNamespace(before="", commit="", week=0, epoch=None, commit_changes=True, push="origin", branch="main", dry_run=False)
        ns.__dict__.update(kw)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code, _kv, _lines = run(root, ns)
        return code, buf.getvalue()

    with tempfile.TemporaryDirectory(prefix="wdb-ci-archive-") as tmp:
        t = Path(tmp)
        origin, work = t / "origin.git", t / "work"
        _g(t, "init", "--bare", "-b", "main", str(origin))

        def clone(name: str) -> Path:
            d = t / name
            _g(t, "clone", "-q", str(origin), str(d))
            _g(d, "config", "user.name", "ci")
            _g(d, "config", "user.email", "ci@example.invalid")
            return d

        def write(d: Path, rel: str, text: str) -> None:
            (d / rel).parent.mkdir(parents=True, exist_ok=True)
            (d / rel).write_bytes(text.replace("\n", "\r\n").encode("utf-8"))

        def ver(series: int, patch: int) -> str:
            return json.dumps({"epoch": 0, "series": series, "patch": patch, "label": f"0.{series}.{patch}", "open_commit": "x"}, indent="\t") + "\n"

        w = clone("work")
        write(w, "project.godot", "")
        write(w, "scripts/data/version.json", ver(5, 12))
        rows = [{"id": "grok_web_w4", "label": "W4", "desc": "d", "commit": "a" * 40, "pages_slug": "archives/grok_web_w4", "video": "", "docs": []}]
        (w / "scripts/data").mkdir(parents=True, exist_ok=True)
        (w / "scripts/data/archive_catalog.json").write_bytes(b"\xef\xbb\xbf" + json.dumps({"archives": rows}, indent="\t").replace("\n", "\r\n").encode() + b"\r\n")
        write(w, "design/a.md", "# a\n")
        write(w, "design/changelog/0.5.0.md", "## 0.5.0\n")
        write(w, "design/changelog/0.5.3.md", "## 0.5.3\n")
        _g(w, "add", "-A")
        _g(w, "commit", "-qm", "base")
        _g(w, "push", "-q", "origin", "HEAD:main")
        base = _g(w, "rev-parse", "HEAD")

        def squash_week(n: int) -> str:
            """grok-build-wN: seed + changes + week-close changelog, squash-merged to main as ONE commit, then a stamp commit."""
            _g(w, "pull", "-q", "--ff-only", "origin", "main")
            _g(w, "switch", "-qc", f"grok-build-w{n}")
            write(w, "scripts/data/version.json", ver(n, 0))
            write(w, f"design/changelog/0.{n}.0.md", f"## 0.{n}.0\n")
            write(w, f"design/changelog/0.{n}.1.md", f"## 0.{n}.1\n")
            write(w, "design/b.md", f"# b{n}\n")
            _g(w, "add", "-A")
            _g(w, "commit", "-qm", f"Grok Build Week {n}")
            _g(w, "switch", "-q", "main")
            _g(w, "merge", "-q", "--squash", f"grok-build-w{n}")
            _g(w, "commit", "-qm", f"Grok Build Week {n} (#9{n})")
            merged = _g(w, "rev-parse", "HEAD")
            write(w, "scripts/data/changelog.json", f'{{"week": {n}}}\n')
            _g(w, "add", "-A")
            _g(w, "commit", "-qm", f"chore: stamp 0.{n}.0 [skip ci]")
            _g(w, "push", "-q", "origin", "HEAD:main")
            return merged

        def rows_of(d: Path, ref: str = "HEAD") -> dict:
            raw = _g(d, "show", f"{ref}:scripts/data/archive_catalog.json")
            return {r["id"]: r for r in json.loads(raw.lstrip("\ufeff"))["archives"]}

        merged6 = squash_week(6)
        # 1. nothing to do on a push without a week-close file, or when only the stamp commit is in range
        ci = clone("ci1")
        code, out = call(ci, before=merged6, commit="HEAD")
        check(code == 0 and "week_close=none" in out and _g(ci, "tag", "--list", "archive/*") == "", "no week-close file: expected a no-op")
        # 2. the real run: before = old tip, commit = the squash merge (stamp commit sits on top)
        tip_before = _g(ci, "rev-parse", "HEAD")
        code, out = call(ci, before=base, commit=merged6)
        check(code == 0 and "week_close=0.6.0" in out, f"week-close 0.6.0 not detected (rc={code})")
        tags = _g(origin, "tag", "--list", "archive/*").split()
        check(tags == ["archive/grok-build-w6", "archive/grok-web-w6"], f"origin tags: {tags}")
        check(all(_g(origin, "rev-list", "-n", "1", x) == merged6 for x in tags), "both tags must sit on the merge commit")
        r = rows_of(origin, "main")
        check({"grok_web_w6", "grok_build_w6"} <= set(r) and all(r[i]["commit"] == merged6 for i in ("grok_web_w6", "grok_build_w6")), "catalog rows on origin/main")
        check("archives/docs/grok_web_w6/0.6.1.md" in r.get("grok_web_w6", {}).get("docs", []) and "archives/docs/grok_build_w6/0.6.0.md" in r.get("grok_build_w6", {}).get("docs", []), "docs lists the copied notes")
        check((ci / "archives/docs/grok_web_w6/0.6.0.md").is_file() and (ci / "archives/docs/grok_build_w6/0.6.1.md").is_file(), "notes copied for both pins")
        raw = (ci / "scripts/data/archive_catalog.json").read_bytes()
        check(raw.startswith(b"\xef\xbb\xbf") and b"\r\n" in raw, "catalog keeps BOM + CRLF")
        check(_g(origin, "log", "-1", "--format=%s", "main") == "chore: archive week 6 [skip ci]", "archive commit subject")
        check(_g(origin, "rev-parse", "main") == _g(ci, "rev-parse", "HEAD"), "origin main == CI HEAD")
        check(_g(origin, "diff", "--name-only", tip_before, "main").split("\n")[0:1] != [""], "archive commit changed files")
        # 3. idempotent: same clone, then a fresh CI clone (a workflow rerun)
        tip = _g(origin, "rev-parse", "main")
        code, out = call(ci, before=base, commit=merged6)
        ci2 = clone("ci2")
        code2, out2 = call(ci2, before=base, commit=merged6)
        check(code == 0 and code2 == 0 and "tag=exists" in out2 and "row=exists" in out2, "rerun must report exists")
        check(_g(origin, "rev-parse", "main") == tip and _g(ci2, "status", "--porcelain", "--", "scripts", "archives") == "", "rerun must change nothing")
        # 4. repair: tag lost on origin and locally, row kept
        _g(origin, "tag", "-d", "archive/grok-web-w6")
        _g(ci2, "tag", "-d", "archive/grok-web-w6")
        code, out = call(ci2, before=base, commit=merged6)
        check(code == 0 and _g(origin, "rev-list", "-n", "1", "archive/grok-web-w6") == merged6, "missing tag recreated at the row commit")
        check(_g(origin, "rev-parse", "main") == tip, "tag repair adds no commit")
        # 5. dry-run writes nothing; then a race: someone else pushes main between checkout and push
        merged7 = squash_week(7)
        ci3 = clone("ci3")
        before_dry = _g(ci3, "status", "--porcelain")
        tags_dry = _g(ci3, "tag", "--list")
        code, out = call(ci3, before=merged6, commit=merged7, dry_run=True)
        check(code == 0 and "would-add" in out and _g(ci3, "status", "--porcelain") == before_dry and _g(ci3, "tag", "--list") == tags_dry, "dry-run must write nothing")
        write(w, "design/other.md", "# other\n")
        _g(w, "add", "-A")
        _g(w, "commit", "-qm", "other main push")
        _g(w, "push", "-q", "origin", "HEAD:main")
        other = _g(w, "rev-parse", "HEAD")
        code, out = call(ci3, before=merged6, commit=merged7)
        check(code == 0 and "rejected" in out, f"race: expected one rejected push then a rebase (rc={code})")
        check(_g(origin, "merge-base", "--is-ancestor", other, "main") == "" and {"grok_web_w7", "grok_build_w7"} <= set(rows_of(origin, "main")), "race: other push kept and week 7 rows landed")
        for x in (tip, other, merged7):
            check(_g(origin, "merge-base", "--is-ancestor", x, "main") == "", f"history only grows: {x[:8]} must stay an ancestor")
        # 6. manual week (workflow_dispatch) and a non-ancestor commit
        code, out = call(clone("ci4"), week=7, commit=merged7)
        check(code == 0 and "manual" in out and "row=exists" in out, "manual --week on an archived week is a no-op")
        try:
            with contextlib.redirect_stderr(io.StringIO()):
                call(ci3, commit=base[:-1] + ("0" if base[-1] != "0" else "1"))
            check(False, "unknown commit must fail")
        except SystemExit as exc:
            check(exc.code == 2, "unknown commit exits 2")
    return bad, ran[0]


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("CI week-close archives: tag + catalog rows + docs for web and build when design/changelog/0.N.0.md lands.", writes=True)
    ap.add_argument("--before", default="", help="Push base SHA (github.event.before). Default HEAD^.")
    ap.add_argument("--commit", default="", help="Commit to pin (the merge). Default HEAD.")
    ap.add_argument("--week", type=int, default=0, metavar="N", help="Pin week N without detection (manual run).")
    ap.add_argument("--epoch", type=int, default=None, help="Epoch for --week (default version.json).")
    ap.add_argument("--commit-changes", action="store_true", help="Commit the catalog and docs as 'chore: archive week N [skip ci]'.")
    ap.add_argument("--push", default="", metavar="REMOTE", help="Push new tags, then the commit, to REMOTE (plain pushes; fetch + rebase retry).")
    ap.add_argument("--branch", default="main", help="Branch --push updates (default main).")
    ap.add_argument("--selftest", action="store_true", help="Prove detection, tags, rows, docs, idempotency, repair and a push race on a temp origin.")
    args = ap.parse_args(argv)
    if args.selftest:
        bad, ran = selftest()
        for b in bad:
            print(f"selftest: {b}")
        return agent_log.emit_result("FAIL" if bad else "PASS", None, checks=ran, problems=len(bad))
    if args.week < 0:
        agent_log.fail("--week N must be positive")
    root = agent_log.resolve_root(args)
    code, kv, lines = run(root, args)
    body = "\n".join([f"root=. dryRun={args.dry_run}", *lines])
    return agent_log.finish("ci-archive", root, body, "FAIL" if code else "PASS", args=args, echo="", **kv)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
