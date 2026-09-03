# Player UI, HUD, menus, recap

Status: binding design + live snapshot
Read when: changing HUD, pause tabs, recap, maps, toasts, interaction UIs, or loading
Code: `scripts/ui/hud.gd`, `pause_menu.gd`, `pause_inv.gd`, `pause_skills.gd`, `pause_system.gd`, `menu_pad.gd`, `gear_board.gd`, `gear_board_floor.gd`, `gear_board_tip.gd`, `gear_board_text.gd`, `gear_board_stats.gd`, `gear_board_act.gd`, `gear_board_sub.gd`, `progress_ui.gd`, `progress_ui_hub.gd`, `progress_ui_inv.gd`, `progress_ui_shop.gd`, `recap.gd`, `loader.gd`, `present.gd`, `theme.gd`
See also: `design/gear-ui.md`, `design/input.md`, `design/debug.md`, `design/inventory.md`, `design/skills.md`, `design/hud.md`

## UI theme (playable surfaces)

Every player-facing UI and HUD element in the live path MUST be designed with dungeon theming and MUST NOT ship as a default, unskinned, or engine-debug control. This includes the gauntlet strip, pause menu, Extraction Gate UI, Ghost Shop, anvil, Floor Crystal loadout UI, quest UI, Controls Billboard, recap, maps, toasts, title / credit flow, confirmation prompts, and any other surface a normal player can open.

The secret debug menu (including Automated Playtest, profiles, Animation Browser chrome, and raw value editors) MAY use default or lightly skinned engine controls. Appearance there is not a Demo-Complete art requirement.

## HUD – gauntlet strip (mandatory elements and behavior)

The HUD is a persistent horizontal strip that MUST remain visible at all times during dungeon play and MUST be readable from couch distance on a 1080p television.

| Required Element | Notes |
|------------------|-------|
| Player portrait | |
| HP bar with numeric value | |
| Potion quick-slot icon + cooldown sweep / numeric cooldown | |
| Dash cooldown indicator | |
| Special (LT) cooldown indicator | |
| Level | Highest global Combat Level; if the equipped weapon’s style level is lower it appears in parentheses (e.g. `Level 14 (Magic 11)`) |
| Current gold | |
| Current ore / wood | |
| Current floor number | e.g. “F3” |
| Shrine buff icon + remaining time | Appears only while active |
| Food heal-over-time icon + remaining time | Appears only while a food effect is active |
| Boss / Floor Guardian / Gate Master HP bar | Appears only while the boss is alive and in range / engaged |

Bag-fullness indicator is explicitly removed and MUST NOT appear.
All cooldowns MUST show both a visual fill/sweep and be understandable at a glance. Exact pixel positions, colors, and sizes are left to implementation so long as the information hierarchy is preserved and the strip does not obscure critical gameplay.

## Pause menu

Opened with Menu / Start / Esc. Freezes gameplay.
Every menu (including this one) MUST open with valid initial focus so it is immediately navigable by gamepad.

Menu bindings are shared through `scripts/ui/menu_pad.gd` (`design/input.md`):
- A / Enter confirms the focused control. A second A confirms a pending prompt.
- B / Esc backs out of a nested layer (re-equip list, rebind page, pending prompt). At root, close the menu.
- LB / RB (or `[` / `]`) cycle the three pause tabs. They MUST NOT page the inventory stats card.

Exactly three tabs, navigable with LB/RB or equivalent:
1. Inventory – shared paper-doll gear board (`design/gear-ui.md`), 7-column bag grid, flyout tooltips, paged stats. Stats pages use **Q / LT** and **E / RT**. Use / consume / drop / equip as specified there, including mid-run weapon changes from the bag. Active artifact set bonuses appear on the Artifact sets stats page and in item flyouts.
2. Skills – list of the eleven skills with current level, XP bar to next level, and permanent XP total.
3. System – MUST open focused on the first System control, not the Inventory tab button, and MUST contain every one of the following:
   - Master / Music / SFX volume sliders
   - Camera zoom slider (1.0–1.75)
   - HUD scale slider
   - Aim-line toggle and opacity slider
   - Presentation mode switcher + Archives browser
   - Control rebinding screen
   - Character type switch (male / female)
   - Patreon link
   - “Delete Save Data” with confirmation
   - “Dispel” Avatar button with strong confirmation prompt

The full debug / balance menu is **no longer** present in the Pause Menu.

Placeholdia inventory (same board, opened outside a run) MUST use Loadout option sources: starters, holds, and non-white bank items. Dungeon inventory MAY only list the equipped piece plus bag items of that slot.

## Extraction Gate UI

- Opens on interact with an active Extraction Gate.
- Shows a clear, scrollable list of every item currently in the player’s bag and equipped slots that can be extracted.
- Player can select individual items or use a “Send All” option.
- Confirmation step required before items are removed from the run and marked as banked.
- MUST be fully usable with gamepad only and readable from couch distance.

## Ghost Shop UI

- Lists available Artifacts (2–4) with short descriptions and prices.
- Player may purchase a maximum of two Artifacts per visit.
- Lists snacks with prices.
- Option to pawn any currently carried gear for a low gold return.
- Clean confirmation on every transaction.
- Active set bonuses are shown beneath artifact descriptions.

## Anvil UI

- Shows the three holds for the selected slot.
- Analyze → First Forge → Re-forge flow with clear cost breakdown (gold, ore, root).
- Smithing level influence visible.
- Confirmation on every forge action.
- No pause-style tab strip. LB / RB do nothing here. Stats paging on the shared board still uses Q / LT and E / RT.

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

## Minimap and large map

- Small minimap on HUD shows only visited tiles + important markers (stairs, crystal, Extraction Gates, shop, player).
- View / Back button opens a large full-screen map overlay. Gameplay continues underneath.
- Fog of war and visited tracking follow the rules in `design/dungeon.md`.

## Toasts and floating combat text

- Floating damage / heal numbers: integers only, rise and fade quickly.
- Critical hits use yellow + magenta colored damage numbers (no extra “CRIT!” text).
- Toasts appear for bag-full, level-up, extraction success, and other system events. Short, readable, non-stacking or lightly stacking.

## Live snapshot — HUD / pause

`hud.gd`: strip top-left, minimap top-right, boss bar when near, toast. Level string uses combat level and parenthetical style level.
Pause Skills also shows run XP earned this descent.
Inventory and loadout share `Board.build`. Bag grid is 7 columns. Stats pages: kit bonuses, combat, utility, artifacts (artifacts omitted on loadout). Stats card is not in the focus chain. Pages change with Q / LT and E / RT. Pause tabs change with LB / RB via `menu_pad.gd`. System opens focused on Character. Loadout opens focused on **Enter dungeon**.

## Live snapshot — loading bar (`loader.gd`)

`CanvasLayer` that survives scene changes. Used on title → Placeholdia (`App.play_from_menu`) and similar heavy transitions.

- `begin(heading, status)`
- `set_status(text)`
- `set_progress(0..1)`
- `finish()` snaps to 100%, hides, calls `App.wake_web_pad()`

Visual: dim overlay, heading, status, percent, 720 px track with smoothed fill.