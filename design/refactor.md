# Refactor recipe

Status: protocol  
Read when: splitting a live script for size; Bot size or extract flow


Grok Bot uses this file on every task. Other paths use it only when they must split.

Grok Build feature work is **not** a refactor. Implementation freedom (new same-system APIs, helpers, local module shape) lives in the build path file. This file’s **No new code** rules do not bind that work. **Grok Build** does not use this file for a size cap. Over-cap leftovers go to the Bot size job.

## Caps

| Rule | Who |
|------|-----|
| Ship floor: every live `scripts/**/*.gd` under **10,000 bytes** | Bot size PR. Not Build while running |
| Sweep target: each resulting file under **5,000 bytes** when existing code can move | Grok Bot size sweep only |

Web / chat and Grok Build do not cap-split.

Do not split a file that is already under the cap that applies to the current path, except Grok Bot extract work (new shared module or fitting existing owner) when that flow is the active Job-table sibling.

## No new code

This section binds **Grok Bot** size splits and extracts only. It does not bind Grok Build feature work.

A refactor only rearranges what already exists.

- Do not add features, tunables, comments, docs-of-taste, renames, reformats, or “while I’m here” cleanups.
- Do not invent a better API. Do not generalize two vaguely similar features into a new one.
- Do not add a helper function that was not already in the tree, except Grok Bot’s shared-module extract of **near-identical** existing bodies (same control flow; renamed locals OK).
- Edits are the minimum needed to relocate existing lines and keep the project compiling.

Adding `: Type` on a line already being moved, a `load()` / `preload()`, a one-line facade delegate, or `host` / `pt` / `ui` / `p` on a moved `static func` is wiring, not new behavior.

A non-empty `design/reuse-map.md` brief may name small kits at the surface that brief states; it is not a license to invent a widget framework.

## Cluster folders (placement rule; one copy)

The **facade stays beside its folder** in the area dir. Its **helpers live in a folder named by the stem, with the repeated stem trimmed**: `scripts/graphics/light_rt.gd` + `scripts/graphics/light_rt/hub_bake.gd`, `lights.gd`, `publish.gd`. Facade-less families that share a first token (two or more files) get a folder named by the token and no facade (`scripts/world/crystal/net.gd`, `crystal_place.gd`). Folders stay inside the existing area (`audio combat data debug dungeon graphics input ui world`, and the root `scripts/`); depth stops at the stem folder. A cluster over 9 files splits one level into sibling stem folders (`playtest/`, `playtest_ai/`, `playtest_log/`). Loose single files stay loose. Facade file names and `class_name`s never change.
- **Helper naming.** Drop the leading `<stem>_` (`light_rt_fov` -> `fov.gd`). Keep a qualifier (last stem token, then more tokens, up to the full old name) when the trimmed name is generic (`util`, `parts`, `act`, `view`, `core`, `hub`, ... `gd_lib.GENERIC`), two characters or fewer, or equals another `.gd` basename in the repo: `playtest_ai_util` -> `ai_util.gd`, `camp_build_util` -> `build_util.gd`, `light_stamp_k` -> `stamp_k.gd`, `hud_act` stays `hud_act.gd`. Never create a second `util.gd` / `parts.gd`.
- **Basenames are unique repo-wide** (editor tabs, quick-open, grep, bare names in code-map rows). `python3 tools/check_script_cap.py` fails on `dupes=`. `split_funcs.py` picks the names (`--dry-run` prints them); `gd_lib.helper_basenames` is the rule.
- A new helper from a size split or extract goes into the facade's folder (`split_funcs.py` creates it). Splitting a loose facade needs no move first. A helper inside a folder: `split_funcs.py FILE` writes beside it (`--in-folder` for facade-less families).
- A move or rename carries `.uid` sidecars and every `res://` / bare path (`move_script_cluster.py`, below: scripts, scenes, `project.godot`, design, tools, `.grok`, `.github`, root md). Path length counts toward the 10KB floor.
- **Manual checks after any move or rename** (the tool cannot see these): grep prose globs (`dir/stem*.gd`, `stem_*`), the OLD basename of every renamed file repo-wide in md / yaml / py / json / gd (skip `design/changelog/`), string-built paths (`"res://scripts/" + ...`, `%s`), shot / smoke / tool code that names a script file, and the three external skills `wdb-size-split`, `wdb-reuse-brief`, `wdb-opt`, `wdb-doc-facade` in `/home/box/agent-data/workflows`. One batch, gates once (`design/tools.md` rule 10). Then editor import, `check_load_graph`, `check_code_map`, `check_script_cap`, `bot_warnscan --areas static --non-leak-diff`.

## Size split

If a file must be split:

