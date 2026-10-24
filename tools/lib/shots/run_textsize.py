#!/usr/bin/env python3
"""On-screen text size per screen at phone, tablet and desktop viewports, in CSS px (what a player's eye gets).

  python tools/shots.py textsize                          # every screen in tools/data/text-size.json at every viewport
  python tools/shots.py textsize --flow title-menu --viewport phone-l
  python tools/shots.py textsize --gate                   # FAIL when text on a gated viewport is under min_css
  python tools/shots.py textsize --from DIR [--compare OLD_DIR]   # re-read a run (no Godot); old vs new smallest per screen
  python tools/shots.py textsize --selftest

Each screen is a shot flow run on the desktop build with the window at CSS size x dpr (the web canvas is device pixels)
and `--dpr` passed to the game (`--wdb-dpr`, read by ui_text.gd as on web). Every shot dumps its visible texts
(`--texts-all`): px = font size x canvas, layer and stretch scale in window pixels; CSS px = px / dpr (the em size;
a lowercase letter is about half). Frames and texts land in _logs/textsize/<viewport>/<flow>/; report.json beside them.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import boot  # noqa: E402,F401

import agent_log
import run_shot_flow
import run_shots
from agent_log import rel

JOB = "textsize"
DATA = "tools/data/text-size.json"

def screen_rows(fdir: Path, dpr: float, skip: list[str]) -> dict[str, list[dict]]:
    """{state: rows sorted smallest first} from a flow's NN-state.texts.json dumps; each row gains css."""
    out: dict[str, list[dict]] = {}
    for f in sorted(fdir.glob("[0-9]*.texts.json")):
        state = f.name.split("-", 1)[1][: -len(".texts.json")]
        rows = [dict(r, css=round(float(r.get("px", 0)) / dpr, 1)) for r in json.loads(f.read_text(encoding="utf-8"))
                if r.get("px") is not None and not any(re.search(p, str(r.get("path", ""))) for p in skip)]
        out[state] = sorted(rows, key=lambda r: r["css"])
    return out

def summarize(root_dir: Path, cfg: dict) -> dict:
    """{viewport: {flow/state: {min, text, n, under}}} for every dump under root_dir/<viewport>/<flow>/."""
    rep: dict = {}
    allow = cfg.get("allow", {})
    for vp, (_, _, dpr) in cfg["viewports"].items():
        for fdir in sorted((root_dir / vp).glob("*")) if (root_dir / vp).is_dir() else []:
            for state, rows in screen_rows(fdir, float(dpr), cfg.get("skip", [])).items():
                key = "%s/%s" % (fdir.name, state)
                floor = min([float(v) for k, v in allow.items() if re.search(k, key)] or [cfg["min_css"]])
                if rows:
                    rep.setdefault(vp, {})[key] = {
                        "min": rows[0]["css"], "text": rows[0]["text"][:40].replace("\n", " "), "path": rows[0].get("path", "")[-60:],
                        "n": len(rows), "floor": floor, "allow": floor < cfg["min_css"], "under": sum(1 for r in rows if r["css"] < floor)}
    return rep

def run(root: Path, out: Path, cfg: dict, flows: list[str], vps: list[str], timeout: int) -> list[str]:
    known = run_shot_flow.list_flows(root)
    bad = []
    for vp in vps:
        w, h, dpr = cfg["viewports"][vp]
        for name in flows:
            fdir = out / vp / name
            shutil.rmtree(fdir, ignore_errors=True)
            fdir.mkdir(parents=True)
            ns = run_shots.build_parser().parse_args(["--steps", str(known[name]["_file"]), "--frames-dir", str(fdir), "--out", str(fdir / "last.png"),
                                                      "--width", str(int(w * dpr)), "--height", str(int(h * dpr)), "--texts-all",
                                                      "--dpr", str(dpr), "--timeout-sec", str(timeout)])
            res = run_shots.capture(ns, root, {"width", "height", "scale"})
            fl = res.get("flow") or {}
            print("%s %s %s %s" % (vp, name, res.get("band"), fl.get("fail", "")), flush=True)
            if not res.get("ok") or not fl.get("ok", True):
                bad.append("%s %s: %s" % (vp, name, fl.get("fail") or res.get("status")))
    return bad

