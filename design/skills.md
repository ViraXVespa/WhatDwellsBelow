# Skills, XP, and combat level

Status: binding design + live snapshot
Read when: changing XP, HUD level text, forging, or enemy scaling vs the player
Code: `scripts/data/progress.gd`, `scripts/ui/hud.gd`, `scripts/ui/pause_menu.gd`, `scripts/data/balance.gd`
See also: `design/combat.md`, `design/enemies.md`, `design/ui.md`

## Skills included in the demo

- Great Axe
- Staff
- Longbow
- Strength
- Magic
- Ranged
- Defense
- Hitpoints
- Mining
- Woodcutting
- Smithing

These eleven are mandatory.

Live ids: `axe`, `staff`, `bow`, `str`, `mag`, `rng`, `def`, `hp`, `mine`, `wood`, `smith`.

## XP gain and permanent progression

- During a run the player accumulates “run XP” in each skill.
- On death or voluntary “Dispel”, only a small fragment of that run XP is kept permanently.
- The recap screen MUST contain a clear visual sequence that shows the run XP values draining down to the permanent fragment amounts, after which the new permanent XP totals and resulting levels are displayed.

## Weapon-specific XP rules

- Great Axe attacks grant Great Axe XP + Strength XP.
- Lightning Staff melee attacks grant Strength XP + Staff XP.
- Lightning Staff special attacks grant Magic XP + Staff XP.
- Longbow attacks (both basic and special) grant Ranged XP + Longbow XP.

## Combat level

- Three separate style-specific combat levels are tracked:
  - Melee = Great Axe + Strength
  - Magic = Staff + Magic
  - Ranged = Longbow + Ranged
- Defense and Hitpoints feed into the global Combat Level.
- The HUD displays the player’s highest (global) Combat Level.
- If the currently equipped weapon’s style Combat Level is lower than the highest, that style level is shown in parentheses next to it (e.g. Level 14 (Magic 11)).

## Skill effects (high-level)

- Great Axe, Staff, Longbow, Strength, Magic, and Ranged: increase damage dealt with the corresponding style or weapon (with possible differential scaling on specials).
- Defense & Hitpoints: increase survivability.
- Mining: improves reward chance and effectiveness with the hit-based mining system.
- Woodcutting: improves reward chance and effectiveness with the hit-based woodcutting system.
- Smithing: reduces forge cost/time and improves output at the anvil.

## Visible power gain after one good run

After a single successful extraction and return to Placeholdia the player MUST be able to notice either:
- a few permanent skill levels, or
- at least one new piece of usable forged gear (or both).

This is a required feel target. Concrete proxy: after one successful run the permanent skill levels or new forged item MUST be visible on the hub loadout/skills screens without external guidance.

## Live snapshot — player CL formulas (`progress.gd`)
survive = lv(def) + lv(hp)
melee   = lv(axe) + lv(str) + survive
magic   = lv(staff) + lv(mag) + survive
ranged  = lv(bow) + lv(rng) + survive
combat  = max(melee, magic, ranged)
style   = melee | magic | ranged from the equipped weapon

Fragment rate is `App.bal.xp_keep` (live 0.20). Adrenaline multiplies run XP in `add_run_xp`.

## Live snapshot — enemy combat level (post-GDD)

Enemies now carry a combat level used to scale fights against the player. Keys live in `balance.gd` and MUST stay in the secret debug menu.

| Key | Live default | Role |
|-----|--------------|------|
| `enemy_cl_per_floor` | 20 | Expected enemy CL gained per floor |
| `enemy_cl_end_pct` | 0.86 | How close a typical enemy sits to the floor target |
| `enemy_cl_jitter` | 2 | Random CL noise |
| `enemy_cl_dmg` / `enemy_cl_gear_dmg` | 0.018 / 0.012 | Per-CL damage |
| `enemy_cl_hp` / `enemy_cl_gear_hp` | 0.010 / 0.016 | Per-CL HP |
| `enemy_cl_def` / `enemy_cl_gear_def` | 0.4 / 0.3 | Per-CL defense |
| `cl_dealt_up` / `cl_dealt_down` | 1.15 / 0.85 | Outgoing damage vs CL delta |
| `cl_received_up` / `cl_received_down` | 0.85 / 1.15 | Incoming damage vs CL delta |
| `cl_xp_up` / `cl_xp_down` | 1.1 / 0.9 | XP vs CL delta |
| `cl_style_weight` | 0.5 | Style-mismatch weight |