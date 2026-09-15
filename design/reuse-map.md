# Reuse map

Status: protocol + live snapshot
Read when: the User names reuse, extract, DRY, shared helpers, or this file
See also: `AGENTS.md`, `design/refactor.md`, `design/grok-bot-session.md`, `design/README.md`, `design/constraints.md`, `design/ui.md`, `design/ui-theme.md`

This file is the reuse / extract index. It is not a feature list and not a license to invent skills, rarities, hub upgrades, meta-progression, or co-op.

**Grok Bot** opens this file only when the User names reuse, extract, DRY, or shared helpers. Do not load it on a normal size-split sweep.

**Grok Build / web / chat** may read it for the same named work. Web / chat still follows `design/web-session.md` (one goal, no source in a docs-only session).

Do not walk the whole live tree to rediscover copies. Use the worklist below. Verify a listed body before moving it.

## How to use

1. Inventory the named cluster with `tools/list_oversize_scripts.ps1` if size is also in scope.
2. Take the next **Worklist** item that matches the User’s ask. One cluster per Bot PR.
3. Prefer an **existing owner** when that owner already is the concern and stays under the 10KB ship floor.
4. Prefer a **new shared module** when near-identical control flow spans systems and the owner would blow the cap or is the wrong concern.
5. Kits (token sheet, overlay shell, item view) are in the default worklist for this named work. They are small new APIs. Do not grow them into a widget framework or `Entity.gd`.
6. After a slice: compile, run smokes, stop and report. Do not start a 5KB cleanliness sweep in the same run unless a touched file is over 10KB.

Binding design stays. Live snapshot is current code. If they disagree, patch live toward binding or ask.

---

# Live snapshot — existing owners

Route here before creating a file.

| Concern | Owner |
|---------|--------|
| Label / button / StyleBoxFlat / skill row / skill tip text / bind chip | `scripts/ui/theme.gd` (`ThemeS.lab`, `btn`, `sb`, `skill_row`, `skill_tip`, `bind_text`) |
| UI text scale / `font_px` | `scripts/ui/ui_text.gd` |
| Menu confirm / back / tab / page | `scripts/ui/menu_pad.gd` |
| Footer hint strip | `scripts/ui/prompt_view.gd` |
| Modal yes / no | `scripts/ui/confirm_dlg.gd` |
| Overlay chrome + two-column list / detail + `wire_vert` | `scripts/ui/split_menu_chrome.gd`, `scripts/ui/split_menu_view.gd` |
| Pause caps / sliders / tip hide / pending confirm flag | `scripts/ui/pause_menu_util.gd` |
| − / value / + row | `scripts/ui/step_row.gd` |
| Gear flyout host + place | `scripts/ui/gear_board/gear_board_tip.gd` |
| Item rarity color / risk / charges | `scripts/ui/gear_board/gear_board_text_fmt.gd` |
| Gear short / cell / tooltip / stats copy | `scripts/ui/gear_board/gear_board_text.gd` |
| Pause bag short / cell / detail | `scripts/ui/pause_inv_text.gd` |
| XP curve / skill level | `scripts/data/progress_combat.gd` (`skill_lv`, `level_from_xp`, `xp_to_reach`, `xp_to_next`, `xp_ratio`) |
| Item templates | `scripts/data/progress_make.gd` |
| Affix roll + stamp | `scripts/data/gear_roll.gd` |
| Artifact catalog + set bonus lines | `scripts/data/catalog.gd` |
| Room AABB | `scripts/dungeon/gen_rooms_place.gd` `in_room` |
| World interact sprite / used-chest fade / Label3D | `scripts/world/interact_fx.gd` |
| Sprite filter / mips | `scripts/world/sprite_filter.gd` |
| Cover / sprite projection | `scripts/combat/cover.gd`, `cover_geom.gd`, `cover_hit.gd` |
| Combat LOS | `scripts/combat/combat.gd` (playtest already calls this) |
| World HP bar (Sprite3D ImageTexture) | `scripts/combat/hp_bar.gd` |
| Floating damage | `scripts/combat/float_num.gd` |
| Device move / aim / held | `scripts/input/pad.gd` |
| Web JS gamepad | `scripts/web_pad.gd` |
| Touch overlay | `scripts/input/touch_pad.gd` |
| Look wheel / pinch | `scripts/input/look_ctrl.gd` |
| Glyph text | `scripts/input/prompts.gd` |
| Gear slot icons | `scripts/ui/gear_icons.gd` |
| Display web vs desktop | `scripts/display_mode.gd` + `_web` / `_desk` |
| Enter / wake overlay | `scripts/ui/present.gd` |
| Crystal zoom / map pin | `scripts/ui/crystal_ui_util.gd` |
| Dungeon map pan / zoom | `scripts/world/dungeon_map_act.gd` |

