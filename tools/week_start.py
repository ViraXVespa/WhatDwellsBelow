#!/usr/bin/env python3
"""QUARANTINE: human-only. Agents must not run this file.

Local week start: pin HEAD as grok_web_w{series}, seed epoch.{series+1}.0 + open_commit, archive prior
changelogs, worktree gc, drop Godot locks, clean --new-week. Does not pin grok_build_w*, bump epoch,
kill Godot, or write leave-off.

    python3 tools/week_start.py [--dry-run]       # old: -WhatIf
Summary: _logs/week-start/summary.txt
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

TOOLS = Path(__file__).resolve().parent


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Human-only week start: pin, seed version, archive, gc, clean.", writes=True, json_out=True)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    dry = args.dry_run
    out = [f"root=. dryRun={dry}", ""]

    def say(s: str) -> None:
        out.append(s)
        print(s)

    def py(script: str, *a: str) -> int:
        return subprocess.run([sys.executable, str(TOOLS / script), "--root", str(root), *a], cwd=root).returncode

    ver_p, cat_p = root / "scripts/data/version.json", root / "scripts/data/archive_catalog.json"
    for p in (ver_p, cat_p):
        if not p.is_file():
            agent_log.fail(f"missing {agent_log.rel(root, p)}")
    ver = json.loads(ver_p.read_text(encoding="utf-8-sig"))
    epoch, series, patch, old = int(ver["epoch"]), int(ver["series"]), int(ver["patch"]), str(ver["label"])
    sha = repo_lib.run_git(root, "rev-parse", "HEAD")[1].strip()
    pin_id, pin_label, tag = f"grok_web_w{series}", f"Grok Web Results (Week {series})", f"archive/grok-web-w{series}"
    say(f"version={old} epoch={epoch} series={series} patch={patch}")
    say(f"head={sha}")
    say(f"pin={pin_id} (previous week Web results)")
    cat = json.loads(cat_p.read_text(encoding="utf-8-sig"))
    builds = cat if isinstance(cat, list) else cat.get("builds", [])
    pin_status = "exists"
    if not any(b.get("id") == pin_id for b in builds):
        pin_status = "added"
        doc_dir, change_src = root / "archives/docs" / pin_id, root / "design/changelog"
        copied = 0
        if not dry:
            doc_dir.mkdir(parents=True, exist_ok=True)
            for f in change_src.glob(f"{epoch}.{series}.*.md") if change_src.is_dir() else []:
                shutil.copy2(f, doc_dir / f.name)
                copied += 1
            desc = f"Live path at the end of Grok Web week {series} ({old})."
            if py("week_pin.py", "--id", pin_id, "--label", pin_label, "--desc", desc, "--commit", sha) != 0:
                agent_log.fail("week_pin.py failed", 1)
            if not repo_lib.run_git(root, "tag", "--list", tag)[1].strip():
                repo_lib.run_git(root, "tag", tag, sha)
                say(f"tag={tag}")
            else:
                say(f"tag=exists {tag}")
        ndocs = sum(1 for p in (root / "design").rglob("*") if p.suffix in (".md", ".yaml", ".yml"))
        say(f"catalog={pin_status} changelog_copied={copied} docs={ndocs}")
    else:
        say("catalog=exists")
    new_label = f"{epoch}.{series + 1}.0"
    if patch == 0 and old == new_label:
        seed = "skipped"
        say(f"seed=already {new_label}")
    else:
        seed = "wrote"
        say(f"seed={new_label} open_commit={sha}")
        if not dry:
            data = {"epoch": epoch, "series": series + 1, "patch": 0, "label": new_label, "open_commit": sha}
            ver_p.write_text(json.dumps(data, indent="\t") + "\n", encoding="utf-8")
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
        say(f"lock-del {lf.name}")
        if not dry:
            lf.unlink(missing_ok=True)
    if not locks:
        say("locks=none")
    clean = "whatif" if dry else ("ok" if py("clean_agent_logs.py", "--new-week") == 0 else "error")
    say(f"clean={clean}")
    return agent_log.finish("week-start", root, "\n".join(out), "FAIL" if "error" in (arch, gc, clean) else "PASS", args=args,
                            echo="", pin=pin_status, seed=seed, archive=arch, gc=gc, locks_deleted=len(locks), clean=clean)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
