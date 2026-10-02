#!/usr/bin/env python3
"""Idempotent text/doc edit library and CLI (design/doc-library.md).

CLI (no scratch file needed; --dry-run prints "would write" and changes nothing):

    python3 tools/doc_patch.py replace FILE --old "x" --new "y"
    python3 tools/doc_patch.py ensure-line FILE --line "text" [--after "anchor"]
    python3 tools/doc_patch.py set-read-when FILE "when text"
    python3 tools/doc_patch.py changelog --bullet "one line" [--bullet ...] [--label 0.5.11] [--summary "s"]
    python3 tools/doc_patch.py next-label
    python3 tools/doc_patch.py write FILE [--b64 S | stdin] [--bom] [--append]
    python3 tools/doc_patch.py replace-file FILE (--from-file NEW | stdin)   # whole-file rewrite, file must exist; BOM + CRLF kept
    python3 tools/doc_patch.py apply plan.json
    python3 tools/doc_patch.py check

Library: scratch runners import this module instead of copying replace logic:

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import doc_patch as dp
"""
from __future__ import annotations

import argparse
import base64
import collections
import json
import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import gd_lib
import md_format_lib as md
import repo_lib

DRY = False  # set by the CLI --dry-run; library callers may set dp.DRY = True
EOL = "keep"  # keep | crlf | lf. keep = the existing file's line ending (CRLF for new files)


