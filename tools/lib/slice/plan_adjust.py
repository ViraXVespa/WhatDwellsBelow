#!/usr/bin/env python3
"""Adjust the context index in session-plan.md (below `<!-- gathered -->`), logging every change in the same step.

    python tools/slice.py adjust add-func PATH NAME [--cand --when TEXT] [--why TEXT] [--reason R]
    python tools/slice.py adjust add-file PATH [--lines A-B] | add-doc PATH[#Heading] | add-doc PATH --lines A-B | add-names PATH
                                                         (same flags; one path may hold several --lines ranges)
    python tools/slice.py adjust rem ID|REF   (aliases rem-func PATH NAME, rem-file PATH, rem-doc REF)
    python tools/slice.py adjust promote ID [--why TEXT] | demote ID TEXT | set-condition ID TEXT
                                                         (demote and set-condition also take --when TEXT instead)
    python tools/slice.py adjust batch FILE|- | batch --op "OP ARGS" [--op ...]   one op per line or per --op (# comments)
    python tools/slice.py adjust report --text "judgment" [--halt REASON]
New items are core unless --cand (a candidate needs --when). Ops run by the gather agent (WDB_ROLE=gather) set the
index identity to `gather: agent`. Every op appends one line to _logs/gather/delta.jsonl
(by = $WDB_ROLE or build; reason optional, default "(none)"); `slice.py plan --refresh` replays them after a re-seed.
`report` writes _logs/gather/report.md (delta summary + the text) and with --halt also _logs/gather/halt, which makes
`slice.py open` refuse to launch the main session. Format: plan_index.py. --selftest runs the cases in a temp repo.
Output: applied ops fold after 12 (--verbose prints all); errors always print in full, also under --dry-run, and
--json carries them (`error_text`) with the applied list (`done`).
"""
from __future__ import annotations

import contextlib
import io
import json
import os
import shlex
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import md_format_lib as md
import plan_index as pi

PLAN = "session-plan.md"
GATHER = "_logs/gather"
OPS = ("add-func", "add-file", "add-doc", "add-names", "rem", "rem-func", "rem-file", "rem-doc", "promote", "demote",
       "set-condition", "batch", "report")
USAGE = {  # one line per op; --help prints them and errors quote them
    "add-func": "add-func PATH NAME [--cand --when TEXT] [--why TEXT] [--reason R]",
    "add-file": "add-file PATH [--lines A-B] [--cand --when TEXT] [--why TEXT]  (.gd --lines stores each covering func)",
    "add-doc": "add-doc PATH[#Heading] | add-doc PATH --lines A-B (same flags as add-file)",
    "add-names": "add-names PATH (same flags as add-file)",
    "rem": "rem ID|REF (or rem-func PATH NAME, rem-file PATH, rem-doc REF)",
    "rem-func": "rem-func PATH NAME", "rem-file": "rem-file PATH", "rem-doc": "rem-doc REF",
    "promote": "promote ID [--why TEXT]",
    "demote": "demote ID TEXT  or  demote ID --when TEXT",
    "set-condition": "set-condition ID TEXT  or  set-condition ID --when TEXT",
    "batch": "batch FILE|-  or  batch --op 'OP ARGS' [--op ...] (one op per line or --op; # comments)",
    "report": "report --text TEXT [--halt REASON]",
}
EPILOG = "ops:\n" + "\n".join(f"  {u}" for k, u in USAGE.items() if not k.startswith("rem-")) + (
    "\nIn a batch line or --op string each op takes the same arguments and flags as on the command line.")

def gather_dir(root: Path) -> Path:
    d = root / GATHER
    d.mkdir(parents=True, exist_ok=True)
    return d

def delta_path(root: Path) -> Path:
    return root / GATHER / "delta.jsonl"

def clear_delta(root: Path) -> None:
    if delta_path(root).is_file():
        delta_path(root).unlink()

# Text flags keep every following word. --op stops only at an outer flag, so an inner --why stays inside the op.
_TEXT = ("--why", "--when", "--reason", "--text", "--halt")
_INNER = {"--cand", "--when", "--why", "--lines", "--reason"}
_OUTER = {"--op", "--text", "--halt", "--dry-run", "--json", "--verbose", "-v", "--selftest", "--root", "--help", "-h"}


