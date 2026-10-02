#!/usr/bin/env python3
"""design/code-map.md CLI: check, row, patch (check_code_map.py and patch_code_map.py are shims to it).

    python3 tools/code_map.py check
    python3 tools/code_map.py row --path scripts/foo/bar.gd
    python3 tools/code_map.py patch --system "Debug" --add scripts/x.gd [--remove p] [--rename old=new] [--dry-run]

Logic lives in code_map_lib (rows, ticks, add/remove/rename). The three old script
names stay as shims for one release. Summaries: _logs/code-map-{check,row,patch}/.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import code_map_lib as cm
import gd_lib
import md_format_lib as md


def _head(title: str, *extra: str) -> list[str]:
    return [f"code-map {title} {datetime.now(timezone.utc).isoformat()}", "root=.", *extra]


def cmd_check(root: Path, args) -> int:
    path = root / "design" / "code-map.md"
    lines = _head("check")
    if not path.is_file():
        return agent_log.finish("code-map-check", root, "\n".join(lines), "FAIL", args=args, error="missing-code-map")
    rows = cm.parse_rows(md.read_text(path))
    scripts = [cm.posix(p.relative_to(root).as_posix()) for p in gd_lib.iter_gd(root)]
    unmapped = [r for r in scripts if not cm.file_is_mapped(r, rows)]
    missing = [r for r in cm.listed_file_paths(rows) if not (root / r).is_file()]
    mapped = len(scripts) - len(unmapped)
    lines += [
        f"rows_scanned={len(rows)} scripts={len(scripts)} mapped={mapped}",
        "measure=scripts/**/*.gd vs code-map ticks; directory ticks cover children; do not read the map",
        "",
    ]
    lines += [f"UNMAPPED {r}" for r in unmapped] + [f"MISSING {r}" for r in missing]
    echo = f"unmapped={len(unmapped)} missing={len(missing)} mapped={mapped} scripts={len(scripts)}"
    status = "FAIL" if unmapped or missing else "PASS"
    return agent_log.finish("code-map-check", root, "\n".join(lines), status, args=args, echo=echo,
                            unmapped=len(unmapped), missing=len(missing), mapped=mapped, scripts=len(scripts))


def cmd_row(root: Path, args) -> int:
    path = root / "design" / "code-map.md"
    needle = cm.posix(args.path)
    lines = _head("row", f"path={needle}")
    if not path.is_file():
        return agent_log.finish("code-map-row", root, "\n".join(lines), "FAIL", args=args, matches=0, error="missing-code-map")
    rows = cm.parse_rows(md.read_text(path))
    hits = [r for r in rows if cm.matches(needle, r.listed)]
    lines += [f"rows_scanned={len(rows)} matches={len(hits)}", "measure=parse design/code-map.md table; do not read the rest of the map", ""]
    if not hits:
        lines.append("NO_ROW")
    for r in hits:
        lines += [f"system={r.system}", f"live={r.live}", ""]
    return agent_log.finish("code-map-row", root, "\n".join(lines), "PASS" if hits else "FAIL", args=args,
                            echo=f"matches={len(hits)}", matches=len(hits))


def _parse_rename(raw: str) -> tuple[str, str] | None:
    old, _, new = raw.partition("=")
    old, new = old.strip(), new.strip()
    return (old, new) if old and new else None


def cmd_patch(root: Path, args) -> int:
    path = root / "design" / "code-map.md"
    lines = _head("patch", f"system={args.system}")

    def end(status: str, echo: str | None = None, **kv) -> int:
        return agent_log.finish("code-map-patch", root, "\n".join(lines), status, args=args, echo=echo, **kv)

    if not (args.add or args.remove or args.rename):
        return end("FAIL", changed=0, error="no-ops")
    if not path.is_file():
        return end("FAIL", changed=0, error="missing-code-map")
    raw = path.read_bytes().decode("utf-8-sig").replace("\r\n", "\n")
    rows = cm.parse_rows(raw)
    row = cm.find_system(rows, args.system)
    if row is None:
        lines += ["matched=", "systems=" + ", ".join(cm.system_choices(rows, args.system))]
        return end("FAIL", changed=0, error="unknown-system")
    lines.append(f"matched={row.system}")
    live = row.live
    added = removed = renamed = skipped = failed = 0
    for p in args.remove:
        live, resolved, action = cm.remove_path(live, p)
        if action == "removed":
            removed += 1
            lines.append(f"removed={resolved}")
        else:
            failed += 1
            lines.append(f"skip={cm.posix(p)} reason=not-listed")
    for spec in args.rename:
        parsed = _parse_rename(spec)
        if parsed is None:
            failed += 1
            lines.append(f"skip={spec} reason=bad-rename")
            continue
        live, resolved, token, action = cm.rename_path(live, *parsed)
        if action == "renamed":
            renamed += 1
            lines.append(f"renamed={resolved}->{token}")
        else:
            failed += 1
            lines.append(f"skip={cm.posix(parsed[0])} reason=not-listed")
    for p in args.add:
        live, token, action = cm.add_path(live, p)
        if action == "added":
            added += 1
            lines.append(f"added={cm.posix(p)} as={token}")
        else:
            skipped += 1
            lines.append(f"skip={cm.posix(p)} reason=already-listed")
    changed = int(live != row.live)
    if changed and not args.dry_run:
        file_lines = raw.splitlines(keepends=True)
        md.rewrite_table_row(file_lines, row.index, cm.format_row(row.system, live))
        md.write_text(path, md.join_lines_keep_trailing(raw, file_lines))
    lines += [f"live={live}", "measure=mutate one code-map row; do not read the rest of the map"]
    echo = f"changed={changed} added={added} removed={removed} renamed={renamed} failed={failed}" + (" (dry-run)" if args.dry_run else "")
    return end("FAIL" if failed else "PASS", echo, changed=changed, added=added, removed=removed,
               renamed=renamed, skipped=skipped, failed=failed, dry_run=args.dry_run)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Check, query, or patch design/code-map.md.", writes=True, json_out=True)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check", help="Diff live .gd files against code-map ticks.")
    s = sub.add_parser("row", help="Print the system row matching a path.")
    s.add_argument("--path", required=True, help="Live script or scene path")
    s = sub.add_parser("patch", help="Patch one system row.")
    s.add_argument("--system", required=True, help="System row name (exact, else unique prefix)")
    s.add_argument("--add", action="append", default=[], help="Live path to add (repeatable)")
    s.add_argument("--remove", action="append", default=[], help="Live path to remove (repeatable)")
    s.add_argument("--rename", action="append", default=[], help="old=new (repeatable)")
    # accept the shared flags after the subcommand too (old tools took --root last)
    for name in ("check", "row", "patch"):
        sub.choices[name].add_argument("--root", default=None, help="Repo root (default: auto).", dest="root_sub")
        sub.choices[name].add_argument("--json", dest="json_sub", action="store_true")
    sub.choices["patch"].add_argument("--dry-run", dest="dry_sub", action="store_true", help="Print what would change; write nothing.")
    args = ap.parse_args(argv)
    args.root = getattr(args, "root_sub", None) or args.root
    args.json = args.json or getattr(args, "json_sub", False)
    args.dry_run = args.dry_run or getattr(args, "dry_sub", False)
    root = agent_log.resolve_root(args)
    return {"check": cmd_check, "row": cmd_row, "patch": cmd_patch}[args.cmd](root, args)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
