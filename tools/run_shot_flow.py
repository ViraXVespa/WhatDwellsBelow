#!/usr/bin/env python3
"""Run scripted shot flows (tools/shot-flows/*.json): open an NPC menu or screen, press pad/key input,
set state, shoot every page, assert, then diff against a baseline or publish into the docs/assets.

  python3 tools/run_shot_flow.py --list
  python3 tools/run_shot_flow.py --flow camp-receptionist-menu [--baseline DIR] [--save-baseline DIR] [--publish]
  python3 tools/run_shot_flow.py --smoke --no-pixels        # every smoke:true flow, headless, asserts only

Each flow is one worker boot (run_shots.py --steps). Frames land in _logs/shot-flow/<flow>/ as
NN-name.png (plus NN-name.texts.json and flow.json). Flow format and ops: design/shot-tool.md.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import run_shots
import shot_diff
from agent_log import rel

JOB = "shot-flow"
FLOW_DIR = "tools/shot-flows"
NON_FLOW = {"states.json"}


def list_flows(root: Path) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for f in sorted((root / FLOW_DIR).glob("*.json")):
        if f.name in NON_FLOW:
            continue
        data = json.loads(f.read_text(encoding="utf-8"))
        data["_file"] = f
        out[str(data.get("name") or f.stem)] = data
    return out


def pick(flows: dict[str, dict], names: list[str], smoke: bool, every: bool) -> list[str]:
    if every:
        return list(flows)
    if smoke:
        return [n for n, d in flows.items() if d.get("smoke")]
    bad = [n for n in names if n not in flows]
    if bad:
        agent_log.fail("unknown flow %s. flows: %s" % (", ".join(bad), ", ".join(flows)))
    return names


def publish(root: Path, flow: dict, frames_dir: Path, dest_override: str, dry: bool) -> dict:
    """Copy a flow's PNGs to its publish dir and write shots.json (name, file, sha256, size)."""
    spec = flow.get("publish") or {}
    dest = Path(dest_override) if dest_override else root / str(spec.get("dir") or "")
    if not dest_override and not spec.get("dir"):
        agent_log.fail("flow %s has no publish.dir (or pass --publish-dir)" % flow.get("name"))
    prefix = str(spec.get("prefix", ""))
    rows = []
    for fr in json.loads((frames_dir / "flow.json").read_text(encoding="utf-8")).get("frames", []):
        if not fr.get("file"):
            continue
        name = "%s%s.png" % (prefix, fr["file"][:-4] if spec.get("numbered", True) else fr["name"])
        src = frames_dir / fr["file"]
        if not dry:
            dest.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dest / name)
        rows.append({"file": name, "source": fr["file"], "frame": fr["name"], "w": fr["w"], "h": fr["h"],
                     "sha256": hashlib.sha256(src.read_bytes()).hexdigest()})
    manifest = {"flow": flow.get("name"), "source": rel(root, flow["_file"]), "frames": rows}
    if not dry:
        (dest / ("%sshots.json" % prefix)).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return {"dir": rel(root, dest) if dest.is_absolute() and str(dest).startswith(str(root)) else str(dest), "files": len(rows)}


def run_one(root: Path, name: str, flow: dict, args, out_root: Path) -> dict:
    fdir = out_root / name
    if fdir.exists() and not args.dry_run:
        shutil.rmtree(fdir)
    argv = ["--steps", str(flow["_file"]), "--frames-dir", str(fdir), "--out", str(fdir / "last.png"),
            "--timeout-sec", str(args.timeout_sec), "--scale", str(args.scale or flow.get("scale", 100))]
    if args.no_pixels:
        argv.append("--no-pixels")
    if args.dry_run:
        argv.append("--dry-run")
    ns = run_shots.build_parser().parse_args(argv)
    res = run_shots.capture(ns, root, {"scale"})
    flow_json = res.get("flow") or {}
    row = {"flow": name, "band": res["band"], "status": res["status"], "ok": bool(res["ok"]) and bool(flow_json.get("ok", True)),
           "steps": flow_json.get("steps", 0), "frames": len(flow_json.get("frames", [])), "fail": flow_json.get("fail", ""),
           "dir": rel(root, fdir), "wall_ms": res.get("wall_ms", 0)}
    if args.dry_run:
        row["cmd"] = " ".join(str(a) for a in res["godot_args"])
        return row
    row["errors"] = res.get("errors", [])[:5]
    if args.save_baseline and not args.no_pixels:
        dst = Path(args.save_baseline) / name
        dst.mkdir(parents=True, exist_ok=True)
        for png in fdir.glob("[0-9]*.png"):
            shutil.copyfile(png, dst / png.name)
        row["saved_baseline"] = str(dst)
    if args.baseline and not args.no_pixels:
        base = Path(args.baseline) / name
        if not base.is_dir():
            row["diff"] = "no-baseline"
            row["diff_status"] = "FAIL"
        else:
            both = [p for p in fdir.glob("[0-9]*.png")]
            tmp = fdir / "frames-only"
            tmp.mkdir()
            for png in both:
                shutil.copyfile(png, tmp / png.name)
            bdir = fdir / "baseline-only"
            bdir.mkdir()
            for png in base.glob("[0-9]*.png"):
                shutil.copyfile(png, bdir / png.name)
            rows = shot_diff.compare_dirs(bdir, tmp, args.tol, fdir / "diff")
            row["diff_status"] = shot_diff.verdict(rows, args.max_ratio)
            row["diff"] = [{k: r.get(k) for k in ("name", "status", "changed_px", "ratio", "bbox")} for r in rows]
            shutil.rmtree(tmp)
            shutil.rmtree(bdir)
    if args.check_published and row["ok"] and not args.no_pixels:
        spec = flow.get("publish") or {}
        man = root / str(spec.get("dir", "")) / (str(spec.get("prefix", "")) + "shots.json")
        stale = []
        if man.is_file():
            fresh = {fr["file"]: hashlib.sha256((fdir / fr["file"]).read_bytes()).hexdigest()
                     for fr in json.loads((fdir / "flow.json").read_text(encoding="utf-8")).get("frames", []) if fr.get("file")}
            stale = [r["file"] for r in json.loads(man.read_text(encoding="utf-8")).get("frames", [])
                     if fresh.get(r["source"]) != r["sha256"]]
        else:
            stale = ["(no shots.json: never published)"]
        row["stale"] = stale
    if args.publish and row["ok"] and not args.no_pixels:
        row["published"] = publish(root, flow, fdir, args.publish_dir, False)
    return row


