extends CanvasLayer

const RecapBars := preload("res://scripts/ui/recap/bars.gd")
const TipHover := preload("res://scripts/ui/tip_hover.gd")
const Ui := preload("res://scripts/ui/recap/recap_ui.gd")
const Rebuild := preload("res://scripts/ui/recap/rebuild.gd")
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
	Flow.tick(self, delta)

func skip_drain() -> void:
	Flow.skip_drain(self)

func _finish() -> void:
	Flow.finish(self)

func _unhandled_input(event: InputEvent) -> void:
	Flow.handle_unhandled(self, event)
