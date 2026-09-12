# Inventory live snapshots

Status: binding design
Read when: catalog sets or required slots live snapshot
See also: `design/inventory.md`, `design/inventory-bag.md`, `design/inventory-gear.md`, `design/inventory-meta.md`, `design/gear-ui.md`, `design/hub.md`, `design/skills.md`, `design/doc-refactor.md`, `design/README.md`

## Live snapshot — catalog sets

Live set ids: `cinder`, `tide`, `root`, `ash`, `spark`, `bone`, `veil`, `iron`.

| Pieces | Set | Family |
|--------|-----|--------|
| cinder_ember, cinder_coil | cinder | damage |
| tide_pearl, tide_scale | tide | HP |
| root_knot, root_charm, root_seed | root | gathering |
| ash_mask, ash_bell, ash_cloak | ash | defense |
| spark_lens, spark_wire | spark | crit |
| bone_ring, bone_splint, bone_tooth | bone | HP |
| veil_shard, veil_thread, veil_coin, veil_hush | veil | speed |
| iron_seal, iron_nail, iron_link, iron_plate, iron_heart | iron | defense |

Pause inventory uses a 7-column bag grid and shows gold / ore / wood / cap.

## Live snapshot — required slots

`Gear.ensure_required_slots` runs after new-progress `reset_meta`, save `from_meta`, and recap `lose_unextracted`. An empty or invalid weapon or tool slot takes the selected hold when `hold_pick` is in range for that slot; otherwise it takes the current starter (`pick_weapon` / `tool_type`). Head, body, legs, potion, and food are not filled by this path. `begin_run_loadout` uses the same weapon/tool rule so hub and dungeon match.

Forge ledger lives on `App.prog.forge_book`, keyed `slot:type:rarity`. Legacy `analyzed` remnants migrate into that book once and then clear. Load also runs `Rules.normalize_prog` so pre-affix saves pick up item level, Finish, Fortune, and capped affix rows.
