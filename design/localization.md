# Localization

Status: current plan  
Read when: tr(), translation keys, adding a locale, converting a string, item names, plurals  

English is the default and only shipped locale. Player-facing strings go through `tr()`; the English text lives in one PO file.

## How localization works here

1. Code never holds a sentence. It holds a key such as `pause_menu.resume_run` and asks `tr(key)` (or `App.tr(key)` in a `static func`).
2. `tr()` looks the key up in the active language's PO file. `scripts/data/locale/en.po` pairs each key (`msgid`) with its English text (`msgstr`). Change a sentence by editing the `msgstr`; the key stays.
3. A key with no entry shows as the raw key, so gaps are easy to spot.
4. At startup `LocS.setup()` (`app_loc.gd`) loads every code in `LOCALES` and picks one: the `--wdb-locale=xx` flag, else the language saved in the save payload, else `en`.
5. Things that are ids (items, artifacts, skills, slots, boss roles) store the id, not the text. Screens turn the id into text with `tr()` when they draw. Saved items keep a name key (`nk`, for example `["gear.longbow"]`) and a `forged` flag; `ItemNames.name_of()` builds the name from them, and the saved `name` is a cache that `ItemNames.refresh()` rewrites on load and on language change. The description works the same way: `ItemNames.desc_of()` derives it from slot, rarity, tool, `charge_max` or the artifact id (`item.<id>.desc`), and `desc` is a cache rewritten by the same calls. The ghost shop stock holds ids only; the shop screen looks up name and text when it draws.
6. The Gameplay settings page has a Language row. It cycles `LOCALES`; with one language it changes nothing. The choice is saved as `locale` with the other preferences.
7. Controls only translate when their text is assigned, so a language change shows after a screen rebuild (the row rebuilds its page).

## Files

| Path | Role |
|------|------|
| `scripts/data/locale/en.po` | Source strings, sorted by key. Plural entries use `msgid_plural` and `msgstr[n]`. |
| `scripts/app/app_loc.gd` | `LocS`: `setup`, `set_locale`, `apply_saved`, `next_locale`, `name_of`, `plural(key, n)`, `tr_or(key, fallback)`. |
| `scripts/data/item_names.gd` | `ItemNames`: `base_nk`, `name_of`, `desc_of`, `rarity_name`, `type_name`, `forge`, `refresh`, `migrate` (old saves). |

Registration: `project.godot` `[internationalization]` lists `en.po`. `setup()` skips locales already registered, so there are no duplicates. The OS locale is ignored on purpose.

## Key naming

`<file stem>.<slug>`, lowercase, dots and underscores only. The slug is the first words of the English text (about five words, 32 chars). A string used in two or more places is `common.<slug>`. Collisions get `_2`. Keys never look like English text, so a Control's auto-translate cannot double-translate. Id-derived keys: `item.<id>.name`, `item.<id>.desc`, `rarity.<id>`, `set.<id>.name`, `gear.desc_piece` / `desc_tool` / `desc_potion` / `desc_food`, `skill.<id>`, `slot.<slot>`, `boss.<role>`, `gear.<type>`. Never rename a shipped key; if the wording changes, edit only the `msgstr`.

## Add a string

1. Add a `msgid`/`msgstr` pair to `en.po`, in sorted order (escape `\\ \" \n \t`).
2. Write `tr("scope.key")`, or `App.tr(...)` inside a `static func`.
3. New strings use named placeholders: `tr(k).format({"gold": g})` with `{gold}` in the `msgstr`. Do not build sentences by `+`.
4. Never call `tr()` in a class-level `const`/`var` initialiser, a func default, or for ids, node names, dict keys, log or debug text.
5. Run the English check: every key translates to its `msgstr`; converted sites read as before.

## Add a locale

1. Copy `en.po` to `<code>.po`, set `Language:` and `Plural-Forms:`, translate each `msgstr` (and every `msgstr[n]`).
2. Add the code to `LOCALES` in `app_loc.gd` and set a `locale.name` entry (shown in the Language row).
3. Run with `--wdb-locale=<code>`, or pick it in settings.
4. Check fonts and layout (Decisions 5-6) before shipping a language.

## Status

Player-facing sites are converted (menus, prompts, tutorial, quest, shop, tables by id, named-placeholder messages). Const tables hold no English: `LocS.tr_or(key, fallback)` uses an id or `capitalize()` default for a missing key only. The one exception is the bind table (`input/binds/table.gd`), whose `label` is the missing-key default for `controls.<id>`. Boss titles carry a role id (`gate_master`, `guardian`) through `Gen.boss_role` into combat. The HUD prompt colour reads the `prompt_locked` flag (`App.interact_locked`), not text.

| Left in English | Why |
|-----------------|-----|
| `archive_catalog.json` label/desc | shared data file; the PO overrides it by `archive.<id>.*` |
| `input/prompts.gd` key and button names (`Esc`, `D-pad Up`, `LMB`) | hardware labels derived from the bind id; `sprite_filter.gd` keeps `Filter %d` as its missing-key default |
| `data/tunables.gd` `ONE_LINER`, `foundation.gd` hint, `launch.gd` name | const or dev text |
| `debug/*`, smokes, logs, ids, node names | out of scope |

## Decisions

1. **Keys**: keep `<file stem>.<slug>`; a rename pass can use a key-map script later.
2. **Plurals**: `LocS.plural(key, n)` wraps `tr_n`; the PO holds `msgid_plural` and `msgstr[n]`; callers write `LocS.plural(k, n) % n`. English `Plural-Forms: nplurals=2; plural=(n != 1);`. Used by `forge_act.kept_hold` and `anvil_forge_job.stopped_the_queue_pick_from`. Languages with more forms only add `msgstr[n]` lines.
3. **Placeholders**: named for new strings; positional strings convert when touched.
4. **Persistence**: `locale` is stored in the save payload next to the other preferences (there is no separate settings file). A launch flag beats the saved value. A missing or unknown value means `en`.
5. **Fonts (plan)**: before a CJK, Cyrillic, Thai or Arabic locale, choose a UI font with the glyphs, set a fallback chain on the theme, and check label widths and truncation on the longest screens.
6. **Right-to-left (plan, not built)**: set `Control.layout_direction` from the locale, mirror HBox order and anchors, align text to the start side, test bidi runs (numbers, item names inside sentences), and keep arrow glyphs and the HUD layout flippable. No RTL code exists; no locale needs it.
7. **Names from ids**: `nk` plus `forged` is the truth, `name` a cache. `ItemNames.migrate` runs in `Norm.normalize_item`: it infers `nk` from an old English `name` (exact match to a known key, optionally "Forged "), and leaves unmatched names untouched.