def table(rep: dict, old: dict | None, vps: list[str]) -> list[str]:
    lines = []
    for vp in vps:
        for key, r in sorted(rep.get(vp, {}).items(), key=lambda kv: kv[1]["min"]):
            was = (old or {}).get(vp, {}).get(key)
            lines.append("%-8s %-44s min %5.1f%s  under=%d%s  \"%s\"" % (vp, key, r["min"], ("  (was %.1f)" % was["min"]) if was else "", r["under"],
                                                              ("  floor=%g" % r["floor"]) if r.get("allow") else "", r["text"]))
    return lines

def selftest() -> list[str]:
    import tempfile
    bad = []
    with tempfile.TemporaryDirectory() as td:
        d = Path(td) / "phone-l" / "f"
        d.mkdir(parents=True)
        (d / "01-menu.texts.json").write_text(json.dumps([{"text": "Big", "px": 45.0, "path": "/root/A"}, {"text": "tiny", "px": 15.0, "path": "/root/Dbg/x"},
                                                          {"text": "small", "px": 24.0, "path": "/root/B"}]))
        cfg = {"min_css": 11, "viewports": {"phone-l": [844, 390, 3]}, "skip": ["/Dbg/"]}
        rep = summarize(Path(td), cfg)
        got = rep.get("phone-l", {}).get("f/menu", {})
        if got.get("min") != 8.0 or got.get("text") != "small" or got.get("under") != 1 or got.get("n") != 2:
            bad.append("summarize: %s" % got)
        cfg["allow"] = {"^f/": 8}
        got = summarize(Path(td), cfg).get("phone-l", {}).get("f/menu", {})
        if got.get("under") != 0 or got.get("floor") != 8:
            bad.append("allow: %s" % got)
    return bad

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Text size per screen in CSS px at phone / tablet / desktop viewports (shot flows + texts dumps).")
    ap.add_argument("--flow", default="", help="flows, comma separated (default: the list in %s)" % DATA)
    ap.add_argument("--viewport", default="", help="viewport names, comma separated (default all; --gate: the gated ones)")
    ap.add_argument("--gate", action="store_true", help="FAIL when any text on a gated viewport is under min_css")
    ap.add_argument("--min", type=float, default=0.0, help="override min_css")
    ap.add_argument("--out", default="", help="run folder (default _logs/textsize/run)")
    ap.add_argument("--from", dest="src", default="", help="summarize an earlier run folder; Godot does not run")
    ap.add_argument("--compare", default="", help="older run folder: print its smallest size beside each screen")
    ap.add_argument("--timeout-sec", type=int, default=300, help="per flow")
    ap.add_argument("--selftest", action="store_true", help="offline check of the summary math")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    if args.selftest:
        bad = selftest()
        return agent_log.finish(JOB, root, "textsize selftest\n" + "\n".join(bad or ["ok"]), "FAIL" if bad else "PASS", args=args, problems=len(bad))
    cfg = json.loads((root / DATA).read_text(encoding="utf-8"))
    if args.min > 0:
        cfg["min_css"] = args.min
    vps = [v for v in args.viewport.split(",") if v] or (cfg["gate"] if args.gate else list(cfg["viewports"]))
    flows = [f for f in args.flow.split(",") if f] or cfg["flows"]
    unknown = [v for v in vps if v not in cfg["viewports"]] + [f for f in flows if f not in run_shot_flow.list_flows(root)]
    if unknown:
        agent_log.fail("unknown viewport or flow: %s" % ", ".join(unknown))
    out = Path(args.src or args.out or (root / "_logs" / JOB / "run")).resolve()
    errs = [] if args.src else run(root, out, cfg, flows, vps, args.timeout_sec)
    rep = summarize(out, cfg)
    (out / "report.json").write_text(json.dumps({"min_css": cfg["min_css"], "screens": rep}, indent=1) + "\n", encoding="utf-8")
    old = summarize(Path(args.compare).resolve(), cfg) if args.compare else None
    lines = table(rep, old, vps)
    gated = [v for v in vps if v in cfg["gate"]]
    under = sum(r["under"] for v in gated for r in rep.get(v, {}).values())
    smallest = min((r["min"] for v in gated for r in rep.get(v, {}).values()), default=0.0)
    status = "FAIL" if errs or (args.gate and under) else ("INFO" if under else "PASS")
    body = "\n".join(["textsize min_css=%g gate=%s out=%s" % (cfg["min_css"], ",".join(cfg["gate"]), rel(root, out))] + lines + errs)
    return agent_log.finish(JOB, root, body, status, args=args, screens=sum(len(v) for v in rep.values()), under=under,
                            smallest=smallest, errors=len(errs))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
