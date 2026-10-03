extends Object

## Localization setup. English ("en") is the default locale and the only one shipped (scripts/data/locale/en.po).
## Keys are "<file stem>.<slug>" or "common.<slug>". How to add a string or a locale: design/localization.md.

const CliArgs := preload("res://scripts/debug/cli_args.gd")
const DEFAULT := "en"
const LOCALES: PackedStringArray = ["en"]
const DIR := "res://scripts/data/locale/"

static func setup() -> void:
	for code: String in LOCALES:
		var have: Translation = TranslationServer.get_translation_object(code)
		if have != null and have.locale == code:
			continue  # already registered via project.godot
		var table: Translation = load(DIR + code + ".po") as Translation
		if table != null:
			TranslationServer.add_translation(table)
	set_locale(requested())

## Locale from `--wdb-locale=xx` (URL `?wdb-locale=xx` on web); anything unknown falls back to English.
static func requested() -> String:
	for arg: String in CliArgs.args():
		if arg.begins_with("--wdb-locale="):
			return arg.substr(13)
	return DEFAULT

## Translated text for `key`, or `fallback` when the key has no entry (for const tables that keep English in code).
static func tr_or(key: String, fallback: String) -> String:
	var t: String = TranslationServer.translate(key)
	return fallback if t == key else t

static func set_locale(code: String) -> void:
	TranslationServer.set_locale(code if code in LOCALES else DEFAULT)
