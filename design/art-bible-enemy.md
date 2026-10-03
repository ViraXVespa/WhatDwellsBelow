# Enemy directional Bible: prompts, props and hands

Status: binding design (one capped test run, vision-described, needs a human glance and a retest in Build: see Results)
Read when: prompting enemy directional reference sets, enemy props or hands per facing, enemy Bible test plan

art is already open when this sibling is loaded. Do not reopen art_pipeline from this file. Imagine runs only through the isolated-media gate (CLI Build). Structure only, not style.

## Where things stand

- Live enemy stills are ONE picture per type: `tools/pack_p4_enemies.py` copies it to five directions and flips it for `left`, `up_left`, `down_left`. `idle_up` shows the front, and flipped sheets swap every prop hand. There is no real directional set yet.
- Convention to reuse: 8 directions (Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right), 3x3 sheet with the same cell order as the player Bible (`art-bible-character`), centre cell = close-up, opaque `#FF00FF` plate, then `plate_remap.py`. `bible_prompt.py` prints player prompts only; copy the enemy template below by hand.
- Samples stay out of git: sessions path (`$WDB_GROK_SESSIONS`, `agent_log.grok_sessions()`), one folder per enemy.

## Hand geometry (camera south of the figure, "right/left" = the CHARACTER's own)

| Facing | Right hand | Left hand | Note |
|---|---|---|---|
| Down | viewer-left | viewer-right | both visible |
| Down-Right | near, viewer-left of body | far, partly behind | |
| Right | near side, fully visible | far, mostly hidden | |
| Up-Right | near, viewer-right | far, behind body | |
| Up | viewer-right | viewer-left | back view |
| Up-Left | far, viewer-right | near, viewer-left | |
| Left | far, mostly hidden | near side, fully visible | |
| Down-Left | far, viewer-left, behind body | near, viewer-right | |

Mirror rule: flipping Right gives a Left with the hands swapped (a right-hand prop lands in the left hand). Mirror only symmetric or two-handed props, or when the User accepts the swap; else generate Left, Up-Left, Down-Left on their own. A far-hand prop must still show a visible piece in profile (staff head, bow tip).

## Prop and hand table (single source for prompts)

No game data holds props (`roster.gd` has role and move only). Rows come from a vision read of the live stills; hands marked ? are unverified (User confirms; Build edits only this table).

| Enemy | Props (exactly these) | Hand | Notes |
|---|---|---|---|
| slime, bat, spider, wolf, beetle, wisp | none | - | prop-free; say "no weapons, no held items" |
| goblin | rusty knife | right ? | |
| orc | two-handed battle axe; one pauldron | axe both hands (right high ?); pauldron left shoulder | asymmetric armour |
| skeleton | rusted sword; purple cloak | sword right ?; cloak over left shoulder | |
| archer | longbow; arrow; back quiver | bow left, arrow draw right ? | quiver visible only from the back and the far-side profile |
| shaman | bone staff with horned skull | right ? | left hand tucked in sleeve |
| imp | small flame in each hand | both | symmetric |

## Prompt template (copy, fill the braces)

```
Create a single image: a perfect 3x3 Enemy Bible grid on solid pure magenta #FF00FF for the enemy "{ENEMY}" of "What Dwells Below": {BODY_DESC}.
Strict cell layout (do not swap, reverse or move any figure). Top row: Up-Left, Up, Up-Right. Middle row: Left, centre = head-and-shoulders close-up, Right. Bottom row: Down-Left, Down, Down-Right.
{FACING_PHRASES}
PROPS: this character owns exactly {PROP_LIST}. Every full-body figure shows every prop. {HAND_RULES} No other props, no extra limbs, no duplicated weapons.
HANDS: "right" and "left" mean the CHARACTER's own hands. Facing Down the right hand is at the image's LEFT edge side; facing Up, at the RIGHT edge side. In the Right figure only the right side is toward the camera; in the Left figure only the left. Do not mirror a figure to make another.
All eight figures: identical proportions, palette and silhouette height, feet on one baseline, neutral standing, true pixel art, no anti-aliasing, no text, no grid lines.
```

