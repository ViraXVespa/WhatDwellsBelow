# Web / chat session flow: bug sweep

Status: protocol
Read when: User asks for a bug sweep (or “flag defects”, “sweep for bugs”)

For **web / chat** only. Grok Build and Grok Bot ignore it.

## Start

User names “bug sweep” (optionally with areas; default is all of `design/code-map.md`).
Read this file, then run the two passes below in order. Do not start Pass 2 until the re-validation table and the failure-mode checklist for the current system are written.

## Definition of a bug

A bug is any behavior that produces a wrong, incomplete, leaky, mismatched, or unintuitive player-visible result on a path the design contemplates.
Design docs are concept overviews, not exhaustive requirement lists. When the design is silent or high-level, judge from the code’s player-visible result and common-edge completeness.

This includes:
- Incorrect calculations, fallbacks, or state transitions (even if non-crashing)
- Incomplete happy-path edges the design contemplates
- Feel and presentation defects (wrong vertical motion, missing feedback, incorrect facing, visual leaks)
- Progression and economy gaps (overwrite instead of top-up, silent drops, off-by-one)
- Input and state lifetime issues (locks, cooldowns, or armed flags that do not decay or clear)
- Resource and lifecycle problems (mesh/texture leaks, repeated loads, missing cleanup on frequent paths)
- Unexpected behavior (UI focus issues, unnecessary menu steps, unintuitive flows)
- Collision/visual mismatch (shape center or offset does not match the visual node’s feet or bounds)
- Interact-group lifetime (node added to `"interact"`, `"gates"`, or `"boss_door"` and never removed or freed on the open/spent/hidden path)
- Multi-step flow desync (forge job, extract, restock, loadout enter, etc. can leave phase, item, or resource fields inconsistent after cancel, tab change, payment failure, or deferred rebuild)
- Unpaired free/hide

Do **not** treat the following as bugs:
- Missing defensive null/validity checks on paths whose construction order and invariants guarantee the node or value exists
- Silent fallbacks on missing assets when `prove.md` applies only to test/proof scripts
- Behavior that matches an open task’s stated rules or an explicit design note
- Persistence or idle states that the owning doc or code comments describe as intentional

Partial guards do **not** close an item. A validity check, string return, or early exit that does not sit on the exact path named in the re-validation table or the failure-mode checklist leaves the Finding open.

## Pass 1 — mandatory re-validation table (before any Findings)

Before writing Findings, output this table. Cite the proving line for each. If the current code still matches the failure mode, it is a Finding.

| File | What to prove | Failure mode if still true |
|------|---------------|----------------------------|
| `scripts/world/player/near_interact.gd` | Fresh path + shared statics re-validate with `is_instance_valid` | Stale/freed node returned |
| `scripts/data/progress/extract.gd` | UID miss / non-mailable re-adds or surfaces | Silent drop |
| `scripts/combat/projectile.gd` | `_flush` → `_resolve` has its own fresh validity test | Freed lock target resolved |
| `scripts/data/progress_quest/restock.gd` | Potion (and any stack) is top-up, not replace | Overwrite of partial charges |
| `scripts/combat/enemy/enemy_present.gd` | Y-pin after slide does not fight hop/fly/lift | Lift cancelled |
| `scripts/combat/threat.gd` | Distance / travel index is bounds-checked | Crash or wrong CL |
| animation clip helpers (`player_anim.gd`, `anim_loco.gd`, …) | Empty or missing clip does not blank the sprite; diagonals are not collapsed | Blank or wrong facing |
| `scripts/combat/hp_bar.gd` | Texture not recreated without free on every pulse | Leak |
| `scripts/combat/telegraph.gd` | Mesh not replaced without free on every show | Leak |
| any forge / extract multi-step job script | Cancel / tab / payment-failure restores or surfaces partial state | Silent abort / lost materials |

## Pass 1 — failure-mode checklist (per system)

For every system (or the areas named), after the body reads, answer each with yes/no + citation:

- Static or cached node references: re-validated with `is_instance_valid` on every read path (including flush and deferred)?
- Item removal / UID paths: miss or non-mailable re-adds, or can it silently drop?
- Slot or resource writes in multi-step flows: top-up/merge, or full replacement that discards partial state?
- Mesh / texture assignment on frequent paths: previous freed, or new one created every update?
- Forced position pins after physics: fights any lift, hop, fly, or knock?
- Array / distance indexing: every index bounds-checked?
- Animation / clip fallbacks: empty or missing clip leaves a texture, or can the sprite go blank?
- Interact-group nodes: removed from the group or freed on the open/spent/hidden/used path, and prompt still correct?

Any “yes” (bad result still possible) is a Finding unless an explicit design note or open task covers the exact behavior.

## Pass 2 — cross-system entry / caller / exit

After the table and checklist, for every paid or destructive action (forge, extract, analyze, pawn, warp, loadout commit, restock, etc.):

- List the entry points.
- List the callers (UI buttons, interact, deferred rebuilds, tab changes, pause, scene change).
- List the exit paths (success, cancel, failure, tab wipe, close).
- Flag any path that can leave phase, item, resource, or group state inconsistent or silent.

## Output format (mandatory)

**Findings**

(Full relevant body has been read. The code produces a wrong, incomplete, leaky, mismatched, or unintuitive player-visible result on a path the design contemplates. Cite the function. Partial guards do not close the item.)

**Needs investigation**

(Body or surrounding context not yet fully read, or the defect is not yet clear.)

**Meets requirements**

(Full checklist body-read, re-validation table emitted, failure-mode checklist answered, and no player-visible defect observed on those paths. Include the one-line “Failure modes: … — all clear / N Findings” citation.)

## Rules

* Do not drop an item because a partial guard exists elsewhere on the path, because the helper is thin, or because a previous sweep already noted it. Re-flag if the cited path still produces the bad result.
* On every turn, body-read as many remaining checklist items as the turn can hold. Request another turn only when no further files can be opened.
* No code changes during the sweep itself.
* When working out of a grok-build branch, do not add changelog files unless the User named changelog as the specific goal.