Archives UI already uses SplitMenu. Binds page already uses `ThemeS` + `SplitView`. FS gate already wraps `ThemeS.lab` / `btn`. Anim browser already uses `ThemeS.lab` / `btn` but still builds its own dim + gold edge.

---

# Unified plate tokens

All dungeon overlay plates use SplitMenu chrome. Do not keep per-caller dim / plate / edge literals.

| Token | Value |
|-------|--------|
| Dim | `Color(0.03, 0.02, 0.02, 0.82)` |
| Plate | `Color(0.13, 0.10, 0.08, 0.97)` |
| Edge | `Color(0.55, 0.42, 0.22, 1)` |
| Edge height | `8` |

Title / splash / FS-gate void (`Color(0.06, 0.05, 0.045, 1)`) and `present.gd` stay off this sheet.

---

# Worklist

Do in this order unless the User names one item. Skip BOT-08 only if the User later says so; this session keeps it in the default list.

## BOT-01 — Plate chrome

**Kind:** new module or grow `theme.gd` only if it stays under 10KB.

Helpers: `dim(parent, color := DIM)`, `plate(parent, pos, size, bg := PLATE)`, `edge(parent, pos, width, height := 8)`.

Call sites that already share this stack:

- `scripts/ui/split_menu_chrome.gd` `setup_overlay` (canonical; after unify it still calls the helper)
- `scripts/ui/confirm_dlg.gd`
- `scripts/ui/crystal_ui_util.gd` `panel`
- `scripts/ui/crystal_ui.gd` `_rebuild` dim
- `scripts/title_news_show.gd` dim + plate + edge
- `scripts/debug/anim_browser_ui.gd` dim + preview well + gold edge (already same tokens)
- `scripts/ui/loader.gd` — reuse the **edge color / height token only**, not the full menu plate

Do not fold `ThemeS.sb()` (StyleBoxFlat) into ColorRect plates.

## BOT-02 — Label factory

**Kind:** route to `ThemeS.lab`.

Add optional align / wrap / outline flags on `ThemeS.lab` if that is the only way to keep appearance identical. Do not add `label_util.gd`.

| Site | Rule |
|------|------|
| `pause_menu_util.cap` | Route; keep missing outline if that is current look |
| `title.gd` `_lab` | Route only if pixel-identical |
| `pause_skills.gd` `skill_lab` | Route |
| `recap_bars.gd` `skill_lab` | Route |
| `hud_view.gd` `lab` | Route only if pixel-identical |
| `splash.gd` `_lab` | Route only if pixel-identical; splash branding colors stay |
| `fs_gate.gd` `_lab` | Already wraps `ThemeS.lab` |
| `loader.gd` captions | Route only if pixel-identical |

## BOT-03 — Item short text + rarity

**Kind:** move matching bodies into `scripts/ui/gear_board/gear_board_text_fmt.gd`, then call it.

Owner already has `item_color`, `is_risk`, charges.

Move `item_short` / `item_cell` here if pause inv and gear board bodies match after local names.

Call sites: `pause_inv_text.gd`, `gear_board_text.gd`, `progress_ui_shop.gd` button labels when they inline name + rarity + hold.

Keep `pause_inv_text.detail_text` / `stat_line` / `extract_note` on pause inv unless a later body diff is identical. Keep board tooltip / stats pages on `gear_board_text.gd`.

## BOT-04 — XP math

**Kind:** route. Do not copy the curve again.

Delete local `xp_lv` / `xp_to_next` / `xp_ratio` in `pause_skills.gd` and `recap_bars.gd`. Call `ProgressCombat`.

Do not merge recap dual-span bars with pause single-fill bars.

## BOT-05 — Settings slider

**Kind:** route to `pause_menu_util.slider_row`.

`pause_settings_pages.gd` `_slider` may omit the value caption. Add an optional arg on `slider_row` for that. Do not create a third slider widget.

`debug_menu_settings.gd` `_slider`: route only if the body is the same HSlider wrapper. Debug value **SpinBox** grid stays on `debug_menu_val*`.

`step_row.gd` stays a different control.

## BOT-06 — Tooltip place geometry

**Kind:** new `scripts/ui/tip_place.gd`.

Extract only flip / clamp / defer-to-next-frame / footer cutoff. Signature stays dumb: anchor rect + tip host + footer top.

- `gear_board_tip.gd` keeps gear text (`Text.tooltip`)
- `pause_skills.gd` keeps skill text (`ThemeS.skill_tip`)
- `pause_menu_util.paint_tip` stays a dispatcher

Do not merge gear flyouts and skill tips into one feature.

## BOT-07 — `in_room`

**Kind:** route to `scripts/dungeon/gen_rooms_place.gd` `in_room`.

`crystal_place.gd` `_in_room` is the same AABB. Call the gen helper.

`_room_exits` vs `room_exits` share a walk but not the floor test (`host._is_floor_cell` vs `PackedByteArray`). Do not invent a callback API unless the rest of both functions is identical after that test. Default: share `in_room` only.

