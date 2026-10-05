#!/usr/bin/env python3
"""Run scripted shot flows (tools/shot-flows/*.json): open an NPC menu or screen, press pad/key input,
set state, shoot every page, assert, then diff against a baseline or publish to _out/shots/<flow>/ (never assets/: Grok Build places those).

  python tools/run_shot_flow.py --list
  python tools/run_shot_flow.py --survey [--flow A,B]   # one text line per flow: about, states, last shot, band (no picture needed)
  python tools/run_shot_flow.py --sheet NAME            # tile a flow's last frames into one sheet.png (labels; small text is not readable on it)
  python tools/run_shot_flow.py --flow camp-receptionist-menu [--baseline DIR] [--save-baseline DIR] [--publish]
  python tools/run_shot_flow.py --job ui.pause [--save-baseline DIR]   # every flow routes.yaml maps to the job (a door name: its door flows), one call, one summary
  python tools/run_shot_flow.py --changed               # the flows whose JSON changed, plus those mapped to a job whose doc changed
  python tools/run_shot_flow.py --flow N --state NAME   # re-shoot one state of a flow (its steps up to that shot only); prints that frame as changed or same
  python tools/run_shot_flow.py --smoke --no-pixels        # every smoke:true flow, headless, asserts only

Each flow is one worker boot (run_shots.py --steps); the shot tool cannot run two step files in one boot. Flows picked together are run in one call and
deduplicated: a flow with `covered_by: OTHER` is skipped when OTHER is picked too (OTHER shoots and asserts everything it does; `--no-dedupe` runs both). Frames land in _logs/shot-flow/<flow>/ as
NN-name.png (plus NN-name.texts.json and flow.json). Flow format and ops: design/shot-flows.md.
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


def _shot_names(steps: list) -> list[str]:
    out: list[str] = []
    for s in steps:
        if isinstance(s, dict):
            if s.get("op") == "shot":
                out.append(str(s.get("name", "")))
            out += _shot_names(s.get("steps", []) if isinstance(s.get("steps"), list) else [])
    return out


def survey_lines(root: Path, flows: dict[str, dict], names: list[str]) -> list[str]:
    """One text line per flow, so a survey needs no picture: about | states | last shot | band."""
    lines = []
    for n in names or list(flows):
        d = flows[n]
        fdir = root / "_logs" / JOB / n
        pngs = sorted(fdir.glob("[0-9]*.png")) if fdir.is_dir() else []
        band = "never shot"
        if (fdir / "flow.json").is_file():
            try:
                band = "good" if json.loads((fdir / "flow.json").read_text(encoding="utf-8")).get("ok") else "fail"
            except ValueError:
                band = "unreadable"
        about = str(d.get("about", "")).split(". ")[0][:110]
        states = _shot_names(d.get("steps", []))
        lines.append("%s | %s | states: %s | last shot: %s | band: %s" % (
            n, about, ",".join(states) or "none", rel(root, pngs[-1]) if pngs else "none", band))
    return lines


def contact_sheet(root: Path, name: str) -> Path | None:
    """Tile a flow's numbered frames into <flow dir>/sheet.png (imglib montage); None when there are no frames."""
    fdir = root / "_logs" / JOB / name
    pngs = sorted(fdir.glob("[0-9]*.png"))
    if not pngs:
        return None
    from imglib import compare, imgio

    cols = min(4, len(pngs))
    sheet = compare.montage([imgio.load(p) for p in pngs], [p.stem for p in pngs], cols=cols, cell=(480, 270))
    return imgio.save(sheet, fdir / "sheet.png")


def job_flows(root: Path, flows: dict[str, dict], job: str) -> list[str]:
    """Flow names routes.yaml maps to `job` (door.job: its own mapping; a door name: the door's mapping)."""
    from load_routes import check_route, load_routes, shot_flows

    data = load_routes(root)
    door, jb = (job.split(".", 1)[0], job) if "." in job else (job, "")
    bad = check_route(data, door, jb)
    if bad:
        agent_log.fail(bad)
    names = shot_flows(data, door=door, job=jb, job_only=bool(jb))
    if not names:
        agent_log.fail("no shot_flows mapped to %s in design/routes.yaml (a visual job maps its flow there)" % job)
    missing = [n for n in names if n not in flows]
    if missing:
        agent_log.fail("routes.yaml maps %s to unknown flow %s. flows: %s" % (job, ", ".join(missing), ", ".join(flows)))
    return names


