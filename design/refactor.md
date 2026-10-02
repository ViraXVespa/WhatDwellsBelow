# Refactor recipe

Status: protocol  
Read when: splitting a live script for size; Bot size or extract flow

Grok Bot uses this file on every task. Other paths use it only when they must split. Grok Build feature work is **not** a refactor: same-system APIs and helpers live in the build path file, the **No new code** rules do not bind it, and Build does not cap-split (over-cap leftovers go to the Bot size job). Web / chat does not cap-split either.

## Caps

| Rule | Who |
|------|-----|
| Ship floor: every live `scripts/**/*.gd` under **10,000 bytes** | Bot size PR. Not Build while running |
| Sweep target: each resulting file under **5,000 bytes** when existing code can move | Grok Bot size sweep only |

Do not split a file already under the cap that applies, except Grok Bot extract work (new shared module or fitting existing owner).

## No new code

Binds **Grok Bot** size splits and extracts only. A refactor only rearranges what already exists.

- No features, tunables, comments, renames, reformats or "while I'm here" cleanups. No better API; no generalizing two vaguely similar features.
- No helper that was not already in the tree, except a shared-module extract of **near-identical** existing bodies (same control flow; renamed locals OK).
- Minimum edits to relocate lines and keep compiling. Wiring is not new behavior: `: Type` on a moved line, `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`.
- A non-empty `design/reuse-map.md` brief may name small kits at the surface it states; it is not a license for a widget framework.

## Cluster folders (placement rule; one copy)

The **facade stays beside its folder** in the area dir. Its **helpers live in a folder named by the stem, with the repeated stem trimmed**: `scripts/graphics/light_rt.gd` + `scripts/graphics/light_rt/hub_bake.gd`, `lights.gd`, `publish.gd`. Facade-less families that share a first token (two or more files) get a folder named by the token and no facade (`scripts/world/crystal/net.gd`, `crystal_place.gd`). Folders stay inside the existing area (`audio combat data debug dungeon graphics input ui world`, and the root `scripts/`); depth stops at the stem folder. A cluster over 9 files splits one level into sibling stem folders (`playtest/`, `playtest_ai/`, `playtest_log/`). Loose single files stay loose. Facade file names and `class_name`s never change.
- **Helper naming.** Drop the leading `<stem>_` (`light_rt_fov` -> `fov.gd`). Keep a qualifier (last stem token, then more, up to the full old name) when the trimmed name is generic (`util`, `parts`, `act`, `view`, `core`, `hub`, ... `gd_lib.GENERIC`), two characters or fewer, or equals another `.gd` basename in the repo: `playtest_ai_util` -> `ai_util.gd`, `light_stamp_k` -> `stamp_k.gd`, `hud_act` stays `hud_act.gd`. Never create a second `util.gd` / `parts.gd`.
- **Basenames are unique repo-wide** (editor tabs, grep, bare names in code-map rows). `check_script_cap.py` fails on `dupes=`. `split_funcs.py` picks the names (`--dry-run` prints them); rule: `gd_lib.helper_basenames`.
- A new helper from a split or extract goes into the facade's folder (`split_funcs.py` creates it; `--in-folder` for facade-less families). Splitting a loose facade needs no move first.
- A move or rename carries `.uid` sidecars and every `res://` / bare path (`move_script_cluster.py`, below). Path length counts toward the 10KB floor.
- **Manual checks after any move or rename** (the tool cannot see these): prose globs (`dir/stem*.gd`, `stem_*`), the OLD basename of every renamed file repo-wide in md / yaml / py / json / gd (skip `design/changelog/`), string-built paths (`"res://scripts/" + ...`, `%s`), shot / smoke / tool code that names a script file, and the four `wdb-*` skills in `/home/box/agent-data/workflows`. One batch, gates once (`design/tools.md` rule 10). Then editor import, `check_load_graph`, `check_code_map`, `check_script_cap`, `bot_warnscan --areas static --non-leak-diff`.

## Size split

