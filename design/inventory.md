# Inventory / gear rules (door)

Status: current plan  
Read when: affixes, artifacts, mailing  
Code: `scripts/data/progress_gear.gd` (facade: items, bag, eat, extraction mailing, restock) + `scripts/data/progress_gear/`; public: `scripts/data/progress_gear/consumable.gd` (potion holds, food stacks), `scripts/data/gear_rules/rules_kit.gd` (`Kit`), `scripts/data/gear_rules/rules_norm.gd` (`Norm`), `scripts/data/affixes.gd`, `scripts/data/gear_roll.gd`, `scripts/data/catalog.gd`, `scripts/data/item_names.gd` (code map row Inventory; gdhealth group `inventory`)  

Other code calls the facade or the public files above, never another `progress_gear/` helper. Skill math reads gear stats through `progress_combat` (skills).

| Job | Open |
|-----|------|
| pouch tiles, ration versus flask | `design/inventory-bag.md` |
| item level, duplicate rule, white baseline | `design/inventory-gear.md` |
| set bonuses, shopkeep restock | `design/inventory-meta.md` |
| stat-table listing, required sockets | `design/inventory-live.md` |
