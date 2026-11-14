"""Chunk view for `lint.py unused`: --paths scoping, reach explanations, --baseline diffs, plan markdown.

Reach: one Dijkstra from the sweep roots over strong (cost 0) and weak edges (cost 1 from an in-chunk caller,
OUT from an out-of-chunk caller), so each func gets the path that needs the fewest out-of-chunk fixes. Tags:
  strong     reached through resolved edges only (debug_only rows: the path names the debug caller)
  type_here  every weak hop on the best path is in the chunk: add types/preloads at the named sites
  cascade    no path avoids a weak hop from an OUT-of-chunk caller (named): leave it for that caller's chunk
  unreached  no path from any root (unused / shadowed / dead_chain)
Nothing here edits the repo; --plan-out writes only the given plan file (outside the repo by convention)."""
from __future__ import annotations

import heapq
import json
import re
import subprocess
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

import agent_log

OUT = 1000
KEEP = {  # why a leftover row stays, per kind, when no refusal or reach reason is more specific
    "write_only_var": "write kept (assignment/initializer may have side effects)",
    "init_only_var": "initializer kept (side effects)",
    "debug_only": "shipped code reached from debug/tools; never deleted in cleanup",
    "decl": "legacy report only", "maybe": "legacy report only", "dynamic": "dynamic name: report only",
    "facade_auto": "report only",
}

def glob_re(globs: list[str]) -> re.Pattern:
    parts = []
    for g in globs:
        g = g.strip().strip("/")
        if not any(c in g for c in "*?[") and not g.endswith((".gd", ".tscn", ".md", ".json")):
            g += "/**"  # a bare directory means everything under it
        rx = re.escape(g).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*").replace(r"\?", "[^/]")
        last = g.rsplit("/", 1)[-1]
        if last != "**" and "*" in last and "." not in last:
            rx += "(?:/.*)?"  # `scripts/title*` also covers a `title_x/` folder
        parts.append(rx)
    return re.compile("^(?:" + "|".join(parts or ["$^"]) + ")$")

def in_chunk(rx: re.Pattern, rel: str) -> bool:
    return bool(rx.match(rel.replace("\\", "/")))

def reach_paths(g, chunk: set[str]):
    import unused_graph as ug
    over = defaultdict(list)
    for up, name, child in g._overrides():
        over[(up, name)].append(child)
    files = g.file_reach
    dist, par, heap = {}, {}, []
    for node, why in g.roots(files):
        if node not in dist:
            dist[node], par[node] = 0, (None, why, 0)
            heap.append((0, node))
    heapq.heapify(heap)
    while heap:
        d, node = heapq.heappop(heap)
        if d > dist.get(node, d):
            continue
        outs = list(g.edges.get(node, ())) + [(c, node[1], "override", 0) for c in over.get(node, ())]
        for t, n, k, ln in outs:
            if t not in files or (k not in ug.STRONG and k not in ug.WEAK):
                continue
            nd = d + (0 if k in ug.STRONG else (1 if node[0] in chunk else OUT))
            key = (t, n)
            if nd < dist.get(key, nd + 1):
                dist[key], par[key] = nd, (node, k, ln)
                heapq.heappush(heap, (nd, key))
    return dist, par

def hops(par, key) -> list[tuple]:
    """[(src_node, kind, line, dst_node)] from a root to key; a root hop has src None and kind = root reason."""
    out, seen = [], set()
    while key in par and key not in seen:
        seen.add(key)
        src, k, ln = par[key]
        out.append((src, k, ln, key))
        if src is None:
            break
        key = src
    return out[::-1]

def explain(g, dist, par, key, chunk: set[str]) -> dict:
    import unused_graph as ug
    if key not in dist:
        return dict(tag="unreached", sites=[], path=[])
    path = hops(par, key)
    weak = [(s[0], ln, k) for s, k, ln, _d in path if s is not None and k in ug.WEAK]
    out_w = [f"{r}:{ln}({k})" for r, ln, k in weak if r not in chunk]
    in_w = [f"{r}:{ln}({k})" for r, ln, k in weak if r in chunk]
    tag = "cascade" if out_w else ("type_here" if in_w else "strong")
    txt = []
    for s, k, ln, d in path:
        txt.append(f"root({k}) {d[0]}:{d[1]}" if s is None else f"-{k}@{s[0]}:{ln}-> {d[0]}:{d[1]}")
    return dict(tag=tag, sites=out_w or in_w, path=txt)

