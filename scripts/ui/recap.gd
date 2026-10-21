extends CanvasLayer

const TipHover := preload("res://scripts/ui/tip_hover.gd")
const Ui := preload("res://scripts/ui/recap/recap_ui.gd")
const Rebuild := preload("res://scripts/ui/recap/rebuild.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const Flow := preload("res://scripts/ui/recap/recap_flow.gd")

var open := false
var box: VBoxContainer
var scroll: ScrollContainer
var draining := false
var applied := false
var shown: Dictionary = {}
var targets: Dictionary = {}
var perm0: Dictionary = {}
var run0: Dictionary = {}
var keep0: Dictionary = {}
var gain_now: Dictionary = {}
var rows: Dictionary = {}
var focus_btn: Control
var flavor: Label
var mailed_lab: Label
var head_right: Label
var skill_labs: Dictionary = {}
var last_title := ""
var tip_host: PanelContainer
var tip_lab: Label
var tip_id := ""
var tip_kind := ""
var tip_from: Control = null
var tip_sheet: Rect2 = Rect2()
var sheet_rect: Rect2 = Rect2()
var header: VBoxContainer
var footer: VBoxContainer
var cont_btn: Button

func _ready() -> void:
	Ui.build(self)

func _fit_sheet() -> void:
	Ui.fit(self)

func play(cond: String) -> void:
	Flow.play(self, cond)

func _rebuild(cond: String) -> void:
	Rebuild.rebuild(self, cond)

func _blur_tip() -> void:
	TipHover.blur(self, "skill_id")

func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()

func _process(delta: float) -> void:
	if cont_btn and is_instance_valid(cont_btn):
		var g: TextureRect = cont_btn.get_meta("glyph", null) as TextureRect
		var t: Texture2D = Prompts.texture_for("ui_accept")
		if g and g.texture != t:
			g.texture = t
		_dim_continue()
	Flow.tick(self, delta)

func skip_drain() -> void:
	Flow.skip_drain(self)

func _finish() -> void:
	Flow.finish(self)

func _unhandled_input(event: InputEvent) -> void:
	Flow.handle_unhandled(self, event)

## Glyph + label follow the button's disabled look (theme font_disabled_color) during the XP drain.
func _dim_continue() -> void:
	var lab: Label = cont_btn.get_meta("glyph_lab", null) as Label
	var g: TextureRect = cont_btn.get_meta("glyph", null) as TextureRect
	if lab == null or g == null:
		return
	var off: bool = cont_btn.disabled
	var col: Color = cont_btn.get_theme_color("font_disabled_color" if off else "font_color")
	if lab.get_theme_color("font_color") != col:
		lab.add_theme_color_override("font_color", col)
	g.modulate = Color(1, 1, 1, maxf(0.35, col.a * 0.6)) if off else Color.WHITE
