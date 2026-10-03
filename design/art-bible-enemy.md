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
HANDS: "right" and "left" always mean the CHARACTER's own hands, never the viewer's. Facing Down the right hand is on the viewer's LEFT. Facing Right only the character's right side is toward the viewer. Facing Left only the left side is toward the viewer. Facing Up the right hand is on the viewer's RIGHT. Do not mirror a figure to make another.
All eight figures: identical proportions, palette and silhouette height, feet on one baseline, neutral standing, true pixel art, no anti-aliasing, no text, no grid lines.
```

Facing phrases (one per cell): Down "face and chest toward the viewer"; Up "back of head and back toward the viewer, no face visible"; Left "left profile, nose and toes point to the viewer's left"; Right "right profile, nose and toes point to the viewer's right"; Up-Left "three-quarter back view turned to the viewer's left, back and one cheek visible"; Up-Right same, to the right; Down-Left "three-quarter front view turned to the viewer's left, both eyes visible"; Down-Right same, to the right.

`{HAND_RULES}`, one clause per prop: "the {PROP} is in its right hand: on the viewer's left in the Down view, on the viewer's right in the Up view, on the near side in the Right view, and only the {VISIBLE_PIECE} shows in the Left view." Two-handed: name both hands and the grip.

## Recipe

1. Down figure first as its own `image_gen` (props and palette proof).
2. 3x3 sheet in one pass (best identity per `art-bible-character` Appendix D). Attach the Down figure when the tool accepts a reference.
3. Score every cell with the checklist; a cell that fails ONLY on props or hand is redone by `image_edit` of that cell against the passing Down cell with the failing clause restated first. Cap: 3 prompt revisions per failure class, then stop and report.
4. Checklist per cell: (a) every prop, no extras; (b) facing matches; (c) correct hand for that facing; (d) identity and palette match Down. All four to pass.
5. After accept: `plate_remap.py`, square, split, nearest-neighbor cleanup as the player Bible.

## Template notes (from the test run)

- Spell out each cell's viewer-side position of every prop and asymmetric armour piece (orc: pauldron on the LEFT shoulder, per view). Short clauses: long geometry paragraphs lowered facing accuracy.
- "Exactly one {PROP}" per prop. Two-handed prop: say it is in BOTH hands in EVERY figure, including Up with the haft seen from behind, and fix the grip ("right hand higher").
- Say "the Right figure is NOT a flipped Left figure; never mirror".

## Failure modes (observed, bible_* samples under the sessions path, not in git)

- The generator mirrors right-facing profile cells from left-facing ones. Orc v1: axe hand changed between views and the Up view had no axe. Archer v1 and v2: Right profile mirrored, so the bow sat in the right hand.
- Hand-per-prop holds in front, back and three-quarter views once each view's side is spelled out (orc v2 all 8, archer v2 seven of eight).
- Archer v3 added long near/far arm geometry for the profile cells and "Left and Right cells must look different": WORSE, most figures turned left-facing. Cap of 3 revisions reached for asymmetric two-hand-role props in profile cells; stopped.
- Prop-free and single-staff enemies pass as-is (wolf v1, shaman v1; skull visible in the far-hand Left view).
- Workaround for asymmetric props (bow): generate Down and the Left profile as references, then make the Right profile cell with `image_edit` of that cell against the passing Down cell, restating the hand first, and check it by eye. Mirroring is acceptable only for symmetric or two-handed props.
- The tester's image generator may differ from Build's: retest the final template once in Build before relying on it.

## Results (vision-described, needs a human glance)

P = pass, F = fail. Samples: bible_orc_v1, bible_archer_v1, bible_shaman_v1, bible_archer_v2, bible_orc_v2, bible_archer_v3, bible_wolf_v1 (1:1 sheets, 3x3).

| Enemy (best run) | Dn | DR | R | UR | Up | UL | L | DL |
|---|---|---|---|---|---|---|---|---|
| wolf v1 | P | P | P | P | P | P | P | P |
| shaman v1 | P | P | P | P | P | P | P | P |
| orc v2 (v1 failed props and hands) | P | P | P | P | P | P | P | P |
| archer v2 (v1 F, v3 worse) | P | P | F mirror | P | P | P | P | P |

