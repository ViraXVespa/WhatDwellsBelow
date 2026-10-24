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

def build_job(names: list[str], question: str, rubric: str) -> str:
    lines = ["# Shot review (isolated)", "",
             "You review game screenshots for a developer who will NOT see them. Look at each file below.",
             "Answer only from what is visible. Do not generate or edit images. Do not walk a parent repo.", "",
             "Files: " + ", ".join(f"`{n}`" for n in names), "", f"Question: {question}"]
    if rubric:
        lines += ["", "Rubric (check each item):", rubric]
    lines += ["", f"Write `{REPORT}` in this directory, plain text, under 400 words:",
              "one section per file (what is visible, defects, the answer for that file), then a last line",
              "exactly `VERDICT: PASS`, `VERDICT: FAIL` or `VERDICT: UNSURE`. Then stop."]
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
        argv = iso.grok_child_argv(grok, job, scratch, max_turns)
        child = subprocess.run(argv, cwd=scratch, text=True, capture_output=True, check=False)
        if child.returncode != 0:
            sys.stderr.write((child.stderr or "")[-1500:])
            return fail(f"isolated session exited {child.returncode}")
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
    with tempfile.TemporaryDirectory(prefix="wdb-review-st-") as tmp:
        t = Path(tmp)
        fake = t / "grok"
        fake.write_text(FAKE, encoding="utf-8")
        fake.chmod(0o755)
        png = t / "a.png"
        png.write_bytes(b"\x89PNG\r\n\x1a\n")
        me = [*boot.cmd("review_shots")]
        cases = [("ok", str(fake), 0, "VERDICT: PASS"), ("leak", str(fake), 1, "isolation not proven"),
                 ("crash", str(fake), 1, "exited 4"), ("silent", str(fake), 1, "no report.md"),
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
    return agent_log.emit_result("PASS" if not bad else "FAIL", cmd="selftest", problems=len(bad))

def main() -> int:
    ap = agent_log.std_parser("Offload shot review to an isolated Grok session; print only the text report (FAIL if isolation cannot run).")
    ap.add_argument("paths", nargs="*", help="PNG paths to review")
    ap.add_argument("--question", default="", help="What to answer about the shots (required)")
    ap.add_argument("--rubric", default="", help="Checklist text, or @FILE to read it from a file")
    ap.add_argument("--grok", default="grok", help="Grok Build executable (default: grok)")
    ap.add_argument("--max-turns", type=int, default=6, help="Max child turns (default 6)")
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
