#!/usr/bin/env python3
"""design/tunables.md and tunables-world.md CLI: get, set, add.

    python tools/tunables.py get --key <key-or-alias>
    python tools/tunables.py set --key <key-or-alias> --set "new Live cell" [--dry-run]
    python tools/tunables.py add --after <existing-key> --key NEW_KEY --set "Live cell" [--dry-run]

Logic lives in tunables_lib. The two old script names stay as shims for one release.
Summaries: _logs/tunable-row/ and _logs/tunable-patch/.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import md_format_lib as md
import tunables_lib as tl


def _head(title: str, *extra: str) -> list[str]:
    return [f"tunable {title} {datetime.now(timezone.utc).isoformat()}", "root=.", *extra]


FILES = ("tunables.md", "tunables-world.md")


def _find(root: Path, key: str) -> tuple[list[tuple[Path, str, "tl.Hit"]], bool]:
    """(path, raw text, hit) for every row matching key across the tunables files; flag = main file exists."""
    found = []
    for name in FILES:
        path = root / "design" / name
        if path.is_file():
            raw = md.read_text(path)
            found += [(path, raw, h) for h in tl.find_hits(tl.parse_hits(raw), key)]
    return found, (root / "design" / FILES[0]).is_file()


def cmd_get(root: Path, args) -> int:
    lines = _head("row", f"key={args.key}")
    found, exists = _find(root, args.key)
    if not exists:
        return agent_log.finish("tunable-row", root, "\n".join(lines), "FAIL", args=args, matches=0, error="missing-tunables")
    hits = [h for _p, _r, h in found]
    lines += [f"matches={len(hits)}", "measure=parse tunables tables; do not read the rest of the file", ""]
    if not hits:
        lines.append("NO_ROW")
        print(f"error: no tunable row matches {args.key!r}; --key matches a name or alias substring in design/tunables*.md (try a shorter fragment)", file=sys.stderr)
    for hit in hits:
        lines += tl.format_hit(hit) + [""]
    shown = [x for x in lines[4:] if x.strip()]  # the rows themselves, not only the summary file
    return agent_log.finish("tunable-row", root, "\n".join(lines), "PASS" if hits else "FAIL", args=args,
                            echo="\n".join(shown[:30] + ([f"... +{len(shown) - 30} more lines (summary file); use a longer --key"] if len(shown) > 30 else [])) if hits else f"matches={len(hits)}", matches=len(hits))


def cmd_add(root: Path, args) -> int:
    """Insert one row after an existing key's row (same table); other cells are `-` for the caller to fill."""
    lines = _head("add", f"key={args.key}", f"after={args.after}", f"set={args.value}")

    def end(status: str, echo: str | None = None, **kv) -> int:
        return agent_log.finish("tunable-add", root, "\n".join(lines), status, args=args, echo=echo, **kv)

    if _find(root, args.key)[0]:
        return end("PASS", "changed=0", changed=0, skipped="exists")
    found, exists = _find(root, args.after)
    if not exists or len(found) != 1:
        return end("FAIL", changed=0, error="missing-tunables" if not exists else "after-not-unique-or-missing")
    path, raw, hit = found[0]
    file_lines = raw.splitlines(keepends=True)
    out = tl.insert_row(file_lines, hit, f"`{args.key}`", args.value)
    if not args.dry_run:
        md.write_text(path, md.join_lines_keep_trailing(raw, out))
    lines += [f"section={hit.section}", f"inserted_after_line={hit.index + 1}", "other cells are `-`; fill them (suggested, note) with doc_patch.py replace"]
    return end("PASS", f"changed=1 section={hit.section}" + (" (dry-run)" if args.dry_run else ""), changed=1, dry_run=args.dry_run)


def cmd_set(root: Path, args) -> int:
    lines = _head("patch", f"key={args.key}", f"set={args.value}")

    def end(status: str, echo: str | None = None, **kv) -> int:
        return agent_log.finish("tunable-patch", root, "\n".join(lines), status, args=args, echo=echo, **kv)

    found, exists = _find(root, args.key)
    if not exists:
        return end("FAIL", changed=0, error="missing-tunables")
    hits = [h for _p, _r, h in found]
    lines.append(f"matches={len(hits)}")
    if len(hits) != 1:
        lines.append("sections=" + ", ".join(h.section for h in hits))
        return end("FAIL", changed=0, error="no-row" if not hits else "ambiguous")
    path, raw, hit = found[0]
    lines.extend(tl.format_hit(hit))
    if hit.live_cell == args.value:
        return end("PASS", "changed=0", changed=0, skipped="already")
    file_lines = raw.splitlines(keepends=True)
    file_lines[hit.index] = tl.set_live_cell(file_lines[hit.index], hit.live_col, args.value)
    if not args.dry_run:
        md.write_text(path, md.join_lines_keep_trailing(raw, file_lines))
    lines += [f"live_was={hit.live_cell}", f"live_now={args.value}", "measure=mutate one tunables Live cell; do not read the rest of the file"]
    return end("PASS", f"changed=1 live={args.value}" + (" (dry-run)" if args.dry_run else ""), changed=1, dry_run=args.dry_run)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Read or patch design/tunables.md / tunables-world.md rows.", writes=True, json_out=True)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("get", help="Print one tunables row.")
    s.add_argument("key_pos", nargs="?", default="", metavar="KEY", help="Tunable key or unique alias (same as --key)")
    s.add_argument("--key", default="", help="Tunable key or unique alias")
    s = sub.add_parser("set", help="Patch one Live cell.")
    s.add_argument("key_pos", nargs="?", default="", metavar="KEY", help="Tunable key or unique alias (same as --key)")
    s.add_argument("--key", default="", help="Tunable key or unique alias")
    s.add_argument("--set", "--value", dest="value", required=True, help="New Live cell text")
    s = sub.add_parser("add", help="Insert a row after an existing key's row.")
    s.add_argument("key_pos", nargs="?", default="", metavar="KEY", help="New key (no row exists yet; same as --key)")
    s.add_argument("--key", default="", help="New key (no row exists yet)")
    s.add_argument("--after", required=True, help="Existing key or alias; the new row goes below it, same table")
    s.add_argument("--set", "--value", dest="value", required=True, help="Live cell text")
    for name in ("get", "set", "add"):
        sub.choices[name].add_argument("--root", default=None, help="Repo root (default: auto).", dest="root_sub")
        sub.choices[name].add_argument("--json", dest="json_sub", action="store_true", help="Print one JSON object instead of text.")
    sub.choices["set"].add_argument("--dry-run", dest="dry_sub", action="store_true", help="Print what would change; write nothing.")
    sub.choices["add"].add_argument("--dry-run", dest="dry_sub", action="store_true", help="Print what would change; write nothing.")
    args = ap.parse_args(argv)
    args.key = args.key or args.key_pos
    if not args.key:
        agent_log.fail(f"tunables {args.cmd}: pass a KEY (example: tunables.py {args.cmd} move_speed)")
    args.root = getattr(args, "root_sub", None) or args.root
    args.json = args.json or getattr(args, "json_sub", False)
    args.dry_run = args.dry_run or getattr(args, "dry_sub", False)
    root = agent_log.resolve_root(args)
    return {"get": cmd_get, "set": cmd_set, "add": cmd_add}[args.cmd](root, args)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
