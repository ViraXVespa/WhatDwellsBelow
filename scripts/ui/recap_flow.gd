extends Object

## Recap play / drain / finish flow.

const RecapBars := preload("res://scripts/ui/recap_bars.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Rebuild := preload("res://scripts/ui/recap_rebuild.gd")


static func play(host: CanvasLayer, cond: String) -> void:
	host.open = true
	host.visible = true
	host.draining = true
	host.applied = false
	App.ui_open = true
	host.get_tree().paused = true
	host.shown.clear()
	host.targets.clear()
	host.perm0.clear()
	host.run0.clear()
	host.keep0.clear()
	host.gain_now.clear()
	host.rows.clear()
	host.skill_labs.clear()
	host.head_right = null
	RecapBars.hide_tip(host)
	var keep: float = App.bal.xp_keep
	for id in App.prog.SKILLS:
		var runx := float(App.prog.skills_run.get(id, 0.0))
		var perm := float(App.prog.skills_perm.get(id, 0.0))
		host.run0[id] = runx
		host.perm0[id] = perm
		host.keep0[id] = runx * keep
		host.shown[id] = runx
		host.targets[id] = 0.0
		host.gain_now[id] = 0.0
	Rebuild.rebuild(host, cond)
	PromptView.footer(host, [{"action": "ui_accept", "verb": "continue"}])
	host.set_process(true)

static func tick(host: CanvasLayer, delta: float) -> void:
	if not host.draining:
		return
	var left := false
	for id in App.prog.SKILLS:
		var cur := float(host.shown.get(id, 0.0))
		var start := float(host.run0.get(id, 0.0))
		if cur > 0.2:
			host.shown[id] = move_toward(cur, 0.0, RecapBars.xfer_speed(host, id, cur) * delta)
			left = true
		else:
			host.shown[id] = 0.0
		if start > 0.0001:
			host.gain_now[id] = float(host.keep0.get(id, 0.0)) * (1.0 - float(host.shown[id]) / start)
		else:
			host.gain_now[id] = float(host.keep0.get(id, 0.0))
	if not left:
		host.draining = false
		lock_totals(host)
		mark_starting(host)
		RecapBars.refresh(host)
		if host.flavor:
			host.flavor.text = "Permanent totals locked in."
		if host.mailed_lab:
			host.mailed_lab.text = mailed_line(host)
		var cont := continue_btn(host)
		if cont:
			cont.disabled = false
			cont.grab_focus()
	else:
		RecapBars.refresh(host)

static func continue_btn(host: CanvasLayer) -> Button:
	for n in host.box.get_children():
		if n is Button and bool(n.get_meta("recap_continue", false)):
			return n
	return null

static func lock_totals(host: CanvasLayer) -> void:
	if host.applied:
		return
	host.applied = true
	for id in App.prog.SKILLS:
		host.shown[id] = 0.0
		host.gain_now[id] = float(host.keep0.get(id, 0.0))
	App.prog.keep_fragments()
	App.save_now()
	if App.tel:
		App.tel.recap_drain = true

static func mailed_line(_host: CanvasLayer) -> String:
	var g: int = int(App.prog.mailed_gold)
	var o: int = int(App.prog.mailed_ore)
	var w: int = int(App.prog.mailed_wood)
	var r: int = int(App.prog.mailed_root)
	var names: PackedStringArray = App.prog.mailed_names
	if g + o + w + r + names.size() <= 0:
		return "Nothing reached the surface."
	var bits: PackedStringArray = PackedStringArray()
	if g > 0:
		bits.append("%dg" % g)
	if o > 0:
		bits.append("%d ore" % o)
	if w > 0:
		bits.append("%d wood" % w)
	if r > 0:
		bits.append("%d root" % r)
	if names.size() > 0:
		bits.append(", ".join(names))
	return "Extracted: " + ", ".join(bits)

static func skip_drain(host: CanvasLayer) -> void:
	for id in App.prog.SKILLS:
		host.shown[id] = 0.0
		host.gain_now[id] = float(host.keep0.get(id, 0.0))
	host.draining = false
	lock_totals(host)
	mark_starting(host)
	RecapBars.refresh(host)
	if host.flavor:
		host.flavor.text = "Permanent totals locked in."
	if host.mailed_lab:
		host.mailed_lab.text = mailed_line(host)
	var cont := continue_btn(host)
	if cont:
		cont.disabled = false

static func finish(host: CanvasLayer) -> void:
	if host.draining:
		return
	RecapBars.hide_tip(host)
	host.open = false
	host.visible = false
	App.ui_open = false
	host.get_tree().paused = false
	host.set_process(false)
	App.prog.lose_unextracted()
	if App.playtest and App.playtest.has_method("consume_recap") and App.playtest.consume_recap():
		return
	App.wake_pending = true
	App.go_camp()

static func mark_starting(host: CanvasLayer) -> void:
	if host.head_right:
		host.head_right.text = "Starting XP"


static func handle_unhandled(host: CanvasLayer, event: InputEvent) -> void:
	if not host.open:
		return
	if event.is_action_pressed("ui_accept") and not host.draining:
		finish(host)
		host.get_viewport().set_input_as_handled()