## BOT-08 — Billboard Sprite3D

**Kind:** route to `interact_fx.sprite`, or a sibling next to `scripts/world/interact_fx.gd` if that file would go over 10KB.

Same flags: `Sprite3D`, centered, unshaded, billboard Y, pixel_size from texture height, `SpriteFilt`, Y offset.

Sites: `interact_fx.sprite`, `player_setup.make_sprite`, `dummy.gd` `_ready` sprite, `breakable.gd` `_spr`, `gather_node` visual if the body matches, `pickup.gd` `_visual` only if flags match.

Do not fold collision, HP bars, or death tweens into this helper.

## BOT-09 — Vertical focus wire

**Kind:** route to `split_menu_view.wire_vert`.

`title.gd` `_wire_focus` / `_loop_btn` when the control list is one column. `fs_gate.gd` two-button neighbors may call `wire_vert([action, continue])`. Confirm already does.

## BOT-10 — ColorRect fill meter

**Kind:** extract only after a body diff.

If `hud_view.meter` and `pause_skills.xp_bar` are both parent track + child fill + ratio, a short helper is legal. Recap dual-span stays recap-local and may *call* that helper per span. World `hp_bar.gd` is not this.

## Kits (default list)

Small new APIs. Stop at the stated surface.

### Kit A — Token sheet

One place for dim / plate / edge / edge height (table above) plus overlay z-index if both confirm and SplitMenu use the same value. Loader uses edge tokens only. Title / splash void stays separate.

### Kit B — Overlay shell

Dumb builder: dim → plate → gold edge → title slot → body slot → `PromptView` footer → restore focus on close.

Content stays in the caller (confirm copy, news RichText, crystal map, loader bar). No wizard, no menu router, no “any UI.”

### Kit C — Item view

Grow `gear_board_text_fmt.gd` (or a sibling if cap requires) to `{ short, cell, color, risk, charges, detail_lines }` from an item dict. Do not introduce a `class_name` Item Resource in the same sweep as chrome.

---

# Lane A — route, don’t invent

Quality notes that are call-site routing, not new systems.

- Pause and recap must use `ProgressCombat` for XP math (BOT-04).
- Pause, board, shop, tooltip must use one item sentence / color path (BOT-03 / Kit C).
- Player menus classify input through `menu_pad` and footers through `PromptView`. Do not rebuild hint `HBox`es.
- Overlay look is the unified plate tokens (BOT-01 / Kit A–B).
- When already in a file, follow `AGENTS.md` types and warnings on rewritten lines only. Do not convert a file for style.

---

# Do not merge

- `gather_node` vs `breakable` vs `pickup` vs used-chest fade
- `player_hit*` vs `enemy_hit.take_hit` vs dummy `take_hit`
- World `hp_bar.gd` vs HUD meters vs recap XP bars (except BOT-04 math and a confirmed BOT-10 ColorRect helper)
- `progress_ui` mode rebuild vs SplitMenu chrome
- Title / splash / FS-gate void vs dungeon dim plates
- `present.gd` vs menu dim
- `web_pad.gd` vs `input/pad.gd` vs `touch_pad.gd` (optional two-line deadzone helper only if the body is identical and reused)
- `display_mode` web vs desktop
- `dungeon_map_act` pan / zoom vs `crystal_ui_util.place_mark`
- `step_row` vs sliders vs debug SpinBox
- `interact_prompt.gd` (Label3D / kind strings) vs `PromptView`
- Playtest grid walk vs combat cover sprite projection
- Playtest log / path / AI internals into combat or world
- `Entity.gd`, a UI framework, ECS, or flattening hostify clusters back into one oversized script
- Restyling debug value editors to match pause (debug MAY stay engine-default; plate tokens apply only where debug already reused dungeon chrome)
- New skills, rarities, hub upgrades, meta-progression, or co-op

---

# PR order

One cluster per Bot session.

1. Kit A tokens + BOT-01 call sites
2. Kit B overlay shell if chrome call sites still rebuild dim / plate / edge by hand
3. BOT-02 `ThemeS.lab`
4. BOT-03 / Kit C item view
5. BOT-04 XP math
6. BOT-05 slider optional arg
7. BOT-06 tip place
8. BOT-07 `in_room`
9. BOT-08 sprite maker
10. BOT-09 `wire_vert`
11. BOT-10 only after the HUD vs pause-bar body diff

Touched live `scripts/**/*.gd` must ship under 10KB. Split with `design/refactor.md` if a kit file goes over. Do not keep splitting toward 5KB in the same run.

Public entry points that must not change when a helper is split: `App.playtest`, `App.set_zoom` / `App.set_hud_scale` / `App.set_volume`, `PauseInv.*`, `Gen.generate` / `Gen.make_opening`, `EnemyAI.tick`, `SmokeLate.p5`–`p9`, `ProgressGear.make_*`.
