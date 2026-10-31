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

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import agent_log  # noqa: E402

CACHE = "_logs/prove-cache.json"
## bot-status check -> (prove_rules rule id or None, extra globs). Checks not listed here always run (each < 1 s).
SCOPE: dict[str, tuple[str | None, list[str]]] = {
    "dupes_gate": (None, ["scripts/*.gd", "tools/*.py", "tools/data/dupes*"]),
    "stale_refs": ("stale-refs", []),
    "bake_repro": ("bake-check", ["scripts/graphics/wrap_shader.gd", "scripts/app/app_bake.gd", "scripts/world/camp_build*",
                                  "tools/data/hub_bake_inputs.json", "tools/lib/bake/*"]),
    "textsize": ("textsize", []),
}

## Visual-review gate: a branch touching these needs _logs/visual-review/<sha>.md for the tip (or for an ancestor with
## no visual path changed since). Questions 1-6 are a starting point, not an exhaustive list: any ad hoc issue counts.
VISUAL = ["assets/sprites/*", "assets/baked/*", "scripts/graphics/*", "scripts/world/camp*", "scripts/world/camp/*",
          "scripts/world/camp_build/*", "tools/data/hub_bake_inputs.json"]
REVIEW_DIR = "_logs/visual-review"
QUESTIONS = [
    "Every object grounded, nothing floating?",
    "Every shadow matches its object's 3D shape and the light direction?",
    "Surfaces meet with no gaps or overlaps?",
    "Sizes in proportion to the player?",
    "No unnatural repetition or mirroring?",
    "Lighting/shading present and natural, compared with the last approved round?",
    "Anything else that looks wrong, odd or unnatural? (not limited to the above; name the areas and objects scanned)",
]
SHOTS = ["python3 tools/shots.py capture --scene camp --mode build --hud 0 --zoom 2.0 --px 14 --pz 10 --out <wide.png>",
         "python3 tools/shots.py flow --flow camp-prop-shadows  (close-ups: _logs/shot-flow/camp-prop-shadows/*.png)"]
_BARE = {"ok", "okay", "yes", "no", "fine", "none", "n/a", "na", "good", "pass", "same", "nothing", "-", "looks good", "all good"}

def review_text(text: str, root: Path) -> list[str]:
    """Faults in one review file: wide/close shot lines naming existing files, and answers 1..7 that say what was seen."""
    bad = []
    for kind in ("wide", "close"):
        shots = [ln.split(":", 1)[1].strip() for ln in text.splitlines() if ln.lower().startswith(kind + ":")]
        if not shots:
            bad.append(f"no '{kind}: <shot path>' line")
        bad += [f"{kind} shot missing on disk: {p}" for p in shots if not (root / p).is_file() and not Path(p).is_file()]
    for i in range(1, len(QUESTIONS) + 1):
        ans = next((ln.split(":", 1)[1].strip() for ln in text.splitlines() if ln.strip().startswith(f"{i}:")), "")
        words = len(ans.split())
        if not ans or ans.lower().strip(" .!") in _BARE or words < (8 if i == 7 else 5):
            bad.append(f"answer {i} empty or bare ({ans[:30]!r}): name what you saw" + (" and which areas/objects you scanned" if i == 7 else ""))
    return bad

def review_faults(root: Path, changed: list[str]) -> list[str]:
    """[] when the branch touches no VISUAL path, or a valid review exists for HEAD or an ancestor with no visual change since."""
    if not hits(changed, VISUAL):
        return []
    d = root / REVIEW_DIR
    for f in sorted(d.glob("*.md"), key=lambda f: f.stat().st_mtime, reverse=True) if d.is_dir() else []:
        sha = f.stem
        if subprocess.run(["git", "merge-base", "--is-ancestor", sha, "HEAD"], cwd=root, capture_output=True).returncode:
            continue
        since = _git(root, "diff", "--name-only", sha).split()
        if hits(since, VISUAL):
            continue
        return [f"{f.relative_to(root)}: {b}" for b in review_text(f.read_text(encoding="utf-8"), root)]
    head = _git(root, "rev-parse", "HEAD").strip()
    return [f"no visual review for {head[:8]}: write {REVIEW_DIR}/{head}.md (commit first; the sha is the tip's)"]

def review_help() -> list[str]:
    return (["review: lines 'wide: <png>' and 'close: <png>' (one or more each), then '1: ...' to '7: ...' naming what you saw.",
             "review: 1-6 are a starting point, not an exhaustive list; any ad hoc issue counts under 7. 'ok' / 'none' alone fail."]
            + [f"review Q{i}: {q}" for i, q in enumerate(QUESTIONS, 1)] + [f"review shot: {c}" for c in SHOTS])

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
        (r / "w.png").write_bytes(b"x")
        good = "wide: w.png\nclose: w.png\n" + "".join(f"{i}: saw the dumpster raised on four wheels, light between them\n" for i in range(1, 7)) \
            + "7: scanned guild front, reception window, yard props, ground and both awnings: nothing else odd\n"
        if review_text(good, r):
            bad.append(f"full review must pass: {review_text(good, r)}")
        for name, txt in [("bare ok", good.replace("1: saw the dumpster raised on four wheels, light between them", "1: ok")),
                          ("bare none on 7", good.split("7:")[0] + "7: none\n"),
                          ("no question 7", good.split("7:")[0]),
                          ("no wide shot", good.replace("wide: w.png\n", "")),
                          ("shot not on disk", good.replace("close: w.png", "close: gone.png"))]:
            if not review_text(txt, r):
                bad.append(f"review {name} must fail")
        if review_faults(r, ["README.md"]):
            bad.append("docs-only branch must not need a review")
        (r / "assets/sprites").mkdir(parents=True)
        (r / "assets/sprites/a.png").write_bytes(b"x")
        _git(r, "add", "-A")
        _git(r, "commit", "-qm", "1")
        if not review_faults(r, ["assets/sprites/a.png"]):
            bad.append("sprite change with no review must fail")
        sha = _git(r, "rev-parse", "HEAD").strip()
        (r / REVIEW_DIR).mkdir(parents=True)
        (r / REVIEW_DIR / f"{sha}.md").write_text(good)
        if review_faults(r, ["assets/sprites/a.png"]):
            bad.append(f"sprite change with a tip review must pass: {review_faults(r, ['assets/sprites/a.png'])}")
        (r / "assets/sprites/a.png").write_bytes(b"y")
        _git(r, "commit", "-qam", "2")
        if not review_faults(r, ["assets/sprites/a.png"]):
            bad.append("a sprite change after the reviewed sha must need a new review")
    for b in bad:
        print("FAIL " + b)
    return bad

def main() -> int:
    p = agent_log.std_parser(__doc__)
    p.add_argument("--selftest", action="store_true", help="Replay the scoping cases in a throwaway repo.")
    ns = p.parse_args()
    if not ns.selftest:
        agent_log.fail("library module: only --selftest runs here (bot_status.py --prove uses it)")
    bad = selftest()
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))

if __name__ == "__main__":
    raise SystemExit(main())
