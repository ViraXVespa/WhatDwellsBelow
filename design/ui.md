# Player UI, HUD, menus, recap

Status: binding design + live snapshot
Read when: changing HUD, pause tabs, recap, maps, toasts, interaction UIs, title, or loading
Code: `scripts/ui/hud.gd`, `hud_view.gd`, `hud_act.gd`, `touch_hud.gd`, `pause_menu.gd`, `pause_inv.gd`, `pause_skills.gd`, `pause_system.gd`, `menu_pad.gd`, `prompt_view.gd`, `gear_board.gd`, `gear_board_floor.gd`, `gear_board_tip.gd`, `gear_board_text.gd`, `gear_board_stats.gd`, `gear_board_act.gd`, `gear_board_sub.gd`, `progress_ui.gd`, `progress_ui_hub.gd`, `progress_ui_inv.gd`, `progress_ui_shop.gd`, `recap.gd`, `loader.gd`, `present.gd`, `theme.gd`, `scripts/title.gd`, `scripts/title_news.gd`, `scripts/data/game_ver.gd`
See also: `design/gear-ui.md`, `design/input.md`, `design/debug.md`, `design/inventory.md`, `design/skills.md`, `design/camera.md`, `design/versioning.md`, `design/save-tech.md`

## UI theme (playable surfaces)

Every player-facing UI and HUD element in the live path MUST be designed with dungeon theming and MUST NOT ship as a default, unskinned, or engine-debug control. This includes the gauntlet strip, pause menu, Extraction Gate UI, Ghost Shop, anvil, Floor Crystal loadout UI, quest UI, Controls Billboard, recap, maps, toasts, title / credit flow, confirmation prompts, the title “what’s new” overlay, the web touch overlay, and any other surface a normal player can open.

The secret debug menu (including Automated Playtest, profiles, Animation Browser chrome, Settings tab, and raw value editors) MAY use default or lightly skinned engine controls. Appearance there is not a Demo-Complete art requirement.

## Title / play menu

`scripts/title.gd` is the play menu. Overlay body lives in `scripts/title_news.gd`. The card MUST show `Version: {label}` from `version.json` at all times.

Buttons, top to bottom: Play (or Play — Male / Play — Female), Updates, Archives.

When the current label is newer than saved `last_seen_game_ver`, a “what’s new” overlay MUST appear on this menu before Play is used. Updates opens the same overlay on demand.

- Gamepad-first. A / Start or B / Esc dismisses, writes `last_seen_game_ver` to the current label, saves, and focuses Play.
- Overlay always lists every `changelog.json` entry, newest first (current series baked into JSON).
- Entries with `label` greater than `last_seen_game_ver` render bold / gold. First launch or wiped save: only the current build is marked new; older JSON rows still list.
- Older series: keep the in-series list, plus one control that opens `https://viraxvespa.github.io/WhatDwellsBelow/changelog/`.
- Body shape on screen: build label as a heading, key points, optional subpoints, then the Summary line. Markdown (`**bold**`, `` `code` ``) renders.
- Long lists scroll with mouse wheel and right stick. D-pad only moves Close / Earlier weeks.
- Text sits on a solid title-card panel. Play / Updates / Archives MUST NOT take focus while the overlay is open.

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

The web touch overlay sits on `CanvasLayer` 28 (HUD is 20, pause is 55). The move stick lives in the left half below the HUD. All virtual buttons sit in a two-column strip on the right, from the bottom safe edge up to just under the minimap, and must not cover the gauntlet strip or the minimap. A look-mode cue may appear under the minimap.

## Web touch overlay

Binding rules live in `design/input.md`. UI rules for this slice:

- Drawn in-theme (dark well, gold ring, pad glyphs). No default engine buttons.
- No right aim well. No lock button. Auto-aim stays on while the overlay is active.
- Hidden while `App.ui_open` so pause, gear, recap, title, and debug stay tappable.
- Hidden on title / foundation. Shown only in Placeholdia and the dungeon when the device check passes.
- Map well stays visible in Placeholdia but is disabled.
- Menus are finger-tap. Do not draw virtual A / B over an open menu.

## Pause menu

Opened with Menu / Start / Esc. Freezes gameplay.
Every menu (including this one) MUST open with valid initial focus so it is immediately navigable by gamepad.

