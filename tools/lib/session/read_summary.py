#!/usr/bin/env python3
"""Print a job's runs, or a short slice of a log.

    python tools/session.py summary --job build-gate          # index + newest summary
    python tools/session.py summary --job build-gate --index  # the index only
    python tools/session.py summary --job build-gate --run 2  # the 2nd newest run (1 = newest)
    python tools/session.py summary --path _logs/smokes/<stamp>-p1-err.log
    python tools/session.py summary --job perf-sweep --section '--- places ---'
    python tools/session.py summary --job perf-sweep --match fps_pct --max 20
    python tools/session.py summary --list 'perf-sweep-web-*/*.jsonl'
    python tools/session.py summary --path _logs/web-perf/hitch.jsonl --jsonl --where ev=eq:hitch --where seg=eq:hub1 --group phase --stat submit_ms --stat draw

No filter prints the whole job summary (the printer). A filter prints a capped
slice or an aggregate and never the whole file. A .jsonl path with no filter
is refused. --jsonl walks the file once and keeps numbers for --stat only.
PowerShell: single-quote globs, regexes, and --- headings. Compares are
key=ge:N, le:N, gt:N, lt:N, ne:TEXT, has:TEXT, eq:TEXT. An unquoted > or <
redirects and never arrives as an argument.
Every run keeps its own timestamped file under _logs/<job>/ and index.txt lists the last 20 (run_log_lib.py).
No --job/--path/--list lists the job dirs found under _logs/. Exit 0 ok, 1 missing, 2 usage.
"""
from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import run_log_lib

_QUERY_JOB = "summary-query"
_OPS = (">=", "<=", "!=", "~=", ">", "<", "=")
_WORD_OPS = {"eq": "=", "ne": "!=", "ge": ">=", "le": "<=", "gt": ">", "lt": "<", "has": "~="}
_PS_HINT = (
    "PowerShell: single-quote globs, regexes, and --- headings. "
    "Unquoted > or < redirects. Compares: --where key=ge:N le:N gt:N lt:N ne:TEXT has:TEXT eq:TEXT"
)
_MAX_SERIES = 50000
_BODY_CAP = 200
_LINE_CAP = 1000000


def _filtered(args) -> bool:
    return bool(
        args.match or args.section or args.head or args.tail
        or args.jsonl or args.where or args.group or args.stat or args.pick or args.list
    )


def _under_root(root: Path, full: Path) -> bool:
    try:
        full.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _resolve_file(root: Path, raw: str) -> Path:
    full = Path(raw)
    return full if full.is_absolute() else root / full


def _list_logs(root: Path, pattern: str) -> list[str]:
    logs = root / "_logs"
    if not logs.is_dir():
        return ["files=0 (no _logs)"]
    try:
        found = [p for p in logs.glob(pattern) if p.is_file() and _under_root(root, p)]
    except (ValueError, OSError) as exc:
        raise ValueError("bad --list %s. %s" % (exc, _PS_HINT)) from exc
    found.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    lines = ["files=%d pattern=%s" % (len(found), pattern)]
    for path in found:
        stamp = datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
        lines.append("bytes=%d mtime=%s path=%s" % (path.stat().st_size, stamp, agent_log.rel(root, path)))
    if not found and not any(ch in pattern for ch in "*?["):
        lines.append("hint=pattern has no wildcard. PowerShell expands * before Python. Single-quote the glob. " + _PS_HINT)
    return lines


def _section_end(lines: list[str], start: int) -> int:
    head = lines[start].lstrip()
    if head.startswith("---"):
        for i in range(start + 1, len(lines)):
            if lines[i].lstrip().startswith("---"):
                return i
        return len(lines)
    seen = False
    for i in range(start + 1, len(lines)):
        if lines[i].strip():
            seen = True
            continue
        if seen:
            return i
    return len(lines)


class _Missing(Exception):
    pass


