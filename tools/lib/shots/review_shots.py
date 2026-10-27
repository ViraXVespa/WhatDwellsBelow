#!/usr/bin/env python3
"""Offload shot review to an isolated Grok session; print only its text report.

Use when the main session does not need the image itself (a pass/fail look, a
rubric check, a before/after diff). The PNGs are copied into a scratch dir
outside the repo, the run_isolated_grok isolation gate (`grok inspect`: no
project instructions) must pass, a fresh child session answers the question
and writes report.md, and only that text comes back. Any failure (grok
missing, isolation not proven, child error, no report) is RESULT FAIL; there is
no placeholder verdict. Use shots.py show instead when you need the image.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log  # noqa: E402
import run_isolated_grok as iso  # noqa: E402

REPORT = "report.md"
MAX_REPORT = 6000

def turn_budget(n_images: int, requested: int) -> int:
    """Turns for one read of each image plus the report. A low --max-turns still rises with the image count."""
    auto = min(16, max(8, 2 + 2 * max(n_images, 1)))
    if requested <= 0:
        return auto
    return max(requested, auto)

def build_job(names: list[str], question: str, rubric: str) -> str:
    lines = ["# Shot review (isolated)", "",
             "You review game screenshots. The developer will not see the images, only your report.",
             "The files are in this directory. They are real screenshots.",
             "Call read_file once on each file. That call shows you the picture. Trust it.",
             "Do not run a terminal command, Python, OCR, or a crop. Do not re-read a file.",
             "Do not walk any other directory. Do not generate or edit images.", "",
             "Files: " + ", ".join(f"`{n}`" for n in names), "", f"Question: {question}"]
    if rubric:
        lines += ["", "Rubric (check each item):", rubric]
    lines += ["", f"Then write `{REPORT}` in this directory with the write tool, plain text, under 400 words.",
              "One section per file: what is visible, and the answer for that file.",
              "Last line exactly `VERDICT: PASS`, `VERDICT: FAIL`, or `VERDICT: UNSURE`.",
              "Use UNSURE when the question asks for a description rather than a pass or fail.",
              "Write the file in the same turn you finish looking. Then stop."]
    return "\n".join(lines) + "\n"

def fail(why: str) -> int:
    print(f"REVIEW FAILED: {why}")
    return agent_log.emit_result("FAIL", reason=why)

def review(paths: list[Path], question: str, rubric: str, grok: str, max_turns: int) -> int:
    missing = [str(p) for p in paths if not p.is_file()]
    if missing:
        return fail("missing " + ", ".join(missing))
    if iso._which_grok(grok) is None:
        return fail(f"grok not on PATH ({grok}); isolated review cannot run")
    with tempfile.TemporaryDirectory(prefix="wdb-review-") as tmp:
        scratch = Path(tmp).resolve()
        names = []
        for i, p in enumerate(paths):  # numbered: before/after shots often share a name
            name = f"{i + 1:02d}-{p.name}"
            shutil.copy2(p, scratch / name)
            names.append(name)
        job = scratch / "job.md"
        iso.write_job(job, build_job(names, question, rubric))
        try:
            ins = subprocess.run([grok, "inspect"], cwd=scratch, text=True, capture_output=True, check=False)
        except OSError as e:
            return fail(f"grok inspect: {e}")
        text = (ins.stdout or "") + "\n" + (ins.stderr or "")
        n = iso.inspect_instruction_count(text)
        if ins.returncode != 0 or iso.inspect_mentions_repo_agents(text) or n != 0:
            return fail(f"isolation not proven (inspect exit {ins.returncode}, project instructions {n})")
        budget = turn_budget(len(paths), max_turns)
        argv = iso.grok_child_argv(grok, job, scratch, budget)
        child = subprocess.run(argv, cwd=scratch, text=True, capture_output=True, check=False)
        if child.returncode != 0:
            err = (child.stderr or "").strip()
            if err:
                sys.stderr.write(err[-1500:] + "\n")
            why = f"isolated session exited {child.returncode}"
            if "max turns" in err.lower():
                why += f" (turn budget {budget} spent before {REPORT}; {len(paths)} image(s))"
            return fail(why)
        rep = scratch / REPORT
        if not rep.is_file() or not rep.read_text(encoding="utf-8").strip():
            return fail(f"isolated session wrote no {REPORT}")
        body = rep.read_text(encoding="utf-8").strip()[:MAX_REPORT]
    verdict = next((ln.split(":", 1)[1].strip().upper() for ln in reversed(body.splitlines())
                    if ln.strip().upper().startswith("VERDICT:")), "")
    print("REVIEW_SHOTS (isolated)\n" + body)
    if verdict not in ("PASS", "FAIL", "UNSURE"):
        return fail("report has no VERDICT line")
    return agent_log.emit_result("PASS", verdict=verdict, files=len(paths))

FAKE = """#!/usr/bin/env python3
import os, sys
mode = os.environ.get("FAKE_MODE", "ok")
if sys.argv[1:2] == ["inspect"]:
    print("Project Instructions (%s)" % ("2" if mode == "leak" else "none")); sys.exit(0)
