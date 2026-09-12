extends CanvasLayer

const ThemeS := preload("res://scripts/ui/theme.gd")
const RecapBars := preload("res://scripts/ui/recap_bars.gd")
const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Ui := preload("res://scripts/ui/recap_ui.gd")
const Rebuild := preload("res://scripts/ui/recap_rebuild.gd")
const Flow := preload("res://scripts/ui/recap_flow.gd")

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


func _ready() -> void:
	Ui.build(self)


func _make_tip() -> void:
	Ui.make_tip(self)


func play(cond: String) -> void:
	Flow.play(self, cond)


func _rebuild(cond: String) -> void:
	Rebuild.rebuild(self, cond)


func _blur_tip() -> void:
	RecapBars.blur_tip(self)


func _hide_tip() -> void:
	RecapBars.hide_tip(self)


func _focus() -> void:
	if focus_btn:
		focus_btn.grab_focus()


func _mark_starting() -> void:
	Flow.mark_starting(self)


func _process(delta: float) -> void:
	Flow.tick(self, delta)


func _continue_btn() -> Button:
	return Flow.continue_btn(self)


func _lock_totals() -> void:
	Flow.lock_totals(self)


func _refresh_skills() -> void:
	RecapBars.refresh(self)


func _mailed_line() -> String:
	return Flow.mailed_line(self)


func skip_drain() -> void:
	Flow.skip_drain(self)


func _finish() -> void:
	Flow.finish(self)


func _unhandled_input(event: InputEvent) -> void:
	Flow.handle_unhandled(self, event)
