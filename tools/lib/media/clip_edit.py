#!/usr/bin/env python3
"""Thin ffmpeg wrapper for gameplay clips: trim, crossfade-join, captions, side-by-side before/after, and X-sized export.

  python tools/media.py clip info IN
  python tools/media.py clip trim IN --start 1.5 --end 6 --out O.mp4
  python tools/media.py clip join A B [C ...] --fade 0.5 --out O.mp4          # crossfade each cut
  python tools/media.py clip caption IN --text "Roof shadows" [--start S --end E] [--pos top|bottom] --out O.mp4
  python tools/media.py clip sbs BEFORE AFTER [--labels Before,After] --out O.mp4   # shorter side holds its last frame
  python tools/media.py clip export IN --for x|gif [--width W] --out O               # X: H.264 <=1280x720, <=140 s, <=512 MB; GIF <=15 MB
  python tools/media.py clip --selftest                                          # synthetic clips through every op (ffmpeg only)

ffmpeg/ffprobe do the work; this file only builds the filter graphs and checks the X limits. Outputs default to
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

def join(srcs: list[Path], fade: float, out: Path) -> Path:
    """Crossfade each cut by `fade` s; clips are scaled to the first one's size and fps."""
    first = info(srcs[0])
    norm = "scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2,fps=%s,format=yuv420p,settb=AVTB" % (
        first["w"], first["h"], first["w"], first["h"], first["fps"])
    parts = ["[%d:v]%s[v%d]" % (i, norm, i) for i in range(len(srcs))]
    last, at = "v0", 0.0
    for i in range(1, len(srcs)):
        at += info(srcs[i - 1])["sec"] - fade
        parts.append("[%s][v%d]xfade=transition=fade:duration=%.3f:offset=%.3f[x%d]" % (last, i, fade, at, i))
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

def caption(src: Path, text: str, out: Path, start: float = 0.0, end: float = 0.0, pos: str = "bottom", font: str = "") -> Path:
    i = info(src)
    enable = "between(t,%.3f,%.3f)" % (start, end) if end > 0 else ""
    with tempfile.TemporaryDirectory() as td:
        _run(["-i", str(src), "-vf", _text(text, i["h"], pos, font, enable=enable, tmp=Path(td)), "-an", *H264, str(out)])
    return out

def sbs(before: Path, after: Path, out: Path, labels: tuple[str, str] = ("Before", "After"), font: str = "") -> Path:
    """Before | after at the before clip's height; the shorter clip holds its last frame; labels top-left of each half."""
    a, b = info(before), info(after)
    h = a["h"] - a["h"] % 2
    hold = [max(0.0, b["sec"] - a["sec"]), max(0.0, a["sec"] - b["sec"])]
    with tempfile.TemporaryDirectory() as td:
        legs = []
        for k, lab in enumerate(labels):
            legs.append("[%d:v]scale=-2:%d,fps=%s,tpad=stop_mode=clone:stop_duration=%.3f,%s[s%d]" % (
                k, h, a["fps"], hold[k], _text(lab, h, "top", font, x="w*0.03", tmp=Path(td)), k))
        _run(["-i", str(before), "-i", str(after), "-filter_complex", ";".join(legs) + ";[s0][s1]hstack=inputs=2[o]",
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
        x, xbad = export(t / "s.mp4", "x", t / "x.mp4")
        checks.append(("export-x", info(x), lambda i: i["w"] <= 1280 and i["h"] <= 720 and i["codec"] == "h264" and not xbad))
        g, gbad = export(a, "gif", t / "g.gif", 320)
        checks.append(("export-gif", info(g), lambda i: i["w"] == 320 and not gbad))
        for name, got, ok in checks:
            if not ok(got):
                bad.append("%s: %s" % (name, got))
    return bad

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Trim, join with crossfades, caption, side-by-side and X export of video clips (ffmpeg).", writes=False)
    ap.add_argument("op", nargs="?", choices=("info", "trim", "join", "caption", "sbs", "export"), help="what to do")
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
    need = {"info": 1, "trim": 1, "caption": 1, "export": 1, "sbs": 2, "join": 2}[args.op]
    if len(ins) < need or (args.op != "join" and len(ins) != need):
        agent_log.fail("%s takes %s input(s)" % (args.op, "2+" if args.op == "join" else need))
    problems: list[str] = []
    ext = ".gif" if args.op == "export" and args.kind == "gif" else ".mp4"
    out = None if args.op == "info" else _out(root, args.out, args.op + ext)
    if args.op == "trim":
        trim(ins[0], args.start, args.end, out)
    elif args.op == "join":
        join(ins, args.fade, out)
    elif args.op == "caption":
        caption(ins[0], args.text, out, args.start, args.end, args.pos, args.font)
    elif args.op == "sbs":
        labs = (args.labels.split(",") + ["", ""])[:2]
        sbs(ins[0], ins[1], out, (labs[0], labs[1]), args.font)
    elif args.op == "export":
        _, problems = export(ins[0], args.kind, out, args.width)
    got = info(out or ins[0])
    body = "clip %s\n%s %s\n%s" % (args.op, rel(root, (out or ins[0]).resolve()), json.dumps(got), "\n".join(problems))
    return agent_log.finish(JOB, root, body, "FAIL" if problems else "PASS", args=args, out=rel(root, (out or ins[0]).resolve()),
                            w=got["w"], h=got["h"], sec=got["sec"], mb=got["mb"], problems=len(problems))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
