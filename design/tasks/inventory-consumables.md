# Inventory consumables, vendor board, dumpster bread

id: inventory-consumables
title: Potion and food holding, vendor consumable board, dumpster moldy bread
owner: build
status: open
done-when: lighter consumable board with icons; potion and food holding/equip rules; three random potions and three food variants with tunables; vendor stock and disposal rules; dumpster moldy bread with the three flavor lines; food-themed Talk lines; Vira has seen the vendor, dumpster and a return-to-hub equip cycle
area: inventory
door: inventory
job: bag
units: inventory.bag
done:

Your first command, before any file read or memory topic: python tools/start_build_slice.py --door inventory --job bag --from-task inventory-consumables

## Intent
One slice updates the bag rules and the vendor/dumpster UIs together. Vendor and dumpster fronts stay; behavior is added on top.

## Potion rules
- Lighter consumable board (not a full gear-board clone) showing Potion and Food with UI icons.
- Vendor stocks three random potions per visit.
- Variations (tunable ranges, exposed in the secret debug menu): usage count (charges), health restored, cooldown, heal speed, plus a chance of a small 3–6 s bonus to the same stats equipment can modify.
- Persist through runs like a held weapon. Player can hold up to three different potions in the hub and brings one into the dungeon.
- Only obtainable from the vendor.
- Slot stays equipped with the last-used potion by default; the player must deliberately unequip it.
- On return to Placeholdia: whatever potion was in the potion slot before the previous dive is re-equipped.
- Starter potion is equipped by default.

## Food rules
- Three different food variants, each with bonuses that fit the food’s stats (tunable).
- Player can hold stacks of up to six different kinds of food.
- Food can be empty. On return to Placeholdia: if the food slot is empty and any food stacks exist, the next available stack is equipped; otherwise the slot clears.
- Starter food is equipped by default until consumed.

## Vendor stock and disposal
- Always offers a minimum of 1 new food stack.
- Always offers a minimum of 1 existing stack the player already has that is not at max capacity (if any such slots exist). Full stacks are excluded from the existing options.
- If all existing stacks are full, no existing option is shown.
- If the player’s 6 food slots are already filled, the vendor still shows 3 new options only when all stacks are at max capacity; otherwise existing stacks can still be shown.
- The disposal prompt appears whenever the player selects ANY new kind while all 6 slots are filled, regardless of whether those stacks are at max capacity. Selecting a new kind prompts to dispose of an existing stack before the buy completes.

## Dumpster moldy bread
- One moldy bread available on a fresh save; a new one appears after returning to the hub from the dungeon if the previous was collected.
- Collect rules and flavor:
  - Success: “You scavenge some moldy bread from the dumpster... I guess it's better than nothing.” when room exists (no moldy stack or moldy stack not at cap, and a food-stack slot free).
  - Max-stack: “You scavenge some moldy bread from the dumpster... You've reached your limit for hoarding moldy bread and don't want people to start saying weird things about you, so you leave the bread where it is...”
  - Six other food stacks: “You scavenge some moldy bread from the dumpster, but you can't think of how that would be useful to you.”
- Moldy bread is a weaker version of the starter food (lower heal, minimal or no bonuses). Tunable.
- Create a new visually distinct moldy-bread asset: icon at `assets/ui/gear/moldy_bread.png`, food id `moldy_bread` (or equivalent), and an entry in `gear_icons.gd` `ITEM_PATHS`. Do not reuse the ration or trail-bread icon.

## Vendor Talk lines (food-themed)
- Fresh out of the oven… well, as fresh as Placeholdia gets.
- This ration will keep you upright. The moldy stuff from the dumpster won’t.
- Careful with the potions—some of them hit harder than they look.
- You can hold a few different brews up here. Only one goes with you Below.
- Running low? I always keep a couple of the usuals and something you already like.
- If your bag’s full of food, you’ll have to toss something before I sell you a new kind.
- Ore’s fine, but a full stomach is what gets you back to the surface.
- Don’t ask me what’s in the green one. It works. That’s the warranty.

## Tunables
All ranges, costs, stack caps, heal amounts and bonuses go in design/tunables.md and the secret debug menu.

## Files
- scripts/ui/progress_ui/shop.gd (vendor board + talk)
- inventory / progress holding and equip logic
- dumpster interact
- design/tunables.md
- assets/ui/gear/moldy_bread.png (new)
- scripts/ui/gear_icons.gd (ITEM_PATHS entry)

## Art survey
- Vendor rows: pale bars over the baked stall; shelf/price-tag row 9-slice 96x32. Med.
- Vendor crate (code X box) and red jar blob: real icons 64x64 transparent. Med.
- Dumpster Leave: flat white bar; sticker-style button 9-slice 96x32, 2 states. Low.
Refs [camp-npc-panels_01-vendor](../refs/inventory-consumables/camp-npc-panels_01-vendor.jpg), [camp-npc-panels_03-dumpster](../refs/inventory-consumables/camp-npc-panels_03-dumpster.jpg). Ref shots: Bot survey of grok-build-w7 on 2026-10-11.
