#!/usr/bin/env python3
"""Thin ffmpeg wrapper for gameplay clips: trim, crossfade-join, captions, side-by-side before/after, and X-sized export.

  python tools/media.py clip info IN
  python tools/media.py clip trim IN --start 1.5 --end 6 --out O.mp4
  python tools/media.py clip join A B [C ...] --fade 0.5 --out O.mp4          # crossfade each cut
  python tools/media.py clip caption IN --text "Roof shadows" [--start S --end E] [--pos top|bottom] --out O.mp4
  python tools/media.py clip sbs BEFORE AFTER [--labels Before,After] --out O.mp4   # shorter side holds its last frame
  python tools/media.py clip export IN --for x|gif [--width W] --out O               # X: H.264 <=1280x720, <=140 s, <=512 MB; GIF <=15 MB
  python tools/media.py clip crop IN --box X,Y,W,H|--region NAME [--movie M] [--size x|WxH] --out O.mp4   # static crop
  python tools/media.py clip zoom IN --box FROM --to TO [--start S --end E] [--size x] --out O.mp4        # Ken Burns
  python tools/media.py clip fit IN --size x|x-square|x-portrait|WxH [--fill pad|crop|blur] --out O.mp4
  python tools/media.py clip join A B --transition wipeleft|slideup|dissolve|...          # any xfade transition
  python tools/media.py clip sbs BEFORE AFTER --stack v                                    # before over after
  python tools/media.py clip wipe BEFORE AFTER [--hold 0.6 --sweep 1.6 --once] --out O.mp4  # slider reveal line
  python tools/media.py clip pip MAIN INSET [--corner tr --scale 0.33 --start S --end E] --out O.mp4
  python tools/media.py clip mark IN --box X,Y,W,H [--box ...] [--no-arrows] [--start S --end E] --out O.mp4
  python tools/media.py clip caption IN --cue 0,2,"First" --cue 2.5,5,"Second" --out O.mp4      # timed captions
  python tools/media.py clip ba BEFORE AFTER [--layout auto|wipe|sbs|stack] [--box B] --out O.mp4  # auto zoom + wipe
  python tools/media.py clip --selftest                                          # synthetic clips through every op (ffmpeg only)

ffmpeg/ffprobe do the work; this file only builds the filter graphs and checks the X limits (framing, transitions and
overlays: clip_fx.py). Outputs default to
_logs/clip/ (git-ignored); videos are never committed. Captions use --font, else fontconfig's sans.
Importable: info(), encode_seq(), trim(), join(), caption(), sbs(), export() (shots.py movie uses them).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import boot  # noqa: E402,F401

import agent_log
from agent_log import rel

import clip_fx  # noqa: E402  (imports this module back; only its functions are used, at call time)

JOB = "clip"
X_MAX = {"w": 1280, "h": 720, "sec": 140.0, "mb": 512.0, "gif_mb": 15.0}
H264 = ["-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart"]

def _run(cmd: list[str]) -> None:
    p = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *cmd], capture_output=True, text=True)
    if p.returncode != 0:
        raise SystemExit("ffmpeg failed: " + (p.stderr.strip().splitlines() or ["?"])[-1])

def info(path: Path) -> dict:
    """{w, h, fps, sec, mb, codec} of the first video stream."""
    p = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                        "stream=width,height,r_frame_rate,codec_name,nb_frames:format=duration,size", "-of", "json", str(path)],
                       capture_output=True, text=True)
    if p.returncode != 0:
        raise SystemExit("ffprobe failed on %s" % path)
    d = json.loads(p.stdout)
    st, fm = d["streams"][0], d["format"]
    num, den = (st.get("r_frame_rate") or "0/1").split("/")
    return {"w": int(st["width"]), "h": int(st["height"]), "fps": round(int(num) / max(1, int(den)), 2),
            "sec": round(float(fm.get("duration", 0)), 2), "mb": round(int(fm.get("size", 0)) / 1048576, 2), "codec": st.get("codec_name", "")}

def encode_seq(pattern: Path, fps: int, start: int, count: int, out: Path, size: tuple[int, int] = (0, 0)) -> Path:
    """PNG sequence (printf `pattern`, first index `start`, `count` frames) -> H.264 MP4, fitted into `size` when given."""
    fit = "scale=%d:%d:force_original_aspect_ratio=decrease:flags=lanczos," % size if size[0] > 0 and size[1] > 0 else ""
    _run(["-framerate", str(fps), "-start_number", str(start), "-i", str(pattern), "-frames:v", str(count),
          "-vf", fit + "pad=ceil(iw/2)*2:ceil(ih/2)*2", *H264, str(out)])
    return out

def trim(src: Path, start: float, end: float, out: Path) -> Path:
    _run(["-i", str(src), "-ss", "%.3f" % start, *(["-to", "%.3f" % end] if end > 0 else []), "-an", *H264, str(out)])
    return out

def join(srcs: list[Path], fade: float, out: Path, transition: str = "fade") -> Path:
    """Cross each cut by `fade` s with an xfade transition (clip_fx.TRANSITIONS); clips take the first one's size and fps."""
    first = info(srcs[0])
    norm = "scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2,fps=%s,format=yuv420p,settb=AVTB" % (
        first["w"], first["h"], first["w"], first["h"], first["fps"])
    parts = ["[%d:v]%s[v%d]" % (i, norm, i) for i in range(len(srcs))]
    last, at = "v0", 0.0
    for i in range(1, len(srcs)):
        at += info(srcs[i - 1])["sec"] - fade
        parts.append("[%s][v%d]xfade=transition=%s:duration=%.3f:offset=%.3f[x%d]" % (last, i, transition, fade, at, i))
        last = "x%d" % i
    cmd = [a for s in srcs for a in ("-i", str(s))]
    _run([*cmd, "-filter_complex", ";".join(parts), "-map", "[%s]" % last, "-an", *H264, str(out)])
    return out

