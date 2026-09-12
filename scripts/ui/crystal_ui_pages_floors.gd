extends Object

## Crystal UI floor transport pages.

const ThemeS := preload("res://scripts/ui/theme.gd")
const Util := preload("res://scripts/ui/crystal_ui_util.gd")
const Net := preload("res://scripts/ui/crystal_ui_pages_net.gd")


static func page_floors(host) -> void:
	Util.panel(host, Vector2(520, 160), Vector2(880, 760))
	var box := VBoxContainer.new()
	box.position = Vector2(552, 192)
	box.size = Vector2(816, 696)
	box.add_theme_constant_override("separation", 8)
	host.add_child(box)
	Net.net_tabs(host, box)
	box.add_child(ThemeS.lab("Floor Transport Network", 28, Color(0.95, 0.82, 0.5)))
	var deepest := maxi(1, int(App.prog.deepest))
	if str(host.page) == "band":
		box.add_child(ThemeS.lab("Floors %d–%d" % [host.band_lo, host.band_hi], 20, Color(0.78, 0.86, 0.9)))
		list_floors(host, box, host.band_lo, mini(host.band_hi, deepest), deepest)
	elif deepest > 10:
		box.add_child(ThemeS.lab("Deepest floor: %d" % deepest, 20, Color(0.78, 0.86, 0.9)))
		var lo := 1
		var first: Button = null
		while lo <= deepest:
			var hi: int = lo + 9
			var lab := "Floors %d–%d" % [lo, hi]
			var a := lo
			var b := hi
			var btn := ThemeS.btn(lab, func(): open_band(host, a, b))
			box.add_child(btn)
			if first == null:
				first = btn
			lo += 10
		host.focus_btn = first
	else:
		box.add_child(ThemeS.lab("Deepest floor: %d" % deepest, 20, Color(0.78, 0.86, 0.9)))
		list_floors(host, box, 1, deepest, deepest)
	var back := ThemeS.btn("Back", func(): host._back())
	box.add_child(back)
	if host.focus_btn == null:
		host.focus_btn = back

static func open_band(host, lo: int, hi: int) -> void:
	host.band_lo = lo
	host.band_hi = hi
	host.page = "band"
	host._rebuild()

static func list_floors(host, box: VBoxContainer, lo: int, hi: int, deepest: int) -> void:
	var first: Button = null
	for n in range(lo, hi + 1):
		var here: bool = n == App.floor_n
		var reached: bool = n <= deepest
		var title := "Floor %d" % n
		if here:
			title += "  (here)"
		elif not reached:
			title += "  (locked)"
		var btn := ThemeS.btn(title, func(): host._pick_floor(n), reached and not here)
		box.add_child(btn)
		if first == null and reached and not here:
			first = btn
	if first:
		host.focus_btn = first
