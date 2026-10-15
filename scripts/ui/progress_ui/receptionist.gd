extends Object

## Receptionist pages. Root is Talk and Ask?. Talk shows one lore line. Ask? lists How-to-Play topics.
## A topic opens on the guide frame. B / Esc steps one page up and closes at the root (ui-run-flow).

const ThemeS := preload("res://scripts/ui/theme.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Talk := preload("res://scripts/data/talk_lines.gd")
const Pages := preload("res://scripts/data/tutorial_pages.gd")

const TALK_W: float = 920.0

static func rebuild(ui) -> void:
	ui._clear()
	var page: String = str(ui.reception_page)
	if page == "talk":
		_talk(ui)
	elif page == "ask":
		_ask(ui)
	elif page == "topic":
		_topic(ui)
	else:
		_root(ui)

static func hint(ui) -> void:
	var page: String = str(ui.reception_page)
	var verb: String = "leave" if page == "root" else "back"
	PromptView.footer(ui, [{"action": "ui_cancel", "verb": verb}])

## True when a page stepped back. False at the root, so the caller closes the menu.
static func back(ui) -> bool:
	var page: String = str(ui.reception_page)
	if page == "root":
		return false
	if page == "topic":
		ui.reception_page = "ask"
		ui.mode = "receptionist"
	else:
		ui.reception_page = "root"
		ui.mode = "receptionist"
	rebuild(ui)
	ui._show()
	return true

static func _root(ui) -> void:
	ui.mode = "receptionist"
	var talk: Button = ThemeS.btn(App.tr("receptionist.talk"), func() -> void:
		ui.reception_page = "talk"
		rebuild(ui)
		ui._show()
	, true, "primary")
	ui.focus_btn = talk
	ui.box.add_child(talk)
	var ask: Button = ThemeS.btn(App.tr("receptionist.ask"), func() -> void:
		ui.reception_page = "ask"
		rebuild(ui)
		ui._show()
	, true, "primary")
	ui.box.add_child(ask)

static func _talk(ui) -> void:
	ui.mode = "receptionist"
	var key: String = Talk.line_key("receptionist")
	Talk.commit_once("receptionist")
	var line: Button = _read(App.tr(key), func() -> void:
		ui.reception_page = "root"
		rebuild(ui)
		ui._show()
	, 200.0)
	ui.focus_btn = line
	ui.box.add_child(line)

static func _ask(ui) -> void:
	ui.mode = "receptionist"
	ui.box.add_child(ThemeS.lab(App.tr("receptionist.prompt"), 26, ThemeS.INK))
	var first: bool = true
	for row: Dictionary in Pages.PAGES:
		var id: String = str(row["id"])
		var topic: Button = ThemeS.btn(App.tr(str(row["title"])), _open_topic.bind(ui, id), true, "primary")
		if first:
			ui.focus_btn = topic
			first = false
		ui.box.add_child(topic)

static func _open_topic(ui, id: String) -> void:
	ui.reception_topic = id
	ui.reception_page = "topic"
	ui.mode = "guide"
	rebuild(ui)
	ui._show()

static func _topic(ui) -> void:
	ui.mode = "guide"
	var row: Dictionary = Pages.page_of(str(ui.reception_topic))
	ui.box.add_child(ThemeS.lab(App.tr(str(row["title"])), 32, ThemeS.INK))
	var shot: TextureRect = TextureRect.new()
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shot.texture = Pages.shot_tex(str(row["id"]))
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shot.custom_minimum_size = Vector2(TALK_W, 300)
	shot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ui.box.add_child(shot)
	var body: Button = _read(App.tr(str(row["body"])), Callable(), 240.0)
	ui.focus_btn = body
	ui.box.add_child(body)

## A reading block: ink on the page, a ring only while it has pad focus. A on the Talk line returns to the choices.
static func _read(text: String, on_press: Callable, tall: float) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.clip_text = false
	b.custom_minimum_size = Vector2(TALK_W, tall)
	UiBuild.button_base(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiBuild.ink_text(b)
	b.add_theme_font_override("font", ThemeS.ink_font())
	b.add_theme_font_size_override("font_size", ThemeS.font_px(22))
	UiBuild.states(b, _pad(0), _pad(0), _pad(0), _pad(2), _pad(0))
	if not on_press.is_null():
		b.pressed.connect(on_press)
	return b

static func _pad(border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = ThemeS.INK
	box.set_border_width_all(border)
	box.set_content_margin_all(10)
	return box