def main(argv: list[str] | None = None) -> int:
    p = agent_log.std_parser("Run scripted shot flows: capture, assert, diff against a baseline, publish.",
                             writes=True, json_out=True)
    p.add_argument("--list", action="store_true", help="list flows and exit")
    p.add_argument("--flow", action="append", default=[], help="flow name (repeat or comma-separate)")
    p.add_argument("--all", action="store_true", help="every flow")
    p.add_argument("--smoke", action="store_true", help="every flow marked smoke:true")
    p.add_argument("--no-pixels", action="store_true", help="headless: steps and asserts only, no PNGs, no display needed")
    p.add_argument("--scale", type=int, default=0, help="PNG scale percent (default: the flow's scale, else 100)")
    p.add_argument("--timeout-sec", type=int, default=run_shots.TIMEOUT_SEC)
    p.add_argument("--out-dir", default="", help="frames root (default _logs/shot-flow)")
    p.add_argument("--baseline", default="", help="directory of earlier frames (BASE/<flow>/NN-name.png) to diff against")
    p.add_argument("--save-baseline", default="", help="copy this run's frames to DIR/<flow>/ (run before the change)")
    p.add_argument("--tol", type=int, default=0, help="per-channel diff tolerance")
    p.add_argument("--max-ratio", type=float, default=None, help="FAIL when a frame changes more than this pixel fraction")
    p.add_argument("--publish", action="store_true", help="copy frames to the flow's publish.dir and write shots.json")
    p.add_argument("--check-published", action="store_true",
                   help="after capture, FAIL when the flow's published shots no longer match (UI changed: re-publish)")
    p.add_argument("--publish-dir", default="", help="publish here instead of the flow's publish.dir")
    args = p.parse_args(argv)
    root = Path(args.root).resolve() if args.root else agent_log.repo_root(_TOOLS.parent)
    flows = list_flows(root)
    if args.list:
        for n, d in flows.items():
            print("%s\tsmoke=%s\tsteps=%d\tcovers=%s\t%s" % (n, str(bool(d.get("smoke"))).lower(), len(d.get("steps", [])),
                                                             ",".join(d.get("covers", [])), d.get("about", "")[:80]))
        return agent_log.emit_result("PASS", flows=len(flows))
    names = agent_log.split_list(args.flow)
    if not (names or args.all or args.smoke):
        agent_log.fail("name a flow (--flow N), or use --all / --smoke / --list")
    todo = pick(flows, names, args.smoke, args.all)
    out_root = Path(args.out_dir) if args.out_dir else root / "_logs" / JOB
    rows = [run_one(root, n, flows[n], args, out_root) for n in todo]
    bad_run = [r for r in rows if not r["ok"] and not args.dry_run]
    bad_diff = [r for r in rows if r.get("diff_status") == "FAIL"]
    changed = [r for r in rows if r.get("diff_status") == "INFO"]
    stale = [r for r in rows if r.get("stale")]
    status = "FAIL" if (bad_run or bad_diff or stale) else ("INFO" if changed else "PASS")
    lines = ["shot-flow root=. no_pixels=%s" % args.no_pixels]
    for r in rows:
        lines.append("%s band=%s ok=%s steps=%s frames=%s diff=%s fail=%s dir=%s" % (
            r["flow"], r["band"], r["ok"], r["steps"], r["frames"], r.get("diff_status", "-"), r["fail"] or "-", r["dir"]))
        for d in r.get("diff", []) if isinstance(r.get("diff"), list) else []:
            if d["status"] != "same":
                lines.append("  %s %s changed_px=%s ratio=%s bbox=%s" % (d["status"], d["name"], d["changed_px"], d["ratio"], d["bbox"]))
        if r.get("cmd"):
            lines.append("  cmd: " + r["cmd"])
        for e in r.get("errors", []):
            lines.append("  error: " + e)
        for sfile in r.get("stale", []):
            lines.append("  stale: " + sfile)
        if r.get("published"):
            lines.append("  published: %(dir)s files=%(files)d" % r["published"])
    out_root.mkdir(parents=True, exist_ok=True)
    summary = out_root / "summary.txt"
    res = agent_log.result_line(status, rel(root, summary), flows=len(rows), pass_=sum(1 for r in rows if r["ok"]),
                                fail=len(bad_run), stale=len(stale), changed=len(changed), frames=sum(r["frames"] for r in rows))
    res = res.replace("pass_=", "pass=")
    if not args.dry_run:
        summary.write_text("\n".join(lines + [res]) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps({"status": status, "flows": rows}))
    else:
        print("\n".join(lines + [res]))
    return agent_log.exit_code(status)


if __name__ == "__main__":
    raise SystemExit(main())
