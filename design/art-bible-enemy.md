# Enemy directional Bible: prompts, props and hands

Status: binding design (prompt recipe UNTESTED: see Results)
Read when: prompting enemy directional reference sets, enemy props or hands per facing, enemy Bible test plan

art is already open when this sibling is loaded. Do not reopen art_pipeline from this file. Imagine runs only through the isolated-media gate (CLI Build; Web and Bot never generate). Style is not locked here: only structure.

## Where things stand

- Live enemy stills are ONE picture per type: `tools/pack_p4_enemies.py` copies it to five directions and flips it for `left`, `up_left`, `down_left`. `idle_up` shows the front, and flipped sheets swap every prop hand. There is no real directional set yet.
- Convention to reuse: 8 directions (Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right), 3x3 sheet with the same cell order as the player Bible (`art-bible-character`), centre cell = close-up, opaque `#FF00FF` plate, then `plate_remap.py`. `bible_prompt.py` prints player prompts only; the enemy template below is copied by hand until the User approves extending it (`--enemy ID` reading the table here).
- Sample images stay out of git: store under the sessions path (`$WDB_GROK_SESSIONS`, default `C:\Users\Vira\.grok\sessions`, `agent_log.grok_sessions()`), one folder per enemy, and cite names in the report.

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

Mirror rule: a horizontal flip of Right is a valid Left only with the hands swapped. A right-hand prop would land in the left hand. Mirror only props that are symmetric or two-handed, or when the User accepts the swap; otherwise generate Left, Up-Left and Down-Left on their own. A far-hand prop must still show a visible piece (blade tip, bow tip, staff head) in profile.

## Prop and hand table (single source for prompts)

No game data holds props (`roster.gd` has role and move only). Rows come from the live stills (vision read of `idle_right.png`); hands marked ? are unverified. User: confirm or correct; Build then edits only this table.

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

Facing phrases (one per cell, say the body part that proves it): Down "face and chest toward the viewer"; Up "back of head and back toward the viewer, no face visible"; Left "left profile, nose and toes point to the viewer's left"; Right "right profile, nose and toes point to the viewer's right"; Up-Left "three-quarter back view turned to the viewer's left, back and one cheek visible"; Up-Right same, to the right; Down-Left "three-quarter front view turned to the viewer's left, both eyes visible"; Down-Right same, to the right.

`{HAND_RULES}` is built from the table, one clause per prop: "the {PROP} is in its right hand: on the viewer's left in the Down view, on the viewer's right in the Up view, on the near side in the Right view, and only the {VISIBLE_PIECE} shows in the Left view." For a two-handed prop name both hands and the grip order.

## Recipe

1. Down figure first as its own `image_gen` (props and palette proof); the User picks it.
2. 3x3 sheet in one pass (best identity per `art-bible-character` Appendix D). Attach the Down figure when the tool accepts a reference.
3. Score every cell with the checklist; a cell that fails ONLY on props or hand is redone by `image_edit` of that cell against the passing Down cell with the failing clause restated and the facing phrase repeated first. Cap: 3 prompt revisions per failure class, then stop and report.
4. Checklist per cell: (a) every prop present, no extras; (b) facing matches the phrase; (c) each prop in the correct hand for that facing; (d) identity and palette match Down. Pass needs all four.
5. After accept: `plate_remap.py`, square and split as the player Bible, nearest-neighbor cleanup.

## Failure modes to expect (hypotheses, not yet observed)

- Prop dropped in back and three-quarter views: restate the prop in every cell clause.
- Hand swap or mirrored figure in Left cells: forbid mirroring in words, name the near hand, verify against the geometry table.
- Duplicated or two-sided weapon (axe on both sides, two bows): "exactly one {PROP}".
- Facing drift to the front in Up cells: put "no face visible" in the phrase.
- Palette drift between cells: edit from the Down figure instead of regenerating the sheet.

## Results (tested enemy x direction)

Image generation was not available to the Bot session that wrote this doc, so nothing was generated. Test plan: orc (two-handed + pauldron), archer (bow, arrow, quiver), wolf (prop-free), shaman (single staff, one hand).

| Enemy | Dn | DR | R | UR | Up | UL | L | DL |
|---|---|---|---|---|---|---|---|---|
| orc | - | - | - | - | - | - | - | - |
| archer | - | - | - | - | - | - | - | - |
| wolf | - | - | - | - | - | - | - | - |
| shaman | - | - | - | - | - | - | - | - |

`-` = not run. Fill with P/F plus the failed checklist letter; record the minimal phrasing that passed under Failure modes.
