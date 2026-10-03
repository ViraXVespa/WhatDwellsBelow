# Enemy directional Bible: prompts, props and hands

Status: binding design (capped test runs, vision-described, human glance and Build retest needed: see Results)
Read when: prompting enemy directional reference sets, enemy props or hands per facing, enemy Bible test plan

Imagine runs only through the isolated-media gate (CLI Build). Structure, not style.

## Where things stand

- Live enemy stills are ONE picture per type, copied to five directions and flipped for three (`pack_p4_enemies.py`): `idle_up` shows the front and flips swap prop hands. No real directional set yet.
- Reuse: 8 directions (Up, Down, Left, Right and the four diagonals), 3x3 sheet with the same cell order as the player Bible (`art-bible-character`), centre cell = close-up, opaque `#FF00FF` plate, then `plate_remap.py`.  `bible_prompt.py` is player-only; copy the template below by hand.
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

Mirror rule: a flipped Right is a Left with hands swapped. Mirror only symmetric or two-handed props, or if the User accepts the swap (option b). A far-hand prop must still show a piece in profile (staff head, bow tip).

## Prop and hand table (single source for prompts)

No game data holds props. Rows: vision read of live stills; ? = unverified.

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
Strict cell layout, never swap or reverse a figure. Top row: Up-Left, Up, Up-Right. Middle row: Left, centre = head-and-shoulders close-up, Right. Bottom row: Down-Left, Down, Down-Right.
{FACING_PHRASES}
PROPS: this character owns exactly {PROP_LIST}. Every full-body figure shows every prop. {HAND_RULES} No other props, extra limbs or duplicated weapons.
PROP ANGLE: each prop points where its figure faces, level at chest height, never tilted: Down end-on toward the camera, Up away (stock end only), Left/Right horizontal toward that edge, diagonals diagonally. Same size and height in all eight.
HANDS: "right" and "left" mean the CHARACTER's own hands. Facing Down the right hand is at the image's LEFT edge side; facing Up, at the RIGHT edge side. In Right only the right side faces the camera; in Left only the left. Never mirror a figure.
All eight figures: identical proportions, palette and silhouette height, feet on one baseline, neutral standing, true pixel art, no anti-aliasing, text or grid lines.
```

Facing phrases (one per cell): Down "face and chest toward the viewer"; Up "back toward the viewer, no face"; Left "profile, nose and toes point toward the LEFT EDGE of the image"; Right "...RIGHT EDGE"; Up-Left "three-quarter back view toward the LEFT EDGE, one cheek visible"; Down-Left "three-quarter front view toward the LEFT EDGE, both eyes visible"; Up-Right and Down-Right same, RIGHT EDGE.

`{HAND_RULES}`, one clause per prop: "the {PROP} is in its right hand: at the image's left side in Down, right side in Up, near side in Right, and only the {VISIBLE_PIECE} shows in Left." Two-handed: name both hands and the grip.

## Recipe (sheets are the only route)

Separate figures drift in look and palette: ONE 3x3 sheet in one pass per enemy.

1. Fill the template from the prop table; run the sheet.
2. Score every cell with the checklist: (a) every prop, no extras; (b) facing; (c) hand for that facing; (d) identity and palette consistent; (e) prop angle, length and height match the Left cell. All to pass.
3. Cap: 3 prompt revisions per failure class, then report.
4. After accept: `plate_remap.py`, square, split, cleanup as the player Bible.

Asymmetric props (bow) can fail the Right column. Options in one sheet, OPEN for the User:
- (a) Symmetric or two-handed props, or a fixed-hand prop that tests stable (shaman staff, orc axe v2, crossbowman v1: one crossbow in BOTH hands passed all 8 directions).
- (b) Use the mirror rule above and accept the prop swapping hands on the Right cell.
- (c) Fix only the failing cell with an edit pass inside the finished sheet, then a human check.
Design question: does the archer keep the bow and accept (b) or (c), or become a crossbowman (a)?

## Template notes (from the test runs)

- Describe facing in image-edge terms ("viewer's RIGHT" was drawn facing left): "face, chest, bow and arrow point toward the RIGHT EDGE of the image; bow in the left hand = the far arm, extended toward the right edge; right hand = near arm pulls the string".
- Spell out each cell's side of every prop and armour piece (orc pauldron: LEFT shoulder). Keep clauses short (long geometry hurt facing).
- "Exactly one {PROP}". Two-handed prop: BOTH hands in EVERY figure, including Up with the haft seen from behind; fix the grip.
- "Right is NOT a flipped Left" helps orc, not asymmetric props.

## Failure modes (observed; samples not in git)

- The generator mirrors right-facing profile cells from left-facing ones. Orc v1: axe hand changed, no axe in Up. Archer v1, v2, v4: Right column mirrored (bow in right hand); v4 also flipped Down's hands.
- Archer v3 (long near/far arm geometry): WORSE, most figures faced left. Cap reached.
- Edge wording fixed facing in one-figure probes (archer_left_single P; archer_right_single v1 "viewer's RIGHT" F, v2 edge wording P); not recommended, figures drift.
- Marker colours do not fix handedness: archer v5 (red left glove, blue right, bow in the red-glove hand) ignored the colours, read Up/Down as aim-up/aim-down and mirrored the right column.
- Diagonal front cells tend to tilt the prop down: say "level, not tilted" in those cells and check. Crossbowman v2: Down-Left/Right tilted, six others level, same size, Down foreshortened right. Close-up has no crossbow (head only, fine). Mirrored cells swap hands (fine for two-handed props).
- The test generator may differ from Build's: retest the final template once in Build.

## Results (vision-described, needs a human glance)

P = pass, F = fail. 14 images: 11 sheets (orc v1-2, archer v1-5, shaman, wolf, crossbowman v1-2) and 3 one-figure probes (see Failure modes).

| Enemy (best run) | Dn | DR | R | UR | Up | UL | L | DL |
|---|---|---|---|---|---|---|---|---|
| wolf v1 | P | P | P | P | P | P | P | P |
| shaman v1 | P | P | P | P | P | P | P | P |
| orc v2 (v1 failed props and hands) | P | P | P | P | P | P | P | P |
| crossbowman v1 (minor hand wobble on 3/4, glance) | P | P | P | P | P | P | P | P |
| crossbowman v2 (angle rule; DR, DL prop tilted down) | P | F | P | P | P | P | P | F |
| archer sheet v2 (v1, v3-v5 worse) | P | P | F mirror | P | P | P | P | P |