def changed_flows(root: Path, flows: dict[str, dict]) -> list[str]:
    """Flows whose JSON file changed (git status), plus the flows mapped to a job whose doc changed."""
    import subprocess
    from load_routes import load_routes, shot_flows

    out = subprocess.run(["git", "status", "--porcelain=v1", "-uall"], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    files = {ln[3:].strip().strip('"').split(" -> ")[-1] for ln in out.splitlines() if len(ln) > 3}
    picked = [n for n, d in flows.items() if rel(root, d["_file"]) in files]
    try:
        for door, spec in (load_routes(root).get("doors") or {}).items():
            for jb, doc in ((spec or {}).get("jobs") or {}).items():
                if isinstance(doc, str) and doc in files:
                    picked += [n for n in shot_flows(load_routes(root), door=door, job=f"{door}.{jb}", job_only=True) if n in flows]
    except Exception:
        pass
    return list(dict.fromkeys(picked))


def state_flow(flow: dict, state: str, path: Path) -> dict | None:
    """The flow cut after its top-level `shot` named `state`: earlier shots and their text asserts are dropped (setup steps stay). None when there is no such shot."""
    steps = flow.get("steps", [])
    idx = next((i for i, s in enumerate(steps) if isinstance(s, dict) and s.get("op") == "shot" and s.get("name") == state), -1)
    if idx < 0:
        return None
    keep = [s for s in steps[:idx] if not (isinstance(s, dict) and s.get("op") in ("shot", "assert_texts"))] + [steps[idx]]
    return {**{k: v for k, v in flow.items() if k not in ("_file", "steps")}, "steps": keep, "_file": path}


def state_frame(fdir: Path, state: str) -> Path | None:
    hits = sorted(fdir.glob("[0-9]*-%s.png" % state)) if fdir.is_dir() else []
    return hits[0] if hits else None


def state_verdict(old: bytes | None, new: Path) -> str:
    """'same' | 'changed' | 'new' for a re-shot state against the frame it replaces."""
    if old is None:
        return "new (no earlier frame of this state to compare)"
    return "same as the earlier frame" if hashlib.sha256(old).digest() == hashlib.sha256(new.read_bytes()).digest() else "CHANGED against the earlier frame"


def plan(flows: dict[str, dict], todo: list[str], dedupe: bool = True) -> tuple[list[str], list[str]]:
    """(flows to run, note lines): a flow `covered_by` another picked flow is skipped; picked flows that cover a common state are noted."""
    run, notes = [], []
    for n in todo:
        by = str(flows[n].get("covered_by") or "")
        if dedupe and by and by != n and by in todo:
            notes.append("skipped %s: covered by %s, which is picked too (its frames and asserts are in that flow)" % (n, by))
        else:
            run.append(n)
    for i, a in enumerate(run):
        for b in run[i + 1:]:
            both = sorted(set(flows[a].get("covers", [])) & set(flows[b].get("covers", [])))
            if both:
                notes.append("overlap: %s and %s both cover %s" % (a, b, ", ".join(both)))
    return run, notes


def pick(flows: dict[str, dict], names: list[str], smoke: bool, every: bool) -> list[str]:
    if every:
        return list(flows)
    if smoke:
        return [n for n, d in flows.items() if d.get("smoke")]
    bad = [n for n in names if n not in flows]
    if bad:
        agent_log.fail("unknown flow %s. flows: %s" % (", ".join(bad), ", ".join(flows)))
    return names


def publish_blocked(root: Path, dest: Path) -> bool:
    """True when dest is inside <root>/assets (after resolving .. and symlinks). Build alone places assets."""
    try:
        d = dest.resolve()
        a = (root / "assets").resolve()
    except OSError:
        return True
    return d == a or a in d.parents


def publish(root: Path, flow: dict, frames_dir: Path, dest_override: str, dry: bool) -> dict:
    """Copy a flow's PNGs to its publish dir and write shots.json (name, file, sha256, size)."""
    spec = flow.get("publish") or {}
    dest = Path(dest_override) if dest_override else root / str(spec.get("dir") or "_out/shots/%s" % flow.get("name"))
    if not dest.is_absolute():
        dest = root / dest
    if publish_blocked(root, dest):
        agent_log.fail("refusing to publish into %s: tooling never writes under assets/ (Grok Build places "
                       "guide images; publish to _out/shots/<flow> and hand them over)" % dest)
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
            rows = shot_diff.compare_dirs(bdir, tmp, max(args.tol, int(flow.get("tol", 0))), fdir / "diff", [tuple(m) for m in flow.get("mask", [])])
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


def selftest() -> int:
    """plan(): a flow covered_by a picked flow is skipped; alone it runs; common `covers` ids are noted."""
    fl = {"a": {"covered_by": "b"}, "b": {"covers": ["ui:x"]}, "c": {"covers": ["ui:x"]}}
    bad = []
    run, notes = plan(fl, ["a", "b"])
    if run != ["b"] or "skipped a: covered by b" not in notes[0]:
        bad.append("a covered flow must be skipped when its cover is picked")
    if plan(fl, ["a"])[0] != ["a"] or plan(fl, ["a", "b"], False)[0] != ["a", "b"]:
        bad.append("a covered flow runs alone, and with --no-dedupe")
    if "overlap: b and c both cover ui:x" not in plan(fl, ["b", "c"])[1]:
        bad.append("two picked flows covering one state must be noted")
    st = {"name": "f", "steps": [{"op": "device"}, {"op": "shot", "name": "a"}, {"op": "assert_texts"}, {"op": "press"}, {"op": "shot", "name": "b"}, {"op": "press"}]}
    cut = state_flow(st, "b", Path("x.json"))
    if cut is None or [s["op"] for s in cut["steps"]] != ["device", "press", "shot"] or state_flow(st, "zz", Path("x.json")) is not None:
        bad.append("--state keeps the setup steps and the named shot, drops earlier shots and text asserts, and refuses an unknown state")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


def main(argv: list[str] | None = None) -> int:
    p = agent_log.std_parser("Run scripted shot flows: capture, assert, diff against a baseline, publish.",
                             writes=True, json_out=True)
    p.add_argument("--list", action="store_true", help="list flows and exit")
    p.add_argument("--selftest", action="store_true", help="run the dedupe cases (no Godot)")
    p.add_argument("--survey", action="store_true", help="one text line per flow (about, states, last shot, band); no Godot run")
    p.add_argument("--sheet", default="", metavar="FLOW", help="tile FLOW's last frames into one sheet.png (labels; fine text is not readable on it)")
    p.add_argument("--flow", action="append", default=[], help="flow name (repeat or comma-separate)")
    p.add_argument("--job", action="append", default=[], metavar="JOB", help="every flow routes.yaml maps to JOB (door.job, or a door name); one call, one summary")
    p.add_argument("--state", default="", metavar="NAME", help="with one --flow: re-shoot only that flow's state NAME (steps up to its shot); prints it as changed or same")
    p.add_argument("--changed", action="store_true", help="flows whose JSON changed, plus those mapped to a job whose doc changed")
    p.add_argument("--no-dedupe", action="store_true", help="run a flow even when a picked flow covers it (covered_by)")
    p.add_argument("--all", action="store_true", help="every flow")
    p.add_argument("--smoke", action="store_true", help="every flow marked smoke:true")
    p.add_argument("--no-pixels", action="store_true", help="headless: steps and asserts only, no PNGs, no display needed")
    p.add_argument("--scale", type=int, default=0, help="PNG scale percent (default: the flow's scale, else 100)")
    p.add_argument("--timeout-sec", type=int, default=run_shots.TIMEOUT_SEC, help="Godot timeout per flow in seconds.")
    p.add_argument("--out-dir", default="", help="frames root (default _logs/shot-flow)")
    p.add_argument("--baseline", default="", help="directory of earlier frames (BASE/<flow>/NN-name.png) to diff against")
    p.add_argument("--save-baseline", default="", help="copy this run's frames to DIR/<flow>/ (run before the change)")
    p.add_argument("--tol", type=int, default=0, help="per-channel diff tolerance")
    p.add_argument("--max-ratio", type=float, default=None, help="FAIL when a frame changes more than this pixel fraction")
    p.add_argument("--publish", action="store_true", help="copy frames to the flow's publish.dir (default _out/shots/<flow>; assets/ is refused) and write shots.json")
    p.add_argument("--check-published", action="store_true",
                   help="after capture, FAIL when the flow's published shots no longer match (UI changed: re-publish)")
    p.add_argument("--publish-dir", default="", help="publish here instead of the flow's publish.dir (assets/ is refused)")
    args = p.parse_args(argv)
    if args.selftest:
        return selftest()
    root, where = agent_log.cwd_scan_root(args)
    flows = list_flows(root)
    if args.list:
        for n, d in flows.items():
            print("%s\tsmoke=%s\tsteps=%d\tcovers=%s\tcovered_by=%s\t%s" % (n, str(bool(d.get("smoke"))).lower(), len(d.get("steps", [])),
                                                                           ",".join(d.get("covers", [])), d.get("covered_by", "-"), d.get("about", "")[:80]))
        return agent_log.emit_result("PASS", flows=len(flows))
    names = agent_log.split_list(args.flow)
    if args.survey:
        bad = [n for n in names if n not in flows]
        if bad:
            agent_log.fail("unknown flow %s. flows: %s" % (", ".join(bad), ", ".join(flows)))
        for ln in survey_lines(root, flows, names):
            print(ln)
        return agent_log.emit_result("PASS", flows=len(names) or len(flows))
    if args.sheet:
        if args.sheet not in flows:
            agent_log.fail("unknown flow %s. flows: %s" % (args.sheet, ", ".join(flows)))
        out = contact_sheet(root, args.sheet)
        if out is None:
            agent_log.fail("no frames for %s yet: run `python tools/run_shot_flow.py --flow %s` first" % (args.sheet, args.sheet))
        print("sheet: %s (labels are frame names; open a single frame to read small text)" % rel(root, out))
        return agent_log.emit_result("PASS", sheet=rel(root, out))
    for j in agent_log.split_list(args.job):
        names += job_flows(root, flows, j)
    if args.changed:
        names += changed_flows(root, flows)
        if not names and not (args.all or args.smoke):
            print("no changed flow files and no changed job doc with a mapped flow: nothing to run")
            return agent_log.emit_result("PASS", flows=0)
    names = list(dict.fromkeys(names))
    if not (names or args.all or args.smoke):
        agent_log.fail("name a flow (--flow N), a job (--job J), or use --changed / --all / --smoke / --list / --survey")
    out_root = Path(args.out_dir) if args.out_dir else root / "_logs" / JOB
    if args.state:
        if len(names) != 1 or args.all or args.smoke or args.changed:
            agent_log.fail("--state NAME goes with exactly one --flow N (example: python tools/run_shot_flow.py --flow camp-npc-panels --state vendor)")
        base = names[0]
        if base not in flows:
            agent_log.fail("unknown flow %s. flows: %s" % (base, ", ".join(flows)))
        sname = "%s~%s" % (base, args.state)
        cut = state_flow(flows[base], args.state, out_root / ("%s.steps.json" % sname))
        if cut is None:
            agent_log.fail("flow %s has no top-level shot named %r. states: %s" % (base, args.state, ", ".join(_shot_names(flows[base].get("steps", []))) or "none"))
        prev = state_frame(out_root / sname, args.state) or state_frame(out_root / base, args.state)
        old = prev.read_bytes() if prev else None
        out_root.mkdir(parents=True, exist_ok=True)
        if not args.dry_run:
            (out_root / ("%s.steps.json" % sname)).write_text(json.dumps({k: v for k, v in cut.items() if k != "_file"}, indent=1), encoding="utf-8")
        rows = [run_one(root, sname, cut, args, out_root)]
        notes = []
        fr = state_frame(out_root / sname, args.state)
        if fr is not None and not args.dry_run:
            notes.append("state %s: %s (%s)" % (args.state, state_verdict(old, fr), rel(root, fr)))
        todo = [sname]
    else:
        todo, notes = plan(flows, pick(flows, names, args.smoke, args.all), not args.no_dedupe)
        rows = [run_one(root, n, flows[n], args, out_root) for n in todo]
    bad_run = [r for r in rows if not r["ok"] and not args.dry_run]
    bad_diff = [r for r in rows if r.get("diff_status") == "FAIL"]
    changed = [r for r in rows if r.get("diff_status") == "INFO"]
    stale = [r for r in rows if r.get("stale")]
    status = "FAIL" if (bad_run or bad_diff or stale) else ("INFO" if changed else "PASS")
    lines = ["shot-flow %s no_pixels=%s" % (where, args.no_pixels)] + notes
    for r in rows:
        lines.append("%s band=%s ok=%s steps=%s frames=%s diff=%s fail=%s dir=%s" % (
            r["flow"], r["band"], r["ok"], r["steps"], r["frames"], r.get("diff_status", "-"), r["fail"] or "-", r["dir"]))
        for d in r.get("diff", []) if isinstance(r.get("diff"), list) else []:
            if d["status"] != "same":
                lines.append("  %s %s changed_px=%s ratio=%s bbox=%s" % (d["status"], d["name"], d["changed_px"], d["ratio"], d["bbox"]))
        if r["frames"] and not args.no_pixels and not args.dry_run:
            lines.append("  frames: " + " ".join(sorted(x.name for x in (root / r["dir"]).glob("[0-9]*.png"))))
        if r.get("cmd"):
            lines.append("  cmd: " + r["cmd"])
        for e in r.get("errors", []):
            lines.append("  error: " + e)
        for sfile in r.get("stale", []):
            lines.append("  stale: " + sfile)
        if r.get("published"):
            lines.append("  published: %(dir)s files=%(files)d" % r["published"])
    out_root.mkdir(parents=True, exist_ok=True)
    if status == "FAIL" and not args.dry_run:
        import retry_lib

        lines += ["", retry_lib.block(root, "run_shot_flow.py --flow " + ",".join(t.split("~")[0] for t in todo), lines)]
    res = agent_log.write_run_file(root, out_root, JOB, "\n".join(lines), status, write=not args.dry_run, flows=len(rows),
                                   **{"pass": sum(1 for r in rows if r["ok"])}, fail=len(bad_run), stale=len(stale),
                                   changed=len(changed), frames=sum(r["frames"] for r in rows))
    if args.json:
        agent_log.print_json({"status": status, "flows": rows})
    else:
        print("\n".join(lines + [res]))
    return agent_log.exit_code(status)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
