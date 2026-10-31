#!/usr/bin/env python3
"""bot-status --prove scoping: each slow check names the paths it reads; untouched in the branch diff -> SKIP, same
inputs as its last pass -> SKIP (per-input pass cache, _logs/prove-cache.json). `--full` (merges, week-start) runs all.

Globs come from tools/data/prove_rules.json (the check.py prove rule of the same check) plus SCOPE extras below.
`python3 tools/lib/checks/prove_scope.py --selftest` replays the scoping cases.
"""
from __future__ import annotations

import fnmatch
import hashlib
import json
import subprocess
import sys
from pathlib import Path

CACHE = "_logs/prove-cache.json"
## bot-status check -> (prove_rules rule id or None, extra globs). Checks not listed here always run (each < 1 s).
SCOPE: dict[str, tuple[str | None, list[str]]] = {
    "dupes_gate": (None, ["scripts/*.gd", "tools/*.py", "tools/data/dupes*"]),
    "stale_refs": ("stale-refs", []),
    "bake_repro": ("bake-check", ["scripts/graphics/wrap_shader.gd", "scripts/app/app_bake.gd", "scripts/world/camp_build*",
                                  "tools/data/hub_bake_inputs.json", "tools/lib/bake/*"]),
    "textsize": ("textsize", []),
}

def globs(root: Path, check: str) -> list[str]:
    rule_id, extra = SCOPE[check]
    out = list(extra)
    if rule_id:
        rules = json.loads((root / "tools/data/prove_rules.json").read_text(encoding="utf-8"))["checks"]
        out += next(r["when"] for r in rules if r["id"] == rule_id)
    return out

def hits(paths: list[str], gs: list[str]) -> list[str]:
    return [p for p in paths if any(fnmatch.fnmatch(p, g) for g in gs)]

def _git(root: Path, *a: str) -> str:
    return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True).stdout

def digest(root: Path, gs: list[str]) -> str:
    """Hash of every tracked or untracked file under gs as it is on disk now (HEAD blob, or the worktree bytes if dirty)."""
    tree = {ln.split("\t", 1)[1]: ln.split()[2] for ln in _git(root, "ls-files", "-s").splitlines() if "\t" in ln}
    dirty = set(_git(root, "diff", "--name-only", "HEAD").split()) | set(_git(root, "ls-files", "-o", "--exclude-standard").split())
    h = hashlib.sha1("\n".join(gs).encode())
    for p in sorted(hits(sorted(set(tree) | dirty), gs)):
        f = root / p
        blob = hashlib.sha1(f.read_bytes()).hexdigest() if p in dirty and f.is_file() else tree.get(p, "gone")
        h.update(f"{p}\0{blob}\n".encode())
    return h.hexdigest()[:16]

def load(root: Path) -> dict:
    f = root / CACHE
    try:
        return json.loads(f.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}

def save(root: Path, cache: dict) -> None:
    f = root / CACHE
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps(cache, indent=1, sort_keys=True) + "\n", encoding="utf-8")

def decide(root: Path, check: str, changed: list[str], cache: dict, full: bool) -> tuple[str | None, str]:
    """(None, digest) = run it; (reason, digest) = SKIP with that reason."""
    gs = globs(root, check)
    d = digest(root, gs)
    if full:
        return None, d
    hit = hits(changed, gs)
    if not hit:
        return f"SKIP untouched (no changed path matches {', '.join(gs[:3])}{' ...' if len(gs) > 3 else ''})", d
    if cache.get(check) == d:
        return f"SKIP cached pass (inputs unchanged since its last pass; {len(hit)} matching path(s) differ from main)", d
    return None, d

def selftest() -> int:
    import tempfile
    bad = []
    with tempfile.TemporaryDirectory() as td:
        r = Path(td)
        for c in (["init", "-q"], ["config", "user.email", "t@t"], ["config", "user.name", "t"]):
            _git(r, *c)
        (r / "tools/data").mkdir(parents=True)
        (r / "tools/data/prove_rules.json").write_text(json.dumps({"checks": [
            {"id": "textsize", "when": ["scripts/ui/*"]}, {"id": "stale-refs", "when": ["*.md"]}, {"id": "bake-check", "when": ["assets/baked/*"]}]}))
        (r / "scripts/ui").mkdir(parents=True)
        (r / "scripts/ui/a.gd").write_text("x")
        (r / "README.md").write_text("y")
        _git(r, "add", "-A")
        _git(r, "commit", "-qm", "0")
        cache: dict = {}
        why, _ = decide(r, "textsize", ["README.md"], cache, False)
        if not (why or "").startswith("SKIP untouched"):
            bad.append(f"docs-only change must skip textsize: {why}")
        why, d = decide(r, "textsize", ["scripts/ui/a.gd"], cache, False)
        if why is not None:
            bad.append(f"ui change must run textsize: {why}")
        cache["textsize"] = d
        why, _ = decide(r, "textsize", ["scripts/ui/a.gd"], cache, False)
        if not (why or "").startswith("SKIP cached"):
            bad.append(f"rerun with no new change must hit the cache: {why}")
        (r / "scripts/ui/a.gd").write_text("z")
        why, _ = decide(r, "textsize", ["scripts/ui/a.gd"], cache, False)
        if why is not None:
            bad.append(f"edited ui file must miss the cache: {why}")
        why, _ = decide(r, "stale_refs", ["README.md"], {"stale_refs": "x"}, True)
        if why is not None:
            bad.append(f"--full must run: {why}")
    for b in bad:
        print("FAIL", b)
    print(f"RESULT {'FAIL' if bad else 'PASS'} cases=5 bad={len(bad)}")
    return 1 if bad else 0

if __name__ == "__main__":
    raise SystemExit(selftest() if "--selftest" in sys.argv else 2)
