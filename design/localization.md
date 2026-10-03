# Localization

Status: binding design  
Read when: tr(), translation keys, adding a locale, converting a string  

English is the default locale and reads exactly as before. Player-facing strings go through Godot's `tr()`; the English text lives in one PO file.

## Files

| Path | Role |
|------|------|
| `scripts/data/locale/en.po` | Source strings: `msgid` = key, `msgstr` = English. Sorted by key. |
| `scripts/app/app_loc.gd` | `LocS.setup()` (called first in `app_boot._ready`): loads each code in `LOCALES`, picks the locale. |

Why runtime registration: `project.godot` is outside the bot allowlist. Owner follow-up (optional): add `locale/translations=PackedStringArray("res://scripts/data/locale/en.po")` under `[internationalization]`, then the editor and exports know the file without the helper (keep `setup()` for the locale choice).

Locale choice: default `en`. `--wdb-locale=xx` (web: `?wdb-locale=xx`) selects another code in `LOCALES`; unknown codes fall back to `en`. `LocS.set_locale(code)` is the hook for a future settings UI. The OS locale is ignored on purpose. Nothing is saved yet.

## Key naming

`<file stem>.<slug>`, lowercase, dots and underscores only (`pause_menu.resume_run`). The slug is the first words of the English text (about five words, 32 chars). A string used in two or more places is `common.<slug>` (`common.back`). Collisions get `_2`. Keys never look like English text, so a Control's auto-translate cannot double-translate.

Never rename a shipped key: translators key on it. If the English wording changes, edit only the `msgstr`.

## Add a string

1. Pick a key by the rules above and add a `msgid`/`msgstr` pair to `en.po`, in sorted order (escape `\\ \" \n \t`).
2. In code write `tr("scope.key")`. Inside a `static func` write `App.tr("scope.key")` (`tr` is an instance method; `App` is an autoload).
3. Formatting stays positional: `tr("hud.gold_fmt") % [gold]`, with `%s`/`%d` kept in the `msgstr`. Do not build sentences by `+` concatenation; make one key with a placeholder instead.
4. Never call `tr()` in a class-level `const`/`var` initialiser, in a func signature default, or for ids, node names, dict lookup keys, log or debug text.
5. Run the English check: every key must translate to its `msgstr` and every converted site must read the same as before.

## Add a locale

1. Copy `en.po` to `<code>.po` (for example `de.po`) in the same folder.
2. Set the `Language:` header; translate each `msgstr`. Leave `msgid` alone.
3. Add the code to `LOCALES` in `app_loc.gd`.
4. Run with `--wdb-locale=de`.
5. Missing keys show the raw key, which makes gaps easy to spot. Controls only translate when their text is assigned, so a language change at runtime needs the screen rebuilt.

## Status (this pass)

Converted: 548 sites, 448 keys (66 are `common.`) in 74 files; 468 of the sites are in static helpers (`App.tr`). Areas (sites): `ui/gear_board` 82, `ui/progress_ui` 67, `world/interact` 54, `ui/theme` 34, `data/progress_gear` 31, `ui/recap` 29, `ui/crystal_ui` 24, `data/progress` 23, `ui/pause_settings*` 36, `ui/hud` 16, `data/progress_quest` 15, `data/gear_rules` 13, `ui/archives_ui*` 17, `ui/fs_gate` 12, `world/gather` 11, `title*` 13, `app/*` 11, `world/*` other 21, `data/progress_forge` 6, `display_mode` 6, others 27.

Not converted (about 130 prose strings, plus short words and labels counted by hand later):

| Area | Approx. | Why |
|------|---------|-----|
| `data/catalog.gd` item names and blurbs | 48 | const data tables; needs a lookup-by-id key scheme |
| `data/archives/*` | 12 | text built in data modules |
| `ui/gear_board/*` fragments | 12 | `"Hold  " + name` concatenation |
| `data/affixes.gd` | 10 | const label table |
| `ui/binds_page.gd` | 10 | const action-label dict |
| `ui/progress_ui/shop.gd` | 6 | concatenated messages |
| `data/progress_gear`, `progress_quest`, `gear_roll`, `progress_forge`, `extract` | 10 | concatenated toasts |
| `world/sprite_filter.gd`, `boss_door.gd`, `dungeon/gen.gd`, `ui/hud` leftovers | 9 | option names, repeat prompts, boss titles |
| `world/foundation.gd`, `ui/step_row.gd` | few | const or debug-adjacent |

Out of scope by design: `debug/*`, smokes, playtest and log text, ids and node names.

## Open questions

- Key scheme: is file-stem keys fine, or should keys be semantic (`menu.pause.resume`) so moving code does not touch the PO?
- Plurals: many strings use `%s` for a plural suffix ("piece%s"). Use `tr_n` and PO plural forms?
- Named placeholders (`{gold}`) instead of positional `%s`/`%d`?
- Fonts for CJK, Cyrillic, Thai; the bundled UI font is Latin-oriented.
- Right-to-left layout and mirrored HUD.
- Item/affix/quest content in data tables: translate by id or by text?
- Persist the locale in the save slot and add a settings row?
- Register the PO in `project.godot` (needs owner approval)?