def _font(font: str) -> str:
    if font:
        return font
    p = subprocess.run(["fc-match", "-f", "%{file}", "sans"], capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else ""

def _text(text: str, h: int, pos: str, font: str, x: str = "(w-text_w)/2", enable: str = "", tmp: Path | None = None) -> str:
    """drawtext over a dark box; the text goes through a file so quotes and colons need no escaping."""
    tf = (tmp or Path(tempfile.mkdtemp())) / ("cap%d.txt" % abs(hash((text, x))))
    tf.write_text(text, encoding="utf-8")
    size = max(14, h // 18)
    y = "h*0.05" if pos == "top" else "h-text_h-h*0.06"
    ff = _font(font)
    return "drawtext=textfile='%s':%sfontsize=%d:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=%d:x=%s:y=%s%s" % (
        tf, ("fontfile='%s':" % ff) if ff else "", size, size // 3, x, y, (":enable='%s'" % enable) if enable else "")

def caption(src: Path, text: str, out: Path, start: float = 0.0, end: float = 0.0, pos: str = "bottom", font: str = "",
            cues: list | None = None) -> Path:
    """One caption (text, start, end) or timed cues [(start, end, text), ...] (end 0 = to the end of the clip)."""
    i = info(src)
    cues = cues or [(start, end, text)]
    with tempfile.TemporaryDirectory() as td:
        vf = ",".join(_text(c[2], i["h"], pos, font, enable=("between(t,%.3f,%.3f)" % (c[0], c[1])) if c[1] > 0 else "", tmp=Path(td)) for c in cues)
        _run(["-i", str(src), "-vf", vf, "-an", *H264, str(out)])
    return out

def sbs(before: Path, after: Path, out: Path, labels: tuple[str, str] = ("Before", "After"), font: str = "", stack: str = "h") -> Path:
    """Before | after at the before clip's height (stack v: before over after at its width); the shorter clip holds its
    last frame; labels top-left of each part."""
    a, b = info(before), info(after)
    h = a["h"] - a["h"] % 2
    fitk = "scale=-2:%d" % h if stack != "v" else "scale=%d:-2" % (a["w"] - a["w"] % 2)
    hold = [max(0.0, b["sec"] - a["sec"]), max(0.0, a["sec"] - b["sec"])]
    with tempfile.TemporaryDirectory() as td:
        legs = []
        for k, lab in enumerate(labels):
            legs.append("[%d:v]%s,fps=%s,tpad=stop_mode=clone:stop_duration=%.3f,%s[s%d]" % (
                k, fitk, a["fps"], hold[k], _text(lab, h, "top", font, x="w*0.03", tmp=Path(td)), k))
        _run(["-i", str(before), "-i", str(after), "-filter_complex", ";".join(legs) + ";[s0][s1]%s=inputs=2[o]" % ("vstack" if stack == "v" else "hstack"),
              "-map", "[o]", "-an", *H264, str(out)])
    return out

def export(src: Path, kind: str, out: Path, width: int = 0) -> tuple[Path, list[str]]:
    """X-ready copy: MP4 (H.264, fits 1280x720, <=60 fps) or GIF (palette, 15 fps). Returns (out, limit problems)."""
    i = info(src)
    if kind == "gif":
        w = width or min(640, i["w"])
        _run(["-i", str(src), "-vf", "fps=15,scale=%d:-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];"
              "[b][p]paletteuse=dither=bayer:bayer_scale=5" % w, str(out)])
    else:
        w = width or X_MAX["w"]
        _run(["-i", str(src), "-vf", "scale='min(%d,iw)':'min(%d,ih)':force_original_aspect_ratio=decrease,"
              "pad=ceil(iw/2)*2:ceil(ih/2)*2,fps='min(60,source_fps)'" % (w, X_MAX["h"]), "-an", *H264, str(out)])
    o = info(out) if kind != "gif" else {**info(out), "mb": round(out.stat().st_size / 1048576, 2)}
    bad = []
    if o["sec"] > X_MAX["sec"]:
        bad.append("longer than %d s" % X_MAX["sec"])
    if o["mb"] > (X_MAX["gif_mb"] if kind == "gif" else X_MAX["mb"]):
        bad.append("%.1f MB over the X limit" % o["mb"])
    return out, bad

def _out(root: Path, given: str, stem: str) -> Path:
    p = Path(given) if given else agent_log.ensure_agent_log_dir(JOB, root) / stem
    p.parent.mkdir(parents=True, exist_ok=True)
    return p

def selftest(root: Path) -> list[str]:
    """Every op on two synthetic 2 s testsrc clips; checks sizes, durations and the X fit."""
    bad: list[str] = []
    with tempfile.TemporaryDirectory() as td:
        t = Path(td)
        for n, src in (("a", "testsrc2"), ("b", "smptebars")):
            _run(["-f", "lavfi", "-i", "%s=size=1920x1080:rate=30:duration=2" % src, *H264, str(t / (n + ".mp4"))])
        a, b = t / "a.mp4", t / "b.mp4"
        checks = [
            ("trim", info(trim(a, 0.5, 1.5, t / "t.mp4")), lambda i: abs(i["sec"] - 1.0) < 0.15),
            ("join", info(join([a, b], 0.5, t / "j.mp4")), lambda i: abs(i["sec"] - 3.5) < 0.15),
            ("caption", info(caption(a, "Roof: shadows 'on'", t / "c.mp4", 0.2, 1.5)), lambda i: abs(i["sec"] - 2.0) < 0.15),
            ("sbs", info(sbs(a, trim(b, 0, 1.0, t / "b1.mp4"), t / "s.mp4")), lambda i: i["w"] == 3840 and abs(i["sec"] - 2.0) < 0.15),
        ]
        import clip_fx
        bad += clip_fx.selftest(t)
        x, xbad = export(t / "s.mp4", "x", t / "x.mp4")
        checks.append(("export-x", info(x), lambda i: i["w"] <= 1280 and i["h"] <= 720 and i["codec"] == "h264" and not xbad))
        g, gbad = export(a, "gif", t / "g.gif", 320)
        checks.append(("export-gif", info(g), lambda i: i["w"] == 320 and not gbad))
        for name, got, ok in checks:
            if not ok(got):
                bad.append("%s: %s" % (name, got))
    return bad

OPS = ("info", "trim", "join", "caption", "sbs", "export", "crop", "zoom", "fit", "wipe", "pip", "mark", "ba")

def _fx(args, ins: list[Path], out: Path, root: Path) -> list[str]:
    """crop, zoom, fit, wipe, pip, mark, ba (clip_fx)."""
    i = info(ins[0])
    size = clip_fx.size_of(args.size) if args.size else (0, 0)
    boxes = [clip_fx.box_px(b, i["w"], i["h"], root, args.movie) for b in args.box]
    labs = tuple((args.labels.split(",") + ["", ""])[:2])
    if args.op in ("crop", "zoom", "mark") and not boxes:
        agent_log.fail("%s needs --box" % args.op)
    if args.op == "crop":
        clip_fx.crop(ins[0], boxes[0], out, size)
    elif args.op == "zoom":
        to = clip_fx.box_px(args.to, i["w"], i["h"], root, args.movie) if args.to else boxes[0]
        clip_fx.zoom(ins[0], boxes[0], to, out, size, args.start, max(0.0, args.end - args.start))
    elif args.op == "fit":
        clip_fx.fit(ins[0], size or clip_fx.SIZES["x"], out, args.fill)
    elif args.op == "wipe":
        clip_fx.wipe(ins[0], ins[1], out, labs, args.hold, args.sweep, not args.once, font=args.font)
    elif args.op == "pip":
        clip_fx.pip(ins[0], ins[1], out, args.corner, args.scale, args.start, args.end)
    elif args.op == "mark":
        clip_fx.mark(ins[0], boxes, out, not args.no_arrows, args.start, args.end, args.color)
    elif args.op == "ba":
        pick = clip_fx.ba(ins[0], ins[1], out, boxes[0] if boxes else None, args.layout, labs, font=args.font)
        print("ba pick: %s" % json.dumps(pick))
    return []

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Trim, join with crossfades, caption, side-by-side and X export of video clips (ffmpeg).", writes=False)
    ap.add_argument("op", nargs="?", choices=OPS, help="what to do")
    ap.add_argument("inputs", nargs="*", help="input clip(s)")
    ap.add_argument("--out", default="", help="output path (default _logs/clip/<op>.<ext>)")
    ap.add_argument("--start", type=float, default=0.0, help="trim / caption start seconds")
    ap.add_argument("--end", type=float, default=0.0, help="trim / caption end seconds (0 = to the end)")
    ap.add_argument("--fade", type=float, default=0.5, help="join: crossfade seconds")
    ap.add_argument("--text", default="", help="caption text")
    ap.add_argument("--pos", choices=("top", "bottom"), default="bottom", help="caption position")
    ap.add_argument("--labels", default="Before,After", help="sbs: the two labels, comma separated")
    ap.add_argument("--font", default="", help="caption font file (default fontconfig sans)")
    ap.add_argument("--for", dest="kind", choices=("x", "gif"), default="x", help="export target")
    ap.add_argument("--width", type=int, default=0, help="export width (x: max 1280; gif: default 640)")
    ap.add_argument("--box", action="append", default=[], help="crop/zoom/mark/ba: X,Y,W,H in px or fractions, or a region name (mark: repeat)")
    ap.add_argument("--to", default="", help="zoom: end box (the view eases from --box to --to)")
    ap.add_argument("--movie", default="", help="movie in tools/data/movies.json whose regions --box names")
    ap.add_argument("--size", default="", help="crop/zoom/fit/export: x, x-square, x-portrait or WxH")
    ap.add_argument("--fill", choices=("pad", "crop", "blur"), default="pad", help="fit/export --size: how a different aspect is filled")
    ap.add_argument("--transition", choices=clip_fx.TRANSITIONS, default="fade", help="join: xfade transition")
    ap.add_argument("--stack", choices=("h", "v"), default="h", help="sbs: h side by side, v before over after")
    ap.add_argument("--hold", type=float, default=0.6, help="wipe: seconds on before before the sweep")
    ap.add_argument("--sweep", type=float, default=1.6, help="wipe: seconds per sweep")
    ap.add_argument("--once", action="store_true", help="wipe: sweep once (no sweep back)")
    ap.add_argument("--corner", choices=("tl", "tr", "bl", "br"), default="tr", help="pip corner")
    ap.add_argument("--scale", type=float, default=0.33, help="pip inset width share")
    ap.add_argument("--color", default="#ffd23f", help="mark colour")
    ap.add_argument("--no-arrows", action="store_true", help="mark: boxes only")
    ap.add_argument("--cue", action="append", default=[], help="caption: START,END,TEXT (repeat; END 0 = to the end)")
    ap.add_argument("--layout", choices=("auto", "wipe", "sbs", "stack"), default="auto", help="ba layout (auto: zoom + wipe for a small change)")
    ap.add_argument("--selftest", action="store_true", help="run every op on synthetic clips")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    if shutil.which("ffmpeg") is None:
        agent_log.fail("ffmpeg not on PATH")
    if args.selftest:
        bad = selftest(root)
        return agent_log.finish(JOB, root, "clip selftest\n" + "\n".join(bad or ["ok"]), "FAIL" if bad else "PASS", args=args, problems=len(bad))
    if not args.op:
        ap.print_help()
        return 2
    ins = [Path(p) for p in args.inputs]
    need = {"sbs": 2, "join": 2, "wipe": 2, "pip": 2, "ba": 2}.get(args.op, 1)
    if len(ins) < need or (args.op != "join" and len(ins) != need):
        agent_log.fail("%s takes %s input(s)" % (args.op, "2+" if args.op == "join" else need))
    problems: list[str] = []
    ext = ".gif" if args.op == "export" and args.kind == "gif" else ".mp4"
    out = None if args.op == "info" else _out(root, args.out, args.op + ext)
    if args.op == "trim":
        trim(ins[0], args.start, args.end, out)
    elif args.op == "join":
        join(ins, args.fade, out, args.transition)
    elif args.op == "caption":
        cues = [(float(c.split(",", 2)[0]), float(c.split(",", 2)[1]), c.split(",", 2)[2]) for c in args.cue]
        caption(ins[0], args.text, out, args.start, args.end, args.pos, args.font, cues)
    elif args.op == "sbs":
        labs = (args.labels.split(",") + ["", ""])[:2]
        sbs(ins[0], ins[1], out, (labs[0], labs[1]), args.font, args.stack)
    elif args.op == "export":
        src = ins[0]
        if args.size:
            src = clip_fx.fit(src, clip_fx.size_of(args.size), out.with_suffix(".fit.mp4"), args.fill)
        _, problems = export(src, args.kind, out, args.width)
        if src != ins[0]:
            src.unlink()
    else:
        problems = _fx(args, ins, out, root)
    got = info(out or ins[0])
    body = "clip %s\n%s %s\n%s" % (args.op, rel(root, (out or ins[0]).resolve()), json.dumps(got), "\n".join(problems))
    return agent_log.finish(JOB, root, body, "FAIL" if problems else "PASS", args=args, out=rel(root, (out or ins[0]).resolve()),
                            w=got["w"], h=got["h"], sec=got["sec"], mb=got["mb"], problems=len(problems))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
