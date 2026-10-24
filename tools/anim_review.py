#!/usr/bin/env python3
"""Animation Browser review briefs from tools/anim_review/review.json (one tool, three jobs).

    python tools/anim_review.py pack   [--review P] [--out-md P] [--out-json P] [--dry-run]
    python tools/anim_review.py regen  [--review P] [--out-md P] [--out-json P] [--dry-run]
    python tools/anim_review.py tree   [--review P] [--out DIR] [--dry-run]

pack:  Repack notes plus Good locomotion clips on disk -> pack_brief.md/.json (tune pack_locomotion.py).
regen: Regenerate notes plus the current i2v_seeds.build_prompt text -> regen_brief.md/.json (tune i2v_seeds.py).
tree:  wiped I2V test tree (source.png, prompt.txt, notes.txt per Regenerate clip) at tools/anim_review/regen_tree.
Summary: _logs/anim-review/<stamp>-anim-review.txt.
"""
from __future__ import annotations

import shutil
import sys
from collections import defaultdict
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import anim_review_lib as lib

def _scan_good_pack_clips() -> list[dict]:
    """Clips on disk that look like packed locomotion and are not flagged."""
    flagged = {row["key"] for row in lib.clip_rows()}
    found: list[dict] = []
    for model, gender in lib.PLAYER_IDS.items():
        base = lib.PLAYER_SPRITE / gender
        if not base.is_dir():
            continue
        for facing in (
            "up",
            "up_right",
            "right",
            "down_right",
            "down",
            "down_left",
            "left",
            "up_left",
        ):
            for anim in lib.PACK_ANIMS:
                frames = lib.frame_paths(model, facing, anim)
                if len(frames) <= 1:
                    continue
                key = f"{model}/{facing}/{anim}"
                if key in flagged:
                    continue
                found.append(
                    {
                        "key": key,
                        "model": model,
                        "facing": facing,
                        "anim": anim,
                        "state": "good",
                        "note": "",
                        "frames": [str(p.relative_to(lib.ROOT)) for p in frames],
                    }
                )
    return found

def _pack_md(repack: list[dict], good: list[dict], missing: list[str]) -> str:
    lines = [
        "# Pack review brief",
        "",
        "Input: `tools/anim_review/review.json`.",
        "Use Repack notes as failure cases. Use Good locomotion clips as keep-behavior.",
        "Do not treat Regenerate rows as pack-script failures.",
        "",
        f"Repack clips: {len(repack)}",
        f"Good pack-family clips on disk: {len(good)}",
        "",
        "## Repack",
        "",
    ]
    if not repack:
        lines.append("None.")
        lines.append("")
    by_model = defaultdict(list)
    for row in repack:
        by_model[row["model"]].append(row)
    for model in sorted(by_model):
        lines.append(f"### {model}")
        lines.append("")
        for row in by_model[model]:
            frames = [str(p.relative_to(lib.ROOT)) for p in lib.frame_paths(row["model"], row["facing"], row["anim"])]
            lines.append(f"- `{row['key']}` frames={len(frames)}")
            if frames:
                lines.append(f"  - assets: `{frames[0]}` … `{frames[-1]}`" if len(frames) > 1 else f"  - assets: `{frames[0]}`")
            else:
                lines.append("  - assets: missing on disk")
            note = row["note"].strip()
            lines.append(f"  - note: {note if note else '(none)'}")
            if not row["player"]:
                lines.append("  - warning: enemy pack pipeline is not configured; notes only.")
            lines.append("")
    lines.extend(["## Good pack-family clips", ""])
    if not good:
        lines.append("None.")
        lines.append("")
    else:
        for row in good:
            lines.append(f"- `{row['key']}` frames={len(row['frames'])}")
        lines.append("")
    lib.add_missing(lines, missing)
    lines.extend(
        [
            "## Tuning hint",
            "",
            "Prefer changing `tools/pack_locomotion.py` (stride period, idle MAD, plant-foot rotation,",
            "torso X lock, start/stop split) only when Repack notes name those symptoms and Good clips",
            "of the same facing family should keep working.",
            "",
        ]
    )
    return "\n".join(lines)

def _player_prompt(row: dict) -> str:
    if not row["player"]:
        return ""
    facing = row["facing"]
    if facing == "idle_none":
        facing = "down"
    import i2v_seeds

    return i2v_seeds.build_prompt(
        facing,
        row["i2v_action"],
        [],
        test=False,
        gender=row["gender"] or "male",
    )

def _regen_md(regen: list[dict], prompts: dict[str, str], missing: list[str]) -> str:
    lines = [
        "# Regen review brief",
        "",
        "Input: `tools/anim_review/review.json`.",
        "Use these notes when changing `tools/i2v_seeds.py` MOTION / IDENTITY_LOCK / FACING_LOCK.",
        "Accepted clips are everything not listed here; do not break those prompts without cause.",
        "",
        f"Regenerate clips: {len(regen)}",
        "",
        "## Regenerate",
        "",
    ]
    if not regen:
        lines.append("None.")
        lines.append("")
    by_model = defaultdict(list)
    for row in regen:
        by_model[row["model"]].append(row)
    for model in sorted(by_model):
        lines.append(f"### {model}")
        lines.append("")
        for row in by_model[model]:
            lines.append(f"- `{row['key']}` i2v_action=`{row['i2v_action']}`")
            note = row["note"].strip()
            lines.append(f"  - note: {note if note else '(none)'}")
            if not row["player"]:
                lines.append("  - warning: enemy I2V pipeline is not configured; notes only.")
            else:
                prompt = prompts.get(row["key"], "").strip()
                if prompt:
                    lines.append("  - current prompt:")
                    lines.append("")
                    for ln in prompt.splitlines():
                        lines.append(f"    {ln}")
                    lines.append("")
            lines.append("")
    lib.add_missing(lines, missing)
    lines.extend(
        [
            "## Tuning hint",
            "",
            "Change one motion or identity sentence at a time. Re-check every facing that is not",
            "in this list before widening a prompt change.",
            "",
        ]
    )
    return "\n".join(lines)

