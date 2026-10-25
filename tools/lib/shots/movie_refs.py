#!/usr/bin/env python3
"""shots.py movie --refs A,B NAMES: record the same catalog entries at two git refs and cut a before/after reel.

Per ref: a detached worktree in a temp dir (the editor cache .godot is seeded from this checkout), the current recording
tooling injected (INJECT: shot tool, shot_views; INJECT_MISSING only when the ref lacks it), `gate.py import` there, then
every name recorded with this checkout's tools: a movie as a clip, a view as a still (flow state, scenario or a stitched
full-map with overlays). Each pair is diffed: no change -> "no visible change" (left out of the reel); else a captioned
`clip ba` segment (zoom + wipe for small or subtle changes, side by side for strong wide ones). Outputs in --out
(default _logs/movie/refs-<A>-<B>-<NAMES>/, one per name list): reel.mp4, reel-x.mp4, reel.gif, contact.png (A | B | heat per change),
compare.json. Worktrees are removed afterwards (--keep-worktrees keeps them).
"""
from __future__ import annotations

import json
import random
import re
import string
import shutil
import subprocess
import tempfile
from pathlib import Path

import clip_edit
import clip_fx
import run_movie
import run_shots

INJECT = ("scripts/debug/shot_tool", "scripts/debug/shot_tool.gd", "scripts/debug/shot_views.gd")
INJECT_MISSING = ("scripts/debug/smoke.gd", "scripts/debug/dungeon_map", "scripts/debug/drop_stage.gd")
STILL_SHARE = 0.002  # a still pair differs when more than this share of pixels moved by over TOL levels
TOL = 16
CLIP_SHARE = 0.004  # a clip pair differs when change_box finds a patch over this share of the frame

def git(root: Path, *a: str) -> str:
    return subprocess.run(["git", "-C", str(root), *a], check=True, capture_output=True, text=True).stdout.strip()

def expand(data: dict, names: str) -> list[tuple[str, str]]:
    """Comma names (sets expand) -> [(name, movie|view)]."""
    out: list[tuple[str, str]] = []
    for n in [x for x in names.split(",") if x]:
        for m in data.get("sets", {}).get(n, [n]):
            kind = "movie" if m in data["movies"] else "view" if m in data.get("views", {}) else ""
            if not kind:
                raise SystemExit("no movie, view or set %r (have: %s)" % (m, ", ".join(sorted({*data["movies"], *data.get("views", {}), *data.get("sets", {})}))))
            if (m, kind) not in out:
                out.append((m, kind))
    return out

def _copy(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)

def inject(root: Path, wt: Path) -> list[str]:
    """Copy the recording tooling into the worktree; returns the paths written (relative)."""
    done: list[str] = []
    for rel_p, always in [(p, True) for p in INJECT] + [(p, False) for p in INJECT_MISSING]:
        src = root / rel_p
        files = [src] if src.is_file() else sorted(p for p in src.rglob("*") if p.is_file()) if src.is_dir() else []
        if not always and (wt / rel_p).exists():
            continue
        for f in files:
            d = wt / f.relative_to(root)
            if not d.is_file() or d.read_bytes() != f.read_bytes():
                _copy(f, d)
                done.append(str(f.relative_to(root)))
    tool = [f for r in INJECT + INJECT_MISSING for f in ([root / r] if (root / r).is_file() else (root / r).rglob("*.gd"))]
    return done + _deps(root, wt, tool)

