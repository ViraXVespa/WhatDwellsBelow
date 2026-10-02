# Run-flow UI (extract, shop, quest, recap, map, toasts)

Status: binding design  
Read when: extraction gate, ghost shop, quest, recap, minimap, crystal map UI, toasts  


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

## Quest UI

- Accessible from the guild in Placeholdia.
- Displays three random quests.
- Clear accept / decline flow.
- Active quest status visible where appropriate.

## Back layers (multi-level menus)

Rule: B / Esc / Start backs out one layer; at the root it closes (input and pause docs). There is **no shared back stack**; each UI keeps its own layer state:
- `scripts/ui/crystal_ui.gd`: a `page` string (`root` / `local` / `floors` / `band`) rebuilt by `_rebuild()`, with `_back()` stepping one page up and closing at `root`. Cleanest model for a page-per-level menu; footer verb via `PromptView.footer` (`ui_cancel` → "back").
- `scripts/ui/pause_menu/menu_flow.gd` `_back()`: Confirm → gear sub-panel → Settings column → close.
- `scripts/ui/progress_ui.gd` (quest, vendor, shop, controls, extract, flavor): one level only. `ui_flow.gd` `_unhandled_input` maps cancel to Confirm close, forge cancel, or `close_ui()` (whole UI). A Talk → Ask? → topic → page flow must add its own page var and route cancel to a `_back()` there (new sibling file; the facade and flow files are near the script cap).
- Pad paging inside a layer: `MenuPad.tab_delta` (wired for the anvil and crystal pages).

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
- Fog of war and visited tracking follow dungeon.

## Toasts and floating combat text

- Floating damage / heal numbers: integers only, rise and fade quickly.
- Critical hits use yellow + magenta colored damage numbers (no extra “CRIT!” text).
- Toasts appear for bag-full, level-up, extraction success, and other system events. Short, readable, non-stacking or lightly stacking.
