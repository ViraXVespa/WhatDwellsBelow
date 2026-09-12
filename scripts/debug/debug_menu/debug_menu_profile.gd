extends Object

## Named balance profiles. Host is scripts/debug/debug_menu/debug_menu.gd.


static func page_profiles(host) -> void:
	host.status.text = "Unlimited named profiles. Saved under user://wdb_profiles/"
	var le := LineEdit.new()
	le.text = host.profile_name
	le.custom_minimum_size = Vector2(360, 36)
	le.focus_mode = Control.FOCUS_ALL
	le.text_changed.connect(func(t): host.profile_name = t)
	host.root_box.add_child(le)
	host.root_box.add_child(host._btn("Save", func(): save_profile(host); host.status.text = "Saved " + host.profile_name))
	host.root_box.add_child(host._btn("Load", func(): load_profile(host); host.status.text = "Loaded " + host.profile_name; host.page = "values"; host._rebuild()))
	host.root_box.add_child(host._btn("Delete", func(): delete_profile(host); host.status.text = "Deleted " + host.profile_name))
	host.root_box.add_child(host._btn("Rename current to field", func(): rename_profile(host); host.status.text = "Renamed"))
	host.root_box.add_child(Label.new())
	for n in list_profiles():
		var nm := n
		host.root_box.add_child(host._btn("Load " + nm, func(): host.profile_name = nm; load_profile(host); host.status.text = "Loaded " + nm))


static func dir() -> String:
	return "user://wdb_profiles"


static func list_profiles() -> PackedStringArray:
	var d := DirAccess.open("user://")
	if d and not d.dir_exists("wdb_profiles"):
		d.make_dir("wdb_profiles")
	var out: PackedStringArray = PackedStringArray()
	var pd := DirAccess.open(dir())
	if pd == null:
		return out
	pd.list_dir_begin()
	var f := pd.get_next()
	while f != "":
		if f.ends_with(".json"):
			out.append(f.get_basename())
		f = pd.get_next()
	return out


static func save_profile(host) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir()))
	var data := {}
	for row in App.bal.schema():
		data[str(row[0])] = App.bal.getv(str(row[0]))
	var f := FileAccess.open("%s/%s.json" % [dir(), host.profile_name], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		host.loaded_profile = host.profile_name


static func load_profile(host) -> void:
	var f := FileAccess.open("%s/%s.json" % [dir(), host.profile_name], FileAccess.READ)
	if f == null:
		host.status.text = "Missing profile."
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		for k in d.keys():
			App.bal.setv(str(k), float(d[k]))
		host.loaded_profile = host.profile_name


static func delete_profile(host) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.json" % [dir(), host.profile_name]))


static func rename_profile(host) -> void:
	var prev: String = host.loaded_profile
	save_profile(host)
	if prev != "" and prev != host.profile_name:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.json" % [dir(), prev]))
	host.loaded_profile = host.profile_name