def _deps(root: Path, wt: Path, todo: list[Path]) -> list[str]:
    """res:// scripts the injected files preload that the ref lacks (e.g. a newer helper), copied missing-only with a fresh
    .uid (a moved file keeps its old uid and would clash)."""
    out: list[str] = []
    while todo:
        f = todo.pop()
        if f.suffix != ".gd":
            continue
        for rel_p in re.findall(r'res://([\w/.-]+\.gd)\b', f.read_text(errors="replace")):
            src, d = root / rel_p, wt / rel_p
            if src.is_file() and not d.exists():
                _copy(src, d)
                d.with_name(d.name + ".uid").write_text("uid://%s\n" % "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(13)))
                out.append(rel_p)
                todo.append(src)
    return out

def worktree(root: Path, sha: str, base: Path) -> Path:
    wt = base / sha[:10]
    git(root, "worktree", "add", "--detach", str(wt), sha)
    if (root / ".godot").is_dir():
        shutil.copytree(root / ".godot", wt / ".godot", ignore=shutil.ignore_patterns("editor"), dirs_exist_ok=True)
    return wt

def drop_worktree(root: Path, wt: Path) -> None:
    subprocess.run(["git", "-C", str(root), "worktree", "remove", "--force", str(wt)], capture_output=True)
    shutil.rmtree(wt, ignore_errors=True)
    subprocess.run(["git", "-C", str(root), "worktree", "prune"], capture_output=True)

def gate_import(root: Path, wt: Path) -> str:
    r = subprocess.run(["python3", str(root / "tools/gate.py"), "import", "--root", str(wt), "--json", "--no-static"], capture_output=True, text=True)
    try:
        return str(json.loads(r.stdout.strip().splitlines()[-1]).get("status", "?"))
    except (ValueError, IndexError):
        return "rc=%d" % r.returncode

# Before every view still: pin wall-clock pulses (HUD danger gem) so they never count as a change.
STILL = [{"op": "call", "target": "script:debug/shot_views", "method": "still_hud"}, {"op": "wait", "ms": 100}]

def view_flow(root: Path, data: dict, name: str) -> dict:
    v = data["views"][name]
    sc = data["scenarios"][v["scenario"]] if v.get("scenario") else v
    base = run_movie.scenario_flow(root, sc)
    return {"about": "view %s: %s" % (name, v.get("about", "")), **{k: x for k, x in base.items() if k != "steps"},
            "steps": base["steps"] + list(v.get("steps", [])) + STILL + [{"op": "shot", "name": "view"}]}

def record(root: Path, data: dict, wt: Path, name: str, kind: str, out: Path) -> tuple[Path | None, str]:
    """One catalog entry at one worktree -> (file or None, note)."""
    out.mkdir(parents=True, exist_ok=True)
    if kind == "movie":
        mp4 = out / (name + ".mp4")
        rc = run_movie.main([name, "--game", str(wt), "--out", str(mp4)])
        return (mp4 if rc == 0 and mp4.is_file() else None), "rc=%d" % rc
    v = data["views"][name]
    png = out / (name + ".png")
    if v.get("kind") == "full-map":
        argv = ["--full-map", "--mode", "build", "--seed", str(v.get("seed", 42)), "--floor", str(v.get("floor", 1)),
                "--max-px", str(v.get("max_px", 4096)), "--overlays", ",".join(v.get("overlays", [])), "--out", str(png)]
    else:
        work = out / (name + "-flow")
        work.mkdir(exist_ok=True)
        (work / "flow.json").write_text(json.dumps(view_flow(root, data, name), indent=1), encoding="utf-8")
        argv = ["--steps", str(work / "flow.json"), "--frames-dir", str(work), "--mode", "build", "--scale", "100", "--out", str(png)]
    res = run_shots.capture(run_shots.build_parser().parse_args(argv), wt, set())
    return (png if res.get("ok") and png.is_file() else None), str(res.get("band", ""))

def still_diff(a: Path, b: Path) -> dict:
    from PIL import Image
    from imglib import compare
    Image.MAX_IMAGE_PIXELS = None
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    size_changed = ia.size != ib.size
    d = compare.delta_map(ia, ib.resize(ia.size))
    share = float((d > TOL).mean())
    return {"share": round(share, 4), "mean": round(float(d.mean()), 2), "size_changed": size_changed,
            "changed": share > STILL_SHARE or size_changed}

def clip_diff(a: Path, b: Path) -> dict:
    box, share, strength = clip_fx.change_box(a, b)
    return {"share": round(share, 4), "strength": strength, "box": [round(v) for v in box] if box else None,
            "changed": box is not None and share > CLIP_SHARE}

def still_clip(png: Path, out: Path, sec: float = 3.0) -> Path:
    clip_edit._run(["-loop", "1", "-t", "%.2f" % sec, "-i", str(png), "-vf",
                    "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,fps=30,format=yuv420p", "-an", *clip_edit.H264, str(out)])
    return out

def peak_frames(a: Path, b: Path, td: Path, samples: int = 8) -> tuple:
    """Frames of a and b where they differ most (for the contact sheet)."""
    from PIL import Image, ImageChops, ImageStat
    dur = min(clip_edit.info(a)["sec"], clip_edit.info(b)["sec"])
    best = (-1.0, None, None)
    for k in range(samples):
        t = dur * (k + 0.5) / samples
        clip_edit._run(["-ss", "%.3f" % t, "-i", str(a), "-frames:v", "1", str(td / ("pa%d.png" % k))])
        clip_edit._run(["-ss", "%.3f" % t, "-i", str(b), "-frames:v", "1", str(td / ("pb%d.png" % k))])
        x, y = Image.open(td / ("pa%d.png" % k)).convert("RGB"), Image.open(td / ("pb%d.png" % k)).convert("RGB")
        m = sum(ImageStat.Stat(ImageChops.difference(x, y.resize(x.size))).mean)
        if m > best[0]:
            best = (m, x, y)
    return best[1], best[2]

def short(text: str, n: int = 56) -> str:
    """One caption line that fits a 1280 px frame."""
    return text if len(text) <= n else text[:n].rsplit(" ", 1)[0].rstrip(",;:(") + "..."

def reel(rows: list[dict], labels: tuple[str, str], out: Path) -> dict:
    """Captioned ba segment per changed row -> reel.mp4, reel-x.mp4, reel.gif, contact.png."""
    from PIL import Image
    from imglib import compare
    Image.MAX_IMAGE_PIXELS = None
    segs, sheet, names = [], [], []
    with tempfile.TemporaryDirectory() as tdn:
        td = Path(tdn)
        for r in [r for r in rows if r.get("diff", {}).get("changed")]:
            a, b = Path(r["a"]), Path(r["b"])
            if r["kind"] == "view":
                ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
                a, b = still_clip(a, td / (r["name"] + "-a.mp4")), still_clip(b, td / (r["name"] + "-b.mp4"))
            else:
                ia, ib = peak_frames(a, b, td)
            seg = td / (r["name"] + "-ba.mp4")
            r["layout"] = clip_fx.ba(a, b, seg, labels=labels)["layout"]
            capt = td / (r["name"] + "-cap.mp4")
            clip_edit.caption(seg, short("%s: %s" % (r["name"], r["about"])), capt)
            segs.append(capt)
            for im in (ia, ib):
                im.thumbnail((960, 960))
            sheet += [ia, ib.resize(ia.size), compare.heatmap(ia, ib.resize(ia.size), tol=TOL)]
            names += ["%s %s" % (r["name"], labels[0]), "%s %s" % (r["name"], labels[1]), "%s change" % r["name"]]
        if not segs:
            return {"segments": 0}
        full = out / "reel.mp4"
        clip_edit.join(segs, 0.4, full) if len(segs) > 1 else shutil.copy2(segs[0], full)
    xs, px = clip_edit.export(full, "x", out / "reel-x.mp4")
    for w in (640, 480, 360):  # X caps a GIF at 15 MB: shrink until it fits
        gs, pg = clip_edit.export(full, "gif", out / "reel.gif", width=w)
        if not any("MB" in p for p in pg):
            break
    compare.montage(sheet, labels=names, cols=3).save(out / "contact.png")
    return {"segments": len(segs), "reel": str(full), "x": str(xs), "gif": str(gs), "contact": str(out / "contact.png"), "limits": px + pg}

def run(root: Path, data: dict, refs: str, names: str, out: Path, keep: bool, log) -> dict:
    """The whole compare; log(str) reports progress. Returns the compare.json dict."""
    ra, rb = [x.strip() for x in refs.split(",")]
    items = expand(data, names)
    shas = [git(root, "rev-parse", "--verify", r + "^{commit}") for r in (ra, rb)]
    labels = (ra, rb)
    out.mkdir(parents=True, exist_ok=True)
    base = Path(tempfile.mkdtemp(prefix="wdb-refs-"))
    res: dict = {"refs": dict(zip(labels, shas)), "items": [], "import": {}, "injected": {}}
    wts: list[Path] = []
    try:
        for lab, sha in zip(labels, shas):
            wt = worktree(root, sha, base)
            wts.append(wt)
            res["injected"][lab] = inject(root, wt)
            res["import"][lab] = gate_import(root, wt)
            log("%s %s: worktree %s, injected %d files, import %s" % (lab, sha[:10], wt, len(res["injected"][lab]), res["import"][lab]))
            for name, kind in items:
                got, note = record(root, data, wt, name, kind, out / lab.replace("/", "_"))
                log("  %s %s %s -> %s (%s)" % (lab, kind, name, got or "FAILED", note))
                row = next((r for r in res["items"] if r["name"] == name), None)
                if row is None:
                    about = (data["movies"].get(name) or data["views"].get(name, {})).get("about", "")
                    row = {"name": name, "kind": kind, "about": about}
                    res["items"].append(row)
                row["a" if lab == labels[0] else "b"] = str(got) if got else None
        for r in res["items"]:
            if r.get("a") and r.get("b"):
                r["diff"] = clip_diff(Path(r["a"]), Path(r["b"])) if r["kind"] == "movie" else still_diff(Path(r["a"]), Path(r["b"]))
                log("%-18s %s %s" % (r["name"], "CHANGED" if r["diff"]["changed"] else "no visible change", json.dumps(r["diff"])))
            else:
                log("%-18s not compared (a recording failed)" % r["name"])
        res["reel"] = reel(res["items"], labels, out)
    finally:
        if not keep:
            for wt in wts:
                drop_worktree(root, wt)
            shutil.rmtree(base, ignore_errors=True)
    (out / "compare.json").write_text(json.dumps(res, indent=1) + "\n", encoding="utf-8")
    return res

def selftest(root: Path) -> list[str]:
    """Catalog entries resolve and compose; worktree + injection + cleanup on HEAD; still diff and reel on synthetic pairs."""
    from PIL import Image, ImageDraw
    bad: list[str] = []
    data = run_movie.load(root)
    for s in data.get("sets", {}):
        try:
            for n, k in expand(data, s):
                if k == "view" and data["views"][n].get("kind") != "full-map" and view_flow(root, data, n)["steps"][-3:-1] != STILL:
                    bad.append("view %s: no still_hud pin before its shot" % n)
        except (SystemExit, KeyError) as exc:
            bad.append("set %s: %s" % (s, exc))
    with tempfile.TemporaryDirectory() as tdn:
        td = Path(tdn)
        wt = worktree(root, git(root, "rev-parse", "HEAD"), td)
        (wt / "scripts/debug/shot_views.gd").unlink(missing_ok=True)
        shutil.rmtree(wt / "scripts/debug/dungeon_map", ignore_errors=True)
        cli = "scripts/app/cli_args.gd"
        for p in (wt / cli, wt / (cli + ".uid")):
            p.unlink(missing_ok=True)
        got = inject(root, wt)
        if "scripts/debug/shot_views.gd" not in got or not any(g.startswith("scripts/debug/dungeon_map/") for g in got):
            bad.append("inject missed files: %s" % got[:5])
        if cli not in got or (wt / (cli + ".uid")).read_text() == (root / (cli + ".uid")).read_text():
            bad.append("missing preload dep %s not copied with a fresh uid" % cli)
        drop_worktree(root, wt)
        if wt.exists() or str(wt) in git(root, "worktree", "list"):
            bad.append("worktree not cleaned up")
        imgs = []
        for k in range(3):
            im = Image.new("RGB", (320, 180), (20, 20, 30))
            if k == 2:
                ImageDraw.Draw(im).rectangle((200, 20, 300, 120), fill=(240, 200, 40))
            im.save(td / ("s%d.png" % k))
            imgs.append(td / ("s%d.png" % k))
        if still_diff(imgs[0], imgs[1])["changed"] or not still_diff(imgs[0], imgs[2])["changed"]:
            bad.append("still diff threshold")
        rows = [{"name": "same", "kind": "view", "about": "x", "a": str(imgs[0]), "b": str(imgs[1]), "diff": still_diff(imgs[0], imgs[1])},
                {"name": "box", "kind": "view", "about": "a box appears", "a": str(imgs[0]), "b": str(imgs[2]), "diff": still_diff(imgs[0], imgs[2])}]
        r = reel(rows, ("A", "B"), td)
        if r.get("segments") != 1 or not (td / "reel-x.mp4").is_file() or not (td / "contact.png").is_file():
            bad.append("reel %s" % r)
        if short("x " * 40).__len__() > 59 or short("short") != "short":
            bad.append("caption cut")
        if reel(rows[:1], ("A", "B"), td / "none").get("segments") != 0:
            bad.append("no-change reel not empty")
    return bad