def _absorb(argv: list[str], i: int, stop: set[str]) -> tuple[list[str], int]:
    """argv[i] is a flag. Join the following words until the next real flag."""
    flag = argv[i]
    i += 1
    parts: list[str] = []
    while i < len(argv) and argv[i] not in stop:
        parts.append(argv[i])
        i += 1
    return [flag, " ".join(parts)], i


def pack_cli(argv: list[str]) -> list[str]:
    """One token for --op (until the next outer flag) and for each text flag."""
    out: list[str] = []
    i = 0
    text = set(_TEXT)
    while i < len(argv):
        tok = argv[i]
        if tok == "--op":
            chunk, i = _absorb(argv, i, _OUTER)
            out.extend(chunk)
        elif tok in text:
            chunk, i = _absorb(argv, i, _OUTER | _INNER | text)
            out.extend(chunk)
        else:
            out.append(tok)
            i += 1
    return out


def pack_op(words: list[str]) -> list[str]:
    """After shlex splits an --op string, join --why / --when / --reason again."""
    out: list[str] = []
    i = 0
    text = {"--why", "--when", "--reason"}
    while i < len(words):
        tok = words[i]
        if tok in text:
            chunk, i = _absorb(words, i, text | _INNER)
            out.extend(chunk)
        else:
            out.append(tok)
            i += 1
    return out


def _funcs_instead(root: Path, idx: pi.Index, ref: str, rng: tuple[int, int], parsed) -> list[tuple[str, str, list[str]]]:
    """A line range on a .gd is the funcs that cover it. Logged as add-func so a later edit does not slide the range."""
    path = root / ref
    if not path.is_file():
        raise ValueError(f"{ref} is not on disk; name the function (add-func). A line range on a script slides when the file changes")
    import gd_lib
    a, b = rng
    names = [nm for nm, start, end, _n in gd_lib.funcs_of(path.read_text(encoding="utf-8")) if start <= b and end >= a]
    if not names:
        raise ValueError(f"no func in {ref} covers L{a}-{b}; name the function (add-func)")
    made: list[tuple[str, str, list[str]]] = []
    for nm in names:
        sub = ["add-func", ref, nm]
        if parsed.cand:
            sub.append("--cand")
        if parsed.when:
            sub += ["--when", parsed.when]
        if parsed.why:
            sub += ["--why", parsed.why]
        if parsed.reason:
            sub += ["--reason", parsed.reason]
        made.extend(apply(root, idx, sub))
    return made


def load(root: Path) -> tuple[str, pi.Index]:
    path = root / PLAN
    if not path.is_file():
        agent_log.fail("no session-plan.md here; `python tools/slice.py plan` writes the seed first")
    kept, gathered = pi.split_plan(md.read_text(path))
    if not gathered:
        agent_log.fail("session-plan.md has no `<!-- gathered -->` index; `python tools/slice.py plan --refresh` rebuilds it")
    return kept, pi.parse(gathered)

