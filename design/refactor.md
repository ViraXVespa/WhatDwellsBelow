# Refactor recipe

Status: protocol  
Read when: splitting a live script; placing a new script or helper (Cluster folders); Bot split or extract flow

Grok Bot uses this file on every task; other paths only when they must split. Grok Build feature work is **not** a refactor (same-system APIs and helpers: the build path file; **No new code** does not bind it).

## No new code

Binds **Grok Bot** splits and extracts only: a refactor only rearranges what already exists.

- No features, tunables, comments, renames, reformats or drive-by cleanups; no better API; no generalizing two vaguely similar features.
- No helper that was not already in the tree, except a shared-module extract of **near-identical** existing bodies (same control flow; renamed locals OK).
- Minimum edits to relocate lines and keep compiling. Wiring is not new behavior: `: Type` on a moved line, `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`.
- A non-empty `design/reuse-map.md` brief may name small kits at the surface it states, not a widget framework.

## Cluster folders (placement rule; one copy)

The **facade stays beside its folder** in the area dir. Its **helpers live in a folder named by the stem, with the repeated stem trimmed**: `scripts/graphics/light_rt.gd` + `scripts/graphics/light_rt/hub_bake.gd`, `lights.gd`, `publish.gd`. Facade-less families that share a first token (two or more files) get a folder named by the token and no facade (`scripts/world/crystal/net.gd`, `crystal_place.gd`). Folders stay inside the existing area (`audio combat data debug dungeon graphics input ui world`, or root `scripts/`); depth stops at the stem folder. A cluster over 9 files splits one level into sibling stem folders (`playtest/`, `playtest_ai/`, `playtest_log/`). Loose single files stay loose. Facade names and `class_name`s never change.
- **Naming.** Drop the leading `<stem>_` (`light_rt_fov` -> `fov.gd`). Keep a qualifier (last stem token, then more, up to the full old name) when the trimmed name is generic (`util`, `parts`, `act`, `view`, `core`, `hub`, ... `gd_lib.GENERIC`), two characters or fewer, or equals another `.gd` basename in the repo: `playtest_ai_util` -> `ai_util.gd`, `light_stamp_k` -> `stamp_k.gd`, `hud_act` stays `hud_act.gd`. No second `util.gd` / `parts.gd`.
- **Basenames are unique repo-wide** (`check_script_cap.py` fails on `dupes=`). `split_funcs.py --dry-run` prints the names; rule: `gd_lib.helper_basenames`.
- A new helper from a split or extract goes into the facade's folder (`split_funcs.py` creates it; `--in-folder` for facade-less families). 
- A move or rename carries `.uid` sidecars and every `res://` / bare path (`move_script_cluster.py`, below).
- **Manual checks after any move or rename** (the tool cannot see these): prose globs (`dir/stem*.gd`, `stem_*`), the OLD basename of every renamed file repo-wide in md / yaml / py / json / gd (skip `design/changelog/`), string-built paths (`"res://scripts/" + ...`, `%s`), shot / smoke / tool code that names a script file, and the four `wdb-*` skills in `/home/box/agent-data/workflows`. One batch, gates once (`design/tools.md` rule 10). Then editor import, `check_load_graph`, `code_map.py check`, `check_script_cap`, `bot_warnscan --areas static --non-leak-diff`.

## Split recipe

1. Split into a helper in the stem folder (`act.gd`, `view.gd`, `boot.gd`, `text.gd`, ...; qualifier per Cluster folders).
2. Keep the original facade beside its folder (`App.playtest`, `PauseMenu.show_menu`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`: the facade preloads its helpers; helpers never preload the facade. If a helper needs facade-held `static var` state, use `var rt: Variant = load(RT_PATH)` then `rt.name` (see `publish.gd`). For a node script, the facade keeps state and one-line delegates; each moved instance func becomes `static func name(node: Variant, ...)` in a sibling `extends Object` helper that reads state as `node.field` (see `drive.gd`). Prove by a line-multiset compare against the original (qualifiers stripped) plus smokes before and after; `facade_requal.py` qualifies moved names in the facade.
5. Godot 4 analyzes a parent script alone: never call methods that exist only on a child; call the helper module from the parent.
6. Never split files under a pinned archive commit.
7. Split the largest first, one cluster per batch, then stop (Bot: ship the PR and report).

A helper is **moved code**, not new logic. The Bot's size targets are in `grok-bot-size.md`.

## New shared modules and reuse (Grok Bot)

Hunt for copies only after split work on the current cluster, or in the extract / staged reuse flow; not when the User already named the cluster.

- Near-identical = same control flow (renamed locals OK), not vaguely similar features. Do not merge pairs under **Do not merge** in the Bot extract job.
- Copy lives inside one system: a sibling of that facade (the split shape), not a new global owner.
- Same concern as an **existing** shared script and routing call sites there fits the owner (`grok-bot-extract.md`): call that script. Find owners from the live tree plus one `design/code-map.md` row (not `design/reuse-map.md`, which is not an owners encyclopedia). Known: menu tab / confirm / back / page `scripts/ui/menu_pad.gd`; prompt / hint strip `scripts/ui/prompt_view.gd`; also `theme.gd`, `menu_util.gd`, `tip.gd`, `plate_chrome.gd`, `tip_place.gd`.
- Otherwise prefer a **NEW shared module** (moved bodies) over growing an owner: never grow an owner just to avoid a new file, and do not add a method to an existing owner just so copies fit; if neither fits, leave the copies and report.
- Build: same-system method or helper is just-do; a new cross-system owner is asked first (build path file).

## Hostify, types, shared calcs

Compile pitfalls of facade + `static func(host, ...)` splits, typing rules for moved lines, and the one-helper rule for gameplay formulas used by smokes: `refactor-hostify.md`, when a split or extract touches `host` helpers or a smoke asserts a gameplay number.

## Tokens and after a split

One `design/code-map.md` row + the cluster is enough; do not load the design corpus, read bodies to measure them, or dump whole files when a diff will do. After a split update `design/code-map.md` when a new sibling or shared module must be listed; leave topic design files alone unless behavior changed. Bot does not write extract results into `design/reuse-map.md` (web / chat Phase 4 emit owns that brief).

## Parked folder moves

The Bot relocate job owns these, not a split. Every `preload` / `load` / ExtResource path and `design/code-map.md` row must stay correct; no behavior change.

`python tools/move_script_cluster.py` (modes and flags: `--help`; `--dry-run` first). One run = one rewrite pass: it `git mv`s files (+ `.uid`) and rewrites `res://` paths, bare paths and bare old basenames under `scripts/`, `design/`, scenes, `project.godot`, `tools/`, `.grok/`, `.github/` and root md (not `design/changelog/`), keeping BOM and CRLF. `--wrapper` stubs at old paths only when asked or when refs are too many to retarget; otherwise update call sites. Then the manual checks above and the editor import check. New fat facade clusters move only on a User go.