def collect(blob: dict, rx: re.Pattern) -> dict[str, list[dict]]:
    rows: dict[str, list[dict]] = defaultdict(list)
    for kind, items in blob["rows"].items():
        rows[kind] += [dict(r) for r in items if in_chunk(rx, r["rel"])]
    for kind, items in blob["legacy"].items():
        rows[kind] += [dict(r) for r in items if in_chunk(rx, r["rel"])]
    rows["apply_ready"] = [dict(r) for r in blob["apply_ready"] if in_chunk(rx, r["rel"])]
    rows["apply_refused"] = [dict(r) for r in blob["apply_refused"] if in_chunk(rx, r["rel"])]
    return {k: v for k, v in rows.items() if v}

def git_tip(root: Path) -> tuple[str, bool]:
    def run(*a):
        try:
            return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True, timeout=30).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            return ""
    return run("rev-parse", "--short=8", "HEAD"), bool(run("status", "--porcelain", "--", "scripts", "tools", "design"))

def build(root: Path, g, blob: dict, globs: list[str]) -> dict:
    rx = glob_re(globs)
    chunk = {r for r in g.scripts if in_chunk(rx, r)}
    rows = collect(blob, rx)
    dist, par = reach_paths(g, chunk)
    refuse = {(r["rel"], r["name"]): r["refuse"] for r in blob["apply_refused"]}
    funcs = {(rel, n) for rel, s in g.scripts.items() for n in s.funcs}
    callers: Counter = Counter()
    sites: Counter = Counter()
    tags: Counter = Counter()
    for kind, items in rows.items():
        if kind in ("apply_ready", "apply_refused"):
            continue
        for r in items:
            key = (r["rel"], r["name"])
            if key in funcs and kind in ("ambiguous", "debug_only"):
                r["reach"] = explain(g, dist, par, key, chunk)
                tags[r["reach"]["tag"]] += 1
                if r["reach"]["tag"] == "cascade":
                    callers.update({s.split(":")[0] for s in r["reach"]["sites"]})
                elif r["reach"]["tag"] == "type_here":
                    sites.update(set(r["reach"]["sites"]))
            r["keep"] = refuse.get(key) or (r.get("reach") and _reach_reason(r["reach"])) or KEEP.get(kind, r.get("why", ""))
    tip, dirty = git_tip(root)
    return dict(globs=globs, files=sorted(chunk), tip=tip, dirty=dirty,
                counts={k: len(v) for k, v in sorted(rows.items())}, rows=rows,
                reach=dict(tags=dict(tags), cascade_callers=dict(callers.most_common()), type_here_sites=dict(sites.most_common())))

def _reach_reason(rc: dict) -> str:
    sites = ", ".join(rc["sites"][:3])
    return {"cascade": f"weak-reach cascade via out-of-chunk {sites}: leave for that caller's chunk",
            "type_here": f"weak edge in chunk at {sites}: type or teach it here",
            "strong": "", "unreached": ""}[rc["tag"]]

def key_rows(ch: dict) -> set[tuple[str, str, str]]:
    return {(k, r["rel"], r["name"]) for k, v in ch["rows"].items() for r in v}

def diff(before: dict, after: dict) -> dict:
    kinds = sorted(set(before["counts"]) | set(after["counts"]))
    b, a = key_rows(before), key_rows(after)
    return dict(tip_before=before.get("tip", ""), counts={k: [before["counts"].get(k, 0), after["counts"].get(k, 0)] for k in kinds},
                gone=sorted("\t".join(x) for x in b - a), new=sorted("\t".join(x) for x in a - b))

def find_symbol(g, spec: str) -> list[tuple[str, str]]:
    where, _, name = spec.rpartition(":")
    hits = [r for r in g.defs.get(name, []) if name in g.scripts[r].funcs]
    if where:
        hits = [r for r in hits if r == where or r.endswith("/" + where) or Path(r).stem == where]
    return [(r, name) for r in sorted(hits)]

