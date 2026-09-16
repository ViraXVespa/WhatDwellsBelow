# Anvil / Loadout entry points

Status: binding design  
Read when: Anvil / Loadout / tooltip entry chrome from ui — not shared board internals  

ui is already open when this sibling is loaded. Open gear-ui only when board / anvil chrome is the named work. Do not reopen theme, title-web, hud, pause, run-flow, hub, input, or doc-refactor from this file.

## Anvil UI

- Analyze / Forge tabs. LB / RB cycle those tabs. The tab row uses the shared header chrome (bumper glyphs, stretch, horizontal scroll).
- Analyze → First Forge → Re-forge flow with clear cost breakdown (gold, ore, root).
- Smithing level influence visible.
- Confirmation on every forge action.
- Stats paging on the shared board still uses Q / LT and E / RT.

## Loadout UI

- Opens only by interacting with the Floor Crystal in Placeholdia. There is no separate loadout station.
- Uses shared_gear_board_in_the_gear_ui. Holds / starters / bank populate each slot list.
- Footer is `Floor: [−] [selected] [+] (Deepest floor: n)` then **Enter dungeon**. No character button and no top weapon / tool / deepest summary.
- Choose starting weapon and tool type (pickaxe or hatchet — locked for the run) from the doll slots. Starting floor is only a previously reached floor. Never backward.
- First focus is **Enter dungeon**. One press enters. B / Esc / Close cancels without entering.
- No tab strip. LB / RB do nothing. Stats pages use Q / LT and E / RT.
- Visual presentation MUST meet the same clean, dungeon-themed, TV-readable standard as the other interaction UIs.
- Esc / B on the re-equip list MUST NOT confirm enter or close the crystal UI.

## Gear tooltips

- Flyouts follow gear_ui. Hidden until hover, keyboard highlight, or activating the focused slot.
- **Y** cycles off → current item stats → forge preview.
- Active artifact set bonuses are shown in the flyout and on the Artifact sets stats page.
- Smithing level influence remains visible in Anvil UI.
