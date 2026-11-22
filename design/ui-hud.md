# HUD and web touch overlay

Status: current plan  
Read when: gauntlet HUD strip or web touch overlay  

## HUD – gauntlet strip (mandatory elements and behavior)

The HUD is a persistent horizontal strip that MUST remain visible at all times during dungeon play and MUST be readable from couch distance on a 1080p television.

| Required Element | Notes |
|------------------|-------|
| Player portrait | Center cell of the live bible lock (`assets/sprites/player/bible_locked_male.png` / `bible_locked_female.png`, the copy of `_src/new_bibles`). The chroma plate is keyed out. Bruise shows from about 88% HP, cuts from about 72%, blood from 50% and heavier toward 0. |
| HP bar with numeric value | |
| Potion quick-slot icon + cooldown sweep | Equipped potion icon and stack (`xN`). A clockwise dark sweep covers the icon while the cooldown runs. No seconds numeral and no separate bar. |
| Dash cooldown indicator | |
| Special cooldown indicator | Caption is “Special”, not a baked LT / RMB string |
| Level | Highest global Combat Level; if the equipped weapon’s style level is lower it appears in parentheses (e.g. `Level 14 (Magic 11)`) |
| Current gold | |
| Current ore / wood | |
| Current floor number | e.g. “F3” |
| Shrine buff icon + remaining time | Appears only while active |
| Equipped food icon + stack | Always shown. Empty slot art when nothing is equipped. The same clockwise sweep as the potion runs while a heal-over-time is active. |
| Red border glow | A red edge on the screen first appears at 50% HP and grows stronger toward 0%. Settings → UI, default on, saved. |
| Boss / Floor Guardian / Gate Master HP bar | Appears only while the boss is alive and in range / engaged |
| Interact prompt | Last-used `interact` glyph plus the verb from the focused interactable. Locked / spent lines are text only. A dark plate sits behind the line so the dungeon does not show through. |

There is no bag-fullness indicator and one MUST NOT appear.
All cooldowns MUST show both a visual fill/sweep and be understandable at a glance. Exact pixel positions, colors, and sizes are left to implementation so long as the information hierarchy is preserved and the strip does not obscure critical gameplay.

The web touch overlay sits on `CanvasLayer` 28 (HUD is 20, pause is 55). The move stick lives in the left half below the HUD. The right cluster is a 2×2 of large wells (attack / special / interact / dash) with a row of four small wells above it (map, food, potion, pause). Live anchor is about 86% across and 78% down the viewport, clamped off the bezel. The right cluster is uses 25% larger wells and grows toward the top-left so dash / special stay put. It must not cover the gauntlet strip or the minimap. A look-mode cue may appear under the minimap.

## Web touch overlay

Binding rules live in input. UI rules for this slice:

- Drawn in-theme (paper well, brown rule, ink glyph). No default engine buttons.
- No right aim well. No lock button. Auto-aim stays on while the overlay is active.
- Hidden while `App.ui_open` so pause, gear, recap, title, and debug stay tappable.
- Hidden on title / foundation. Shown only in Placeholdia and the dungeon when the device check passes, or when Debug Settings **Force touch overlay** is on (session-only; still hidden while `App.ui_open`).
- Map well stays visible in Placeholdia but is disabled.
- Menus are finger-tap. Do not draw virtual A / B over an open menu.
- Touch Attack is press-and-hold only. There is no double-tap latch.

## HUD / pause layout

- Metal-chain strip top-left: iron card, bone type, mana bar under HP, danger gem on the right of the same card. The chain border tiles at the texture's link size so the links stay square. The card is only as tall as its rows; the interact prompt sits under the card. Minimap top-right in a thin rule, boss bar when near, toast, interact glyph row, look-mode cue under the minimap.
- Meter fills keep their own colors inside iron troughs. Toast and look cue stay light because they sit on the world. The boss bar stays a flat meter.
- Level string: combat level with style level in parentheses. The danger gem compares walk-distance Threat CL with combat level (green at or under, yellow at +3, red at +7) and can be hidden from Settings → Graphics.
- Mana refills over time, from mana orbs, potions and food. A special does not start when mana is short.
- Pause Skills also shows run XP earned this descent.
- Inventory and loadout share one board. Bag grid is 7 columns. Stats pages: kit bonuses, combat, utility, artifacts (not on loadout). The stats card is not in the focus chain. Pages change with Q / LT and E / RT; pause tabs with LB / RB. Default tab is Settings; the current tab uses hover-panel chrome and darker tan text.
- Camera zoom, display mode, and sprite filter (Mipmaps / Anisotropic checkboxes) are on Settings → Graphics and apply without a restart. HUD scale, the red border glow, and the minimap size, opacity, zoom, and map toggle are on Settings → UI and apply without a restart. Alt+Enter also toggles display. Small windows scale HUD chrome and fonts from the saved text floor (default 14).
- Loadout opens focused on **Enter dungeon**.
- Confirm dialogs restore prior focus on cancel and draw Select / Back on the dialog. Prompts, tab chips and footers refresh when the input scheme flips.

## Web touch wiring

Touch overlay (move stick, right-hand cluster, pinch, map swipe) sits on layer 28 and shows only when touch is wanted.
