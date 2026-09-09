# Animation Browser review briefs

Status: binding design  
Read when: packing an Animation Browser brief, regen tree, or review ledger  
See also: `design/art-pipeline.md`, `design/art-i2v.md`, `design/art-pack.md`, `design/debug.md`  
Code: `tools/anim_review_lib.py`, `tools/anim_review_pack.py`, `tools/anim_review_regen.py`, `tools/anim_review_tree.py`, `scripts/debug/anim_browser.gd`

Open this file from the door. Output under `tools/anim_review/` is gitignored.

The Animation Browser writes a local ledger at `tools/anim_review/review.json` (editor-only, gitignored). That file is not a game setting and is not part of `SaveStore`.

CLI:

- `python tools/anim_review_pack.py` — pack brief (`tools/anim_review/pack_brief.md` + `.json`). Repack notes are failure cases. Good on-disk locomotion clips (`walk`, `idle_to_walk`, `walk_to_idle`) are keep-behavior. Ignore Regenerate rows here.
- `python tools/anim_review_regen.py` — regen brief (`tools/anim_review/regen_brief.md` + `.json`). Regenerate notes plus the current `i2v_seeds.build_prompt` text for player clips. `i2v_action` keeps class keys (`attack_great_axe`, not `attack`). `gather` writes both tool prompts. Use this when editing MOTION / IDENTITY_LOCK / FACING_LOCK.
- `python tools/anim_review_tree.py` — wiped test tree at `tools/anim_review/regen_tree/<model>/<facing>/<anim>/`. Each player folder gets `source.png` (locked Bible cell, same scale/pad as `i2v_seeds.py --cell`), `prompt.txt`, and `notes.txt` when the User typed a note. The dest tree is deleted and rebuilt every run. Split the locked Bible with `dict(zip(CELL_NAMES, split_equal_3x3(...)))`; `split_equal_3x3` returns a list, not a name map.

`AnimScan` lists `gather_pickaxe` and `gather_hatchet` when those sequences exist, and falls back to `gather_{facing}_*` if a tool set is missing. `idle_to_walk` / `walk_to_idle` stay out of the browser list (repack-only).

Enemy clips in the regen brief / tree get a warning until that pipeline exists. Do not invent an enemy I2V path here.