def apply(root: Path, idx: pi.Index, words: list[str]) -> list[tuple[str, str, list[str]]]:
    """Apply one op to idx. Returns [(item id, ref, logged argv)]. Raises ValueError with a usage message."""
    words = pack_op(words)
    ap = agent_log.std_parser("one adjust op", json_out=False)
    ap.add_argument("op", choices=[o for o in OPS if o not in ("batch", "report")], help="Operation.")
    ap.add_argument("args", nargs="*", help="Operation arguments.")
    ap.add_argument("--cand", action="store_true", help="Add as a candidate (needs --when).")
    ap.add_argument("--when", default="", help="Candidate condition: read if / read when.")
    ap.add_argument("--why", default="", help="Core note: why it is in context.")
    ap.add_argument("--lines", default="", help="add-file range A-B.")
    ap.add_argument("--reason", default="", help="Optional reason (logged).")
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err):
            a = ap.parse_args(words)
    except SystemExit as exc:
        why = next((ln for ln in reversed(err.getvalue().splitlines()) if ln.strip()), "")
        raise ValueError(f"bad op: {shlex.join(words)} ({why.split('error: ', 1)[-1] or 'usage'})") from exc
    op, args = a.op, a.args
    need = {"add-func": 2, "rem-func": 2}.get(op, 1)
    if len(args) < need:
        raise ValueError(f"{op} needs {need} argument(s): {USAGE.get(op, op)}")
    if op.startswith("add-"):
        kind = op[4:]
        ref = f"{args[0]}:{args[1]}" if kind == "func" else args[0]
        if a.cand and not a.when:
            raise ValueError("a candidate needs --when (read if / read when)")
        try:
            rng = tuple(int(x) for x in a.lines.split("-", 1)) if a.lines else None
        except ValueError as exc:
            raise ValueError(f"--lines takes A-B, got {a.lines!r}") from exc
        if rng and (len(rng) != 2 or kind not in ("file", "doc") or (kind == "doc" and "#" in ref)):
            raise ValueError("--lines A-B goes with add-file PATH or add-doc PATH (no #Heading)")
        if op == "add-file" and rng and ref.endswith(".gd"):
            return _funcs_instead(root, idx, ref, rng, a)
        old = next((it for it in idx.items if it.ref == ref and it.lines == rng), None)
        if old:
            old.core, old.note = not a.cand, (a.when if a.cand else a.why) or old.note
            return [(old.id, ref, words)]
        it = pi.Item(idx.next_id(not a.cand), kind, ref, not a.cand, a.when if a.cand else a.why, rng)
        idx.items.append(it)
        return [(it.id, ref, words)]
    token = f"{args[0]}:{args[1]}" if op == "rem-func" else args[0]
    it = idx.find(token)
    if it is None:
        raise ValueError(f"no index item {token!r} (ids: {', '.join(i.id for i in idx.items)})")
    if op.startswith("rem"):
        idx.items.remove(it)
    elif op == "promote":
        it.core, it.note = True, a.why or it.note
    elif op in ("demote", "set-condition"):  # the condition: positional TEXT or --when TEXT (not both)
        when = " ".join(args[1:]).strip()
        if when and a.when:
            raise ValueError(f"{op}: give the condition once, as TEXT or --when TEXT ({USAGE[op]})")
        when = when or a.when.strip()
        if not when:
            raise ValueError(f"{op} needs a condition: {USAGE[op]}")
        it.note = when
        if op == "demote":
            it.core = False
    return [(it.id, it.ref, words)]

