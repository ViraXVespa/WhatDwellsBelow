#!/usr/bin/env python3
"""Gameplay clips from the desktop build: put the game in a named scenario, play a short input timeline, record it with
Godot movie maker (--write-movie) and keep only the frames between the timeline's marks as an H.264 MP4.

  python tools/shots.py movie --list                       # movies and scenarios in tools/data/movies.json
  python tools/shots.py movie hub-walk                     # -> _logs/movie/hub-walk/hub-walk.mp4 (+ end.png, movie-flow.json)
  python tools/shots.py movie hub-walk --game DIR --out O  # same script against another checkout (before/after clips)
  python tools/shots.py movie hub-walk --dry-run           # print the composed shot flow, run nothing
  python tools/shots.py movie --selftest                   # every movie composes; trim math; --refs worktree, inject, diff, reel
  python tools/shots.py movie --refs origin/main,HEAD hub-ui   # same movies/views/sets at two refs -> reel + contact sheet (movie_refs.py)

A movie is `{about, scenario, fps, width, height, zoom?, timeline: [shot-flow ops]}`. A scenario is either shot-flow
header keys plus setup `steps`, or `{flow, state}`: that flow's steps up to its `state` shot (gear, enemies, rooms and
camera all come from the flow). The run is one `shots.py capture --steps` boot with `--movie` and `--fixed-fps fps`, so
the recorded clip is frame-exact and repeatable. Movie maker records at the project viewport size (1920x1080; the
window size does not change it), so the cut is scaled into the movie's width x height (same 16:9 framing). Timeline ops: walk_to, drive, tap (step_play.gd) and every other flow op.
Edit the result with `media.py clip` (trim, join, caption, sbs, export). Clips stay in _logs/ (never committed).
"""
from __future__ import annotations

import hashlib
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import boot  # noqa: E402,F401

import agent_log
import clip_edit
import movie_refs
import run_shot_flow
import run_shots
from agent_log import rel

JOB = "movie"
DATA = "tools/data/movies.json"
HEADER = ("scene", "hud", "zoom", "settle_ms", "seed", "floor", "px", "pz")
MARK = re.compile(r"SHOT: mark name=(\S+) frame=(\d+)")

def load(root: Path) -> dict:
    return json.loads((root / DATA).read_text(encoding="utf-8"))

def scenario_flow(root: Path, sc: dict) -> dict:
    """Header keys + setup steps of a scenario; a {flow, state} one is that flow cut at the state, its last shot dropped."""
    if sc.get("flow"):
        flows = run_shot_flow.list_flows(root)
        if sc["flow"] not in flows:
            raise SystemExit("scenario flow %r not in %s" % (sc["flow"], run_shot_flow.FLOW_DIR))
        cut = run_shot_flow.state_flow(flows[sc["flow"]], str(sc.get("state", "")), Path(sc["flow"]))
        if cut is None:
            raise SystemExit("flow %s has no state %r" % (sc["flow"], sc.get("state")))
        return {**{k: cut[k] for k in HEADER if k in cut}, "steps": cut["steps"][:-1] + list(sc.get("steps", []))}
    return {**{k: sc[k] for k in HEADER if k in sc}, "steps": list(sc.get("steps", []))}

def compose(data: dict, name: str, root: Path) -> dict:
    """One shot flow: scenario setup, mark start, timeline, mark end, a closing still (the shot tool needs one)."""
    mv = data["movies"].get(name)
    if mv is None:
        raise SystemExit("no movie %r (have: %s)" % (name, ", ".join(sorted(data["movies"]))))
    sc = data["scenarios"].get(mv.get("scenario", ""))
    if sc is None:
        raise SystemExit("movie %s: no scenario %r" % (name, mv.get("scenario")))
    base = scenario_flow(root, sc)
    head = {**{k: v for k, v in base.items() if k != "steps"}, **{k: mv[k] for k in HEADER if k in mv}}
    fps = int(mv.get("fps", 30))
    return {"about": "movie %s: %s" % (name, mv.get("about", "")), **head, "width": int(mv.get("width", 1280)),
            "height": int(mv.get("height", 720)), "fixed_fps": fps,
            "steps": base["steps"] + [{"op": "mark", "name": "start"}] + list(mv["timeline"])
            + [{"op": "mark", "name": "end"}, {"op": "shot", "name": "end"}]}

