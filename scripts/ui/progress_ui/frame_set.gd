extends Object

## The object frames the progress panel host can wear. Add a skin: write its script (see frame_base.gd), list it here.
## Mount order is list order; the host mounts once and re-applies on every open.

const FrameBase: GDScript = preload("res://scripts/ui/progress_ui/frame_base.gd")
const VendorFrame: GDScript = preload("res://scripts/ui/progress_ui/vendor_frame.gd")
const DumpsterFrame: GDScript = preload("res://scripts/ui/progress_ui/dumpster_frame.gd")
const ControlsFrame: GDScript = preload("res://scripts/ui/progress_ui/controls_frame.gd")
const AnvilFrame: GDScript = preload("res://scripts/ui/progress_ui/anvil_frame.gd")

const SKINS: Array = [VendorFrame, DumpsterFrame, ControlsFrame, AnvilFrame]

static func mount(host: CanvasLayer) -> void:
	for skin: GDScript in SKINS:
		FrameBase.mount(host, skin)

static func apply(host: CanvasLayer) -> void:
	FrameBase.apply(host, SKINS)