def _gd_tabs(text: str) -> str:
    out: list[str] = []
    for line in text.splitlines(keepends=True):
        raw = line.lstrip(" ")
        spaces = len(line) - len(raw)
        if spaces and spaces % 4 == 0 and raw[:1] != " ":
            line = ("\t" * (spaces // 4)) + raw
        out.append(line)
    return "".join(out)


def _py_ok(path: Path, text: str) -> None:
    if path.suffix != ".py":
        return
    try:
        compile(text, str(path), "exec")
    except SyntaxError as exc:
        raise SystemExit("FAIL  py syntax %s:%s: %s" % (path.as_posix(), exc.lineno, exc.msg)) from exc
    if "from __future__ import" not in text:
        return
    body = text.lstrip("\ufeff")
    lines = body.splitlines()
    i = 0
    if lines and lines[0].startswith("#!"):
        i = 1
    while i < len(lines) and (not lines[i].strip() or lines[i].lstrip().startswith("#")):
        i += 1
    mark = lines[i][:3] if i < len(lines) else ""
    if mark in (chr(34) * 3, chr(39) * 3):
        if lines[i].count(mark) < 2:
            i += 1
            while i < len(lines) and mark not in lines[i]:
                i += 1
        i += 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines) or not lines[i].startswith("from __future__ import"):
        raise SystemExit("FAIL  future import not first in %s" % path.as_posix())


def _near(lines: list[str], needle: str) -> str:
    want = needle.strip()
    best = 0
    score = -1
    for i, ln in enumerate(lines):
        got = ln.strip()
        n = 0
        for ch_a, ch_b in zip(got, want):
            if ch_a != ch_b:
                break
            n += 1
        if n > score:
            score = n
            best = i
    lo = max(0, best - 1)
    hi = min(len(lines), best + 2)
    shown = " | ".join(lines[j].strip() for j in range(lo, hi))
    return "line %d: %s" % (best + 1, shown)


def func_count(text: str, name: str) -> int:
    return gd_lib.func_count(text, name)


def repo_root(start: Path | None = None) -> Path:
    try:
        return agent_log.repo_root(start)
    except FileNotFoundError:
        raise SystemExit("FAIL  run from the WhatDwellsBelow repo root")


def _shown(path: Path) -> str:
    try:
        return agent_log.rel(agent_log.repo_root(), path)
    except FileNotFoundError:
        return Path(path).as_posix()


def read_text(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL  missing {path.as_posix()}")
    return md.read_text(path)


def write_text(path: Path, text: str) -> None:
    if path.suffix == ".gd":
        text = _gd_tabs(text)
    _py_ok(path, text)
    if DRY:
        print("  would write %s (%d bytes)" % (_shown(path), len(text.encode("utf-8"))))
        return
    md.write_text(path, text, eol=EOL, mkdir=True)
    print("  wrote %s (%d bytes)" % (_shown(path), path.stat().st_size))


def _variants(old: str) -> list[str]:
    return md.path_tick_variants(old)


def replace_once(text: str, old: str, new: str, where: str) -> str:
    hit = md.replace_once_text(text, old, new, path=where)
    if hit is not None:
        return hit
    if new in text:
        print(f"  skip {where} (already applied)")
        return text
    raise SystemExit(f"FAIL  patch miss in {where}: {old[:96]!r}")


def replace_once_any(text: str, olds: list[str], new: str, where: str) -> str:
    if new in text:
        print(f"  skip {where} (already applied)")
        return text
    last = ""
    for old in olds:
        last = old
        for cand in _variants(old):
            if cand in text:
                return text.replace(cand, new, 1)
    raise SystemExit(f"FAIL  patch miss in {where}: {last[:96]!r}")



def func_span(text: str, name: str) -> tuple[int, int]:
    """Line range [start, end) for column-0 func name( / static func name(."""
    try:
        return gd_lib.func_span(text, name)
    except ValueError:
        raise SystemExit(f"FAIL  func {name} missing")


def replace_func(path: Path, name: str, new_src: str) -> None:
    text = read_text(path)
    if func_count(text, name) > 1:
        raise SystemExit("FAIL  func %s duplicated in %s" % (name, path.as_posix()))
    lines = text.splitlines(keepends=True)
    start, end = func_span(text, name)
    body = new_src if new_src.endswith("\n") else new_src + "\n"
    write_text(path, "".join(lines[:start]) + body + "".join(lines[end:]))


def upsert_func(path: Path, name: str, new_src: str) -> None:
    text = read_text(path)
    if func_count(text, name) > 1:
        raise SystemExit("FAIL  func %s duplicated in %s" % (name, path.as_posix()))
    if func_count(text, name) == 1:
        replace_func(path, name, new_src)
        return
    body = new_src if new_src.endswith("\n") else new_src + "\n"
    if not body.endswith("\n\n"):
        body = body.rstrip("\n") + "\n\n"
    lines = text.splitlines(keepends=True)
    at = len(lines)
    for i, ln in enumerate(lines):
        if ln.startswith("func ") or ln.startswith("static func "):
            at = i
    write_text(path, "".join(lines[:at]) + body + "".join(lines[at:]))


def replace_block(path: Path, start_pred, end_pred, new_src: str) -> None:
    """Replace a line span. start_pred/end_pred are callables(line, index, lines)->bool."""
    text = read_text(path)
    lines = text.splitlines(keepends=True)
    start = next((i for i, ln in enumerate(lines) if start_pred(ln, i, lines)), -1)
    if start < 0:
        raise SystemExit(f"FAIL  block start miss in {path.as_posix()}")
    end = start + 1
    while end < len(lines) and not end_pred(lines[end], end, lines):
        end += 1
    if end < len(lines) and end_pred(lines[end], end, lines):
        end += 1
    body = new_src if new_src.endswith("\n") else new_src + "\n"
    write_text(path, "".join(lines[:start]) + body + "".join(lines[end:]))


def run_cmd(argv: list, cwd: Path | None = None):
    root = repo_root(cwd)
    proc = subprocess.run(list(argv), cwd=str(root))
    return proc.returncode, ""


def patch_file(path: Path, old: str, new: str) -> None:
    text = replace_once(read_text(path), old, new, path.as_posix())
    write_text(path, text)


def set_read_when(path: Path, value: str) -> None:
    text = read_text(path)
    new_line = f"Read when: {value.rstrip()}"
    updated, n = re.subn(r"^Read when:.*$", new_line, text, count=1, flags=re.M)
    if n == 0:
        raise SystemExit(f"FAIL  no Read when in {path.as_posix()}")
    if updated == text:
        print(f"  skip {path.as_posix()} Read when (already applied)")
        return
    write_text(path, updated)


def ensure_line(path: Path, line: str, after: str | None = None) -> None:
    text = read_text(path)
    needle = line.rstrip("\n")
    if needle in text or any(ln.strip() == needle.strip() for ln in text.splitlines()):
        print("  skip %s ensure_line (already applied)" % path.as_posix())
        return
    insert = needle + "\n"
    if after is None:
        write_text(path, text.rstrip("\n") + "\n" + insert)
        return
    lines = text.splitlines(keepends=True)
    want = after.strip()
    hit = -1
    for i, ln in enumerate(lines):
        if ln.strip() == want or after in ln:
            hit = i
            break
    if hit < 0:
        raise SystemExit(
            "FAIL  ensure_line anchor miss in %s: %r near %s" % (path.as_posix(), after[:96], _near(lines, after))
        )
    lines.insert(hit + 1, insert if insert.endswith("\n") else insert + "\n")
    write_text(path, "".join(lines))

def drop_citations(path: Path, needles: list[str]) -> None:
    text = read_text(path)
    keep: list[str] = []
    changed = False
    for line in text.splitlines(keepends=True):
        if any(n in line for n in needles):
            changed = True
            continue
        keep.append(line)
    if not changed:
        print(f"  skip {path.as_posix()} drop_citations (already applied)")
        return
    write_text(path, "".join(keep))


def drop_table_column(path: Path, header: str) -> None:
    text = read_text(path)
    lines = text.splitlines(keepends=True)
    idx = None
    out: list[str] = []
    in_table = False
    changed = False
    for line in lines:
        if line.startswith("|") and header in line and idx is None:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if header in cells:
                idx = cells.index(header)
                in_table = True
        if in_table and line.startswith("|") and idx is not None:
            raw = line.strip().strip("|").split("|")
            if len(raw) > idx:
                raw.pop(idx)
                line = "| " + " | ".join(c.strip() for c in raw) + " |\n"
                changed = True
        elif in_table and not line.startswith("|"):
            in_table = False
        out.append(line)
    if not changed:
        print(f"  skip {path.as_posix()} drop_table_column (already applied)")
        return
    write_text(path, "".join(out))


def next_label(root: Path | None = None) -> str:
    """Baked version.json label with patch + 1. Ignore stamp commits."""
    return repo_lib.next_label(repo_root(root))


def _ensure_summary(text: str, summary: str) -> tuple[str, bool]:
    line = f"Summary: {summary.strip()}"
    if re.search(r"^Summary:", text, re.I | re.M):
        return text, False
    if not text.endswith("\n"):
        text += "\n"
    return text + "\n" + line + "\n", True


def write_changelog(root: Path, bullets: list[str], label: str | None = None, summary: str | None = None) -> Path:
    root = repo_root(root)
    label = label or next_label(root)
    path = root / "design/changelog" / f"{label}.md"
    incoming = [b.rstrip() for b in bullets if b.strip()]
    if path.is_file():
        text = read_text(path)
        added = False
        found = re.search(r"(?im)^Summary:", text)
        insert_at = found.start() if found else len(text)
        chunk = ""
        for bullet in incoming:
            line = f"- {bullet}"
            if line in text or bullet in text:
                continue
            chunk += line + "\n"
            added = True
        if chunk:
            prefix = text[:insert_at].rstrip("\n") + "\n"
            suffix = text[insert_at:].lstrip("\n")
            text = prefix + chunk
            if suffix:
                if not text.endswith("\n"):
                    text += "\n"
                if suffix.startswith("Summary:"):
                    text += "\n"
                text += suffix
        if summary:
            text, sum_added = _ensure_summary(text, summary)
            added = added or sum_added
        if added:
            write_text(path, text)
        else:
            print(f"  skip {path.as_posix()} (bullets already present)")
        return path
    body = f"## {label}\n\n" + "".join(f"- {b}\n" for b in incoming)
    if summary:
        body += f"\nSummary: {summary}\n"
    write_text(path, body)
    return path


def run_checker(root: Path | None = None) -> int:
    root = repo_root(root)
    print("running tools/check_load_graph.py")
    proc = subprocess.run(
        [sys.executable, str(root / "tools/check_load_graph.py"), "--root", str(root)],
        cwd=str(root),
    )
    if proc.returncode != 0:
        print(f"FAIL  check_load_graph exit {proc.returncode}")
    return proc.returncode

JOB_SCRIPTS = {
    "build-gate": "run_build_gate.ps1",
    "dungeon-map": "run_dungeon_map.ps1",
    "load-timing": "run_load_timing.ps1",
    "dungeon-load-timing": "run_dungeon_load_timing.ps1",
    "smokes": "run_smokes.ps1",
}  # stems; run_prove() picks the .py twin when it exists, else the .ps1


def out(text: str) -> None:
    text = str(text).replace("\ufeff", "").rstrip()
    sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))
    sys.stdout.buffer.flush()


