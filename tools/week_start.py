#!/usr/bin/env python3
"""QUARANTINE: human-only. Agents must not run this file.

Local week start, in this order: pin HEAD as grok_web_w{series} (the closing week's web results) with its local
tag, seed version.json as epoch.{series+1}.0 + open_commit, create the local branch grok-build-w{series+1} from
HEAD (the Build week branch; the User pushes it), archive prior changelogs, `grok worktree gc`, delete Godot
locks, clean logs (--new-week). Never bumps the epoch, pins grok_build_w* (CI does, or week_pin.py --build),
kills Godot, pushes, or writes leave-off. --dry-run prints "would ..." lines and changes nothing.

    python3 tools/week_start.py [--dry-run]       # old: -WhatIf
Each run writes _logs/week-start/<stamp>-week-start.txt (read_summary.py --job week-start).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import repo_lib
import week_pin

TOOLS = Path(__file__).resolve().parent


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Human-only week start: pin, seed version, week branch, archive, gc, clean.", writes=True, json_out=True)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    dry = args.dry_run
    w = "would " if dry else ""
    out = [f"root=. dryRun={dry}", ""]

    def say(s: str) -> None:
        out.append(s)
        print(s)

    def py(script: str, *a: str) -> int:
        p = subprocess.run([sys.executable, str(TOOLS / script), "--root", str(root), *a], cwd=root, capture_output=True, text=True)
        if p.returncode:
            print((p.stdout + p.stderr).strip(), file=sys.stderr)
        return p.returncode

    ver_p, cat_p = root / "scripts/data/version.json", root / "scripts/data/archive_catalog.json"
    for p in (ver_p, cat_p):
        if not p.is_file():
            agent_log.fail(f"missing {agent_log.rel(root, p)}")
    ver = json.loads(ver_p.read_text(encoding="utf-8-sig"))
    epoch, series, patch, old = int(ver["epoch"]), int(ver["series"]), int(ver["patch"]), str(ver["label"])
    new_series, new_label = series + 1, f"{epoch}.{series + 1}.0"
    sha = repo_lib.run_git(root, "rev-parse", "HEAD")[1].strip()
    spec = week_pin.pin_spec("web", series)
    say(f"version={old} epoch={epoch} series={series} patch={patch}")
    say(f"head={sha}")
    say(f"new_series={new_series} (epoch {epoch} stays; only the User changes it)")
    cat = json.loads(cat_p.read_text(encoding="utf-8-sig"))
    rows = cat.get("archives", []) if isinstance(cat, dict) else []
    # 1. web pin for the closing week
    if any(b.get("id") == spec["id"] for b in rows):
        pin_status = "exists"
        say(f"pin={spec['id']} exists")
    else:
        pin_status = "would-add" if dry else "added"
        say(f"pin={spec['id']} {w}add commit={sha} tag={spec['tag']}")
        if py("week_pin.py", "--web", str(series), "--commit", sha, *(["--dry-run"] if dry else [])) != 0:
            agent_log.fail("week_pin.py failed", 1)
    build_id = f"grok_build_w{series}"
    build_pin = "exists" if any(b.get("id") == build_id for b in rows) else "missing"
    say(f"build_pin={build_id} {build_pin}" + (" (CI adds it when the series seed lands on main, else: python3 tools/week_pin.py --build %d --commit SHA)" % series if build_pin == "missing" else ""))
    # 2. seed
    if patch == 0 and old == new_label:
        seed = "skipped"
        say(f"seed=already {new_label}")
    else:
        seed = "would-write" if dry else "wrote"
        say(f"seed={w}write {new_label} open_commit={sha}")
        if not dry:
            data = {"epoch": epoch, "series": new_series, "patch": 0, "label": new_label, "open_commit": sha}
            ver_p.write_text(json.dumps(data, indent="\t") + "\n", encoding="utf-8")
    # 3. week branch (local only)
    branch = f"grok-build-w{new_series}"
    if repo_lib.run_git(root, "rev-parse", "--verify", "--quiet", f"refs/heads/{branch}")[0] == 0:
        br = "exists"
        say(f"branch={branch} exists (left as is)")
    else:
        br = "would-create" if dry else "created"
        if not dry and repo_lib.run_git(root, "branch", branch, sha)[0] != 0:
            br = "error"
        say(f"branch={branch} {w}create at {sha[:12]}" if br != "error" else f"branch={branch} git branch failed")
    say(f"push=User runs: git push -u origin {branch} (and git push origin archive/grok-web-w{series} for the tag)")
    # 4. housekeeping
    arch = "whatif" if dry else ("ok" if py("archive_prior_changelogs.py") == 0 else "error")
    if dry:
        py("archive_prior_changelogs.py", "--dry-run")
    say(f"archive_changelogs={arch}")
    gc = "skipped"
    grok = shutil.which("grok")
    if grok:
        say(f"grok=found path={grok}")
        if dry:
            gc = "whatif"
        else:
            p = subprocess.run([grok, "worktree", "gc"], capture_output=True, text=True, encoding="utf-8", errors="replace")
            gc = "ok" if p.returncode == 0 else "error"
            out += [f"gc: {ln.strip()}" for ln in (p.stdout + p.stderr).splitlines() if ln.strip()]
        say(f"gc={gc}")
    else:
        say("grok=missing (no worktree gc)")
    locks = sorted((root / "_logs/godot-lock").glob("*.lock")) if (root / "_logs/godot-lock").is_dir() else []
    for lf in locks:
        say(f"lock-del {lf.name}" if not dry else f"would lock-del {lf.name}")
        if not dry:
            lf.unlink(missing_ok=True)
    if not locks:
        say("locks=none")
    clean = "whatif" if dry else ("ok" if py("clean_agent_logs.py", "--new-week") == 0 else "error")
    say(f"clean={clean}")
    bad = "error" in (arch, gc, clean, br)
    return agent_log.finish("week-start", root, "\n".join(out), "FAIL" if bad else "PASS", args=args, echo="", pin=pin_status,
                            seed=seed, branch=br, archive=arch, gc=gc, locks_deleted=0 if dry else len(locks), clean=clean, dry_run=dry)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
