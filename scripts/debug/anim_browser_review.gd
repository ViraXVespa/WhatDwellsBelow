extends Object

## Animation Browser review chrome. Facade stays scripts/debug/anim_browser.gd.

const ThemeS := preload("res://scripts/ui/theme.gd")
const AnimReview := preload("res://scripts/debug/anim_review.gd")


static func model_id(host: Node) -> String:
	var models: Array = host.models
	if models.is_empty():
		return ""
	var m: Dictionary = models[host.model_i]
	return str(m.get("id", m.get("label", "")))


static func build(host: Node) -> void:
	var review_btn: Button = ThemeS.btn("Good  (Y)", func(): cycle(host))
	review_btn.position = Vector2(980, 860)
	review_btn.size = Vector2(900, 48)
	host.add_child(review_btn)
	host.review_btn = review_btn
	var note_edit := LineEdit.new()
	note_edit.position = Vector2(48, 916)
	note_edit.size = Vector2(1824, 52)
	note_edit.placeholder_text = "Notes (keyboard) — kept for Repack / Regenerate"
	note_edit.add_theme_font_size_override("font_size", 18)
	note_edit.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62))
	note_edit.add_theme_color_override("font_placeholder_color", Color(0.55, 0.48, 0.36))
	note_edit.text_changed.connect(func(t: String): on_note(host, t))
	note_edit.visible = false
	host.add_child(note_edit)
	host.note_edit = note_edit


static func open(host: Node) -> void:
	AnimReview.ensure_loaded()
	refresh(host)


static func close(_host: Node) -> void:
	AnimReview.save_disk()


static func cycle(host: Node) -> void:
	var anim: String = host.anim_name
	if anim == "":
		return
	AnimReview.cycle(model_id(host), str(host.facing), anim, host._frames().size())
	refresh(host)


static func refresh(host: Node) -> void:
	var review_btn: Button = host.review_btn
	var note_edit: LineEdit = host.note_edit
	if review_btn == null or note_edit == null:
		return
	var anim: String = host.anim_name
	var n: int = host._frames().size()
	var id := model_id(host)
	if anim == "" or not AnimReview.can_review(n):
		review_btn.text = "Still — no review"
		review_btn.disabled = true
		note_edit.visible = false
		return
	review_btn.disabled = false
	var facing := str(host.facing)
	var st := AnimReview.state_of(id, facing, anim)
	review_btn.text = "%s  (Y)" % AnimReview.label_of(id, facing, anim)
	if st == AnimReview.REPACK:
		review_btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	elif st == AnimReview.REGEN:
		review_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	else:
		review_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	var show_note := st == AnimReview.REPACK or st == AnimReview.REGEN
	note_edit.visible = show_note
	host.note_lock = true
	if show_note:
		note_edit.text = AnimReview.note_of(id, facing, anim)
	host.note_lock = false


static func on_note(host: Node, t: String) -> void:
	if bool(host.note_lock) or str(host.anim_name) == "":
		return
	AnimReview.set_note(model_id(host), str(host.facing), str(host.anim_name), t, host._frames().size())


static func handle_tip(host: Node, event: InputEvent) -> bool:
	if not event.is_action_pressed("gear_tip"):
		return false
	var note_edit: LineEdit = host.note_edit
	if note_edit and note_edit.has_focus() and event is InputEventKey:
		return false
	cycle(host)
	return true