def _clean_token(raw: str) -> str:
    text = raw.strip().replace("\u201c", "").replace("\u201d", "").replace("\u2018", "").replace("\u2019", "")
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        text = text[1:-1].strip()
    return text


def _parse_where(spec: str) -> tuple[str, str, str]:
    text = _clean_token(spec)
    if not text:
        raise ValueError("empty --where. " + _PS_HINT)
    if "=" in text and not any(op in text for op in (">=", "<=", "!=", "~=", ">", "<")):
        key, raw = text.split("=", 1)
        key = key.strip()
        raw = raw.strip()
        if not key:
            raise ValueError("bad --where %s. %s" % (spec, _PS_HINT))
        if ":" in raw:
            word, rest = raw.split(":", 1)
            mapped = _WORD_OPS.get(word)
            if mapped is not None:
                if rest == "" and mapped not in ("=", "!="):
                    raise ValueError("empty compare in --where %s. %s" % (spec, _PS_HINT))
                return key, mapped, rest
        return key, "=", raw
    matched = None
    for op in _OPS:
        if op in text:
            key, raw = text.split(op, 1)
            matched = (key.strip(), op, raw.strip())
            break
    if matched is None or not matched[0]:
        raise ValueError("bad --where %s (use key=value or key=ge:N). %s" % (spec, _PS_HINT))
    key, op, raw = matched
    if op != "=" and raw == "":
        raise ValueError("empty compare in --where %s. %s" % (spec, _PS_HINT))
    return key, op, raw


def _text_slice(text: str, args) -> list[str]:
    lines = text.splitlines()
    start = 0
    end = len(lines)
    if args.section:
        needle = _clean_token(args.section).lower()
        if not needle or set(needle) <= set("- \t"):
            raise ValueError(
                "section is empty or only dashes; the heading quotes were dropped. "
                "Single-quote it: --section '--- places ---'. " + _PS_HINT
            )
        start = -1
        for i, line in enumerate(lines):
            if needle in line.lower():
                start = i
                break
        if start < 0:
            raise _Missing("section %s missing lines=%d" % (args.section, len(lines)))
        end = _section_end(lines, start)
    chosen = lines[start:end]
    if args.head:
        chosen = chosen[: args.head]
    if args.tail:
        chosen = chosen[-args.tail :]
    if args.match:
        try:
            rx = re.compile(_clean_token(args.match), re.IGNORECASE)
        except re.error as exc:
            raise ValueError("bad --match %s. %s" % (exc, _PS_HINT)) from exc
        ctx = max(0, min(int(args.context), 5))
        hits: list[str] = []
        for i, line in enumerate(chosen):
            if rx.search(line) is None:
                continue
            lo = max(0, i - ctx)
            hi = min(len(chosen), i + ctx + 1)
            if hits and ctx:
                hits.append("--")
            for j in range(lo, hi):
                hits.append(chosen[j])
            if len(hits) >= _BODY_CAP:
                break
        if not hits:
            return ["match=%s hits=0 lines=%d" % (args.match, len(chosen))]
        return hits
    return chosen


def _num(value: object) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def _where_ok(row: dict, spec: tuple[str, str, str]) -> bool:
    key, op, raw = spec
    if key not in row:
        return op == "!="
    val = row[key]
    if op == "~=":
        return raw.lower() in str(val).lower()
    left = _num(val)
    right = _num(raw)
    if op in (">=", "<=", ">", "<"):
        if left is None or right is None:
            return False
        if op == ">=":
            return left >= right
        if op == "<=":
            return left <= right
        if op == ">":
            return left > right
        return left < right
    if left is not None and right is not None:
        eq = left == right
    else:
        eq = str(val) == raw
    return eq if op == "=" else not eq


