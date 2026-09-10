#!/usr/bin/env python3
"""Export pinned catalog archives into a Pages site directory.

Best-effort: one dead pin must not abort the rest. Cache hits are keyed by
archive id + commit SHA so frozen pins are not re-exported.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run_git(root: Path, args: list[str], check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(root), *args],
        text=True,
        capture_output=True,
        check=check,
    )


def run_godot(
    godot: Path,
    godot_args: list[str],
    cache_home: Path,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    cache_home.mkdir(parents=True, exist_ok=True)
    env["XDG_CACHE_HOME"] = str(cache_home)
    env["XDG_CONFIG_HOME"] = str(cache_home / "config")
    print("+", godot.name, " ".join(godot_args), flush=True)
    return subprocess.run(
        [str(godot), *godot_args],
        text=True,
        capture_output=True,
        env=env,
    )


def dump_proc(proc: subprocess.CompletedProcess[str]) -> None:
    if proc.stdout:
        sys.stdout.write(proc.stdout)
        if not proc.stdout.endswith("\n"):
            sys.stdout.write("\n")
    if proc.stderr:
        sys.stderr.write(proc.stderr)
        if not proc.stderr.endswith("\n"):
            sys.stderr.write("\n")


def stamp_project(path: Path, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    named = f"What Dwells Below — {label}"
    text, n = re.subn(r'config/name="[^"]*"', f'config/name="{named}"', text, count=1)
    if n != 1:
        raise RuntimeError(f"could not stamp name in {path}")
    path.write_text(text, encoding="utf-8", newline="\n")


def cached_export(cache_pin: Path) -> bool:
    return (cache_pin / "index.html").is_file()


def copy_export(src: Path, dest: Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dest)


def remove_worktree(root: Path, wt: Path) -> None:
    if wt.exists():
        run_git(root, ["worktree", "remove", "--force", str(wt)])
    if wt.exists():
        shutil.rmtree(wt, ignore_errors=True)


def export_pin(
    root: Path,
    godot: Path,
    wt_root: Path,
    cache_root: Path,
    entry: dict,
) -> Path | None:
    aid = str(entry.get("id") or "").strip()
    sha = str(entry.get("commit") or "").strip()
    label = str(entry.get("label") or aid).strip()
    if not aid or not sha:
        print(f"skip catalog row missing id/commit: {entry!r}", flush=True)
        return None

    cache_pin = cache_root / aid / sha
    if cached_export(cache_pin):
        print(f"cache hit {aid} @ {sha}", flush=True)
        return cache_pin

    print(f"export {aid} @ {sha}", flush=True)
    wt = wt_root / aid
    godot_user = cache_root / ".godot-user" / aid
    stage = cache_root / aid / f"{sha}.partial"
    if stage.exists():
        shutil.rmtree(stage, ignore_errors=True)
    stage.mkdir(parents=True, exist_ok=True)

    remove_worktree(root, wt)
    add = run_git(root, ["worktree", "add", "--detach", str(wt), sha])
    if add.returncode != 0:
        dump_proc(add)
        print(f"FAIL {aid}: git worktree add {sha}", flush=True)
        return None

    try:
        project = wt / "project.godot"
        if not project.is_file():
            print(f"FAIL {aid}: missing project.godot", flush=True)
            return None
        stamp_project(project, label)
        godot_dir = wt / ".godot"
        if godot_dir.exists():
            shutil.rmtree(godot_dir, ignore_errors=True)

        imported = run_godot(
            godot,
            ["--headless", "--path", str(wt), "--import"],
            godot_user,
        )
        dump_proc(imported)
        if imported.returncode != 0:
            print(f"FAIL {aid}: godot --import exit {imported.returncode}", flush=True)
            return None

        html = stage / "index.html"
        exported = run_godot(
            godot,
            ["--headless", "--path", str(wt), "--export-release", "Web", str(html)],
            godot_user,
        )
        dump_proc(exported)
        if exported.returncode != 0 or not html.is_file():
            print(f"FAIL {aid}: godot --export-release Web exit {exported.returncode}", flush=True)
            return None

        if cache_pin.exists():
            shutil.rmtree(cache_pin, ignore_errors=True)
        stage.rename(cache_pin)
        stage = None
        print(f"cached {aid} @ {sha}", flush=True)
        return cache_pin
    except Exception as exc:
        print(f"FAIL {aid}: {exc}", flush=True)
        return None
    finally:
        if stage is not None and stage.exists():
            shutil.rmtree(stage, ignore_errors=True)
        remove_worktree(root, wt)


def export_archives(root: Path, site: Path, godot: Path, cache_root: Path, wt_root: Path) -> int:
    catalog_path = root / "scripts" / "data" / "archive_catalog.json"
    if not catalog_path.is_file():
        print(f"catalog missing: {catalog_path}", flush=True)
        return 1
    if not godot.is_file():
        print(f"godot missing: {godot}", flush=True)
        return 1

    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    rows = catalog.get("archives")
    if not isinstance(rows, list):
        print("catalog has no archives list", flush=True)
        return 1

    cache_root.mkdir(parents=True, exist_ok=True)
    wt_root.mkdir(parents=True, exist_ok=True)
    site.mkdir(parents=True, exist_ok=True)

    ok = 0
    failed = 0
    skipped = 0
    for entry in rows:
        if not isinstance(entry, dict):
            failed += 1
            continue
        slug = str(entry.get("pages_slug") or "").strip()
        cached = export_pin(root, godot, wt_root, cache_root, entry)
        if cached is None:
            failed += 1
            continue
        if not slug:
            print(f"skip {entry.get('id')}: missing pages_slug", flush=True)
            skipped += 1
            continue
        dest = site.joinpath(*slug.split("/"))
        copy_export(cached, dest)
        ok += 1

    print(f"archives copied={ok} failed={failed} skipped={skipped}", flush=True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Best-effort cached export of catalog archives.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--site", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--worktrees", type=Path, default=None)
    args = parser.parse_args()
    root = args.root.resolve()
    site = args.site if args.site.is_absolute() else root / args.site
    cache = args.cache if args.cache.is_absolute() else root / args.cache
    wt = args.worktrees
    if wt is None:
        wt = root / ".archive_worktrees"
    elif not wt.is_absolute():
        wt = root / wt
    return export_archives(root, site, args.godot.resolve(), cache, wt)


if __name__ == "__main__":
    raise SystemExit(main())