#!/usr/bin/env python3
"""Shared task files in design/tasks/ for Web, Build and Bot: list, show, new, done, index, check.

    python tools/docs.py task list [--owner build|web|bot]
    python tools/docs.py task show ID
    python tools/docs.py task new ID|opt-next --owner bot --title "..." --done-when "..." --resume "..." [--needs ID,ID] [--body-file PATH]
    python tools/docs.py task update ID [--status S] [--needs ID,ID] [--section TITLE --body TEXT | --body-file PATH]
    python tools/docs.py task done ID [--changelog design/changelog/X.Y.Z.md]
    python tools/docs.py task index | check

`done` deletes the task file, drops it from other tasks' `needs:` and adds one line to this branch's changelog entry. Rules: design/tasks/README.md.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import md_format_lib as md
import repo_lib
import task_lib

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List, show, create, finish and check the task files in design/tasks/.", writes=True)
    sub = ap.add_subparsers(dest="cmd", required=True)
    ls = sub.add_parser("list", help="The open tasks (the README index).")
    ls.add_argument("--owner", choices=task_lib.OWNERS, default="", help="Only tasks for this owner.")
    sh = sub.add_parser("show", help="One task: header, resume command and the file.")
    sh.add_argument("id", help="Task id (file name without .md).")
    nw = sub.add_parser("new", help="Write a new task file and refresh the index.")
    nw.add_argument("id", help="Task id (file name without .md).")
    nw.add_argument("--owner", choices=task_lib.OWNERS, required=True, help="Who runs it.")
    nw.add_argument("--title", required=True, help="One-line title.")
    nw.add_argument("--done-when", dest="done_when", required=True, help="The check that proves it is finished.")
    nw.add_argument("--resume", required=True, help="How a fresh session picks it up. Build: the launch line `python tools/slice.py open AREA --task ID`; Web/Bot: one plain line. Any tool named must exist.")
    nw.add_argument("--needs", default="", help="Comma-separated task ids this waits on (makes it blocked).")
    nw.add_argument("--body", default="", help="Body markdown (sections start `## `).")
    nw.add_argument("--body-file", dest="body_file", default="", help="File holding the body markdown.")
    up = sub.add_parser("update", help="Change a task's status / needs, or replace one ## section (added when missing).")
    up.add_argument("id", help="Task id (file name without .md).")
    up.add_argument("--status", choices=task_lib.STATUSES, default="", help="New status.")
    up.add_argument("--needs", default=None, help="Comma-separated ids, or none.")
    up.add_argument("--section", default="", help="Section title to replace, e.g. 'Open questions'.")
    up.add_argument("--body", default="", help="New section body markdown.")
    up.add_argument("--body-file", dest="body_file", default="", help="File holding the body markdown.")
    dn = sub.add_parser("done", help="Finish a task: delete it, unblock dependants, one changelog line (skipped on grok-build-w* branches).")
    dn.add_argument("id", help="Task id (file name without .md).")
    dn.add_argument("--changelog", default="", help="Changelog file for the line (default: the newest design/changelog entry main does not have).")
    sub.add_parser("index", help="Regenerate the README index.")
    sub.add_parser("check", help="Lint the task files (check.py load-graph runs the same).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    tasks = task_lib.load(root)
    dry = bool(args.dry_run)

    def end(body: str, status: str, **kv: object) -> int:
        return agent_log.finish("task", root, body, status, args=args, write=not dry, cmd=args.cmd, **kv)

    if args.cmd in ("show", "done", "update") and args.id not in tasks:
        print(f"error: no task {args.id}; open tasks: {', '.join(tasks) or 'none'}", file=sys.stderr)
        return end("", "FAIL", error="not-found")
    if args.cmd == "list":
        rows = {k: v for k, v in tasks.items() if not args.owner or v.get("owner") == args.owner}
        return end("\n".join(task_lib.index_lines(rows)), "PASS", count=len(rows))
    if args.cmd == "show":
        t = tasks[args.id]
        lines = [f"{k}: {t[k]}" for k in ("title", "owner", "status", "needs", "done-when") if t.get(k)]
        label = "resume (the User's launch line from the repo root; a session never runs it)" if t.get("owner") == "build" else "resume"
        lines += [f"{label}: {t.get('resume', '')}", f"file: {t['path']} (read it whole; it is the task)"]
        return end("\n".join(lines), "PASS", id=args.id)
    if args.cmd == "new":
        if args.id == "opt-next":
            args.id = task_lib.next_opt(root)
        if not task_lib.ID_RE.match(args.id) or args.id in tasks:
            print(f"error: {args.id} must be a new lowercase kebab id", file=sys.stderr)
            return end("", "FAIL", error="bad-id")
        needs = task_lib.split(args.needs)
        missing = [n for n in needs if n not in tasks]
        if missing:
            print(f"error: --needs names no open task: {', '.join(missing)}", file=sys.stderr)
            return end("", "FAIL", error="bad-needs")
        bad_cmd = task_lib.command_fails(root, f"{task_lib.TASKS_REL}/{args.id}.md", "resume", args.resume)
        if bad_cmd:
            print("error: " + "; ".join(bad_cmd), file=sys.stderr)
            return end("", "FAIL", error="bad-resume")
        body = md.read_text(args.body_file) if args.body_file else args.body
        p = task_lib.task_path(root, args.id)
        if not dry:
            md.write_text(p, task_lib.skeleton(args.id, args.owner, args.title, args.done_when, args.resume, needs, body), mkdir=True)
            task_lib.write_index(root)
        return end(("would write " if dry else "wrote ") + f"{task_lib.TASKS_REL}/{args.id}.md and the README index", "PASS", id=args.id, changed=0 if dry else 1)
    if args.cmd == "update":
        p = root / tasks[args.id]["path"]
        needs = task_lib.split(args.needs) if args.needs is not None else None
        missing = [n for n in (needs or []) if n not in tasks or n == args.id]
        body = md.read_text(args.body_file) if args.body_file else args.body
        if missing or (args.section and not body.strip()) or not (args.status or needs is not None or args.section):
            print("error: update needs --status, --needs (open task ids) or --section with a body", file=sys.stderr)
            return end("", "FAIL", error="bad-update")
        changed = []
        if not dry:
            for key, val in (("status", args.status), ("needs", None if needs is None else ", ".join(needs) or "none")):
                if val and (task_lib.set_head(p, key, val) or task_lib.ensure_head(p, key, val)):  # ensure: a header without the line
                    changed.append(key)
            if args.section and task_lib.set_section(p, args.section, body):
                changed.append(args.section)
            task_lib.write_index(root)
        return end(f"{tasks[args.id]['path']}: " + (", ".join(changed) or ("would update" if dry else "no change")), "PASS", id=args.id, changed=len(changed))
    if args.cmd == "done":
        if repo_lib.head_kind(root) == "build":
            # Build path: no changelog
            return end("\n".join(task_lib.done(root, args.id, None, dry)), "PASS", id=args.id, changed=0 if dry else 1)
        log = (root / args.changelog) if args.changelog else task_lib.changelog_target(root, create=not dry)
        if log is None and dry:
            return end("\n".join(task_lib.done(root, args.id, None, dry) + ["changelog: would add one line to a new entry"]), "PASS", id=args.id, changed=0)
        if log is None:
            print("error: could not resolve or create changelog", file=sys.stderr)
            return end("", "FAIL", error="no-changelog")
        return end("\n".join(task_lib.done(root, args.id, log, dry)), "PASS", id=args.id, changed=0 if dry else 1)
    if args.cmd == "index":
        changed = task_lib.write_index(root, dry)
        return end("index " + ("refreshed" if changed else "already current"), "PASS", changed=int(changed))
    bad = task_lib.fails(root)
    return end("\n".join(f"- {b}" for b in bad) or "tasks ok", "FAIL" if bad else "PASS", tasks=len(tasks), problems=len(bad))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