def marks(lines: list[str]) -> dict[str, int]:
    return {m.group(1): int(m.group(2)) for m in (MARK.search(x) for x in lines) if m}

def cut(raw: Path, at: dict[str, int], fps: int, out: Path, size: tuple[int, int] = (0, 0)) -> tuple[int, int]:
    """Encode raw/f%08d.png from the start mark to the end mark; returns (first frame, count)."""
    have = sorted(int(p.stem[1:]) for p in raw.glob("f[0-9]*.png"))
    if not have:
        raise SystemExit("movie maker wrote no frames in %s" % raw)
    first = max(have[0], min(at.get("start", have[0]), have[-1]))
    last = max(first, min(at.get("end", have[-1]), have[-1]))
    clip_edit.encode_seq(raw / "f%08d.png", fps, first, last - first + 1, out, size)
    return first, last - first + 1

def selftest(root: Path) -> list[str]:
    bad: list[str] = []
    data = load(root)
    ops = set(re.findall(r'"([a-z_]+)"', " ".join(re.findall(r'^\t\t"[^\n]*":$', (root / "scripts/debug/shot_tool/step_ops.gd").read_text(encoding="utf-8"), re.M)))) | {"repeat"}
    for name in data["movies"]:
        try:
            fl = compose(data, name, root)
        except SystemExit as exc:
            bad.append("%s: %s" % (name, exc))
            continue
        unknown = sorted({s.get("op") for s in fl["steps"]} - ops)
        if unknown:
            bad.append("%s: unknown ops %s" % (name, unknown))
        if [s["name"] for s in fl["steps"] if s["op"] == "mark"][-2:] != ["start", "end"] or not fl.get("scene"):
            bad.append("%s: marks or scene missing" % name)
    if marks(["x SHOT: mark name=start frame=12", "SHOT: mark name=end frame=40"]) != {"start": 12, "end": 40}:
        bad.append("mark parse")
    if refs_tag("origin/main,HEAD", "hub-ui") == refs_tag("origin/main,HEAD", "hud-low-hp"):
        bad.append("refs out dir ignores the names (a subset rerun would overwrite the full compare)")
    with tempfile.TemporaryDirectory() as td:
        t = Path(td)
        clip_edit._run(["-f", "lavfi", "-i", "testsrc2=size=320x180:rate=30:duration=1", "-start_number", "0", str(t / "f%08d.png")])
        first, n = cut(t, {"start": 5, "end": 24}, 30, t / "c.mp4", (160, 90))
        got = clip_edit.info(t / "c.mp4")
        if (first, n) != (5, 20) or abs(got["sec"] - 20 / 30) > 0.05 or got["w"] != 160:
            bad.append("trim math: first=%d n=%d %s" % (first, n, got))
    return bad

def refs_tag(refs: str, names: str) -> str:
    """Out dir name: refs-<A>-<B>-<names>, so a rerun of a subset never overwrites another name list's compare.json."""
    slug = lambda x: re.sub(r"[^\w.-]+", "_", x)
    tag = "refs-" + "-".join(slug(r) for r in refs.split(",")) + "-" + slug(names)
    return tag if len(tag) <= 80 else tag[:70] + "-" + hashlib.sha1(names.encode()).hexdigest()[:8]

