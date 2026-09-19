# Stats card and tooltips

Status: binding design  
Read when: kit deltas, combat totals, hover highlight, Y preview  


## Stats card

Pages, in order:

1. **Bonuses from this kit** — only stats the current equipment actually changes
2. **All combat stats** — damage, defense, max HP, crit chance, crit damage, attack speed, attack range, health on hit / kill
3. **All utility stats** — movement speed, gather speed / power / yield
4. **Artifact sets** — pause / dungeon inventory only; omitted on Loadout and Anvil

Totals come from `App.prog.gear_stat`. When a piece has an `affixes` list, only those rows count. Leftover flat keys on old saves MUST NOT appear here.

The current page name sits in the card header. Navigation chrome is on either side of that title (`Q · LT` left, `RT · E` right), not in a separate bar at the top of the menu. Labels stay horizontal.

The card is display-only. It MUST NOT take keyboard, mouse, or gamepad focus and MUST NOT sit in the focus chain. Pages change only through **Q / LT** and **E / RT**. LB / RB MUST NOT page this card; those bumpers cycle menu tabs when the host has tabs. Mouse click MUST NOT page it. On the Forge results screen, Q / LT and E / RT MAY page the card so the player can compare kit totals while highlighting a roll.

## Highlight and tooltips

- Opening the menu MUST leave the flyout hidden until the player hovers a slot, moves highlight with keyboard/gamepad, or activates the already-focused slot. Loadout first focus is **Enter dungeon**, so the flyout stays hidden until a slot is highlighted.
- Highlight (focus or mouse hover) shows a flyout next to that control, not a label under the slot. On the main board the flyout sits to the right of the plate (flips left if it would clip). On the re-equip list the flyout sits under the icon: top-left a few pixels below the center of the icon’s bottom edge.
- The flyout MUST only anchor to a control that has an item key. Close, tab buttons, empty bag cells, and Anvil Potion / Food plates hide it.
- Leaving every slot with the mouse hides the flyout. Keyboard / d-pad highlight MUST show it again without requiring a mouse pass first.
- Changing pause tabs or Anvil tabs hides the flyout. Returning to Inventory restores it only if it was visible when the player left. Paging the stats card hides it.
- First-open layout MUST wait until the plate has a real on-screen rect so the flyout does not land on the bottom edge.
- **Y** cycles tooltip detail: off → current item stats → forge preview (then back to off). Artifacts, food, and potions have no forge preview.
- White starters on a slot or in the re-equip list MUST resolve to the implied weapon/tool (or the item stored on the button). They MUST NOT read as empty when an icon is showing.
