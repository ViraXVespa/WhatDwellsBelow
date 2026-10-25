extends Object

## Pause > Settings > Report Bug page (design/tasks/bug-report-relay.md). Gamepad-first: area and "what happened"
## cycle on A, so a report can go without typing; details and email are optional text fields. The form lives in
## static vars so a rebuild (cycle, send result) keeps it. Sending goes through bug_send.gd.

const ThemeS := preload("res://scripts/ui/theme.gd")
const View := preload("res://scripts/ui/split_menu/split_menu_view.gd")
const Pages := preload("res://scripts/ui/pause_settings/settings_pages.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const Send := preload("res://scripts/app/bug_report/bug_send.gd")
const Crash := preload("res://scripts/app/bug_report/crash_mark.gd")

static var form := {"area": 0, "kind": 0, "details": "", "email": "", "opt_in": false, "shot": true, "crash": true}
static var status := ""
static var busy := false

static func build(host: Node) -> void:
	_cycle(host, "bug_report.area", Send.AREAS[int(form.area)][0], "area", Send.AREAS.size())
	_cycle(host, "bug_report.kind", Send.KINDS[int(form.kind)], "kind", Send.KINDS.size())
	var te := TextEdit.new()
	te.placeholder_text = App.tr("bug_report.details_hint")
	te.text = str(form.details)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(560, 120)
	te.set("tab_input_mode", false)
	te.text_changed.connect(func() -> void: form.details = te.text)
	_field(host, te)
	var em := LineEdit.new()
	em.placeholder_text = App.tr("bug_report.email_hint")
	em.text = str(form.email)
	em.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	em.text_changed.connect(func(t: String) -> void: form.email = t)
	_field(host, em)
	_toggle(host, "bug_report.opt_in", "opt_in")
	_toggle(host, "bug_report.shot", "shot")
	if Crash.crashed_log != "":
		_toggle(host, "bug_report.crash", "crash")
	var go: Button = ThemeS.btn(App.tr("bug_report.send"), func() -> void: send(host), not busy)
	View.add_page_btn(host, go)
	var note: Label = ThemeS.lab(App.tr("bug_report.privacy"), 16, ThemeS.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.info_box.add_child(note)
	if status != "":
		var st: Label = ThemeS.lab(status, 20, ThemeS.INK, HORIZONTAL_ALIGNMENT_CENTER)
		st.name = "report_status"
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.info_box.add_child(st)

static func send(host: Node, dry_run: bool = false) -> void:
	if busy:
		return
	if not Send.email_ok(str(form.email)):
		_done(host, App.tr("bug_report.bad_email"))
		return
	busy = true
	_done(host, App.tr("bug_report.sending"))
	var shot := ""
	if bool(form.shot) and host.get("pause") is CanvasLayer:
		shot = await Send.capture(host.pause)
	Send.post(Send.payload(form, shot, dry_run), func(code: int, data: Dictionary) -> void:
		busy = false
		if code == 201:
			form.details = ""
		_done(host, Send.status_text(code, data))
	)

static func _done(host: Node, text: String) -> void:
	status = text
	if not is_instance_valid(host) or str(host.get("split_page")) != "report":
		return
	host.split_build_page("report")
	View.apply_col(host)
	if str(host.get("col")) == "detail":
		_focus_send(host)

static func _focus_send(host: Node) -> void:
	for b: Variant in host.info_btns:
		if b is Button and str((b as Button).text) == App.tr("bug_report.send"):
			(b as Button).grab_focus()
			return

static func _cycle(host: Node, key: String, val_key: String, field: String, n: int) -> void:
	var i: int = host.info_btns.size()
	View.add_page_btn(host, ThemeS.btn(App.tr(key) % App.tr(val_key), func() -> void:
		form[field] = (int(form[field]) + 1) % n
		host.split_build_page("report")
		View.apply_col(host)
		if i < host.info_btns.size():
			(host.info_btns[i] as Control).grab_focus()
	))

static func _toggle(host: Node, key: String, field: String) -> void:
	Pages._add_check_centered(host, Pages._check(App.tr(key), bool(form[field]), func(on: bool) -> void: form[field] = on))

static func _field(host: Node, c: Control) -> void:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.focus_mode = Control.FOCUS_ALL
	c.add_theme_font_override("font", ThemeS.ink_font())
	UiText.track(c, 20)
	for k: String in ["font_color", "caret_color"]:
		c.add_theme_color_override(k, ThemeS.INK)
	c.add_theme_color_override("font_placeholder_color", ThemeS.INK_FAINT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeS.PAPER.lightened(0.08)
	sb.border_color = ThemeS.INK_SOFT
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	var foc: StyleBoxFlat = sb.duplicate()
	foc.border_color = ThemeS.INK
	foc.set_border_width_all(3)
	c.add_theme_stylebox_override("normal", sb)
	c.add_theme_stylebox_override("focus", foc)
	host.info_box.add_child(c)
	host.info_btns.append(c)