def _pct(vals: list[float], q: float) -> float:
    ordered = sorted(vals)
    if q == 0.5:
        return ordered[len(ordered) // 2]
    idx = int(round(q * (len(ordered) - 1)))
    return ordered[idx]


def _stat_text(key: str, vals: list[float], truncated: bool) -> str:
    if not vals:
        return "%s n=0" % key
    flag = " truncated=1" if truncated else ""
    return "%s n=%d med=%.1f p95=%.1f min=%.1f max=%.1f%s" % (
        key, len(vals), _pct(vals, 0.5), _pct(vals, 0.95), min(vals), max(vals), flag,
    )


def _jsonl_report(path: Path, args, specs: list[tuple[str, str, str]]) -> list[str]:
    group_keys = [part.strip() for part in args.group.split(",") if part.strip()] if args.group else []
    pick_keys = [part.strip() for part in args.pick.split(",") if part.strip()] if args.pick else []
    pick_cap = args.max if args.max > 0 else 40
    stats: dict[str, dict[str, list[float]]] = {}
    truncated: dict[str, dict[str, bool]] = {}
    counts: dict[str, int] = {}
    first_keys: list[str] = []
    picked: list[str] = []
    lines_n = 0
    ok_n = 0
    bad_n = 0
    kept = 0
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            lines_n += 1
            if len(line) > _LINE_CAP:
                bad_n += 1
                continue
            raw = line.strip().lstrip("\ufeff")
            if not raw:
                continue
            try:
                row = json.loads(raw)
            except json.JSONDecodeError:
                bad_n += 1
                continue
            if not isinstance(row, dict):
                bad_n += 1
                continue
            ok_n += 1
            if not all(_where_ok(row, spec) for spec in specs):
                continue
            kept += 1
            if not first_keys:
                first_keys = list(row.keys())[:40]
            if pick_keys and len(picked) < pick_cap:
                picked.append(" ".join("%s=%s" % (key, row.get(key, "-")) for key in pick_keys))
            label = "all" if not group_keys else " ".join(
                "%s=%s" % (key, row.get(key, "-")) for key in group_keys
            )
            counts[label] = counts.get(label, 0) + 1
            bucket = stats.setdefault(label, {})
            flags = truncated.setdefault(label, {})
            for key in args.stat:
                num = _num(row.get(key))
                if num is None:
                    continue
                series = bucket.setdefault(key, [])
                if len(series) >= _MAX_SERIES:
                    flags[key] = True
                    continue
                series.append(num)
    header = "bytes=%d lines=%d json_ok=%d bad=%d kept=%d" % (
        path.stat().st_size, lines_n, ok_n, bad_n, kept,
    )
    out = [header]
    if not args.stat:
        shown = ",".join(first_keys) if first_keys else "(none)"
        out.append("keys=%s" % shown)
        out.append("groups=%d (pass --stat KEY to aggregate; rows are not printed)" % len(counts))
    labels = sorted(counts, key=lambda name: (-counts[name], name))
    for label in labels:
        bits = ["group %s n=%d" % (label, counts[label])]
        for key in args.stat:
            bits.append(_stat_text(key, stats.get(label, {}).get(key, []), truncated.get(label, {}).get(key, False)))
        out.append(" ".join(bits))
    if not labels:
        out.append("groups=0")
    if ok_n == 0 and bad_n > 0:
        raise ValueError(
            "no JSON objects in %s (lines=%d bad=%d). Drop --jsonl for a text log. %s"
            % (path.name, lines_n, bad_n, _PS_HINT)
        )
    if kept and args.stat:
        for key in args.stat:
            total = sum(len(bucket.get(key, [])) for bucket in stats.values())
            if total == 0:
                out.append("hint=%s had no numbers on %d kept rows" % (key, kept))
    if pick_keys:
        out.append("pick=%s shown=%d" % (",".join(pick_keys), len(picked)))
        out.extend(picked)
        if kept > len(picked):
            out.append("... %d more kept rows (--max %d)" % (kept - len(picked), pick_cap))
    return out


def _finish_query(root: Path, args, lines: list[str], status: str = "INFO") -> int:
    body_lines = lines[:_BODY_CAP]
    if len(lines) > _BODY_CAP:
        body_lines.append("... %d more lines not stored" % (len(lines) - _BODY_CAP))
    echo_lines = agent_log.fold(body_lines, verbose=bool(getattr(args, "verbose", False)), keep=12, limit=30)
    return agent_log.finish(
        _QUERY_JOB,
        root,
        "\n".join(body_lines),
        status,
        args=args,
        legacy=False,
        echo="\n".join(echo_lines),
    )


def _install_error(ap: object) -> None:
    def error(self, message: str) -> None:
        extra = ""
        if "--section" in message and "expected one argument" in message:
            extra = " A heading that starts with --- has to be --section='--- places ---'.\n"
        sys.stderr.write("error: %s\n%s%s\n" % (message, extra, _PS_HINT))
        sys.stderr.flush()
        raise SystemExit(2)

    ap.error = error.__get__(ap, type(ap))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Print a job's run index and newest summary, or a short slice of a log.")
    ap.add_argument("job_pos", nargs="?", default="", help="Job name (same as --job).")
    ap.add_argument("--job", default="", help="Job name, e.g. smokes.")
    ap.add_argument("--path", default="", help="Repo-relative or absolute file under this checkout.")
    ap.add_argument("--index", action="store_true", help="Print only the run index of the job.")
    ap.add_argument("--run", type=int, default=1, help="Which run's summary to print: 1 = newest (default), 2 = the one before.")
    ap.add_argument("--list", default="", help="Glob under _logs, single-quoted in PowerShell. No file bodies.")
    ap.add_argument("--match", default="", help="Case-insensitive regex. Single-quote it in PowerShell.")
    ap.add_argument("--context", type=int, default=0, help="Lines before and after a --match hit (max 5).")
    ap.add_argument("--section", default="", help="One block. Single-quote a --- heading in PowerShell.")
    ap.add_argument("--head", type=int, default=0, help="Keep the first N lines of the selected text.")
    ap.add_argument("--tail", type=int, default=0, help="Keep the last N lines of the selected text.")
    ap.add_argument("--max", type=int, default=40, help="Cap printed text-slice lines (default 40).")
    ap.add_argument("--jsonl", action="store_true", help="Parse JSON lines and aggregate. A .jsonl path with no filter is refused.")
    ap.add_argument("--where", action="append", default=[], help="Keep rows: key=value or key=ge:N le:N gt:N lt:N ne:TEXT has:TEXT eq:TEXT. Quote symbol ops (>=, >, <) in PowerShell.")
    ap.add_argument("--group", default="", help="Comma-separated JSON keys. One output line per distinct tuple.")
    ap.add_argument("--stat", action="append", default=[], help="Numeric JSON field to summarize (med, p95, min, max). Repeatable.")
    ap.add_argument("--pick", default="", help="Comma-separated JSON keys to print for each kept row. Capped by --max.")
    _install_error(ap)
    args = ap.parse_args(argv)
    if args.head < 0 or args.tail < 0 or args.context < 0 or args.max < 0:
        print("error: --head, --tail, --context, and --max must be >= 0. " + _PS_HINT, file=sys.stderr, flush=True)
        return 2
    root, where = agent_log.cwd_scan_root(args)
    if args.list:
        try:
            listed = _list_logs(root, args.list)
        except ValueError as exc:
            print("error: %s" % exc, file=sys.stderr, flush=True)
            return 2
        cap = args.max if args.max > 0 else 40
        head = listed[:1]
        rows = listed[1:]
        if len(rows) > cap:
            hidden = len(rows) - cap
            rows = rows[:cap] + ["... %d more files (--max %d)" % (hidden, cap)]
        return _finish_query(root, args, [where, *head, *rows])
    if (args.where or args.group or args.stat or args.pick) and not args.jsonl:
        print("error: --where, --group, --stat, and --pick need --jsonl", file=sys.stderr, flush=True)
        return 2
    job = args.job or args.job_pos
    logs = root / "_logs"
    names = sorted(d.name for d in logs.iterdir() if d.is_dir() and run_log_lib.latest(d)) if logs.is_dir() else []
    if not _filtered(args):
        print(where)
    if not job and not args.path and not _filtered(args):
        print("usage: python tools/session.py summary --job <name>")
        print("jobs: " + (", ".join(names) or "(none yet)"))
        return 2
    if not job and not args.path:
        print("error: --job or --path is required", file=sys.stderr, flush=True)
        return 2
    full: Path | None = None
    index_lines: list[str] = []
    if args.path:
        full = _resolve_file(root, args.path)
    else:
        d = agent_log.agent_log_dir(job, root)
        rows = run_log_lib.entries(d)
        if rows:
            index_lines.append("index _logs/%s/index.txt (newest first)" % job)
            for i, (stamp, status, _file, note) in enumerate(rows, 1):
                index_lines.append(("  %2d %s %s %s" % (i, stamp, status, note)).rstrip())
            if args.index and not _filtered(args):
                print("\n".join(index_lines))
                return 0
            if args.index and _filtered(args):
                return _finish_query(root, args, [where, *index_lines])
            if not 1 <= args.run <= len(rows):
                print("error: --run %s is outside 1-%s" % (args.run, len(rows)), file=sys.stderr, flush=True)
                return 2
            full = d / rows[args.run - 1][2]
            index_lines.append("--- run %s: %s ---" % (args.run, agent_log.rel(root, full)))
        else:
            full = run_log_lib.latest(d) or d / run_log_lib.LEGACY
    if full is not None and full.is_dir():
        print("error: %s is a directory. Pass a file, or --job NAME." % agent_log.rel(root, full), file=sys.stderr, flush=True)
        return 2
    if full is None or not full.is_file():
        shown = agent_log.rel(root, full) if full is not None else args.path
        print("error: missing %s; jobs with a summary: %s" % (shown, ", ".join(names) or "(none yet)"), file=sys.stderr, flush=True)
        return 1
    if not _under_root(root, full):
        print("error: path is outside this checkout", file=sys.stderr, flush=True)
        return 2
    shown = agent_log.rel(root, full)
    capped = bool(args.head or args.tail or args.match or args.section)
    if full.suffix.lower() == ".jsonl" and not args.jsonl and not capped:
        print("error: refusing to print %s whole. Pass --jsonl, or --head N. %s" % (shown, _PS_HINT), file=sys.stderr, flush=True)
        return 2
    try:
        if args.jsonl:
            specs = [_parse_where(item) for item in args.where]
            report = [where, "file=%s" % shown, *_jsonl_report(full, args, specs)]
            return _finish_query(root, args, report)
        if _filtered(args):
            text = full.read_text(encoding="utf-8", errors="replace")
            sliced = _text_slice(text, args)
            cap = args.max if args.max > 0 else 40
            if len(sliced) > cap:
                hidden = len(sliced) - cap
                sliced = sliced[:cap] + ["... %d more matching lines (--max %d)" % (hidden, cap)]
            report = [where, "file=%s bytes=%d" % (shown, full.stat().st_size)]
            if index_lines:
                report.extend(index_lines[:1])
            report.extend(sliced)
            return _finish_query(root, args, report)
        if index_lines:
            print("\n".join(index_lines))
        sys.stdout.write(full.read_text(encoding="utf-8", errors="replace"))
    except _Missing as exc:
        print("error: %s" % exc, file=sys.stderr, flush=True)
        return 1
    except ValueError as exc:
        print("error: %s" % exc, file=sys.stderr, flush=True)
        return 2
    except OSError as exc:
        print("error: cannot read %s (%s)" % (shown, getattr(exc, "strerror", None) or exc), file=sys.stderr, flush=True)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
