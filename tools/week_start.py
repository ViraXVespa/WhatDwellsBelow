#!/usr/bin/env python3
"""QUARANTINE: human-only. Agents must not run this file.

Local week start, run on an up-to-date main. In this order: seed version.json as epoch.{series+1}.0 + open_commit,
archive prior changelogs, create and switch to the local branch grok-build-w{series+1} from HEAD, commit the seed
there ("Grok Build Week N": version.json, changelogs, catalog), `grok worktree gc`, delete Godot locks, clean logs
(--new-week). The weekly archives are NOT made here: CI pins both grok_web_wN and grok_build_wN when the squash-merge
of that branch adds design/changelog/0.N.0.md (ci_archive.py). Catch-up only: when the closing series has no
`grok_web_w{series}` / `grok_build_w{series}` row (CI did not run), the missing rows are pinned at HEAD with local
tags. Never bumps the epoch, kills Godot, pushes, or writes leave-off. --dry-run prints "would ..." lines.

    python tools/week_start.py [--dry-run]       # old: -WhatIf
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
    ap = agent_log.std_parser("Human-only week start: seed version, week branch, changelog archive, catch-up pins, gc, clean.", writes=True, json_out=True)
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
    say(f"version={old} epoch={epoch} series={series} patch={patch}")
    say(f"head={sha}")
    say(f"new_series={new_series} (epoch {epoch} stays; only the User changes it)")
    branch = f"grok-build-w{new_series}"
    # 0. where we are: the seed commit goes on the new branch, cut from an up-to-date main
    cur = repo_lib.run_git(root, "rev-parse", "--abbrev-ref", "HEAD")[1].strip()
    behind = repo_lib.run_git(root, "rev-list", "--count", "HEAD..origin/main")[1].strip()
    if cur != "main":
        say(f"WARN on branch {cur}, not main: run from main (git switch main; git pull)")
        if not dry:
            agent_log.fail(f"on branch {cur}: run week_start.py from main (git switch main; git pull)")
    if behind.isdigit() and int(behind) > 0:
        say(f"WARN main is {behind} commit(s) behind origin/main: git pull first so the branch starts after CI's stamp and archive commits")
    if repo_lib.run_git(root, "rev-parse", "--verify", "--quiet", f"refs/heads/{branch}")[0] == 0:
        say(f"branch={branch} exists: this week is already started")
        if not dry:
            agent_log.fail(f"branch {branch} exists: week {new_series} is already started (nothing changed)")
    cat = json.loads(cat_p.read_text(encoding="utf-8-sig"))
    have = {b.get("id") for b in cat.get("archives", [])} if isinstance(cat, dict) else set()
    # 1. catch-up pins for the closing week (normally CI made them on the week-close merge)
    catch, catch_tags = 0, []
    for kind in ("web", "build"):
        spec = week_pin.pin_spec(kind, series)
        if spec["id"] in have:
            say(f"pin={spec['id']} exists (CI or an earlier run made it)")
            continue
        catch += 1
        catch_tags.append(spec["tag"])
        say(f"pin={spec['id']} MISSING: catch-up {w}add commit={sha} tag={spec['tag']}")
        if py("week_pin.py", f"--{kind}", str(series), "--commit", sha, *(["--dry-run"] if dry else [])) != 0:
            agent_log.fail("week_pin.py failed", 1)
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
    # 3. park old changelogs, then the week branch with the seed commit (local only)
    arch = "whatif" if dry else ("ok" if py("archive_prior_changelogs.py") == 0 else "error")
    if dry:
        py("archive_prior_changelogs.py", "--dry-run")
    say(f"archive_changelogs={arch}")
    br = "would-create"
    if not dry:
        br = "created"
        paths = ["scripts/data/version.json", "scripts/data/archive_catalog.json", "design/changelog", "archives/docs"]
        if repo_lib.run_git(root, "switch", "-c", branch)[0] != 0:
            br = "error"
        elif repo_lib.run_git(root, "add", "-A", "--", *paths)[0] != 0 or repo_lib.run_git(root, "commit", "-m", f"Grok Build Week {new_series}", "--", *paths)[0] != 0:
            br = "error"
    say(f"branch={branch} {w}create at {sha[:12]} and commit the seed (Grok Build Week {new_series})" if br != "error" else f"branch={branch} switch or seed commit failed")
    say(f"push=User runs: git push -u origin {branch}" + (f" and git push origin {' '.join(catch_tags)} (catch-up tags)" if catch else "") + " (never main; CI archives on the squash-merge)")
    # 4. housekeeping
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
    return agent_log.finish("week-start", root, "\n".join(out), "FAIL" if bad else "PASS", args=args, echo="", catchup_pins=catch,
                            seed=seed, branch=br, archive=arch, gc=gc, locks_deleted=0 if dry else len(locks), clean=clean, dry_run=dry)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
