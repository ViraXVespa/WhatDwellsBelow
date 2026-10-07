# UI style: tokens, builders, object frames

Status: current plan  
Read when: restyle, builders, skin hooks, scrollbar hiding  

One place per job, so a screen only fills in what is its own. Existing screens render the same as before this layer.

## Tokens
- `scripts/ui/ui_tokens.gd` is the palette: ink, rule, paper, danger, button paper, outline and their softer steps. `theme.gd` forwards them as `ThemeS.INK` and friends, so callers keep their names.
- Restyle = edit a token (or a skin script), rebuild, shoot. No live skin switching, no autoload.
- On purpose separate: HUD draw alphas (`touch_hud/hud_draw.gd` builds on tokens), the title / splash / fs-gate / loader / prompt / hud local label twins. Merge one only on her word.

## Builders (`scripts/ui/ui_build.gd`)
- Labels and pictures: `chrome_label`, `piece`, `place`, `keep` (texture cache), `dot` (pixel brush).
- Boxes and buttons: `blank_box`, `tex_box` (textured state box), `button_base`, `ink_text`, `states` (the five states).
- Scroll bars: `bars(scroll, shown)`. Bars are hidden on object frames (the rows still scroll with the pad), shown on the cream plate.
- Tooltips: `tip_panel`, `tip_text` (used by the scroll box and the gear board).
- Use these before writing a local copy; add a builder here when a second screen needs it.
## Button hints (`prompt_view.gd`, `prompt_chip.gd`)
- Each glyph + verb pair in a hint strip is a chip. Click or tap presses that action while the pointer is down and lets go on release, the same path as the key or pad press, so the menu's own handler decides what it does. The Back chip is the touch way out of every menu.
- Chips have `focus_mode` NONE: no tab, highlight or select focus, and the menu keeps its focus.
- A strip that only lists binds (the controls sign rows, the world HUD prompt) sets `prompt_tap` false on its host.
- A scheme change (pad, keys, touch) swaps the glyphs inside the same chips, so the press that changed the scheme still lands.
- Guard: `python tools/run_smokes.py --phases 6` opens every hub menu and closes it by each Back bind, by the Back chip, and after going one to three levels in.

## Object frames (`scripts/ui/progress_ui/`)
A frame re-skins the progress panel host for one object (stall, bin). `frame_base.gd` owns what every frame shares: the chrome layer under the host, the cream plate every other mode keeps, the footer room, the button row (the host's scroll area) and its separation. `frame_set.gd` lists the skins.
A skin is a script with static hooks:
- `spec()` returns mode, chrome (node name), pos, size, footer, rows_pos, rows_size, sep, blank_rows.
- `build(chrome)` makes the pieces and labels once; `place(chrome)` positions them each open.
- Callers keep their own `prepare` / `dress` per object (text, button look).
Add a frame: write `<object>_frame.gd` (+ `<object>_art.gd` for code-drawn pictures), list it in `frame_set.gd`, set the host `mode` when it opens. A frame takes the hooks it needs and adds its own pieces; it need not look like another.

## Web export (flagged, not changed)
- `journal_page._tex_at` reads `res://assets/ui/journal/*.png` with `Image.load`; a web export ships imported textures, so loose PNGs under res:// may be absent there. Use `load()` when that page is touched.
- `ThemeS.ink_font()` asks for Windows font names; a browser may not have them. Check text fit on the web build.
- Frame art is drawn in code (no file reads).
- A missing asset fails loudly; no fallback texture or color.
