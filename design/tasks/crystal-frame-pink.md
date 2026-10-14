# Crystal frame studs: stop deriving from the mis-keyed pink

id: crystal-frame-pink
owner: build
status: blocked
done-when: After rekey-assets, crystal_art.gd stud colours come from the rekeyed crystal (not the magenta keying remnant), frame art rebaked, Vira approves the loadout/floor crystal shots.
resume: python tools/bake_frame_art.py --check
needs: rekey-assets

## Task (her words)
The pink crystal decorations on the crystal UI frame came from the erroneous keying of the crystal asset. She likes the look and wants it left for now. After the assets are all rekeyed, update the crystal frame art so it is not derived from the mis-keyed pink.

## Where the pink comes from
- Source: the hub crystal sprite `assets/sprites/props/crystal.png` was keyed with magenta left in (pink/magenta pixels such as (182, 59, 165) remain on the gem edge). That keying is what `rekey-assets` redoes.
- The loadout/floor crystal frame art copied that pink: `scripts/ui/progress_ui/crystal_art.gd` consts `PINK` (0.93, 0.24, 0.55) and `PINK_LIT` (1.0, 0.74, 0.86), drawn by `_spark` as the four diamond studs (the two plinth corners at (36, 332) and (404, 332), the two upper ones at (78, 292) and (362, 292)).
- The baked frame PNG `assets/ui/frames/crystal/body.png` carries those studs (rebake with `python tools/bake_frame_art.py`; the frame-art smoke check must stay passing).

## Steps
1. Wait for `rekey-assets` to land and Vira to accept the rekeyed `crystal.png`.
2. Pick the stud colours from the rekeyed crystal (gem accent), not from the old magenta, and replace `PINK` / `PINK_LIT` in `crystal_art.gd`.
3. Rebake the crystal frame art and shoot loadout and floor crystal before/after for her.

## Open questions
- Whether she wants the studs kept as a design accent in a new colour, or removed.

## Related
- ui-png-art owns the new crystal background graphic (floor/loadout/teleport). This task keeps the studs only.
