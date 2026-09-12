# HUD and web touch overlay

Status: binding design
Read when: gauntlet HUD strip or web touch overlay
See also: `design/ui.md`, `design/ui-theme.md`, `design/ui-title-web.md`, `design/ui-pause.md`, `design/ui-run-flow.md`, `design/ui-gear-entry.md`, `design/gear-ui.md`, `design/hub.md`, `design/input.md`, `design/doc-refactor.md`

## HUD – gauntlet strip (mandatory elements and behavior)

The HUD is a persistent horizontal strip that MUST remain visible at all times during dungeon play and MUST be readable from couch distance on a 1080p television.

| Required Element | Notes |
|------------------|-------|
| Player portrait | |
| HP bar with numeric value | |
| Potion quick-slot icon + cooldown sweep / numeric cooldown | |
| Dash cooldown indicator | |
| Special cooldown indicator | Caption is “Special”, not a baked LT / RMB string |
| Level | Highest global Combat Level; if the equipped weapon’s style level is lower it appears in parentheses (e.g. `Level 14 (Magic 11)`) |
| Current gold | |
| Current ore / wood | |
| Current floor number | e.g. “F3” |
| Shrine buff icon + remaining time | Appears only while active |
| Food heal-over-time icon + remaining time | Appears only while a food effect is active |
| Boss / Floor Guardian / Gate Master HP bar | Appears only while the boss is alive and in range / engaged |
| Interact prompt | Last-used `interact` glyph plus the verb from the focused interactable. Locked / spent lines are text only |

Bag-fullness indicator is explicitly removed and MUST NOT appear.
All cooldowns MUST show both a visual fill/sweep and be understandable at a glance. Exact pixel positions, colors, and sizes are left to implementation so long as the information hierarchy is preserved and the strip does not obscure critical gameplay.

The web touch overlay sits on `CanvasLayer` 28 (HUD is 20, pause is 55). The move stick lives in the left half below the HUD. The right cluster is a 2×2 of large wells (attack / special / interact / dash) with a row of four small wells above it (map, food, potion, pause). Live anchor is about 86% across and 78% down the viewport, clamped off the bezel. The right cluster is 25% larger than the pre-tune wells and grows toward the top-left so dash / special stay put. It must not cover the gauntlet strip or the minimap. A look-mode cue may appear under the minimap.

## Web touch overlay

Binding rules live in `design/input.md`. UI rules for this slice:

- Drawn in-theme (dark well, gold ring, pad glyphs). No default engine buttons.
- No right aim well. No lock button. Auto-aim stays on while the overlay is active.
- Hidden while `App.ui_open` so pause, gear, recap, title, and debug stay tappable.
- Hidden on title / foundation. Shown only in Placeholdia and the dungeon when the device check passes, or when Debug Settings **Force touch overlay** is on (session-only; still hidden while `App.ui_open`).
- Map well stays visible in Placeholdia but is disabled.
- Menus are finger-tap. Do not draw virtual A / B over an open menu.
- Touch RT is press-and-hold only. There is no double-tap latch.

## Live snapshot — HUD / pause

`hud.gd` facade plus `hud_view.gd` / `hud_act.gd`: strip top-left, minimap top-right, boss bar when near, toast, interact glyph row, look-mode cue under the minimap. Level string uses combat level and parenthetical style level.
Pause Skills also shows run XP earned this descent.
Inventory and loadout share `Board.build`. Bag grid is 7 columns. Stats pages: kit bonuses, combat, utility, artifacts (artifacts omitted on loadout). Stats card is not in the focus chain. Pages change with Q / LT and E / RT. Pause tabs change with LB / RB via `menu_pad.gd`. Default tab is Settings (`pause_settings.gd`). The current tab uses hover-panel chrome and darker tan text. Camera zoom and HUD scale write `App.set_zoom` / `App.set_hud_scale` and apply without a restart. Display mode writes `DisplayMode.cycle_desktop` or `DisplayMode.toggle_web_fullscreen` from Settings → Graphics. Alt+Enter also toggles display through `DisplayMode.handle_input`. Small windows multiply HUD chrome and Theme fonts by `UiText.applied()` from a saved text floor (debug slider, default 14). Sprite filter is Mipmaps / Anisotropic checkboxes through `App.set_sprite_filter`. Loadout opens focused on **Enter dungeon**.
`confirm_dlg.gd` restores prior focus on cancel and draws Select / Back on the dialog itself. `PromptView.pulse()` refreshes tab chips, gear page glyphs, and footers when `Pad.mode` flips.

## Live snapshot — web touch

`App` instances `scripts/ui/touch_hud.gd` and `scripts/web_pad.gd`. `touch_hud.gd` draws the move stick, the right-hand cluster, pinch, and map swipe; `touch_pad.gd` owns detection, move vector, and `force_show`. Overlay layer 28. Visibility is `Touch.wants_show()`. Large-map transform lives in `dungeon_map_act.gd`.

