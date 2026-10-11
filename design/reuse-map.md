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

4. Thin named-intent wrappers, theme part: theme.gd StyleBox convenience wrappers that clear the min-line bar (`_ink_box` / `_box` differ only in corner radius and margins). The val_sb/val_spin_sb, tarp_mat/awning_mat and is_page_prev/is_page_next builders are done.

5. Tool bootstrap + runner heads: extract the repeated `sys.path` insert + common import blocks across tools (bot_status, check_shot_gaps, doc_patch, export_web, and the other copies) into a shared `tools/_boot.py` or equivalent. Also fold the near-identical Godot-launch / `agent_log.finish` tails where the RESULT line can stay tool-specific. Path insert must remain before local imports.

6. Enemy setup / state-machine hooks: extract parallel sequences in `scripts/combat/enemy.gd` and the `enemy_*.gd` helpers (state enum handling, timing vars, leash/group checks) into shared helpers without changing combat feel. Golden compare on hit/AI paths if any numeric thresholds move.

Hot-path (gen, shaders, pixel loops) and art-output items stay out; only implement the six clusters above. Update `design/code-map.md` for any new public helper paths.
