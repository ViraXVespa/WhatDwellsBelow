extends Object

## Crystal UI net tabs / root / cycle.

const ThemeS := preload("res://scripts/ui/theme.gd")
const CrystalNet := preload("res://scripts/world/crystal/net.gd")
const Util := preload("res://scripts/ui/crystal_ui/ui_util.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")

static func net_tabs(host, box: VBoxContainer) -> void:
	var shell := HBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	var left := HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(36, 28)
	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size = Vector2(36, 28)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(200, 52)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	var local_ok := CrystalNet.local_unlocked(host.host)
	var floor_ok := CrystalNet.floor_unlocked()
	var on_local: bool = str(host.page) == "local"
	var b1 := ThemeS.btn(App.tr("pages_net.local"), func(): go_local(host), local_ok)
	var b2 := ThemeS.btn(App.tr("pages_net.floors"), func(): go_floors(host), floor_ok)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.custom_minimum_size = Vector2(160, 44)
	b2.custom_minimum_size = Vector2(160, 44)
	if on_local:
		b1.disabled = true
		b1.focus_mode = Control.FOCUS_NONE
	else:
		b2.disabled = true
		b2.focus_mode = Control.FOCUS_NONE
	row.add_child(b1)
	row.add_child(b2)
	sc.add_child(row)
	shell.add_child(left)
	shell.add_child(sc)
	shell.add_child(right)
	PromptView.fill(left, [{"action": "tab_left"}], 16, ThemeS.INK_SOFT)
	PromptView.fill(right, [{"action": "tab_right"}], 16, ThemeS.INK_SOFT)
	box.add_child(shell)

static func cycle_net(host, dir: int) -> void:
	if dir == 0:
		return
	var local_ok := CrystalNet.local_unlocked(host.host)
	var floor_ok := CrystalNet.floor_unlocked()
	if str(host.page) == "local" and floor_ok:
		go_floors(host)
	elif (str(host.page) == "floors" or str(host.page) == "band") and local_ok:
		go_local(host)

static func page_root(host) -> void:
	Util.panel(host, Vector2(520, 220), Vector2(880, 620))
	var box := VBoxContainer.new()
	box.position = Vector2(552, 252)
	box.size = Vector2(816, 556)
	box.add_theme_constant_override("separation", 10)
	host.add_child(box)
	box.add_child(ThemeS.lab(App.tr("pages_net.floor_crystal"), 30, ThemeS.INK))
	var cl := 1
	if host.spot:
		cl = int(host.spot.get("crystal_cl"))
	box.add_child(ThemeS.lab(App.tr("pages_net.f_cl") % [App.floor_n, cl], 20, ThemeS.INK_SOFT))
	var local_ok := CrystalNet.local_unlocked(host.host)
	var floor_ok := CrystalNet.floor_unlocked()
	var b1 := ThemeS.btn(App.tr("common.local_transport_network"), func(): go_local(host), local_ok)
	if not local_ok:
		b1.text = App.tr("pages_net.local_transport_network_bind_ano")
	box.add_child(b1)
	host.focus_btn = b1 if local_ok else null
	var b2 := ThemeS.btn(App.tr("common.floor_transport_network"), func(): go_floors(host), floor_ok)
	if not floor_ok:
		b2.text = App.tr("pages_net.floor_transport_network_reach_a")
	box.add_child(b2)
	if host.focus_btn == null and floor_ok:
		host.focus_btn = b2
	var back := ThemeS.btn(App.tr("common.back"), func(): host.close_ui())
	box.add_child(back)
	if host.focus_btn == null:
		host.focus_btn = back
	host.status = ThemeS.lab("", 18, ThemeS.INK_FAINT)
	box.add_child(host.status)

static func go_local(host) -> void:
	if not CrystalNet.local_unlocked(host.host):
		return
	host.page = "local"
	host._rebuild()

static func go_floors(host) -> void:
	if not CrystalNet.floor_unlocked():
		return
	host.page = "floors"
	host._rebuild()
