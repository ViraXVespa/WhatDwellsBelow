#!/usr/bin/env python3
"""design/tunables*.md and balance code CLI: get, set, add, list, diff, range.

    python tools/docs.py tunable get --key <key-or-alias>
    python tools/docs.py tunable set --key <key-or-alias> --set "new Live cell" [--dry-run]
    python tools/docs.py tunable add --after <existing-key> --key NEW_KEY --set "Live cell" [--dry-run]
Code side (tunables_code.py, balance_src.py): defaults in scripts/data/balance/vars_<system>.gd (one per tunables doc),
slider rows in schema_a/b.gd (enemy e_* stats: enemies.gd), debug-menu category in val_cat_map.gd.
    python tools/docs.py tunable list [PREFIX] [--system main|combat|world|economy]
    python tools/docs.py tunable diff                         (code vs sliders vs docs; prove runs it)
    python tools/docs.py tunable set KEY VALUE [--range] [--changelog "bullet"] [--label 0.8.7] [--dry-run]
    python tools/docs.py tunable range KEY MIN MAX [STEP] [--dry-run]          (e_*_hp: the shared enemy stat row)
    python tools/docs.py tunable add KEY --default V --range MIN MAX STEP [--type float|int|bool] [--system S]
        [--after VAR] [--doc-after ROWKEY] [--note "what it does"] [--cat "Debug category"] [--dry-run]
    python tools/docs.py tunable --selftest

`get` prints one line per matching row (file:line, key, Live cell, section; first 8, `--verbose` for every
row with its aliases). Logic lives in tunables_lib.
Summaries: _logs/tunable-row/ and _logs/tunable-patch/.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import md_format_lib as md
import tunables_lib as tl
import balance_src as bs
import tunables_code as tc

def _head(title: str, *extra: str) -> list[str]:
    return [f"tunable {title} {datetime.now(timezone.utc).isoformat()}", "root=.", *extra]

FILES = ("tunables.md", "tunables-combat.md", "tunables-world.md", "tunables-economy.md")

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
    if getattr(args, "verbose", False):
        shown = [x for x in lines[4:] if x.strip()]
    else:
        shown = [f"{agent_log.rel(root, p)}:{h.index + 1}  {h.key_cell} = {h.live_cell}  [{h.section}]" for p, _r, h in found]
        shown = agent_log.fold(shown, keep=8, limit=8)
    return agent_log.finish("tunable-row", root, "\n".join(lines), "PASS" if hits else "FAIL", args=args,
                            echo="\n".join(shown) if hits else f"matches={len(hits)}", matches=len(hits))

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
    lines += [f"section={hit.section}", f"inserted_after_line={hit.index + 1}", "other cells are `-`; fill them (suggested, note) with docs.py patch replace"]
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
    ap = agent_log.std_parser("Read or patch design/tunables*.md rows.", writes=True, json_out=True)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("get", help="Print one tunables row.")
    s.add_argument("key_pos", nargs="?", default="", metavar="KEY", help="Tunable key or unique alias (same as --key)")
    s.add_argument("--key", default="", help="Tunable key or unique alias")
    s.add_argument("--verbose", "-v", action="store_true", help="Every matching row with all its fields (default: one line each, first 8).")
    s = sub.add_parser("set", help="Patch one Live cell.")
    s.add_argument("key_pos", nargs="?", default="", metavar="KEY", help="Tunable key or unique alias (same as --key)")
    s.add_argument("--key", default="", help="Tunable key or unique alias")
    s.add_argument("--set", "--value", dest="value", default=None, help="Doc-only: new Live cell text")
    s.add_argument("code_value", nargs="?", default=None, metavar="VALUE", help="New code default: edits vars_*.gd / enemies.gd / tunables.gd and the doc Live cell")
    s.add_argument("--range", dest="widen", action="store_true", help="With VALUE: widen the slider row to fit it instead of failing")
    s.add_argument("--changelog", default="", help="With VALUE: one changelog bullet (docs.py patch changelog)")
    s.add_argument("--label", default=None, help="Changelog label (default: the one this branch added, else the next)")
    s = sub.add_parser("add", help="Insert a doc row after a key's row; with --default, create the tunable end to end.")
    s.add_argument("key_pos", nargs="?", default="", metavar="KEY", help="New key (no row exists yet; same as --key)")
    s.add_argument("--key", default="", help="New key (no row exists yet)")
    s.add_argument("--after", default="", help="Existing key; the new row (and with --default the var and slider) goes below it")
    s.add_argument("--set", "--value", dest="value", default=None, help="Doc-only add: Live cell text")
    s.add_argument("--default", default=None, help="Create the key: default value (type from the literal or --type)")
    s.add_argument("--range", nargs=3, metavar=("MIN", "MAX", "STEP"), default=None, help="Slider row for --default")
    s.add_argument("--type", choices=("float", "int", "bool"), default=None, help="Value type (default: from the literal)")
    s.add_argument("--system", default="", help="main|combat|world|economy (default: --after's file, else the category's)")
    s.add_argument("--doc-after", dest="doc_after", default="", help="Doc row to insert below (default: --after)")
    s.add_argument("--note", default="", help="Doc Notes cell")
    s.add_argument("--cat", default="", help="Debug-menu category rule for the key (val_cat_map.gd)")
    s = sub.add_parser("list", help="Code defaults: key, value, type, slider, system, category.")
    s.add_argument("key_pos", nargs="?", default="", metavar="PREFIX", help="Key prefix filter")
    s.add_argument("--system", default="", help="main|combat|world|economy|enemy")
    s = sub.add_parser("diff", help="Drift between code defaults, slider rows and doc Live cells (FAIL on any).")
    s = sub.add_parser("range", help="Change a slider row (min max [step]); every default it covers must stay inside.")
    s.add_argument("key_pos", metavar="KEY", help="Key (e_<id>_<stat> or e_*_<stat>: the shared enemy stat row)")
    s.add_argument("lo", metavar="MIN", help="Slider minimum")
    s.add_argument("hi", metavar="MAX", help="Slider maximum")
    s.add_argument("step", nargs="?", default=None, metavar="STEP", help="Default: keep the current step")
    for name in ("get", "set", "add", "list", "diff", "range"):
        sub.choices[name].add_argument("--root", default=None, help="Repo root (default: auto).", dest="root_sub")
        sub.choices[name].add_argument("--json", dest="json_sub", action="store_true", help="Print one JSON object instead of text.")
    sub.choices["set"].add_argument("--dry-run", dest="dry_sub", action="store_true", help="Print what would change; write nothing.")
    sub.choices["add"].add_argument("--dry-run", dest="dry_sub", action="store_true", help="Print what would change; write nothing.")
    sub.choices["range"].add_argument("--dry-run", dest="dry_sub", action="store_true", help="Print what would change; write nothing.")
    ap.add_argument("--selftest", action="store_true", help="Scratch-copy replay of set/range/add/diff (writes nothing here).")
    argv = sys.argv[1:] if argv is None else argv
    if "--selftest" in argv:
        import tunables_selftest
        return tunables_selftest.main()
    args = ap.parse_args(argv)
    args.key = getattr(args, "key", "") or getattr(args, "key_pos", "")
    args.system = getattr(args, "system", "")
    if args.cmd in ("list", "diff"):
        args.root = getattr(args, "root_sub", None) or args.root
        args.json = args.json or getattr(args, "json_sub", False)
        return {"list": tc.cmd_list, "diff": tc.cmd_diff}[args.cmd](agent_log.resolve_root(args), args)
    if not args.key:
        agent_log.fail(f"tunables {args.cmd}: pass a KEY (example: docs.py tunable {args.cmd} move_speed)")
    args.root = getattr(args, "root_sub", None) or args.root
    args.json = args.json or getattr(args, "json_sub", False)
    args.dry_run = args.dry_run or getattr(args, "dry_sub", False)
    root = agent_log.resolve_root(args)
    if args.cmd == "range":
        return tc.cmd_range(root, args)
    if args.cmd == "set" and args.code_value is not None:
        return tc.cmd_set_code(root, args)
    if args.cmd == "set" and getattr(args, "value", None) is None:
        agent_log.fail("tunable set: pass VALUE (code default) or --set TEXT (doc Live cell only)")
    if args.cmd == "add" and args.default is not None:
        return tc.cmd_add_code(root, args)
    if args.cmd == "add" and (not args.after or args.value is None):
        agent_log.fail("tunable add: doc-only needs --after KEY --set TEXT; a new tunable needs --default V --range MIN MAX STEP")
    return {"get": cmd_get, "set": cmd_set, "add": cmd_add}[args.cmd](root, args)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
