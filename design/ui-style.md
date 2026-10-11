﻿# UI style: tokens, builders, object frames

Status: current plan  
Read when: restyle, builders, skin hooks, scrollbar hiding  

One place per job, so a screen only fills in what is its own. Existing screens render the same as before this layer.

## Tokens
- `scripts/ui/ui_tokens.gd` is the palette: ink, rule, paper, danger, button paper, outline and their softer steps. `theme.gd` forwards them as `ThemeS.INK` and friends, so callers keep their names.
- Restyle = edit a token (or a skin script), rebuild, shoot. No live skin switching, no autoload.
- On purpose separate: HUD draw alphas (`touch_hud/hud_draw.gd` builds on tokens), the title / splash / fs-gate / loader / prompt / hud local label twins. Merge one only on her word.

## Control skins (`scripts/ui/btn_skin.gd`)
- Outside the pause journal, buttons, tabs and gear slots wear a skin from `ui_tokens.gd` `SKINS`: `neutral` (hub cream-plate menus, ghost shop, anvil, recap), `title` (title card, news, archives: also turns ink labels and plates dark), `crystal` (loadout crystal, dungeon floor crystal, extraction gate).
- A host names its skin with meta `btn_skin` or a `btn_skin()` method; the progress panel asks its open frame (`BTN_SKIN` const on the frame script, else `neutral`). No skin found = paper (the journal).
- `ThemeS.btn`, `paint_tab`, `paint_plate`, `lab` and `Plate.plate` / `edge` register the control; it is restyled on entering the tree. Frame-dressed buttons (`UiBuild.button_base`) keep their frame look.
- The gear board stats card ("Bonuses" pager) takes the host skin too (`BtnSkin.card`); crystal has one button look (primary = secondary), so the loadout matches the transport pages.
- Focus is a ring drawn over the state (bright edge + glow), so pad focus reads on every face. Gear slots stay light so item art reads.
- The dungeon floor crystal pages sit on the crystal art (`crystal_ui/ui_util.gd` `crystal_panel`, same place and scale as the loadout frame); long lists scroll with focus.

## Builders (`scripts/ui/ui_build.gd`)
- Labels and pictures: `chrome_label`, `piece`, `place`, `keep` (texture cache), `dot` (pixel brush).
- Boxes and buttons: `blank_box`, `tex_box` (textured state box), `button_base`, `ink_text`, `states` (the five states).
- Scroll bars: `bars(scroll, shown)`. Bars are hidden on object frames (the rows still scroll with the pad), shown on the cream plate.
- Tooltips: `tip_panel`, `tip_text` (used by the scroll box and the gear board). Show and hide on focus or hover through `scripts/ui/tip_hover.gd` (`TipHover.attach`, `show`, `blur`, `place_below`); the pause Skills tab and the recap bars use it. The gear board keeps its own (`gear_board/tip.gd`).
- Icon grids (consumables, ghost shop, pawn): `scripts/ui/item_board.gd`. Two-sheet journal layouts on any host: `scripts/ui/journal_spread.gd`.
- Pause tabs: one row each in `pause_menu.gd` `TABS` (id, label, builder). Code, flows and smokes name tabs by id.
- Text: every new line (Talk lines, tutorial pages, labels) is an en.po key in `scripts/data/locale/en.po`, shown with `App.tr(key)`. Keys are `<owner>.<what>` (Talk: `talk.<npc>.NN`); never rename a shipped key.
- Use these before writing a local copy; add a builder here when a second screen needs it.
## Button hints (`prompt_view.gd`, `prompt_chip.gd`)
- Each glyph + verb pair in a hint strip is a chip. Click or tap presses that action while the pointer is down and lets go on release, the same path as the key or pad press, so the menu's own handler decides what it does. The Back chip is the touch way out of every menu.
- Hover tints a chip (`Tok.CHIP_HOVER`) and a press flashes it darker for a beat (`Tok.CHIP_PRESS`), back to `Tok.CHIP_REST`. It is a modulate over the chip's own glyph and word, so it suits every frame. Read-only strips get neither.
- The death recap shows no Back hint; Continue is its only way out.
- Chips have `focus_mode` NONE: no tab, highlight or select focus, and the menu keeps its focus.
- A strip that only lists binds (the controls sign rows, the world HUD prompt) sets `prompt_tap` false on its host.
- A scheme change (pad, keys, touch) swaps the glyphs inside the same chips, so the press that changed the scheme still lands.
- Guard: phase 6 opens every hub menu and closes it by each Back bind, by the Back chip, and after going one to three levels in (`python tools/run_smokes.py --phases 6` and `bot_smokes.py` both run it). The first-open timing (`--wdb-open-timing`, `scripts/debug/open_timing.gd`) runs inside `bot_smokes.py` phase 6 only; run it by hand with `--wdb-load-timing-smoke --wdb-open-timing`.

## Object frames (`scripts/ui/progress_ui/`)
A frame re-skins the progress panel host for one object (stall, bin). `frame_base.gd` owns what every frame shares: the chrome layer under the host, the cream plate every other mode keeps, the footer room, the button row (the host's scroll area) and its separation. `frame_set.gd` lists the skins.
A skin is a script with static hooks:
- `spec()` returns mode, chrome (node name), pos, size, footer, rows_pos, rows_size, sep, blank_rows. Build it with `FrameBase.make_spec(...)` (shared defaults; pass only what differs).
- `build(chrome)` makes the pieces and labels once; `place(chrome)` positions them each open.
- Callers keep their own `prepare` / `dress` per object (text, button look).
Add a frame: write `<object>_frame.gd` (+ `<object>_art.gd` for code-drawn pictures), list it in `frame_set.gd`, set the host `mode` when it opens. A frame takes the hooks it needs and adds its own pieces; it need not look like another.
First open: `ui_warm.gd` loads every listed skin's art on a worker from the title screen and opens the heavy menus once behind the hub loader. A new menu or frame gets a row in `scripts/debug/open_timing.gd` (pause tabs are timed from `TABS`), and a warm step if its first open is over budget.

Frame art ships as PNG (her decision). Existing frames: the `*_art.gd` code is the source and `python tools/bake_frame_art.py` bakes it to `assets/ui/frames/<art>/<key>.png` (button looks from each `dress()` too); at runtime `art_bake.gd` loads only the PNGs and a missing one is an error. Re-bake after editing any `*_art.gd` or `dress()`; `bake_frame_art.py --check` (also in `bot_smokes.py` phase 6) fails on a stale PNG. Posters and other hand-made art: PNGs under `assets/ui/<object>/` (posters: `assets/ui/posters/`, loader `progress_ui/poster_art.gd`, its `REQUIRED` list names the files); no drawn stand-in. Where hand-made PNG art would clearly beat the code-drawn look is listed in the W7 button-style audit for her.

## Web export (flagged, not changed)
- `journal_page._tex_at` loads `res://assets/ui/journal/paper.png` and `leather.png` with `load()` so the imported textures ship in the web pack. A missing page texture errors; it does not cache an empty image.
- `ThemeS.ink_font()` returns the shipped `res://assets/ui/journal/ink.ttf` (Patrick Hand, OFL). SystemFont is not used; the web export has no Windows faces.
- Frame art loads from baked PNGs under `assets/ui/frames/` (imported, so they ship in the web pack); see Object frames.
- A missing asset fails loudly; no fallback texture or color.