def why_lines(g, blob: dict, spec: str, globs: list[str]) -> list[str]:
    import unused_graph as ug
    rx = glob_re(globs) if globs else None
    keys = find_symbol(g, spec)
    if not keys:
        return [f"why: no func named {spec}"]
    kind_of = {(r["rel"], r["name"]): k for k, v in blob["rows"].items() for r in v}
    out = [] if rx else ["(no --paths: tags are relative to the target's own file)"]
    for key in keys:
        chunk = {r for r in g.scripts if rx and in_chunk(rx, r)} or {key[0]}
        dist, par = reach_paths(g, chunk)
        rc = explain(g, dist, par, key, chunk)
        out.append(f"why {key[0]}:{key[1]} kind={kind_of.get(key, 'live')} reach={rc['tag']}" + (f" sites={','.join(rc['sites'][:4])}" if rc["sites"] else ""))
        out += ["  " + p for p in rc["path"]]
        inn = sorted({f"{s[0]}:{ln} {k}{'' if s[0] in chunk else ' (out of chunk)'}" for s, outs in g.edges.items()
                      for t, n, k, ln in outs if (t, n) == key and k in ug.WEAK})
        if inn:
            out.append("  weak callers: " + "; ".join(inn[:6]) + (f" (+{len(inn) - 6})" if len(inn) > 6 else ""))
    return out

def console(ch: dict, limit: int) -> list[str]:
    out = [f"chunk: {len(ch['files'])} files, {sum(ch['counts'].values())} rows ({' '.join(ch['globs'])})",
           "counts: " + " ".join(f"{k}={v}" for k, v in ch["counts"].items())]
    if ch.get("diff"):
        d = ch["diff"]
        out.append(f"vs baseline {d['tip_before'] or '?'}: " + " ".join(f"{k} {b}->{a}" for k, (b, a) in d["counts"].items() if b != a)
                   + f" (gone {len(d['gone'])}, new {len(d['new'])})" if d["gone"] or d["new"] or any(b != a for b, a in d["counts"].values())
                   else f"vs baseline {d['tip_before'] or '?'}: no change")
    t, c, h = ch["reach"]["tags"], ch["reach"]["cascade_callers"], ch["reach"].get("type_here_sites", {})
    if t:
        out.append("reach: " + " ".join(f"{k}={v}" for k, v in sorted(t.items())))
    if h:
        out.append("type_here sites: " + ", ".join(f"{f} x{n}" for f, n in list(h.items())[:4]) + (f" (+{len(h) - 4})" if len(h) > 4 else ""))
    if c:
        out.append("cascade callers (their chunk): " + ", ".join(f"{f} x{n}" for f, n in list(c.items())[:4]) + (f" (+{len(c) - 4})" if len(c) > 4 else ""))
    limit = max(4, limit - len(out) - 3)
    shown = []
    for kind in ("orphan_file", "unused", "shadowed", "dead_chain", "apply_ready", "ambiguous", "unused_var", "write_only_var", "init_only_var"):
        for r in ch["rows"].get(kind, []):
            rc = r.get("reach") or {}
            note = f"{rc['tag']} " + ",".join(x.rsplit("/", 1)[-1] for x in rc["sites"][:2]) if rc.get("sites") else (r.get("keep") or "")
            shown.append(f"{kind}\t{r['rel']}:{r.get('line', 0)}\t{r['name']}\t{note[:100]}")
    out += shown[:limit]
    if len(shown) > limit:
        out.append(f"... {len(shown) - limit} more rows (--limit N; unused-chunk.json has all)")
    return out

def plan_md(ch: dict, chunk_no: str) -> str:
    when = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    d = ch.get("diff")
    lines = [f"<!-- unused-chunk {chunk_no} -->", f"#### Chunk {chunk_no} sweep (`{ch['tip']}`{', dirty tree' if ch['dirty'] else ''}; {when})", "",
             "Scope: " + ", ".join(f"`{x}`" for x in ch["globs"]) + f" ({len(ch['files'])} files).", ""]
    lines += ["| kind | before | after |", "|---|---|---|"] if d else ["| kind | rows |", "|---|---|"]
    if d:
        lines += [f"| {k} | {b} | {a} |" for k, (b, a) in d["counts"].items()]
    else:
        lines += [f"| {k} | {v} |" for k, v in ch["counts"].items()]
    lines += ["", "Leftovers and why:"]
    for kind, items in ch["rows"].items():
        if kind == "apply_refused":
            continue
        why = Counter(_short(r.get("keep", "")) for r in items)
        lines.append(f"- {kind} ({len(items)}): " + "; ".join(f"{w} x{n}" if n > 1 else w for w, n in why.most_common(4))
                     + (f"; +{len(why) - 4} other reasons" if len(why) > 4 else ""))
    c, h = ch["reach"]["cascade_callers"], ch["reach"].get("type_here_sites", {})
    if h:
        lines.append("- weak sites inside this chunk: " + ", ".join(f"`{f}` x{n}" for f, n in list(h.items())[:6]))
    if c:
        lines.append("- cascade callers (fix in their own chunk): " + ", ".join(f"`{f}` x{n}" for f, n in c.items()))
    lines.append(f"<!-- /unused-chunk {chunk_no} -->")
    return "\n".join(lines) + "\n"

