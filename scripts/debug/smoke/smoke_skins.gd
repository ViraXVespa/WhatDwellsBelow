extends Object

## P7: popups follow the host skin (design/ui-style.md Control skins). Under a crystal host a tooltip panel, a
## picker panel and its labels, a confirm card and a scroll bar wear the crystal colours; under a host with no skin
## (pause journal) the tooltip keeps its paper box. No dark label under a skin carries an outline. The progress panel maps loadout and extract to crystal and
## anvil to neutral through the frames' BTN_SKIN hook.

const BtnSkin := preload("res://scripts/ui/btn_skin.gd")
const UiBuild: GDScript = preload("res://scripts/ui/ui_build.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Tok := preload("res://scripts/ui/ui_tokens.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const StepRow := preload("res://scripts/ui/step_row.gd")
const FrameSet := preload("res://scripts/ui/progress_ui/frame_set.gd")

static func run(host: Node) -> bool:
	var want: Dictionary = Tok.SKIN_CRYSTAL
	var sky := CanvasLayer.new()
	sky.set_meta("btn_skin", "crystal")
	sky.set_meta("prompt_ink", true)
	host.add_child(sky)
	var tip: PanelContainer = UiBuild.tip_panel(80)
	sky.add_child(tip)
	var good: bool = _bg(tip).is_equal_approx(want["panel"])
	var pick := PanelContainer.new()
	BtnSkin.watch(pick, "panel")
	sky.add_child(pick)
	var lab: Label = ThemeS.lab("x", 18, ThemeS.INK)
	pick.add_child(lab)
	good = good and _bg(pick).is_equal_approx(want["panel"])
	good = good and lab.get_theme_color("font_color").is_equal_approx(want["words"][0])
	Confirm.open(sky, "t", "b", Callable())
	var card: ColorRect = null
	for n: Node in sky.find_children("*", "ColorRect", true, false):
		if (n as ColorRect).size == Vector2(800, 360):
			card = n
	good = good and card != null and card.color.is_equal_approx(want["panel"])
	Confirm.close(sky)
	var row: HBoxContainer = StepRow.make("Floor:", Callable(), Callable())
	sky.add_child(row)
	good = good and _no_dark_halo(sky)
	var sc := ScrollContainer.new()
	sky.add_child(sc)
	UiBuild.bars(sc, true)
	var thumb: StyleBox = sc.get_v_scroll_bar().get_theme_stylebox("grabber")
	good = good and thumb is StyleBoxFlat and (thumb as StyleBoxFlat).bg_color.is_equal_approx(want["edge"])
	var plain := CanvasLayer.new()
	host.add_child(plain)
	var paper_tip: PanelContainer = UiBuild.tip_panel(80)
	plain.add_child(paper_tip)
	good = good and not _bg(paper_tip).is_equal_approx(want["panel"])
	var maps: Dictionary = {"loadout": "crystal", "extract": "crystal", "anvil": "neutral"}
	var mapped: Dictionary = {}
	for mode: String in maps:
		mapped[mode] = _mode_skin(mode)
	good = good and mapped == maps
	sky.queue_free()
	plain.queue_free()
	printerr("P7: host_skin=" + str(good) + " " + str(mapped))
	return good

## Dark text never carries an outline (UiBuild.halo): a dark halo smudges dark ink.
static func _no_dark_halo(root: Node) -> bool:
	for n: Node in root.find_children("*", "Label", true, false):
		var l := n as Label
		if l.get_theme_color("font_color").get_luminance() < 0.5 and l.get_theme_constant("outline_size") > 0:
			printerr("P7: dark_halo " + str(l.text) + " " + str(l.get_path()))
			return false
	return true

static func _bg(p: PanelContainer) -> Color:
	var s: StyleBox = p.get_theme_stylebox("panel")
	return (s as StyleBoxFlat).bg_color if s is StyleBoxFlat else Color(0, 0, 0, 0)

## FrameBase.btn_skin reads host.mode; a bare holder with that one field stands in for the progress panel.
static func _mode_skin(mode: String) -> String:
	var holder := _ModeHost.new()
	holder.mode = mode
	var out: String = FrameSet.btn_skin(holder)
	holder.free()
	return out

class _ModeHost extends CanvasLayer:
	var mode: String = ""
