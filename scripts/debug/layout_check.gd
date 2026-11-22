extends RefCounted

## Menu layout probe (camp-menu-fade, camp-pause-phone flows). Each getter returns "" (or "caught") or the first fault.
## .hud_clear: while a camp menu is open the PlayHud bar is hidden (camp_hud.follow_menus), also after the hub was
## re-parented (the shot tool mounts it in a capture viewport). .hud_plant: a bar left drawn under an open menu is caught.
## .pause_geometry: pause_menu_view.rect_for over phone / 16:9 / 4:3 / ultrawide / notched canvases: inside the safe
## area, centred in it, 1920x1080 is the base (32, 16, 1856, 1048). .pause_fit: the open pause journal is centred in the
## live canvas and every Settings list row lies inside the list pane (none clipped or scrolled off). .pause_plant: the
## old fixed rect on this canvas and a row pushed past the pane must both be caught. .confirm_fit: the open confirm slip
## is centred across the canvas and its buttons sit inside it, clear of the prompt hint. .touch_prompt (touch HUD up, a
## world prompt shown): the HUD prompt chip reads as the touch Use button (ringed word, no pad glyph); .touch_plant: the
## same chip built with the touch HUD off (a pad glyph) is caught.

const View := preload("res://scripts/ui/pause_menu/pause_menu_view.gd")
const Touch := preload("res://scripts/input/touch_pad.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Chip := preload("res://scripts/ui/prompt_chip.gd")

var hud_clear: String:
	get:
		return hud_fault(_hud())
var hud_plant: String:
	get:
		var hud: CanvasLayer = _hud()
		if hud == null or not App.ui_open:
			return "hud_plant: needs an open camp menu and the PlayHud bar"
		var was: bool = hud.visible
		hud.visible = true
		var r: String = hud_fault(hud)
		hud.visible = was
		return "caught" if r != "" else "missed: a bar drawn under an open menu passed"
var pause_geometry: String:
	get:
		if View.rect_for(Vector2(1920, 1080), Vector4.ZERO) != Rect2(32, 16, 1856, 1048):
			return "16:9 base moved: %s" % View.rect_for(Vector2(1920, 1080), Vector4.ZERO)
		var cases: Array = [
			[Vector2(2337, 1080), Vector4.ZERO], [Vector2(2337, 1080), Vector4(132, 0, 132, 63)],
			[Vector2(1920, 1440), Vector4.ZERO], [Vector2(2560, 1080), Vector4.ZERO], [Vector2(1920, 1080), Vector4(0, 40, 0, 60)],
		]
		for c: Array in cases:
			var bad: String = rect_fault(View.rect_for(c[0], c[1]), c[0], c[1])
			if bad != "":
				return "%s ins %s: %s" % [c[0], c[1], bad]
		return ""
var pause_fit: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		if pm == null or not bool(pm.get("open")):
			return "pause_fit: pause menu not open"
		var vp: Vector2 = pm.get_viewport().get_visible_rect().size
		var panel: Control = pm.get_node("menu_panel") as Control
		var bad: String = rect_fault(Rect2(panel.position, panel.size), vp, Touch.safe_insets(vp))
		if bad != "":
			return "journal %s on %s: %s" % [Rect2(panel.position, panel.size), vp, bad]
		return rows_fault(_list_rows(pm), _list_pane(pm))
var pause_plant: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		var vp: Vector2 = pm.get_viewport().get_visible_rect().size
		if rect_fault(Rect2(32, 16, 1856, 1048), vp, Vector4.ZERO) == "":
			return "missed: the old fixed journal passed as centred on %s" % vp
		var pane: Rect2 = _list_pane(pm)
		var rows: Array[Rect2] = _list_rows(pm)
		if rows.is_empty():
			return "pause_plant: no Settings list rows"
		rows.append(Rect2(rows[-1].position + Vector2(0, pane.size.y), rows[-1].size))
		return "caught" if rows_fault(rows, pane) != "" else "missed: a row past the list pane passed"

var confirm_fit: String:
	get:
		var pm: CanvasLayer = App.pause_menu
		var dlg: Node = pm.get_node_or_null("confirm_dlg")
		if dlg == null:
			return "confirm_fit: no confirm slip open"
		var vp: Vector2 = pm.get_viewport().get_visible_rect().size
		var paper: Control = null
		for c: Node in dlg.find_children("*", "TextureRect", true, false):
			if c.has_meta("paper_tex"):
				paper = c as Control
		var hint: Control = dlg.find_child("confirm_hint", true, false) as Control
		if paper == null or hint == null:
			return "confirm_fit: slip paper or hint missing"
		var pr: Rect2 = paper.get_global_rect()
		if not Rect2(Vector2.ZERO, vp).encloses(pr) or absf(pr.position.x - (vp.x - pr.end.x)) > 2.0:
			return "confirm slip %s not centred across %s" % [pr, vp]
		for b: Node in dlg.find_children("*", "Button", true, false):
			var br: Rect2 = (b as Control).get_global_rect()
			if br.intersects(hint.get_global_rect()) or not paper.get_global_rect().encloses(br):
				return "confirm button %s overlaps the hint or leaves the slip" % br
		return ""

var touch_prompt: String:
	get:
		var row: Control = _prompt_row()
		if row == null or str(App.interact_prompt) == "":
			return "touch_prompt: no HUD prompt row or no world prompt"
		return prompt_fault(row)
var touch_plant: String:
	get:
		var row: Control = _prompt_row()
		var was: bool = Touch.force_show
		Touch.force_show = false
		var tmp := HBoxContainer.new()
		row.get_parent().add_child(tmp)
		PromptView.fill(tmp, [{"action": "interact", "verb": "x"}])
		var r: String = prompt_fault(tmp)
		tmp.free()
		Touch.force_show = was
		return "caught" if r != "" else "missed: a pad glyph passed as the touch word"

## The first prompt chip in row must be the touch Use word with its ring.
static func prompt_fault(row: Control) -> String:
	for c: Node in row.get_children():
		if not c.has_meta(Chip.META) or c.get_child_count() == 0:
			continue
		var g: Node = c.get_child(0)
		if not (g is Label):
			return "prompt chip shows a %s (pad / key glyph), not the touch word" % g.get_class()
		if (g as Label).text != App.tr("hud_draw.use") or not (g as Label).has_theme_stylebox_override("normal"):
			return "prompt chip word %s (ring %s), want %s" % [(g as Label).text, (g as Label).has_theme_stylebox_override("normal"), App.tr("hud_draw.use")]
		return ""
	return "no prompt chip in the HUD prompt row"

static func _prompt_row() -> Control:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for n: Node in tree.root.find_children("*", "CanvasLayer", true, false):
		if "prompt_row" in n and n.get("prompt_row") is Control:
			return n.get("prompt_row") as Control
	return null

static func hud_fault(hud: CanvasLayer) -> String:
	if hud == null:
		return "no PlayHud bar on the hub"
	if App.ui_open and hud.visible:
		return "PlayHud bar drawn while a menu is open (it overlaps the panel top)"
	return ""

## Rect r inside the safe area of a vp canvas and centred in it (2 px slack).
static func rect_fault(r: Rect2, vp: Vector2, ins: Vector4) -> String:
	var safe := Rect2(ins.x, ins.y, vp.x - ins.x - ins.z, vp.y - ins.y - ins.w)
	if not safe.encloses(r):
		return "outside the safe area %s" % safe
	var gl: float = r.position.x - safe.position.x
	var gr: float = safe.end.x - r.end.x
	var gt: float = r.position.y - safe.position.y
	var gb: float = safe.end.y - r.end.y
	if absf(gl - gr) > 2.0 or absf(gt - gb) > 2.0:
		return "off centre (left %d right %d top %d bottom %d)" % [gl, gr, gt, gb]
	return ""

static func rows_fault(rows: Array[Rect2], pane: Rect2) -> String:
	if rows.is_empty():
		return "no Settings list rows"
	for i: int in rows.size():
		if not pane.grow(1.0).encloses(rows[i]):
			return "list row %d %s outside the list pane %s" % [i, rows[i], pane]
	return ""

static func _hud() -> CanvasLayer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var n: Node = tree.get_first_node_in_group("player")
	while n != null and not ("hud" in n and "hint" in n):
		n = n.get_parent()
	return null if n == null else n.get("hud") as CanvasLayer

static func _settings(pm: CanvasLayer) -> Node:
	return pm.call("_settings_host")

static func _list_pane(pm: CanvasLayer) -> Rect2:
	var s: Node = _settings(pm)
	var sc: Variant = s.get_meta("_list_scroll", null) if s else null
	return (sc as Control).get_global_rect() if sc is Control else Rect2()

static func _list_rows(pm: CanvasLayer) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var s: Node = _settings(pm)
	if s == null:
		return out
	for b: Variant in s.get("list_btns"):
		if b is Control and is_instance_valid(b):
			out.append((b as Control).get_global_rect())
	return out