def _short(why: str) -> str:
    return re.sub(r":\d+(\(\w+\))?", "", why)[:110] or "-"

def write_plan(path: Path, block: str, chunk_no: str) -> str:
    text = path.read_text(encoding="utf-8") if path.is_file() else ""
    rx = re.compile(rf"<!-- unused-chunk {re.escape(chunk_no)} -->.*?<!-- /unused-chunk {re.escape(chunk_no)} -->\n?", re.S)
    if rx.search(text):
        text, how = rx.sub(lambda _m: block, text, count=1), "replaced"
    else:
        text, how = text.rstrip("\n") + ("\n\n" if text else "") + block, "appended"
    path.write_text(text, encoding="utf-8")
    return how

def save(path: Path, ch: dict) -> None:
    path.write_text(json.dumps(ch, indent=1) + "\n", encoding="utf-8")

def add_args(ap, view: bool) -> None:
    """Chunk flags shared by lint.py unused (view=True) and check.py chunk-finish."""
    ap.add_argument("--paths", nargs="+", default=[], help="Chunk globs (`dir/**`, `dir/x*.gd`; a bare dir or `x*` = everything under it)"
                    + (": print only in-chunk rows by kind, a reach tag per ambiguous/debug_only row (strong; type_here: weak site in the "
                       "chunk; cascade: only via a weak edge from an out-of-chunk caller, named) and why each row stays. "
                       "Writes _logs/unused-funcs/unused-chunk.json." if view else "."))
    ap.add_argument("--baseline", metavar="FILE", help="Diff chunk counts and rows against a file saved by lint.py unused --save-baseline.")
    ap.add_argument("--plan-out", metavar="PATH", help="With --chunk N: write/replace the chunk's marked plan block in PATH (never commits)"
                    + ("." if view else "; only when every phase is green."))
    ap.add_argument("--chunk", metavar="N", help="Chunk number/label for the plan block markers.")
    if view:
        ap.add_argument("--why", metavar="[FILE:]FUNC", help="Reach path from the roots with each edge kind, and weak callers (in/out of --paths).")
        ap.add_argument("--save-baseline", metavar="FILE", help="With --paths: save the chunk JSON as a baseline.")
        ap.add_argument("--plan-md", action="store_true", help="With --paths: print the plan markdown block (tip, counts, leftovers and why).")

def cli(root: Path, g, js: Path, opt: dict, limit: int, txt: Path) -> int:
    """lint.py unused with --paths or --why: print this view instead of the repo-wide rows."""
    blob = json.loads(js.read_text(encoding="utf-8"))
    if opt.get("why"):
        for line in why_lines(g, blob, opt["why"], opt["paths"]):
            print(line[:240])
        return agent_log.emit_result("PASS", summary=agent_log.rel(root, txt), cmd="why")
    ch = build(root, g, blob, opt["paths"])
    base = opt.get("baseline")
    if base:
        bp = Path(base)
        if not bp.is_file():
            return agent_log.emit_result("FAIL", error=f"baseline not found: {base} (write one with --save-baseline)")
        ch["diff"] = diff(json.loads(bp.read_text(encoding="utf-8")), ch)
    out = js.parent / "unused-chunk.json"
    save(out, ch)
    if opt.get("save_baseline"):
        save(Path(opt["save_baseline"]), ch)
    extra = {}
    if opt.get("plan_md") or opt.get("plan_out"):
        block = plan_md(ch, opt.get("chunk") or "?")
        if opt.get("plan_out"):
            extra["plan"] = write_plan(Path(opt["plan_out"]), block, opt.get("chunk") or "?")
        if opt.get("plan_md"):
            print(block.rstrip())
    if opt.get("json"):
        return agent_log.emit_result("PASS", summary=agent_log.rel(root, txt), chunk=ch, **extra)
    for line in console(ch, limit):
        print(line[:220])
    print(f"json: {agent_log.rel(root, out)}")
    return agent_log.emit_result("PASS", summary=agent_log.rel(root, txt), files=len(ch["files"]), rows=sum(ch["counts"].values()),
                                 **ch["counts"], **{f"reach_{k}": v for k, v in ch["reach"]["tags"].items()}, **extra)