1. Split into a helper in the stem folder (`act.gd`, `view.gd`, `boot.gd`, `text.gd`, ...; qualifier per Cluster folders).
2. Keep the original facade beside its folder (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`: the facade preloads its helpers; helpers never preload the facade. If a helper needs facade-held `static var` state, use `var rt: Variant = load(RT_PATH)` then `rt.name` (see `publish.gd`). For a node script, the facade keeps state and one-line delegates; each moved instance func becomes `static func name(node: Variant, ...)` in a sibling `extends Object` helper that reads state as `node.field` (see `drive.gd`). Prove by a line-multiset compare against the original after stripping qualifiers, plus smokes before and after. `tools/facade_requal.py` qualifies moved names in the facade.
5. Godot 4 analyzes a parent script alone: do not call methods that exist only on a child; call the helper module from the parent.
6. Never split files under a pinned archive commit. Slim `archives/docs/` copies are live-tree museum text only.
7. Split the largest first. One cluster per batch; then stop (web / chat: so the User can paste; Bot: ship the PR and report).

A size split's helper is **moved code**, not newly written logic. Bot sweep: after the split each live `.gd` should be under 5KB when whole existing functions can move; a function itself over 5KB stays whole and is reported. Never leave a touched file over 10KB if a legal split can fix it.

## New shared modules and reuse (Grok Bot)

Hunt for copies only after size work on the current cluster, or when the active Bot flow is extract / staged reuse; not when the User already named the cluster.

- Near-identical = same control flow (renamed locals OK), not vaguely similar features. Do not merge pairs under **Do not merge** in the Bot extract job.
- Copy lives inside one system: a sibling of that facade (the size-split shape), not a new global owner.
- Same concern as an **existing** shared script and routing call sites there keeps it under the size cap: call that script. Find owners from the live tree plus one `design/code-map.md` row (not `design/reuse-map.md`, which is not an owners encyclopedia). Known: menu tab / confirm / back / page `scripts/ui/menu_pad.gd`; prompt / hint strip `scripts/ui/prompt_view.gd`; also `theme.gd`, `menu_util.gd`, `tip.gd`, `plate_chrome.gd`, `tip_place.gd` when they already expose the function.
- Otherwise prefer a **NEW shared module** (moved bodies) over growing an owner: never grow an owner just to avoid a new file, and do not add a method to an existing owner just so copies fit; if neither fits, leave the copies and report.
- Build: same-system method or helper is just-do; a new cross-system owner is propose-first (build path file).

## Hostify, types, shared calcs

Compile pitfalls of facade + `static func(host, ...)` splits, typing rules for moved lines, and the one-helper rule for gameplay formulas used by smokes: `refactor-hostify.md`. Read it when a split or extract touches `host` helpers or a smoke asserts a gameplay number.

## Token rules

One `design/code-map.md` row + the cluster is enough for a split; do not load the design corpus. Measure with `os.path.getsize` / Length, not by reading bodies. Do not dump whole files when a diff or PR is enough.

## After a split

Update `design/code-map.md` when a new sibling or shared module must be listed. Do not update topic design files unless behavior changed. Bot does not write extract results into `design/reuse-map.md` (web / chat Phase 7 owns that brief).

## Parked folder moves

Not part of a size split; the Bot relocate job owns them. Every `preload` / `load` / ExtResource path plus `design/code-map.md` rows must stay correct; no behavior change.

`python3 tools/move_script_cluster.py` (`--help`; catalog: `design/tools.md`). Modes: `--stem/--from-dir/--to-dir` (one cluster), `--plan plan.json` (`{to_dir: [files]}`), `--map map.json` (exact `{old_file: new_file}` moves and renames), `--list-cluster FACADE`, `--dry-run`, `--wrapper` (`extends "res://..."` stubs at old paths; only when asked or when refs are too many to retarget). One run = one rewrite pass: it `git mv`s files (+ `.uid`), rewrites `res://` paths, bare paths and bare old basenames under `scripts/`, `design/`, scenes, `project.godot`, `tools/`, `.grok/`, `.github/` and root md (not `design/changelog/`), keeps BOM and CRLF, and writes `_logs/move-cluster/summary.txt`. Then the manual checks above and the editor import check. Prefer updating call sites over wrappers when external refs are few. New fat facade clusters move only on a User go.