if mode == "crash":
    sys.exit(4)
if mode != "silent":
    job = open(sys.argv[sys.argv.index("--prompt-file") + 1]).read()
    assert "01-a.png" in job and "Rubric" in job
    open("report.md", "w").write("01-a.png: panel visible.\\nVERDICT: PASS\\n")
"""

def selftest() -> int:
    bad = []
    sample = build_job(["01-a.png"], "Is the panel visible?", "- panel")
    if "Do not run a terminal" not in sample or "VERDICT: UNSURE" not in sample or "01-a.png" not in sample:
        bad.append("prompt")
    if turn_budget(3, 6) != 8 or turn_budget(1, 6) != 8 or turn_budget(3, 20) != 20 or turn_budget(12, 0) != 16:
        bad.append("budget")
    with tempfile.TemporaryDirectory(prefix="wdb-review-st-") as tmp:
        t = Path(tmp)
        script = t / ("grok_fake.py" if os.name == "nt" else "grok")
        script.write_text(FAKE, encoding="utf-8")
        script.chmod(0o755)
        if os.name == "nt":
            launcher = t / "grok.cmd"
            launcher.write_text(f'@"{sys.executable}" "{script}" %*\r\n', encoding="utf-8")
            grok_bin = str(launcher)
        else:
            grok_bin = str(script)
        png = t / "a.png"
        png.write_bytes(b"\x89PNG\r\n\x1a\n")
        me = [*boot.cmd("review_shots")]
        cases = [("ok", grok_bin, 0, "VERDICT: PASS"), ("leak", grok_bin, 1, "isolation not proven"),
                 ("crash", grok_bin, 1, "exited 4"), ("silent", grok_bin, 1, "no report.md"),
                 ("ok", str(t / "nogrok"), 1, "not on PATH")]
        for mode, grok, want, needle in cases:
            env = dict(os.environ, FAKE_MODE=mode)
            r = subprocess.run(me + [str(png), "--question", "Is the panel visible?", "--rubric", "- panel",
                                     "--grok", grok], text=True, capture_output=True, env=env)
            out = r.stdout + r.stderr
            ok = (r.returncode == 0) == (want == 0) and needle in out and ("PLACEHOLDER" not in out)
            print(f"{'ok ' if ok else 'BAD'} {mode} grok={Path(grok).name} exit={r.returncode}")
            if not ok:
                bad.append(mode)
                print(out[-400:].replace("\n", " | "))
    return agent_log.emit_result("PASS" if not bad else "FAIL", cmd="selftest", problems=len(bad))

def main() -> int:
    ap = agent_log.std_parser("Offload shot review to an isolated Grok session; print only the text report (FAIL if isolation cannot run).")
    ap.add_argument("paths", nargs="*", help="PNG paths to review")
    ap.add_argument("--question", default="", help="What to answer about the shots (required)")
    ap.add_argument("--rubric", default="", help="Checklist text, or @FILE to read it from a file")
    ap.add_argument("--grok", default="grok", help="Grok Build executable (default: grok)")
    ap.add_argument("--max-turns", type=int, default=6, help="Max child turns. The run rises with the image count (at least 8, +2 per image, cap 16) when this is lower.")
    ap.add_argument("--selftest", action="store_true", help="Run against a mock grok; no Grok needed")
    args = ap.parse_args()
    root = agent_log.resolve_root(args)
    if args.selftest:
        return selftest()
    if not args.paths or not args.question.strip():
        return fail("give PNG paths and --question")
    rubric = args.rubric
    if rubric.startswith("@"):
        rubric = Path(rubric[1:]).read_text(encoding="utf-8")
    paths = [Path(p) if Path(p).is_absolute() or not (root / p).exists() else root / p for p in args.paths]
    return review(paths, args.question.strip(), rubric.strip(), args.grok, args.max_turns)

if __name__ == "__main__":
    sys.exit(main())
