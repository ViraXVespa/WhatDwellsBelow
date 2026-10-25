extends Object

## The object frames the progress panel host can wear. Add a skin: write its script (see frame_base.gd), list it here.
## Mount order is list order; the host mounts once and re-applies on every open.

const FrameBase: GDScript = preload("res://scripts/ui/progress_ui/frame_base.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const VendorFrame: GDScript = preload("res://scripts/ui/progress_ui/vendor_frame.gd")
const DumpsterFrame: GDScript = preload("res://scripts/ui/progress_ui/dumpster_frame.gd")
const ControlsFrame: GDScript = preload("res://scripts/ui/progress_ui/controls_frame.gd")
const AnvilFrame: GDScript = preload("res://scripts/ui/progress_ui/anvil_frame.gd")
const CrystalFrame: GDScript = preload("res://scripts/ui/progress_ui/crystal_frame.gd")
const ExtractFrame: GDScript = preload("res://scripts/ui/progress_ui/extract_frame.gd")
const ShopFrame: GDScript = preload("res://scripts/ui/progress_ui/shop_frame.gd")
const QuestFrame: GDScript = preload("res://scripts/ui/progress_ui/quest_frame.gd")
const ReceptionFrame: GDScript = preload("res://scripts/ui/progress_ui/receptionist_frame.gd")
const GuideFrame: GDScript = preload("res://scripts/ui/progress_ui/guide_frame.gd")

const SKINS: Array = [VendorFrame, DumpsterFrame, ControlsFrame, AnvilFrame, CrystalFrame, ExtractFrame, ShopFrame, QuestFrame, ReceptionFrame, GuideFrame]

static func mount(host: CanvasLayer) -> void:
	for skin: GDScript in SKINS:
		FrameBase.mount(host, skin)

## Text scale cap of the frame `mode` wears (skin const TEXT_CAP: fixed art that cannot grow with the text); 0 = none.
static func text_cap(mode: String) -> float:
	for skin: GDScript in SKINS:
		if str(skin.spec()["mode"]) == mode:
			return float(skin.get("TEXT_CAP")) if skin.get("TEXT_CAP") != null else 0.0
	return 0.0

static func btn_skin(host: CanvasLayer) -> String:
	return FrameBase.btn_skin(host, SKINS)

static func apply(host: CanvasLayer) -> void:
	FrameBase.apply(host, SKINS)
