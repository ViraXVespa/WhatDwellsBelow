# Metal HUD re-theme + danger gem + mana pacing

id: metal-hud-mana
owner: web
status: open
done-when: User confirms the re-themed HUD, danger gem, and mana pacing feel correct in play
resume: Open design/tasks/metal-hud-mana.md and continue from the frozen decisions

## Mandate
Full HUD strip re-theme to metal-chain / dungeon-prisoner language, plus a danger gem indicator and a mana resource that paces special attacks.

## Frozen decisions
- HUD strip only. Paper/journal look fully replaced by metal-chain / iron / prisoner-in-dungeon visual language. Must respect existing HUD scale setting. Minimap and other layers unchanged.
- Danger gem: always-visible, shared-frame container on the right side of the strip. Color from expected Threat CL (walk-distance) vs player combat_lv(): solid green when threat <= player CL; transitions to solid yellow at +3; solid red at +7. Mostly transparent gem with animated glow. Settings -> Graphics toggle. Independent of dungeon crystals.
- Mana: secondary long-term pace limiter for specials (conserve between fights or recover via items). Existing special recovery lengthened so pure-special play is not viable. Regen over time + chance-based mana orbs (like HP orbs) + potions and food also restore mana. Mana bar below HP bar. All numbers tunable in debug menu + design/tunables.md.

## Open questions
- Exact mana numbers (max, regen rate, special cost, recovery length, orb chance/amount, potion/food mana values). All start as tunables.

## Likely Source
- revise scripts/ui/hud/hud_view.gd
- revise scripts/ui/hud/hud_act.gd
- revise scripts/ui/theme.gd (or new HUD-specific styles)
- revise scripts/world/player*.gd and combat specials (mana cost + recovery)
- revise scripts/data/progress.gd or new mana module
- revise loot/pickup for mana orbs
- revise potion/food use paths
- revise scripts/ui/pause_settings.gd or settings pages (toggle)
- new or revise assets for metal frame / gem if needed

## Likely Docs
- revise design/ui-hud.md
- revise design/combat.md
- revise design/tunables.md
- revise design/constraints.md if scope note needed

## Tests that would prove it
- HUD scale still applies correctly.
- Danger gem color matches Threat vs player CL thresholds.
- Special cannot be spammed via recovery; mana drains and limits long-term use.
- Mana orbs, potions, and food restore mana.
- Toggle hides the gem.
- Visual: paper look gone; metal-chain feel present (User confirmation).

## Why parked
Multi-system change (full visual re-theme + new HUD element + new resource system touching combat, loot, and items). Better as a focused follow-up session than continued discussion in this thread.

## Art survey
- Player card and HP/dash/special bars: flat beige card, flat bars. Metal re-theme art: bar frame + trough 9-slice 64x16, card 9-slice 96x96, transparent. High (always on screen). Minimap bezel is outside this task's scope; see ui-png-art. Ref [dungeon-hud-states_01-hud-default](../refs/metal-hud-mana/dungeon-hud-states_01-hud-default.jpg), [dungeon-hud-states_02-hud-buffs-low-hp](../refs/metal-hud-mana/dungeon-hud-states_02-hud-buffs-low-hp.jpg). Ref shots: Bot survey of grok-build-w7 on 2026-10-11.
