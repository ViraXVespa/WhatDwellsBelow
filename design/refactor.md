# Refactor recipe

Status: protocol  
Read when: splitting a live script for size; Copilot every task; Grok Build when an edit is over 10KB; web / chat Phase 6  
See also: `AGENTS.md`, `design/copilot-session.md`, `design/README.md`

This file is the mechanical recipe. Session flow lives in the path files. Copilot uses this file on every task. Other paths use it only when they must split.

## Caps

| Rule | Who |
|------|-----|
| Ship floor: every live `scripts/**/*.gd` under **10,000 bytes** | Every path that ships a `.gd` |
| Sweep target: each resulting file under **5,000 bytes** when existing code can move | Copilot only (`design/copilot-session.md`) |

Grok Build and web / chat stop once the file is under 10KB. They do not keep splitting toward 5KB.

Do not split a file that is already under the cap that applies to the current path, except Copilot reuse (call sites → existing owner).

## No new code

Grok writes behavior. A refactor only rearranges what already exists.

- Do not add features, tunables, comments, docs-of-taste, renames, reformats, or “while I’m here” cleanups.
- Do not invent a better API. Do not generalize two similar functions into a new one.
- Do not add a helper function that was not already in the tree.
- Do not create `scripts/util/` or any other new shared module.
- Edits are the minimum needed to relocate existing lines and keep the project compiling.

Adding `: Type` on a line already being moved, a `load()` / `preload()`, a one-line facade delegate, or `host` / `pt` / `ui` / `p` on a moved `static func` is wiring, not new behavior.

## Size split

If a file must be split:

1. Split into a sibling helper (`*_act.gd`, `*_view.gd`, `*_boot.gd`, `*_text.gd`, …).
2. Keep the original path as the facade (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Helpers are `static func` with `host` / `pt` / `ui` / `p` first.
4. No circular `preload()`. Use `load()` on one side or put shared state on the host.
5. Godot 4 analyzes a parent script alone. Do not call methods that exist only on a child; call the helper module from the parent.
6. Never split files under a pinned archive commit. Slim `archives/docs/` copies are live-tree museum text only.
7. Split the largest first. One cluster per batch. Stop so the User can compile (web / chat: so the User can paste; Copilot: report and ask before the next cluster).

The only new path this recipe may create is that sibling helper. Its body is **moved code**, not newly written logic.

Copilot: after the split, each resulting live `.gd` should be under 5KB when whole existing functions can move. If one existing function is itself over 5KB, leave it whole and report it. Never leave a touched file over 10KB if a legal split can fix it.

## Reuse

Hunt for copied logic only after size work on the current cluster, or when the cluster *is* a reuse item.

1. If the copy only lives inside one system, it belongs in a sibling of that facade — the size-split shape above. Not a new global owner.
2. If the copy is the same concern as an **existing** shared script, change the copies to call that script. Live owners include:
   - menu tab / confirm / back / page: `scripts/ui/menu_pad.gd`
   - bottom prompt / hint strip: `scripts/ui/prompt_view.gd`
   - other existing shared scripts already in the tree (`theme.gd`, `pause_menu_util.gd`, `gear_board_tip.gd`, …) when they already expose the function
3. If nothing existing owns it, **leave the copies**. Report them. Do not write a new owner. Do not add a new method on the owner so the copies can fit.

Reuse is call-site edits plus using a function that already exists. It is not a new abstraction.

## Types

`AGENTS.md` → GDScript types. On lines already being moved or rewritten:

- `:=` only for literals / typed built-ins Godot 4.7 infers (`0`, `1.5`, `true`, `"male"`, `Vector2.DOWN`, …).
- Otherwise `var name: Type = ...`.
- Typed `func` / `static func` args and `->` return.

Do not retype a whole file for style.

## Token rules

- Do not load the design corpus for a split. Code map row + the cluster is enough.
- Measure UTF-8 bytes on the target files. Do not guess.
- Do not dump whole files on Grok Build or Copilot when a diff is enough.
- Do not restyle, do not rewrite comments, do not rename for taste.
- Do not combine a refactor with a feature.
- Web / chat still emits full files in Phase 4 / Phase 6 as `design/web-session.md` requires. This recipe does not change emit shape.

## After a split

Update the `design/README.md` code map when a new sibling must be listed. Do not update topic design files unless behavior changed (a legal sweep does not change behavior).

Copilot sweep notes: `_logs/copilot-sweep.md` per `design/copilot-session.md`. Not `design/sessions.md`. Not `design/changelog/`.