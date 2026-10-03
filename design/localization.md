# Localization

Status: binding design  
Read when: tr(), translation keys, adding a locale, converting a string  

English is the default locale and reads exactly as before. Player-facing strings go through Godot's `tr()`; the English text lives in one PO file.

## Files

| Path | Role |
|------|------|
| `scripts/data/locale/en.po` | Source strings: `msgid` = key, `msgstr` = English. Sorted by key. |
| `scripts/app/app_loc.gd` | `LocS.setup()` (called first in `app_boot._ready`): loads each code in `LOCALES`, picks the locale. `LocS.tr_or(key, fallback)` reads const tables. |

Registration: `project.godot` `[internationalization]` lists `en.po` (new locales are also added to `LOCALES` below). `setup()` is idempotent and also picks the locale.

Locale choice: default `en`. `--wdb-locale=xx` (web: `?wdb-locale=xx`) selects another code in `LOCALES`; unknown codes fall back to `en`. `LocS.set_locale(code)` is the hook for a future settings UI. The OS locale is ignored on purpose. Nothing is saved.

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

## Status

**Pass 1** (548 sites, 448 keys, 74 files): menus, prompts, hints, titles, tutorial, quest, shop, dialog labels, plain `tr("key")` swaps. **Pass 2** (+198 keys, 646 total): data tables by id, named-placeholder messages, small leftovers.

Pass 2 by id (const tables keep their English in code as a fallback; a PO entry overrides it through `LocS.tr_or(key, fallback)`):

| Table | Keys | Read through |
|-------|------|--------------|
| `data/catalog.gd` artifacts | `item.<id>.name`, `item.<id>.desc` (24 ids) | `Catalog._loc()` in `pick`/`by_id` |
| `catalog.gd` set bonus lines | `set.<set>.bonus` (8) | `App.tr` |
| `data/affixes.gd` | `affix.<id>.label` (13) | `App.tr` in `defs()` |
| `archive_catalog.json` | `archive.<id>.label`/`.desc` (12 ids) | `ArchivesCatalog.all()` |
| skills | `skill.<id>` (11) | `bars`, `pause_skills`, `theme.skill_name` |
| gear slots | `slot.<slot>` (7) | `text_fmt.slot_name()` |
| binds / controls | `controls.<action>` (15) | `binds_page`, `ui_hub` |
| sprite filter | `sprite_filter.label_<n>` (5) | `sprite_filter.label()` |

Named-placeholder messages (`tr(k).format({...})`, 25 sites): gear bag toasts, extract, rules_kit, quest, shop, recap, set bonus, board text, anvil/forge picks, sub_open heads, restock, archive launch status, binds reset. Also converted: archive launch statuses, `binds_page` buttons, interact titles (STAIRS...), skill/style names, small labels.

**Not converted** (listed for a later pass):

| Area | Why |
|------|-----|
| `dungeon/gen.gd` boss titles "Gate Master"/"Floor Guardian" | compared as ids in combat code; needs role ids first |
| `ui/hud/hud_act.gd:92` | classifies toasts with `begins_with("Locked")` etc.; needs a kind flag |
| item names saved in slots (`gear_roll` "Forged ", weapon names, `forge_act`, `progress_make`) | text is persisted in the save; needs name from id at display |
| `data/tunables.gd` `ONE_LINER` | const; used in about text |
| `world/foundation.gd` hint, `launch.gd` project-name string | dev text |
| plural-suffix `%s` (see Decisions 2) | waits for `tr_n` |
| English fallbacks kept in const tables (catalog 48, binds 6, skills, sprite labels) | harmless duplicates; drop once a second locale exists |

Out of scope by design: `debug/*`, smokes, playtest and log text, ids and node names.

## Decisions (owner delegated, 2026-10-03)

1. **Keys**: keep `<file stem>.<slug>`. A rename pass is cheap later with a key-map script; not planned.
2. **Plurals**: use `tr_n` and PO plural forms when a second locale is actually added. Until then `%s` suffix cases stay: `anvil_forge_job.stopped_the_queue_pick_from` ("piece%s") and `forge_act.kept_hold` ("hold%s").
3. **Placeholders**: new strings use named placeholders: `tr("scope.key").format({"gold": g})` with `{gold}` in the `msgstr`. Existing positional `%s`/`%d` strings convert opportunistically when touched.
4. **Locale persistence**: save the choice in settings (not the save slot) when a settings row is added. Not built.
5. **Data tables** (catalog, affixes, archives): translate by id, key derived from the id (`item.<id>.name`). Done in pass 2; quest titles still come from generated text.
6. **Fonts and RTL**: deferred until a target language is chosen. Then: pick a UI font with the needed glyphs (CJK/Cyrillic/Thai fallback chain), check label widths, and add mirrored layout for RTL.

Registration: `project.godot` lists `en.po` under `[internationalization]`. `LocS.setup()` skips a locale that is already registered, so there are no duplicates; it still adds any other code in `LOCALES` and picks the locale.
