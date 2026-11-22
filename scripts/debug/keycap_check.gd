extends RefCounted

## Controls page probe (camp-controls flow, with the page open). .rows: every bind slot button (binds_page.gd tags
## each with bind_slot = [action, pool, slot]) shows the keycap / glyph texture for its live binding, and the name the
## player reads (the button text, or the tooltip on an icon-only one-letter key) names that same input; at least 20
## slots must be seen. .plant_caught: an M keycap captioned H, a keycap from another binding and a missing glyph fed
## to the same validator must each fail.

const Binds := preload("res://scripts/input/binds.gd")
const Prompts := preload("res://scripts/input/prompts.gd")

## Label words whose glyph id differs from the plain lowercase of the word.
const ALIAS := {"start": "menu", "l3": "ls", "r3": "rs", "lstick": "ls", "rstick": "rs", "[": "lbracket", "]": "rbracket"}

static func _norm(s: String) -> String:
	var n := s.to_lower().replace(" ", "").replace("-", "").replace("_", "")
	return str(ALIAS.get(n, n))

## The first fault for one slot, or "".
static func validate(tag: String, ev: InputEvent, icon_path: String, shown: String) -> String:
	if ev == null:
		return "" if shown == "—" else "%s: unbound slot reads %s" % [tag, shown]
	var want := Prompts.path_for_event(ev, tag.get_slice(":", 1))
	var label := Prompts.label_for_event(ev)
	if want != "" and ResourceLoader.exists(want) and icon_path != want:
		return "%s: keycap %s, binding wants %s" % [tag, icon_path.get_file(), want.get_file()]
	if shown != label:
		return "%s: reads %s, binding is %s" % [tag, shown, label]
	var stem := _norm(icon_path.get_file().get_basename())
	if icon_path != "" and stem != _norm(label):
		return "%s: keycap %s vs label %s" % [tag, stem, label]
	return ""

var rows: String:
	get:
		var tree := Engine.get_main_loop() as SceneTree
		var seen := 0
		for n: Node in tree.root.find_children("*", "Button", true, false):
			if not n.has_meta("bind_slot") or not (n as Button).is_visible_in_tree():
				continue
			var b := n as Button
			var s: Array = b.get_meta("bind_slot")
			var ev: InputEvent = Binds.slot_event(str(s[0]), str(s[1]), int(s[2]))
			var icon_path := b.icon.resource_path if b.icon else ""
			var shown := b.text if b.text != "" else b.tooltip_text
			var bad := validate("%s:%s:%d" % s, ev, icon_path, shown)
			if bad != "":
				return bad
			seen += 1
		return "" if seen >= 20 else "only %d bind slots seen" % seen

var plant_caught: String:
	get:
		var m := InputEventKey.new()
		m.physical_keycode = KEY_M
		var dir := "res://assets/ui/prompts/kb/"
		var plants := {
			"M captioned H": validate("map_view:kb:0", m, dir + "m.png", "H"),
			"wrong keycap": validate("map_view:kb:0", m, dir + "h.png", "M"),
			"no glyph": validate("map_view:kb:0", m, "", "M"),
		}
		for name: String in plants:
			if plants[name] == "":
				return "planted %s passed" % name
		return ""