Facing phrases (one per cell): Down "face and chest toward the viewer"; Up "back of head and back toward the viewer, no face visible"; Left "profile, nose and toes point toward the LEFT EDGE of the image"; Right "...RIGHT EDGE"; Up-Left "three-quarter back view turned toward the LEFT EDGE, back and one cheek visible"; Up-Right same, RIGHT EDGE; Down-Left "three-quarter front view toward the LEFT EDGE, both eyes visible"; Down-Right same, RIGHT EDGE.

`{HAND_RULES}`, one clause per prop: "the {PROP} is in its right hand: at the image's left side in Down, right side in Up, near side in Right, and only the {VISIBLE_PIECE} shows in Left." Two-handed: name both hands and the grip.

## Recipe

1. Down figure first, alone (props and palette proof).
2. Symmetric, two-handed or single-fixed-hand types (wolf, shaman, orc): one 3x3 sheet in one pass (best identity per `art-bible-character` Appendix D). Asymmetric props (archer bow): NO sheet; one single-figure image per facing, assemble the cells.
3. Score every cell; a cell failing ONLY on props or hand is regenerated alone (or `image_edit` against the passing Down cell, restating the failing clause first). Cap: 3 prompt revisions per failure class, then stop and report.
4. Checklist per cell: (a) every prop, no extras; (b) facing matches; (c) correct hand for that facing; (d) identity and palette match Down. All four to pass.
5. After accept: `plate_remap.py`, square, split, nearest-neighbor cleanup as the player Bible.

## Template notes (from the test runs)

- Describe facing in image-edge terms ("viewer's RIGHT" was drawn facing left): "face, chest, bow and arrow point toward the RIGHT EDGE of the image; bow in the left hand = the arm farther from the camera, extended toward the right edge; right hand = near arm pulls the string; quiver on the left side of the image".
- Spell out each cell's side of every prop and asymmetric armour piece (orc: pauldron on the LEFT shoulder, per view). Keep clauses short (long geometry lowered facing accuracy).
- "Exactly one {PROP}". Two-handed prop: BOTH hands in EVERY figure, including Up with the haft seen from behind; fix the grip ("right hand higher").
- "The Right figure is NOT a flipped Left figure; never mirror" helps orc but does not stop sheet re-mirroring of asymmetric props.

## Failure modes (observed, bible_* and archer_* samples under the sessions path, not in git)

- The generator mirrors right-facing profile cells from left-facing ones. Orc v1: axe hand changed, Up view had no axe. Archer sheets v1, v2, v4: Right column mirrored (bow in the right hand); v4 also flipped the Down cell's hands.
- Archer v3 (long near/far arm geometry, "Left and Right cells must look different"): WORSE, most figures faced left. Cap of 3 revisions reached for sheets.
- Single-figure images work: archer_left_single P; archer_right_single v1 ("viewer's RIGHT") F, drawn facing left; v2 (edge wording) P.
- Wolf v1 and shaman v1 pass a sheet as-is (skull shows in the far-hand Left view).
- Mirroring is acceptable only for symmetric or two-handed props.
- The test generator may differ from Build's: retest the final template once in Build before relying on it.

## Results (vision-described, needs a human glance)

P = pass, F = fail. 11 images: 7 sheets (bible_orc_v1/v2, bible_archer_v1/v2/v3/v4, bible_shaman_v1, bible_wolf_v1) and 3 archer singles.

| Enemy (best run) | Dn | DR | R | UR | Up | UL | L | DL |
|---|---|---|---|---|---|---|---|---|
| wolf v1 | P | P | P | P | P | P | P | P |
| shaman v1 | P | P | P | P | P | P | P | P |
| orc v2 (v1 failed props and hands) | P | P | P | P | P | P | P | P |
| archer sheet v2 (v1, v3, v4 worse) | P | P | F mirror | P | P | P | P | P |
| archer singles (L v1; R v2 edge wording) | - | - | P | - | - | - | P | - |

