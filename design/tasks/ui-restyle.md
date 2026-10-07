# Handoff: ui

id: ui-restyle
title: UI restyle, remaining units
owner: build
status: open
done-when: the ghost shop, death recap, quest notice board and guild receptionist units are committed after Vira saw each one
area: ui
door: ui
job:
units: ui.controls, ui.anvil, ui.loadout, ui.extract, ui.ghost_shop, ui.recap, ui.quest_board, ui.receptionist
done: ui.controls, ui.anvil, ui.loadout, ui.extract
from: implementation session on grok-build-w6 after the extraction gate page
Your first command, before any file read or memory topic: python tools/start_build_slice.py --door ui --from-task ui-restyle
The survey is done and the answers below stand; ask again only what Open questions lists or what a discovery changes. Open no pictures except the baselines listed for the chosen surface.

## Task (her words)
Continue the UI restyle across the rest of the player-facing UI. The pause menus stay as they are and are the style reference. Journal materials stay on the pause. Other menus match the object they represent and stay visually cohesive with that pause work. She sees each screen before it is committed.

Work the remaining queue unit by unit. After a unit is committed and pushed, `python tools/start_build_slice.py --next` prints the next unit's card. No new survey and no re-reading of earlier units.

Done and not reopened unless she asks: the pause menus, the vendor stall front, the dumpster bin front, the controls sign front (4fda75a9), the anvil stump front (e7f6bf46), the floor-crystal front (11cda46a), the extraction gate page.

This session starts at the ghost shop.

## Q0 answers so far
- result look: Non-pause menus have a distinct style that matches the object they represent. The journal style is exclusive to the pause menu and is the styling base for the other UIs.
- reference: Each location that needs one gets a distinct UI, visually cohesive with the pause menu work. A front is built for the object. The world sprite stays the prop.
- out of bounds, incl. frames or layouts already built: Keep the pause menus as they are. Settings stays the shorter left sheet and wider right page. Inventory stays two even sheets. Skills stays split right of center. A confirm stays a slip. Words, gamepad order, and what each pause control does stay. The vendor front stays. The dumpster front stays. The controls sign stays. The anvil stump stays. The floor-crystal front stays. The extraction gate page stays. The gear board shared with pause Inventory stays.

## Her decisions
- Journal materials stay on the pause. Other menus match the object they represent and stay visually cohesive with that pause work.
- Pause menus stay as built. They are the reference, and they are not reopened.
- The vendor stall, the dumpster bin, the controls sign, the anvil stump, and the floor-crystal front are finished units.
- Order for the rest, which she named: controls billboard, anvil, floor-crystal loadout, extraction gate, ghost shop, death recap, quest notice board, guild receptionist.
- Extraction gate: one page, themed to the extract gate asset (stone, iron, lanterns, cyan mouth). The inventory gear board is the layout on that page, adjusted for the gate. You can mail equipped pieces, unsafe goods, and resources. Artifacts, forged holds, and a white weapon or tool stay. Send All mails what can go. The confirm stays a slip.
- A shot of a screen that lists what the delver is carrying must stock that kit first. A starter-only delver is not a test. The extract flow calls `App.prog.stock_extract_shot`.
- Quest notice board: "notice board should show quest posters instead of buttons."
- Guild receptionist: "the guild receptionist should just say "Hi" for now (rest later)."

## Chosen surfaces, in order
- ui.ghost_shop: ghost shop (this session)
- ui.recap: death recap
- ui.quest_board: quest notice board
- ui.receptionist: guild receptionist
Done already, do not reopen: ui.controls, ui.anvil, ui.loadout, ui.extract.

## Ledger
Decisions I made that were yours: on the gate page the worn slots and the bag are the inventory board, resources are their own row, Send All sits under the bag, and the extract bag shows one row instead of the full empty capacity so Send All stays on the page. A white weapon or tool is not mailed, because the slot refills with another white one.
Assumptions carried from memory or docs: the pause stays the reference. The gear board shared with pause Inventory stays. Unsafe means lost on death unless mailed (`text_fmt.is_risk`). The gate shot stocks a green weapon, a blue helm, a green body, the Cinder Ember artifact, and ore, wood, gold, and root.
Also changed: `frame_set.gd` lists ExtractFrame and every progress panel still wears only its own skin. `extract.gd` is also used by town progress and quest restock. `en.po` gained extract.equipped, extract.resources, extract.unsafe, and extract.carried. The import check dirtied `.import` files; they are not part of the unit. Vendor, dumpster, controls, anvil, crystal, and pause were not re-shot.

## Baselines for the chosen surface
none. The next unit is the ghost shop. Its card names the flow (dungeon-gate-shop, state shop). `python tools/run_shot_flow.py --job ui.ghost_shop` re-shoots just that state. Shoot it before editing. Open questions below still apply before editing that unit.

## Files and functions to touch
- scripts/ui/progress_ui/shop.gd: rebuild_shop
- scripts/ui/progress_ui.gd: open_shop
- scripts/ui/ui_tokens.gd: the palette
- scripts/ui/ui_build.gd: chrome_label, piece, place, tex_box, states
- scripts/ui/progress_ui/frame_base.gd: mount, apply
- scripts/ui/progress_ui/frame_set.gd: SKINS

## Did not work
none

## Open questions
- For each remaining unit that has no ruling yet, before editing its card: what the prop looks like (the prop already in the hub, a short description, or a picture). Ghost shop, death recap, notice board, receptionist. Ask once per unit, with the reuse-or-draw options. The rule already stands (a front for the object, cohesive with the pause work).
- Quest notice board: what a quest poster shows (kind, reward, title) and how a poster is chosen with the gamepad. Ask before editing.
- Guild receptionist: where "Hi" shows (a line on her window, a speech bubble, or a small card). Ask before editing.