def refs_main(root: Path, data: dict, args) -> int:
    tag = refs_tag(args.refs, args.movie)
    out = Path(args.out).resolve() if args.out else agent_log.ensure_agent_log_dir(JOB, root) / tag
    lines: list[str] = []
    def log(x: str) -> None:
        print(x, flush=True)
        lines.append(x)
    res = movie_refs.run(root, data, args.refs, args.movie, out, args.keep_worktrees, log)
    changed = [r["name"] for r in res["items"] if r.get("diff", {}).get("changed")]
    failed = [r["name"] for r in res["items"] if not (r.get("a") and r.get("b"))]
    lines.append("changed: %s | no visible change: %s | failed: %s" % (", ".join(changed) or "-", ", ".join(
        r["name"] for r in res["items"] if r.get("diff") and not r["diff"]["changed"]) or "-", ", ".join(failed) or "-"))
    lines.append("reel: %s" % json.dumps(res["reel"]))
    return agent_log.finish(JOB, root, "\n".join(lines), "FAIL" if failed else "PASS", args=args, refs=args.refs, changed=len(changed),
                            same=len(res["items"]) - len(changed) - len(failed), failed=len(failed), out=rel(root, out))

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Scenario + input timeline -> Godot movie maker clip (MP4 between the marks).", writes=True)
    ap.add_argument("movie", nargs="?", default="", help="movie name in tools/data/movies.json (with --refs: comma movies, views, sets)")
    ap.add_argument("--refs", default="", help="A,B: record the names at both git refs in temp worktrees, diff, build a before/after reel (movie_refs.py)")
    ap.add_argument("--keep-worktrees", action="store_true", help="with --refs: leave the temp worktrees")
    ap.add_argument("--list", action="store_true", help="list movies and scenarios")
    ap.add_argument("--game", default="", help="Godot project to record (default this repo); e.g. a worktree at an older commit for the before clip")
    ap.add_argument("--out", default="", help="output MP4 (default _logs/movie/<name>/<name>.mp4)")
    ap.add_argument("--keep-raw", action="store_true", help="keep the raw movie-maker PNG frames")
    ap.add_argument("--timeout-sec", type=int, default=1800, help="Godot timeout")
    ap.add_argument("--selftest", action="store_true", help="compose every movie and check the trim math")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    if args.selftest:
        bad = selftest(root) + movie_refs.selftest(root)
        return agent_log.finish(JOB, root, "movie selftest\n" + "\n".join(bad or ["ok"]), "FAIL" if bad else "PASS", args=args, problems=len(bad))
    data = load(root)
    if args.list or not args.movie:
        rows = ["movie %s | %s | %s" % (n, m.get("scenario"), m.get("about", "")) for n, m in data["movies"].items()]
        rows += ["scenario %s | %s" % (n, s.get("about", "") or "%s@%s" % (s.get("flow"), s.get("state"))) for n, s in data["scenarios"].items()]
        rows += ["view %s | %s" % (n, v.get("about", "")) for n, v in data.get("views", {}).items()]
        rows += ["set %s | %s" % (n, ",".join(v)) for n, v in data.get("sets", {}).items()]
        print("\n".join(rows))
        return 0
    if args.refs:
        return refs_main(root, data, args)
    flow = compose(data, args.movie, root)
    game = Path(args.game).resolve() if args.game else root
    out = Path(args.out).resolve() if args.out else agent_log.ensure_agent_log_dir(JOB, root) / args.movie / (args.movie + ".mp4")
    if args.dry_run:
        print(json.dumps(flow, indent=1))
        return agent_log.finish(JOB, root, "", "INFO", args=args, write=False, movie=args.movie, game=game)
    work = out.parent
    work.mkdir(parents=True, exist_ok=True)
    (work / "movie-flow.json").write_text(json.dumps(flow, indent=1) + "\n", encoding="utf-8")
    raw = work / "raw"
    shutil.rmtree(raw, ignore_errors=True)
    raw.mkdir()
    ns = run_shots.build_parser().parse_args(["--steps", str(work / "movie-flow.json"), "--frames-dir", str(work), "--out", str(work / "end.png"),
                                              "--movie", str(raw / "f.png"), "--timeout-sec", str(args.timeout_sec)])
    res = run_shots.capture(ns, game, set())
    at = marks(res.get("lines", []))
    lines = ["movie %s scenario=%s game=%s" % (args.movie, data["movies"][args.movie].get("scenario"), game)] + res.get("lines", [])[-12:] + res.get("errors", [])[:5]
    if not res.get("ok") or "end" not in at:
        return agent_log.finish(JOB, root, "\n".join(lines), "FAIL", args=args, movie=args.movie, band=res.get("band"))
    first, n = cut(raw, at, int(flow["fixed_fps"]), out, (int(flow["width"]), int(flow["height"])))
    if not args.keep_raw:
        shutil.rmtree(raw)
    got = clip_edit.info(out)
    lines.append("frames %d..%d (%d) -> %s %s" % (first, first + n - 1, n, rel(root, out), json.dumps(got)))
    return agent_log.finish(JOB, root, "\n".join(lines), "PASS", args=args, movie=args.movie, out=rel(root, out), frames=n, sec=got["sec"], mb=got["mb"])

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