Menu bindings are shared through `scripts/ui/menu_pad.gd` (`design/input.md`):
- A / Enter confirms the focused control. A second A confirms a pending prompt.
- B / Esc backs out of a nested layer (re-equip list, rebind page, pending prompt). At root, close the menu.
- LB / RB (or `[` / `]`) cycle the three pause tabs. They MUST NOT page the inventory stats card.

Select / Back (and extra actions such as drop / tip) render in a footer strip at the bottom-right of the menu panel via `PromptView.footer`. Button captions stay verbs only.

Exactly three tabs, navigable with LB/RB or equivalent:
1. Inventory – shared paper-doll gear board (`design/gear-ui.md`), 7-column bag grid, flyout tooltips, paged stats. Stats pages use **Q / LT** and **E / RT**. Use / consume / drop / equip as specified there, including mid-run weapon changes from the bag. Active artifact set bonuses appear on the Artifact sets stats page and in item flyouts.
2. Skills – list of the eleven skills with current level, XP bar to next level, and permanent XP total.
3. System – MUST open focused on the first System control, not the Inventory tab button, and MUST contain every one of the following:
   - Master / Music / SFX volume sliders
   - Camera zoom slider (1.0–2.5, default 1.75). MUST apply live; no restart.
   - HUD scale slider. MUST apply live.
   - Sprite filter cycle (on-spec only): Nearest / Nearest + mips / Nearest + mips + aniso. Default is nearest + mips + aniso. Linear modes MUST NOT appear here.
   - Aim-line toggle and opacity slider
   - Presentation mode switcher + Archives browser
   - Control rebinding screen
   - Character type switch (male / female)
   - Patreon link
   - “Delete Save Data” with confirmation
   - “Dispel” Avatar button with strong confirmation prompt

The full debug / balance menu is **no longer** present in the Pause Menu. In-test display options that are not approved for players live on the secret debug **Settings** tab (`design/debug.md`). Touch tap-window and stick deadzone sliders live there too.

Placeholdia inventory (same board, opened outside a run) MUST use Loadout option sources: starters, holds, and non-white bank items. Dungeon inventory MAY only list the equipped piece plus bag items of that slot.

## Extraction Gate UI

- Opens on interact with an active Extraction Gate.
- Shows a clear, scrollable list of every item currently in the player’s bag and equipped slots that can be extracted.
- Player can select individual items or use a “Send All” option.
- Confirmation step required before items are removed from the run and marked as banked.
- MUST be fully usable with gamepad only and readable from couch distance.
- Select / Back live in the shared footer, not on the Leave / Send buttons.

## Ghost Shop UI

- Lists available Artifacts (2–4) with short descriptions and prices.
- Player may purchase a maximum of two Artifacts per visit.
- Lists snacks with prices.
- Option to pawn any currently carried gear for a low gold return.
- Clean confirmation on every transaction.
- Active set bonuses are shown beneath artifact descriptions.

## Anvil UI

- Analyze / Forge tabs. LB / RB cycle those tabs. The tab row uses the shared header chrome (bumper glyphs, stretch, horizontal scroll).
- Analyze → First Forge → Re-forge flow with clear cost breakdown (gold, ore, root).
- Smithing level influence visible.
- Confirmation on every forge action.
- Stats paging on the shared board still uses Q / LT and E / RT.

## Loadout UI

- Opens only by interacting with the Floor Crystal in Placeholdia. There is no separate loadout station.
- Uses the shared gear board in `design/gear-ui.md`. Holds / starters / bank populate each slot list.
- Footer is `Floor: [−] [selected] [+] (Deepest floor: n)` then **Enter dungeon**. No character button and no top weapon / tool / deepest summary.
- Choose starting weapon and tool type (pickaxe or hatchet — locked for the run) from the doll slots. Starting floor is only a previously reached floor. Never backward.
- First focus is **Enter dungeon**. One press enters. B / Esc / Close cancels without entering.
- No tab strip. LB / RB do nothing. Stats pages use Q / LT and E / RT.
- Visual presentation MUST meet the same clean, dungeon-themed, TV-readable standard as the other interaction UIs.
- Esc / B on the re-equip list MUST NOT confirm enter or close the crystal UI.

## Gear tooltips

- Flyouts follow `design/gear-ui.md`. Hidden until hover, keyboard highlight, or activating the focused slot.
- **Y** cycles off → current item stats → forge preview.
- Active artifact set bonuses are shown in the flyout and on the Artifact sets stats page.
- Smithing level influence remains visible in Anvil UI.

## Quest UI

- Accessible from the guild in Placeholdia.
- Displays three random quests.
- Clear accept / decline flow.
- Active quest status visible where appropriate.

