# Staged Bot reuse brief

Status: protocol  
Read when: web / chat is staging this brief, or Grok Bot Job table -> design/grok-bot-reuse.md and this body is not the empty template  

This file is a User-authored staging brief for the next Grok Bot reuse work. It is not an owners encyclopedia, not a standing BOT list, and not default Bot context.  

Web / chat writes or replaces the whole file in a Phase 4 emit. Grok Bot implements this entire Brief on the current open Bot PR (design/grok-bot-reuse.md), including every cluster named under Brief. Do not take a subset. Do not open a second PR only because a later heading exists. Bot does not invent rows and adds no Ready / Done columns; it clears the completed Brief items from this file on the same PR.  

## How to fill (web / chat)  

Replace Brief with the full mandate. Multiple clusters in one body still ride the current open Bot PR. Leave Brief empty when nothing is staged.  

## How to run (Grok Bot)  

If Brief is empty, stop and report empty. Do not start a size sweep. If Brief has any content, implement all of it on the current open Bot PR (create that PR if none exists).  

## Brief

1. Extract nearest-interact full-list walk to a new shared module. Copies: `scripts/world/player/player_act.gd` `refresh_prompt` / `try_interact`. Same control flow. Owning requirement in `design/refactor.md` “New shared modules and reuse” is unmet. Overlaps opt-005 item 1 (still return the nearest valid prompt within range).

2. Extract floating damage number spawn to a new shared module. Copies: `scripts/world/player/player_act.gd` `_float` and `scripts/combat/enemy/enemy_hit.gd` `float_num`. Same control flow (FloatS.new + setup + parent add). Owning requirement unmet.

3. Extract breakables hit full-list walk to a new shared module. Copies: `scripts/combat/player_hit.gd` `hit_breakables_arc` / `hit_breakables_circle` and `scripts/combat/projectile.gd` `_smash_breakables`. Same control flow. Owning requirement unmet. Overlaps opt-005 items 4 and 5 (spatial or near-arc subset still fine).

4. Extract actor grounding / present sequence to a new shared module. Copies: `scripts/world/player/player_tick.gd` `physics` / `_loco` and `scripts/world/player/player_act.gd` `tick_exit`. Same control flow (velocity / move_and_slide / y=0 / Depth.apply / facing / rig.follow). Owning requirement unmet.

Prior staged rows (B11–D7) remain deferred per their Why left notes; do not invent work on them in this brief.
