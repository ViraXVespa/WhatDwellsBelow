# Enemy directional Bible: layout, props and hands

Status: current plan (test runs vision-described; a human glance and a Build retest are still needed)
Read when: prompting enemy directional reference sets, enemy props or hands per facing

Imagine runs only through the isolated-media gate (CLI Build). Samples stay out of git (`$WDB_GROK_SESSIONS`, `agent_log.grok_sessions()`).

## Layout

- One 3x3 sheet per enemy in one pass (separate figures drift in look and palette). Cell order as the player Bible (`art-bible-character`): Up-Left, Up, Up-Right / Left, centre close-up, Right / Down-Left, Down, Down-Right.
- Opaque `#FF00FF` plate, then `plate_remap.py`, square, split, cleanup as the player Bible.
- Live enemy stills are ONE picture per type, copied to five directions and flipped for three (`pack_p4_enemies.py`), so there is no real directional set yet.

## Props, hands and the prompt (one home: the tool)

`python3 tools/bible_prompt.py --enemy ID` prints the filled prompt; `--list-enemies` lists the ids with props, hands and idle poses; `--body "clause"` sets the body description. The prop and hand table, the template, the edge wording and the idle rule live in `tools/bible_prompt.py`; edit them there. A `?` in the data is an unverified hand: the output marks it UNKNOWN and stderr names it. No `?` is open today.

**Idle rule (every bible that shows a held weapon or prop):** props are at rest, carried, never aimed, drawn or swung, so they can be animated later. Examples: bow hangs at the side in the left hand with the string undrawn and the arrow not nocked; axe held two-handed low; staff planted upright; crossbow lowered, muzzle down.

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

Never mirror a figure. A flipped Right is a Left with hands swapped: mirror only symmetric or two-handed props, or if the User accepts the swap. A far-hand prop still shows a piece in profile (staff head, bow tip).

## Checklist (score every cell; all must pass)

(a) every prop, no extras; (b) facing; (c) hand for that facing; (d) identity and palette consistent; (e) prop idle pose (at rest, not aimed or drawn, same size and height as the Left cell). Cap: 3 prompt revisions per failure class, then report.

## Lessons

- Describe facing in image-edge terms ("viewer's RIGHT" can be drawn facing left); spell out each cell's side of every prop and armour piece; keep clauses short.
- The generator tends to mirror right-facing cells from left-facing ones: archer v1-v4 had the Right column mirrored (bow in the right hand). Marker colours on hands do not fix it. Diagonal front cells tilt props down (say "level"; with the idle rule, say "at rest").
- Two-handed or fixed-hand props are stable (orc axe, shaman staff, crossbow in both hands).
- Hypothesis, untested: idle poses (bow down at the side, string undrawn) remove the right-profile bow mirroring, because there is no drawn bow to mirror. Retest the archer with the idle prompt, then once in Build (its generator may differ).

## Results (vision-described, needs a human glance)

14 images (11 sheets, 3 one-figure probes). Pass on all 8 directions: wolf v1, shaman v1, orc v2 (v1 failed props and hands), crossbowman v1. Crossbowman v2 (angle rule) tilted the prop down in Down-Left and Down-Right. Archer v1-v5: Right column mirrored (best v2); v3 worse.
