extends Object

## Localization setup. English ("en") is the default locale and the only one shipped (scripts/data/locale/en.po).
## Keys are "<file stem>.<slug>" or "common.<slug>". How to add a string or a locale: design/localization.md.

const CliArgs := preload("res://scripts/debug/cli_args.gd")
const DEFAULT := "en"
const LOCALES: PackedStringArray = ["en"]
const DIR := "res://scripts/data/locale/"

static var current := DEFAULT
static var _flag := false

static func setup() -> void:
	for code: String in LOCALES:
		var have: Translation = TranslationServer.get_translation_object(code)
		if have != null and have.locale == code:
			continue  # already registered via project.godot
		var table: Translation = load(DIR + code + ".po") as Translation
		if table != null:
			TranslationServer.add_translation(table)
	var want: String = requested()
	_flag = want != ""
	set_locale(want if _flag else DEFAULT)

## Locale from `--wdb-locale=xx` (URL `?wdb-locale=xx` on web); empty when the flag is absent.
static func requested() -> String:
	for arg: String in CliArgs.args():
		if arg.begins_with("--wdb-locale="):
			return arg.substr(13)
	return ""

## Translated text for `key`, or a safe `fallback` (an id, never English prose) when the key has no entry.
static func tr_or(key: String, fallback: String) -> String:
	var t: String = TranslationServer.translate(key)
	return fallback if t == key else t

static func set_locale(code: String) -> void:
	current = code if code in LOCALES else DEFAULT
	TranslationServer.set_locale(current)

## Locale saved in the settings; a launch flag wins over it, empty means "no saved choice".
static func apply_saved(code: String) -> void:
	if code != "" and not _flag:
		set_locale(code)

static func next_locale() -> String:
	return LOCALES[(LOCALES.find(current) + 1) % LOCALES.size()]

## The language's own name, from its PO (`locale.name`).
static func name_of(code: String) -> String:
	var t: Translation = TranslationServer.get_translation_object(code)
	var n: String = str(t.get_message("locale.name")) if t != null and t.locale == code else ""
	return n if n != "" else code

## Plural form of `key` for `n` (PO msgid_plural entry); use `% n` on the result.
static func plural(key: String, n: int) -> String:
	return App.tr_n(key, key, n)