## Recap screen (mandatory sequence)

Triggered on every death or “Dispel”.
1. Display run statistics.
2. Play a clear visual sequence that shows each skill’s run XP value draining down to the permanent fragment amount.
3. After the drain completes, display the new permanent XP totals and the resulting levels.
4. Show gold and items successfully extracted (if any).
5. Title / subtitle variants according to performance, including verge states.
6. Special case: death or “Dispel” on floor 1 with an empty bag MUST include the exact flavor line “They lived just to die. What a waste.”
7. After the player dismisses recap, play the Placeholdia wake-up sequence.
8. Continue lives in the shared footer (`ui_accept`), not as a baked A / Enter caption.

## Minimap and large map

- Small minimap on HUD shows only visited tiles + important markers (stairs, crystal, Extraction Gates, shop, player).
- View / Back button opens a large full-screen map overlay. Gameplay continues underneath.
- The large map starts at fit-to-frame. Zoom in with wheel, pinch, or look-mode right stick. Zoom focus: cursor / pinch midpoint on pointer and touch; player marker on gamepad.
- When zoomed in past fit, pan with mouse drag, one-finger swipe (walk stick not claimed), or look-mode-off right stick. Clamp so the image cannot leave the frame. Zoom-out to fit recenters and disables pan.
- Large-map zoom does not change world `App.cam_zoom`.
- Fog of war and visited tracking follow the rules in `design/dungeon.md`.

## Toasts and floating combat text

- Floating damage / heal numbers: integers only, rise and fade quickly.
- Critical hits use yellow + magenta colored damage numbers (no extra “CRIT!” text).
- Toasts appear for bag-full, level-up, extraction success, and other system events. Short, readable, non-stacking or lightly stacking.

## Live snapshot — title

`title.gd` builds the card and focus graph. `title_news.gd` builds the overlay.
Play / Updates / Archives drop to `FOCUS_NONE` while the overlay is open. Close is the focused control. Right stick and mouse wheel move `ScrollContainer.scroll_vertical`. Overlay body is a `RichTextLabel` on an opaque panel.

## Live snapshot — HUD / pause

`hud.gd` facade plus `hud_view.gd` / `hud_act.gd`: strip top-left, minimap top-right, boss bar when near, toast, interact glyph row, look-mode cue under the minimap. Level string uses combat level and parenthetical style level.
Pause Skills also shows run XP earned this descent.
Inventory and loadout share `Board.build`. Bag grid is 7 columns. Stats pages: kit bonuses, combat, utility, artifacts (artifacts omitted on loadout). Stats card is not in the focus chain. Pages change with Q / LT and E / RT. Pause tabs change with LB / RB via `menu_pad.gd`. System opens focused on Character. Camera zoom and HUD scale write `App.set_zoom` / `App.set_hud_scale` and apply without a restart. Sprite filter cycles `App.set_sprite_filter` over the three nearest modes. Loadout opens focused on **Enter dungeon**.

## Live snapshot — web touch

`App` instances `scripts/ui/touch_hud.gd` and `scripts/web_pad.gd`. `touch_hud.gd` draws the move stick, the right-hand two-column strip, pinch, and map swipe; `touch_pad.gd` owns detection, move vector, and the attack latch. Overlay layer 28. Visibility is `TouchPad.wants_show()`. Large-map transform lives in `dungeon_map_act.gd`.

## Live snapshot — loading bar (`loader.gd`)

`CanvasLayer` layer 110 on `App`. Survives scene changes. Title → Placeholdia uses `App.play_from_menu` → `AppFlow.play_from_menu_async`.

- `begin(heading, status)` shows the overlay and seeds a small fill so the bar is never stuck at 0%.
- `set_status(text)`
- `set_progress(0..1)` only raises the target.
- `_process` eases `_shown` toward the target.
- `finish()` snaps to 100%, hides, calls `App.wake_web_pad()`.

Visual: full-viewport dim, heading, status, percent, 720×20 gold fill on a dark track. Positions are computed from `get_viewport().get_visible_rect()` so the overlay stays centered on desktop and the no-threads web export.

Play → camp pacing in `scripts/app_flow.gd`:
- Preload listed hub assets up to about 70%, with status lines for camp / tiles / buildings / delver / music.
- Ease toward 90% while still on the title scene.
- `go_camp()` (scene instantiate may hitch; the bar is already near the end).
- After camp is ready, ease 92% → 100% with “The square holds.”, then hide.