1. Split into a helper in the stem folder (`act.gd`, `view.gd`, `boot.gd`, `text.gd`, … with a qualifier where the name would be generic or collide; see Cluster folders).
2. Keep the original facade (beside its stem folder) as the facade (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`: the facade preloads its helpers; helpers never preload the facade. If a helper needs facade-held `static var` state, use `var rt: Variant = load(RT_PATH)` then `rt.name` (see `publish.gd`). For a node script, the facade stays the owner of state and keeps one-line delegates; each moved instance func becomes `static func name(node: Variant, ...)` in a sibling `extends Object` helper that reads state as `node.field` (see `drive.gd`). Prove by a line-multiset compare against the original after stripping qualifiers, plus smokes before and after. `tools/facade_requal.py` qualifies moved names in the facade.
5. Godot 4 analyzes a parent script alone. Do not call methods that exist only on a child; call the helper module from the parent.
6. Never split files under a pinned archive commit. Slim `archives/docs/` copies are live-tree museum text only.
7. Split the largest first. One cluster per batch. Stop so the User can compile (web / chat: so the User can paste; Grok Bot: ship the PR, report, and follow the already-open Bot door before the next cluster).

The default new path a **size** split may create is that folder helper. On **Grok Bot** and **web / chat**, its body is **moved code**, not newly written logic.

Grok Bot size sweep: after the split, each resulting live `.gd` should be under 5KB when whole existing functions can move. If one existing function is itself over 5KB, leave it whole and report it. Never leave a touched file over 10KB if a legal split can fix it.

## Grok Bot — new shared modules

Grok Bot **MAY** create shared owners when near-identical behavior spans places. That is the extract or reuse Job-table sibling, not this recipe.

- Prefer a **NEW shared module** over growing an existing owner (example: tooltip placement / behavior across Anvil / Analyze / Forge / Inventory).
- Near-identical = same control flow (renamed locals OK), not vaguely similar features.
- Point at an existing owner only if it already **is** that concern **and** the addition will not blow the size cap.
- Never grow an owner just to avoid a new file.
- Grok Build does not use this Bot extract leash. Same-system APIs: just do. Cross-system owners: the build path file → **Stop and propose first**.
- Do not hunt the live tree to rediscover copies when the User already named the cluster. Do not treat `design/reuse-map.md` as an owners encyclopedia.

## Reuse (existing owners)

Hunt for copied logic only after size work on the current cluster, or when the active Bot flow is extract / staged reuse.

1. If the copy only lives inside one system, it belongs in a sibling of that facade — the size-split shape above. Not a new global owner.
2. If the copy is the same concern as an **existing** shared script **and** routing call sites there keeps that owner under the size cap, change the copies to call that script. Discover owners from the live tree + one `design/code-map.md` row, not from a standing reuse-map table. Short reminders that already ship:
   - menu tab / confirm / back / page: `scripts/ui/menu_pad.gd`
   - bottom prompt / hint strip: `scripts/ui/prompt_view.gd`
   - other existing shared scripts already in the tree (`theme.gd`, `menu_util.gd`, `tip.gd`, `plate_chrome.gd`, `tip_place.gd`, …) when they already expose the function
3. If nothing existing owns it, or the owner would blow the size cap: **Grok Bot** prefers a new shared module for near-identical spanning copies; otherwise leave the copies and report them. Do not add a new method on an existing owner just so the copies can fit. **Grok Build** may add a same-system method or helper; a new cross-system owner is propose-first.

Reuse against an existing owner is call-site edits plus using a function that already exists. Grok Bot extract to a new shared module is moved bodies into a new file, not invented logic. Do not merge pairs listed under **Do not merge** on the Bot extract job.

## Hostify, types, shared calcs

Compile pitfalls of facade + `static func(host, ...)` splits, typing rules for moved lines, and the one-helper rule for gameplay formulas used by smokes: `refactor-hostify.md`. Read it when a split or extract batch touches `host` helpers or a smoke asserts a gameplay number.

## Token rules

- Do not load the design corpus for a split. One `design/code-map.md` row + the cluster is enough. Open the reuse-map brief only from the Bot reuse job when that brief is not the empty template.
- Measure on-disk byte length (Get-Item Length / dir). Do not guess. Do not ReadAllText + GetByteCount just to size-check.
- Do not dump whole files on Grok Build or Grok Bot when a diff / PR is enough.
- Do not restyle, do not rewrite comments, do not rename for taste — on Grok Bot and web / chat size-splits. Grok Build feature work may rename or reshape inside one system per the build path file.

## After a split

Update `design/code-map.md` when a new sibling or shared module must be listed. Do not update topic design files unless behavior changed (a legal sweep does not change behavior). Do not write extract results into `design/reuse-map.md` from Bot; web / chat Phase 7 owns that staging brief.

## Parked folder moves

Do **not** fold these into a size split. Folder relocates use the Bot relocate job, not this recipe's size-split steps. Every `preload` / `load` / ExtResource path plus `design/code-map.md` rows must stay correct. No behavior change.

From repo root run `python3 tools/move_script_cluster.py` (flags: `--help`; catalog in design/tools.md). Modes: `--stem/--from-dir/--to-dir` (one cluster), `--plan plan.json` (`{to_dir: [files]}`), `--map map.json` (exact `{old_file: new_file}` moves and renames, for facade-out and trimmed names), `--list-cluster FACADE`. One run = one rewrite pass. It `git mv`s the files (+ `.uid`), rewrites `res://` and bare paths, and bare old basenames of renamed files (as the bare new basename), under `scripts/`, `design/`, scenes, `project.godot`, `tools/`, `.grok/`, `.github/` and the root md files (not `design/changelog/`), keeps BOM and CRLF, and writes `_logs/move-cluster/summary.txt`. Then do the manual checks in Cluster folders and run the editor import check.

New fat facade clusters move only on a User go (same tool). Prefer updating call sites over wrappers when external refs are few.

## Documentation facades

Script splits stay in this file. Topic markdown door + sibling splits are the doc-split recipe.
