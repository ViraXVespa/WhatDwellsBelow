"""Build procedure invariants, without launching a game, connector or media runner."""
from __future__ import annotations
import re
from pathlib import Path

# Operating layer only: product/art specs keep their own technical requirements.
DOCS = (
    "AGENTS.md", "design/grok-build.md", "design/build-job-cycle.md", "design/build-handoff.md",
    "design/build-references.md", "design/build-week-start.md", "design/build-simulation.md",
    "design/pc-offload.md", "design/isolated-media.md", "design/prove.md", "design/shot-tool.md",
    "design/shot-flows.md", "design/tools.md", "design/tools-build.md", "design/tools-shots.md",
    "design/tools-media.md", "design/tools-gates.md", "design/tools-lookup.md", "design/tools-libs.md",
    "design/tools-perf.md", "design/debug-smokes.md",
    "design/tasks/README.md", "design/tasks/modular-voxel-walk-proof.md", "design/tasks/ui-png-art.md",
    "design/tasks/perf-sweep.md", ".grok/skills/pc-offload/SKILL.md",
    ".grok/skills/review-shots-isolated/SKILL.md", ".grok/skills/shot-tool/SKILL.md",
)


def check(root: Path) -> list[str]:
    bad = []
    old = re.compile(r"before the first prove|120[–-]150|compact once before|one compact.*before prove", re.I)
    for rel in DOCS:
        text = (root / rel).read_text(encoding="utf-8")
        if old.search(text):
            bad.append(f"obsolete compaction instruction: {rel}")
    skill_meta = (root / ".grok/skills/pc-offload/SKILL.md").read_text().split("---", 2)[1]
    if "Default workflow for every Grok Build task" not in skill_meta:
        bad.append("pc-offload metadata must make the repository Build default explicit")
    canonical = (root / "design/build-job-cycle.md").read_text()
    for phrase in ("compact would be safe", "before Prove", "follow-up Gather or Change", "same session"):
        if phrase not in canonical:
            bad.append("canonical context rule missing: " + phrase)
    if "--fork-session" in (root / "design/tasks/ui-png-art.md").read_text() or "--fork-session" in (root / "design/tasks/perf-sweep.md").read_text():
        bad.append("task resume must not direct an implementation-session fork")
    for rel, limit in (("design/grok-build.md", 4000), ("design/build-job-cycle.md", 8000),
                       ("design/build-handoff.md", 8000), ("design/build-references.md", 8000)):
        if (root / rel).stat().st_size >= limit:
            bad.append(f"Build guide exceeds {limit} bytes: {rel}")
    for rel in ("design/isolated-media.md", "design/art-pipeline.md"):
        if "exception table" in (root / rel).read_text().lower():
            bad.append("undocumented generation override promised: " + rel)
    references = (root / "design/build-references.md").read_text()
    for phrase in ("GROK_SESSION_ID", "read-only", "OCR", "Blender", "Godot", "live schema", "host"):
        if phrase not in references:
            bad.append("reference guide contract missing: " + phrase)
    voxel = (root / "design/tasks/modular-voxel-walk-proof.md").read_text()
    if "_src/new_bibles/female.png" not in voxel or "bible_locked_female.png" in voxel or "references export" in voxel:
        bad.append("voxel task must read the new source without assumed legacy crops")
    return bad
