# Enemy directional Bible: prompts, props and hands

Status: binding design (one capped test run, vision-described, needs a human glance and a retest in Build: see Results)
Read when: prompting enemy directional reference sets, enemy props or hands per facing, enemy Bible test plan

Imagine runs only through the isolated-media gate (CLI Build). Structure only, not style.

## Where things stand

- Live enemy stills are ONE picture per type, copied to five directions and flipped for three (`pack_p4_enemies.py`): `idle_up` shows the front and flips swap prop hands. No real directional set yet.
- Reuse: 8 directions (Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right), 3x3 sheet with the same cell order as the player Bible (`art-bible-character`), centre cell = close-up, opaque `#FF00FF` plate, then `plate_remap.py`. `bible_prompt.py` prints player prompts only; copy the enemy template below by hand.
- Samples stay out of git: `$WDB_GROK_SESSIONS` (`agent_log.grok_sessions()`).

## Hand geometry (camera south of the figure, "right/left" = the CHARACTER's own)

| Facing | Right hand | Left hand |
|---|---|---|
| Down | viewer-left | viewer-right |
| Down-Right | near, viewer-left of body | far, partly behind |
| Right | near, fully visible | far, mostly hidden |
| Up-Right | near, viewer-right | far, behind body |
| Up | viewer-right | viewer-left |
| Up-Left | far, viewer-right | near, viewer-left |
| Left | far, mostly hidden | near, fully visible |
| Down-Left | far, viewer-left, behind body | near, viewer-right |

Mirror rule: flipping Right gives a Left with the hands swapped (a right-hand prop lands left). Mirror only symmetric or two-handed props, or when the User accepts the swap (option b below). A far-hand prop must still show a visible piece in profile (staff head, bow tip).

## Prop and hand table (single source for prompts)

No game data holds props (`roster.gd` has role and move only). Rows are a vision read of the live stills; ? = unverified (User confirms).

| Enemy | Props (exactly these) | Hand | Notes |
|---|---|---|---|
| slime, bat, spider, wolf, beetle, wisp | none | - | say "no weapons, no held items" |
| goblin | rusty knife | right ? | |
| orc | two-handed battle axe; one pauldron | axe both hands (right high ?); pauldron left shoulder | asymmetric armour |
| skeleton | rusted sword; purple cloak | sword right ?; cloak over left shoulder | |
| archer | longbow; arrow; back quiver | bow left, arrow draw right ? | quiver only from the back / far-side profile |
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

## Recipe (sheets are the only route)

Separate figures drift in look and palette: ONE 3x3 sheet in one pass per enemy.

1. Fill the template from the prop table; run the sheet.
2. Score every cell with the checklist: (a) every prop, no extras; (b) facing matches; (c) correct hand for that facing; (d) identity and palette consistent. All four to pass.
3. Cap: 3 prompt revisions per failure class, then stop and report.
4. After accept: `plate_remap.py`, square, split, cleanup as the player Bible.

Asymmetric props (bow) can fail the Right column. Options inside one sheet, choice OPEN for the User:
- (a) Symmetric or two-handed props, or a fixed-hand prop that tests stable (shaman staff, orc axe v2, crossbowman v1: one crossbow in BOTH hands passed all 8 directions). The archer would become a crossbowman.
- (b) Use the mirror rule above and accept the prop swapping hands on the Right cell.
- (c) Fix only the failing cell with an edit pass inside the finished sheet, then a human check.
Design question: does the archer keep the bow and accept (b) or (c), or become a crossbowman (a)?

## Template notes (from the test runs)

- Describe facing in image-edge terms in the sheet's cell clauses ("viewer's RIGHT" was drawn facing left): "face, chest, bow and arrow point toward the RIGHT EDGE of the image; bow in the left hand = the far arm, extended toward the right edge; right hand = near arm pulls the string".
- Spell out each cell's side of every prop and asymmetric armour piece (orc: pauldron on the LEFT shoulder, per view). Short clauses (long geometry lowered facing accuracy).
- "Exactly one {PROP}". Two-handed prop: BOTH hands in EVERY figure, including Up with the haft seen from behind; fix the grip ("right hand higher").
- "The Right figure is NOT a flipped Left figure; never mirror" helps orc, not asymmetric props.

## Failure modes (observed, bible_* and archer_* samples under the sessions path, not in git)

- The generator mirrors right-facing profile cells from left-facing ones. Orc v1: axe hand changed, no axe in Up. Archer v1, v2, v4: Right column mirrored (bow in right hand); v4 also flipped Down's hands.
- Archer v3 (long near/far arm geometry): WORSE, most figures faced left. Cap reached.
- Edge wording fixed facing in one-figure probes (archer_left_single P; archer_right_single v1 "viewer's RIGHT" F, v2 edge wording P). Not recommended: separate figures drift in look and palette.
- Marker colours do not fix handedness: archer v5 (red left glove, blue right glove, bow always in the red-glove hand) ignored the colours, read Up/Down rows as aim-up/aim-down poses and mirrored the right column. Wolf v1 and shaman v1 pass as-is.
- The test generator may differ from Build's: retest the final template once in Build.

## Results (vision-described, needs a human glance)

P = pass, F = fail. 13 images: 10 sheets (bible_orc_v1/v2, bible_archer_v1-v5, bible_shaman_v1, bible_wolf_v1, bible_crossbowman_v1) and 3 one-figure probes.

| Enemy (best run) | Dn | DR | R | UR | Up | UL | L | DL |
|---|---|---|---|---|---|---|---|---|
| wolf v1 | P | P | P | P | P | P | P | P |
| shaman v1 | P | P | P | P | P | P | P | P |
| orc v2 (v1 failed props and hands) | P | P | P | P | P | P | P | P |
| crossbowman v1 (minor hand wobble on 3/4, glance) | P | P | P | P | P | P | P | P |
| archer sheet v2 (v1, v3-v5 worse) | P | P | F mirror | P | P | P | P | P |
| archer one-figure probes (not recommended: drifts) | - | - | P | - | - | - | P | - |