def _cell_for(gender: str, facing: str) -> "object | None":
    import i2v_seeds
    import sprite_pipeline as sp
    from imglib import imgio
    bible = lib.BIBLE.get(gender)
    if bible is None or not bible.is_file():
        return None
    raw = imgio.load(bible)
    cells = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(raw)))
    key = facing if facing in cells else "down"
    im = cells.get(key)
    if im is None:
        return None
    return i2v_seeds.pad_chroma(i2v_seeds.scale_nn(im, i2v_seeds.SCALE), i2v_seeds.PAD_FRAC)

def _wipe(dest: Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True, exist_ok=True)

def _write_player(folder: Path, row: dict) -> str:
    folder.mkdir(parents=True, exist_ok=True)
    facing = row["facing"] if row["facing"] != "idle_none" else "down"
    seed = _cell_for(row["gender"] or "male", facing)
    if seed is None:
        lib.write_text(folder / "warning.txt", "missing locked bible cell for this facing")
        status = "missing-bible"
    else:
        seed.save(folder / "source.png")
        status = "ok"
    prompt = _player_prompt({**row, "facing": facing})
    lib.write_text(folder / "prompt.txt", prompt)
    note = row["note"].strip()
    if note:
        lib.write_text(folder / "notes.txt", note)
    return status

def _write_enemy(folder: Path, row: dict) -> str:
    folder.mkdir(parents=True, exist_ok=True)
    lib.write_text(
        folder / "warning.txt",
        "enemy I2V pipeline is not configured; source.png and prompt.txt omitted",
    )
    note = row["note"].strip()
    if note:
        lib.write_text(folder / "notes.txt", note)
    return "enemy-warning"

def _done(args, cmd: str, wrote: list[Path], **kv: object) -> int:
    body = [f"anim-review {cmd} review={agent_log.rel(lib.ROOT, args.review)}"]
    body += [("would write " if args.dry_run else "wrote ") + agent_log.rel(lib.ROOT, p) for p in wrote]
    return agent_log.finish("anim-review", lib.ROOT, "\n".join(body), "PASS", args=args, cmd=cmd, **kv)

def run_pack(args) -> int:
    review, missing = lib.load_with_missing(args.review)
    repack = [r for r in lib.clip_rows(review) if r["state"] == "repack"]
    good = _scan_good_pack_clips()
    payload = {"v": 1, "kind": "pack_brief", "review": agent_log.rel(lib.ROOT, args.review),
               "repack": repack, "good": good, "missing": missing}
    lib.write_brief(args, _pack_md(repack, good, missing), payload)
    return _done(args, "pack", [args.out_md, args.out_json], repack=len(repack), good=len(good), missing=len(missing))

def run_regen(args) -> int:
    review, missing = lib.load_with_missing(args.review)
    regen = [r for r in lib.clip_rows(review) if r["state"] == "regenerate"]
    prompts = {row["key"]: _player_prompt(row) for row in regen}
    payload = {"v": 1, "kind": "regen_brief", "review": agent_log.rel(lib.ROOT, args.review),
               "regenerate": [{**row, "prompt": prompts.get(row["key"], "")} for row in regen], "missing": missing}
    lib.write_brief(args, _regen_md(regen, prompts, missing), payload)
    return _done(args, "regen", [args.out_md, args.out_json], regenerate=len(regen), missing=len(missing))

def run_tree(args) -> int:
    dest = args.out or lib.REVIEW_DIR / "regen_tree"
    regen = [r for r in lib.clip_rows(lib.load_review(args.review)) if r["state"] == "regenerate"]
    if args.dry_run:
        return _done(args, "tree", [dest], regenerate=len(regen))
    _wipe(dest)
    if not args.review.is_file():
        lib.write_text(dest / "warning.txt", f"no review file at {agent_log.rel(lib.ROOT, args.review)}")
        return _done(args, "tree", [dest], regenerate=0, error="no-review-json")
    counts = {"ok": 0, "missing-bible": 0, "enemy-warning": 0}
    for row in regen:
        folder = dest / row["model"] / row["facing"] / row["anim"]
        status = _write_player(folder, row) if row["player"] else _write_enemy(folder, row)
        counts[status] = counts.get(status, 0) + 1
    return _done(args, "tree", [dest], regenerate=len(regen), ok=counts["ok"],
                 missing_bible=counts["missing-bible"], enemy=counts["enemy-warning"])

def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    cmds = {"pack": ("pack_brief", run_pack), "regen": ("regen_brief", run_regen), "tree": (None, run_tree)}
    cmd = next((a for a in argv if not a.startswith("-")), "")
    if cmd not in cmds:
        ap = agent_log.std_parser(__doc__, writes=True)
        ap.add_argument("cmd", choices=sorted(cmds), help="pack, regen or tree.")
        ap.parse_args(argv)  # prints usage / error and exits
        return 2
    argv.remove(cmd)
    stem, run = cmds[cmd]
    ap = agent_log.std_parser(f"anim_review {cmd}: " + __doc__.splitlines()[0], writes=True)
    ap.prog = f"anim_review.py {cmd}"
    if cmd == "tree":
        ap.add_argument("--out", "--dest", dest="out", type=Path, default=None,
                        help="Output tree (default tools/anim_review/regen_tree). It is wiped first.")
    return run(lib.brief_args(ap, stem, argv))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
