#!/usr/bin/env python3
"""Explicit visual-reference opt-in for a Build task: export, grant, status, revoke.

A grant lasts two hours, only in the original active slice session/unit, and pins
exact file contents. This does not alter host permissions or allow shell readers.
"""
from __future__ import annotations
import json
import sys
from pathlib import Path

import agent_log
import reference_policy as policy


def main() -> int:
    ap = agent_log.std_parser(__doc__, writes=True)
    ap.add_argument("action", nargs="?", choices=("export", "grant", "status", "revoke"), help="Export references, opt in, inspect or remove the grant.")
    ap.add_argument("--task", default="", help="Exact active Build task id.")
    ap.add_argument("--reason", default="", help="Why this task genuinely requires direct shape/colour reference access.")
    ap.add_argument("--path", action="append", default=[], help="Exact image path to grant; repeat, no globs or directories.")
    ap.add_argument("--manifest", default="", help="Grant the exact image files from this task's exported manifest.")
    ap.add_argument("--bible", default="", help="Accepted Bible sheet for export (read-only).")
    ap.add_argument("--walk-dir", default="", help="Current player walk folder for export (read-only).")
    ap.add_argument("--out", default="", help="Fresh export folder under _logs/references/TASK (default: that folder).")
    ap.add_argument("--selftest", action="store_true", help="Run task, session, path and hook regression fixtures; no live art.")
    args = ap.parse_args()
    if args.selftest:
        from reference_access_test import selftest
        return agent_log.selftest_result(selftest())
    if not args.action:
        ap.error("choose export, grant, status or revoke")
    root = agent_log.resolve_root(args).resolve()
    try:
        file = policy.contained(root, policy.GRANT, exists=False)
        if args.action == "export":
            from reference_export import export
            result = export(root, args.task, args.bible, args.walk_dir, args.out, args.dry_run)
            body = f"reference export: {len(result['images'])} native images; sources unchanged; manifest in {args.out or '_logs/references/' + args.task}/manifest.json"
        elif args.action == "grant":
            paths = list(args.path)
            if args.manifest:
                manifest = policy.read_json(root, args.manifest)
                if manifest.get("task") != args.task:
                    raise ValueError("manifest task mismatch")
                for row in manifest["images"]:
                    path = policy.reference(root, args.task, row["path"])
                    if policy.digest(path) != row["sha256"]:
                        raise ValueError("export changed since its manifest was written")
                    paths.append(row["path"])
            result = policy.make_grant(root, args.task, policy.session_id(), args.reason, paths)
            if not args.dry_run:
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            body = f"visual reference grant: task={args.task} files={len(result['files'])} expires_in=7200s; direct reads only; reason={result['reason']}"
        elif args.action == "revoke":
            if not args.dry_run:
                file.unlink(missing_ok=True)
            body = "visual reference grant removed"
        else:
            result = policy.active(root, policy.session_id())
            body = (f"active visual reference grant: task={result['task']} files={len(result['files'])}; reason={result['reason']}" if result else "no active visual reference grant")
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return agent_log.finish("reference-access", root, str(exc), "FAIL", args=args, write=not args.dry_run)
    return agent_log.finish("reference-access", root, body, "PASS", args=args, write=not args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