def log(root: Path, words: list[str], iid: str, ref: str, reason: str) -> None:
    row = {"t": time.strftime("%Y-%m-%dT%H:%M:%S"), "by": os.environ.get("WDB_ROLE") or "build", "op": words[0],
           "id": iid, "ref": ref, "reason": reason or "(none)", "argv": words}
    with open(gather_dir(root) / "delta.jsonl", "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row) + "\n")

def _reason(words: list[str]) -> str:
    return words[words.index("--reason") + 1] if "--reason" in words and words.index("--reason") + 1 < len(words) else ""

def run_ops(root: Path, ops: list[list[str]], dry: bool) -> tuple[list[str], list[str]]:
    kept, idx = load(root)
    done, errs = [], []
    for words in ops:
        try:
            made = apply(root, idx, words)
        except ValueError as exc:
            errs.append(str(exc))
            continue
        for iid, ref, argv in made:
            done.append(f"{argv[0]} {iid} {ref}")
            if not dry:
                log(root, argv, iid, ref, _reason(argv))
    if not dry and done:
        if os.environ.get("WDB_ROLE") == "gather":
            idx.set("gather", "agent")  # the packet says the gather agent refined the seed
        md.write_text(root / PLAN, pi.join_plan(kept, idx))
    return done, errs

def replay(root: Path) -> int:
    """Re-apply logged ops to a freshly seeded index (slice.py plan --refresh). Ops whose target is gone are skipped."""
    path = delta_path(root)
    if not path.is_file():
        return 0
    kept, idx = load(root)
    n = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            row = json.loads(line)
            apply(root, idx, row["argv"])
            n += 1
            if row.get("by") == "gather":
                idx.set("gather", "agent")
        except (ValueError, KeyError, json.JSONDecodeError):
            continue
    md.write_text(root / PLAN, pi.join_plan(kept, idx))
    return n

def report(root: Path, text: str, halt: str) -> str:
    rows = [json.loads(ln) for ln in (delta_path(root).read_text(encoding="utf-8").splitlines() if delta_path(root).is_file() else []) if ln.strip()]
    counts: dict[str, int] = {}
    for r in rows:
        counts[r["op"]] = counts.get(r["op"], 0) + 1
    _, idx = load(root)
    core = [i.id for i in idx.items if i.core]
    cand = [i.id for i in idx.items if not i.core]
    body = [f"# Gather report", "", f"delta: {', '.join(f'{k}={v}' for k, v in sorted(counts.items())) or 'no changes to the seed'}",
            f"index: core={len(core)} ({' '.join(core)}) candidates={len(cand)} ({' '.join(cand)})", "", text.strip() or "(no judgment written)"]
    if halt:
        body += ["", f"HALT: {halt}"]
        (gather_dir(root) / "halt").write_text(halt.strip() + "\n", encoding="utf-8")
    (gather_dir(root) / "report.md").write_text("\n".join(body) + "\n", encoding="utf-8")
    return "\n".join(body)

def main(argv: list[str] | None = None) -> int:
    argv = pack_cli(list(sys.argv[1:] if argv is None else argv))
    if "--selftest" in argv:
        return selftest()
    ap = agent_log.std_parser("Adjust the session-plan context index; every change is logged in _logs/gather/delta.jsonl.",
                              writes=True, verbose=True)
    ap.epilog = EPILOG
    ap.add_argument("op", choices=OPS, help="add-func|add-file|add-doc|add-names|rem|rem-func|rem-file|rem-doc|promote|demote|set-condition|batch|report")
    ap.add_argument("args", nargs="*", help="Op arguments (the ops list below).")
    ap.add_argument("--cand", action="store_true", help="Add as a candidate (needs --when).")
    ap.add_argument("--when", default="", help="Condition (read if / read when): a candidate's, or demote / set-condition's.")
    ap.add_argument("--why", default="", help="Why a core item is in context.")
    ap.add_argument("--lines", default="", help="add-file / add-doc line range A-B.")
    ap.add_argument("--reason", default="", help="Optional reason, logged with the op.")
    ap.add_argument("--text", default="", help="report: the door/job judgment and notes for the main session.")
    ap.add_argument("--halt", default="", help="report: halt reason; slice.py open then refuses to launch.")
    ap.add_argument("--op", dest="inline", action="append", default=[], help="batch: one op as a quoted string (repeat); no stdin or file needed.")
    ap.add_argument("--selftest", action="store_true", help="Run the cases in a temp repo.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.op == "report":
        body = report(root, args.text, args.halt)
        return agent_log.finish("plan-adjust", root, body, "FAIL" if args.halt else "PASS", args=args, op="report", halted=bool(args.halt))
    if args.op == "batch":
        src = sys.stdin.read() if args.args[:1] == ["-"] else (root / args.args[0]).read_text(encoding="utf-8") if args.args else ""
        ops = [shlex.split(ln) for ln in [*src.splitlines(), *args.inline] if ln.strip() and not ln.lstrip().startswith("#")]
    else:
        words = [args.op, *args.args, *(["--cand"] if args.cand else [])]
        for flag in ("when", "why", "lines", "reason"):
            if getattr(args, flag):
                words += [f"--{flag}", getattr(args, flag)]
        ops = [words]
    done, errs = run_ops(root, ops, args.dry_run)
    shown = done if args.verbose or len(done) <= 20 else done[:12] + [f"... {len(done) - 12} more applied (--verbose prints them)"]
    lines = shown + [f"error: {e}" for e in errs]  # errors are never folded
    return agent_log.finish("plan-adjust", root, "\n".join(lines), "FAIL" if errs else "PASS", args=args,
                            write=not args.dry_run, json_extra={"done": done, "error_text": errs},
                            applied=len(done), errors=len(errs), dry_run=True if args.dry_run else None)

def selftest() -> int:
    import subprocess
    import tempfile

    bad: list[str] = []
    seed = pi.Index(identity=[("door", "demo"), ("job", "demo.part")],
                    items=[pi.Item("C1", "doc", "design/demo-part.md", True, "job doc"),
                           pi.Item("K2", "names", "scripts/demo.gd", False, "the change reaches Demo code")], card="card line")
    text = pi.render(seed)
    if pi.render(pi.parse(text)) != text:
        bad.append("schema round-trip: render(parse(render(x))) must equal render(x)")
    import repo_lib

    with tempfile.TemporaryDirectory() as td:
        root = repo_lib.selftest_repo(td, empty_commit=True)
        (root / PLAN).write_text("# Session plan\n\n## Outcome\n\nkeep me\n\n" + pi.MARKER + "\n\n" + text, encoding="utf-8")
        env = dict(os.environ, WDB_ROLE="gather")

        def run(*a: str, stdin: str = "") -> tuple[int, str]:
            p = subprocess.run([*boot.cmd("plan_adjust"), "--root", str(root), *a], capture_output=True, text=True, input=stdin, env=env)
            return p.returncode, p.stdout + p.stderr

        code, out = run("add-func", "scripts/demo.gd", "alpha", "--why", "edited here")
        code2, _ = run("add-doc", "design/demo.md#Rules", "--cand", "--when", "a rule changes")
        code3, out3 = run("add-file", "scripts/x.gd", "--cand")
        if code or code2 or code3 == 0:
            bad.append(f"add ops: {out} / candidate without --when must fail ({out3[:80]})")
        _, out = run("batch", "-", stdin="promote K2 --why needed\nset-condition K4 the rules section changes\n# comment\nrem C1\n")
        plan = (root / PLAN).read_text(encoding="utf-8")
        idx = pi.parse(pi.split_plan(plan)[1])
        k2, k4 = idx.find("K2"), idx.find("K4")
        if not (k2 and k2.core) or not (k4 and k4.note == "the rules section changes") or idx.find("C1"):
            bad.append("batch: promote, set-condition and rem must apply: " + out)
        if "keep me" not in plan:
            bad.append("adjust must keep the four sections above the marker")
        rows = [json.loads(ln) for ln in delta_path(root).read_text(encoding="utf-8").splitlines()]
        if len(rows) != 5 or any(r["by"] != "gather" or not r["reason"] for r in rows):
            bad.append(f"every applied op logs one delta row with by and a default reason ({len(rows)})")
        (root / PLAN).write_text("# Session plan\n\n## Outcome\n\nkeep me\n\n" + pi.MARKER + "\n\n" + text, encoding="utf-8")
        n = replay(root)
        again = pi.parse(pi.split_plan((root / PLAN).read_text(encoding="utf-8"))[1])
        if n != 5 or again.find("C1") or not again.find("scripts/demo.gd:alpha"):
            bad.append(f"replay after a re-seed must re-apply the logged ops ({n})")
        if again.get("gather") != "agent":
            bad.append("ops by the gather role set `gather: agent` in the identity (also on replay)")
        code, out = run("batch", "--op", "add-file data/en.po --lines 3-4 --cand --when 'copy changes'",
                        "--op", "add-file data/en.po --lines 9-9 --cand --when 'opt-in copy'", "--op", "add-doc design/demo.md --lines 2-5")
        ranged = pi.parse(pi.split_plan((root / PLAN).read_text(encoding="utf-8"))[1])
        po = [it for it in ranged.items if it.ref == "data/en.po"]
        doc = next((it for it in ranged.items if it.ref == "design/demo.md" and it.lines), None)
        if code or [it.lines for it in po] != [(3, 4), (9, 9)] or not (doc and doc.core and doc.lines == (2, 5)):
            bad.append("batch --op: one file holds several --lines ranges; add-doc PATH --lines A-B: " + out)
        if run("add-doc", "design/demo.md#Rules", "--lines", "1-2")[0] == 0 or run("add-file", "x.gd", "--lines", "a-b")[0] == 0:
            bad.append("--lines refuses a #Heading doc and a malformed range")
        code, out = run("set-condition", "K4", "--when", "flag form")
        code2, out2 = run("batch", "--op", "demote K2 positional text", "--op", "set-condition K4 --when 'op flag form'")
        flagged = pi.parse(pi.split_plan((root / PLAN).read_text(encoding="utf-8"))[1])
        if code or code2 or flagged.find("K4").note != "op flag form" or flagged.find("K2").core or flagged.find("K2").note != "positional text":
            bad.append("set-condition and demote take TEXT positionally or --when TEXT, top level and in batch: " + out + out2)
        if run("set-condition", "K4", "a", "--when", "b")[0] == 0 or "set-condition ID --when TEXT" not in run("--help")[1]:
            bad.append("set-condition refuses TEXT plus --when, and --help lists every op's arguments")
        many = [f"promote K4 --why n{i}" for i in range(24)] + ["set-condition K4", "rem nosuch"]
        code, out = run("batch", "--dry-run", *sum((["--op", o] for o in many), []))
        if code == 0 or "more applied (--verbose prints them)" not in out or "set-condition needs a condition" not in out \
                or "no index item 'nosuch'" not in out:
            bad.append("a long --dry-run batch folds applied ops but prints every error: " + out[-300:])
        code, out = run("batch", "--dry-run", "--verbose", *sum((["--op", o] for o in many), []))
        if out.count("promote K4") != 24:
            bad.append("--verbose prints every applied op")
        code, out = run("batch", "--dry-run", "--json", "--op", "rem nosuch", "--op", "promote K4")
        try:
            js = json.loads(out.strip().splitlines()[-1])
        except (ValueError, IndexError):
            js = {}
        if js.get("errors") != 1 or "nosuch" not in " ".join(js.get("error_text", [])) or js.get("done") != ["promote K4 design/demo.md#Rules"]:
            bad.append("--json carries error_text and done: " + out[-200:])
        if "nosuch" in (root / GATHER / "delta.jsonl").read_text(encoding="utf-8"):
            bad.append("--dry-run writes no delta rows")
        code, out = run("report", "--text", "door ok", "--halt", "task is ambiguous")
        rep = (root / GATHER / "report.md").read_text(encoding="utf-8")
        if code == 0 or not (root / GATHER / "halt").is_file() or "door ok" not in rep or "add-func=1" not in rep:
            bad.append("report --halt writes report.md (delta summary + text) and the halt file, exit 1")
        code, out = run("add-func", "scripts/demo.gd", "gamma", "--why", "the", "widget", "lives", "here", "--reason", "kept")
        noted = pi.parse(pi.split_plan((root / PLAN).read_text(encoding="utf-8"))[1])
        gamma = noted.find("scripts/demo.gd:gamma")
        if code or not gamma or gamma.note != "the widget lives here":
            bad.append("unquoted --why keeps every word until the next flag: " + out)
        last = json.loads(delta_path(root).read_text(encoding="utf-8").splitlines()[-1])
        if last.get("reason") != "kept":
            bad.append("unquoted --reason stays one logged reason")
        code, out = run("batch", "--op", "add-func", "scripts/demo.gd", "delta", "--why", "spans", "the", "note",
                        "--op", "add-doc", "design/demo.md#Extra")
        noted = pi.parse(pi.split_plan((root / PLAN).read_text(encoding="utf-8"))[1])
        delta = noted.find("scripts/demo.gd:delta")
        if code or not delta or delta.note != "spans the note" or not noted.find("design/demo.md#Extra"):
            bad.append("unquoted --op keeps --why words until the next --op: " + out)
        hud = root / "scripts" / "hud_view.gd"
        hud.parent.mkdir(parents=True, exist_ok=True)
        hud.write_text("extends Node\n\nfunc layout() -> void:\n\tpass\n\nfunc build() -> void:\n\tpass\n", encoding="utf-8")
        code, out = run("add-file", "scripts/hud_view.gd", "--lines", "3-4", "--why", "the", "widget")
        noted = pi.parse(pi.split_plan((root / PLAN).read_text(encoding="utf-8"))[1])
        lay = noted.find("scripts/hud_view.gd:layout")
        filed = [it for it in noted.items if it.ref == "scripts/hud_view.gd" and it.kind == "file"]
        logged = json.loads(delta_path(root).read_text(encoding="utf-8").splitlines()[-1])["argv"]
        if code or not lay or lay.note != "the widget" or filed or noted.find("scripts/hud_view.gd:build") or logged[:3] != ["add-func", "scripts/hud_view.gd", "layout"]:
            bad.append("add-file --lines on a .gd stores the covering func: " + out)
        if run("add-file", "scripts/missing_widget.gd", "--lines", "1-2")[0] == 0:
            bad.append("add-file --lines on a missing .gd must fail")
    return agent_log.selftest_result(bad)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
