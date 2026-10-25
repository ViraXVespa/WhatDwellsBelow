"""`docs.py tunable list|diff|range`, and the code side of `set KEY VALUE` / `add KEY --default`: balance defaults,
slider rows, debug-menu category and the design/tunables*.md row in one edit (balance_src.py reads and writes them).
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

import agent_log
import balance_src as bs
import md_format_lib as md
import tunables_lib as tl

NUM = re.compile(r"^(\*{0,2})(-?\d+(?:\.\d+)?)(\*{0,2}\s*(?:s|%|m|×|x|px)?\*{0,2})$")

def doc_rows(root: Path, key: str) -> list[tuple[str, "tl.Hit"]]:
    """(doc rel, hit) for rows whose key cell is exactly `key` (backticked) in any tunables doc."""
    out = []
    for name in bs.DOC.values():
        p = root / "design" / name
        if p.is_file():
            out += [(f"design/{name}", h) for h in tl.parse_hits(md.read_text(p)) if h.key_cell.strip() == f"`{key}`"]
    return out

def doc_value(cell: str) -> float | None:
    m = NUM.match(cell.strip())
    if not m:
        return None
    v = float(m.group(2))
    return v / 100 if "%" in m.group(3) else v

def _same(a: float, b: float) -> bool:
    return abs(a - b) <= 1e-9 * max(1.0, abs(a), abs(b))

def drift(src: bs.Src) -> tuple[list[str], list[str]]:
    """(DRIFT rows that fail, INFO rows) across code, slider rows, categories and docs."""
    bad, info = [], []
    d = src.defaults()
    rows = src.rows()
    for k, r in rows.items():
        if k not in d:
            bad.append(f"DRIFT {k}: slider row in {r.path}:{r.line + 1} has no default in vars_*.gd / enemies.gd")
        elif d[k].value is not None and not r.lo <= float(d[k].value) <= r.hi:
            bad.append(f"DRIFT {k}: default {d[k].value} outside slider [{bs.fmt('float', r.lo)}, {bs.fmt('float', r.hi)}] ({r.path}:{r.line + 1})")
    no_row = sorted(k for k in d if k not in rows)
    if no_row:
        info.append(f"INFO no_slider={len(no_row)} ({', '.join(no_row[:6])}): not in the debug menu")
    other = sorted(k for k in rows if src.category(k) == "Other")
    if other:
        info.append(f"INFO category_other={len(other)} ({', '.join(other[:6])}): val_cat_map.gd has no rule")
    root = src.root
    for k, v in d.items():
        for rel, h in doc_rows(root, k):
            sysname = next(s for s, n in bs.DOC.items() if rel.endswith("/" + n))
            if v.system not in ("enemy", sysname):
                bad.append(f"DRIFT {k}: doc row in {rel} but the default is in vars_{v.system}.gd (move one; docs and vars files map 1:1)")
            dv = doc_value(h.live_cell)
            if dv is None or v.value is None:
                continue
            if not _same(dv, float(v.value)):
                bad.append(f"DRIFT {k}: {rel}:{h.index + 1} Live {h.live_cell} != code {bs.fmt(v.type, v.value)} ({v.path}:{v.line + 1}); fix with: docs.py tunable set {k} {bs.fmt(v.type, v.value)}")
    return bad, info

def cmd_list(root: Path, args) -> int:
    src = bs.Src(root)
    d, rows = src.defaults(), src.rows()
    pre = (getattr(args, "key", "") or "")
    lines = []
    for k, v in d.items():
        if pre and not k.startswith(pre) or args.system and v.system != args.system:
            continue
        r = rows.get(k)
        rng = f"[{bs.fmt('float', r.lo)}..{bs.fmt('float', r.hi)} /{bs.fmt('float', r.step)}]" if r else "[no slider]"
        val = bs.fmt(v.type, v.value) if v.value is not None else v.expr
        lines.append(f"{k}\t{val}\t{v.type}\t{rng}\t{v.system}\t{src.category(k)}")
    return agent_log.finish("tunable-list", root, "\n".join(lines), "PASS" if lines else "FAIL", args=args,
                            echo="\n".join(agent_log.fold(lines, keep=40, limit=40)) if lines else "matches=0", matches=len(lines))

def cmd_diff(root: Path, args) -> int:
    src = bs.Src(root)
    try:
        bad, info = drift(src)
    except bs.Fail as e:
        bad, info = [f"DRIFT {e}"], []
    body = bad + info
    return agent_log.finish("tunable-diff", root, "\n".join(body), "FAIL" if bad else "PASS", args=args,
                            echo="\n".join(body[:20]) or "clean", drift=len(bad))

def _end(root: Path, job: str, args, lines: list[str], fn) -> int:
    try:
        lines += fn()
        return agent_log.finish(job, root, "\n".join(lines), "PASS", args=args, echo="\n".join(lines), changed=1, dry_run=args.dry_run)
    except bs.Fail as e:
        lines.append(f"error: {e}")
        return agent_log.finish(job, root, "\n".join(lines), "FAIL", args=args, echo="\n".join(lines), changed=0, error=str(e)[:200])

def _patch_doc(src: bs.Src, key: str, kind: str, value: object) -> list[str]:
    rows = doc_rows(src.root, key)
    if not rows:
        return [f"doc=none (curated tables; add a row with: docs.py tunable add --after NEIGHBOR --key {key} --set ...)"]
    out = []
    for rel, h in rows:
        m = NUM.match(h.live_cell.strip())
        if not m:
            out.append(f"doc={rel}:{h.index + 1} Live {h.live_cell!r} is not one number; patch it: docs.py tunable set --key {key} --set ...")
            continue
        new = bs.fmt(kind, value) if "%" not in m.group(3) else bs.fmt("float", float(value) * 100)
        if "." not in m.group(2) and new.endswith(".0"):
            new = new[:-2]  # the row writes whole numbers bare (20, not 20.0)
        cell = m.group(1) + new + m.group(3)
        src.set_line(rel, h.index, tl.set_live_cell(src.lines(rel)[h.index], h.live_col, cell))
        out.append(f"doc={rel}:{h.index + 1} Live {h.live_cell} -> {cell}")
    return out

def _changelog(root: Path, text: str, label: str | None, dry: bool) -> list[str]:
    if not text:
        return []
    if not label:
        r = subprocess.run(["git", "diff", "--name-only", "--diff-filter=A", "origin/main...HEAD", "--", "design/changelog"],
                           cwd=root, capture_output=True, text=True)
        added = [Path(p).stem for p in r.stdout.split() if re.fullmatch(r"\d+\.\d+\.\d+", Path(p).stem)]
        label = added[0] if len(added) == 1 else None
    if dry:
        return [f"changelog={label or 'next'} (dry-run)"]
    import doc_patch
    path = doc_patch.write_changelog(root, [text], label)
    return [f"changelog={agent_log.rel(root, path)}"]

def cmd_set_code(root: Path, args) -> int:
    lines = [f"tunable set {args.key}={args.code_value}"]

    def run() -> list[str]:
        src = bs.Src(root)
        d, rows = src.defaults(), src.rows()
        v = d.get(args.key)
        if v is None:
            raise bs.Fail(f"{args.key} is not a balance key (vars_*.gd / enemies.gd); a doc-only row takes --set TEXT")
        val = bs.parse_value(v.type, args.code_value)
        out = []
        r = rows.get(args.key)
        if r:
            lo, hi = r.lo, r.hi
            if not lo <= float(val) <= hi:
                if not args.widen:
                    raise bs.Fail(f"{args.key}: {args.code_value} is outside its slider [{bs.fmt('float', lo)}, {bs.fmt('float', hi)}]; add --range to widen it")
                lo, hi = min(lo, float(val)), max(hi, float(val))
                out += _set_row(src, r, lo, hi, r.step, d, rows)
        if v.system == "enemy":
            ln = src.lines(v.path)[v.line]
            st = args.key.rsplit("_", 1)[1]
            src.set_line(v.path, v.line, re.sub(rf'("{st}": )-?[0-9.]+', lambda m: m.group(1) + bs.fmt("float", val), ln, count=1))
        else:
            ref = re.fullmatch(r"T\.([A-Z0-9_]+)", v.expr)
            if ref:
                i = src.consts()[ref.group(1)][0]
                ln = src.lines(bs.TCONST)[i]
                src.set_line(bs.TCONST, i, re.sub(r"(=\s*).+?(\s*)$", lambda m: m.group(1) + bs.fmt(v.type, val), ln.rstrip("\r\n")))
                out.append(f"code={bs.TCONST}:{i + 1} {ref.group(1)} (vars_{v.system}.gd reads T.{ref.group(1)})")
            elif v.value is None:
                raise bs.Fail(f"{args.key} = {v.expr} in {v.path}: not a literal (player prefs live in store_data.gd DEF); edit by hand")
            else:
                ln = src.lines(v.path)[v.line].rstrip("\r\n")
                m = bs.VAR_RE.match(ln)
                src.set_line(v.path, v.line, ln[: m.start(3)] + bs.fmt(v.type, val) + ln[m.end(3):])
        if not out or not out[-1].startswith("code="):
            out.append(f"code={v.path}:{v.line + 1} {bs.fmt(v.type, v.value) if v.value is not None else v.expr} -> {bs.fmt(v.type, val)}")
        out += _patch_doc(src, args.key, v.type, val)
        out += [f"wrote={','.join(src.write(args.dry_run))}" + (" (dry-run)" if args.dry_run else "")]
        out += _changelog(root, args.changelog, args.label, args.dry_run)
        return out

    return _end(root, "tunable-set-code", args, lines, run)

def _set_row(src: bs.Src, r: bs.Row, lo: float, hi: float, step: float, d: dict, rows: dict) -> list[str]:
    keys = [k for k, x in rows.items() if x.path == r.path and x.line == r.line]
    for k in keys:
        v = d.get(k)
        bs.check_range(k, v.type if v else "float", lo, hi, step, v.value if v else None)
    ln = src.lines(r.path)[r.line].rstrip("\r\n")
    if r.shared > 1:
        st = r.key.rsplit("_", 1)[1]
        new = re.sub(r"\[(\"e_%s_[a-z]+\" % id),.*\]\)", lambda m: f"[{m.group(1)}, {bs.fmt('float', lo)}, {bs.fmt('float', hi)}, {bs.fmt('float', step)}])", ln)
        src.set_line(r.path, r.line, new)
        return [f"range={r.path}:{r.line + 1} e_*_{st} (shared by {r.shared} enemies) -> [{bs.fmt('float', lo)}, {bs.fmt('float', hi)}, {bs.fmt('float', step)}]"]
    indent = bs.ROW_RE.match(ln).group(1)
    src.set_line(r.path, r.line, bs.row_text(indent, r.key, lo, hi, step))
    return [f"range={r.path}:{r.line + 1} {r.key} [{bs.fmt('float', r.lo)}, {bs.fmt('float', r.hi)}, {bs.fmt('float', r.step)}] -> [{bs.fmt('float', lo)}, {bs.fmt('float', hi)}, {bs.fmt('float', step)}]"]

def cmd_range(root: Path, args) -> int:
    lines = [f"tunable range {args.key} {args.lo} {args.hi} {args.step or ''}".rstrip()]

    def run() -> list[str]:
        src = bs.Src(root)
        d, rows = src.defaults(), src.rows()
        key = args.key.replace("e_*_", "e_%s_" % sorted(k.split("_")[1] for k in src.enemies())[0]) if args.key.startswith("e_*_") else args.key
        r = rows.get(key)
        if r is None:
            raise bs.Fail(f"{args.key} has no slider row (schema_a/b.gd, enemies.gd); `tunable add` creates key + row together")
        lo, hi = bs.parse_value("float", args.lo), bs.parse_value("float", args.hi)
        step = bs.parse_value("float", args.step) if args.step else r.step
        out = _set_row(src, r, lo, hi, step, d, rows)
        return out + [f"wrote={','.join(src.write(args.dry_run))}" + (" (dry-run)" if args.dry_run else "")]

    return _end(root, "tunable-range", args, lines, run)

def _system_for(src: bs.Src, key: str, args, neighbor: bs.Var | None) -> str:
    if args.system:
        if args.system not in bs.SYSTEMS:
            raise bs.Fail(f"--system {args.system}: pick one of {', '.join(bs.SYSTEMS)}")
        if neighbor and neighbor.system != args.system:
            raise bs.Fail(f"--after {neighbor.key} lives in vars_{neighbor.system}.gd but --system is {args.system}")
        return args.system
    if neighbor:
        return neighbor.system
    cat = args.cat or src.category(key)
    s = bs.cat_system(cat)
    if not s:
        raise bs.Fail(f"{key}: system is ambiguous (debug-menu category {cat!r}); pass --system {'|'.join(bs.SYSTEMS)} or --after NEIGHBOR")
    return s

def cmd_add_code(root: Path, args) -> int:
    lines = [f"tunable add {args.key} default={args.default} range={args.range}"]

    def run() -> list[str]:
        src = bs.Src(root)
        key = args.key
        if key.startswith("e_"):
            raise bs.Fail(f"{key}: enemy stats are e_<id>_<stat> from enemies.gd (IDS x defaults()); add an enemy or stat there by hand")
        if not bs.KEY_RE.fullmatch(key) or "__" in key:
            raise bs.Fail(f"{key}: keys are snake_case (a-z, 0-9, _), start with a letter, no trailing/double _")
        d, rows = src.defaults(), src.rows()
        if key in d or key in rows or key in bs.RESERVED:
            raise bs.Fail(f"{key} already exists" + (f" ({d[key].path}:{d[key].line + 1})" if key in d else ""))
        if not args.range:
            raise bs.Fail("--range MIN MAX STEP is required (the debug-menu slider)")
        kind = args.type or (bs.literal(args.default)[0] if bs.literal(args.default) else None)
        if kind not in ("float", "int", "bool"):
            raise bs.Fail(f"--default {args.default!r}: give a float (0.5), int (3) or bool (true); or pass --type")
        val = bs.parse_value(kind, args.default)
        lo, hi, step = (bs.parse_value("float", x) for x in args.range)
        bs.check_range(key, kind, lo, hi, step, val)
        cats = src.cat_rules()[0]
        if args.cat and args.cat not in cats:
            raise bs.Fail(f"--cat {args.cat!r}: not a debug-menu category ({', '.join(cats)})")
        nb = d.get(args.after) if args.after else None
        if args.after and (nb is None or nb.system == "enemy"):
            raise bs.Fail(f"--after {args.after}: not a vars_*.gd key")
        system = _system_for(src, key, args, nb)
        out = []
        # 1. default
        rel = f"{bs.BAL}/vars_{system}.gd"
        decl = f"var {key} := {bs.fmt(kind, val)}"
        at = nb.line + 1 if nb else len(src.lines(rel))
        src.insert(rel, at, decl)
        out.append(f"code={rel}:{at + 1} {decl}")
        # 2. slider row
        nrow = rows.get(args.after) if args.after else None
        srel = nrow.path if nrow and nrow.shared == 1 else bs.SCHEMAS[-1]
        sl = src.lines(srel)
        if nrow and nrow.shared == 1:
            i = nrow.line + 1
        else:
            i = max(j for j, ln in enumerate(sl) if ln.strip() == "]")
        indent = next(m.group(1) for m in map(bs.ROW_RE.match, (x.rstrip("\r\n") for x in sl)) if m)
        src.insert(srel, i, bs.row_text(indent, key, lo, hi, step))
        out.append(f"slider={srel}:{i + 1} [{bs.fmt('float', lo)}, {bs.fmt('float', hi)}, {bs.fmt('float', step)}]")
        # 3. debug-menu category
        if args.cat:
            _cats, _rules, opener = src.cat_rules()
            src.insert(bs.CATMAP, opener + 1, f'\t["{key}", "{args.cat}"],')
            out.append(f"category={args.cat} (rule {bs.CATMAP}:{opener + 2})")
        else:
            cat = src.category(key)
            out.append(f"category={cat}" + (" (no val_cat_map rule matches; pass --cat to file it)" if cat == "Other" else " (prefix rule)"))
        # 4. doc row
        out += _add_doc(src, key, system, kind, val, args)
        out.append(f"wrote={','.join(src.write(args.dry_run))}" + (" (dry-run)" if args.dry_run else ""))
        return out

    return _end(root, "tunable-add-code", args, lines, run)

def _add_doc(src: bs.Src, key: str, system: str, kind: str, val: object, args) -> list[str]:
    rel = f"design/{bs.DOC[system]}"
    anchor = args.doc_after or args.after
    hits = [h for h in tl.parse_hits("".join(src.lines(rel))) if anchor and tl.find_hits([h], anchor)]
    exact = [h for h in hits if h.key_cell.strip() == f"`{anchor}`"]
    hits = exact or hits
    if len(hits) != 1:
        raise bs.Fail(f"doc row: pass --doc-after KEY naming one row of {rel} (the table the key belongs to)"
                      + (f"; {anchor!r} matched {len(hits)}" if anchor else ""))
    h = hits[0]
    ls = src.lines(rel)
    head = next(i for i in range(h.index, -1, -1) if any(c in ("key", "parameter") for c in (x.strip().lower() for x in ls[i].strip().strip("|").split("|"))))
    names = [x.strip().lower() for x in ls[head].strip().strip("|").split("|")]
    cells = ["-"] * h.n_cols
    cells[0] = f"`{key}`"
    cells[h.live_col] = bs.fmt(kind, val)
    note = next((i for i, n in enumerate(names) if n in ("notes", "note", "role", "what it does")), None)
    if args.note:
        if note is None:
            raise bs.Fail(f"{rel} table at line {head + 1} has no Notes column for --note")
        cells[note] = args.note.replace("|", "/")
    src.insert(rel, h.index + 1, "| " + " | ".join(cells) + " |")
    return [f"doc={rel}:{h.index + 2} [{h.section}]" + ("" if args.note or note is None else " (Notes cell `-`: pass --note)")]
