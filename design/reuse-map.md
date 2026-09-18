# Staged Bot reuse brief

Status: protocol
Read when: web / chat Phase 7 is writing this brief, or Grok Bot Job table -> design/grok-bot-reuse.md and this body is not the empty template


This file is a User-authored staging brief for the next Grok Bot reuse work. It is not an owners encyclopedia, not a standing BOT list, and not default Bot context.

Web / chat writes or replaces the whole file in Phase 7. Grok Bot implements this entire Brief on the current open Bot PR (design/grok-bot-reuse.md), including every cluster named under Brief. Do not take a subset. Do not open a second PR only because a later heading exists. Bot does not mark rows done and does not invent rows. After the User merges that PR, the next web session clears or replaces this file.

## How to fill (web / chat)

Replace Brief with the full mandate. Multiple clusters in one body still ride the current open Bot PR. Leave Brief empty when nothing is staged.

## How to run (Grok Bot)

If Brief is empty, stop and report empty. Do not start a size sweep. If Brief has any content, implement all of it on the current open Bot PR (create that PR if none exists).

## Brief

UI chrome extracts only. Same-shape helpers. No UI framework. No Entity.gd. No gear_board vs inventory merge. Inventory each bullet; skip a bullet only when the copy is already one function.

1. Wipe-children. prompt_view._wipe and progress_ui._wipe are the same loop. One small helper. Call sites only.

2. Prompt gold Color(0.86, 0.80, 0.66) and the 5px dark outline become theme tokens. prompt_view and confirm_dlg (and any other hard-coded twin) use the tokens.

3. Destructive / confirm actions in progress extract, shop, delete use confirm_dlg.open. Remove press-twice progress_ui._confirm for those paths. Modal wins.

4. Pause the tree + App.ui_open + PromptView.footer open/close. If progress_ui._show and pause/split already share that shape, one short UiSession-style helper. Stay out of gear_board guts.

5. Focus-neighbor wiring. Use split_menu_view.wire_vert (or one sibling helper) where menus still hand-set focus_neighbor_*. confirm_dlg already calls wire_vert; finish left/right if still manual.

6. Skill row + XP track. pause_skills.gd and recap_bars.gd already share ThemeS.skill_row, skill_lab, and a ColorRect track. One helper for the row + single fill. Recap keeps dual-fill drain and snapshots. Pause keeps TipPlace. Do not merge the two screens into one host.

7. Footer. Callers that still bypass PromptView.footer / fill and rebuild Select/Back by hand should call PromptView. Do not rebuild prompt_view.

Touched live scripts stay under 10KB (design/refactor.md recipe only). Update the UI code-map row if a new public helper path appears. Do not fold opt-001..004 into this Brief.