def compile_broke(body: str) -> bool:
    low = body.lower()
    return (
        "parse error" in low
        or "compile error" in low
        or "failed to compile" in low
        or "failed to load script" in low
    )


def dump_job(root: Path | None, job: str, script: str | None = None) -> tuple[int, str]:
    """Run a prove runner (tools/<stem>.py if it exists, else the .ps1), print its summary.txt body, return (rc, body)."""
    root = repo_root(root)
    name = script or JOB_SCRIPTS.get(job)
    if not name:
        raise SystemExit(f"FAIL  unknown prove job {job!r}")
    py = root / "tools" / (Path(name).stem + ".py")
    cmd = [sys.executable, str(py)] if py.is_file() else ["powershell", "-File", str(root / "tools" / name)]
    proc = subprocess.run(cmd, cwd=str(root), capture_output=True)
    exact = root / "_logs" / job / "summary.txt"
    hits = [exact] if exact.is_file() else sorted(
        (
            p
            for p in (root / "_logs").rglob("summary.txt")
            if p.is_file() and job in p.as_posix().replace("\\", "/")
        ),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    body = hits[0].read_text(encoding="utf-8-sig") if hits else ""
    if body:
        out(body)
    else:
        out(f"missing {job} summary")
        err = (proc.stderr or b"").decode("utf-8", errors="replace")
        if err:
            out(err[-2000:])
    broke = "COMPILE" in body or "clean=false" in body or compile_broke(body)
    if broke and hits:
        extra: list[str] = []
        for p in hits[0].parent.glob("*"):
            n = p.name.lower()
            if p.is_file() and ("err" in n) and p.suffix.lower() in {".log", ".txt"}:
                extra.append(p.read_text(encoding="utf-8-sig", errors="replace")[-4000:])
        if extra:
            out("--- err log ---")
            out("\n".join(extra))
            body = body + "\n" + "\n".join(extra)
    return int(proc.returncode), body


def _arg_text(inline: str | None, file: str | None, what: str) -> str:
    if file:
        return md.read_text(file)
    if inline is None:
        raise SystemExit(f"FAIL  need --{what} or --{what}-file")
    return inline.replace("\\n", "\n") if "\\n" in inline and "\n" not in inline else inline


def _run_op(root: Path, op: dict) -> None:
    kind = op["op"]
    path = root / op["file"] if "file" in op else None
    if kind == "replace":
        patch_file(path, op["old"], op["new"])
    elif kind == "ensure-line":
        ensure_line(path, op["line"], op.get("after"))
    elif kind == "set-read-when":
        set_read_when(path, op["value"])
    elif kind == "changelog":
        write_changelog(root, list(op["bullets"]), op.get("label"), op.get("summary"))
    elif kind == "write":
        write_text(path, op["text"])
    elif kind == "replace-file":
        replace_file(path, op["text"])
    elif kind == "replace-func":
        replace_func(path, op["name"], op["src"])
    elif kind == "upsert-func":
        upsert_func(path, op["name"], op["src"])
    else:
        raise SystemExit(f"FAIL  unknown op {kind!r} (replace, ensure-line, set-read-when, changelog, write, replace-file, replace-func, upsert-func)")


def _write_cmd(root: Path, args: argparse.Namespace) -> None:
    body = base64.b64decode(args.b64) if args.b64 is not None else sys.stdin.buffer.read()
    if body.startswith(b"\xef\xbb\xbf"):
        body = body[3:]
    path = Path(args.file)
    path = path if path.is_absolute() else root / path
    text = body.decode("utf-8")
    if args.append and path.is_file():
        text = read_text(path).rstrip("\n") + "\n" + text
    if DRY:
        print("  would write %s (%d bytes)" % (_shown(path), len(text.encode("utf-8"))))
        return
    md.write_text(path, text, eol=EOL, bom=True if args.bom else None, mkdir=True)
    print("  wrote %s (%d bytes)" % (_shown(path), path.stat().st_size))


def replace_file(path: Path, body: str) -> tuple[int, int]:
    """Rewrite an existing file with `body`, keeping its BOM and line endings. Returns (lines added, lines removed)."""
    if not path.is_file():
        raise SystemExit(f"FAIL  replace-file needs an existing file, missing {_shown(path)} (use `write` to create one)")
    if not body.strip():
        raise SystemExit("FAIL  replace-file got an empty body; refusing to blank " + _shown(path))
    old = read_text(path).splitlines()
    new = md.force_lf(body).splitlines()
    gone = collections.Counter(old) - collections.Counter(new)
    added = collections.Counter(new) - collections.Counter(old)
    write_text(path, body)
    return sum(added.values()), sum(gone.values())


def _replace_file_cmd(root: Path, args: argparse.Namespace) -> tuple[int, int]:
    if args.from_file:
        body = md.read_text(args.from_file)
    elif args.b64 is not None:
        body = base64.b64decode(args.b64).decode("utf-8-sig")
    elif sys.stdin.isatty():
        raise SystemExit("FAIL  replace-file needs the new text: --from-file PATH, --b64 S, or pipe it on stdin")
    else:
        body = sys.stdin.buffer.read().decode("utf-8-sig")
    path = Path(args.file)
    return replace_file(path if path.is_absolute() else root / path, body)


def main(argv: list[str] | None = None) -> int:
    global DRY, EOL
    ap = agent_log.std_parser("Idempotent text/doc edits without a scratch file.", writes=True)
    ap.add_argument("--eol", choices=("keep", "crlf", "lf"), default="keep", help="Line ending for written files (default keep the file's own).")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("replace", help="Replace the first occurrence (idempotent).")
    s.add_argument("file"); s.add_argument("--old"); s.add_argument("--old-file"); s.add_argument("--new"); s.add_argument("--new-file")
    s = sub.add_parser("ensure-line", help="Add a line if missing.")
    s.add_argument("file"); s.add_argument("--line", required=True); s.add_argument("--after")
    s = sub.add_parser("set-read-when", help="Set the 'Read when:' line.")
    s.add_argument("file"); s.add_argument("value")
    s = sub.add_parser("changelog", help="Add bullets to design/changelog/<label>.md.")
    s.add_argument("--bullet", action="append", required=True); s.add_argument("--label"); s.add_argument("--summary")
    sub.add_parser("next-label", help="Print the next changelog label.")
    s = sub.add_parser("write", help="Write a file from stdin or --b64 (BOM stripped, EOL kept).")
    s.add_argument("file"); s.add_argument("--b64"); s.add_argument("--bom", action="store_true"); s.add_argument("--append", action="store_true")
    s = sub.add_parser("replace-file", help="Rewrite a whole existing file from --from-file / --b64 / stdin (BOM and EOL kept).")
    s.add_argument("file"); s.add_argument("--from-file"); s.add_argument("--b64")
    s = sub.add_parser("apply", help="Run a JSON plan: {\"ops\": [{op, file, ...}], \"check\": true} or a bare list.")
    s.add_argument("plan")
    sub.add_parser("check", help="Run tools/check_load_graph.py.")
    args = ap.parse_args(argv)
    DRY, EOL = bool(args.dry_run), args.eol
    root = agent_log.resolve_root(args)
    try:
        if args.cmd == "replace":
            patch_file(root / args.file, _arg_text(args.old, args.old_file, "old"), _arg_text(args.new, args.new_file, "new"))
        elif args.cmd == "ensure-line":
            ensure_line(root / args.file, args.line, args.after)
        elif args.cmd == "set-read-when":
            set_read_when(root / args.file, args.value)
        elif args.cmd == "changelog":
            write_changelog(root, args.bullet, args.label, args.summary)
        elif args.cmd == "next-label":
            label = next_label(root)
            print(f"next={label}")
            return agent_log.emit_result("INFO", next=label)
        elif args.cmd == "write":
            _write_cmd(root, args)
        elif args.cmd == "replace-file":
            plus, minus = _replace_file_cmd(root, args)
            return agent_log.emit_result("PASS", cmd="replace-file", added=plus, removed=minus, dry_run=DRY)
        elif args.cmd == "apply":
            plan = json.loads(md.read_text(args.plan))
            ops = plan["ops"] if isinstance(plan, dict) else plan
            for op in ops:
                _run_op(root, op)
            if isinstance(plan, dict) and plan.get("check") and not DRY:
                if run_checker(root) != 0:
                    return agent_log.emit_result("FAIL", cmd="apply", ops=len(ops), checker="FAIL")
            return agent_log.emit_result("PASS", cmd="apply", ops=len(ops), dry_run=DRY)
        elif args.cmd == "check":
            rc = run_checker(root)
            return agent_log.emit_result("PASS" if rc == 0 else "FAIL", cmd="check", checker="PASS" if rc == 0 else "FAIL")
    except SystemExit as exc:
        if isinstance(exc.code, str):
            print("error: " + re.sub(r"^FAIL\s+", "", exc.code), file=sys.stderr)
            return agent_log.emit_result("FAIL", cmd=args.cmd)
        raise
    return agent_log.emit_result("PASS", cmd=args.cmd, dry_run=DRY)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
