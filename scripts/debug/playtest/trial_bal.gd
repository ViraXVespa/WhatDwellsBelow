extends Object

## Process-local balance floats from --wdb-pt-trial=FILE. Does not save the slot or the defaults.

const CliArgs := preload("res://scripts/app/cli_args.gd")

static func apply() -> void:
	var path: String = ""
	var prefix: String = "--wdb-pt-trial="
	for a: String in CliArgs.args():
		if a.begins_with(prefix):
			path = a.substr(prefix.length())
	if path == "" or not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	for key: Variant in data.keys():
		var val: Variant = data[key]
		if val is float or val is int:
			App.bal.setv(str(key), float(val))
